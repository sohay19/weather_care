import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:weather_care/features/home/tabs/extra_tab.dart';
import 'package:weather_care/features/home/widgets/extra_data_overview.dart';
import 'package:weather_care/features/home/widgets/data_range_tile.dart';
import 'package:weather_care/features/home/widgets/hourly_value_chart.dart';
import 'package:weather_care/features/home/widgets/marine_series.dart';
import 'package:weather_care/services/api_client.dart';
import 'package:weather_care/services/current_location_service.dart';
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
    'source': 'KHOA_TIDE_OBS',
    'title': '관측 조위',
    'scope': 'station',
    'period': 'hourly',
    'targets': [
      {'id': 'DT_0001', 'name': '인천'}
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
  final catalogQueries = <Map<String, String>>[];
  bool failCatalog = false;
  bool failRecords = false;
  Future<Map<String, dynamic>> Function(Map<String, String>)? records;

  @override
  Future<Map<String, dynamic>> get(String path,
      {Map<String, String>? query}) async {
    if (path.endsWith('/catalog')) {
      catalogQueries.add({...?query});
      if (failCatalog) throw StateError('목록 오류');
      return {'groups': groups};
    }
    queries.add({...query!});
    if (failRecords) throw StateError('자료 오류');
    if (records != null) return records!(query);
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
    if (query['source'] == 'KHOA_TIDE_EXTREME' ||
        query['source'] == 'KHOA_TIDE_OBS') {
      return {
        'records': [
          {
            'time': '2026-10-15T00:30:00+09:00',
            'values': {'tideCm': 120, 'extremeType': 1}
          },
          {
            'time': '2026-10-14T12:00:00Z',
            'values': {'tideCm': 90, 'extremeType': 4}
          },
          {
            'time': '2026-10-14 11:00',
            'values': {'tideCm': 100, 'extremeType': 1}
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

Future<void> _open(WidgetTester tester, _ExtraApi api,
    {DateTime? now,
    DeviceCoordinates? coordinates,
    bool active = true,
    KmaGrid grid = const KmaGrid(nx: 60, ny: 121)}) async {
  await tester.pumpWidget(MaterialApp(
    theme: WeatherCareTheme.light(),
    home: Scaffold(
        body: ExtraTab(
            client: api,
            grid: grid,
            active: active,
            coordinates: coordinates,
            now: now ?? DateTime.utc(2026, 10, 14, 4))),
  ));
  await tester.pumpAndSettle();
}

Future<void> _select(WidgetTester tester, String source) async {
  if (source.startsWith('KWATER_') || source.startsWith('HRFCO_')) {
    final tab = find.byKey(const ValueKey('extra-tab-river'));
    await tester.ensureVisible(tab);
    await tester.tap(tab);
    await tester.pumpAndSettle();
  } else if (source.startsWith('KHOA_') || source.startsWith('NIFS_')) {
    final tab = find.byKey(const ValueKey('extra-tab-sea'));
    await tester.ensureVisible(tab);
    await tester.tap(tab);
    await tester.pumpAndSettle();
  }
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

Finder _tideTime(String text) {
  final parts = text.split(' ');
  return find.descendant(
      of: find.byKey(ValueKey(
          parts.first == '만조' ? 'marine-tide-high' : 'marine-tide-low')),
      matching: find.text(parts.last));
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets('관측소 항목마다 가까운 기본값·저장한 선택·자동선택 버튼을 동일하게 적용한다', (tester) async {
    _screen(tester, width: 320);
    for (final (source, scope) in [
      ('HRFCO_RIVER_FLOW', 'station'),
      ('KWATER_DAM', 'dam'),
      ('KHOA_TIDE_OBS', 'station'),
      ('KHOA_BUOY_OBS', 'station'),
      ('KHOA_RIP_CURRENT', 'beach'),
    ]) {
      await tester.pumpWidget(const SizedBox());
      final api = _ExtraApi()
        ..groups = [
          {
            'source': source,
            'scope': scope,
            'title': '관측',
            'targets': [
              {'id': 'FAR', 'name': '먼 관측소', 'distanceKm': 50},
              {
                'id': 'NEAR',
                'name': '가까운 관측소',
                'distanceKm': 1,
                'hasData': false
              },
            ]
          }
        ];
      await _open(tester, api, now: DateTime.utc(2026, 7, 14, 4));
      expect(api.queries.where((q) => q['source'] == source).last['targetId'],
          'NEAR');
      tester
          .widget<DropdownButtonFormField<String>>(
              find.byType(DropdownButtonFormField<String>))
          .onChanged!('FAR');
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
      await _open(tester, api, now: DateTime.utc(2026, 7, 14, 4));
      expect(api.queries.where((q) => q['source'] == source).last['targetId'],
          'FAR');
      final button = find.byKey(ValueKey(source == 'KHOA_RIP_CURRENT'
          ? 'extra-nearest-$source'
          : '${source.startsWith('KHOA') ? 'marine' : 'river'}-nearest-target'));
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(api.queries.where((q) => q['source'] == source).last['targetId'],
          'NEAR');
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('모든 관측소 선택은 조회가 끝나면 결과를 화면 중앙으로 스크롤한다', (tester) async {
    _screen(tester, width: 320);
    tester.view.physicalSize = const Size(320, 800);
    for (final (source, scope) in [
      ('HRFCO_RIVER_FLOW', 'station'),
      ('KWATER_DAM', 'dam'),
      ('KHOA_TIDE_OBS', 'station'),
      ('KHOA_BUOY_OBS', 'station'),
      ('KHOA_RIP_CURRENT', 'beach'),
    ]) {
      await tester.pumpWidget(const SizedBox());
      SharedPreferences.setMockInitialValues({});
      final pending = Completer<Map<String, dynamic>>();
      final api = _ExtraApi()
        ..groups = [
          {
            'source': source,
            'scope': scope,
            'title': '관측',
            'targets': [
              {'id': 'NEAR', 'name': '가까운 관측소', 'distanceKm': 1},
              {'id': 'FAR', 'name': '먼 관측소', 'distanceKm': 50},
            ],
          }
        ];
      Map<String, dynamic> records() => {
            'records': [
              {
                'time': '2026-07-14T11:00:00+09:00',
                'values': {
                  'levelM': 10,
                  'tideCm': 100,
                  'waterTempC': 20,
                  'inflowM3PerSec': 2,
                  'riskScore': 10,
                  'extremeType': 1
                },
              }
            ]
          };
      api.records = (q) async =>
          q['targetId'] == 'FAR' ? await pending.future : records();
      await _open(tester, api, now: DateTime.utc(2026, 7, 14, 4));
      final nearest = find.byKey(ValueKey(source == 'KHOA_RIP_CURRENT'
          ? 'extra-nearest-$source'
          : '${source.startsWith('KHOA') ? 'marine' : 'river'}-nearest-target'));
      expect(tester.getSize(nearest).height, lessThanOrEqualTo(32));
      final scrollable = find.byType(Scrollable).first;
      final position = tester.state<ScrollableState>(scrollable).position;
      tester
          .widget<DropdownButtonFormField<String>>(
              find.byType(DropdownButtonFormField<String>))
          .onChanged!('FAR');
      await tester.pump();
      final waitingOffset = position.pixels;
      await tester.pump(const Duration(milliseconds: 400));
      expect(position.pixels, waitingOffset);
      pending.complete(records());
      await tester.pumpAndSettle();
      final current = find.byKey(ValueKey(source == 'KHOA_RIP_CURRENT'
          ? 'extra-current'
          : '${source.startsWith('KHOA') ? 'marine' : 'river'}-current'));
      expect(tester.getCenter(current).dy, closeTo(400, 5), reason: source);
      if (source != 'KHOA_RIP_CURRENT') {
        final input = find.byKey(const ValueKey('water-target-search-input'));
        await tester.ensureVisible(input);
        await tester.enterText(input, '가까운');
        await tester.pumpAndSettle();
        final result = find.byKey(const ValueKey('water-search-result-NEAR'));
        await tester.ensureVisible(result);
        await tester.tap(result);
        await tester.pumpAndSettle();
        expect(tester.getCenter(current).dy, closeTo(400, 5),
            reason: '$source 검색');
        expect(api.queries.last['targetId'], 'NEAR');
      }
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('저장한 관측소는 구역별로 구분하고 현재 박스 안에 Week 방식의 최저·최고를 표시한다',
      (tester) async {
    _screen(tester);
    final api = _ExtraApi()
      ..groups = [
        {
          'source': 'HRFCO_RIVER_FLOW',
          'scope': 'station',
          'title': '수위/유량',
          'targets': [
            {'id': 'FAR', 'name': '먼 관측소', 'distanceKm': 50},
            {'id': 'NEAR', 'name': '가까운 관측소', 'distanceKm': 1}
          ]
        }
      ];
    await _open(tester, api);
    tester
        .widget<DropdownButtonFormField<String>>(
            find.byType(DropdownButtonFormField<String>))
        .onChanged!('FAR');
    await tester.pumpAndSettle();
    await _open(tester, api, grid: const KmaGrid(nx: 98, ny: 76));
    expect(api.queries.last['targetId'], 'NEAR');
    await _open(tester, api);
    expect(api.queries.last['targetId'], 'FAR');
    final current = find.byKey(const ValueKey('river-current'));
    expect(find.descendant(of: current, matching: find.byType(DataRangeTile)),
        findsNWidgets(2));
    final time = tester.widget<Text>(find.text('0시').first);
    expect(time.style?.fontWeight, FontWeight.w800);
  });

  testWidgets('만조·간조는 조위의 가까운 기본값·저장·자동선택을 함께 사용한다', (tester) async {
    _screen(tester);
    final targets = [
      {'id': 'DT_0005', 'name': '먼 관측소', 'distanceKm': 100},
      {'id': 'DT_0001', 'name': '가까운 관측소', 'distanceKm': 1},
    ];
    final api = _ExtraApi()
      ..groups = [
        {..._groups[1], 'targets': targets},
        {..._groups[3], 'targets': targets},
      ];
    String? selected(String source) =>
        api.queries.where((q) => q['source'] == source).last['targetId'];
    await _open(tester, api);
    expect(selected('KHOA_TIDE_EXTREME'), 'DT_0001');
    tester
        .widget<DropdownButtonFormField<String>>(
            find.byType(DropdownButtonFormField<String>))
        .onChanged!('DT_0005');
    await tester.pumpAndSettle();
    expect(selected('KHOA_TIDE_EXTREME'), 'DT_0005');
    expect(selected('KHOA_TIDE_OBS'), 'DT_0005');
    await tester.pumpWidget(const SizedBox());
    await _open(tester, api);
    expect(selected('KHOA_TIDE_EXTREME'), 'DT_0005');
    final button = find.byKey(const ValueKey('marine-nearest-target'));
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(selected('KHOA_TIDE_EXTREME'), 'DT_0001');
    expect(selected('KHOA_TIDE_OBS'), 'DT_0001');
    expect(find.byKey(const ValueKey('marine-tide-info')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('K-water 탭 없이 통합 관측소를 이름·코드로 검색하고 선택한다', (tester) async {
    _screen(tester, width: 320);
    final api = _ExtraApi()
      ..groups = [
        {
          'source': 'HRFCO_RIVER_FLOW',
          'scope': 'station',
          'title': '수위/유량',
          'targets': [
            {
              'id': '1001603',
              'name': '영월군(판운교)',
              'codes': ['1001603', '9000265'],
              'providers': ['한강홍수통제소']
            },
            {
              'id': '9000266',
              'name': '삼척시(갈밭교)',
              'providers': ['K-water']
            },
            {'id': '9000267', 'name': '결측 관측소', 'hasData': false},
          ],
        },
        {
          'source': 'KWATER_RIVER_LEVEL',
          'scope': 'station',
          'title': 'K-water 하천 수위',
          'targets': []
        },
      ];
    await _open(tester, api);
    expect(find.byKey(const ValueKey('extra-source-KWATER_RIVER_LEVEL')),
        findsNothing);
    final input = find.byKey(const ValueKey('water-target-search-input'));
    final combo = find.byType(DropdownButtonFormField<String>);
    expect(tester.getTopLeft(input).dy, lessThan(tester.getTopLeft(combo).dy));
    expect(find.byKey(const ValueKey('water-target-search-results')),
        findsNothing);
    final requests = api.queries.length;
    await tester.ensureVisible(input);
    await tester.enterText(input, '갈 밭');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('water-search-result-9000266')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('water-search-result-1001603')),
        findsNothing);
    expect(api.queries.length, requests);
    expect(find.byType(AlertDialog), findsNothing);
    expect(
        tester
            .getTopLeft(
                find.byKey(const ValueKey('water-target-search-results')))
            .dy,
        greaterThan(tester.getBottomLeft(input).dy));
    await tester.enterText(input, '관측소');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('water-search-result-9000267')),
        findsOneWidget);
    expect(find.textContaining('오늘 관측 자료 없음'), findsOneWidget);
    await tester.enterText(input, '9000265');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('water-search-result-1001603')),
        findsOneWidget);
    await tester.enterText(input, '없는이름');
    await tester.pumpAndSettle();
    expect(find.text('검색 결과가 없어요.'), findsOneWidget);
    await tester.enterText(input, '9000266');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('water-search-result-9000266')));
    await tester.pumpAndSettle();
    expect(api.queries.last, containsPair('source', 'HRFCO_RIVER_FLOW'));
    expect(api.queries.last, containsPair('targetId', '9000266'));
    expect(find.text('자료 제공 · K-water'), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    expect(tester.widget<TextField>(input).controller!.text, isEmpty);
    expect(find.byKey(const ValueKey('water-target-search-results')),
        findsNothing);
    await tester.ensureVisible(input);
    await tester.enterText(input, '갈밭');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('water-target-search-clear')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('water-target-search-results')),
        findsNothing);
    expect(api.queries.last['targetId'], '9000266');
    expect(tester.takeException(), isNull);
  });

  testWidgets('하천 통합 항목의 지표를 바다와 같은 관측 요약·범위·시간별 그래프로 표시한다', (tester) async {
    _screen(tester, width: 320);
    for (final (source, metrics) in [
      ('HRFCO_RIVER_FLOW', [('levelM', '3m'), ('flowM3PerSec', '12㎥/s')]),
      (
        'KWATER_DAM',
        [
          ('levelM', '3m'),
          ('inflowM3PerSec', '21㎥/s'),
          ('dischargeM3PerSec', '9㎥/s')
        ]
      ),
    ]) {
      await tester.pumpWidget(const SizedBox());
      final api = _ExtraApi()
        ..groups = [
          {
            'source': source,
            'scope': source == 'KWATER_DAM' ? 'dam' : 'station',
            'title': '하천',
            'targets': [
              {'id': 'RIVER_1', 'name': '시험 관측소'}
            ],
          }
        ]
        ..records = (_) async => {
              'records': [
                {
                  'time': '2026-10-14 12:30',
                  'values': {
                    'levelM': 3,
                    'flowM3PerSec': 12,
                    'inflowM3PerSec': 21,
                    'dischargeM3PerSec': 9,
                  },
                }
              ]
            };
      await _open(tester, api);
      expect(
          find.byKey(const ValueKey('river-combined-panel')), findsOneWidget);
      expect(
          find.byKey(const ValueKey('extra-description-box')), findsOneWidget);
      for (final (metric, value) in metrics) {
        final chip = find.byKey(ValueKey('river-metric-$metric'));
        await tester.ensureVisible(chip);
        await tester.tap(chip);
        await tester.pumpAndSettle();
        expect(
            find.descendant(
                of: find.byKey(const ValueKey('river-current-value')),
                matching: find.text(value)),
            findsOneWidget);
        expect(find.text('기준 시간 · 12:30'), findsOneWidget);
        expect(
            find.byKey(const ValueKey('river-observed-range')), findsOneWidget);
        expect(
            find.byKey(const ValueKey('river-hourly-scroll')), findsOneWidget);
      }
      expect(api.queries.where((q) => q['source'] == source).length, 1);
      expect(find.text('● 예측'), findsNothing);
      expect(find.textContaining('예측 기준:'), findsNothing);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('하천의 오늘 관측이 없으면 과거 자료를 현재값이나 오늘 범위로 표시하지 않는다', (tester) async {
    _screen(tester);
    final api = _ExtraApi()
      ..groups = [_groups[2]]
      ..records = (_) async => {
            'records': [
              {
                'time': '2026-10-13 12:00',
                'values': {'levelM': 100}
              }
            ],
          };
    await _open(tester, api);
    expect(find.text('오늘 관측값이 없어요'), findsOneWidget);
    expect(
        find.byWidgetPredicate((widget) =>
            widget is DataRangeTile &&
            widget.label == '최저' &&
            widget.value == '자료 없음'),
        findsOneWidget);
    expect(
        find.byWidgetPredicate((widget) =>
            widget is DataRangeTile &&
            widget.label == '최고' &&
            widget.value == '자료 없음'),
        findsOneWidget);
    expect(find.text('표시할 시간별 자료가 없어요.'), findsOneWidget);
    expect(find.text('100m'), findsNothing);
  });

  testWidgets('통합 화면은 예측 조회 실패에도 관측을 유지하고 재시도한다', (tester) async {
    _screen(tester);
    var fail = true;
    final api = _ExtraApi()
      ..groups = [
        ..._groups,
        {..._groups[1], 'source': 'KHOA_TIDE_HOURLY'}
      ]
      ..records = (q) async {
        if (q['source'] == 'KHOA_TIDE_HOURLY' && fail) {
          throw StateError('예측 오류');
        }
        return {
          'records': [
            {
              'time': '2026-10-14 11:00',
              'values': {'tideCm': 120}
            }
          ]
        };
      };
    await _open(tester, api);
    expect(find.text('예측 자료를 불러오지 못했어요.'), findsOneWidget);
    expect(
        find.descendant(
            of: find.byKey(const ValueKey('marine-current-value')),
            matching: find.text('120cm')),
        findsOneWidget);
    fail = false;
    await tester.ensureVisible(find.text('다시 시도'));
    await tester.tap(find.text('다시 시도'));
    await tester.pumpAndSettle();
    expect(find.text('예측 자료를 불러오지 못했어요.'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('통합 화면에서 지점을 바꾸면 이전 관측과 예측의 늦은 응답을 무시한다', (tester) async {
    _screen(tester);
    final previous = Completer<Map<String, dynamic>>();
    final api = _ExtraApi()
      ..groups = [
        ..._groups.where((g) => g['source'] != 'KHOA_TIDE_OBS'),
        for (final source in ['KHOA_TIDE_OBS', 'KHOA_TIDE_HOURLY'])
          {
            ..._groups[1],
            'source': source,
            'targets': [
              {'id': 'DT_0001', 'name': '인천'},
              {'id': 'DT_0005', 'name': '부산'}
            ]
          },
      ];
    await _open(tester, api);
    await _select(tester, 'KHOA_TIDE_OBS');
    api.records = (q) async => q['targetId'] == 'DT_0005'
        ? await previous.future
        : {
            'records': [
              {
                'time': '2026-10-14 12:00',
                'values': {'tideCm': 120}
              }
            ]
          };
    tester
        .widget<DropdownButtonFormField<String>>(
            find.byType(DropdownButtonFormField<String>))
        .onChanged!('DT_0005');
    await tester.pump();
    tester
        .widget<DropdownButtonFormField<String>>(
            find.byType(DropdownButtonFormField<String>))
        .onChanged!('DT_0001');
    await tester.pumpAndSettle();
    previous.complete({
      'records': [
        {
          'time': '2026-10-14 12:00',
          'values': {'tideCm': 999}
        }
      ]
    });
    await tester.pumpAndSettle();
    expect(
        find.descendant(
            of: find.byKey(const ValueKey('marine-current-value')),
            matching: find.text('120cm')),
        findsOneWidget);
    expect(find.text('999cm'), findsNothing);
  });

  testWidgets('이안류는 한국 시각의 6~9월에만 조회하고 그 외에는 제공 시기를 안내한다', (tester) async {
    _screen(tester);
    for (final (date, available) in [
      (DateTime.utc(2026, 5, 31, 14, 59), false),
      (DateTime.utc(2026, 5, 31, 15), true),
      (DateTime.utc(2026, 9, 30, 14, 59), true),
      (DateTime.utc(2026, 9, 30, 15), false),
    ]) {
      await tester.pumpWidget(const SizedBox());
      final api = _ExtraApi()
        ..groups = [
          ..._groups,
          {
            'source': 'KHOA_RIP_CURRENT',
            'scope': 'beach',
            'title': '이안류',
            'targets': [
              {'id': 'HAE', 'name': '해운대'}
            ],
          }
        ];
      await _open(tester, api, now: date);
      await _select(tester, 'KHOA_RIP_CURRENT');
      expect(
          api.queries.any((q) => q['source'] == 'KHOA_RIP_CURRENT'), available);
      expect(find.text('이안류 정보 제공 시기가 아니에요. 6~9월에 제공돼요.'),
          available ? findsNothing : findsOneWidget);
    }
  });

  testWidgets('보고서 내용이 비면 콤보박스에 표시하고 예시는 실제 자료와 구분한다', (tester) async {
    _screen(tester);
    final api = _ExtraApi()..records = (_) async => {'records': []};
    await _open(tester, api);
    await _select(tester, 'NIFS_JELLYFISH_DETAIL');
    expect(find.text('보고된 자료없음'), findsWidgets);
    expect(find.text('보고된 자료가 없어요'), findsNothing);
    final example = find.byKey(const ValueKey('jellyfish-example'));
    await tester.ensureVisible(example);
    expect(find.textContaining('실제 관측·특보가 아니에요'), findsOneWidget);
    expect(find.descendant(of: example, matching: find.byType(ExpansionTile)),
        findsNothing);
  });

  testWidgets('바다·하천의 모든 항목 제목 오른쪽에서 용어 설명을 연다', (tester) async {
    _screen(tester);
    await _open(tester, _ExtraApi());
    for (final source in [
      'KHOA_TIDE_OBS',
      'KHOA_RIP_CURRENT',
      'NIFS_JELLYFISH_DETAIL',
      'KHOA_BUOY_OBS',
      'HRFCO_RIVER_FLOW',
      'KWATER_DAM'
    ]) {
      if (source == 'HRFCO_RIVER_FLOW') {
        await tester.ensureVisible(find.text('하천'));
        await tester.tap(find.text('하천'));
        await tester.pumpAndSettle();
      }
      await _select(tester, source);
      final help = find.byKey(ValueKey('extra-help-$source'));
      await tester.ensureVisible(help);
      await tester.tap(help);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      final dialog = tester.widget<AlertDialog>(find.byType(AlertDialog));
      expect(
          (dialog.title as Text).data,
          {
            'KHOA_TIDE_OBS': '만조·간조/조위란?',
            'KHOA_RIP_CURRENT': '이안류란?',
            'NIFS_JELLYFISH_DETAIL': '해파리란?',
            'KHOA_BUOY_OBS': '수온/유속/유향이란?',
            'HRFCO_RIVER_FLOW': '수위/유량이란?',
            'KWATER_DAM': '댐/보란?',
          }[source]);
      if ([
        'KHOA_RIP_CURRENT',
        'KHOA_BUOY_OBS',
        'HRFCO_RIVER_FLOW',
        'KWATER_DAM'
      ].contains(source)) {
        final body = (dialog.content as SingleChildScrollView).child! as Text;
        expect(body.data, contains('\n\n'));
      }
      await tester.tap(find.text('확인'));
      await tester.pumpAndSettle();
    }
    expect(find.textContaining('시간별 그래프는'), findsNothing);
  });

  testWidgets('해양 통합 화면은 가까운 관측소를 고르고 인근 예측을 함께 읽는다', (tester) async {
    _screen(tester);
    final api = _ExtraApi()
      ..groups = [
        ..._groups,
        {
          'source': 'KHOA_BUOY_OBS',
          'scope': 'station',
          'title': '부이',
          'targets': [
            {'id': 'FAR', 'name': '먼 부이', 'distanceKm': 50},
            {'id': 'NEAR', 'name': '가까운 부이', 'distanceKm': 1.2},
          ]
        },
        {
          'source': 'KHOA_ROMS',
          'scope': 'area',
          'title': '예측',
          'targets': [
            {'id': 'BUOY_NEAR', 'name': '가까운 부이 인근 해역'},
            {'id': 'BUOY_FAR', 'name': '먼 부이 인근 해역'},
          ]
        },
      ];
    await _open(tester, api,
        coordinates: const DeviceCoordinates(latitude: 37.2, longitude: 127));
    await _select(tester, 'KHOA_BUOY_OBS');
    expect(
        api.queries
            .where((q) => q['source'] == 'KHOA_BUOY_OBS')
            .last['targetId'],
        'NEAR');
    expect(
        api.queries.where((q) => q['source'] == 'KHOA_ROMS').last['targetId'],
        'BUOY_NEAR');
    expect(find.byKey(const ValueKey('extra-data-modes')), findsNothing);
    tester
        .widget<DropdownButtonFormField<String>>(
            find.byType(DropdownButtonFormField<String>))
        .onChanged!('FAR');
    await tester.pumpAndSettle();
    await _select(tester, 'NIFS_JELLYFISH_DETAIL');
    await _select(tester, 'KHOA_BUOY_OBS');
    expect(
        api.queries
            .where((q) => q['source'] == 'KHOA_BUOY_OBS')
            .last['targetId'],
        'FAR');
    await _open(tester, api,
        active: false,
        coordinates: const DeviceCoordinates(latitude: 37.3, longitude: 127));
    await _open(tester, api,
        coordinates: const DeviceCoordinates(latitude: 37.3, longitude: 127));
    expect(
        api.queries
            .where((q) => q['source'] == 'KHOA_BUOY_OBS')
            .last['targetId'],
        'FAR');
  });

  testWidgets('바다·하천 칩을 유지하고 낙뢰는 목록·선택·조회에서 제외한다', (tester) async {
    _screen(tester);
    final api = _ExtraApi();
    await _open(tester, api);
    final box = find.byKey(const ValueKey('extra-water-box'));
    expect(box, findsOneWidget);
    expect(find.descendant(of: box, matching: find.byType(TabBar)),
        findsOneWidget);
    expect(find.byKey(const ValueKey('extra-category-기상')), findsNothing);
    expect(
        find.byKey(const ValueKey('extra-source-KMA_LIGHTNING')), findsNothing);
    expect(find.text('낙뢰'), findsNothing);
    List<String> topics() => tester
        .widgetList<ChoiceChip>(find.descendant(
            of: find.byKey(const ValueKey('extra-topic-chips')),
            matching: find.byType(ChoiceChip)))
        .map((chip) => (chip.label as Text).data!)
        .toList();
    expect(topics(), ['만조·간조/조위', '이안류', '해파리', '수온/유속/유향']);
    expect(find.byKey(const ValueKey('marine-tide-summary')), findsOneWidget);
    expect(find.byKey(const ValueKey('extra-source-KHOA_TIDE_EXTREME')),
        findsNothing);
    await tester.tap(find.byKey(const ValueKey('extra-tab-river')));
    await tester.pumpAndSettle();
    expect(topics(), ['수위/유량', '댐/보']);
    expect(api.queries.last['source'], 'KWATER_DAM');
    await tester.tap(find.byKey(const ValueKey('extra-tab-sea')));
    await tester.pumpAndSettle();
    expect(
        api.queries
            .where((query) => query['source'] != 'KHOA_TIDE_EXTREME')
            .last['source'],
        'KHOA_TIDE_OBS');
    for (final chip in tester.widgetList<ChoiceChip>(find.byType(ChoiceChip))) {
      expect(chip.showCheckmark, isFalse);
    }
    expect(find.byType(Checkbox), findsNothing);
    expect(api.queries.any((query) => query['source'] == 'KHOA_TIDE_EXTREME'),
        isTrue);
    expect(api.queries.any((query) => query['source'] == 'KMA_LIGHTNING'),
        isFalse);
    // 낙뢰만 반환하는 서버에서도 기본 선택으로 되살리거나 조회하지 않는다.
    api.groups = [_groups.first];
    final queryCount = api.queries.length;
    await tester
        .widget<RefreshIndicator>(find.byType(RefreshIndicator))
        .onRefresh();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('extra-category-기상')), findsNothing);
    expect(find.text('낙뢰'), findsNothing);
    expect(api.queries.length, queryCount);
    expect(tester.takeException(), isNull);
  });

  testWidgets('만조·간조는 조위 현재 박스의 최저·최고 위에만 표시한다', (tester) async {
    _screen(tester);
    final api = _ExtraApi();
    await _open(tester, api);
    final summary = find.byKey(const ValueKey('marine-tide-summary'));
    final current = find.byKey(const ValueKey('marine-current'));
    expect(_tideTime('만조 11:00'), findsOneWidget);
    expect(_tideTime('간조 21:00'), findsOneWidget);
    expect(find.descendant(of: current, matching: summary), findsOneWidget);
    expect(
        tester.getBottomLeft(summary).dy,
        lessThan(tester
            .getTopLeft(find.byKey(const ValueKey('marine-forecast-range')))
            .dy));
    expect(
        tester.getTopLeft(summary).dy,
        greaterThan(tester
            .getBottomLeft(find.byKey(const ValueKey('extra-topic-chips')))
            .dy));
    final count =
        api.queries.where((q) => q['source'] == 'KHOA_TIDE_EXTREME').length;
    await _select(tester, 'NIFS_JELLYFISH_DETAIL');
    expect(summary, findsNothing);
    expect(api.queries.where((q) => q['source'] == 'KHOA_TIDE_EXTREME').length,
        count);
    await _select(tester, 'KWATER_DAM');
    expect(summary, findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('만조·간조는 1·3과 2·4를 구분하고 오늘의 다음 시각을 조위 박스에 표시한다', (tester) async {
    _screen(tester);
    final api = _ExtraApi()
      ..records = (query) async => {
            'records': query['source'] != 'KHOA_TIDE_EXTREME'
                ? []
                : [
                    {
                      'time': '2026-10-14T03:00:00+09:00',
                      'values': {'extremeType': 1}
                    },
                    {
                      'time': '2026-10-14T09:30:00+09:00',
                      'values': {'extremeType': '2'}
                    },
                    {
                      'time': '2026-10-14T15:00:00+09:00',
                      'values': {'extremeType': 3}
                    },
                    {
                      'time': '2026-10-14T21:30:00+09:00',
                      'values': {'extremeType': 4}
                    },
                    {
                      'time': '2026-10-13T10:00:00+09:00',
                      'values': {'extremeType': 1}
                    },
                    {
                      'time': '2026-10-15T10:00:00+09:00',
                      'values': {'extremeType': 2}
                    },
                    {
                      'time': '2026-10-14T10:00:00+09:00',
                      'values': {'extremeType': 9}
                    },
                  ]
          };
    await _open(tester, api);
    expect(_tideTime('만조 15:00'), findsOneWidget);
    expect(_tideTime('간조 21:30'), findsOneWidget);
    expect(_tideTime('만조 3:00'), findsNothing);
    expect(_tideTime('간조 9:30'), findsNothing);
  });

  testWidgets('관측소 변경 전의 늦은 만조·간조 응답은 새 관측소를 덮어쓰지 않는다', (tester) async {
    _screen(tester);
    final previous = Completer<Map<String, dynamic>>();
    final api = _ExtraApi()
      ..groups = [
        {
          ..._groups[3],
          'targets': [
            {'id': 'DT_0001', 'name': '인천'},
            {'id': 'DT_0005', 'name': '부산'},
          ]
        },
      ];
    api.records = (q) async {
      if (q['source'] != 'KHOA_TIDE_EXTREME') return {'records': []};
      if (q['targetId'] == 'DT_0001') return previous.future;
      return {
        'records': [
          {
            'time': '2026-10-14T15:00:00+09:00',
            'values': {'extremeType': 3}
          }
        ]
      };
    };
    await _open(tester, api);
    tester
        .widget<DropdownButtonFormField<String>>(
            find.byType(DropdownButtonFormField<String>))
        .onChanged!('DT_0005');
    await tester.pumpAndSettle();
    expect(_tideTime('만조 15:00'), findsOneWidget);
    expect(api.queries.last, containsPair('targetId', 'DT_0005'));
    previous.complete({
      'records': [
        {
          'time': '2026-10-14T11:00:00+09:00',
          'values': {'extremeType': 1}
        }
      ]
    });
    await tester.pumpAndSettle();
    expect(_tideTime('만조 15:00'), findsOneWidget);
    expect(_tideTime('만조 11:00'), findsNothing);
  });

  testWidgets('만조·간조 조회 실패는 조위를 유지하고 같은 관측소로 재시도한다', (tester) async {
    _screen(tester, width: 320);
    final api = _ExtraApi();
    var fail = true;
    api.records = (q) async {
      if (q['source'] == 'KHOA_TIDE_EXTREME' && fail) throw StateError('실패');
      return {
        'records': [
          {
            'time': '2026-10-14T11:00:00+09:00',
            'values': {'tideCm': 100, 'extremeType': 1}
          }
        ]
      };
    };
    await _open(tester, api);
    expect(find.text('100cm'), findsWidgets);
    expect(_tideTime('만조 --:--'), findsOneWidget);
    expect(find.text('만조·간조 자료를 불러오지 못했어요.'), findsOneWidget);
    fail = false;
    final retry = find.text('만조·간조 다시 시도');
    await tester.ensureVisible(retry);
    await tester.tap(retry);
    await tester.pumpAndSettle();
    expect(_tideTime('만조 11:00'), findsOneWidget);
    expect(api.queries.last, containsPair('targetId', 'DT_0001'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('지역 변경 전의 늦은 만조·간조 응답은 새 지역의 시각을 덮어쓰지 않는다', (tester) async {
    _screen(tester);
    final previous = Completer<Map<String, dynamic>>();
    final api = _ExtraApi()
      ..records = (query) async {
        if (query['source'] != 'KHOA_TIDE_EXTREME') return {'records': []};
        if (query['nx'] == '60') return previous.future;
        return {
          'records': [
            {
              'time': '2026-10-14T13:00:00+09:00',
              'values': {'extremeType': 3}
            },
            {
              'time': '2026-10-14T19:00:00+09:00',
              'values': {'extremeType': 4}
            },
          ]
        };
      };
    await _open(tester, api);
    await tester.pumpWidget(MaterialApp(
      theme: WeatherCareTheme.light(),
      home: Scaffold(
          body: ExtraTab(
              client: api,
              grid: const KmaGrid(nx: 61, ny: 121),
              active: true,
              now: DateTime.utc(2026, 10, 14))),
    ));
    await tester.pumpAndSettle();
    expect(_tideTime('만조 13:00'), findsOneWidget);
    previous.complete({
      'records': [
        {
          'time': '2026-10-14T11:00:00+09:00',
          'values': {'extremeType': 1}
        },
      ]
    });
    await tester.pumpAndSettle();
    expect(_tideTime('만조 13:00'), findsOneWidget);
    expect(_tideTime('만조 11:00'), findsNothing);
  });

  testWidgets('콤보박스에서 구역을 바꾸면 해당 대상의 데이터를 조회한다', (tester) async {
    _screen(tester);
    final api = _ExtraApi();
    await _open(tester, api);
    await _select(tester, 'KWATER_DAM');
    expect(
        find.descendant(
            of: find.byKey(const ValueKey('river-current-value')),
            matching: find.text('20.5m')),
        findsOneWidget);
    final combo = find.byType(DropdownButtonFormField<String>);
    await tester.ensureVisible(combo);
    await tester.tap(combo);
    await tester.pumpAndSettle();
    await tester.tap(find.text('둘째댐').last);
    await tester.pumpAndSettle();
    expect(api.queries.last['source'], 'KWATER_DAM');
    expect(api.queries.last['targetId'], '2022511');
    expect(
        find.descendant(
            of: find.byKey(const ValueKey('river-current-value')),
            matching: find.text('30.5m')),
        findsOneWidget);
    expect(
        find.descendant(
            of: find.byKey(const ValueKey('river-current-value')),
            matching: find.text('20.5m')),
        findsNothing);
    final inflow = find.byKey(const ValueKey('river-metric-inflowM3PerSec'));
    await tester.ensureVisible(inflow);
    await tester.tap(inflow);
    await tester.pumpAndSettle();
    expect(
        find.descendant(
            of: find.byKey(const ValueKey('river-current-value')),
            matching: find.text('4.2㎥/s')),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('조위는 한 관측소의 현재 관측과 예측 최저·최고를 함께 표시한다', (tester) async {
    _screen(tester);
    final api = _ExtraApi()
      ..groups = [
        ..._groups,
        {..._groups[1], 'source': 'KHOA_TIDE_HOURLY', 'title': '예측 조위'}
      ]
      ..records = (q) async => {
            'records': [
              {
                'time': '2026-10-14 10:00',
                'values': {
                  'tideCm': q['source'] == 'KHOA_TIDE_HOURLY' ? 999 : 120
                }
              },
              {
                'time': '2026-10-14 14:00',
                'values': {
                  'tideCm': q['source'] == 'KHOA_TIDE_HOURLY' ? 230 : 777
                }
              },
            ]
          };
    await _open(tester, api);
    expect(
        find.descendant(
            of: find.byKey(const ValueKey('marine-current-value')),
            matching: find.text('120cm')),
        findsOneWidget);
    expect(find.text('기준 시간 · 10:00'), findsOneWidget);
    expect(
        find.byWidgetPredicate((widget) =>
            widget is DataRangeTile &&
            widget.label == '최저' &&
            widget.value == '230cm'),
        findsOneWidget);
    expect(
        find.byWidgetPredicate((widget) =>
            widget is DataRangeTile &&
            widget.label == '최고' &&
            widget.value == '999cm'),
        findsOneWidget);
    final chart =
        tester.widget<HourlyValueChart>(find.byType(HourlyValueChart));
    expect(chart.series.values[10]?.lower, 120);
    expect(chart.series.values[14], isNull);
    expect(chart.overlays.single.values[10]?.lower, 999);
    expect(chart.overlays.single.values[14]?.lower, 230);
    expect(chart.avoidLineOverlaps, isTrue);
    expect(
        tester
            .getRect(find.byKey(
                const ValueKey('hourly-value-marine-observed-tideCm-10')))
            .overlaps(tester.getRect(find.byKey(
                const ValueKey('hourly-value-marine-forecast-tideCm-10')))),
        isFalse);
    expect(find.byKey(const ValueKey('marine-metric-chips')), findsNothing);
    expect(find.byKey(const ValueKey('extra-data-modes')), findsNothing);
    expect(find.byKey(const ValueKey('marine-hourly-scroll')), findsOneWidget);
    expect(find.text('조위\ncm'), findsOneWidget);
    expect(find.textContaining('기준 격자'), findsNothing);
    expect(find.byKey(const ValueKey('extra-description-box')), findsOneWidget);
    expect(find.textContaining('격자 전체의 값'), findsNothing);
  });

  testWidgets('자료가 없는 항목도 설명과 비활성 선택창을 표시한다', (tester) async {
    _screen(tester);
    final api = _ExtraApi();
    await _open(tester, api);
    final queries = api.queries.length;
    await _select(tester, 'KHOA_RIP_CURRENT');
    expect(find.textContaining('이안류 위험지수'), findsOneWidget);
    expect(find.text('이안류 정보 제공 시기가 아니에요. 6~9월에 제공돼요.'), findsOneWidget);
    expect(find.byType(DropdownButtonFormField<String>), findsNothing);
    expect(api.queries.length, queries);
    expect(find.byKey(const ValueKey('extra-timeline')), findsNothing);
  });

  testWidgets('수온·유속·유향은 한줄 지표 칩과 관측·예측 통합 그래프를 표시한다', (tester) async {
    _screen(tester, width: 320);
    final api = _ExtraApi()
      ..groups = [
        ..._groups,
        {
          'source': 'KHOA_BUOY_OBS',
          'title': '부이',
          'scope': 'station',
          'targets': [
            {'id': 'TW_1', 'name': '인천항'}
          ]
        },
        {
          'source': 'KHOA_ROMS',
          'title': '예측',
          'scope': 'area',
          'targets': [
            {'id': 'BUOY_TW_1', 'name': '인천항 인근 해역'}
          ]
        },
      ]
      ..records = (q) async => {
            'records': [
              {
                'time': '2026-10-14 12:00',
                'values': {
                  'waterTempC': 20,
                  'currentSpeedCmPerSec': 123,
                  'currentDirectionDeg': 90
                }
              },
              {
                'time': '2026-10-14 14:00',
                'values': {
                  'waterTempC': 22,
                  'currentSpeed': 2,
                  'currentDirectionDeg': 120
                }
              },
            ]
          };
    await _open(tester, api);
    await _select(tester, 'KHOA_BUOY_OBS');
    final speed = find.byKey(const ValueKey('marine-metric-currentSpeed'));
    await tester.ensureVisible(speed);
    await tester.tap(speed);
    await tester.pumpAndSettle();
    expect(
        find.descendant(
            of: find.byKey(const ValueKey('marine-current-value')),
            matching: find.text('1.2m/s')),
        findsOneWidget);
    expect(find.textContaining('예측 기준:'), findsNothing);
    expect(find.byKey(const ValueKey('extra-data-modes')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('보고서가 없으면 안내하고 해양 자료가 전혀 없어도 통합 상태를 표시한다', (tester) async {
    _screen(tester);
    final api = _ExtraApi()
      ..groups =
          _groups.where((g) => g['source'] != 'NIFS_JELLYFISH_DETAIL').toList();
    await _open(tester, api);
    await _select(tester, 'NIFS_JELLYFISH_DETAIL');
    expect(find.text('보고된 자료없음'), findsWidgets);
    expect(find.text('보고된 자료가 없어요'), findsNothing);
    await _select(tester, 'KHOA_BUOY_OBS');
    expect(find.text('조회 가능한 지점 없음'), findsOneWidget);
    expect(find.text('오늘 관측값이 없어요'), findsOneWidget);
    expect(
        find.byWidgetPredicate((widget) =>
            widget is DataRangeTile &&
            widget.label == '최저' &&
            widget.value == '자료 없음'),
        findsOneWidget);
  });

  testWidgets('만조·간조가 과거 자료만 받으면 시간 대신 마지막 자료 날짜를 안내한다', (tester) async {
    _screen(tester);
    final api = _ExtraApi();
    await tester.pumpWidget(MaterialApp(
      theme: WeatherCareTheme.light(),
      home: Scaffold(
          body: ExtraTab(
              client: api,
              grid: const KmaGrid(nx: 58, ny: 125),
              active: true,
              now: DateTime.utc(2026, 10, 20))),
    ));
    await tester.pumpAndSettle();
    expect(_tideTime('만조 --:--'), findsOneWidget);
    expect(_tideTime('간조 --:--'), findsOneWidget);
    expect(find.text('오늘 예보가 없어요. 자료 기준일: 2026-10-15'), findsOneWidget);
  });

  testWidgets('바다의 늦은 응답이 하천 탭의 자료를 덮어쓰지 않는다', (tester) async {
    _screen(tester);
    final previous = Completer<Map<String, dynamic>>();
    final api = _ExtraApi();
    await _open(tester, api);
    api.records = (query) async => query['source'] == 'NIFS_JELLYFISH_DETAIL'
        ? await previous.future
        : {
            'records': [
              {
                'time': '2026-10-14 11:00',
                'values': {'levelM': 30.5}
              }
            ]
          };
    await tester
        .tap(find.byKey(const ValueKey('extra-source-NIFS_JELLYFISH_DETAIL')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('extra-tab-river')));
    await tester.pumpAndSettle();
    previous.complete({
      'records': [
        {
          'time': '2026-10-14',
          'values': {'내용': '이전 바다 보고서'}
        }
      ]
    });
    await tester.pumpAndSettle();
    expect(
        find.descendant(
            of: find.byKey(const ValueKey('river-current-value')),
            matching: find.text('30.5m')),
        findsOneWidget);
    expect(find.textContaining('이전 바다 보고서'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('하천 요약은 오늘 관측만 사용하며 과거 날짜와 미래 시각을 제외한다', (tester) async {
    _screen(tester);
    final api = _ExtraApi()
      ..records = (_) async => {
            'records': [
              {
                'time': '2026-10-13 23:00',
                'values': {'levelM': 999}
              },
              {
                'time': '2026-10-14 11:00',
                'values': {'levelM': 20}
              },
              {
                'time': '2026-10-14 12:30',
                'values': {'levelM': 21}
              },
              {
                'time': '2026-10-14 14:00',
                'values': {'levelM': 999}
              },
            ]
          };
    await _open(tester, api);
    await _select(tester, 'KWATER_DAM');
    expect(find.text('기준 시간 · 12:30'), findsOneWidget);
    expect(
        find.byWidgetPredicate((widget) =>
            widget is DataRangeTile &&
            widget.label == '최저' &&
            widget.value == '20m'),
        findsOneWidget);
    expect(
        find.byWidgetPredicate((widget) =>
            widget is DataRangeTile &&
            widget.label == '최고' &&
            widget.value == '21m'),
        findsOneWidget);
    expect(find.byKey(const ValueKey('river-hourly-scroll')), findsOneWidget);
    expect(
        tester
            .state<ScrollableState>(find.descendant(
                of: find.byKey(const ValueKey('river-hourly-scroll')),
                matching: find.byType(Scrollable)))
            .position
            .pixels,
        greaterThan(0));
    expect(find.text('● 예측'), findsNothing);
    expect(find.text('시간대별 수위'), findsOneWidget);
    expect(find.textContaining('오늘 예측'), findsNothing);
    expect(find.byKey(const ValueKey('extra-timeline')), findsNothing);
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
      ..groups = [_groups[4]]
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
    expect(find.text('보고서 내용'), findsOneWidget);
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
    expect(find.text('댐·보 없음'), findsOneWidget);
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
    expect(find.text('관측 자료를 불러오지 못했어요.'), findsOneWidget);
    api.failRecords = false;
    await tester.ensureVisible(find.text('다시 시도'));
    await tester.tap(find.text('다시 시도'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('marine-combined-panel')), findsOneWidget);
    expect(find.text('관측 자료를 불러오지 못했어요.'), findsNothing);
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
    await tester.tap(find.byKey(const ValueKey('extra-tab-river')));
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
    expect(
        find.descendant(
            of: find.byKey(const ValueKey('river-current-value')),
            matching: find.text('30.5m')),
        findsOneWidget);
    expect(
        find.descendant(
            of: find.byKey(const ValueKey('river-current-value')),
            matching: find.text('99m')),
        findsNothing);
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
    expect(find.byKey(const ValueKey('marine-combined-panel')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('그래프 지표와 시각을 바꿔도 결측을 0으로 만들지 않는다', (tester) async {
    _screen(tester);
    final api = _ExtraApi()
      ..groups = [
        {..._groups[1], 'source': 'KMA_LIGHTNING', 'scope': 'grid'}
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
    final result = await api.records!({});
    await tester.pumpWidget(MaterialApp(
        theme: WeatherCareTheme.light(),
        home: Scaffold(
            body: SingleChildScrollView(
                child: ExtraDataOverview(
          records: (result['records'] as List).cast<Map<String, dynamic>>(),
          source: 'GENERIC_OBSERVATION',
          targetName: '시험 관측소',
          labelFor: (key) => {'tideCm': '조위', 'waterTempC': '수온'}[key] ?? key,
          unitFor: (key) => key == 'tideCm' ? 'cm' : '℃',
          timeFor: marineRecordTime,
          timeLabel: (raw) => marineRecordTime(raw)!
              .toIso8601String()
              .substring(0, 16)
              .replaceFirst('T', ' '),
        )))));
    await tester.pumpAndSettle();
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
    expect(
        find.byWidgetPredicate((widget) =>
            widget is DataRangeTile &&
            widget.label == '최저' &&
            widget.value == '20℃'),
        findsOneWidget);
    expect(
        find.byWidgetPredicate((widget) =>
            widget is DataRangeTile &&
            widget.label == '최고' &&
            widget.value == '22℃'),
        findsOneWidget);
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
