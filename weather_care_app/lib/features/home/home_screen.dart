import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/app_settings.dart';
import '../../models/recommendation.dart';
import '../../models/weather.dart';
import '../../services/api_client.dart';
import '../../services/app_config.dart';
import '../../services/kma_direct_weather_service.dart';
import '../../services/weather_service.dart';
import '../../theme/weather_theme.dart';
import '../settings/settings_screen.dart';
import 'tabs/detail_tab.dart';
import 'tabs/main_tab.dart';
import 'tabs/today_tab.dart';
import 'tabs/week_tab.dart';
import 'widgets/weather_status_view.dart';

class HomeScreen extends StatefulWidget {
  final int initialIndex;

  const HomeScreen({super.key, this.initialIndex = 2});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AppSettings _settings = AppSettings.fallback('local-installation');
  WeatherService? _service;
  TodayWeatherResponse? _today;
  WeeklyWeatherResponse? _weekly;
  WeatherLoadMode? _loadMode;
  late int _selectedIndex;
  bool _refreshing = true;
  String _statusMessage = '운영 서버 연결 상태를 확인하고 있습니다.';

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex < 0
        ? 0
        : widget.initialIndex > 4
            ? 4
            : widget.initialIndex;
    _initialize();
  }

  Future<void> _initialize() async {
    final config = await AppConfig.load();
    if (!mounted) return;
    _service = WeatherService(
      ApiClient(baseUrl: config.serverUrl),
      directKma: KmaDirectWeatherService(
        serviceKey: config.kmaServiceKey,
      ),
    );
    await _loadData();
  }

  Future<void> _loadData() async {
    final service = _service;
    if (service == null) return;
    if (mounted) {
      setState(() => _refreshing = true);
    }

    final result = await service.fetchWeather(
      installationId: _settings.installationId,
      nx: 60,
      ny: 121,
    );

    if (!mounted) return;
    setState(() {
      _today = result.today;
      _weekly = result.weekly;
      _loadMode = result.mode;
      _statusMessage = result.message;
      _refreshing = false;
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
    final directKma = _loadMode == WeatherLoadMode.directKma;

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
                      refreshing: _refreshing,
                      directKma: directKma,
                      serverFeaturesAvailable: serverFeaturesAvailable,
                      onRefresh: _loadData,
                    ),
                    WeekTab(
                      weekly: weekly,
                      serverFeaturesAvailable: serverFeaturesAvailable,
                      onRefresh: _loadData,
                    ),
                    const SettingsScreen(embedded: true),
                  ]
                : [
                    _statusView('today-tab'),
                    _statusView('detail-tab'),
                    _statusView('main-tab'),
                    _statusView('week-tab'),
                    const SettingsScreen(embedded: true),
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
              tooltip: '오늘의 가방과 오늘 하루',
              icon: Icon(Icons.work_outline_rounded),
              selectedIcon: Icon(Icons.work_rounded),
              label: 'Today',
            ),
            NavigationDestination(
              tooltip: '상세 날씨',
              icon: Icon(Icons.query_stats_outlined),
              selectedIcon: Icon(Icons.query_stats_rounded),
              label: 'Detail',
            ),
            NavigationDestination(
              tooltip: '메인',
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded),
              label: 'Main',
            ),
            NavigationDestination(
              tooltip: '한 주 날씨',
              icon: Icon(Icons.calendar_month_outlined),
              selectedIcon: Icon(Icons.calendar_month_rounded),
              label: 'Week',
            ),
            NavigationDestination(
              tooltip: '설정',
              icon: Icon(Icons.tune_outlined),
              selectedIcon: Icon(Icons.tune_rounded),
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
}
