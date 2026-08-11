import 'dart:developer';

import '../models/weather.dart';
import 'api_client.dart';
import '../data/sample_payloads.dart';

class WeatherService {
  final ApiClient client;

  WeatherService(this.client);

  Future<TodayWeatherResponse> fetchToday({
    required String installationId,
    int nx = 60,
    int ny = 121,
  }) async {
    try {
      final data = await client.get(
        '/api/v1/weather/today',
        query: {'nx': '$nx', 'ny': '$ny', 'installationId': installationId},
      );
      return TodayWeatherResponse.fromJson(data);
    } catch (_) {
      log('Today API fallback used');
      return TodayWeatherResponse.fromJson(sampleTodayPayload(installationId));
    }
  }

  Future<WeeklyWeatherResponse> fetchWeekly({
    required String installationId,
    int nx = 60,
    int ny = 121,
  }) async {
    try {
      final data = await client.get(
        '/api/v1/weather/weekly',
        query: {'nx': '$nx', 'ny': '$ny', 'installationId': installationId},
      );
      return WeeklyWeatherResponse.fromJson(data);
    } catch (_) {
      return WeeklyWeatherResponse.fromJson(sampleWeeklyPayload());
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
      return const ComparisonResponse(comparisonAvailable: false, payload: {});
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
      return const ComparisonResponse(comparisonAvailable: false, payload: {});
    }
  }
}

