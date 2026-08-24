import 'dart:developer';

import 'package:http/http.dart' as http;

import '../models/weather.dart';
import 'api_client.dart';
import 'kma_direct_weather_service.dart';

enum WeatherLoadMode {
  server,
  directKma,
  offline,
  unavailable,
}

class WeatherLoadResult {
  final TodayWeatherResponse? today;
  final WeeklyWeatherResponse? weekly;
  final WeatherLoadMode mode;
  final String message;

  const WeatherLoadResult({
    required this.today,
    required this.weekly,
    required this.mode,
    required this.message,
  });

  bool get hasWeather => today != null && weekly != null;
  bool get serverFeaturesAvailable => mode == WeatherLoadMode.server;
}

class WeatherService {
  final ApiClient client;
  final KmaDirectWeatherService directKma;
  final Future<bool> Function() internetProbe;

  WeatherService(
    this.client, {
    required this.directKma,
    Future<bool> Function()? internetProbe,
  }) : internetProbe = internetProbe ?? _defaultInternetProbe;

  Future<WeatherLoadResult> fetchWeather({
    required String installationId,
    int nx = 60,
    int ny = 121,
  }) async {
    final serverResult = await fetchServerWeather(
      installationId: installationId,
      nx: nx,
      ny: ny,
    );
    if (serverResult.hasWeather) return serverResult;
    return fetchDirectWeather(nx: nx, ny: ny);
  }

  Future<WeatherLoadResult> fetchServerWeather({
    required String installationId,
    int nx = 60,
    int ny = 121,
  }) async {
    try {
      final responses = await Future.wait([
        client.get(
          '/api/v1/weather/today',
          query: {
            'nx': '$nx',
            'ny': '$ny',
            'installationId': installationId,
          },
        ),
        client.get(
          '/api/v1/weather/weekly',
          query: {
            'nx': '$nx',
            'ny': '$ny',
            'installationId': installationId,
          },
        ),
      ]);
      return WeatherLoadResult(
        today: TodayWeatherResponse.fromJson(responses[0]),
        weekly: WeeklyWeatherResponse.fromJson(responses[1]),
        mode: WeatherLoadMode.server,
        message: '운영 서버 연결',
      );
    } catch (error) {
      log('Weather server unavailable (${error.runtimeType})');
      return const WeatherLoadResult(
        today: null,
        weekly: null,
        mode: WeatherLoadMode.unavailable,
        message: '운영 서버에 연결하지 못했습니다.',
      );
    }
  }

  Future<WeatherLoadResult> fetchDirectWeather({
    int nx = 60,
    int ny = 121,
  }) async {
    if (directKma.isConfigured) {
      try {
        final direct = await directKma.fetch(nx: nx, ny: ny);
        return WeatherLoadResult(
          today: direct.today,
          weekly: direct.weekly,
          mode: WeatherLoadMode.directKma,
          message: '운영 서버 미연결 · 기상청 직접 조회',
        );
      } catch (error) {
        log('Direct KMA unavailable (${error.runtimeType})');
      }
    }

    final online = await internetProbe();
    if (!online) {
      return const WeatherLoadResult(
        today: null,
        weekly: null,
        mode: WeatherLoadMode.offline,
        message: '인터넷 연결 불가로 날씨 정보를 지원하지 않습니다.',
      );
    }

    return WeatherLoadResult(
      today: null,
      weekly: null,
      mode: WeatherLoadMode.unavailable,
      message: directKma.isConfigured
          ? '운영 서버와 기상청 직접 조회를 사용할 수 없습니다.'
          : '운영 서버 미연결 · KMA_SERVICE_KEY 미설정으로 직접 조회가 미지원됩니다.',
    );
  }

  Future<ComparisonResponse> fetchYesterdayComparison({
    required String installationId,
    int nx = 60,
    int ny = 121,
  }) async {
    try {
      final data = await client.get(
        '/api/v1/weather/comparison/yesterday',
        query: {'nx': '$nx', 'ny': '$ny', 'installationId': installationId},
      );
      return ComparisonResponse.fromJson(data);
    } catch (_) {
      return const ComparisonResponse.unavailable();
    }
  }

  Future<ComparisonResponse> fetchLastYearComparison({
    required String installationId,
    int nx = 60,
    int ny = 121,
  }) async {
    try {
      final data = await client.get(
        '/api/v1/weather/comparison/last-year',
        query: {'nx': '$nx', 'ny': '$ny', 'installationId': installationId},
      );
      return ComparisonResponse.fromJson(data);
    } catch (_) {
      return const ComparisonResponse.unavailable();
    }
  }
}

Future<bool> _defaultInternetProbe() async {
  try {
    await http
        .get(Uri.https('cp.cloudflare.com', '/generate_204'))
        .timeout(const Duration(seconds: 4));
    return true;
  } catch (_) {
    return false;
  }
}
