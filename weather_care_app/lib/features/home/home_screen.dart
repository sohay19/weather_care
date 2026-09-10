import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';

import '../../models/app_settings.dart';
import '../../models/lifestyle_message.dart';
import '../../models/recommendation.dart';
import '../../models/weather.dart';
import '../../services/api_client.dart';
import '../../services/app_config.dart';
import '../../services/app_settings_repository.dart';
import '../../services/kma_direct_weather_service.dart';
import '../../services/kma_grid.dart';
import '../../services/installation_identity.dart';
import '../../services/notification_registration_service.dart';
import '../../services/notification_destination.dart';
import '../../services/settings_sync_service.dart';
import '../../services/weather_service.dart';
import '../../services/current_location_service.dart';
import '../../services/region_catalog.dart';
import '../../models/selectable_region.dart';
import '../../theme/weather_theme.dart';
import '../settings/settings_screen.dart';
import 'tabs/detail_tab.dart';
import 'tabs/main_tab.dart';
import 'tabs/today_tab.dart';
import 'tabs/week_tab.dart';
import 'widgets/server_connection_failure_dialog.dart';
import 'widgets/weather_status_view.dart';

class HomeScreen extends StatefulWidget {
  final int initialIndex;
  final NotificationTopic? initialNotificationTopic;
  final CurrentLocationService locationService;
  final WeatherService? weatherService;
  final SettingsSyncService? settingsSync;
  final NotificationRegistrationService? notificationRegistration;
  final RegionCatalog? regionCatalog;

