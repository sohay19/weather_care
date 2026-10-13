import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weather_care/features/home/widgets/preparation_icon.dart';
import 'package:weather_care/models/recommendation.dart';

void main() {
  test('새 준비물 API 키를 각각 올바른 종류로 해석한다', () {
    for (final type in [
      RecommendationType.lightOuterwear,
      RecommendationType.sunHat,
      RecommendationType.slipResistantShoes,
    ]) {
      expect(recommendationTypeFromApiName(type.apiName), type);
    }
  });

  test('PNG 15종의 API 키를 준비물 종류로 해석한다', () {
    final imageTypes = RecommendationType.values
        .where((type) => type.assetPath != null)
        .toList(growable: false);

    for (final type in imageTypes) {
      final recommendation = WeatherRecommendation.fromJson({
        'type': type.apiName,
        'recommended': true,
      });
      expect(recommendation.type, type);
    }
  });

  testWidgets('제공된 준비물 PNG 15종을 불러온다', (tester) async {
    final imageTypes = RecommendationType.values
        .where((type) => type.assetPath != null)
        .toList(growable: false);

    expect(imageTypes, hasLength(15));

    await tester.pumpWidget(
      MaterialApp(
        home: Wrap(
          children: [
            for (final type in imageTypes)
              PreparationIcon(type: type, size: 32),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(Image), findsNWidgets(15));
    expect(tester.takeException(), isNull);
  });
}
