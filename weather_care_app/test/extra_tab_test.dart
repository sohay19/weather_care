import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weather_care/features/home/tabs/extra_tab.dart';
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
    {DateTime? now, DeviceCoordinates? coordinates, bool active = true}) async {
  await tester.pumpWidget(MaterialApp(
    theme: WeatherCareTheme.light(),
    home: Scaffold(
        body: ExtraTab(
            client: api,
            grid: const KmaGrid(nx: 60, ny: 121),
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

void main() {
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
            of: find.byKey(const ValueKey('marine-current')),
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
            of: find.byKey(const ValueKey('marine-current')),
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

  testWidgets('보고서는 목록이 비었거나 선택한 보고서 내용이 비면 같은 문구를 쓴다', (tester) async {
    _screen(tester);
    final api = _ExtraApi()..records = (_) async => {'records': []};
    await _open(tester, api);
    await _select(tester, 'NIFS_JELLYFISH_DETAIL');
    expect(find.text('보고된 자료가 없어요'), findsOneWidget);
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
        'NEAR');
  });

  testWidgets('큰 박스의 바다·하천 탭은 지정한 칩을 표시하고 기상 자료도 유지한다', (tester) async {
    _screen(tester);
    final api = _ExtraApi();
    await _open(tester, api);
    final box = find.byKey(const ValueKey('extra-water-box'));
    expect(box, findsOneWidget);
    expect(find.descendant(of: box, matching: find.byType(TabBar)),
        findsOneWidget);
    expect(find.byKey(const ValueKey('extra-category-기상')), findsOneWidget);
    List<String> topics() => tester
        .widgetList<ChoiceChip>(find.descendant(
            of: find.byKey(const ValueKey('extra-topic-chips')),
            matching: find.byType(ChoiceChip)))
        .map((chip) => (chip.label as Text).data!)
        .toList();
    expect(topics(), ['조위', '이안류', '해파리', '수온/유속/유향']);
    expect(find.byKey(const ValueKey('marine-tide-summary')), findsOneWidget);
    expect(find.byKey(const ValueKey('extra-source-KHOA_TIDE_EXTREME')),
        findsNothing);
    await tester.tap(find.byKey(const ValueKey('extra-tab-river')));
    await tester.pumpAndSettle();
    expect(topics(), ['수위 및 유량', 'K-water 하천 수위', '댐 보 운영']);
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
    await _select(tester, 'KMA_LIGHTNING');
    expect(find.text('낙뢰 발생  2회'), findsOneWidget);
    expect(find.byType(DropdownButtonFormField<String>), findsNothing);
    expect(api.queries.last['targetId'], '60_121');
    expect(tester.takeException(), isNull);
  });

  testWidgets('만조·간조는 다른 바다 칩에서도 최상단 한 행을 유지하고 설명은 팝업으로 표시한다', (tester) async {
    _screen(tester);
    await _open(tester, _ExtraApi());
    final summary = find.byKey(const ValueKey('marine-tide-summary'));
    expect(find.text('만조 11:00'), findsOneWidget);
    expect(find.text('간조 21:00'), findsOneWidget);
    expect(
        tester.getBottomLeft(summary).dy,
        lessThan(tester
            .getTopLeft(find.byKey(const ValueKey('extra-topic-chips')))
            .dy));
    await _select(tester, 'NIFS_JELLYFISH_DETAIL');
    expect(find.text('만조 11:00'), findsOneWidget);
    expect(find.text('간조 21:00'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('marine-tide-info')));
    await tester.tap(find.byKey(const ValueKey('marine-tide-info')));
    await tester.pumpAndSettle();
    expect(find.text('만조·간조 안내'), findsOneWidget);
    expect(find.textContaining('만조는 바닷물 높이가 가장 높아질 때'), findsOneWidget);
    expect(find.text('기준 관측소'), findsOneWidget);
    await tester.tap(find.text('닫기'));
    await tester.pumpAndSettle();
    await _select(tester, 'KWATER_DAM');
    expect(summary, findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('만조·간조는 1·3과 2·4를 구분하고 오늘의 다음 시각만 상단에 표시한다', (tester) async {
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
    expect(find.text('만조 15:00'), findsOneWidget);
    expect(find.text('간조 21:30'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('marine-tide-info')));
    await tester.pumpAndSettle();
    expect(find.text('만조: 3:00 / 15:00'), findsOneWidget);
    expect(find.text('간조: 9:30 / 21:30'), findsOneWidget);
  });

  testWidgets('만조·간조 관측소는 설명 팝업에서 변경하며 다른 칩의 자료를 유지한다', (tester) async {
    _screen(tester);
    final api = _ExtraApi()
      ..groups = [
        ..._groups.where((group) => group['source'] != 'KHOA_TIDE_EXTREME'),
        {
          ..._groups[1],
          'targets': [
            {'id': 'DT_0001', 'name': '인천'},
            {'id': 'DT_0005', 'name': '부산'},
          ]
        },
      ];
    await _open(tester, api);
    await _select(tester, 'NIFS_JELLYFISH_DETAIL');
    await tester.tap(find.byKey(const ValueKey('marine-tide-info')));
    await tester.pumpAndSettle();
    tester
        .widget<DropdownButtonFormField<String>>(
            find.byKey(const ValueKey('marine-tide-target-DT_0001')))
        .onChanged!('DT_0005');
    await tester.pumpAndSettle();
    expect(api.queries.last['source'], 'KHOA_TIDE_EXTREME');
    expect(api.queries.last['targetId'], 'DT_0005');
    await tester.tap(find.text('닫기'));
    await tester.pumpAndSettle();
    expect(find.text('내용  해파리 출현 해역을 확인해주세요.'), findsOneWidget);
  });

  testWidgets('만조·간조 자료가 없거나 목록 조회에 실패해도 한 행과 설명 버튼은 남는다', (tester) async {
    _screen(tester, width: 320);
    final api = _ExtraApi()..failCatalog = true;
    await _open(tester, api);
    expect(find.text('만조 --:--'), findsOneWidget);
    expect(find.text('간조 --:--'), findsOneWidget);
    expect(find.byKey(const ValueKey('marine-tide-info')), findsOneWidget);
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
    expect(find.text('만조 13:00'), findsOneWidget);
    previous.complete({
      'records': [
        {
          'time': '2026-10-14T11:00:00+09:00',
          'values': {'extremeType': 1}
        },
      ]
    });
    await tester.pumpAndSettle();
    expect(find.text('만조 13:00'), findsOneWidget);
    expect(find.text('만조 11:00'), findsNothing);
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
            of: find.byKey(const ValueKey('marine-current')),
            matching: find.text('120cm')),
        findsOneWidget);
    expect(find.text('기준 시간 · 10/14 10:00'), findsOneWidget);
    expect(find.text('최저 230cm'), findsOneWidget);
    expect(find.text('최고 999cm'), findsOneWidget);
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
    expect(find.textContaining('이안류의 위험지수'), findsOneWidget);
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
            of: find.byKey(const ValueKey('marine-current')),
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
    expect(find.text('보고된 자료가 없어요'), findsOneWidget);
    await _select(tester, 'KHOA_BUOY_OBS');
    expect(find.text('조회 가능한 지점 없음'), findsOneWidget);
    expect(find.text('오늘 관측값이 없어요'), findsOneWidget);
    expect(find.text('최저 자료 없음'), findsOneWidget);
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
    expect(find.text('만조 --:--'), findsOneWidget);
    expect(find.text('간조 --:--'), findsOneWidget);
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
    expect(find.text('수위  30.5m'), findsOneWidget);
    expect(find.textContaining('이전 바다 보고서'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('하천은 실제 시각의 날짜별 타임라인을 유지한다', (tester) async {
    _screen(tester);
    final api = _ExtraApi()
      ..records = (_) async => {
            'records': [
              {
                'time': '2026-10-14 11:00',
                'values': {'levelM': 20}
              },
              {
                'time': '2026-10-15 12:00',
                'values': {'levelM': 21}
              }
            ]
          };
    await _open(tester, api);
    await _select(tester, 'KWATER_DAM');
    expect(find.byKey(const ValueKey('extra-timeline')), findsOneWidget);
    expect(find.text('2026-10-14'), findsOneWidget);
    expect(find.text('2026-10-15'), findsOneWidget);
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
    await _select(tester, 'KWATER_DAM');
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
    expect(find.byKey(const ValueKey('marine-combined-panel')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('그래프 지표와 시각을 바꿔도 결측을 0으로 만들지 않는다', (tester) async {
    _screen(tester);
    final api = _ExtraApi()
      ..groups = [
        {..._groups[1], 'source': 'KWATER_RIVER_LEVEL', 'scope': 'station'}
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
