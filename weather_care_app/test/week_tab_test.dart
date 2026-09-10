import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weather_care/features/home/tabs/week_tab.dart';
import 'package:weather_care/features/home/widgets/week_presentation.dart';
import 'package:weather_care/models/weather.dart';
import 'package:weather_care/utils/korea_date.dart';

void main() {
  test('API의 달력 날짜와 기존 요일을 독립적으로 보존한다', () {
    final weekly = WeeklyWeatherResponse.fromJson({
      'days': [
        {'date': '목', 'forecastDate': '2026-09-10'},
        {'date': '금'},
      ],
    });
    expect(weekly.days.first.date, '목');
    expect(weekly.days.first.forecastDate, '2026-09-10');
    expect(weekly.days.last.forecastDate, isNull);
  });

  test('잘못된 날짜·요일·시각을 날짜로 추정하거나 보정하지 않는다', () {
    for (final value in [
      null,
      '',
      '금',
      '2026-02-30',
      '2026-13-01',
      '2026-09-10T00:00:00Z',
      '20260910'
    ]) {
      expect(parseForecastDate(value), isNull, reason: '$value');
      expect(weekDayLabel(_day(value)), '날짜 확인 어려움');
    }
    expect(weekDayLabel(_day('2028-02-29')), '2월 29일 (화)');
  });

  test('실제 날짜 범위와 제공 일수만 표시한다', () {
    expect(weekPeriodLabel([_day('2026-09-10'), _day('2026-09-11')]),
        '9월 10일~9월 11일 · 2일 예보');
    expect(weekPeriodLabel([_day('2026-09-11')]), '9월 11일 · 1일 예보');
    expect(weekPeriodLabel([_day('2026-12-31'), _day('2027-01-01')]),
        '2026년 12월 31일~2027년 1월 1일 · 2일 예보');
  });

  test('중간 결측·중복·순서 뒤바뀜·날짜 누락을 임의의 연속 예보로 만들지 않는다', () {
    expect(
        weekPeriodLabel([
          _day('2026-10-02'),
          _day('2026-09-30'),
          _day('2026-09-30'),
          _day(null),
        ]),
        '9월 30일~10월 2일 · 기간 내 2일 자료 · 날짜 미확인 1개');
    expect(weekPeriodLabel([_day(null)]), '날짜 정보가 없어 예보 기간을 확인하기 어려워요');
  });

  testWidgets('첫 날짜가 내일이면 오늘을 붙이지 않는다', (tester) async {
    await _pump(tester, [_day('2026-09-11')]);
    expect(find.text('날짜별 날씨'), findsOneWidget);
    expect(find.text('9월 11일 (금)'), findsOneWidget);
    expect(find.text('오늘'), findsNothing);
    expect(find.textContaining('이번주'), findsNothing);
  });

  testWidgets('목록 위치와 기기 시간대가 아닌 한국 날짜로 오늘을 표시한다', (tester) async {
    await _pump(tester, [_day('2026-09-10'), _day('2026-09-11')],
        now: () => DateTime.parse('2026-09-10T15:00:00Z'));
    expect(find.byKey(const ValueKey('week-today-2026-09-10')), findsNothing);
    expect(find.byKey(const ValueKey('week-today-2026-09-11')), findsOneWidget);
  });

  testWidgets('요일만 받은 기존 서버 자료에는 날짜·오늘을 만들지 않는다', (tester) async {
    await _pump(tester, [_day(null)]);
    expect(find.text('날짜 확인 어려움'), findsOneWidget);
    expect(find.text('오늘'), findsNothing);
    expect(find.text('날짜 정보가 없어 예보 기간을 확인하기 어려워요'), findsOneWidget);
  });

  testWidgets('빈 목록에는 0일 요약이나 정상 날씨를 표시하지 않는다', (tester) async {
    await _pump(tester, []);
    expect(find.text('날짜별 예보 자료가 없어요'), findsOneWidget);
    expect(find.text('제공된 예보 요약'), findsNothing);
    expect(find.text('0일'), findsNothing);
    expect(find.text('준비물 없음'), findsNothing);
  });

  testWidgets('자정에는 자료를 다시 받지 않아도 오늘 배지가 바뀐다', (tester) async {
    var now = DateTime.parse('2026-09-10T14:59:59Z');
    await _pump(tester, [_day('2026-09-10'), _day('2026-09-11')],
        now: () => now);
    expect(find.byKey(const ValueKey('week-today-2026-09-10')), findsOneWidget);
    now = now.add(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(find.byKey(const ValueKey('week-today-2026-09-10')), findsNothing);
    expect(find.byKey(const ValueKey('week-today-2026-09-11')), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('백그라운드 복귀 시 날짜를 다시 확인한다', (tester) async {
    var now = DateTime.parse('2026-09-10T01:00:00Z');
    await _pump(tester, [_day('2026-09-10'), _day('2026-09-11')],
        now: () => now);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    now = now.add(const Duration(days: 1));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(find.byKey(const ValueKey('week-today-2026-09-10')), findsNothing);
    expect(find.byKey(const ValueKey('week-today-2026-09-11')), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('좁은 화면·2배 글씨에서도 날짜·범위·준비물이 넘치지 않는다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final weekly = WeeklyWeatherResponse.fromJson({
      'days': [
        {
          'forecastDate': '2026-12-31',
          'weatherLabel': '비와 눈',
          'min': '-15',
          'max': '-5',
          'recommendations': [
            {'type': 'HEAVY_SNOW_CAUTION', 'recommended': true},
            {'type': 'UMBRELLA', 'recommended': true},
            {'type': 'OUTERWEAR', 'recommended': true},
          ],
        },
        {'forecastDate': '2027-01-01', 'weatherLabel': '맑음'}
      ],
    });
    await _pump(tester, weekly.days, textScale: 2);
    expect(find.text('12월 31일 (목)'), findsOneWidget);
    expect(find.text('많은 눈 대비'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

WeeklyForecastItem _day(String? date) => WeeklyForecastItem(
      date: '금',
      forecastDate: date,
      weatherLabel: '비',
      min: 20,
      max: 25,
      recommendations: const [],
    );

Future<void> _pump(
  WidgetTester tester,
  List<WeeklyForecastItem> days, {
  DateTime Function()? now,
  double textScale = 1,
}) async {
  addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
  await tester.pumpWidget(MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
      child: Scaffold(
          body: WeekTab(
        weekly: WeeklyWeatherResponse(days: days),
        serverFeaturesAvailable: true,
        now: now ?? () => DateTime.parse('2026-09-10T01:00:00Z'),
        onRefresh: () async {},
      )),
    ),
  ));
}
