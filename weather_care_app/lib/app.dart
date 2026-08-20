import 'package:flutter/material.dart';

import 'features/home/home_screen.dart';
import 'theme/weather_theme.dart';

class WeatherCareApp extends StatelessWidget {
  const WeatherCareApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '날씨챙겨',
      debugShowCheckedModeBanner: false,
      theme: WeatherCareTheme.light(),
      routes: {
        '/': (_) => const HomeScreen(),
        '/settings': (_) => const HomeScreen(initialIndex: 4),
        '/weather-details': (_) => const HomeScreen(initialIndex: 1),
        '/weather/precipitation': (_) =>
            const WeatherRecommendationDetailScreen(
              title: '우산이 필요한 이유',
              subtitle: '오후 비 가능성과 강수 시간대를 확인해요',
              icon: Icons.umbrella_outlined,
              accent: Color(0xFF4E8FD8),
              background: Color(0xFFEAF3FD),
            ),
        '/weather/uv': (_) => const WeatherRecommendationDetailScreen(
              title: '자외선 대비가 필요한 이유',
              subtitle: '자외선 지수와 햇볕이 강한 시간대를 확인해요',
              icon: Icons.wb_sunny_outlined,
              accent: Color(0xFFE98B65),
              background: Color(0xFFFFEFE8),
            ),
        '/weather/snow': (_) => const WeatherRecommendationDetailScreen(
              title: '눈길 이동에 주의해요',
              subtitle: '강설 가능성과 이동 주의 시간대를 확인해요',
              icon: Icons.ac_unit_rounded,
              accent: Color(0xFF65A9C8),
              background: Color(0xFFEAF7FC),
            ),
        '/weather/temperature': (_) => const WeatherRecommendationDetailScreen(
              title: '겉옷이 필요한 이유',
              subtitle: '기온과 체감온도 변화를 함께 확인해요',
              icon: Icons.checkroom_rounded,
              accent: Color(0xFF8B78C6),
              background: Color(0xFFF1EDFB),
            ),
        '/weather/air-quality': (_) => const WeatherRecommendationDetailScreen(
              title: '마스크가 필요한 이유',
              subtitle: '미세먼지와 대기질 상태를 확인해요',
              icon: Icons.face_outlined,
              accent: Color(0xFF748596),
              background: Color(0xFFF0F3F5),
            ),
        '/weather/heat': (_) => const WeatherRecommendationDetailScreen(
              title: '물을 챙겨야 하는 이유',
              subtitle: '체감더위와 수분 보충 필요성을 확인해요',
              icon: Icons.local_drink_outlined,
              accent: Color(0xFF3FA9C5),
              background: Color(0xFFE7F8FB),
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
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: WeatherCareTheme.mood('clear'),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.insights_rounded,
                  color: WeatherCareTheme.primaryDeep,
                  size: 30,
                ),
                SizedBox(height: 16),
                Text(
                  '숫자는 추천을 이해하는\n근거로 보여드릴게요.',
                  style: TextStyle(
                    fontSize: 25,
                    height: 1.3,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.7,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: WeatherCareTheme.surfaceDecoration(),
            child: const _ConnectionNotice(
              title: '상세 예보를 준비 중이에요',
              message: '서버가 연결되면 시간별 기온·강수·자외선·대기질 데이터를 이 화면에 표시합니다.',
            ),
          ),
        ],
      ),
    );
  }
}

class WeatherRecommendationDetailScreen extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final Color background;

  const WeatherRecommendationDetailScreen({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.background,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('추천 상세')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(28),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: accent, size: 28),
                ),
                const SizedBox(height: 18),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.6,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: WeatherCareTheme.textSecondary,
                    fontSize: 14,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: WeatherCareTheme.surfaceDecoration(),
            child: const _ConnectionNotice(
              title: '추천 근거 데이터',
              message:
                  '현재는 화면 골격만 제공됩니다. 서버가 연결되면 추천 설명과 강수·UV·체감온도 같은 근거 수치가 표시됩니다.',
            ),
          ),
        ],
      ),
    );
  }
}

class _ConnectionNotice extends StatelessWidget {
  final String title;
  final String message;

  const _ConnectionNotice({required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: WeatherCareTheme.primarySoft,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(
            Icons.cloud_off_outlined,
            size: 20,
            color: WeatherCareTheme.primaryDeep,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 5),
              Text(message, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ],
    );
  }
}
