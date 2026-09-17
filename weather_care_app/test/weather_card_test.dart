import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weather_care/features/home/tabs/main_tab.dart';
import 'package:weather_care/features/home/weather_labels.dart';
import 'package:weather_care/features/home/widgets/weather_card.dart';
import 'package:weather_care/models/weather.dart';

void main() {
  test('대기질 측정소명과 관측 시각을 읽고 없는 정보는 만들지 않는다', () {
    final current = CurrentWeather.fromJson({
      'current': {
        'pm10': 31,
        'airQualityStationName': ' 좌동 ',
        'airQualityObservedAt': '2026-09-10T09:00:00Z',
      },
    });
    expect(current.airQualityStationName, '좌동');
    expect(current.airQualityObservedAt, '2026-09-10T09:00:00Z');
    expect(CurrentWeather.fromJson({}).airQualityStationName, isNull);
    expect(CurrentWeather.fromJson({}).airQualityObservedAt, isNull);
  });

  for (final timestamp in [
    '2026-09-10T09:00:00Z',
    '2026-09-10T18:00:00+09:00'
  ]) {
    testWidgets('대기질 상세에 실제 측정소와 한국 관측 시각을 표시한다 ($timestamp)', (tester) async {
      await _pumpCard(
          tester,
          CurrentWeather(
            temperature: 22,
            pm10: 31,
            pm25: 12,
            airQualityStationName: '좌동',
            airQualityObservedAt: timestamp,
          ));
      for (final label in ['초미세먼지', '미세먼지']) {
        final detailButton =
            find.byKey(ValueKey('weather-metric-detail-$label'));
        await tester.ensureVisible(detailButton);
        await tester.tap(detailButton);
        await tester.pumpAndSettle();
        expect(
            find.textContaining('좌동 측정소 · 9월 10일 18시 00분 관측'), findsOneWidget);
        expect(find.textContaining('사용자 위치에서 직접 측정한 농도는 아니에요'), findsNothing);
        await tester.ensureVisible(detailButton);
        await tester.tap(detailButton);
        await tester.pumpAndSettle();
        expect(
          find.byKey(ValueKey('weather-metric-detail-content-$label')),
          findsNothing,
        );
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('측정소나 관측 시각이 없으면 지역명·예보 시각으로 대체하지 않는다', (tester) async {
    await _pumpCard(
        tester,
        const CurrentWeather(
          temperature: 22,
          pm10: 31,
          forecastAt: '2026-09-10T09:00:00Z',
          airQualityObservedAt: '2026-09-10T18:00:00',
        ));
    final detailButton =
        find.byKey(const ValueKey('weather-metric-detail-미세먼지'));
    await tester.ensureVisible(detailButton);
    await tester.tap(detailButton);
    await tester.pumpAndSettle();
    expect(find.textContaining('측정소 정보 없음 · 관측 시각 정보 없음'), findsOneWidget);
    expect(find.textContaining('18시'), findsNothing);
  });

  test('현재 기온의 결측과 실제 0도를 구분한다', () {
    expect(CurrentWeather.fromJson({}).temperature, isNull);
    expect(
      CurrentWeather.fromJson({
        'current': {'temperature': null}
      }).temperature,
      isNull,
    );
    final zero = CurrentWeather.fromJson({
      'current': {
        'temperature': 0,
        'apparentTemperature': 0,
        'humidity': 0,
        'windSpeed': 0,
        'uvIndex': 0,
        'pm10': 0,
        'pm25': 0,
      },
    });
    expect(zero.temperature, 0);
    expect(zero.apparentTemperature, 0);
    expect(zero.humidity, 0);
    expect(zero.windSpeed, 0);
    expect(zero.uvIndex, 0);
    expect(zero.pm10, 0);
    expect(zero.pm25, 0);
  });

  test('예상기온 시각은 한국시간을 사용하고 없는 시각은 만들지 않는다', () {
    for (final timestamp in [
      '2026-09-10T15:00:00+09:00',
      '2026-09-10T06:00:00Z',
      '2026-09-10T15:00:00',
    ]) {
      expect(forecastTemperatureLabel(timestamp), '오후 3시 예상기온');
    }
    expect(
      forecastTemperatureLabel('2026-09-10T15:00:00Z'),
      '오전 12시 예상기온',
    );
    expect(forecastTemperatureLabel(null), '예상기온');
    expect(forecastTemperatureLabel('unknown'), '예상기온');
    expect(forecastTemperatureLabel('2026-09-10'), '예상기온');
  });

  testWidgets('결측이어도 6개 지표를 유지하고 0이나 정상 등급으로 표시하지 않는다', (tester) async {
    await _pumpCard(tester, const CurrentWeather(temperature: null));

    expect(find.text('자료 없음'), findsNWidgets(7));
    expect(find.text('하늘 상태 자료 없음'), findsOneWidget);
    expect(find.text('미지원'), findsNothing);
    expect(find.text('0.0℃'), findsNothing);
    for (final label in ['체감', '습도', '풍속', '자외선', '초미세먼지', '미세먼지']) {
      final metric = find.byKey(ValueKey('weather-metric-$label'));
      final detailButton = find.byKey(ValueKey('weather-metric-detail-$label'));
      expect(metric, findsOneWidget);
      await tester.ensureVisible(detailButton);
      await tester.tap(detailButton);
      await tester.pumpAndSettle();
      expect(
        find.byKey(ValueKey('weather-metric-detail-content-$label')),
        findsOneWidget,
      );
      expect(find.textContaining('좋음 등급'), findsNothing);
      await tester.ensureVisible(detailButton);
      await tester.tap(detailButton);
      await tester.pumpAndSettle();
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('각 지표 상세는 수준을 먼저 보여주고 설명을 아래에 둔다', (tester) async {
    await _pumpCard(
      tester,
      const CurrentWeather(
        temperature: 25,
        apparentTemperature: 25,
        humidity: 72,
        windSpeed: 10,
        uvIndex: 7,
        pm25: 41,
        pm10: 91,
      ),
    );

    final expectedLevels = {
      '체감': '체감온도는 조금 더운 수준이에요',
      '습도': '실외 습도는 높은 수준이에요',
      '풍속': '바람은 강한 수준이에요',
      '자외선': '자외선은 높음 단계예요',
      '초미세먼지': '초미세먼지는 나쁨 등급이에요',
      '미세먼지': '미세먼지는 나쁨 등급이에요',
    };
    for (final entry in expectedLevels.entries) {
      final button = find.byKey(
        ValueKey('weather-metric-detail-${entry.key}'),
      );
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
      final level = find.byKey(
        ValueKey('weather-metric-level-${entry.key}'),
      );
      expect(level, findsOneWidget);
      expect(tester.widget<Text>(level).data, entry.value);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('실제 0은 단위와 함께 표시한다', (tester) async {
    await _pumpCard(
      tester,
      const CurrentWeather(
        temperature: 0,
        apparentTemperature: 0,
        humidity: 0,
        windSpeed: 0,
        uvIndex: 0,
        pm10: 0,
        pm25: 0,
        sky: '맑음',
      ),
    );
    expect(find.text('자료 없음'), findsNothing);
    expect(find.text('0.0℃'), findsNWidgets(2));
    expect(find.text('0%'), findsOneWidget);
    expect(find.text('0.0m/s'), findsOneWidget);
    expect(find.text('0.0'), findsOneWidget);
    expect(find.text('0㎍/㎥'), findsNWidgets(2));
  });

  testWidgets('초미세먼지가 없어도 PM10으로 대체하지 않고 각각 표시한다', (tester) async {
    await _pumpCard(tester, const CurrentWeather(temperature: 20, pm10: 42));
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('weather-metric-초미세먼지')),
        matching: find.text('자료 없음'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('weather-metric-미세먼지')),
        matching: find.text('42㎍/㎥'),
      ),
      findsOneWidget,
    );
  });

  for (final scale in [1.0, 2.0]) {
    testWidgets('360px에서 지표 순서와 큰 글씨를 유지한다 ($scale배)', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await _pumpCard(
        tester,
        const CurrentWeather(
          temperature: 29,
          forecastAt: '2026-09-10T06:00:00Z',
          apparentTemperature: 32.7,
          humidity: 72,
          windSpeed: 2.8,
          uvIndex: 7,
          pm25: 41,
          pm10: 80,
          sky: '구름 많음',
        ),
        scale: scale,
      );
      expect(find.text('오후 3시 예상기온'), findsOneWidget);
      expect(find.text('29.0℃'), findsOneWidget);
      expect(find.text('32.7℃'), findsOneWidget);
      expect(find.text('2.8m/s'), findsOneWidget);
      expect(find.text('41㎍/㎥'), findsOneWidget);
      expect(find.text('80㎍/㎥'), findsOneWidget);
      final first =
          tester.getTopLeft(find.byKey(const ValueKey('weather-metric-체감')));
      final second =
          tester.getTopLeft(find.byKey(const ValueKey('weather-metric-습도')));
      final third =
          tester.getTopLeft(find.byKey(const ValueKey('weather-metric-풍속')));
      expect(second.dx, first.dx);
      expect(second.dy, greaterThan(first.dy));
      expect(third.dx, first.dx);
      expect(third.dy, greaterThan(second.dy));

      for (final label in ['풍속', '초미세먼지', '미세먼지']) {
        final detailButton =
            find.byKey(ValueKey('weather-metric-detail-$label'));
        await tester.ensureVisible(detailButton);
        await tester.tap(detailButton);
        await tester.pumpAndSettle();
        final detail = find.byKey(
          ValueKey('weather-metric-detail-content-$label'),
        );
        expect(detail, findsOneWidget);
        expect(
          find.descendant(
            of: detail,
            matching: find.textContaining(label == '풍속'
                ? '2.8m/s'
                : label == '초미세먼지'
                    ? '41㎍/㎥'
                    : '80㎍/㎥'),
          ),
          findsOneWidget,
        );
        await tester.ensureVisible(detailButton);
        await tester.tap(detailButton);
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Main에서도 없는 예상기온을 0도로 표시하지 않는다', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: MainTab(
          today: TodayWeatherResponse(
            dataSource: 'test',
            region: const WeatherRegion(nx: 60, ny: 127, name: '서울'),
            brief: '테스트',
            current: const CurrentWeather(temperature: null),
            recommendations: const [],
            lifestyleMessages: const [],
            timeline: const [],
            hourly: const [],
          ),
          dateLabel: '9월 10일',
          mood: 'calm',
          serverFeaturesAvailable: true,
          onRefresh: () async {},
          onDetail: (_) {},
        ),
      ),
    ));
    expect(find.text('예상기온'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('main-apparent-temperature-row')),
        matching: find.text('자료 없음'),
      ),
      findsNWidgets(2),
    );
    expect(find.text('0.0℃'), findsNothing);
    expect(find.textContaining('하늘 상태 자료가 없어'), findsOneWidget);
    expect(find.textContaining('맑은 하늘'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Main 체감 문구는 실제 기온과의 차이를 먼저 설명한다', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: MainTab(
          today: const TodayWeatherResponse(
            dataSource: 'test',
            region: WeatherRegion(nx: 60, ny: 127, name: '서울'),
            brief: '테스트',
            current: CurrentWeather(
              temperature: 29,
              apparentTemperature: 27,
              sky: '맑음',
            ),
            recommendations: [],
            lifestyleMessages: [],
            timeline: [],
            hourly: [],
          ),
          dateLabel: '9월 16일',
          mood: 'clear',
          serverFeaturesAvailable: true,
          onRefresh: () async {},
          onDetail: (_) {},
        ),
      ),
    ));

    expect(
      find.text(
        '맑은 하늘이 이어지는 날씨예요. 실제 기온보다 2.0℃ 낮지만, '
        '체감 상 조금 덥게 느껴질 수 있어요.',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpCard(
  WidgetTester tester,
  CurrentWeather current, {
  double scale = 1,
}) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(scale)),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: WeatherInfoCard(current: current),
        ),
      ),
    ),
  ));
}
