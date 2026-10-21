import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weather_care/models/home_widget_snapshot.dart';
import 'package:weather_care/services/home_widget_service.dart';

const _snapshot = HomeWidgetSnapshot(
    generatedAt: '2026-10-21T04:00:00Z',
    locationKey: '60:121',
    briefingId: '',
    sceneId: '',
    validFrom: '',
    validUntil: '',
    nextBriefingBoundary: '',
    dataFreshUntil: '',
    briefingTimeline: [],
    region: '검증 지역',
    refreshTime: '13:00',
    condition: '맑음',
    currentTemperature: '16°',
    apparentTemperature: '12°',
    minimumTemperature: '13°',
    maximumTemperature: '16°',
    shortMessage: '',
    brief: '',
    nextTime: '',
    nextCondition: '',
    nextTemperature: '',
    preparations: [],
    preparationCatalog: []);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.codesoha.weathercare/home-widget');
  final calls = <MethodCall>[];
  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return null;
    });
  });
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('시험 위젯 인증키는 URL이나 날씨 자료에 넣지 않고 별도 필드로 전달한다', () async {
    const url =
        'https://weather-test-api.codesoha.com/api/v1/weather/widget?nx=60&ny=121';
    await const HomeWidgetService()
        .publish(_snapshot, refreshUrl: url, testAccessKey: 'test-key');
    final values = calls.single.arguments as Map;
    expect(values['testAccessKey'], 'test-key');
    expect(values['refreshUrl'], url);
    expect(values['snapshot'], isNot(contains('test-key')));
  });

  test('운영·다른 호스트·HTTP 위젯에는 시험 인증키를 전달하지 않는다', () async {
    for (final url in [
      'https://weather-api.codesoha.com/widget',
      'https://weather-test-api.codesoha.com.example.org/widget',
      'http://weather-test-api.codesoha.com/widget',
    ]) {
      await const HomeWidgetService()
          .publish(_snapshot, refreshUrl: url, testAccessKey: 'test-key');
      expect(calls.last.arguments as Map, isNot(contains('testAccessKey')));
    }
  });

  test('GPS 모드와 측정 시각을 양 플랫폼 위젯에 전달한다', () async {
    for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
      debugDefaultTargetPlatformOverride = platform;
      final measuredAt = DateTime.parse('2026-10-21T14:00:00+09:00');
      await const HomeWidgetService()
          .publish(_snapshot, gpsEnabled: true, locationMeasuredAt: measuredAt);
      final values = calls.last.arguments as Map;
      expect(values['gpsEnabled'], true);
      expect(values['locationMeasuredAt'], '2026-10-21T05:00:00.000Z');
      await const HomeWidgetService().publish(_snapshot);
      expect((calls.last.arguments as Map)['gpsEnabled'], false);
      expect(
          calls.last.arguments as Map, isNot(contains('locationMeasuredAt')));
    }
  });

  test('키 없는 저장과 위젯 삭제에는 인증키를 보내지 않는다', () async {
    await const HomeWidgetService().publish(_snapshot,
        refreshUrl: 'https://weather-test-api.codesoha.com/widget');
    expect(calls.single.arguments as Map, isNot(contains('testAccessKey')));
    await const HomeWidgetService().clear();
    expect(calls.last.method, 'clear');
    expect(calls.last.arguments, isNull);
  });
}
