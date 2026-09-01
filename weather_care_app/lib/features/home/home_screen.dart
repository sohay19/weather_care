import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';

import '../../models/app_settings.dart';
import '../../models/recommendation.dart';
import '../../models/weather.dart';
import '../../services/api_client.dart';
import '../../services/app_config.dart';
import '../../services/app_settings_repository.dart';
import '../../services/kma_direct_weather_service.dart';
import '../../services/installation_identity.dart';
import '../../services/notification_registration_service.dart';
import '../../services/settings_sync_service.dart';
import '../../services/weather_service.dart';
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

  const HomeScreen({super.key, this.initialIndex = 2});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late AppSettings _settings;
  final AppSettingsRepository _settingsRepository =
      const AppSettingsRepository();
  WeatherService? _service;
  NotificationRegistrationService? _notificationRegistration;
  SettingsSyncService? _settingsSync;
  Future<void> _settingsSaveQueue = Future<void>.value();
  int _settingsRevision = 0;
  TodayWeatherResponse? _today;
  WeeklyWeatherResponse? _weekly;
  WeatherLoadMode? _loadMode;
  late int _selectedIndex;
  bool _loading = false;
  String _statusMessage = '운영 서버 연결 상태를 확인하고 있습니다.';

  @override
  void initState() {
    super.initState();
    _settings = AppSettings.fallback('initializing-installation');
    _selectedIndex = widget.initialIndex < 0
        ? 0
        : widget.initialIndex > 4
            ? 4
            : widget.initialIndex;
    _initialize();
  }

  Future<void> _initialize() async {
    final config = await AppConfig.load();
    final installationId = await const InstallationIdentity().getOrCreate();
    final savedSettings = await _settingsRepository.load(installationId);
    if (!mounted) return;
    _settings = savedSettings;
    final client = ApiClient(baseUrl: config.serverUrl);
    _settingsSync = SettingsSyncService(client);
    _service = WeatherService(
      client,
      directKma: KmaDirectWeatherService(
        serviceKey: config.kmaServiceKey,
      ),
    );
    _notificationRegistration = NotificationRegistrationService(client);
    unawaited(
      _notificationRegistration!.initialize(
        installationId: installationId,
        nx: 60,
        ny: 121,
        locationMode: _settings.locationMode,
      ),
    );
    try {
      await _settingsSync!.save(_settings);
    } catch (_) {
      // 날씨 조회와 로컬 설정 사용은 서버 설정 저장 실패와 별도로 유지합니다.
    }
    await _loadData();
  }

  @override
  void dispose() {
    unawaited(_notificationRegistration?.dispose() ?? Future<void>.value());
    super.dispose();
  }

  Future<void> _loadData() async {
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
          nx: 60,
          ny: 121,
        );

        if (!mounted) return;
        if (serverResult.hasWeather) {
          _applyResult(serverResult);
          return;
        }

        final action = await showDialog<ServerFailureAction>(
          context: context,
          barrierDismissible: false,
          builder: (_) => const ServerConnectionFailureDialog(),
        );
        if (!mounted) return;

        if (action == ServerFailureAction.retryServer) {
          continue;
        }

        if (action == ServerFailureAction.useDirectForecast) {
          final directResult = await service.fetchDirectWeather(
            nx: 60,
            ny: 121,
          );
          if (!mounted) return;
          _applyResult(directResult);
          return;
        }

        _applyResult(serverResult);
        return;
      }
    } finally {
      _loading = false;
    }
  }

  void _applyResult(WeatherLoadResult result) {
    setState(() {
      _today = result.today;
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
                    ),
                    MainTab(
                      today: today,
                      dateLabel: _dateLabel,
                      mood: _mood,
                      serverFeaturesAvailable: serverFeaturesAvailable,
                      onRefresh: _loadData,
                    ),
                    WeekTab(
                      weekly: weekly,
                      serverFeaturesAvailable: serverFeaturesAvailable,
                      onRefresh: _loadData,
                    ),
                    SettingsScreen(
                      embedded: true,
                      onRefresh: _loadData,
                      initialSettings: _settings,
                      onSettingsChanged: _handleSettingsChanged,
                    ),
                  ]
                : [
                    _statusView('today-tab'),
                    _statusView('detail-tab'),
                    _statusView('main-tab'),
                    _statusView('week-tab'),
                    SettingsScreen(
                      embedded: true,
                      onRefresh: _loadData,
                      initialSettings: _settings,
                      onSettingsChanged: _handleSettingsChanged,
                    ),
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
              tooltip: '한 주 날씨',
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
      message: _statusMessage,
      onRetry: _loadData,
    );
  }

  void _openRecommendationDetail(RecommendationType _) {
    setState(() => _selectedIndex = 1);
  }

  Future<void> _handleSettingsChanged(AppSettings updated) {
    final revision = ++_settingsRevision;
    final locationChanged = _settings.locationMode != updated.locationMode;
    setState(() => _settings = updated);
    _settingsSaveQueue = _settingsSaveQueue
        .then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    )
        .then((_) async {
      await _settingsRepository.save(updated);
      try {
        await _settingsSync?.save(updated);
        if (locationChanged) {
          await _notificationRegistration?.syncInstallation(
            installationId: updated.installationId,
            nx: 60,
            ny: 121,
            locationMode: updated.locationMode,
          );
        }
      } catch (_) {
        // 로컬 저장값은 유지하고 다음 앱 시작 또는 변경 시 다시 동기화합니다.
      }
      if (mounted && revision == _settingsRevision) await _loadData();
    });
    return _settingsSaveQueue;
  }
}
