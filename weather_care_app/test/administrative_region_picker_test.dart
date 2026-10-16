import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weather_care/features/settings/administrative_region_picker_screen.dart';
import 'package:weather_care/models/selectable_region.dart';
import 'package:weather_care/services/region_catalog.dart';

void main() {
  final catalog = RegionCatalog.fromJson(
      jsonDecode(File('assets/data/kma_regions.json').readAsStringSync())
          as Map<String, dynamic>);

  Future<void> reveal(WidgetTester tester, Finder target) =>
      tester.scrollUntilVisible(target, 180,
          scrollable: find.descendant(
            of: find.byType(CustomScrollView),
            matching: find.byType(Scrollable),
          ));

  Future<void> open(
    WidgetTester tester, {
    Future<RegionCatalog> Function()? loadCatalog,
    ValueChanged<ForecastGridSelection?>? onSelected,
    double textScale = 1,
  }) async {
    await tester.pumpWidget(MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Builder(
          builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () async {
                    final selected =
                        await Navigator.of(context).push<ForecastGridSelection>(
                      MaterialPageRoute(
                          builder: (_) => AdministrativeRegionPickerScreen(
                                loadCatalog: loadCatalog ?? () async => catalog,
                              )),
                    );
                    onSelected?.call(selected);
                  },
                  child: const Text('지역 선택 열기'),
                ),
              )),
    ));
    await tester.tap(find.text('지역 선택 열기'));
    await tester.pumpAndSettle();
  }

  test('모든 행정지역의 대표 격자가 기존 지도 구역과 일치한다', () {
    final map = jsonDecode(
        File('../weather_care_privacy/public/weather-map/data/grid-areas.json')
            .readAsStringSync()) as Map<String, dynamic>;
    final grids = {for (final grid in map['grids']) grid['id']: grid};
    for (final region in catalog.regions) {
      final grid = grids[region.gridId];
      expect(grid, isNotNull, reason: region.fullName);
      expect(
          (grid['regions'] as List)
              .any((r) => r['code'] == region.code && r['name'] == region.name),
          isTrue,
          reason: region.key);
    }
  });

  testWidgets('단계별 탐색 후 읍면동을 고르면 기존 대표 격자와 지역 키를 반환한다', (tester) async {
    ForecastGridSelection? result;
    await open(tester, onSelected: (value) => result = value);
    await reveal(tester, find.text('서울특별시'));
    await tester.tap(find.text('서울특별시'));
    await tester.pumpAndSettle();
    expect(result, isNull);
    await reveal(tester, find.text('구로구'));
    await tester.tap(find.text('구로구'));
    await tester.pumpAndSettle();
    final region = catalog.search('서울 구로 구로3동').single;
    await reveal(tester, find.text(region.fullName));
    await tester.tap(find.text(region.fullName));
    await tester.pumpAndSettle();
    expect(result?.gridId, region.gridId);
    expect(result?.regionKey, region.key);
    expect(result?.regionName, region.fullName);
  });

  testWidgets('동명·중복 코드 지역도 전체 이름으로 구분해 검색하고 선택한다', (tester) async {
    ForecastGridSelection? result;
    await open(tester, onSelected: (value) => result = value);
    await tester.enterText(find.byType(TextField), '강서구');
    await tester.pumpAndSettle();
    await reveal(tester, find.text('부산광역시 강서구'));
    expect(find.text('부산광역시 강서구'), findsOneWidget);
    await reveal(tester, find.text('서울특별시 강서구'));
    expect(find.text('서울특별시 강서구'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '운서2동');
    await tester.pumpAndSettle();
    final region = catalog.search('운서2동').single;
    await tester.tap(find.text(region.fullName));
    await tester.pumpAndSettle();
    expect(result?.regionKey, region.key);
    expect(result?.gridId, region.gridId);
  });

  testWidgets('검색 실패와 검색어 지우기·상위 지역 복귀를 지원한다', (tester) async {
    await open(tester);
    await reveal(tester, find.text('서울특별시'));
    await tester.tap(find.text('서울특별시'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '없는동네987654');
    await tester.pumpAndSettle();
    expect(find.textContaining('검색 결과가 없어요'), findsOneWidget);
    await tester.tap(find.byTooltip('검색어 지우기'));
    await tester.pumpAndSettle();
    expect(
        find.text(catalog.childrenOf('1100000000').first.name), findsOneWidget);
    await tester.tap(find.text('전체'));
    await tester.pumpAndSettle();
    expect(find.text('강원특별자치도'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('지역 선택 열기'), findsOneWidget);
  });

  testWidgets('지역 목록 실패 후 다시 불러올 수 있다', (tester) async {
    var attempts = 0;
    await open(tester, loadCatalog: () async {
      if (attempts++ == 0) throw const FormatException();
      return catalog;
    });
    expect(find.text('지역 목록을 불러오지 못했어요.'), findsOneWidget);
    await tester.tap(find.text('다시 시도'));
    await tester.pumpAndSettle();
    expect(find.text('강원특별자치도'), findsOneWidget);
  });

  testWidgets('320px·2배 글씨와 키보드에서도 지역을 검색하고 선택한다', (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    await open(tester, textScale: 2);
    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    await tester.enterText(find.byType(TextField), '경남 창원 마산합포구');
    await tester.pumpAndSettle();
    final district = catalog
        .search('경남 창원 마산합포구')
        .firstWhere((region) => catalog.childrenOf(region.code).isNotEmpty);
    await tester.ensureVisible(find.text(district.fullName));
    await tester.tap(find.text(district.fullName));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.enterText(find.byType(TextField), '제주 우도면');
    await tester.pumpAndSettle();
    expect(find.text('제주특별자치도 제주시 우도면'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('제주특별자치도 제주시 우도면'));
    await tester.tap(find.text('제주특별자치도 제주시 우도면'));
    await tester.pumpAndSettle();
    expect(find.text('지역 선택 열기'), findsOneWidget);
  });
}
