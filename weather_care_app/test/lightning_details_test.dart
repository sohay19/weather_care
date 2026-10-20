import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weather_care/features/home/tabs/today_tab.dart';
import 'package:weather_care/features/home/widgets/lightning_details_card.dart';
import 'package:weather_care/models/weather.dart';
import 'package:weather_care/services/api_client.dart';
import 'package:weather_care/services/kma_grid.dart';
import 'package:weather_care/services/notification_destination.dart';
import 'package:weather_care/theme/weather_theme.dart';

class _Client extends ApiClient {
  _Client() : super(baseUrl: 'https://example.invalid');
  final queries = <Map<String, String>>[];
  bool fail = false;
  Map<String, dynamic> data = {};
  Future<Map<String, dynamic>> Function(Map<String, String>)? load;

  @override
  Future<Map<String, dynamic>> get(String path,
      {Map<String, String>? query}) async {
    expect(path, '/api/v1/weather/extra/lightning');
    queries.add({...query!});
    if (fail) throw StateError('조회 실패');
    if (load != null) return await load!(query);
    return data;
  }
}

Map<String, dynamic> _data(DateTime now,
        {List<DateTime>? times, String status = 'AVAILABLE'}) =>
    {
      'status': status,
      'checkedAt': now.toIso8601String(),
      'feedExpiresAt': now.add(const Duration(minutes: 15)).toIso8601String(),
      'observations': (times ?? [now.subtract(const Duration(minutes: 5))])
          .map((time) => time.toIso8601String())
          .toList(),
    };

