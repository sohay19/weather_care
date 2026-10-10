import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';

import '../../models/app_settings.dart';
import '../../models/briefing_time.dart';
import '../../models/lifestyle_message.dart';
import '../../models/recommendation.dart';
import '../../models/weather.dart';
import '../../models/home_widget_snapshot.dart';
import '../../services/api_client.dart';
import '../../services/ad_removal_service.dart';
import '../../services/server_data_access.dart';
import '../../services/app_config.dart';
import '../../services/app_settings_repository.dart';
import '../../services/kma_grid.dart';
import '../../services/installation_identity.dart';
import '../../services/notification_registration_service.dart';
import '../../services/notification_destination.dart';
import '../../services/settings_sync_service.dart';
import '../../services/settings_save_controller.dart';
import '../../services/notification_permission_service.dart';
import '../../services/native_ad_unit_config.dart';
import '../../services/permission_onboarding_store.dart';
import '../../services/weather_service.dart';
import '../../services/current_location_service.dart';
import '../../services/gps_region_name_service.dart';
import '../../services/home_widget_service.dart';
import '../../services/region_catalog.dart';
import '../../models/selectable_region.dart';
import '../../theme/weather_theme.dart';
import '../../utils/korea_date.dart';
import '../settings/settings_screen.dart';
import '../ads/consent_aware_native_ad_card.dart';
import 'weather_labels.dart';
import 'weather_data_phase.dart';
import 'tabs/detail_tab.dart';
import 'tabs/main_tab.dart';
import 'tabs/today_tab.dart';
import 'tabs/week_tab.dart';
import 'widgets/server_connection_failure_dialog.dart';
import 'widgets/permission_onboarding_dialog.dart';
import 'widgets/weather_status_view.dart';

class HomeScreen extends StatefulWidget {
  final int initialIndex;
  final NotificationTopic? initialNotificationTopic;
  final CurrentLocationService locationService;
  final GpsRegionNameService gpsRegionNameService;
  final WeatherService? weatherService;
  final SettingsSyncService? settingsSync;
  final NotificationRegistrationService? notificationRegistration;
  final RegionCatalog? regionCatalog;
  final NotificationPermissionService? notificationPermission;
  final ServerDataAccess? serverDataAccess;
  final PermissionOnboardingStore permissionOnboardingStore;
  final HomeWidgetService homeWidgetService;
  final AdRemovalService? adRemoval;
  final VoidCallback? onHomeReady;
  final DateTime Function()? now;

