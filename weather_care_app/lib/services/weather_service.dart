import 'dart:developer';

import 'package:http/http.dart' as http;

import '../models/weather.dart';
import 'api_client.dart';
import 'kma_direct_weather_service.dart';
import 'current_location_service.dart';

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
  bool get hasAnyWeather => today != null || weekly != null;
  bool get serverFeaturesAvailable => mode == WeatherLoadMode.server;
}

class WeatherService {
  final ApiClient client;
  final KmaDirectWeatherService directKma;
  final Future<bool> Function() internetProbe;
  final int serverRetryCount;
  final Duration serverRetryDelay;
  final Future<void> Function(Duration) serverRetryWait;

  WeatherService(
    this.client, {
    required this.directKma,
    Future<bool> Function()? internetProbe,
    this.serverRetryCount = 3,
    this.serverRetryDelay = const Duration(seconds: 5),
    Future<void> Function(Duration)? serverRetryWait,
  })  : assert(serverRetryCount >= 0),
        internetProbe = internetProbe ?? _defaultInternetProbe,
        serverRetryWait = serverRetryWait ?? _wait;

  Future<WeatherLoadResult> fetchWeather({
    required String installationId,
    int nx = 60,
    int ny = 121,
    DeviceCoordinates? coordinates,
  }) async {
    final serverResult = await fetchServerWeather(
      installationId: installationId,
      nx: nx,
      ny: ny,
      coordinates: coordinates,
    );
    if (serverResult.hasWeather) return serverResult;
    return fetchDirectWeather(nx: nx, ny: ny);
  }

  Future<WeatherLoadResult> fetchServerWeather({
    required String installationId,
    int nx = 60,
    int ny = 121,
    DeviceCoordinates? coordinates,
    String? regionCode,
    String? regionName,
    Future<String?>? regionNameFuture,
    void Function(TodayWeatherResponse today)? onToday,
    void Function(WeeklyWeatherResponse weekly)? onWeekly,
  }) async {
    Object? lastError;
    TodayWeatherResponse? latestToday;
    WeeklyWeatherResponse? latestWeekly;
    for (var attempt = 0; attempt <= serverRetryCount; attempt++) {
      try {
        final todayFuture = latestToday == null
            ? client.get(
                '/api/v1/weather/today',
                query: {
                  'nx': '$nx',
                  'ny': '$ny',
                  'installationId': installationId,
                  if (coordinates != null) ...{
                    'latitude': '${coordinates.latitude}',
                    'longitude': '${coordinates.longitude}',
                  },
                },
              ).then((data) {
                final today = TodayWeatherResponse.fromJson(data);
                latestToday = today;
                onToday?.call(today);
                return today;
              })
            : Future.value(latestToday!);
        final weeklyFuture = latestWeekly == null
            ? () async {
                final resolvedRegionName = regionName ?? await regionNameFuture;
                final data = await client.get(
                  '/api/v1/weather/weekly',
                  query: {
                    'nx': '$nx',
                    'ny': '$ny',
                    'installationId': installationId,
                    'includeExtras': 'true',
                    if (regionCode != null && regionCode.isNotEmpty)
                      'regionCode': regionCode,
                    if (resolvedRegionName != null &&
                        resolvedRegionName.trim().isNotEmpty)
                      'regionName': resolvedRegionName.trim(),
                  },
                );
                final weekly = WeeklyWeatherResponse.fromJson(data);
                latestWeekly = weekly;
                onWeekly?.call(weekly);
                return weekly;
              }()
            : Future.value(latestWeekly!);
        final responses = await Future.wait([todayFuture, weeklyFuture]);
        return WeatherLoadResult(
          today: responses[0] as TodayWeatherResponse,
          weekly: responses[1] as WeeklyWeatherResponse,
          mode: WeatherLoadMode.server,
          message: '운영 서버 연결',
        );
      } catch (error) {
        lastError = error;
        if (attempt == serverRetryCount) break;
        await serverRetryWait(serverRetryDelay);
      }
    }

    log('Weather server unavailable after '
        '${serverRetryCount + 1} attempts (${lastError.runtimeType})');
    return WeatherLoadResult(
      today: latestToday,
      weekly: latestWeekly,
      mode: latestToday != null || latestWeekly != null
          ? WeatherLoadMode.server
          : WeatherLoadMode.unavailable,
      message: latestToday != null || latestWeekly != null
          ? '일부 날씨 자료만 연결됐습니다.'
          : '운영 서버에 연결하지 못했습니다.',
    );
  }

  Future<TodayWeatherResponse?> fetchMainWeather({
    int nx = 60,
    int ny = 121,
  }) async {
    try {
      final data = await client.get(
        '/api/v1/weather/main',
        query: {'nx': '$nx', 'ny': '$ny'},
      );
      return TodayWeatherResponse.fromJson(data);
    } catch (error) {
      log('Fast Main weather unavailable (${error.runtimeType})');
      return null;
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

Future<void> _wait(Duration duration) => Future<void>.delayed(duration);
