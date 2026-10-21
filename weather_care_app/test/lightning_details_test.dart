import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weather_care/features/home/tabs/today_tab.dart';
import 'package:weather_care/features/home/widgets/lightning_details_card.dart';
import 'package:weather_care/features/home/widgets/lifestyle_evidence_checklist_section.dart';
import 'package:weather_care/models/weather.dart';
import 'package:weather_care/services/api_client.dart';
import 'package:weather_care/services/current_location_service.dart';
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
      'distanceBasis': 'GRID_CENTER',
      'latestDistanceKm': 3.2,
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
    DeviceCoordinates? coordinates,
    KmaGrid grid = const KmaGrid(nx: 60, ny: 121)}) async {
  await tester.pumpWidget(MaterialApp(
    theme: WeatherCareTheme.light(),
    home: Scaffold(
        body: SingleChildScrollView(
            child: LightningDetailsCard(
      client: client,
      grid: grid,
      coordinates: coordinates,
      active: active,
      focused: focused,
      refreshId: refreshId,
      clock: clock,
    ))),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('실제 GPS 좌표를 전송하고 가장 최근 관측의 거리를 현재 위치 기준으로 표시한다', (tester) async {
    final now = DateTime.utc(2026, 10, 21, 1);
    final client = _Client()
      ..data = {
        ..._data(now),
        'distanceBasis': 'COORDINATES',
        'latestDistanceKm': 3.24
      };
    await _open(tester, client, () => now,
        coordinates:
            const DeviceCoordinates(latitude: 37.2636, longitude: 127.0286));
    expect(client.queries.single, {
      'nx': '60',
      'ny': '121',
      'latitude': '37.2636',
      'longitude': '127.0286'
    });
    expect(find.textContaining('현재 위치로부터 약 3.2km'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('정밀 좌표가 없으면 지역 기준점 거리로 구분하고 실패 시 이전 거리는 숨긴다', (tester) async {
    final now = DateTime.utc(2026, 10, 21, 1);
    final client = _Client()
      ..data = {
        ..._data(now),
        'distanceBasis': 'GRID_CENTER',
        'latestDistanceKm': 0.05
      };
    await _open(tester, client, () => now);
    expect(find.textContaining('지역 기준점으로부터 약 0.1km'), findsOneWidget);
    expect(find.textContaining('현재 위치로부터'), findsNothing);
    client.fail = true;
    await _open(tester, client, () => now, refreshId: 1);
    expect(find.textContaining('km'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('같은 격자 안의 위치 변경도 재조회하고 이전 좌표의 늦은 응답을 버린다', (tester) async {
    final now = DateTime.utc(2026, 10, 21, 1);
    final old = Completer<Map<String, dynamic>>();
    final client = _Client()
      ..load = (query) => query['latitude'] == '37.2636'
          ? old.future
          : Future.value({
              ..._data(now),
              'distanceBasis': 'COORDINATES',
              'latestDistanceKm': 4.5
            });
    await _open(tester, client, () => now,
        coordinates:
            const DeviceCoordinates(latitude: 37.2636, longitude: 127.0286));
    await _open(tester, client, () => now,
        coordinates:
            const DeviceCoordinates(latitude: 37.2646, longitude: 127.0286));
    old.complete({
      ..._data(now),
      'distanceBasis': 'COORDINATES',
      'latestDistanceKm': 1.2
    });
    await tester.pumpAndSettle();
    expect(client.queries, hasLength(2));
    expect(find.textContaining('현재 위치로부터 약 4.5km'), findsOneWidget);
    expect(find.textContaining('1.2km'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('시험 샘플은 테스트 제목·출처와 함께 실제 행동 안내 예시를 표시한다', (tester) async {
    final now = DateTime.utc(2026, 10, 21, 1);
    final client = _Client()..data = {..._data(now), 'testSample': true};
    await _open(tester, client, () => now);
    expect(find.text('[테스트] 낙뢰 관측'), findsOneWidget);
    expect(
        find.text(
            '[예시] 안전한 건물이나 자동차 안으로 이동하세요. 마지막 번개·천둥 후 최소 30분은 안전한 장소에서 기다리세요.'),
        findsOneWidget);
    expect(find.text('테스트 서버 샘플'), findsOneWidget);
    expect(find.text('체크할 일'), findsOneWidget);
    expect(find.text('관측 내용'), findsOneWidget);
    expect(find.text('사용한 자료'), findsNothing);
    expect(find.text('자료 상태'), findsNothing);
    expect(find.textContaining('출처: 기상청'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('30분 경계·미래 관측을 제외하고 발생 일자·거리·횟수 순서로 표시한다', (tester) async {
    final now = DateTime.utc(2026, 10, 20, 3, 15);
    final client = _Client()
      ..data = _data(now, times: [
        now.subtract(const Duration(minutes: 30)),
        now.subtract(const Duration(minutes: 30) - const Duration(seconds: 1)),
        now.subtract(const Duration(minutes: 5)),
        now.add(const Duration(seconds: 1)),
      ]);
    await _open(tester, client, () => now);
    expect(find.textContaining('최근 30분 발생 횟수: 2회'), findsOneWidget);
    expect(
        find.text('발생 일자: 10월 20일 12:10\n지역 기준점으로부터 약 3.2km\n최근 30분 발생 횟수: 2회'),
        findsOneWidget);
    expect(find.textContaining('한국시간'), findsNothing);
    expect(find.textContaining('자료 확인:'), findsNothing);
    expect(find.textContaining('관측 지역:'), findsNothing);
    expect(find.text('기상청 낙뢰 관측'), findsOneWidget);
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
    expect(find.textContaining('낙뢰 자료를 확인하지 못했어요'), findsOneWidget);
    expect(find.text('체크할 일'), findsOneWidget);
    expect(find.text('관측 내용'), findsOneWidget);
    expect(find.text('자료 상태'), findsNothing);
    client.fail = false;
    client.data = _data(now);
    await tester.tap(find.text('다시 시도'));
    await tester.pumpAndSettle();
    expect(find.textContaining('최근 30분 발생 횟수: 1회'), findsOneWidget);
    expect(find.textContaining('낙뢰 자료를 확인하지 못했어요'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  for (final status in ['FAILED', 'STALE', 'UNAVAILABLE']) {
    testWidgets('$status 상태는 오래된 횟수 대신 실패 안내를 표시한다', (tester) async {
      final now = DateTime.utc(2026, 10, 20, 3, 15);
      final client = _Client()..data = _data(now, status: status);
      await _open(tester, client, () => now);
      expect(find.textContaining('낙뢰 자료를 확인하지 못했어요'), findsOneWidget);
      expect(find.textContaining('발생 횟수: 1회'), findsNothing);
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
    expect(find.textContaining('발생 횟수: 1회'), findsNothing);
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
    expect(find.textContaining('발생 횟수: 1회'), findsNothing);
    expect(find.textContaining('표시할 최근 낙뢰 관측이 없어요'), findsOneWidget);
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
    expect(find.textContaining('최근 30분 발생 횟수: 1회'), findsOneWidget);
    expect(
        find.descendant(
            of: find.byKey(const ValueKey('lifestyle-evidence-checklist')),
            matching: find.byKey(const ValueKey('lightning-details-card'))),
        findsOneWidget);
    expect(find.text('알림에서 선택한 낙뢰 자료'), findsOneWidget);
    await tester
        .tap(find.byKey(const ValueKey('detail-evidence-toggle-lightning')));
    await tester.pumpAndSettle();
    expect(find.textContaining('최근 30분 발생 횟수: 1회'), findsNothing);
    expect(find.textContaining('안전한 건물이나 자동차 안'), findsOneWidget);
    expect(tester.getTopLeft(find.text('상세 자료')).dy, greaterThanOrEqualTo(0));
    final count = client.queries.length;
    await tester
        .widget<RefreshIndicator>(find.byType(RefreshIndicator))
        .onRefresh();
    await tester.pumpAndSettle();
    expect(client.queries.length, count + 1);
    expect(find.textContaining('최근 30분 발생 횟수: 1회'), findsOneWidget);
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
                  child: LifestyleEvidenceChecklistSection(
                      messages: const [],
                      dataStatusMessages: const [],
                      leadingEvidence: LightningDetailsCard(
                        client: client,
                        grid: const KmaGrid(nx: 60, ny: 121),
                        active: true,
                        focused: true,
                        clock: () => now,
                      )))),
        )));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
