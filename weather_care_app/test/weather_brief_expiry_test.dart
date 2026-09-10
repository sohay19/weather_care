import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weather_care/features/home/tabs/main_tab.dart';
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
    expect(find.textContaining('안내 시간이 지났어요.'), findsOneWidget);
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
      expect(find.textContaining('안내 시간이 지났어요.'), findsOneWidget);
    });
  }

  for (final expiry in ['', 'invalid', '2026-09-10', '2026-09-10T15:00:00']) {
    testWidgets('만료 시각이 잘못되었거나 시간대가 없으면 확인 불가 안내: $expiry', (tester) async {
      await tester.pumpWidget(subject(expiry: expiry));
      expect(find.text(action), findsNothing);
      expect(find.textContaining('안내 시간을 확인하기 어려워요.'), findsOneWidget);
    });
  }

  testWidgets('구버전 서버·기상청 직접 조회처럼 만료 정보가 없으면 기존 문구를 유지한다', (tester) async {
    await tester.pumpWidget(subject(expiry: null));
    now = now.add(const Duration(days: 1));
    await tester.pump(const Duration(days: 1));
    expect(find.text(action), findsOneWidget);
  });

  testWidgets('앱으로 복귀할 때 실제 시각을 확인해 지난 문구를 제거한다', (tester) async {
    await tester.pumpWidget(subject());
    tester.binding
        .handleAppLifecycleStateChanged(AppLifecycleState.paused);
    now = now.add(const Duration(minutes: 5));
    tester.binding
        .handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(find.text(action), findsNothing);
    expect(find.textContaining('안내 시간이 지났어요.'), findsOneWidget);
  });

  testWidgets('시계가 앞으로 조정되어도 주기 점검으로 만료를 반영한다', (tester) async {
    await tester.pumpWidget(subject(expiry: '2026-09-10T16:00:00+09:00'));
    now = now.add(const Duration(hours: 2));
    await tester.pump(const Duration(minutes: 1));
    expect(find.text(action), findsNothing);
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
      'current': {'forecastAt': '2026-09-10T15:00:00+09:00'},
    }).withRegionName('부산 해운대구');
    expect(response.briefExpiresAt, '2026-09-10T06:00:00Z');
    expect(response.brief, action);
    expect(response.current.forecastAt, '2026-09-10T15:00:00+09:00');
    expect(TodayWeatherResponse.fromJson({'brief': action}).briefExpiresAt,
        isNull);
  });

  testWidgets('Main 실제 화면은 지난 행동만 숨기고 공식 예보 시각은 바꾸지 않는다', (tester) async {
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
    expect(find.textContaining('안내 시간이 지났어요.'), findsOneWidget);
    expect(find.textContaining('오후 3시 예상기온'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
