import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
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
import '../../services/address_search_service.dart';
import '../../services/home_widget_service.dart';
import '../../services/background_location_service.dart';
import '../../services/region_catalog.dart';
import '../../models/selectable_region.dart';
import '../../theme/weather_theme.dart';
import '../../utils/korea_date.dart';
import '../../utils/region_name.dart';
import '../settings/settings_screen.dart';
import '../settings/region_picker_screen.dart';
import '../settings/administrative_region_picker_screen.dart';
import '../settings/address_region_picker_screen.dart';
import '../settings/postal_address_picker_screen.dart';
import '../ads/consent_aware_native_ad_card.dart';
import 'weather_labels.dart';
import 'weather_data_phase.dart';
import 'tabs/evidence_focus.dart';
import 'tabs/main_tab.dart';
import 'tabs/today_tab.dart';
import 'tabs/extra_tab.dart';
import 'tabs/week_tab.dart';
import 'widgets/server_connection_failure_dialog.dart';
import 'widgets/permission_onboarding_dialog.dart';
import 'widgets/weather_status_view.dart';

enum _RegionSelectionMethod { administrative, address, map }

class HomeScreen extends StatefulWidget {
  final int initialIndex;
  final NotificationTopic? initialNotificationTopic;
  final NotificationRegion? initialNotificationRegion;
  final CurrentLocationService locationService;
  final GpsRegionNameService gpsRegionNameService;
  final WeatherService? weatherService;
  final SettingsSyncService? settingsSync;
  final NotificationRegistrationService? notificationRegistration;
  final RegionCatalog? regionCatalog;
  final RegionMapBuilder? regionMapBuilder;
  final AddressSearchService addressSearchService;
  final PostalAddressPicker? postalAddressPicker;
  final Future<bool> Function(Uri)? openExternalLink;
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
    this.initialNotificationRegion,
    this.locationService = const CurrentLocationService(),
    this.gpsRegionNameService = const PlatformGpsRegionNameService(),
    this.weatherService,
    this.settingsSync,
    this.notificationRegistration,
    this.regionCatalog,
    this.regionMapBuilder,
    this.addressSearchService = const PlatformAddressSearchService(),
    this.postalAddressPicker,
    this.openExternalLink,
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
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  late AppSettings _settings;
  final AppSettingsRepository _settingsRepository =
      const AppSettingsRepository();
  WeatherService? _service;
  NotificationRegistrationService? _notificationRegistration;
  final BackgroundLocationService _backgroundLocation =
      BackgroundLocationService();
  SettingsSyncService? _settingsSync;
  ServerDataAccess? _serverDataAccess;
  CurrentLocationService get _locationService => widget.locationService;
  DeviceCoordinates? _coordinates;
  String? _gpsRegionName;
  String? _gpsServerRegionName;
  bool _gpsRegionNameLoading = false;
  int _gpsRegionLookupId = 0;
  Timer? _gpsRegionRetryTimer;
  LocationResult _location = const LocationResult(LocationState.idle);
  Future<void>? _refreshFuture;
  bool _refreshAgain = false;
  bool _notifyRefreshFailure = false;
  bool _requestPermission = false;
  bool _requestInitialBackgroundPermission = false;
  bool _forceLocationRefresh = false;
  bool _initialized = false;
  bool _leftApp = false;
  bool _registrationInitialized = false;
  Future<void>? _gpsNotificationRegistrationFuture;
  RegionCatalog? _regionCatalog;
  ForecastRegion? get _manualRegion =>
      _regionCatalog?.find(_settings.manualRegionKey) ??
      (_settings.manualRegionKey == null &&
              _settings.manualRegionName != null &&
              _settings.currentRegionId != null
          ? _notificationSnapshotRegion()
          : null);

