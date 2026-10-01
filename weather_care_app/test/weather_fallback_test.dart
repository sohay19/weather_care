import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weather_care/services/api_client.dart';
import 'package:weather_care/services/app_config.dart';
import 'package:weather_care/services/current_location_service.dart';
import 'package:weather_care/services/weather_service.dart';

void main() {
  test('별도 설정이 없으면 미니 PC 운영 서버를 사용한다', () async {
    final config = await AppConfig.load(bundle: _JsonAssetBundle({}));
    expect(config.serverUrl, 'https://weather-api.codesoha.com');
  });

  test('앱 설정에서는 운영 서버 주소만 로드한다', () async {
    final config = await AppConfig.load(
      bundle: _JsonAssetBundle({
        'SERVER_URL': 'https://weather.example.com',
        'KMA_SERVICE_KEY': '앱에-남으면-안되는-값',
      }),
    );
    expect(config.serverUrl, 'https://weather.example.com');
  });

  test('운영 서버 실패 시 외부 API로 우회하지 않는다', () async {
    final service = WeatherService(
      _FailingApiClient(),
      serverRetryCount: 0,
      serverRetryDelay: Duration.zero,
    );
    final result = await service.fetchWeather(installationId: 'test');
    expect(result.mode, WeatherLoadMode.unavailable);
    expect(result.hasWeather, isFalse);
    expect(result.message, contains('운영 서버'));
  });

  test('운영 서버 날씨 묶음은 5초 간격으로 최대 3회 재시도한다', () async {
    final client = _RetryingApiClient(failuresBeforeSuccess: 3);
    final waits = <Duration>[];
    final service = WeatherService(
      client,
      serverRetryWait: (duration) async => waits.add(duration),
    );
    final result = await service.fetchServerWeather(installationId: 'test');
    expect(result.mode, WeatherLoadMode.server);
    expect(client.todayCalls, 4);
    expect(client.weeklyCalls, 4);
    expect(waits, List.filled(3, const Duration(seconds: 5)));
  });

  test('GPS 좌표와 준비물 카탈로그를 서버 요청에 전달한다', () async {
    final client = _RecordingApiClient();
    final service = WeatherService(client);
    final result = await service.fetchServerWeather(
      installationId: 'device-1',
      coordinates: const DeviceCoordinates(
        latitude: 37.2636,
        longitude: 127.0286,
      ),
    );
    expect(result.hasWeather, isTrue);
    expect(client.queries['/api/v1/weather/today'],
        containsPair('latitude', '37.2636'));
    expect(
        client.queries['/api/v1/weather/weekly'], isNot(contains('latitude')));
    expect(
      client.queries['/api/v1/weather/today'],
      containsPair('recommendationCatalog', 'PREPARATION_15'),
    );
    expect(
      client.queries['/api/v1/weather/weekly'],
      containsPair('recommendationCatalog', 'PREPARATION_15'),
    );
  });

  test('오늘 응답의 수신 시각을 저장하고 지역명 변경 뒤에도 유지한다', () async {
    final before = DateTime.now();
    final today = await WeatherService(_RecordingApiClient())
        .fetchTodayWeather(installationId: 'test');
    final after = DateTime.now();
    expect(today.receivedAt, isNotNull);
    expect(today.receivedAt!.isBefore(before), isFalse);
    expect(today.receivedAt!.isAfter(after), isFalse);
    expect(today.withRegionName('서울').receivedAt, today.receivedAt);
  });

  test('항동 Today·Week 요청에 행정구역 코드와 전체 지역명을 함께 전달한다', () async {
    final client = _RecordingApiClient();
    final service = WeatherService(client);

    await service.fetchServerWeather(
      installationId: 'device-hangdong',
      nx: 57,
      ny: 125,
      regionCode: '1153080000',
      regionName: '서울특별시 구로구 항동',
    );

    expect(client.queries['/api/v1/weather/today'], containsPair('nx', '57'));
    expect(client.queries['/api/v1/weather/today'], containsPair('ny', '125'));
    expect(
      client.queries['/api/v1/weather/today'],
      containsPair('regionCode', '1153080000'),
    );
    expect(
      client.queries['/api/v1/weather/today'],
      containsPair('regionName', '서울특별시 구로구 항동'),
    );
    expect(client.queries['/api/v1/weather/weekly'], containsPair('nx', '57'));
    expect(client.queries['/api/v1/weather/weekly'], containsPair('ny', '125'));
    expect(
      client.queries['/api/v1/weather/weekly'],
      containsPair('regionCode', '1153080000'),
    );
    expect(
      client.queries['/api/v1/weather/weekly'],
      containsPair('regionName', '서울특별시 구로구 항동'),
    );
  });
}

class _JsonAssetBundle extends CachingAssetBundle {
  final Map<String, dynamic> value;

  _JsonAssetBundle(this.value);

  @override
  Future<ByteData> load(String key) async {
    final bytes = Uint8List.fromList(utf8.encode(jsonEncode(value)));
    return ByteData.sublistView(bytes);
  }
}

class _FailingApiClient extends ApiClient {
  _FailingApiClient() : super(baseUrl: 'https://server.invalid');

  @override
  Future<Map<String, dynamic>> get(String path, {Map<String, String>? query}) {
    return Future.error(Exception('server unavailable'));
  }
}

class _RetryingApiClient extends ApiClient {
  final int failuresBeforeSuccess;
  int todayCalls = 0;
  int weeklyCalls = 0;

  _RetryingApiClient({required this.failuresBeforeSuccess})
      : super(baseUrl: 'https://server.example');

  @override
  Future<Map<String, dynamic>> get(String path,
      {Map<String, String>? query}) async {
    if (path.endsWith('/today')) {
      todayCalls++;
      if (todayCalls <= failuresBeforeSuccess) throw Exception('retry');
      return _todayJson;
    }
    weeklyCalls++;
    if (weeklyCalls <= failuresBeforeSuccess) throw Exception('retry');
    return {'days': <Map<String, dynamic>>[]};
  }
}

class _RecordingApiClient extends ApiClient {
  final Map<String, Map<String, String>> queries = {};

  _RecordingApiClient() : super(baseUrl: 'https://server.example');

  @override
  Future<Map<String, dynamic>> get(String path,
      {Map<String, String>? query}) async {
    queries[path] = query ?? {};
    if (path.endsWith('/today')) return _todayJson;
    return {'days': <Map<String, dynamic>>[]};
  }
}

final _todayJson = <String, dynamic>{
  'region': {'nx': 60, 'ny': 121, 'name': '테스트'},
  'current': {'temperature': 24},
  'hourly': <Map<String, dynamic>>[],
};
