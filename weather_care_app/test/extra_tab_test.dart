import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weather_care/features/home/tabs/extra_tab.dart';
import 'package:weather_care/services/api_client.dart';
import 'package:weather_care/services/kma_grid.dart';
import 'package:weather_care/theme/weather_theme.dart';

const _groups = [
  {
    'source': 'KMA_LIGHTNING',
    'title': '낙뢰',
    'scope': 'grid',
    'period': 'hourly',
    'targets': [
      {'id': '60_121', 'name': '현재 격자'}
    ],
  },
  {
    'source': 'KHOA_TIDE_EXTREME',
    'title': '만조·간조',
    'scope': 'station',
    'period': 'daily',
    'targets': [
      {'id': 'DT_0001', 'name': '인천'}
    ],
  },
  {
    'source': 'KWATER_DAM',
    'title': '댐·보 운영',
    'scope': 'dam',
    'period': 'hourly',
    'targets': [
      {'id': '2022510', 'name': '첫째댐'},
      {'id': '2022511', 'name': '둘째댐'},
    ],
  },
  {
    'source': 'NIFS_JELLYFISH_DETAIL',
    'title': '해파리 보고서',
    'scope': 'report',
    'period': 'daily',
    'targets': [
      {'id': 'report1', 'name': '10월 해파리 현황'}
    ],
  },
];

class _ExtraApi extends ApiClient {
  _ExtraApi() : super(baseUrl: 'https://example.invalid');

  List<Map<String, dynamic>> groups = _groups;
  final queries = <Map<String, String>>[];
  bool failCatalog = false;
  bool failRecords = false;
  Future<Map<String, dynamic>> Function(Map<String, String>)? records;

  @override
  Future<Map<String, dynamic>> get(String path,
      {Map<String, String>? query}) async {
    if (path.endsWith('/catalog')) {
      if (failCatalog) throw StateError('목록 오류');
      return {'groups': groups};
    }
    queries.add({...query!});
    if (failRecords) throw StateError('자료 오류');
    if (records != null) return records!(query);
    if (query['source'] == 'KMA_LIGHTNING') {
      return {
        'records': [
          {
            'time': '2026-10-14T10:00:00',
            'values': {'count': 2}
          }
        ]
      };
    }
    if (query['source'] == 'NIFS_JELLYFISH_DETAIL') {
      return {
        'records': [
          {
            'time': '2026-10-14T11:00:00+09:00',
            'values': {'내용': '해파리 출현 해역을 확인해주세요.'}
          }
        ]
      };
    }
    if (query['source'] == 'KHOA_TIDE_EXTREME') {
      return {
        'records': [
          {
            'time': '2026-10-15T00:30:00+09:00',
            'values': {'tideCm': 120}
          },
          {
            'time': '2026-10-14T12:00:00Z',
            'values': {'tideCm': 90}
          },
          {
            'time': '2026-10-14 11:00',
            'values': {'tideCm': 100}
          },
        ]
      };
    }
    return {
      'records': [
        {
          'time': '2026-10-14 11:00',
          'values': {
            'levelM': query['targetId'] == '2022511' ? 30.5 : 20.5,
            'inflowM3PerSec': 4.2,
          }
        }
      ]
    };
  }
}

Future<void> _open(WidgetTester tester, _ExtraApi api) async {
  await tester.pumpWidget(MaterialApp(
    theme: WeatherCareTheme.light(),
    home: Scaffold(
        body: ExtraTab(
            client: api, grid: const KmaGrid(nx: 60, ny: 121), active: true)),
  ));
  await tester.pumpAndSettle();
}

Future<void> _select(WidgetTester tester, String source) async {
  final chip = find.byKey(ValueKey('extra-source-$source'));
  await tester.ensureVisible(chip);
  await tester.tap(chip);
  await tester.pumpAndSettle();
}

