import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weather_care/features/settings/settings_screen.dart';
import 'package:weather_care/features/settings/region_picker_screen.dart';
import 'package:weather_care/models/app_settings.dart';
import 'package:weather_care/services/region_catalog.dart';

void main() {
  final catalog = RegionCatalog.fromJson(
      jsonDecode(File('assets/data/kma_regions.json').readAsStringSync())
          as Map<String, dynamic>);
  testWidgets('지역 탐색을 취소하면 GPS 설정과 기존 값이 유지된다', (tester) async {
    final changes = <AppSettings>[];
    await tester.pumpWidget(MaterialApp(
        home: SettingsScreen(
            loadRegionCatalog: () async => catalog,
            onSettingsChanged: (s) async => changes.add(s))));
    await tester.tap(find.byKey(const ValueKey('location-settings-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('지역 직접 선택'));
    await tester.pumpAndSettle();
    expect(find.byType(RegionPickerScreen), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(changes, isEmpty);
    expect(find.text('지역 선택·변경'), findsNothing);
  });
  testWidgets('검색 결과와 확인 대화상자를 거쳐서만 지역 설정을 변경한다', (tester) async {
    final changes = <AppSettings>[];
    await tester.pumpWidget(MaterialApp(
        home: SettingsScreen(
            loadRegionCatalog: () async => catalog,
            onSettingsChanged: (s) async => changes.add(s))));
    await tester.tap(find.byKey(const ValueKey('location-settings-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('지역 직접 선택'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('region-search')), '부산 해운대 좌1동');
    await tester.pumpAndSettle();
    await tester.tap(find.text('좌제1동'));
    await tester.pumpAndSettle();
    expect(changes, isEmpty);
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    expect(changes, isEmpty);
    await tester.tap(find.text('좌제1동'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('이 지역 사용'));
    await tester.pumpAndSettle();
    expect(changes.single.locationMode, 'MANUAL');
    expect(changes.single.currentRegionId, '100_76');
    expect(changes.single.manualRegionKey,
        catalog.search('부산 해운대 좌1동').single.key);
    expect(find.byType(RegionPickerScreen), findsNothing);
  });
  testWidgets('시도·시군구 순서로 탐색하고 상위 목록으로 돌아갈 수 있다', (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: RegionPickerScreen(loadCatalog: () async => catalog)));
    await tester.pumpAndSettle();
    final results = find.descendant(
        of: find.byKey(const ValueKey('region-results')),
        matching: find.byType(Scrollable));
    final busan = find.byKey(ValueKey(
        'region-${catalog.childrenOf('').firstWhere((r) => r.name == '부산광역시').key}'));
    await tester.scrollUntilVisible(busan, 300, scrollable: results);
    await tester.pumpAndSettle();
    await tester.tap(busan);
    await tester.pumpAndSettle();
    final haeundae = find.byKey(ValueKey(
        'region-${catalog.search('부산 해운대구').firstWhere((r) => r.name == '해운대구').key}'));
    await tester.scrollUntilVisible(haeundae, 300, scrollable: results);
    await tester.pumpAndSettle();
    await tester.tap(haeundae);
    await tester.pumpAndSettle();
    expect(find.text('해운대구 대표 지점 선택'), findsOneWidget);
    expect(find.text('부산광역시 해운대구'), findsOneWidget);
    await tester.tap(find.text('상위 지역 보기'));
    await tester.pumpAndSettle();
    expect(find.text('부산광역시 대표 지점 선택'), findsOneWidget);
  });
  testWidgets('자료 로딩 실패에서 재시도하며 빈 검색도 안내한다', (tester) async {
    var loads = 0;
    await tester
        .pumpWidget(MaterialApp(home: RegionPickerScreen(loadCatalog: () async {
      if (loads++ == 0) throw StateError('missing');
      return catalog;
    })));
    await tester.pumpAndSettle();
    expect(find.textContaining('기존 지역은 변경하지 않았어요'), findsOneWidget);
    await tester.tap(find.text('다시 시도'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('region-search')), '없는동네987654');
    await tester.pumpAndSettle();
    expect(find.textContaining('일치하는 지역이 없어요'), findsOneWidget);
    expect(loads, 2);
  });
  testWidgets('360px·2배 글씨에서 검색·확인 창이 잘리지 않는다', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!),
        home: RegionPickerScreen(loadCatalog: () async => catalog)));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('region-search')), '경기 수원 광교1동');
    await tester.pumpAndSettle();
    await tester.tap(find.text('광교1동'));
    await tester.pumpAndSettle();
    expect(find.text('이 지역 사용'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('전국 검색은 보이는 항목만 만든다', (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: RegionPickerScreen(loadCatalog: () async => catalog)));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('region-search')), '동');
    await tester.pumpAndSettle();
    expect(catalog.search('동').length, greaterThan(1000));
    expect(find.byType(ListTile).evaluate().length, lessThan(30));
  });
}
