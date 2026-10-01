import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weather_care/features/home/tabs/main_tab.dart';
import 'package:weather_care/features/home/weather_data_phase.dart';
import 'package:weather_care/features/home/weather_labels.dart';
import 'package:weather_care/features/home/widgets/weather_brief_text.dart';
import 'package:weather_care/models/weather.dart';

void main() {
  const action = '자외선이 강할 수 있으니, 오후 3시 외출한다면 양산이나 모자를 준비하세요';
  late DateTime now;
  setUp(() => now = DateTime.parse('2026-09-10T14:59:59+09:00'));

  Widget subject(
          {String? expiry = '2026-09-10T15:00:00+09:00',
          String text = action}) =>
      MaterialApp(
          home: Scaffold(
              body: WeatherBriefText(
        text: text,
        expiresAt: expiry,
        now: () => now,
      )));

  testWidgets('만료 전에는 서버 문구를 그대로 표시하고 경계에 도달하면 제거한다', (tester) async {
    await tester.pumpWidget(subject());
    expect(find.text(action), findsOneWidget);
    now = now.add(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text(action), findsNothing);
    expect(find.text('최신 날씨를 확인해 주세요.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  for (final expiry in [
    '2026-09-10T14:59:59+09:00',
    '2026-09-10T05:59:59Z',
    '2026-09-09T23:59:59Z'
  ]) {
    testWidgets('이미 만료된 응답을 처음 열어도 안내하지 않는다: $expiry', (tester) async {
      await tester.pumpWidget(subject(expiry: expiry));
      expect(find.text(action), findsNothing);
      expect(find.text('최신 날씨를 확인해 주세요.'), findsOneWidget);
    });
  }

  for (final expiry in ['', 'invalid', '2026-09-10', '2026-09-10T15:00:00']) {
    testWidgets('만료 시각이 잘못되었거나 시간대가 없으면 확인 불가 안내: $expiry', (tester) async {
      await tester.pumpWidget(subject(expiry: expiry));
      expect(find.text(action), findsNothing);
      expect(find.textContaining('안내 시간을 확인하기 어려워요.'), findsOneWidget);
    });
  }

  testWidgets('만료 정보가 없는 이전 응답은 기존 문구를 유지한다', (tester) async {
    await tester.pumpWidget(subject(expiry: null));
    now = now.add(const Duration(days: 1));
    await tester.pump(const Duration(days: 1));
    expect(find.text(action), findsOneWidget);
  });

  testWidgets('다른 날·구버전 기본 문구는 새 오늘 안내로 대체한다', (tester) async {
    for (final text in [
      '내일 오후 2시 비가 와요',
      '모레 오전 9시 자외선이 강해요',
      '글피 바람이 강해요',
      '다음 날 눈이 와요',
      '오늘은 외출 전에 시간별 예보를 확인하세요',
    ]) {
      await tester.pumpWidget(subject(text: text));
      expect(find.text(text), findsNothing);
      expect(
        find.text('오늘은 특별한 예보가 없으나, 외출 전에 시간별 예보를 확인해보세요'),
        findsOneWidget,
      );
    }
  });

  testWidgets('앱으로 복귀할 때 실제 시각을 확인해 지난 문구를 제거한다', (tester) async {
    await tester.pumpWidget(subject());
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    now = now.add(const Duration(minutes: 5));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(find.text(action), findsNothing);
    expect(find.text('최신 날씨를 확인해 주세요.'), findsOneWidget);
  });

  testWidgets('시계가 앞으로 조정되어도 주기 점검으로 만료를 반영한다', (tester) async {
    await tester.pumpWidget(subject(expiry: '2026-09-10T16:00:00+09:00'));
    now = now.add(const Duration(hours: 2));
    await tester.pump(const Duration(minutes: 1));
    expect(find.text(action), findsNothing);
  });

  testWidgets('서버 timeline 경계에서 앱 재조회 없이 다음 scene으로 바꾼다', (tester) async {
    const copyUv = BriefingCopy(
      short: '자외선이 강해요.',
      medium: '낮 동안 자외선이 강해요. 양산을 챙기세요.',
      long: '낮 동안 자외선이 강해요.',
      notificationTitle: '자외선 안내',
      notificationBody: '양산을 챙기세요.',
    );
    const copyEvening = BriefingCopy(
      short: '선선한 날씨예요.',
      medium: '해가 진 뒤에는 선선하고 편안해요.',
      long: '해가 진 뒤에는 선선하고 편안해요.',
      notificationTitle: '저녁 날씨',
      notificationBody: '선선한 날씨예요.',
    );
    final timeline = [
      const BriefingTimelineEntry(
        briefingId: 'uv',
        sceneId: 'UV',
        validFrom: '2026-09-10T09:40:00Z',
        validUntil: '2026-09-10T09:47:00Z',
        copy: copyUv,
      ),
      const BriefingTimelineEntry(
        briefingId: 'evening',
        sceneId: 'THERMAL_COMFORTABLE',
        validFrom: '2026-09-10T09:47:00Z',
        validUntil: '2026-09-10T15:00:00Z',
        copy: copyEvening,
      ),
    ];
    now = DateTime.parse('2026-09-10T18:46:59+09:00');
    await tester.pumpWidget(MaterialApp(
      home: WeatherBriefText(text: action, timeline: timeline, now: () => now),
    ));
    expect(find.text(copyUv.medium), findsOneWidget);
    now = now.add(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text(copyEvening.medium), findsOneWidget);
    expect(find.textContaining('자외선'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('서버 시계가 2초 빠른 응답은 브리핑을 즉시 표시한다', (tester) async {
    const entry = BriefingTimelineEntry(
      briefingId: 'uv',
      sceneId: 'UV',
      validFrom: '2026-09-10T06:00:01Z',
      validUntil: '2026-09-10T07:00:00Z',
      copy: BriefingCopy(
        short: '자외선 안내',
        medium: '양산을 챙기세요.',
        long: '양산을 챙기세요.',
        notificationTitle: '자외선 안내',
        notificationBody: '양산을 챙기세요.',
      ),
    );
    await tester.pumpWidget(MaterialApp(
      home: WeatherBriefText(
          text: action, timeline: const [entry], now: () => now),
    ));
    expect(find.text('양산을 챙기세요.'), findsOneWidget);
    expect(find.text('최신 날씨를 확인해 주세요.'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('시작까지 10초가 넘는 브리핑은 미리 표시하지 않는다', (tester) async {
    const entry = BriefingTimelineEntry(
      briefingId: 'uv',
      sceneId: 'UV',
      validFrom: '2026-09-10T06:00:10Z',
      validUntil: '2026-09-10T07:00:00Z',
      copy: BriefingCopy(
        short: '자외선 안내',
        medium: '양산을 챙기세요.',
        long: '양산을 챙기세요.',
        notificationTitle: '자외선 안내',
        notificationBody: '양산을 챙기세요.',
      ),
    );
    await tester.pumpWidget(MaterialApp(
      home: WeatherBriefText(
          text: action, timeline: const [entry], now: () => now),
    ));
    expect(find.text('최신 날씨를 확인해 주세요.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('새 응답을 받으면 만료 상태를 해제하고 이전 타이머를 취소한다', (tester) async {
    await tester.pumpWidget(subject());
    await tester
        .pumpWidget(subject(expiry: '2026-09-10T16:00:00+09:00', text: '새 안내'));
    now = now.add(const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('새 안내'), findsOneWidget);
    now = now.add(const Duration(hours: 2));
    await tester.pump(const Duration(minutes: 1));
    expect(find.text('새 안내'), findsNothing);
    await tester.pumpWidget(
        subject(expiry: '2026-09-10T19:00:00+09:00', text: '다시 받은 안내'));
    expect(find.text('다시 받은 안내'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(hours: 3));
    expect(tester.takeException(), isNull);
  });

  test('API 만료 정보를 해석하고 수동 지역 이름 치환 때도 보존한다', () {
    final response = TodayWeatherResponse.fromJson({
      'brief': action,
      'briefExpiresAt': '2026-09-10T06:00:00Z',
      'generatedAt': '2026-09-18T04:33:00Z',
      'current': {'forecastAt': '2026-09-10T15:00:00+09:00'},
      'nextForecast': {'forecastAt': '2026-09-10T16:00:00+09:00'},
    }).withRegionName('부산 해운대구');
    expect(response.briefExpiresAt, '2026-09-10T06:00:00Z');
    expect(response.generatedAt, '2026-09-18T04:33:00Z');
    expect(response.brief, action);
    expect(response.current.forecastAt, '2026-09-10T15:00:00+09:00');
    expect(response.nextForecast?.forecastAt, '2026-09-10T16:00:00+09:00');
    expect(TodayWeatherResponse.fromJson({'brief': action}).briefExpiresAt,
        isNull);
  });

  test('메인 갱신 시각은 서버 UTC 시각을 한국시간으로 표시한다', () {
    expect(
      weatherRefreshLabel('2026-09-18T04:33:00Z'),
      '9월 18일 오후 1시 33분 기준',
    );
    expect(
      weatherRefreshLabel('2026-09-18T00:05:00Z'),
      '9월 18일 오전 9시 05분 기준',
    );
  });

  testWidgets('Main 브리핑은 새로고침 중 만료 안내 대신 로딩을 표시한다', (tester) async {
    final today = TodayWeatherResponse.fromJson({
      'brief': action,
      'briefExpiresAt': '2000-01-01T00:00:00Z',
      'current': {'temperature': 28},
      'region': {'nx': 60, 'ny': 121, 'name': '수원'},
    });
    Widget screen(WeatherDataPhase phase) => MaterialApp(
          home: Scaffold(
            body: MainTab(
              today: today,
              dataPhase: phase,
              dateLabel: '9월 10일',
              mood: 'sunny',
              serverFeaturesAvailable: true,
              onRefresh: () async {},
              onDetail: (_) {},
            ),
          ),
        );

    await tester.pumpWidget(screen(WeatherDataPhase.loading));
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('main-weather-brief')))
          .data,
      '불러오는 중',
    );
    await tester.pumpWidget(screen(WeatherDataPhase.ready));
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('main-weather-brief')))
          .data,
      '최신 날씨를 확인해 주세요.',
    );
  });

  testWidgets('Main은 현재 시각을 누락된 다음 시간 예보에 재사용하지 않는다', (tester) async {
    tester.view.physicalSize = const Size(360, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final today = TodayWeatherResponse.fromJson({
      'brief': action,
      'briefExpiresAt': '2000-01-01T00:00:00Z',
      'current': {'forecastAt': '2026-09-10T15:00:00+09:00', 'temperature': 28},
      'region': {'nx': 60, 'ny': 121, 'name': '수원'},
    });
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: MainTab(
      today: today,
      dateLabel: '9월 10일',
      mood: 'sunny',
      serverFeaturesAvailable: true,
      onRefresh: () async {},
      onDetail: (_) {},
    ))));
    expect(find.text(action), findsNothing);
    expect(find.text('최신 날씨를 확인해 주세요.'), findsOneWidget);
    expect(find.text('예보 시각 자료 없음'), findsOneWidget);
    final futureCard = find.byKey(const ValueKey('main-future-weather-card'));
    expect(
      find.descendant(of: futureCard, matching: find.text('28.0℃')),
      findsNothing,
    );
    expect(
      find.descendant(of: futureCard, matching: find.text('자료 없음')),
      findsNWidgets(2),
    );
    expect(tester.takeException(), isNull);
  });
}
