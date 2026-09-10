import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:weather_care/models/weather.dart';
import 'package:weather_care/services/api_client.dart';
import 'package:weather_care/services/app_config.dart';
import 'package:weather_care/services/kma_direct_weather_service.dart';
import 'package:weather_care/services/weather_service.dart';
import 'package:weather_care/services/current_location_service.dart';

void main() {
  late MockClient kmaClient;

  setUp(() {
    kmaClient = MockClient((request) async {
      expect(request.url.queryParameters['serviceKey'], 'test+key');
      return http.Response(
        jsonEncode({
          'response': {
            'header': {'resultCode': '00', 'resultMsg': 'NORMAL_SERVICE'},
            'body': {
              'items': {
                'item': [
                  ..._slot('20260820', '1000', {
                    'TMP': '28',
                    'REH': '70',
                    'WSD': '2.2',
                    'POP': '20',
                    'PCP': '강수없음',
                    'SNO': '적설없음',
                    'PTY': '0',
                    'SKY': '3',
                  }),
                  ..._slot('20260820', '1100', {
                    'TMP': '29',
                    'REH': '72',
                    'WSD': '2.8',
                    'POP': '70',
                    'PCP': '1.0mm 미만',
                    'SNO': '적설없음',
                    'PTY': '1',
                    'SKY': '4',
                  }),
                  _item('20260820', '0600', 'TMN', '22'),
                  _item('20260820', '1500', 'TMX', '31'),
                ],
              },
            },
          },
        }),
        200,
        headers: const {'content-type': 'application/json'},
      );
    });
  });

  test('KMA 설정 자산은 빌드 모드와 무관하게 로드된다', () async {
    final config = await AppConfig.load(
      bundle: _JsonAssetBundle({
        'SERVER_URL': 'https://weather.example.com',
        'KMA_SERVICE_KEY': 'asset-key',
      }),
    );

    expect(config.serverUrl, 'https://weather.example.com');
    expect(config.kmaServiceKey, 'asset-key');
  });

  test('앱 직접 조회도 기상청 계절별 체감온도 산식을 사용한다', () {
    expect(
      calculateKmaApparentTemperature(
        28,
        humidity: 70,
        windSpeed: 2.2,
        forecastAt: DateTime.parse('2026-08-20T01:00:00Z'),
      ),
      29.3,
    );
    expect(
      calculateKmaApparentTemperature(
        0,
        humidity: 60,
        windSpeed: 1.3,
        forecastAt: DateTime.parse('2026-02-20T01:00:00Z'),
      ),
      -1.4,
    );
  });

  test('앱 직접 기상청 조회는 원시 날씨와 기상청 체감온도를 제공한다', () async {
    final direct = KmaDirectWeatherService(
      serviceKey: 'test%2Bkey',
      client: kmaClient,
      now: () => DateTime.parse('2026-08-20T01:00:00Z'),
    );

    final bundle = await direct.fetch(nx: 60, ny: 121);

    expect(bundle.today.dataSource, '기상청 직접 조회');
    expect(bundle.today.current.temperature, 28);
    expect(bundle.today.current.apparentTemperature, 29.3);
    expect(bundle.today.hourly.first.apparentTemperature, 29.3);
    expect(bundle.today.hourly.first.time, '10');
    expect(bundle.today.hourly.first.forecastDate, '2026-08-20');
    expect(bundle.today.recommendations, isEmpty);
    expect(bundle.today.lifestyleMessages, isEmpty);
    expect(bundle.today.timeline, isEmpty);
    expect(bundle.weekly.days.single.recommendations, isEmpty);
    expect(bundle.weekly.days.single.forecastDate, '2026-08-20');
    expect(bundle.weekly.days.single.date, '목');
    expect(bundle.weekly.days.single.weatherDataComplete, isTrue);
    expect(bundle.weekly.days.single.minTemperatureSource, 'DAILY');
    expect(bundle.weekly.days.single.maxTemperatureSource, 'DAILY');
    expect(bundle.weekly.days.single.recommendationsAvailable, isFalse);
  });

  test('운영 서버 실패 시 기상청 직접 조회로 전환한다', () async {
    final service = WeatherService(
      _FailingApiClient(),
      directKma: KmaDirectWeatherService(
        serviceKey: 'test%2Bkey',
        client: kmaClient,
        now: () => DateTime.parse('2026-08-20T01:00:00Z'),
      ),
      internetProbe: () async => true,
    );

    final result = await service.fetchWeather(installationId: 'test');

    expect(result.mode, WeatherLoadMode.directKma);
    expect(result.hasWeather, isTrue);
    expect(result.serverFeaturesAvailable, isFalse);
  });

  test('운영 서버와 앱 단기예보 조회를 선택적으로 실행할 수 있다', () async {
    final service = WeatherService(
      _FailingApiClient(),
      directKma: KmaDirectWeatherService(
        serviceKey: 'test%2Bkey',
        client: kmaClient,
        now: () => DateTime.parse('2026-08-20T01:00:00Z'),
      ),
      internetProbe: () async => true,
    );

    final serverResult = await service.fetchServerWeather(
      installationId: 'test',
    );
    expect(serverResult.hasWeather, isFalse);
    expect(serverResult.mode, WeatherLoadMode.unavailable);

    final directResult = await service.fetchDirectWeather();
    expect(directResult.hasWeather, isTrue);
    expect(directResult.mode, WeatherLoadMode.directKma);
  });

  test('GPS 좌표는 현재 강수 조회에만 전달한다', () async {
    final client = _RecordingApiClient();
    final service = WeatherService(
      client,
      directKma: KmaDirectWeatherService(serviceKey: ''),
    );

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
    expect(client.queries['/api/v1/weather/today'],
        containsPair('longitude', '127.0286'));
    expect(
        client.queries['/api/v1/weather/weekly'], isNot(contains('latitude')));
  });

  test('시간대 예보는 forecastAt과 눈 예상 파생값을 사용한다', () {
    final response = TodayWeatherResponse.fromJson({
      'region': {'nx': 60, 'ny': 121, 'name': '수원'},
      'current': {'temperature': 0},
      'hourly': [
        {
          'forecastAt': '2026-08-20T18:00:00+09:00',
          'temperature': 0,
          'snowExpected': true,
          'snowfallAmount': 1.2,
        },
      ],
    });

    expect(response.hourly.single.time, '18');
    expect(response.hourly.single.forecastDate, '2026-08-20');
    expect(response.hourly.single.snowExpected, isTrue);
    expect(response.hourly.single.snowfallAmount, 1.2);
  });

  test('직접 조회에서도 기온 누락 슬롯을 유지하고 나머지 결측을 0으로 채우지 않는다', () async {
    final bundle = await _fetchPartialSlots([
      ..._slot('20260820', '1000', {'REH': '70'}),
      ..._slot('20260820', '1100', {
        'TMP': '0',
        'WSD': '0',
        'POP': '0',
        'PCP': '강수없음',
        'SNO': '적설없음',
        'PTY': '0',
        'SKY': '1',
      }),
      _item('20260820', '1500', 'TMX', '3'),
    ]);
    expect(bundle.today.hourly, hasLength(2));
    final missing = bundle.today.hourly.first;
    expect(missing.time, '10');
    expect(missing.temperature, isNull);
    expect(missing.apparentTemperature, isNull);
    expect(missing.windSpeed, isNull);
    expect(missing.precipitationProbability, isNull);
    expect(missing.precipitationAmount, isNull);
    expect(missing.snowExpected, isNull);
    expect(missing.snowfallAmount, isNull);
    expect(missing.skyCondition, isNull);
    expect(bundle.today.current.temperature, isNull);
    expect(bundle.today.current.sky, isNull);
    final zero = bundle.today.hourly.last;
    expect(zero.temperature, 0);
    expect(zero.windSpeed, 0);
    expect(zero.precipitationProbability, 0);
    expect(zero.precipitationAmount, 0);
    expect(zero.snowExpected, isFalse);
    expect(zero.snowfallAmount, 0);
    expect(zero.skyCondition, '맑음');
    expect(bundle.weekly.days.single.min, 0);
    expect(bundle.weekly.days.single.max, 3);
    expect(bundle.weekly.days.single.weatherDataComplete, isFalse);
    expect(bundle.weekly.days.single.minTemperatureSource, 'HOURLY');
    expect(bundle.weekly.days.single.maxTemperatureSource, 'DAILY');
  });

  test('직접 조회의 모든 기온이 누락돼도 일 최저·최고를 0으로 계산하지 않는다', () async {
    final bundle = await _fetchPartialSlots([
      ..._slot('20260820', '1000', {'WSD': '2'}),
      ..._slot('20260820', '1100', {'REH': '50'}),
    ]);
    expect(bundle.today.hourly, hasLength(2));
    expect(bundle.weekly.days.single.min, isNull);
    expect(bundle.weekly.days.single.max, isNull);
    expect(bundle.weekly.days.single.weatherLabel, '정보 없음');
  });

  test('직접 조회의 미만 범위를 상한값으로 바꾸지 않고 비정상 자료를 결측으로 유지한다', () async {
    final bundle = await _fetchPartialSlots([
      ..._slot('20260820', '1000', {
        'TMP': '5',
        'PTY': '3',
        'PCP': '1.0mm 미만',
        'SNO': '0.5cm 미만',
      }),
      ..._slot('20260820', '1100', {
        'TMP': 'NaN',
        'WSD': '--',
        'POP': '자료없음',
        'PCP': '확인 불가',
        'SNO': '자료없음',
        'SKY': '1',
      }),
    ]);
    final range = bundle.today.hourly.first;
    expect(range.precipitationAmount, 0);
    expect(range.precipitationAmountLabel, '1.0mm 미만');
    expect(range.snowfallAmount, 0);
    expect(range.snowfallAmountLabel, '0.5cm 미만');
    expect(range.snowExpected, isTrue);
    expect(range.skyCondition, '눈');
    final missing = bundle.today.hourly.last;
    expect(missing.temperature, isNull);
    expect(missing.windSpeed, isNull);
    expect(missing.precipitationProbability, isNull);
    expect(missing.precipitationAmount, isNull);
    expect(missing.precipitationAmountLabel, isNull);
    expect(missing.snowfallAmount, isNull);
    expect(missing.snowfallAmountLabel, isNull);
    expect(missing.skyCondition, isNull);
  });

  test('인터넷 연결이 없으면 날씨 미지원 상태를 반환한다', () async {
    final service = WeatherService(
      _FailingApiClient(),
      directKma: KmaDirectWeatherService(serviceKey: ''),
      internetProbe: () async => false,
    );

    final result = await service.fetchWeather(installationId: 'test');

    expect(result.mode, WeatherLoadMode.offline);
    expect(result.hasWeather, isFalse);
    expect(result.message, contains('인터넷 연결 불가'));
  });
}