  const HomeScreen({
    super.key,
    this.initialIndex = 2,
    this.initialNotificationTopic,
    this.locationService = const CurrentLocationService(),
    this.gpsRegionNameService = const PlatformGpsRegionNameService(),
    this.weatherService,
    this.settingsSync,
    this.notificationRegistration,
    this.regionCatalog,
    this.notificationPermission,
    this.serverDataAccess,
    this.permissionOnboardingStore = const PermissionOnboardingStore(),
    this.homeWidgetService = const HomeWidgetService(),
    this.adRemoval,
    this.onHomeReady,
    this.now,
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
  ServerDataAccess? _serverDataAccess;
  CurrentLocationService get _locationService => widget.locationService;
  DeviceCoordinates? _coordinates;
  String? _gpsRegionName;
  LocationResult _location = const LocationResult(LocationState.idle);
  Future<void>? _refreshFuture;
  bool _refreshAgain = false;
  bool _notifyRefreshFailure = false;
  bool _requestPermission = false;
  bool _forceLocationRefresh = false;
  bool _initialized = false;
  bool _leftApp = false;
  bool _registrationInitialized = false;
  RegionCatalog? _regionCatalog;
  ForecastRegion? get _manualRegion =>
      _regionCatalog?.find(_settings.manualRegionKey);
  int _locationRevision = 0;
  SettingsSaveController? _settingsSave;
  late final NotificationPermissionService _notificationPermission =
      widget.notificationPermission ?? NotificationPermissionService();
  NotificationPermissionState _permission =
      NotificationPermissionState.checking;
  Future<void>? _permissionFuture;
  bool _permissionRefreshAgain = false;
  bool _permissionSyncRequested = false;
  TodayWeatherResponse? _today;
  WeeklyWeatherResponse? _weekly;
  ComparisonResponse? _yesterdayComparison;
  WeatherLoadMode? _loadMode;
  late int _selectedIndex;
  late bool _todayAdvertisementActivated;
  late bool _mainAdvertisementActivated;
  late bool _weekAdvertisementActivated;
  late NotificationTopic? _detailFocusTopic;
  LifestyleMessageType? _detailFocusLifestyleType;
  DetailFocusSource _detailFocusSource = DetailFocusSource.notification;
  int _detailFocusRequestId = 0;
  bool _loading = false;
  bool _todayRefreshing = false;
  bool _weeklyLoading = false;
  bool _todayRetrying = false;
  bool _weeklyRetrying = false;
  bool _mainDetailsLoading = false;
  bool _todayRequestFailed = false;
  bool _weeklyRequestFailed = false;
  bool _comparisonLoading = false;
  bool _homeReadyReported = false;
  String _statusMessage = '운영 서버 연결 상태를 확인하고 있습니다.';
  String? _widgetServerUrl;
  Timer? _weatherHourTimer;
  String? _lastCompletedWeatherHour;

  DateTime _now() {
    final today = _today;
    final weekly = _weekly;
    return responseNow(
      (widget.now ?? DateTime.now)(),
      generatedAt: today?.generatedAt ?? weekly?.generatedAt,
      receivedAt: today?.receivedAt ?? weekly?.receivedAt,
    );
  }

  WeatherDataPhase get _todayPhase => _todayRetrying
      ? WeatherDataPhase.loading
      : _todayRequestFailed
          ? WeatherDataPhase.failed
          : _mainDetailsLoading || _todayRefreshing || _refreshFuture != null
              ? WeatherDataPhase.loading
              : WeatherDataPhase.ready;

  WeatherDataPhase get _weeklyPhase => _weeklyRetrying
      ? WeatherDataPhase.loading
      : _weeklyRequestFailed
          ? WeatherDataPhase.failed
          : _weeklyLoading || _refreshFuture != null
              ? WeatherDataPhase.loading
              : WeatherDataPhase.ready;

  void _publishHomeWidget() {
    final today = _today;
    if (today == null ||
        _refreshFuture != null ||
        _mainDetailsLoading ||
        _todayRefreshing ||
        _weeklyLoading ||
        _todayRequestFailed) {
      return;
    }
    final snapshot = HomeWidgetSnapshot.fromWeather(
      today: today,
      weekly: _weeklyRequestFailed ? null : _weekly,
    );
    unawaited(widget.homeWidgetService.publish(
      snapshot,
      refreshUrl: _homeWidgetRefreshUrl(),
      gpsEnabled: _settings.locationMode == 'GPS',
    ));
  }

  String? _homeWidgetRefreshUrl() {
    final baseUrl = _widgetServerUrl;
    final grid = _weatherGrid;
    if (baseUrl == null || grid == null) return null;
    final coordinates = _settings.locationMode == 'GPS' &&
            _location.canUseLocalAnalysis &&
            _serverDataAccess?.paused == false
        ? _coordinates
        : null;
    final regionCode =
        _settings.locationMode == 'GPS' ? null : _manualRegion?.code;
    final regionName = _settings.locationMode == 'GPS'
        ? _gpsRegionName
        : _manualRegion?.fullName;
    return Uri.parse(baseUrl)
        .resolve('/api/v1/weather/widget')
        .replace(queryParameters: {
      'nx': '${grid.nx}',
      'ny': '${grid.ny}',
      'widgetSettings': _homeWidgetSettingsKey(),
      if (coordinates != null) ...{
        'latitude': '${coordinates.latitude}',
        'longitude': '${coordinates.longitude}',
      },
      if (regionCode != null && regionCode.isNotEmpty) 'regionCode': regionCode,
      if (regionName != null && regionName.trim().isNotEmpty)
        'regionName': regionName.trim(),
    }).toString();
  }

  String _homeWidgetSettingsKey() => 'u${_settings.umbrellaEnabled ? 1 : 0}'
      'p${_settings.parasolEnabled ? 1 : 0}'
      's${_settings.heavySnowEnabled ? 1 : 0}'
      'o${_settings.outerwearEnabled ? 1 : 0}'
      'm${_settings.maskEnabled ? 1 : 0}'
      'w${_settings.waterEnabled ? 1 : 0}'
      'c${_settings.sunscreenEnabled ? 1 : 0}';

  void _clearHomeWidget() => unawaited(widget.homeWidgetService.clear());

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
    widget.adRemoval?.addListener(_onAdRemovalChanged);
    _settings = AppSettings.fallback('initializing-installation');
    _selectedIndex = widget.initialIndex < 0
        ? 0
        : widget.initialIndex > 4
            ? 4
            : widget.initialIndex;
    _todayAdvertisementActivated = _selectedIndex == 0;
    _mainAdvertisementActivated = _selectedIndex == 2;
    _weekAdvertisementActivated = _selectedIndex == 3;
    _detailFocusTopic = widget.initialNotificationTopic;
    _scheduleWeatherHourRefresh();
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
    _widgetServerUrl = config.serverUrl;
    _settings = savedSettings;
    final access = widget.serverDataAccess ??
        ServerDataAccess(
            api: ApiClient(
                baseUrl: config.serverUrl,
                timeout: const Duration(seconds: 20)),
            legacyInstallationId: installationId);
    _serverDataAccess = access;
    try {
      await access.load();
    } catch (_) {
      access.error = '기기의 본인 확인 정보를 읽지 못했어요.\n서버 전송을 중지했어요.\n앱을 다시 열어주세요.';
    }
    if (!mounted) return;
    access.addListener(_onServerDataChanged);
    if (access.paused) {
      _settings = _settings.copyWith(notificationEnabled: false);
    }
    final client =
        InstallationApiClient(baseUrl: config.serverUrl, access: access);
    _settingsSync = widget.settingsSync ?? SettingsSyncService(client);
    _service = widget.weatherService ?? WeatherService(client);
    _notificationRegistration = widget.notificationRegistration ??
        NotificationRegistrationService(client,
            canRegister: () => !access.paused);
    // A failed remote preferences save must not prevent local GPS or weather.
    _settingsSave = SettingsSaveController(
        saveLocal: _settingsRepository.save,
        saveServer: (settings) async {
          if (access.paused) throw const ServerDataPaused();
          await _settingsSync!.save(settings);
        })
      ..addListener(_onSettingsSaveChanged);
    unawaited(_settingsSave!.save(_settings));
    _initialized = true;
    final permissionsConfirmed =
        await widget.permissionOnboardingStore.isConfirmed();
    if (!mounted) return;
    if (!permissionsConfirmed) {
      final confirmed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const PermissionOnboardingDialog(),
      );
      if (!mounted) return;
      if (confirmed == true) {
        try {
          await widget.permissionOnboardingStore.confirm();
        } catch (_) {
          // Permission requests remain usable even if the guide state cannot persist.
        }
        if (_settings.notificationEnabled) {
          await _readNotificationPermission(request: true, sync: true);
        }
        if (!mounted) return;
        await _refresh(requestPermission: _settings.locationMode == 'GPS');
        return;
      }
    }
    await _loadData();
  }