Future<void> _open(
    WidgetTester tester, _Client client, DateTime Function() clock,
    {bool active = true,
    bool focused = true,
    int refreshId = 0,
    KmaGrid grid = const KmaGrid(nx: 60, ny: 121)}) async {
  await tester.pumpWidget(MaterialApp(
    theme: WeatherCareTheme.light(),
    home: Scaffold(
        body: SingleChildScrollView(
            child: LightningDetailsCard(
      client: client,
      grid: grid,
      active: active,
      focused: focused,
      refreshId: refreshId,
      clock: clock,
    ))),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('30분 경계·미래 관측을 제외하고 관측 시간·횟수·갱신 시각을 표시한다', (tester) async {
    final now = DateTime.utc(2026, 10, 20, 3, 15);
    final client = _Client()
      ..data = _data(now, times: [
        now.subtract(const Duration(minutes: 30)),
        now.subtract(const Duration(minutes: 30) - const Duration(seconds: 1)),
        now.subtract(const Duration(minutes: 5)),
        now.add(const Duration(seconds: 1)),
      ]);
    await _open(tester, client, () => now);
    expect(find.text('최근 30분 수집 자료: 2회'), findsOneWidget);
    expect(find.text('최근 발생: 10월 20일 12:10 (한국시간)'), findsOneWidget);
    expect(find.text('자료 확인: 10월 20일 12:15 (한국시간)'), findsOneWidget);
    expect(find.textContaining('안전을 뜻하지는 않아요'), findsOneWidget);
    expect(client.queries.single, {'nx': '60', 'ny': '121'});
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('열린 화면에서도 30분 경계가 되면 응답을 기다리지 않고 숨긴다', (tester) async {
    var now = DateTime.utc(2026, 10, 20, 3, 15);
    final client = _Client()
      ..data = _data(now,
          times: [now.subtract(const Duration(minutes: 29, seconds: 59))]);
    await _open(tester, client, () => now, focused: false);
    expect(find.text('낙뢰 관측'), findsOneWidget);
    final pending = Completer<Map<String, dynamic>>();
    client.load = (_) => pending.future;
    now = now.add(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('낙뢰 관측'), findsNothing);
    pending.complete(_data(now, times: []));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('조회 실패는 표시하고 다시 시도로 복구한다', (tester) async {
    final now = DateTime.utc(2026, 10, 20, 3, 15);
    final client = _Client()..fail = true;
    await _open(tester, client, () => now);
    expect(find.text('낙뢰 자료를 확인하지 못했어요'), findsOneWidget);
    client.fail = false;
    client.data = _data(now);
    await tester.tap(find.text('다시 시도'));
    await tester.pumpAndSettle();
    expect(find.text('최근 30분 수집 자료: 1회'), findsOneWidget);
    expect(find.text('낙뢰 자료를 확인하지 못했어요'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  for (final status in ['FAILED', 'STALE', 'UNAVAILABLE']) {
    testWidgets('$status 상태는 오래된 횟수 대신 실패 안내를 표시한다', (tester) async {
      final now = DateTime.utc(2026, 10, 20, 3, 15);
      final client = _Client()..data = _data(now, status: status);
      await _open(tester, client, () => now);
      expect(find.text('낙뢰 자료를 확인하지 못했어요'), findsOneWidget);
      expect(find.textContaining('수집 자료: 1회'), findsNothing);
      expect(find.text('다시 시도'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('수집 유효 시간이 지나면 남아 있는 관측도 숨기고 지연을 표시한다', (tester) async {
    var now = DateTime.utc(2026, 10, 20, 3, 15);
    final client = _Client()
      ..data = {
        ..._data(now),
        'feedExpiresAt': now.add(const Duration(seconds: 1)).toIso8601String()
      };
    await _open(tester, client, () => now);
    now = now.add(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.textContaining('수집 자료: 1회'), findsNothing);
    expect(find.textContaining('최신 자료 갱신이 지연'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('미선택 탭은 조회하지 않고 지역 변경 전 늦은 응답은 버린다', (tester) async {
    final now = DateTime.utc(2026, 10, 20, 3, 15);
    final client = _Client()..data = _data(now);
    await _open(tester, client, () => now, active: false);
    expect(client.queries, isEmpty);
    final old = Completer<Map<String, dynamic>>();
    client.load = (query) =>
        query['nx'] == '60' ? old.future : Future.value(_data(now, times: []));
    await _open(tester, client, () => now);
    await _open(tester, client, () => now,
        grid: const KmaGrid(nx: 61, ny: 122));
    old.complete(_data(now));
    await tester.pumpAndSettle();
    expect(find.textContaining('수집 자료: 1회'), findsNothing);
    expect(find.text('표시할 최근 낙뢰 관측이 없어요'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Today의 낙뢰 알림 진입은 카드를 펼치며 새로고침 때 다시 조회한다', (tester) async {
    final now = DateTime.now().toUtc();
    final client = _Client()..data = _data(now);
    const today = TodayWeatherResponse(
      dataSource: 'test',
      region: WeatherRegion(nx: 60, ny: 121, name: '수원'),
      brief: '오늘 날씨',
      current: CurrentWeather(temperature: 22),
      recommendations: [],
      lifestyleMessages: [],
      timeline: [],
      hourly: [],
    );
    await tester.pumpWidget(MaterialApp(
        theme: WeatherCareTheme.light(),
        home: Scaffold(
            body: TodayTab(
          today: today,
          onRefresh: () async {},
          lightningClient: client,
          lightningGrid: const KmaGrid(nx: 60, ny: 121),
          focusTopic: NotificationTopic.lightning,
        ))));
    await tester.pumpAndSettle();
    expect(find.text('최근 30분 수집 자료: 1회'), findsOneWidget);
    final tile = tester.widget<ExpansionTile>(find.descendant(
        of: find.byKey(const ValueKey('lightning-details-card')),
        matching: find.byType(ExpansionTile)));
    expect(tile.initiallyExpanded, isTrue);
    final count = client.queries.length;
    await tester
        .widget<RefreshIndicator>(find.byType(RefreshIndicator))
        .onRefresh();
    await tester.pumpAndSettle();
    expect(client.queries.length, count + 1);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('320px 큰 글씨에서도 낙뢰 안내가 넘치지 않는다', (tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final now = DateTime.utc(2026, 10, 20, 3, 15);
    final client = _Client()..data = _data(now);
    await tester.pumpWidget(MaterialApp(
        theme: WeatherCareTheme.light(),
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
          child: Scaffold(
              body: SingleChildScrollView(
                  child: LightningDetailsCard(
            client: client,
            grid: const KmaGrid(nx: 60, ny: 121),
            active: true,
            focused: true,
            clock: () => now,
          ))),
        )));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
