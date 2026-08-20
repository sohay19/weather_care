import 'dart:developer';

import '../models/weather.dart';
import 'api_client.dart';
import '../data/sample_payloads.dart';

class WeatherFetchResult<T> {
  final T data;
  final bool isSample;

  const WeatherFetchResult({required this.data, required this.isSample});
}

class WeatherService {
  final ApiClient client;

  WeatherService(this.client);

  Future<WeatherFetchResult<TodayWeatherResponse>> fetchToday({
    required String installationId,
    int nx = 60,
    int ny = 121,
  }) async {
    try {
      final data = await client.get(
        '/api/v1/weather/today',
        query: {'nx': '$nx', 'ny': '$ny', 'installationId': installationId},
      );
      return WeatherFetchResult(
        data: TodayWeatherResponse.fromJson(data),
        isSample: false,
      );
    } catch (error) {
      log(
        'Today API unavailable (${error.runtimeType}); sample data in use',
      );
      return WeatherFetchResult(
        data: TodayWeatherResponse.fromJson(sampleTodayPayload(installationId)),
        isSample: true,
      );
    }
  }

  Future<WeatherFetchResult<WeeklyWeatherResponse>> fetchWeekly({
    required String installationId,
    int nx = 60,
    int ny = 121,
  }) async {
    try {
      final data = await client.get(
        '/api/v1/weather/weekly',
        query: {'nx': '$nx', 'ny': '$ny', 'installationId': installationId},
      );
      return WeatherFetchResult(
        data: WeeklyWeatherResponse.fromJson(data),
        isSample: false,
      );
    } catch (error) {
      log(
        'Weekly API unavailable (${error.runtimeType}); sample data in use',
      );
      return WeatherFetchResult(
        data: WeeklyWeatherResponse.fromJson(sampleWeeklyPayload()),
        isSample: true,
      );
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
