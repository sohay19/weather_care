import 'package:flutter/material.dart';
import '../../models/weather.dart';
import '../../models/recommendation.dart';
import '../../models/app_settings.dart';
import '../../services/api_client.dart';
import '../../services/weather_service.dart';
import '../../theme/weather_theme.dart';
import '../../features/home/widgets/recommendation_bag_section.dart';
import '../../features/home/widgets/timeline_section.dart';
import '../../features/home/widgets/lifestyle_section.dart';
import '../../features/home/widgets/weather_card.dart';
import '../settings/settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final WeatherService _service = WeatherService(
    ApiClient(baseUrl: const String.fromEnvironment('SERVER_URL', defaultValue: 'http://localhost:8787')),
  );
  final AppSettings _settings = AppSettings.fallback('local-installation');
  bool _loading = true;
  TodayWeatherResponse _today = TodayWeatherResponse.fromJson(
    const {
      'region': {'nx': 60, 'ny': 121, 'name': '수원'},
      'brief': '오늘은 덥다가 퇴근할 때 비가 와요.',
      'current': {
        'temperature': 29.5,
        'apparentTemperature': 32.1,
      },
      'recommendations': [],
      'lifestyleMessages': [],
      'timeline': [],
    },
  );
  WeeklyWeatherResponse? _weekly;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final data = await _service.fetchToday(
      installationId: _settings.installationId,
      nx: 60,
      ny: 121,
    );
    final weekly = await _service.fetchWeekly(installationId: _settings.installationId);
    if (!mounted) return;
    setState(() {
      _today = data;
      _weekly = weekly;
      _loading = false;
    });
  }

  List<WeatherRecommendation> get _priorityRecommendations {
    final recs = List<WeatherRecommendation>.from(_today.recommendations)
      ..sort((a, b) => b.priority.compareTo(a.priority));
    return recs.where((e) => e.recommended).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('날씨챙겨'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: WeatherCareTheme.mood('clear'),
              child: Text(
                '${_today.region.name} · ${_today.brief}',
                style: const TextStyle(fontSize: 22, color: Colors.white, fontWeight: FontWeight.w600, height: 1.3),
              ),
            ),
            const SizedBox(height: 12),
            WeatherInfoCard(current: _today.current),
            const SizedBox(height: 12),
            RecommendationBagSection(
              regionName: _today.region.name,
              recommendations: _priorityRecommendations,
              onDetail: (type) {
                _openRecommendationDetail(type);
              },
            ),
            const SizedBox(height: 12),
            TimelineSection(items: _today.timeline),
            const SizedBox(height: 12),
            LifestyleSection(messages: _today.lifestyleMessages),
            const SizedBox(height: 12),
            if (_weekly != null) _buildWeeklySummary(),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.pushNamed(context, '/weather-details'),
              child: const Text('상세 날씨 보기'),
            ),
          ],
        ),
      ),
    );
  }

  void _openRecommendationDetail(RecommendationType type) {
    final route = switch (type) {
      RecommendationType.umbrella => '/weather/precipitation',
      RecommendationType.parasol => '/weather/uv',
      RecommendationType.heavySnowCaution => '/weather/snow',
      RecommendationType.outerwear => '/weather/temperature',
      RecommendationType.mask => '/weather/air-quality',
      RecommendationType.water => '/weather/heat',
      RecommendationType.sunscreen => '/weather/uv',
    };
    Navigator.pushNamed(context, route);
  }

  Widget _buildWeeklySummary() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('한 주 날씨', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ..._weekly!.days.map(
              (d) => ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Text(d.date),
                title: Text(d.weatherLabel),
                subtitle: Text('대표 추천: ${d.recommendations.map((r) => r.title).join(' · ')}'),
                trailing: Text('${d.min} / ${d.max}°'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

