import 'dart:developer';

import '../models/weather.dart';
import 'api_client.dart';
import 'current_location_service.dart';

enum WeatherLoadMode {
  server,
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
  final int serverRetryCount;
  final Duration serverRetryDelay;
  final Future<void> Function(Duration) serverRetryWait;

  WeatherService(
    this.client, {
    this.serverRetryCount = 3,
    this.serverRetryDelay = const Duration(seconds: 5),
    Future<void> Function(Duration)? serverRetryWait,
  })  : assert(serverRetryCount >= 0),
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
    return serverResult;
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
            ? fetchTodayWeather(
                installationId: installationId,
                nx: nx,
                ny: ny,
                coordinates: coordinates,
              ).then((today) {
                latestToday = today;
                onToday?.call(today);
                return today;
              })
            : Future.value(latestToday!);
        final weeklyFuture = latestWeekly == null
            ? () async {
                final resolvedRegionName = regionName ?? await regionNameFuture;
                final weekly = await fetchWeeklyWeather(
                  installationId: installationId,
                  nx: nx,
                  ny: ny,
                  regionCode: regionCode,
                  regionName: resolvedRegionName,
                );
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

  Future<TodayWeatherResponse> fetchTodayWeather({
    required String installationId,
    int nx = 60,
    int ny = 121,
    DeviceCoordinates? coordinates,
  }) async {
    final data = await client.get(
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
    );
    return TodayWeatherResponse.fromJson(data);
  }

  Future<WeeklyWeatherResponse> fetchWeeklyWeather({
    required String installationId,
    int nx = 60,
    int ny = 121,
    String? regionCode,
    String? regionName,
  }) async {
    final data = await client.get(
      '/api/v1/weather/weekly',
      query: {
        'nx': '$nx',
        'ny': '$ny',
        'installationId': installationId,
        'includeExtras': 'true',
        if (regionCode != null && regionCode.isNotEmpty)
          'regionCode': regionCode,
        if (regionName != null && regionName.trim().isNotEmpty)
          'regionName': regionName.trim(),
      },
    );
    return WeeklyWeatherResponse.fromJson(data);
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

Future<void> _wait(Duration duration) => Future<void>.delayed(duration);