  const HomeScreen({
    super.key,
    this.initialIndex = 2,
    this.initialNotificationTopic,
    this.locationService = const CurrentLocationService(),
    this.weatherService,
    this.settingsSync,
    this.notificationRegistration,
    this.regionCatalog,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  late AppSettings _settings;
  final AppSettingsRepository _settingsRepository =
      const AppSettingsRepository();
  WeatherService? _service;
  NotificationRegistrationService? _notificationRegistration;
  SettingsSyncService? _settingsSync;
  CurrentLocationService get _locationService => widget.locationService;
  DeviceCoordinates? _coordinates;
  LocationResult _location = const LocationResult(LocationState.idle);
  Future<void>? _refreshFuture;
  bool _refreshAgain = false;
  bool _requestPermission = false;
  bool _initialized = false;
  bool _leftApp = false;
  bool _registrationInitialized = false;
  RegionCatalog? _regionCatalog;
  ForecastRegion? get _manualRegion =>
      _regionCatalog?.find(_settings.manualRegionKey);
  int _locationRevision = 0;
  Future<void> _settingsSaveQueue = Future<void>.value();
  int _settingsRevision = 0;
  TodayWeatherResponse? _today;
  WeeklyWeatherResponse? _weekly;
  WeatherLoadMode? _loadMode;
  late int _selectedIndex;
  late NotificationTopic? _detailFocusTopic;
  LifestyleMessageType? _detailFocusLifestyleType;
  DetailFocusSource _detailFocusSource = DetailFocusSource.notification;
  int _detailFocusRequestId = 0;
  bool _loading = false;
  String _statusMessage = '운영 서버 연결 상태를 확인하고 있습니다.';

  KmaGrid? get _weatherGrid {
    final coordinates = _coordinates;
    if (_settings.locationMode != 'GPS') {
      if (_settings.manualRegionKey != null) {
        final selected = _manualRegion;
        // Never use an old saved grid when catalog identity is missing/changed.
        return selected == null
            ? null
            : KmaGrid(nx: selected.nx, ny: selected.ny);
      }
      final match = RegExp(r'^(\d{1,3})_(\d{1,3})$')
          .firstMatch(_settings.currentRegionId ?? '');
      if (match == null) return null;
      final nx = int.parse(match.group(1)!);
      final ny = int.parse(match.group(2)!);
      return nx > 0 && nx <= 149 && ny > 0 && ny <= 253
          ? KmaGrid(nx: nx, ny: ny)
          : null;
    }
    if (coordinates == null || !_location.hasLocation) return null;
    return KmaGrid.fromCoordinates(
      latitude: coordinates.latitude,
      longitude: coordinates.longitude,
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _settings = AppSettings.fallback('initializing-installation');
    _selectedIndex = widget.initialIndex < 0
        ? 0
        : widget.initialIndex > 4
            ? 4
            : widget.initialIndex;
    _detailFocusTopic = widget.initialNotificationTopic;
    _initialize();
  }

  Future<void> _initialize() async {
    final config = await AppConfig.load();
    final installationId = await const InstallationIdentity().getOrCreate();
    final savedSettings = await _settingsRepository.load(installationId);
    try {
      _regionCatalog = widget.regionCatalog ?? await RegionCatalog.load();
    } catch (_) {
      // GPS/legacy grids remain usable; the picker offers an explicit retry.
    }
    if (!mounted) return;
    _settings = savedSettings;
    final client = ApiClient(baseUrl: config.serverUrl);
    _settingsSync = widget.settingsSync ?? SettingsSyncService(client);
    _service = widget.weatherService ??
        WeatherService(
          client,
          directKma: KmaDirectWeatherService(
            serviceKey: config.kmaServiceKey,
          ),
        );
    _notificationRegistration = widget.notificationRegistration ??
        NotificationRegistrationService(client);
    // A failed remote preferences save must not prevent local GPS or weather.
    _settingsSaveQueue = _saveRemoteSettings(_settings);
    _initialized = true;
    await _loadData();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _locationRevision++;
    unawaited(_notificationRegistration?.dispose() ?? Future<void>.value());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _leftApp = true;
    }
    if (state == AppLifecycleState.resumed && _leftApp) {
      _leftApp = false;
      if (_initialized && _settings.locationMode == 'GPS') {
        unawaited(_refresh(supersede: true));
      }
    }
  }

  Future<void> _loadData() => _refresh();

  Future<void> _refresh(
      {bool requestPermission = false, bool supersede = false}) {
    if (_service == null) return Future<void>.value();
    if (_refreshFuture != null) {
      if (supersede) {
        _refreshAgain = true;
        _requestPermission |= requestPermission;
      }
      return _refreshFuture!;
    }
    _requestPermission |= requestPermission;
    final future = Future<void>.microtask(_refreshLoop);
    _refreshFuture = future;
    return future;
  }

  Future<void> _refreshLoop() async {
    if (!mounted) return;
    try {
      do {
        _refreshAgain = false;
        final revision = _locationRevision;
        final ask = _requestPermission;
        _requestPermission = false;
        if (_settings.locationMode == 'GPS') {
          setState(() {
            _location = const LocationResult(LocationState.checking);
            if (_today == null) {
              _loadMode = null;
              _statusMessage = _location.message;
            }
          });
          final result = await _locationService.locate(requestPermission: ask);
          if (!mounted) return;
          if (revision != _locationRevision) continue;
          setState(() {
            _location = result;
            _coordinates = result.coordinates;
          });
        } else {
          _coordinates = null;
          _location = const LocationResult(LocationState.idle);
        }
        final grid = _weatherGrid;
        if (grid == null) {
          setState(() {
            _today = null;
            _weekly = null;
            _loadMode = WeatherLoadMode.unavailable;
            _statusMessage = _settings.locationMode == 'GPS'
                ? '${_location.message}. Setting에서 위치를 다시 확인해주세요. 다른 지역으로 대체하지 않아요.'
                : '저장된 지역을 확인할 수 없어요. Setting에서 기준 지역을 다시 선택해주세요.';
          });
          _notificationRegistration?.invalidateLocation();
          continue;
        }
        if (_today != null &&
            (_today!.region.nx != grid.nx || _today!.region.ny != grid.ny)) {
          setState(() {
            _today = null;
            _weekly = null;
          });
        }
        final preciseCoordinates =
            _settings.locationMode == 'GPS' && _location.canUseLocalAnalysis
                ? _coordinates
                : null;
        final registration = _notificationRegistration;
        if (registration != null) {
          final register = _registrationInitialized
              ? registration.syncInstallation
              : registration.initialize;
          _registrationInitialized = true;
          unawaited(register(
              installationId: _settings.installationId,
              nx: grid.nx,
              ny: grid.ny,
              locationMode: _settings.locationMode,
              coordinates: preciseCoordinates));
        }
        await _fetchWeather(revision, grid, preciseCoordinates);
      } while (mounted && _refreshAgain);
    } finally {
      _refreshFuture = null;
    }
  }

  Future<void> _fetchWeather(
      int revision, KmaGrid grid, DeviceCoordinates? coordinates) async {
    final service = _service;
    if (service == null || _loading) return;

    _loading = true;
    if (_today == null || _weekly == null) {
      setState(() {
        _loadMode = null;
        _statusMessage = '운영 서버 연결 상태를 확인하고 있습니다.';
      });
    }

    try {
      while (mounted) {
        final serverResult = await service.fetchServerWeather(
          installationId: _settings.installationId,
          nx: grid.nx,
          ny: grid.ny,
          coordinates: coordinates,
        );

        if (!mounted || revision != _locationRevision) return;
        if (serverResult.hasWeather) {
          _applyResult(serverResult, grid);
          return;
        }

        final action = await showDialog<ServerFailureAction>(
          context: context,
          barrierDismissible: false,
          builder: (_) => const ServerConnectionFailureDialog(),
        );
        if (!mounted || revision != _locationRevision) return;

        if (action == ServerFailureAction.retryServer) {
          continue;
        }

        if (action == ServerFailureAction.useDirectForecast) {
          final directResult = await service.fetchDirectWeather(
            nx: grid.nx,
            ny: grid.ny,
          );
          if (!mounted || revision != _locationRevision) return;
          _applyResult(directResult, grid);
          return;
        }

        _applyResult(serverResult, grid);
        return;
      }
    } finally {
      _loading = false;
    }
  }

  void _applyResult(WeatherLoadResult result, KmaGrid expectedGrid) {
    setState(() {
      final received = result.today?.region;
      if (received != null &&
          (received.nx != expectedGrid.nx || received.ny != expectedGrid.ny)) {
        _today = null;
        _weekly = null;
        _loadMode = WeatherLoadMode.unavailable;
        _statusMessage = '기준 지역과 다른 날씨 자료를 받아 표시하지 않았어요. 새로고침해 다시 확인해주세요.';
        return;
      }
      final selected =
          _settings.locationMode == 'MANUAL' ? _manualRegion : null;
      final today = result.today;
      _today = selected != null &&
              today?.region.nx == selected.nx &&
              today?.region.ny == selected.ny
          ? today!.withRegionName(selected.fullName)
          : today;
      _weekly = result.weekly;
      _loadMode = result.mode;
      _statusMessage = result.message;
    });
  }

  List<WeatherRecommendation> get _priorityRecommendations {
    final recommendations = List<WeatherRecommendation>.from(
      _today?.recommendations ?? const [],
    )..sort((a, b) => b.priority.compareTo(a.priority));
    return recommendations.where((item) => item.recommended).toList();
  }

  String get _mood {
    final sky = (_today?.current.sky ?? '').toLowerCase();
    if (sky.contains('비')) return 'rain';
    if (sky.contains('눈')) return 'snow';
    if (sky.contains('흐림') || sky.contains('구름')) return 'cloudy';
    return 'clear';
  }

  String get _dateLabel {
    const weekdays = ['월', '화', '수', '목', '금', '토', '일'];
    final now = DateTime.now();
    return '${now.month}월 ${now.day}일 ${weekdays[now.weekday - 1]}요일';
  }

  @override
  Widget build(BuildContext context) {
    final today = _today;
    final weekly = _weekly;
    final hasWeather = today != null && weekly != null;
    final serverFeaturesAvailable = _loadMode == WeatherLoadMode.server;
    final settingsPanel = AbsorbPointer(
        absorbing: !_initialized,
        child: SettingsScreen(
          embedded: true,
          onRefresh: _loadData,
          initialSettings: _settings,
          onSettingsChanged: _handleSettingsChanged,
          location: _location,
          regionName: _today?.region.name,
          onLocate: () => _refresh(requestPermission: true),
          onOpenLocationSettings: _openDeviceLocationSettings,
          loadRegionCatalog: _loadRegionCatalog,
          manualRegionName: _manualRegion?.fullName,
        ));

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: IndexedStack(
            index: _selectedIndex,
            children: hasWeather
                ? [
                    TodayTab(
                      today: today,
                      recommendations: _priorityRecommendations,
                      serverFeaturesAvailable: serverFeaturesAvailable,
                      onRefresh: _loadData,
                      onDetail: _openRecommendationDetail,
                    ),
                    DetailTab(
                      today: today,
                      recommendations: _priorityRecommendations,
                      serverFeaturesAvailable: serverFeaturesAvailable,
                      onRefresh: _loadData,
                      focusTopic: _detailFocusTopic,
                      focusLifestyleType: _detailFocusLifestyleType,
                      focusSource: _detailFocusSource,
                      focusRequestId: _detailFocusRequestId,
                    ),
                    MainTab(
                      today: today,
                      dateLabel: _dateLabel,
                      mood: _mood,
                      serverFeaturesAvailable: serverFeaturesAvailable,
                      onRefresh: _loadData,
                      onDetail: _openLifestyleDetail,
                    ),
                    WeekTab(
                      weekly: weekly,
                      serverFeaturesAvailable: serverFeaturesAvailable,
                      onRefresh: _loadData,
                    ),
                    settingsPanel,
                  ]
                : [
                    _statusView('today-tab'),
                    _statusView('detail-tab'),
                    _statusView('main-tab'),
                    _statusView('week-tab'),
                    settingsPanel,
                  ],
          ),
        ),
        bottomNavigationBar: NavigationBar(
          key: const ValueKey('main-bottom-navigation'),
          selectedIndex: _selectedIndex,
          height: 74,
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          indicatorColor: WeatherCareTheme.primarySoft,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          onDestinationSelected: (index) {
            if (_selectedIndex == index) return;
            setState(() => _selectedIndex = index);
          },
          destinations: const [
            NavigationDestination(
              tooltip: 'Check List, 간단한 타임라인',
              icon: Icon(
                Icons.work_outline_rounded,
                color: WeatherCareTheme.textSecondary,
              ),
              selectedIcon: Icon(
                Icons.work_rounded,
                color: WeatherCareTheme.textSecondary,
              ),
              label: 'Today',
            ),
            NavigationDestination(
              tooltip: '상세 날씨',
              icon: Icon(
                Icons.query_stats_outlined,
                color: WeatherCareTheme.textSecondary,
              ),
              selectedIcon: Icon(
                Icons.query_stats_rounded,
                color: WeatherCareTheme.textSecondary,
              ),
              label: 'Detail',
            ),
            NavigationDestination(
              tooltip: '메인',
              icon: Icon(
                Icons.home_outlined,
                color: WeatherCareTheme.textSecondary,
              ),
              selectedIcon: Icon(
                Icons.home_rounded,
                color: WeatherCareTheme.textSecondary,
              ),
              label: 'Main',
            ),
            NavigationDestination(
              tooltip: '날짜별 날씨',
              icon: Icon(
                Icons.calendar_month_outlined,
                color: WeatherCareTheme.textSecondary,
              ),
              selectedIcon: Icon(
                Icons.calendar_month_rounded,
                color: WeatherCareTheme.textSecondary,
              ),
              label: 'Week',
            ),
            NavigationDestination(
              tooltip: '설정',
              icon: Icon(
                Icons.tune_outlined,
                color: WeatherCareTheme.textSecondary,
              ),
              selectedIcon: Icon(
                Icons.tune_rounded,
                color: WeatherCareTheme.textSecondary,
              ),
              label: 'Setting',
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusView(String viewKey) {
    return WeatherStatusView(
      viewKey: viewKey,
      loading: _loadMode == null,
      offline: _loadMode == WeatherLoadMode.offline,
      title: _loadMode != null && _weatherGrid == null ? '기준 위치를 확인해주세요' : null,
      message: _statusMessage,
      onRetry: _loadData,
    );
  }

  void _openRecommendationDetail(RecommendationType type) {
    setState(() {
      _detailFocusTopic = null;
      _detailFocusLifestyleType =
          detailLifestyleTypeForRecommendationType(type);
      _detailFocusSource = DetailFocusSource.selection;
      _detailFocusRequestId += 1;
      _selectedIndex = 1;
    });
  }

  void _openLifestyleDetail(LifestyleMessageType type) {
    setState(() {
      _detailFocusTopic = null;
      _detailFocusLifestyleType = type;
      _detailFocusSource = DetailFocusSource.selection;
      _detailFocusRequestId += 1;
      _selectedIndex = 1;
    });
  }

  Future<void> _handleSettingsChanged(AppSettings updated) {
    final revision = ++_settingsRevision;
    final locationChanged = _settings.locationMode != updated.locationMode ||
        _settings.currentRegionId != updated.currentRegionId ||
        _settings.manualRegionKey != updated.manualRegionKey;
    setState(() {
      _settings = updated;
      if (locationChanged) {
        _locationRevision++;
        _coordinates = null;
        _today = null;
        _weekly = null;
        _loadMode = null;
        _notificationRegistration?.invalidateLocation();
      }
    });
    if (locationChanged) {
      unawaited(_refresh(
          requestPermission: updated.locationMode == 'GPS', supersede: true));
    }
    _settingsSaveQueue = _settingsSaveQueue
        .then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    )
        .then((_) async {
      await _settingsRepository.save(updated);
      await _saveRemoteSettings(updated);
      if (mounted && revision == _settingsRevision && !locationChanged) {
        await _loadData();
      }
    });
    return _settingsSaveQueue;
  }

  Future<void> _saveRemoteSettings(AppSettings settings) async {
    try {
      await _settingsSync?.save(settings);
    } catch (_) {/* Local settings remain valid. */}
  }

  Future<RegionCatalog> _loadRegionCatalog() async =>
      _regionCatalog ??= await RegionCatalog.load();

  Future<void> _openDeviceLocationSettings() async {
    final opened = _location.state == LocationState.serviceDisabled
        ? await _locationService.openLocationSettings()
        : await _locationService.openAppSettings();
    if (!mounted || opened) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('설정을 열지 못했어요. 기기 설정에서 위치 권한과 위치 기능을 확인해주세요.')));
  }
}