Future<DirectKmaWeatherBundle> _fetchPartialSlots(
    List<Map<String, dynamic>> items) {
  return KmaDirectWeatherService(
    serviceKey: 'test-key',
    now: () => DateTime.parse('2026-08-20T01:00:00Z'),
    client: MockClient((_) async => http.Response(
        jsonEncode({
          'response': {
            'header': {'resultCode': '00'},
            'body': {
              'items': {'item': items}
            },
          },
        }),
        200,
        headers: {'content-type': 'application/json'})),
  ).fetch(nx: 60, ny: 121);
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
  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, String>? query,
  }) {
    return Future.error(Exception('server unavailable'));
  }
}

class _RecordingApiClient extends ApiClient {
  _RecordingApiClient() : super(baseUrl: 'https://server.example');

  final Map<String, Map<String, String>> queries = {};

  @override
  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, String>? query,
  }) async {
    queries[path] = query ?? {};
    if (path.endsWith('/today')) {
      return {
        'region': {'nx': 60, 'ny': 121, 'name': '수원'},
        'current': {'temperature': 24},
      };
    }
    return {'days': <Map<String, dynamic>>[]};
  }
}

List<Map<String, dynamic>> _slot(
  String date,
  String time,
  Map<String, String> values,
) {
  return values.entries
      .map((entry) => _item(date, time, entry.key, entry.value))
      .toList();
}

Map<String, dynamic> _item(
  String date,
  String time,
  String category,
  String value,
) {
  return {
    'baseDate': '20260820',
    'baseTime': '0800',
    'category': category,
    'fcstDate': date,
    'fcstTime': time,
    'fcstValue': value,
    'nx': 60,
    'ny': 121,
  };
}