void _screen(WidgetTester tester, {double width = 800}) {
  tester.view.physicalSize = Size(width, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  testWidgets('종류별 박스 안의 칩은 체크 표시 없이 자료를 전환한다', (tester) async {
    _screen(tester);
    final api = _ExtraApi();
    await _open(tester, api);
    for (final category in ['기상', '해양', '댐·하천', '보고서']) {
      expect(find.byKey(ValueKey('extra-category-$category')), findsOneWidget);
    }
    final marineBox = find.byKey(const ValueKey('extra-category-해양'));
    expect(find.descendant(of: marineBox, matching: find.text('만조·간조')),
        findsOneWidget);
    for (final chip in tester.widgetList<ChoiceChip>(find.byType(ChoiceChip))) {
      expect(chip.showCheckmark, isFalse);
    }
    expect(find.byType(Checkbox), findsNothing);
    expect(api.queries.first['source'], 'KHOA_TIDE_EXTREME');
    await _select(tester, 'KMA_LIGHTNING');
    expect(find.text('낙뢰 발생  2회'), findsOneWidget);
    expect(find.byType(DropdownButtonFormField<String>), findsNothing);
    expect(api.queries.last['targetId'], '60_121');
    expect(tester.takeException(), isNull);
  });

  testWidgets('콤보박스에서 구역을 바꾸면 해당 대상의 데이터를 조회한다', (tester) async {
    _screen(tester);
    final api = _ExtraApi();
    await _open(tester, api);
    await _select(tester, 'KWATER_DAM');
    expect(find.text('수위  20.5m'), findsOneWidget);
    final combo = find.byType(DropdownButtonFormField<String>);
    await tester.ensureVisible(combo);
    await tester.tap(combo);
    await tester.pumpAndSettle();
    await tester.tap(find.text('둘째댐 (2022511)').last);
    await tester.pumpAndSettle();
    expect(api.queries.last['source'], 'KWATER_DAM');
    expect(api.queries.last['targetId'], '2022511');
    expect(find.text('수위  30.5m'), findsOneWidget);
    expect(find.text('수위  20.5m'), findsNothing);
    expect(find.text('유입량  4.2㎥/s'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('일 단위 수집도 실제 시각이 있으면 한국 시각의 날짜별 타임라인으로 정렬한다', (tester) async {
    _screen(tester);
    await _open(tester, _ExtraApi());
    expect(find.byKey(const ValueKey('extra-timeline')), findsOneWidget);
    expect(find.text('2026-10-14'), findsOneWidget);
    expect(find.text('2026-10-15'), findsOneWidget);
    expect(tester.getTopLeft(find.text('11:00')).dy,
        lessThan(tester.getTopLeft(find.text('21:00')).dy));
    expect(tester.getTopLeft(find.text('21:00')).dy,
        lessThan(tester.getTopLeft(find.text('00:30')).dy));
    expect(find.text('조위  120cm'), findsOneWidget);
  });

  testWidgets('보고서는 시각이 있어도 내용 카드로 표시한다', (tester) async {
    _screen(tester);
    await _open(tester, _ExtraApi());
    await _select(tester, 'NIFS_JELLYFISH_DETAIL');
    expect(find.byKey(const ValueKey('extra-timeline')), findsNothing);
    expect(find.text('보고서 내용'), findsOneWidget);
    expect(find.text('내용  해파리 출현 해역을 확인해주세요.'), findsOneWidget);
    expect(find.text('보고서 선택'), findsOneWidget);
  });

  testWidgets('날짜만 있는 자료는 시간을 만들지 않고 일자별 카드로 표시한다', (tester) async {
    _screen(tester);
    final api = _ExtraApi()
      ..records = (_) async => {
            'records': [
              {
                'time': '2026-10-14',
                'values': {'tideCm': 0.009}
              },
            ]
          };
    await _open(tester, api);
    expect(find.byKey(const ValueKey('extra-timeline')), findsNothing);
    expect(find.text('일자별 자료'), findsOneWidget);
    expect(find.text('2026-10-14'), findsOneWidget);
    expect(find.text('00:00'), findsNothing);
    expect(find.text('조위  0.009cm'), findsOneWidget);
  });

  testWidgets('선택 대상이 없는 항목은 콤보박스를 비활성화한다', (tester) async {
    _screen(tester);
    final api = _ExtraApi()
      ..groups = [
        {..._groups[2], 'targets': <Map<String, dynamic>>[]},
      ];
    await _open(tester, api);
    final combo = tester.widget<DropdownButtonFormField<String>>(
        find.byType(DropdownButtonFormField<String>));
    expect(combo.onChanged, isNull);
    expect(find.text('수집된 선택 대상 없음'), findsOneWidget);
    expect(api.queries, isEmpty);
  });

  testWidgets('목록 실패와 데이터 실패를 안내하고 다시 시도할 수 있다', (tester) async {
    _screen(tester);
    final api = _ExtraApi()..failCatalog = true;
    await _open(tester, api);
    expect(find.text('자료 목록을 불러오지 못했어요.'), findsOneWidget);
    api.failCatalog = false;
    api.failRecords = true;
    await tester.tap(find.text('다시 시도'));
    await tester.pumpAndSettle();
    expect(find.text('자료를 불러오지 못했어요.'), findsOneWidget);
    api.failRecords = false;
    await tester.ensureVisible(find.text('다시 시도'));
    await tester.tap(find.text('다시 시도'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('extra-timeline')), findsOneWidget);
    expect(find.text('자료를 불러오지 못했어요.'), findsNothing);
  });

  testWidgets('구역 변경 전의 늦은 응답이 새 구역의 자료를 덮어쓰지 않는다', (tester) async {
    _screen(tester);
    final previous = Completer<Map<String, dynamic>>();
    final api = _ExtraApi();
    await _open(tester, api);
    api.records = (query) async {
      if (query['targetId'] == '2022510') return previous.future;
      return {
        'records': [
          {
            'time': '2026-10-14 11:00',
            'values': {'levelM': 30.5}
          }
        ]
      };
    };
    await tester.tap(find.byKey(const ValueKey('extra-source-KWATER_DAM')));
    await tester.pump();
    final combo = tester.widget<DropdownButtonFormField<String>>(
        find.byType(DropdownButtonFormField<String>));
    combo.onChanged!('2022511');
    await tester.pumpAndSettle();
    previous.complete({
      'records': [
        {
          'time': '2026-10-14 11:00',
          'values': {'levelM': 99}
        }
      ]
    });
    await tester.pumpAndSettle();
    expect(find.text('수위  30.5m'), findsOneWidget);
    expect(find.text('수위  99m'), findsNothing);
  });

  testWidgets('320 너비와 큰 글씨에서도 종류 박스·콤보박스·타임라인이 넘치지 않는다', (tester) async {
    _screen(tester, width: 320);
    final api = _ExtraApi();
    await tester.pumpWidget(MaterialApp(
      theme: WeatherCareTheme.light(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: const TextScaler.linear(1.3)),
        child: child!,
      ),
      home: Scaffold(
          body: ExtraTab(
              client: api, grid: const KmaGrid(nx: 60, ny: 121), active: true)),
    ));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('extra-timeline')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('그래프 지표와 시각을 바꿔도 결측을 0으로 만들지 않는다', (tester) async {
    _screen(tester);
    final api = _ExtraApi()
      ..groups = [
        {..._groups[1], 'source': 'KHOA_TIDE_OBS'}
      ]
      ..records = (_) async => {
            'records': [
              {
                'time': '2026-10-14 10:00',
                'values': {'tideCm': 100, 'waterTempC': 20}
              },
              {
                'time': '2026-10-14T11:00:00+09:00',
                'values': {'tideCm': null, 'waterTempC': 21}
              },
              {
                'time': '2026-10-14T05:00:00Z',
                'values': {'tideCm': 130, 'waterTempC': 22}
              },
            ]
          };
    await _open(tester, api);
    expect(find.byKey(const ValueKey('extra-chart-tideCm')), findsOneWidget);
    expect(find.text('관측 자료'), findsOneWidget);
    final slider = tester
        .widget<Slider>(find.byKey(const ValueKey('extra-chart-time-slider')));
    slider.onChanged!(1);
    await tester.pump();
    expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('extra-selected-value')))
            .textSpan!
            .toPlainText(),
        '자료 없음');
    await tester.tap(find.byKey(const ValueKey('extra-metric-waterTempC')));
    await tester.pump();
    expect(
        find.byKey(const ValueKey('extra-chart-waterTempC')), findsOneWidget);
    expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('extra-selected-value')))
            .textSpan!
            .toPlainText(),
        '21 ℃');
    expect(find.text('최저  20℃'), findsOneWidget);
    expect(find.text('최고  22℃'), findsOneWidget);
    final chart =
        tester.getRect(find.byKey(const ValueKey('extra-chart-waterTempC')));
    await tester.tapAt(
        Offset(chart.left + 7 + (chart.width - 14) / 4, chart.center.dy));
    await tester.pump();
    expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('extra-selected-value')))
            .textSpan!
            .toPlainText(),
        '21 ℃');
    expect(tester.takeException(), isNull);
  });
}
