import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/sample_payloads.dart';
import '../../models/app_settings.dart';
import '../../models/recommendation.dart';
import '../../models/weather.dart';
import '../../services/api_client.dart';
import '../../services/weather_service.dart';
import '../../theme/weather_theme.dart';
import '../settings/settings_screen.dart';
import 'tabs/detail_tab.dart';
import 'tabs/main_tab.dart';
import 'tabs/today_tab.dart';
import 'tabs/week_tab.dart';

class HomeScreen extends StatefulWidget {
  final int initialIndex;

  const HomeScreen({super.key, this.initialIndex = 2});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AppSettings _settings = AppSettings.fallback('local-installation');
  late final WeatherService _service;
  late TodayWeatherResponse _today;
  late WeeklyWeatherResponse _weekly;
  late int _selectedIndex;
  bool _refreshing = true;
  bool _usingSampleData = true;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex < 0
        ? 0
        : widget.initialIndex > 4
            ? 4
            : widget.initialIndex;
    _today = TodayWeatherResponse.fromJson(
      sampleTodayPayload(_settings.installationId),
    );
    _weekly = WeeklyWeatherResponse.fromJson(sampleWeeklyPayload());
    _service = WeatherService(ApiClient(baseUrl: _resolveServerUrl()));
    _loadData();
  }

  String _resolveServerUrl() {
    return const String.fromEnvironment(
      'SERVER_URL',
      defaultValue: 'https://weather-care-server.sy40222.workers.dev',
    );
  }

  Future<void> _loadData() async {
    if (mounted) {
      setState(() => _refreshing = true);
    }

    final todayFuture = _service.fetchToday(
      installationId: _settings.installationId,
      nx: 60,
      ny: 121,
    );
    final weeklyFuture = _service.fetchWeekly(
      installationId: _settings.installationId,
      nx: 60,
      ny: 121,
    );
    final today = await todayFuture;
    final weekly = await weeklyFuture;

    if (!mounted) return;
    setState(() {
      _today = today.data;
      _weekly = weekly.data;
      _usingSampleData = today.isSample || weekly.isSample;
      _refreshing = false;
    });
  }

  List<WeatherRecommendation> get _priorityRecommendations {
    final recommendations = List<WeatherRecommendation>.from(
      _today.recommendations,
    )..sort((a, b) => b.priority.compareTo(a.priority));
    return recommendations.where((item) => item.recommended).toList();
  }

  String get _mood {
    final sky = (_today.current.sky ?? '').toLowerCase();
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
              TodayTab(
                today: _today,
                recommendations: _priorityRecommendations,
                onRefresh: _loadData,
                onDetail: _openRecommendationDetail,
              ),
              DetailTab(
                today: _today,
                recommendations: _priorityRecommendations,
                onRefresh: _loadData,
              ),
              MainTab(
                today: _today,
                dateLabel: _dateLabel,
                mood: _mood,
                refreshing: _refreshing,
                usingSampleData: _usingSampleData,
                onRefresh: _loadData,
              ),
              WeekTab(weekly: _weekly, onRefresh: _loadData),
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

  void _openRecommendationDetail(RecommendationType _) {
    setState(() => _selectedIndex = 1);
  }
}