  ForecastRegion? _notificationSnapshotRegion() {
    final grid = _settings.currentRegionId!.split('_');
    if (grid.length != 2) return null;
    final nx = int.tryParse(grid[0]);
    final ny = int.tryParse(grid[1]);
    if (nx == null || ny == null || nx < 1 || nx > 149 || ny < 1 || ny > 253) {
      return null;
    }
    return ForecastRegion(
        code: '',
        parentCode: '',
        name: _settings.manualRegionName!,
        nx: nx,
        ny: ny,
        fullName: _settings.manualRegionName!);
  }

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
  late bool _extraAdvertisementActivated;
  late bool _mainAdvertisementActivated;
  late bool _weekAdvertisementActivated;
  late NotificationTopic? _detailFocusTopic;
  LifestyleMessageType? _detailFocusLifestyleType;
  WeatherRecommendation? _detailFocusRecommendation;
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
    final grid = _weatherGrid;
    if (today == null ||
        grid == null ||
        today.region.nx != grid.nx ||
        today.region.ny != grid.ny ||
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
      testAccessKey: _serverDataAccess?.api.testAccessKey,
      gpsEnabled: _settings.locationMode == 'GPS',
      locationMeasuredAt:
          _settings.locationMode == 'GPS' ? _location.measuredAt : null,
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
        ? (_hasGpsRegionName ? _gpsDisplayName : null)
        : _manualRegion?.fullName;
    return Uri.parse(baseUrl)
        .resolve('/api/v1/weather/widget')
        .replace(queryParameters: {
      'nx': '${grid.nx}',
      'ny': '${grid.ny}',
      'widgetSettings': _homeWidgetSettingsKey(),
      'recommendationCatalog': 'PREPARATION_18',
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

  String get _gpsDisplayName => gpsRegionDisplayName(
        deviceName: _gpsRegionName,
        serverName: _gpsServerRegionName,
        loading: _gpsRegionNameLoading,
      );

  bool get _hasGpsRegionName => !isRegionNamePlaceholder(_gpsDisplayName);

  TodayWeatherResponse _withGpsRegionName(TodayWeatherResponse today) {
    if (!isRegionNamePlaceholder(
        gpsRegionDisplayName(serverName: today.region.name))) {
      _gpsServerRegionName = today.region.name;
    }
    return today.withRegionName(_gpsDisplayName);
  }

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
    _extraAdvertisementActivated = _selectedIndex == 1;
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
    // 첫 업데이트에서는 기존 알림 대상 한 곳만 유지한다.
    _settings = savedSettings.copyWith(
        notificationRegionKeys: savedSettings.enabledNotificationRegionKeys);
    final notificationRegion = widget.initialNotificationRegion;
    if (notificationRegion != null) {
      var selected = _regionCatalog?.find(notificationRegion.key);
      if (selected == null &&
          notificationRegion.key == 'GPS' &&
          notificationRegion.name != null) {
        for (final region in _regionCatalog?.regions ?? <ForecastRegion>[]) {
          if (region.nx == notificationRegion.nx &&
              region.ny == notificationRegion.ny &&
              region.fullName == notificationRegion.name) {
            selected = region;
            break;
          }
        }
      }
      if (selected != null &&
          (selected.nx != notificationRegion.nx ||
              selected.ny != notificationRegion.ny)) {
        selected = null;
      }
      _settings = _settings.copyWith(
          locationMode: 'MANUAL',
          currentRegionId: '${notificationRegion.nx}_${notificationRegion.ny}',
          manualRegionKey: selected?.key,
          clearManualRegionKey: selected == null,
          manualRegionName: notificationRegion.name,
          savedRegionKeys: [
            ..._settings.savedRegionKeys,
            if (selected != null &&
                !_settings.savedRegionKeys.contains(selected.key))
              selected.key
          ]);
    }
    final access = widget.serverDataAccess ??
        ServerDataAccess(
            api: ApiClient(
                baseUrl: config.serverUrl,
                testAccessKey: config.testAccessKey,
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
    final client = InstallationApiClient(
        baseUrl: config.serverUrl,
        testAccessKey: config.testAccessKey,
        access: access);
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
    unawaited(_syncBackgroundLocation());
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
      if (confirmed != null) {
        _settings = _settings.copyWith(backgroundLocationEnabled: confirmed);
        if (!confirmed) unawaited(_syncBackgroundLocation());
        await _settingsSave?.save(_settings);
        if (!mounted) return;
        try {
          await widget.permissionOnboardingStore.confirm();
        } catch (_) {
          // Permission requests remain usable even if the guide state cannot persist.
        }
        if (_settings.notificationEnabled) {
          await _readNotificationPermission(request: true, sync: true);
        }
        if (!mounted) return;
        _requestInitialBackgroundPermission = confirmed;
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
    _backgroundLocation.dispose();
    _serverDataAccess?.removeListener(_onServerDataChanged);
    _weatherHourTimer?.cancel();
    _gpsRegionRetryTimer?.cancel();
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
      unawaited(_syncBackgroundLocation());
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
        final lookupId = ++_gpsRegionLookupId;
        _gpsRegionRetryTimer?.cancel();
        final ask = _requestPermission;
        final askBackground = _requestInitialBackgroundPermission;
        _requestInitialBackgroundPermission = false;
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
            _gpsServerRegionName = null;
            _gpsRegionNameLoading = result.hasLocation;
            if (_today != null) {
              _today = _today!.withRegionName(_gpsDisplayName);
            }
          });
          if (askBackground && _backgroundLocationWanted) {
            await _backgroundLocation.requestPermission(initial: true);
            if (!mounted) return;
            if (revision != _locationRevision) continue;
            unawaited(_syncBackgroundLocation());
          }
          if (result.canUseLocalAnalysis) {
            gpsRegionNameFuture = _resolveGpsRegionName(result.coordinates!);
          } else if (result.hasLocation) {
            // 대략적 위치는 기기 주소 변환 대신 서버의 상위 지역명을 조회한다.
            gpsRegionNameFuture = Future<String?>.value();
          }
        } else {
          _coordinates = null;
          _gpsRegionName = null;
          _gpsServerRegionName = null;
          _gpsRegionNameLoading = false;
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
                : '저장된 지역을 확인할 수 없어요.\nMain에서 구역을 다시 추가해주세요.';
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
          if (_settings.notificationEnabled &&
              _settings.locationMode != 'GPS' &&
              _settings.enabledNotificationRegionKeys.contains('GPS')) {
            unawaited(_syncGpsNotificationRegistration());
          } else {
            final register = _registrationInitialized
                ? registration.syncInstallation
                : registration.initialize;
            _registrationInitialized = true;
            unawaited(register(
                    installationId: _settings.installationId,
                    nx: grid.nx,
                    ny: grid.ny,
                    locationMode: _settings.locationMode,
                    coordinates: preciseCoordinates,
                    locationMeasuredAt: _settings.locationMode == 'GPS'
                        ? _location.measuredAt
                        : null)
                .then((_) => _syncBackgroundLocation()));
          }
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
            lookupId,
            grid,
            gpsRegionNameFuture,
            preciseCoordinates,
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
    int lookupId,
    KmaGrid expectedGrid,
    Future<String?> regionNameFuture,
    DeviceCoordinates? coordinates,
  ) async {
    final name = await regionNameFuture;
    if (!mounted ||
        revision != _locationRevision ||
        lookupId != _gpsRegionLookupId ||
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
      _gpsRegionNameLoading = !_hasGpsRegionName;
      _today = _withGpsRegionName(today);
    });
    _publishHomeWidget();
    if (_gpsRegionNameLoading) {
      _scheduleGpsRegionNameRetry(
          revision, lookupId, expectedGrid, coordinates, 5);
    }
  }

  void _scheduleGpsRegionNameRetry(int revision, int lookupId, KmaGrid grid,
      DeviceCoordinates? coordinates, int remaining) {
    _gpsRegionRetryTimer = Timer(const Duration(seconds: 1), () async {
      bool isCurrent() =>
          mounted &&
          revision == _locationRevision &&
          lookupId == _gpsRegionLookupId &&
          _settings.locationMode == 'GPS';
      if (!isCurrent()) return;
      final results = await Future.wait([
        coordinates == null
            ? Future<String?>.value()
            : _resolveGpsRegionName(coordinates),
        _resolveServerRegionName(grid, coordinates),
      ]);
      if (!isCurrent()) return;
      final today = _today;
      if (today == null ||
          today.region.nx != grid.nx ||
          today.region.ny != grid.ny) {
        return;
      }
      setState(() {
        _gpsRegionName = results[0];
        if (results[1] != null) _gpsServerRegionName = results[1];
        _gpsRegionNameLoading = !_hasGpsRegionName && remaining > 1;
        _today = _withGpsRegionName(today);
      });
      _publishHomeWidget();
      if (_gpsRegionNameLoading) {
        _scheduleGpsRegionNameRetry(
            revision, lookupId, grid, coordinates, remaining - 1);
      }
    });
  }

  Future<String?> _resolveServerRegionName(
      KmaGrid grid, DeviceCoordinates? coordinates) async {
    try {
      final response = await _service?.fetchMainWeather(
        nx: grid.nx,
        ny: grid.ny,
        coordinates: coordinates,
      );
      final name = gpsRegionDisplayName(serverName: response?.region.name);
      return isRegionNamePlaceholder(name) ? null : name;
    } catch (_) {
      return null;
    }
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
              ? _withGpsRegionName(today)
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
              ? _withGpsRegionName(preview)
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
        _today = _withGpsRegionName(today);
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
          backgroundLocation: _backgroundLocation,
          onBackgroundLocationPermission: _requestBackgroundLocationPermission,
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
      value: (Theme.of(context).brightness == Brightness.dark
              ? SystemUiOverlayStyle.light
              : SystemUiOverlayStyle.dark)
          .copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: WeatherCareTheme.of(context).surface,
        systemNavigationBarIconBrightness:
            Theme.of(context).brightness == Brightness.dark
                ? Brightness.light
                : Brightness.dark,
      ),
      child: Scaffold(
        key: _scaffoldKey,
        drawer: _regionDrawer(),
        drawerEnableOpenDragGesture: false,
        body: SafeArea(
          bottom: false,
          child: IndexedStack(
            index: _selectedIndex,
            children: [
              today == null
                  ? _statusView('today-tab')
                  : TodayTab(
                      today: visibleToday!,
                      lightningClient: _serverDataAccess?.paused == false
                          ? _service?.client
                          : null,
                      lightningGrid: _weatherGrid,
                      lightningCoordinates: _settings.locationMode == 'GPS' &&
                              _location.canUseLocalAnalysis &&
                              _serverDataAccess?.paused == false
                          ? _coordinates
                          : null,
                      active: _selectedIndex == 0,
                      dataPhase: todayPhase,
                      onRefresh: _refreshFromTab,
                      onRetryData: _retryTodayData,
                      retrying: _todayRetrying,
                      serverFeaturesAvailable: serverFeaturesAvailable,
                      focusTopic: _detailFocusTopic,
                      focusLifestyleType: _detailFocusLifestyleType,
                      focusedRecommendation: _detailFocusRecommendation,
                      focusSource: _detailFocusSource,
                      focusRequestId: _detailFocusRequestId,
                      advertisement: _todayAdvertisementActivated &&
                              !(widget.adRemoval?.isOwned ?? false)
                          ? ConsentAwareNativeAdCard(
                              placement: NativeAdPlacement.today,
                              adRemoval: widget.adRemoval,
                            )
                          : null,
                    ),
              ExtraTab(
                  client: _service?.client,
                  grid: _weatherGrid,
                  coordinates: _settings.locationMode == 'GPS' &&
                          _location.canUseLocalAnalysis &&
                          _serverDataAccess?.paused == false
                      ? _coordinates
                      : null,
                  active: _selectedIndex == 1,
                  advertisement: _extraAdvertisementActivated &&
                          !(widget.adRemoval?.isOwned ?? false)
                      ? ConsentAwareNativeAdCard(
                          placement: NativeAdPlacement.extra,
                          size: NativeAdCardSize.small,
                          adRemoval: widget.adRemoval,
                        )
                      : null),
              today == null
                  ? _statusView('main-tab')
                  : MainTab(
                      today: visibleToday!,
                      todayForecast: visibleWeekly?.days
                          .where(
                              (day) => day.forecastDate == dateInKorea(_now()))
                          .singleOrNull,
                      weeklyDataPhase: weeklyPhase,
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
                      onOpenRegionMenu: _openManualRegionMenu,
                      onOpenWeatherMap: () => unawaited(_openWeatherMap()),
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
                      hourly: visibleToday?.hourly ?? const [],
                      timelineHourly: visibleToday?.timelineHourly ?? const [],
                      snowDepthHistory:
                          visibleToday?.snowDepthHistory ?? const [],
                      currentSnow: visibleToday?.current,
                      advertisement: _weekAdvertisementActivated &&
                              !(widget.adRemoval?.isOwned ?? false)
                          ? ConsentAwareNativeAdCard(
                              placement: NativeAdPlacement.week,
                              size: NativeAdCardSize.small,
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
          backgroundColor: WeatherCareTheme.of(context).surface,
          surfaceTintColor: Colors.transparent,
          indicatorColor: WeatherCareTheme.of(context).primarySoft,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          onDestinationSelected: _selectTab,
          destinations: [
            NavigationDestination(
              tooltip: '오늘 날씨 자세히 보기',
              icon: Icon(
                Icons.work_outline_rounded,
                color: WeatherCareTheme.of(context).textSecondary,
              ),
              selectedIcon: Icon(
                Icons.work_rounded,
                color: WeatherCareTheme.of(context).primaryDeep,
              ),
              label: 'Today',
            ),
            NavigationDestination(
              tooltip: 'Advanced · 바다와 하천 관측 자료',
              icon: Icon(
                Icons.sensors_outlined,
                color: WeatherCareTheme.of(context).textSecondary,
              ),
              selectedIcon: Icon(
                Icons.sensors_rounded,
                color: WeatherCareTheme.of(context).primaryDeep,
              ),
              label: 'Advanced',
            ),
            NavigationDestination(
              tooltip: '날씨, Check List, 어제 비교와 예상',
              icon: Icon(
                Icons.home_outlined,
                color: WeatherCareTheme.of(context).textSecondary,
              ),
              selectedIcon: Icon(
                Icons.home_rounded,
                color: WeatherCareTheme.of(context).primaryDeep,
              ),
              label: 'Main',
            ),
            NavigationDestination(
              tooltip: '이번 주 날씨',
              icon: Icon(
                Icons.calendar_month_outlined,
                color: WeatherCareTheme.of(context).textSecondary,
              ),
              selectedIcon: Icon(
                Icons.calendar_month_rounded,
                color: WeatherCareTheme.of(context).primaryDeep,
              ),
              label: 'Week',
            ),
            NavigationDestination(
              tooltip: '설정',
              icon: Icon(
                Icons.tune_outlined,
                color: WeatherCareTheme.of(context).textSecondary,
              ),
              selectedIcon: Icon(
                Icons.tune_rounded,
                color: WeatherCareTheme.of(context).primaryDeep,
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
    _scaffoldKey.currentState?.openDrawer();
  }

  Widget _regionNotificationSwitch(String key, String name) {
    return Semantics(
        label: '$name 알림',
        child: Switch(
          key: ValueKey('region-notification-$key'),
          value: _settings.enabledNotificationRegionKeys.contains(key),
          onChanged: (_serverDataAccess?.paused ?? true)
              ? null
              : (enabled) {
                  final keys = _settings.enabledNotificationRegionKeys.toSet();
                  if (enabled) {
                    keys.add(key);
                  } else {
                    keys.remove(key);
                  }
                  unawaited(_handleSettingsChanged(_settings.copyWith(
                      notificationRegionKeys: keys.toList())));
                },
        ));
  }

  Widget _regionDrawer() {
    final colors = WeatherCareTheme.of(context);
    final tilePadding = ListTileTheme.of(context).contentPadding ??
        const EdgeInsetsDirectional.only(start: 16, end: 24);
    final gpsSelected = _settings.locationMode == 'GPS';
    return Drawer(
      key: const ValueKey('region-drawer'),
      backgroundColor: colors.surface,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 12),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 20, right: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text('구역 선택',
                              style: Theme.of(context).textTheme.titleLarge),
                        ),
                        IconButton(
                          tooltip: '구역 메뉴 닫기',
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () =>
                              _scaffoldKey.currentState?.closeDrawer(),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                    child: Text(
                        _settings.notificationEnabled
                            ? '지역별로 알림을 켜고 끌 수 있어요'
                            : '전체 알림이 꺼져 있어요. 지역별 선택은 유지돼요.',
                        style: Theme.of(context).textTheme.bodySmall),
                  ),
                  if (_settingsSave?.state.canRetry ?? false)
                    Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_settingsSave!.state.message,
                                  style: Theme.of(context).textTheme.bodySmall),
                              TextButton(
                                  onPressed: () => _saveSettings(_settings,
                                      refreshWeather: false),
                                  child: const Text('저장 다시 시도')),
                            ])),
                  Padding(
                    padding: EdgeInsets.only(
                        right: tilePadding
                                .resolve(Directionality.of(context))
                                .right -
                            12,
                        bottom: 2),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: SizedBox(
                        width: 84,
                        child: Transform.translate(
                          offset: const Offset(-8, 12),
                          child: Text('알림 ON/OFF',
                            key: const ValueKey(
                                'region-notification-column-label'),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontFamily: WeatherCareTheme.fontSuite,
                                color: colors.primary,
                                fontSize: 11,
                                fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                    ),
                  ),
                  ListTile(
                    leading: Icon(gpsSelected
                        ? Icons.check_circle_rounded
                        : Icons.my_location_rounded),
                    title: const Text('현재 위치'),
                    selected: gpsSelected,
                    subtitle: gpsSelected && _hasGpsRegionName
                        ? Text(_gpsDisplayName)
                        : null,
                    trailing: _regionNotificationSwitch('GPS', '현재 위치'),
                    onTap: () {
                      _scaffoldKey.currentState?.closeDrawer();
                      if (!gpsSelected) {
                        unawaited(_handleSettingsChanged(
                            _settings.copyWith(locationMode: 'GPS')));
                      }
                    },
                  ),
                  if (_settings.legacyNotificationRegionAvailable ||
                      _settings.enabledNotificationRegionKeys
                          .contains('LEGACY'))
                    ListTile(
                        leading: const Icon(Icons.notifications_outlined),
                        title: const Text('이전에 설정한 지역'),
                        subtitle: const Text('새 구역을 추가해 알림을 선택할 수 있어요.'),
                        trailing:
                            _regionNotificationSwitch('LEGACY', '이전에 설정한 지역')),
                  for (final key in _settings.savedRegionKeys)
                    if (_regionCatalog?.find(key) case final region?)
                      ListTile(
                        leading: Icon(!gpsSelected &&
                                _settings.manualRegionKey == region.key
                            ? Icons.check_circle_rounded
                            : Icons.location_on_outlined),
                        title: Text(region.displayName),
                        subtitle: region.fullName == region.displayName
                            ? null
                            : Text(region.fullName
                                .substring(
                                    0,
                                    region.fullName.length -
                                        region.displayName.length)
                                .trim()),
                        selected: !gpsSelected &&
                            _settings.manualRegionKey == region.key,
                        trailing: _regionNotificationSwitch(
                            region.key, region.fullName),
                        onTap: () {
                          _scaffoldKey.currentState?.closeDrawer();
                          unawaited(_handleSettingsChanged(_settings.copyWith(
                            locationMode: 'MANUAL',
                            currentRegionId: region.gridId,
                            manualRegionKey: region.key,
                          )));
                        },
                      ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: FilledButton.icon(
                key: const ValueKey('region-add-button'),
                icon: const Icon(Icons.add_rounded),
                label: const Text(
                  '구역 추가',
                  style: TextStyle(fontFamily: WeatherCareTheme.fontSuite),
                ),
                onPressed: () {
                  _scaffoldKey.currentState?.closeDrawer();
                  unawaited(_addRegion());
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addRegion() async {
    if (_settings.savedRegionKeys.length >= 49) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('구역은 최대 49개까지 추가할 수 있어요.')));
      return;
    }
    final method = await showModalBottomSheet<_RegionSelectionMethod>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Text('구역 추가',
                    style: Theme.of(context).textTheme.titleLarge),
              ),
              ListTile(
                leading: const Icon(Icons.search_rounded),
                title: const Text('행정지역명으로 선택'),
                subtitle: const Text('시·도, 시·군·구, 읍·면·동으로 찾아요'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.pop(
                    context, _RegionSelectionMethod.administrative),
              ),
              ListTile(
                leading: const Icon(Icons.location_on_outlined),
                title: const Text('주소로 선택'),
                subtitle: const Text('도로명주소나 지번주소로 찾아요'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () =>
                    Navigator.pop(context, _RegionSelectionMethod.address),
              ),
              ListTile(
                leading: const Icon(Icons.map_outlined),
                title: const Text('지도에서 구역 선택'),
                subtitle: const Text('지도에서 원하는 예보 구역을 골라요'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.pop(context, _RegionSelectionMethod.map),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
    if (!mounted || method == null) return;
    final catalog = await _loadRegionCatalog();
    if (!mounted) return;
    final savedGridIds = {
      for (final key in _settings.savedRegionKeys)
        if (catalog.find(key) case final region?) region.gridId,
    };
    final selected = await Navigator.of(context).push<ForecastGridSelection>(
      MaterialPageRoute(
        builder: (_) => switch (method) {
          _RegionSelectionMethod.administrative =>
            AdministrativeRegionPickerScreen(
              loadCatalog: _loadRegionCatalog,
              selectedRegionKey: _settings.manualRegionKey,
              savedGridIds: savedGridIds,
            ),
          _RegionSelectionMethod.address => AddressRegionPickerScreen(
              loadCatalog: _loadRegionCatalog,
              searchService: widget.addressSearchService,
              pickAddress: widget.postalAddressPicker,
              savedGridIds: savedGridIds,
            ),
          _RegionSelectionMethod.map => RegionPickerScreen(
              loadCatalog: _loadRegionCatalog,
              selectedGridId: _settings.currentRegionId,
              selectedRegionKey: _settings.manualRegionKey,
              mapBuilder: widget.regionMapBuilder,
              savedGridIds: savedGridIds,
            ),
        },
      ),
    );
    if (!mounted || selected == null) return;
    final keys = [..._settings.savedRegionKeys];
    keys.add(selected.regionKey);
    await _handleSettingsChanged(_settings.copyWith(
      locationMode: 'MANUAL',
      currentRegionId: selected.gridId,
      manualRegionKey: selected.regionKey,
      savedRegionKeys: keys,
    ));
  }

  Future<void> _openWeatherMap() async {
    var opened = false;
    try {
      final uri = Uri.parse('https://weather-care.pages.dev/weather-map');
      opened = await (widget.openExternalLink?.call(uri) ??
          launchUrl(uri, mode: LaunchMode.externalApplication));
    } catch (_) {
      // 브라우저를 열 수 없으면 아래 안내를 표시한다.
    }
    if (!mounted || opened) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('예보 구역 지도를 열지 못했어요.\n인터넷 연결을 확인해주세요.'),
    ));
  }

  void _selectTab(int index) {
    if (_selectedIndex == index) return;
    setState(() {
      if (_selectedIndex == 0 &&
          _detailFocusSource == DetailFocusSource.selection) {
        _detailFocusTopic = null;
        _detailFocusLifestyleType = null;
        _detailFocusRecommendation = null;
        _detailFocusSource = DetailFocusSource.notification;
        _detailFocusRequestId += 1;
      }
      _selectedIndex = index;
      if (index == 0) _todayAdvertisementActivated = true;
      if (index == 1) _extraAdvertisementActivated = true;
      if (index == 2) _mainAdvertisementActivated = true;
      if (index == 3) _weekAdvertisementActivated = true;
    });
  }

  void _openRecommendationDetail(WeatherRecommendation recommendation) {
    setState(() {
      _detailFocusTopic = null;
      _detailFocusLifestyleType =
          detailLifestyleTypeForRecommendationType(recommendation.type);
      _detailFocusRecommendation = recommendation;
      _detailFocusSource = DetailFocusSource.selection;
      _detailFocusRequestId += 1;
      _selectedIndex = 0;
      _todayAdvertisementActivated = true;
    });
  }

  Future<void> _handleSettingsChanged(AppSettings updated) {
    if (_serverDataAccess?.paused ?? true) {
      updated = updated.copyWith(notificationEnabled: false);
    }
    final onlyRegionNotificationsChanged =
        updated.notificationRegionKeys != _settings.notificationRegionKeys &&
            updated.locationMode == _settings.locationMode &&
            updated.manualRegionKey == _settings.manualRegionKey;
    final locationChanged = _settings.locationMode != updated.locationMode ||
        _settings.currentRegionId != updated.currentRegionId ||
        _settings.manualRegionKey != updated.manualRegionKey;
    setState(() {
      _settings = updated;
      if (locationChanged) {
        _locationRevision++;
        _coordinates = null;
        _gpsRegionName = null;
        _gpsServerRegionName = null;
        _gpsRegionNameLoading = false;
        _gpsRegionRetryTimer?.cancel();
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
    if (!_backgroundLocationWanted) unawaited(_syncBackgroundLocation());
    return _saveSettings(updated,
            refreshWeather: !locationChanged && !onlyRegionNotificationsChanged)
        .then((_) {
      if (onlyRegionNotificationsChanged &&
          _settings.notificationEnabled &&
          _settings.locationMode != 'GPS' &&
          _settings.enabledNotificationRegionKeys.contains('GPS')) {
        unawaited(_syncGpsNotificationRegistration());
      } else {
        unawaited(_syncBackgroundLocation());
      }
    });
  }

  Future<void> _syncGpsNotificationRegistration() {
    return _gpsNotificationRegistrationFuture ??=
        _registerGpsNotificationLocation().catchError((Object _) {
      /* 위치 실패가 수동 지역 예보를 막지 않는다. */
    }).whenComplete(() => _gpsNotificationRegistrationFuture = null);
  }

  Future<void> _registerGpsNotificationLocation() async {
    final registration = _notificationRegistration;
    if (registration == null ||
        !_settings.notificationEnabled ||
        (_serverDataAccess?.paused ?? true)) {
      return;
    }
    final result = await _locationService.locate(requestPermission: false);
    if (!mounted ||
        _settings.locationMode == 'GPS' ||
        !_settings.notificationEnabled ||
        !_settings.enabledNotificationRegionKeys.contains('GPS') ||
        (_serverDataAccess?.paused ?? true)) {
      return;
    }
    final coordinates = result.hasLocation ? result.coordinates : null;
    final grid = coordinates == null
        ? _weatherGrid
        : KmaGrid.fromCoordinates(
            latitude: coordinates.latitude, longitude: coordinates.longitude);
    if (grid == null) return;
    final register = _registrationInitialized
        ? registration.syncInstallation
        : registration.initialize;
    _registrationInitialized = true;
    await register(
        installationId: _settings.installationId,
        nx: grid.nx,
        ny: grid.ny,
        locationMode: coordinates == null ? 'MANUAL' : 'GPS',
        coordinates: result.canUseLocalAnalysis ? coordinates : null,
        locationMeasuredAt: coordinates == null ? null : result.measuredAt);
    await _syncBackgroundLocation();
  }

  bool get _backgroundLocationWanted =>
      _settings.backgroundLocationEnabled &&
      _settings.enabledNotificationRegionKeys.contains('GPS') &&
      _settings.notificationEnabled &&
      !(_serverDataAccess?.paused ?? true) &&
      _settingsSave?.state != SettingsSaveState.localFailed;

  Future<void> _syncBackgroundLocation() async {
    final access = _serverDataAccess;
    if (access == null || !mounted) return;
    await _backgroundLocation.synchronize(
        enabled: _backgroundLocationWanted, access: access);
  }

  Future<void> _requestBackgroundLocationPermission() async {
    if (!_backgroundLocationWanted) return;
    // Foreground and Always permission requests must be separate on both OSes.
    await _locationService.locate(requestPermission: true);
    if (!mounted || !_backgroundLocationWanted) return;
    await _backgroundLocation.requestPermission();
    await _syncBackgroundLocation();
  }

  void _onSettingsSaveChanged() {
    if (_settingsSave?.state == SettingsSaveState.localFailed) {
      unawaited(_syncBackgroundLocation());
    }
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
    if (_settings.notificationEnabled &&
        _settings.locationMode != 'GPS' &&
        _settings.enabledNotificationRegionKeys.contains('GPS')) {
      unawaited(_syncGpsNotificationRegistration());
      return;
    }
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
                    : null,
            locationMeasuredAt: _settings.locationMode == 'GPS'
                ? _location.measuredAt
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
    unawaited(_syncBackgroundLocation());
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
