import 'package:flutter/material.dart';
import 'features/home/home_screen.dart';
import 'features/settings/settings_screen.dart';
import 'theme/weather_theme.dart';

class WeatherCareApp extends StatelessWidget {
  const WeatherCareApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '날씨챙겨',
      theme: WeatherCareTheme.light(),
      routes: {
        '/': (_) => const HomeScreen(),
        '/settings': (_) => const SettingsScreen(),
        '/weather-details': (_) => const WeatherDetailsScreen(),
        '/weather/precipitation': (_) => const WeatherRecommendationDetailScreen(
              title: '강수/우산 영역',
            ),
        '/weather/uv': (_) => const WeatherRecommendationDetailScreen(
              title: '자외선 영역',
            ),
        '/weather/snow': (_) => const WeatherRecommendationDetailScreen(
              title: '강설/폭설 영역',
            ),
        '/weather/temperature': (_) => const WeatherRecommendationDetailScreen(
              title: '기온·체감온도 영역',
            ),
        '/weather/air-quality': (_) => const WeatherRecommendationDetailScreen(
              title: '대기질 영역',
            ),
        '/weather/heat': (_) => const WeatherRecommendationDetailScreen(
              title: '체감더위 영역',
            ),
      },
      initialRoute: '/',
    );
  }
}

class WeatherDetailsScreen extends StatelessWidget {
  const WeatherDetailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('상세 날씨')),
      body: const Center(child: Text('상세 날씨는 추후 위젯을 확장해서 구현합니다.')),
    );
  }
}

class WeatherRecommendationDetailScreen extends StatelessWidget {
  final String title;
  const WeatherRecommendationDetailScreen({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            '$title 화면은 서버 응답 기반으로 상세 추천 근거를 표시하도록 확장됩니다.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