  @override
  void didUpdateWidget(covariant HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.adRemoval != widget.adRemoval) {
      oldWidget.adRemoval?.removeListener(_onAdRemovalChanged);
      widget.adRemoval?.addListener(_onAdRemovalChanged);
    }
  }

  void _onAdRemovalChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.adRemoval?.removeListener(_onAdRemovalChanged);
    _locationRevision++;
    _settingsSave?.dispose();
    _serverDataAccess?.removeListener(_onServerDataChanged);
    _weatherHourTimer?.cancel();
    if (widget.serverDataAccess == null) _serverDataAccess?.dispose();
    unawaited(_notificationRegistration?.dispose() ?? Future<void>.value());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.inactive) {
      _leftApp = true;
    }
    if (state == AppLifecycleState.resumed && _leftApp) {
      _leftApp = false;
      if (_initialized) unawaited(_readNotificationPermission(sync: true));
      final crossedWeatherHour =
          _lastCompletedWeatherHour != koreaHourKey(_now());
      if (_initialized &&
          (_settings.locationMode == 'GPS' || crossedWeatherHour)) {
        unawaited(_refresh(
            supersede: true,
            forceLocationRefresh: _settings.locationMode == 'GPS'));
      }
    }
  }

  void _scheduleWeatherHourRefresh() {
    _weatherHourTimer?.cancel();
    _weatherHourTimer = Timer(untilNextKoreaHour(_now()), () {
      _scheduleWeatherHourRefresh();
      if (_initialized && mounted) {
        unawaited(_refresh(supersede: true));
      }
    });
  }

  Future<void> _loadData() {
    unawaited(_readNotificationPermission());
    return _refresh();
  }

  Future<void> _refreshFromTab() {
    unawaited(_readNotificationPermission());
    return _refresh(notifyFailure: true, forceLocationRefresh: true);
  }

  Future<void> _refreshFromSettings() {
    unawaited(_readNotificationPermission());
    return _refresh(supersede: true, forceLocationRefresh: true);
  }

  Future<void> _refresh(
      {bool requestPermission = false,
      bool supersede = false,
      bool notifyFailure = false,
      bool forceLocationRefresh = false}) {
    if (_service == null) return Future<void>.value();
    _notifyRefreshFailure |= notifyFailure;
    if (_refreshFuture != null) {
      if (supersede || notifyFailure) {
        _refreshAgain = true;
        _requestPermission |= requestPermission;
        _forceLocationRefresh |= forceLocationRefresh;
      }
      return _refreshFuture!;
    }
    _requestPermission |= requestPermission;
    _forceLocationRefresh |= forceLocationRefresh;
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
        final forceLocationRefresh = _forceLocationRefresh;
        final notifyFailure = _notifyRefreshFailure;
        Future<String?>? gpsRegionNameFuture;
        _requestPermission = false;
        _forceLocationRefresh = false;
        _notifyRefreshFailure = false;
        if (_settings.locationMode == 'GPS') {
          setState(() {
            _location = const LocationResult(LocationState.checking);
            if (_today == null) {
              _loadMode = null;
              _statusMessage = _location.message;
            }
          });
          var result = await _locationService.locate(
            requestPermission: ask,
            forceRefresh: forceLocationRefresh,
          );
          if (_today == null && result.state == LocationState.timedOut) {
            result = await _locationService.locate(forceRefresh: true);
          }
          if (!mounted) return;
          if (revision != _locationRevision) continue;
          setState(() {
            _location = result;
            _coordinates = result.coordinates;
            _gpsRegionName = null;
          });
          if (result.canUseLocalAnalysis) {
            gpsRegionNameFuture = _resolveGpsRegionName(result.coordinates!);
          }
        } else {
          _coordinates = null;
          _gpsRegionName = null;
          _location = const LocationResult(LocationState.idle);
        }
        final grid = _weatherGrid;
        if (grid == null) {
          setState(() {
            _today = null;
            _weekly = null;
            _loadMode = WeatherLoadMode.unavailable;
            _statusMessage = _settings.locationMode == 'GPS'
                ? '${_location.message}.\n위치 권한을 확인하거나 지역을 직접 선택해주세요.'
                : '저장된 지역을 확인할 수 없어요.\nSetting에서 위치를 다시 선택해주세요.';
          });
          _clearHomeWidget();
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
        if (registration != null && !(_serverDataAccess?.paused ?? true)) {
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
        await _fetchWeather(
          revision,
          grid,
          preciseCoordinates,
          gpsRegionNameFuture: gpsRegionNameFuture,
          regionCode:
              _settings.locationMode == 'GPS' ? null : _manualRegion?.code,
          regionName:
              _settings.locationMode == 'GPS' ? null : _manualRegion?.fullName,
          notifyFailure: notifyFailure,
        );
        if (gpsRegionNameFuture != null) {
          await _applyGpsRegionName(
            revision,
            grid,
            gpsRegionNameFuture,
          );
        }
      } while (mounted && _refreshAgain);
    } finally {
      _refreshFuture = null;
      if (mounted) {
        setState(() {});
        _publishHomeWidget();
      }
    }
  }

  Future<String?> _resolveGpsRegionName(DeviceCoordinates coordinates) async {
    try {
      return await widget.gpsRegionNameService.resolve(coordinates);
    } catch (_) {
      return null;
    }
  }

  Future<void> _applyGpsRegionName(
    int revision,
    KmaGrid expectedGrid,
    Future<String?> regionNameFuture,
  ) async {
    final name = await regionNameFuture;
    if (!mounted ||
        revision != _locationRevision ||
        _settings.locationMode != 'GPS') {
      return;
    }
    final today = _today;
    if (today == null ||
        today.region.nx != expectedGrid.nx ||
        today.region.ny != expectedGrid.ny) {
      return;
    }
    setState(() {
      _gpsRegionName = name;
      _today = today.withRegionName(name ?? '현재 위치');
    });
    _publishHomeWidget();
  }

  Future<void> _fetchWeather(
    int revision,
    KmaGrid grid,
    DeviceCoordinates? coordinates, {
    Future<String?>? gpsRegionNameFuture,
    String? regionCode,
    String? regionName,
    bool notifyFailure = false,
  }) async {
    final service = _service;
    if (service == null || _loading) return;

    final hadWeatherBeforeRefresh = _today != null || _weekly != null;
    _loading = true;
    _todayRefreshing = true;
    _weeklyLoading = true;
    setState(() {
      _yesterdayComparison = null;
      _comparisonLoading = true;
      _todayRequestFailed = false;
      _weeklyRequestFailed = false;
      if (_today == null) {
        _loadMode = null;
        _statusMessage = '운영 서버 연결 상태를 확인하고 있습니다.';
      }
    });
    try {
      while (mounted) {
        setState(() => _comparisonLoading = true);
        final comparisonFuture =
            _fetchYesterdayComparison(service, revision, grid);
        var mismatchedToday = false;
        var fullTodayApplied = false;
        if (_today == null) {
          unawaited(service
              .fetchMainWeather(
            nx: grid.nx,
            ny: grid.ny,
            regionCode: regionCode,
            regionName: regionName,
            coordinates: coordinates,
            regionNameFuture: gpsRegionNameFuture,
          )
              .then(
            (preview) {
              if (preview != null && !fullTodayApplied) {
                _applyServerMainPreview(revision, grid, preview);
              }
            },
          ));
        }
        final serverResult = await service.fetchServerWeather(
          installationId: _settings.installationId,
          nx: grid.nx,
          ny: grid.ny,
          coordinates: coordinates,
          regionCode: regionCode,
          regionName: regionName,
          regionNameFuture: gpsRegionNameFuture,
          onToday: (today) {
            fullTodayApplied = true;
            mismatchedToday = !_applyServerToday(revision, grid, today);
          },
          onWeekly: (weekly) => _applyServerWeekly(
            revision,
            weekly,
          ),
        );
        await comparisonFuture;

        if (!mounted || revision != _locationRevision) return;
        if (serverResult.hasAnyWeather) {
          if (serverResult.today case final today?) {
            fullTodayApplied = true;
            mismatchedToday = !_applyServerToday(revision, grid, today);
          }
          if (serverResult.weekly case final weekly?) {
            _applyServerWeekly(revision, weekly);
          }
        }
        if (mismatchedToday) {
          _rejectUnexpectedGrid();
          return;
        }
        if (serverResult.today != null) {
          if (serverResult.hasWeather) {
            _lastCompletedWeatherHour = koreaHourKey(_now());
          }
          if (serverResult.weekly == null) {
            setState(() {
              _weeklyRequestFailed = true;
              _statusMessage = 'Main 날씨는 표시했지만 주간 자료를 받지 못했어요.\n다시 확인해주세요.';
            });
            if (notifyFailure) {
              final action = await showDialog<ServerFailureAction>(
                context: context,
                barrierDismissible: true,
                builder: (_) => const ServerConnectionFailureDialog(
                  refreshFailure: true,
                  partialFailure: true,
                ),
              );
              if (!mounted || revision != _locationRevision) return;
              if (action == ServerFailureAction.retryServer) continue;
            }
          }
          return;
        }

        final canKeepExistingWeather = notifyFailure && hadWeatherBeforeRefresh;
        final action = await showDialog<ServerFailureAction>(
          context: context,
          barrierDismissible: canKeepExistingWeather,
          builder: (_) => ServerConnectionFailureDialog(
            refreshFailure: canKeepExistingWeather,
            partialFailure: serverResult.hasAnyWeather,
          ),
        );
        if (!mounted || revision != _locationRevision) return;

        if (action == ServerFailureAction.retryServer) {
          continue;
        }

        if (canKeepExistingWeather) {
          setState(() {
            _todayRequestFailed = true;
            _weeklyRequestFailed = serverResult.weekly == null;
            _statusMessage = serverResult.message;
          });
          return;
        }

        _applyResult(serverResult, grid);
        return;
      }
    } finally {
      _loading = false;
      if (mounted) {
        setState(() {
          _todayRefreshing = false;
          _weeklyLoading = false;
        });
      }
    }
  }

  Future<void> _fetchYesterdayComparison(
    WeatherService service,
    int revision,
    KmaGrid grid,
  ) async {
    final comparison = await service.fetchYesterdayComparison(
      installationId: _settings.installationId,
      nx: grid.nx,
      ny: grid.ny,
    );
    if (!mounted || revision != _locationRevision) return;
    final currentGrid = _weatherGrid;
    if (currentGrid?.nx != grid.nx || currentGrid?.ny != grid.ny) return;
    setState(() {
      _yesterdayComparison = comparison;
      _comparisonLoading = false;
    });
  }

  Future<void> _retryTodayData() async {
    final service = _service;
    final grid = _weatherGrid;
    if (service == null || grid == null || _todayRetrying) return;
    final revision = _locationRevision;
    setState(() => _todayRetrying = true);
    try {
      final today = await service.fetchTodayWeather(
        installationId: _settings.installationId,
        nx: grid.nx,
        ny: grid.ny,
        coordinates:
            _settings.locationMode == 'GPS' && _location.canUseLocalAnalysis
                ? _coordinates
                : null,
        regionCode:
            _settings.locationMode == 'GPS' ? null : _manualRegion?.code,
        regionName: _settings.locationMode == 'GPS'
            ? _gpsRegionName
            : _manualRegion?.fullName,
      );
      if (!_applyServerToday(revision, grid, today)) {
        if (mounted && revision == _locationRevision) _rejectUnexpectedGrid();
      }
    } catch (_) {
      if (mounted && revision == _locationRevision) {
        setState(() {
          _todayRequestFailed = true;
          _statusMessage = '오늘 자료를 다시 받지 못했어요.';
        });
      }
    } finally {
      if (mounted && revision == _locationRevision) {
        setState(() => _todayRetrying = false);
      }
    }
  }

  Future<void> _retryWeeklyData() async {
    final service = _service;
    final grid = _weatherGrid;
    if (service == null || grid == null || _weeklyRetrying) return;
    final revision = _locationRevision;
    setState(() => _weeklyRetrying = true);
    try {
      final weekly = await service.fetchWeeklyWeather(
        installationId: _settings.installationId,
        nx: grid.nx,
        ny: grid.ny,
        coordinates:
            _settings.locationMode == 'GPS' && _location.canUseLocalAnalysis
                ? _coordinates
                : null,
        regionCode:
            _settings.locationMode == 'GPS' ? null : _manualRegion?.code,
        regionName: _settings.locationMode == 'GPS'
            ? _gpsRegionName
            : _manualRegion?.fullName,
      );
      _applyServerWeekly(revision, weekly);
    } catch (_) {
      if (mounted && revision == _locationRevision) {
        setState(() {
          _weeklyRequestFailed = true;
          _statusMessage = '주간 자료를 다시 받지 못했어요.';
        });
      }
    } finally {
      if (mounted && revision == _locationRevision) {
        setState(() => _weeklyRetrying = false);
      }
    }
  }

  Future<void> _retryYesterdayComparison() async {
    final service = _service;
    final grid = _weatherGrid;
    if (service == null || grid == null || _comparisonLoading) return;
    final revision = _locationRevision;
    setState(() => _comparisonLoading = true);
    await _fetchYesterdayComparison(service, revision, grid);
  }

  bool _applyServerToday(
    int revision,
    KmaGrid expectedGrid,
    TodayWeatherResponse today,
  ) {
    if (!mounted || revision != _locationRevision) return false;
    final received = today.region;
    if (received.nx != expectedGrid.nx || received.ny != expectedGrid.ny) {
      return false;
    }
    final selected = _settings.locationMode == 'MANUAL' ? _manualRegion : null;
    setState(() {
      _today = selected != null &&
              today.region.nx == selected.nx &&
              today.region.ny == selected.ny
          ? today.withRegionName(selected.fullName)
          : _settings.locationMode == 'GPS'
              ? today.withRegionName(_gpsRegionName ?? '현재 위치')
              : today;
      _loadMode = WeatherLoadMode.server;
      _mainDetailsLoading = false;
      _todayRequestFailed = false;
      _statusMessage = 'Main 날씨를 먼저 표시했어요.\n주간 자료는 계속 불러오고 있어요.';
    });
    _scheduleWeatherHourRefresh();
    _publishHomeWidget();
    return true;
  }

  bool _applyServerMainPreview(
    int revision,
    KmaGrid expectedGrid,
    TodayWeatherResponse preview,
  ) {
    if (!mounted || revision != _locationRevision || _today != null) {
      return false;
    }
    final received = preview.region;
    if (received.nx != expectedGrid.nx || received.ny != expectedGrid.ny) {
      return false;
    }
    final selected = _settings.locationMode == 'MANUAL' ? _manualRegion : null;
    setState(() {
      _today = selected != null &&
              preview.region.nx == selected.nx &&
              preview.region.ny == selected.ny
          ? preview.withRegionName(selected.fullName)
          : _settings.locationMode == 'GPS'
              ? preview.withRegionName(_gpsRegionName ?? '현재 위치')
              : preview;
      _loadMode = WeatherLoadMode.server;
      _mainDetailsLoading = true;
      _statusMessage = 'Main 핵심 날씨를 먼저 표시했어요.\n상세 자료를 계속 불러오고 있어요.';
    });
    _scheduleWeatherHourRefresh();
    return true;
  }

  void _rejectUnexpectedGrid() {
    setState(() {
      _today = null;
      _weekly = null;
      _mainDetailsLoading = false;
      _loadMode = WeatherLoadMode.unavailable;
      _statusMessage = '선택한 지역과 다른 날씨 자료를 받아 표시하지 않았어요.\n새로고침해 다시 확인해주세요.';
    });
    _clearHomeWidget();
  }

  void _applyServerWeekly(
    int revision,
    WeeklyWeatherResponse weekly,
  ) {
    if (!mounted || revision != _locationRevision) return;
    setState(() {
      _weekly = weekly;
      _weeklyLoading = false;
      _loadMode = WeatherLoadMode.server;
      _statusMessage = '운영 서버 연결';
      _weeklyRequestFailed = false;
    });
    _scheduleWeatherHourRefresh();
    _publishHomeWidget();
  }

  void _applyResult(WeatherLoadResult result, KmaGrid expectedGrid) {
    setState(() {
      final received = result.today?.region;
      if (received != null &&
          (received.nx != expectedGrid.nx || received.ny != expectedGrid.ny)) {
        _today = null;
        _weekly = null;
        _loadMode = WeatherLoadMode.unavailable;
        _statusMessage = '선택한 지역과 다른 날씨 자료를 받아 표시하지 않았어요.\n새로고침해 다시 확인해주세요.';
        return;
      }
      final selected =
          _settings.locationMode == 'MANUAL' ? _manualRegion : null;
      final today = result.today;
      if (selected != null &&
          today?.region.nx == selected.nx &&
          today?.region.ny == selected.ny) {
        _today = today!.withRegionName(selected.fullName);
      } else if (_settings.locationMode == 'GPS' && today != null) {
        _today = today.withRegionName(_gpsRegionName ?? '현재 위치');
      } else {
        _today = today;
      }
      _weekly = result.weekly;
      _mainDetailsLoading = false;
      _loadMode = result.mode;
      _todayRequestFailed = result.today == null;
      _weeklyRequestFailed = result.weekly == null;
      _statusMessage = result.message;
    });
    _scheduleWeatherHourRefresh();
    if (_today == null) {
      _clearHomeWidget();
    } else {
      _publishHomeWidget();
    }
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

  String get _dateLabel => weatherRefreshLabel(_today?.generatedAt);

  TodayWeatherResponse _loadingToday(TodayWeatherResponse today) =>
      TodayWeatherResponse(
        dataSource: today.dataSource,
        region: today.region,
        brief: '',
        current: const CurrentWeather(temperature: null),
        recommendations: const [],
        lifestyleMessages: const [],
        timeline: const [],
        hourly: const [],
      );

  @override
  Widget build(BuildContext context) {
    final today = _today;
    final weekly = _weekly;
    final todayPhase = _todayPhase;
    final weeklyPhase = _weeklyPhase;
    final visibleToday = today != null && todayPhase == WeatherDataPhase.loading
        ? _loadingToday(today)
        : today;
    final visibleWeekly =
        weekly != null && weeklyPhase == WeatherDataPhase.loading
            ? const WeeklyWeatherResponse(days: [])
            : weekly;
    final serverFeaturesAvailable = _loadMode == WeatherLoadMode.server;
    final homeReady =
        today != null || (_initialized && !_loading && _loadMode != null);
    if (!_homeReadyReported && homeReady) {
      _homeReadyReported = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onHomeReady?.call();
      });
    }
    final settingsPanel = AbsorbPointer(
        absorbing: !_initialized,
        child: SettingsScreen(
          embedded: true,
          onRefresh: _refreshFromSettings,
          initialSettings: _settings,
          onSettingsChanged: _handleSettingsChanged,
          location: _location,
          regionName: _today?.region.name,
          onLocate: () => _refresh(
            requestPermission: true,
            supersede: true,
            forceLocationRefresh: true,
          ),
          onOpenLocationSettings: _openDeviceLocationSettings,
          loadRegionCatalog: _loadRegionCatalog,
          manualRegionName: _manualRegion?.fullName,
          saveState: _settingsSave?.state ?? SettingsSaveState.checking,
          onRetrySave: _retrySettingsSave,
          notificationPermission: _permission,
          onRequestNotificationPermission: () =>
              _readNotificationPermission(request: true, sync: true),
          onRefreshNotificationPermission: () =>
              _readNotificationPermission(sync: true),
          onOpenNotificationSettings: _openNotificationSettings,
          serverDataAccess: _serverDataAccess,
          onDeleteServerData: _deleteServerData,
          onResumeServerData: _resumeServerData,
          adRemoval: widget.adRemoval,
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
            children: [
              today == null
                  ? _statusView('today-tab')
                  : TodayTab(
                      today: visibleToday!,
                      dataPhase: todayPhase,
                      onRefresh: _refreshFromTab,
                      onRetryData: _retryTodayData,
                      retrying: _todayRetrying,
                      advertisement: _todayAdvertisementActivated &&
                              !(widget.adRemoval?.isOwned ?? false)
                          ? ConsentAwareNativeAdCard(
                              placement: NativeAdPlacement.today,
                              adRemoval: widget.adRemoval,
                            )
                          : null,
                    ),
              today == null
                  ? _statusView('detail-tab')
                  : DetailTab(
                      today: visibleToday!,
                      dataPhase: todayPhase,
                      recommendations: _priorityRecommendations,
                      serverFeaturesAvailable: serverFeaturesAvailable,
                      onRefresh: _refreshFromTab,
                      onRetryData: _retryTodayData,
                      retrying: _todayRetrying,
                      focusTopic: _detailFocusTopic,
                      focusLifestyleType: _detailFocusLifestyleType,
                      focusSource: _detailFocusSource,
                      focusRequestId: _detailFocusRequestId,
                    ),
              today == null
                  ? _statusView('main-tab')
                  : MainTab(
                      today: visibleToday!,
                      dataPhase: todayPhase,
                      dateLabel: _dateLabel,
                      mood: todayPhase == WeatherDataPhase.loading
                          ? 'clear'
                          : _mood,
                      serverFeaturesAvailable: serverFeaturesAvailable,
                      detailsLoading: todayPhase == WeatherDataPhase.loading,
                      yesterdayComparison: _yesterdayComparison,
                      comparisonLoading: _comparisonLoading ||
                          todayPhase == WeatherDataPhase.loading,
                      onRefresh: _refreshFromTab,
                      onRetryData: _retryTodayData,
                      onRetryComparison: _retryYesterdayComparison,
                      retryingData: _todayRetrying,
                      onDetail: _openRecommendationDetail,
                      advertisement: _mainAdvertisementActivated &&
                              !(widget.adRemoval?.isOwned ?? false)
                          ? ConsentAwareNativeAdCard(
                              placement: NativeAdPlacement.main,
                              adRemoval: widget.adRemoval,
                            )
                          : null,
                    ),
              weekly == null
                  ? _statusView(
                      'week-tab',
                      loading: _weeklyLoading ||
                          _weeklyRetrying ||
                          _loadMode == null,
                      title: _weeklyLoading || _weeklyRetrying
                          ? '주간 자료를 불러오고 있어요'
                          : null,
                      message: _weeklyLoading || _weeklyRetrying
                          ? '주간 예보와 지난 날짜 자료가 도착하면 화면을 바로 업데이트해요.'
                          : null,
                    )
                  : WeekTab(
                      weekly: visibleWeekly!,
                      dataPhase: weeklyPhase,
                      serverFeaturesAvailable: serverFeaturesAvailable,
                      onRefresh: _refreshFromTab,
                      onRetryData: _retryWeeklyData,
                      retrying: _weeklyRetrying,
                      now: widget.now,
                      fallbackGeneratedAt: today?.generatedAt,
                      fallbackReceivedAt: today?.receivedAt,
                      advertisement: _weekAdvertisementActivated &&
                              !(widget.adRemoval?.isOwned ?? false)
                          ? ConsentAwareNativeAdCard(
                              placement: NativeAdPlacement.week,
                              size: NativeAdCardSize.medium,
                              adRemoval: widget.adRemoval,
                            )
                          : null,
                    ),
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
          onDestinationSelected: _selectTab,
          destinations: const [
            NavigationDestination(
              tooltip: '오늘 날씨와 시간별 예보',
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
              tooltip: '항목별 근거와 자료',
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
              tooltip: '날씨, Check List, 간단한 타임라인',
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
              tooltip: '이번 주 날씨',
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

  Widget _statusView(
    String viewKey, {
    bool? loading,
    String? title,
    String? message,
  }) {
    final missingLocation = _loadMode != null && _weatherGrid == null;
    final isLoading = loading ?? (_loadMode == null || _loading);
    final failed = !isLoading && !missingLocation;
    return WeatherStatusView(
      viewKey: viewKey,
      loading: isLoading,
      offline: failed,
      title: missingLocation ? '기준 위치를 확인해주세요' : title,
      message: message ?? _statusMessage,
      onRetry: _refreshFromTab,
      primaryActionLabel: missingLocation && _settings.locationMode == 'GPS'
          ? switch (_location.state) {
              LocationState.deniedForever => '앱 위치 권한 설정 열기',
              LocationState.serviceDisabled => '기기 위치 설정 열기',
              LocationState.denied => '위치 권한 다시 요청',
              _ => '현재 위치 다시 확인',
            }
          : null,
      onPrimaryAction: missingLocation && _settings.locationMode == 'GPS'
          ? _handleLocationAction
          : null,
      secondaryActionLabel: missingLocation ? '지역 직접 선택' : null,
      onSecondaryAction: missingLocation ? _openManualRegionMenu : null,
    );
  }

  Future<void> _handleLocationAction() {
    if (_location.state == LocationState.deniedForever ||
        _location.state == LocationState.serviceDisabled) {
      return _openDeviceLocationSettings();
    }
    return _refresh(requestPermission: true, forceLocationRefresh: true);
  }

  void _openManualRegionMenu() {
    _selectTab(4);
  }

  void _selectTab(int index) {
    if (_selectedIndex == index) return;
    setState(() {
      if (_selectedIndex == 1 &&
          _detailFocusSource == DetailFocusSource.selection) {
        _detailFocusTopic = null;
        _detailFocusLifestyleType = null;
        _detailFocusSource = DetailFocusSource.notification;
      }
      _selectedIndex = index;
      if (index == 0) _todayAdvertisementActivated = true;
      if (index == 2) _mainAdvertisementActivated = true;
      if (index == 3) _weekAdvertisementActivated = true;
    });
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

  Future<void> _handleSettingsChanged(AppSettings updated) {
    if (_serverDataAccess?.paused ?? true) {
      updated = updated.copyWith(notificationEnabled: false);
    }
    final locationChanged = _settings.locationMode != updated.locationMode ||
        _settings.currentRegionId != updated.currentRegionId ||
        _settings.manualRegionKey != updated.manualRegionKey;
    setState(() {
      _settings = updated;
      if (locationChanged) {
        _locationRevision++;
        _coordinates = null;
        _gpsRegionName = null;
        _today = null;
        _weekly = null;
        _mainDetailsLoading = false;
        _loadMode = null;
        _notificationRegistration?.invalidateLocation();
      }
    });
    if (locationChanged) {
      _clearHomeWidget();
      unawaited(_refresh(
          requestPermission: updated.locationMode == 'GPS',
          supersede: true,
          forceLocationRefresh: updated.locationMode == 'GPS'));
    }
    return _saveSettings(updated, refreshWeather: !locationChanged);
  }

  void _onSettingsSaveChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _saveSettings(AppSettings settings,
      {bool refreshWeather = true}) async {
    await _settingsSave?.save(settings);
    if (mounted &&
        identical(settings, _settings) &&
        refreshWeather &&
        _settingsSave?.state == SettingsSaveState.saved) {
      // A weather error dialog must not hold the settings save queue open.
      unawaited(_loadData());
    }
  }

  Future<void> _retrySettingsSave() => _saveSettings(_settings);

  Future<void> _readNotificationPermission(
      {bool request = false, bool sync = false}) {
    // Checking/asking is single-flight; permission dialogs do not trigger GPS.
    _permissionSyncRequested |= sync;
    if (_permissionFuture != null) {
      _permissionRefreshAgain |= sync;
      return _permissionFuture!;
    }
    final future = Future<void>.microtask(() async {
      var ask = request;
      do {
        _permissionRefreshAgain = false;
        if (!mounted) return;
        setState(() => _permission = NotificationPermissionState.checking);
        final result = await _notificationPermission.read(request: ask);
        ask = false;
        if (!mounted) return;
        setState(() => _permission = result);
      } while (_permissionRefreshAgain);
      if (_permissionSyncRequested) _syncNotificationPermission();
      _permissionSyncRequested = false;
    }).whenComplete(() => _permissionFuture = null);
    _permissionFuture = future;
    return future;
  }

  void _syncNotificationPermission() {
    if (_serverDataAccess?.paused ?? true) return;
    final grid = _weatherGrid;
    if (grid == null) return;
    unawaited(_notificationRegistration?.syncInstallation(
            installationId: _settings.installationId,
            nx: grid.nx,
            ny: grid.ny,
            locationMode: _settings.locationMode,
            coordinates:
                _settings.locationMode == 'GPS' && _location.canUseLocalAnalysis
                    ? _coordinates
                    : null) ??
        Future<void>.value());
  }

  Future<void> _openNotificationSettings() async {
    final opened = await _notificationPermission.openSettings();
    if (!mounted || opened) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('설정을 열지 못했어요.\n기기 설정에서 날씨챙겨의 알림을 확인해주세요.')));
  }

  void _onServerDataChanged() {
    if (_serverDataAccess?.paused ?? true) {
      _notificationRegistration?.invalidateLocation();
    }
    if (mounted) setState(() {});
  }

  Future<void> _deleteServerData() async {
    await _serverDataAccess?.deleteData();
    if (!mounted) return;
    if (_serverDataAccess?.mode == ServerDataMode.deleted) {
      setState(() {
        _settings = _settings.copyWith(notificationEnabled: false);
        _locationRevision++;
        _today = null;
        _weekly = null;
      });
      _clearHomeWidget();
      await _settingsSave?.save(_settings);
      if (mounted) unawaited(_refresh(supersede: true));
    }
  }

  Future<void> _resumeServerData() async {
    if (_serverDataAccess?.mode != ServerDataMode.deleted) return;
    // An expired server registration also resumes with notifications OFF.
    setState(() => _settings = _settings.copyWith(notificationEnabled: false));
    // Persist OFF while registration is still paused, including across a crash.
    final saver = _settingsSave;
    if (saver == null) return;
    await saver.save(_settings);
    if (!mounted || saver.state == SettingsSaveState.localFailed) return;
    await _serverDataAccess?.resume();
    if (!mounted || (_serverDataAccess?.paused ?? true)) return;
    // Re-enable registration only, not notification consent or the master switch.
    await _settingsSave?.save(_settings);
    if (mounted) unawaited(_refresh(supersede: true));
  }

  Future<RegionCatalog> _loadRegionCatalog() async =>
      _regionCatalog ??= await RegionCatalog.load();

  Future<void> _openDeviceLocationSettings() async {
    final opened = _location.state == LocationState.serviceDisabled
        ? await _locationService.openLocationSettings()
        : await _locationService.openAppSettings();
    if (!mounted || opened) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('설정을 열지 못했어요.\n기기 설정에서 위치 권한과 위치 기능을 확인해주세요.')));
  }
}
