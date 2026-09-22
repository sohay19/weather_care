import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:weather_care/features/home/widgets/recommendation_bag_section.dart';
import 'package:weather_care/models/recommendation.dart';
import 'package:weather_care/models/weather.dart';
import 'package:weather_care/services/preparation_checklist_repository.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  const repository = PreparationChecklistRepository();

  test('한국시간 날짜와 자정은 기기 시간대에 의존하지 않는다', () {
    final before = DateTime.parse('2026-09-10T23:59:59+09:00');
    final after = DateTime.parse('2026-09-10T15:00:00Z');
    expect(preparationDateInKorea(before), '2026-09-10');
    expect(untilPreparationMidnight(before), const Duration(seconds: 1));
    expect(preparationDateInKorea(after), '2026-09-11');
    expect(untilPreparationMidnight(after), const Duration(days: 1));
  });

  test('저장 직후 재조회와 저장소 재생성은 같은 날 체크를 복원한다', () async {
    final save = repository.save('2026-09-10', {RecommendationType.umbrella});
    final load = const PreparationChecklistRepository().load('2026-09-10');
    await save;
    expect(await load, {RecommendationType.umbrella});
    expect(await repository.load('2026-09-11'), isEmpty);
    await repository.save('2026-09-11', {RecommendationType.mask});
    expect(await repository.load('2026-09-11'), {RecommendationType.mask});
    await repository.save('2026-09-11', {});
    expect(await repository.load('2026-09-11'), isEmpty);
  });

  test('손상 자료와 알 수 없는 준비물은 체크로 해석하지 않는다', () async {
    const key = 'weather_care_preparation_checklist_v1';
    final prefs = await SharedPreferences.getInstance();
    for (final raw in ['not json', '[]', '{"date":"2026-09-10","checked":7}']) {
      await prefs.setString(key, raw);
      expect(await repository.load('2026-09-10'), isEmpty);
    }
    await prefs.setString(
        key,
        jsonEncode({
          'date': '2026-09-10',
          'checked': ['MASK', 'UNKNOWN', 1, 'MASK'],
        }));
    expect(await repository.load('2026-09-10'), {RecommendationType.mask});
  });

  testWidgets('체크는 지역·추천 변경과 화면 재생성 후에도 유지되고 해제도 저장된다', (tester) async {
    final now = DateTime.parse('2026-09-10T12:00:00+09:00');
    await tester.pumpWidget(bag(now: () => now));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('bag-item-umbrella')));
    await tester.pumpAndSettle();
    expect(find.text('챙겼어요'), findsOneWidget);

    await tester.pumpWidget(bag(now: () => now, visible: false));
    await tester.pumpAndSettle();
    await tester.pumpWidget(bag(now: () => now, region: '부산'));
    await tester.pumpAndSettle();
    expect(find.text('챙겼어요'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(bag(now: () => now));
    await tester.pumpAndSettle();
    expect(find.text('챙겼어요'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('bag-item-umbrella')));
    await tester.pumpAndSettle();
    expect(await repository.load('2026-09-10'), isEmpty);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('앱을 켜둔 상태와 백그라운드 복귀 모두 한국시간 자정에 초기화한다', (tester) async {
    var now = DateTime.parse('2026-09-10T23:59:59+09:00');
    await repository.save('2026-09-10', {RecommendationType.umbrella});
    await tester.pumpWidget(bag(now: () => now));
    await tester.pumpAndSettle();
    expect(find.text('챙겼어요'), findsOneWidget);
    now = now.add(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('챙길게요'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('bag-item-umbrella')));
    await tester.pumpAndSettle();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    now = now.add(const Duration(days: 1));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.text('챙길게요'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('복원 대기 중 터치와 지난 날짜의 늦은 응답은 새 상태를 덮지 않는다', (tester) async {
    var now = DateTime.parse('2026-09-10T23:59:59+09:00');
    final delayed = DelayedRepository();
    await tester.pumpWidget(bag(now: () => now, repository: delayed));
    expect(find.text('확인 중'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('bag-item-umbrella')));
    expect(delayed.saves, 0);
    now = now.add(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    delayed.previousDay.complete({RecommendationType.umbrella});
    await tester.pumpAndSettle();
    expect(find.text('챙길게요'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('저장 실패를 안내하고 이전 상태를 유지한 뒤 다시 저장할 수 있다', (tester) async {
    final failing = FailingRepository();
    await tester.pumpWidget(bag(
      now: () => DateTime.utc(2026, 9, 10),
      repository: failing,
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('bag-item-umbrella')));
    await tester.pumpAndSettle();
    expect(find.text('챙길게요'), findsOneWidget);
    expect(find.text('체크 상태를 저장하지 못했어요.\n다시 눌러주세요'), findsOneWidget);
    failing.failSave = false;
    await tester.tap(find.byKey(const ValueKey('bag-item-umbrella')));
    await tester.pumpAndSettle();
    expect(find.text('챙겼어요'), findsOneWidget);
    expect(await repository.load('2026-09-10'), {RecommendationType.umbrella});
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('읽기 실패 시 체크를 막고 재시도로 기존 체크를 복원한다', (tester) async {
    await repository.save('2026-09-10', {RecommendationType.umbrella});
    final failing = FailingRepository()..failLoad = true;
    await tester.pumpWidget(bag(
      now: () => DateTime.utc(2026, 9, 10),
      repository: failing,
    ));
    await tester.pumpAndSettle();
    expect(find.text('확인 필요'), findsOneWidget);
    failing.failLoad = false;
    await tester.tap(find.text('체크 상태를 불러오지 못했어요 · 다시 시도'));
    await tester.pumpAndSettle();
    expect(find.text('챙겼어요'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('현재 브리핑의 준비물을 추천 엔진 결과 없이도 표시하고 경계에서 교체한다', (tester) async {
    var now = DateTime.parse('2026-09-10T12:30:00+09:00');
    BriefingTimelineEntry entry(
      String scene,
      String from,
      String until,
      String item,
    ) =>
        BriefingTimelineEntry(
          briefingId: scene,
          sceneId: scene,
          validFrom: from,
          validUntil: until,
          recommendedItems: [item],
          copy: const BriefingCopy(
            short: '현재 안내',
            medium: '현재 시각 안내',
            long: '현재 시각의 긴 안내',
            notificationTitle: '날씨 안내',
            notificationBody: '현재 시각 안내',
          ),
        );
    Widget currentBag() => MaterialApp(
          home: Scaffold(
            body: RecommendationBagSection(
              regionName: '서울',
              now: () => now,
              recommendations: const [],
              briefingTimeline: [
                entry(
                  'HUMIDITY_LOW',
                  '2026-09-10T12:00:00+09:00',
                  '2026-09-10T13:00:00+09:00',
                  'WATER',
                ),
                entry(
                  'RAIN',
                  '2026-09-10T13:00:00+09:00',
                  '2026-09-10T14:00:00+09:00',
                  'UMBRELLA',
                ),
              ],
              onDetail: (_) {},
            ),
          ),
        );

    await tester.pumpWidget(currentBag());
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('bag-item-water')), findsOneWidget);
    expect(find.byKey(const ValueKey('bag-item-umbrella')), findsNothing);

    now = DateTime.parse('2026-09-10T13:00:00+09:00');
    await tester.pumpWidget(currentBag());
    await tester.pump();
    expect(find.byKey(const ValueKey('bag-item-water')), findsNothing);
    expect(find.byKey(const ValueKey('bag-item-umbrella')), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}

Widget bag({
  required DateTime Function() now,
  PreparationChecklistRepository repository =
      const PreparationChecklistRepository(),
  bool visible = true,
  String region = '수원',
}) =>
    MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
      child: RecommendationBagSection(
        regionName: region,
        now: now,
        checklistRepository: repository,
        recommendations: [
          if (visible)
            WeatherRecommendation(
              type: RecommendationType.umbrella,
              recommended: true,
              priority: 90,
              title: '우산',
              description: '비가 내릴 수 있어요',
              notificationEligible: true,
            )
        ],
        onDetail: (_) {},
      ),
    )));

class DelayedRepository extends PreparationChecklistRepository {
  final previousDay = Completer<Set<RecommendationType>>();
  int saves = 0;

  @override
  Future<Set<RecommendationType>> load(String date) async {
    if (date == '2026-09-10') return previousDay.future;
    return <RecommendationType>{};
  }

  @override
  Future<void> save(String date, Set<RecommendationType> checked) async {
    saves++;
  }
}

class FailingRepository extends PreparationChecklistRepository {
  bool failSave = true;
  bool failLoad = false;

  @override
  Future<Set<RecommendationType>> load(String date) async {
    if (failLoad) throw StateError('read failed');
    return super.load(date);
  }

  @override
  Future<void> save(String date, Set<RecommendationType> checked) async {
    if (failSave) throw StateError('write failed');
    return super.save(date, checked);
  }
}
