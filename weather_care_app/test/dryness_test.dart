import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weather_care/features/home/weather_labels.dart';
import 'package:weather_care/features/home/widgets/preparation_icon.dart';
import 'package:weather_care/features/home/widgets/weather_card.dart';
import 'package:weather_care/models/app_settings.dart';
import 'package:weather_care/models/lifestyle_message.dart';
import 'package:weather_care/models/recommendation.dart';
import 'package:weather_care/models/weather.dart';

void main() {
  test('건조도 경계와 결측을 구분한다', () {
    for (final entry in {
      40.1: '건조하지 않음',
      40.0: '약한 건조',
      30.1: '약한 건조',
      30.0: '건조',
      20.1: '건조',
      20.0: '매우 건조',
      0.0: '매우 건조',
    }.entries) {
      expect(drynessDescription(entry.key), entry.value);
    }
    for (final value in [null, double.nan, double.infinity, -1.0, 101.0]) {
      expect(drynessDescription(value), isNull);
    }
  });

  test('새 준비물과 건조도 API 종류를 구분하고 설정을 보존한다', () {
    for (final type in [
      RecommendationType.lipBalm,
      RecommendationType.handCream,
      RecommendationType.portableHumidifier
    ]) {
      expect(WeatherRecommendation.fromJson({'type': type.apiName}).type, type);
    }
    expect(LifestyleMessage.fromJson({'type': 'DRYNESS_GUIDANCE'}).type,
        LifestyleMessageType.drynessGuidance);
    final settings =
        AppSettings.fallback('test').copyWith(drynessEnabled: false);
    expect(
        AppSettings.fromJson(settings.toJson(), settings.installationId)
            .drynessEnabled,
        isFalse);
  });

  for (final scale in [1.0, 2.0]) {
    testWidgets('좁은 화면·글자 $scale배에서 건조도와 실내 관리 안내를 표시한다', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(
          home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(scale)),
        child: Scaffold(
            body: SingleChildScrollView(
                child: Column(children: [
          Row(children: [
            for (final type in [
              RecommendationType.lipBalm,
              RecommendationType.handCream,
              RecommendationType.portableHumidifier
            ])
              PreparationIcon(type: type, size: 48),
          ]),
          const WeatherInfoCard(
              current: CurrentWeather(temperature: 20, humidity: 20), showCurrentSummary: false),
        ]))),
      )));
      final metric = find.byKey(const ValueKey('weather-metric-건조도'));
      expect(find.descendant(of: metric, matching: find.text('매우 건조\n20%')),
          findsOneWidget);
      final detail = find.byKey(const ValueKey('weather-metric-detail-건조도'));
      await tester.ensureVisible(detail);
      await tester.tap(detail);
      await tester.pumpAndSettle();
      expect(find.textContaining('실내 습도도 확인'), findsOneWidget);
      expect(find.textContaining('립밤'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
