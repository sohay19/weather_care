import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weather_care/features/settings/region_picker_screen.dart';
import 'package:weather_care/features/settings/settings_screen.dart';
import 'package:weather_care/models/app_settings.dart';
import 'package:weather_care/services/region_catalog.dart';

void main() {
  final catalog = RegionCatalog.fromJson(
    jsonDecode(File('assets/data/kma_regions.json').readAsStringSync())
        as Map<String, dynamic>,
  );

  RegionMapBuilder mapBuilder({
    String gridId = '100_76',
    int nx = 100,
    int ny = 76,
    String? regionKey,
    bool includeRegionKey = true,
  }) {
    final selectedRegionKey = regionKey ??
        catalog.regions
            .firstWhere((region) => region.nx == nx && region.ny == ny,
                orElse: () => catalog.regions.first)
            .key;
    return (context, onSelectionMessage) => Center(
          child: FilledButton(
            key: const ValueKey('fake-grid-selection'),
            onPressed: () => onSelectionMessage(jsonEncode({
              'type': 'weather-grid-selection',
              'gridId': gridId,
              'nx': nx,
              'ny': ny,
              if (includeRegionKey) 'regionKey': selectedRegionKey,
            })),
            child: const Text('격자 선택 완료'),
          ),
        );
  }

  Future<void> openPicker(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('location-settings-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('지역 직접 선택'));
    await tester.pumpAndSettle();
  }

  testWidgets('지도 선택을 취소하면 GPS 설정과 기존 값이 유지된다', (tester) async {
    final changes = <AppSettings>[];
    await tester.pumpWidget(MaterialApp(
      home: SettingsScreen(
        loadRegionCatalog: () async => catalog,
        regionMapBuilder: mapBuilder(),
        onSettingsChanged: (settings) async => changes.add(settings),
      ),
    ));
    await openPicker(tester);
    expect(find.byType(RegionPickerScreen), findsOneWidget);
    expect(find.text('예보 구역 선택'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(changes, isEmpty);
  });

  testWidgets('지도에서 받은 운영 격자를 검증한 뒤 수동 지역으로 저장한다', (tester) async {
    final changes = <AppSettings>[];
    await tester.pumpWidget(MaterialApp(
      home: SettingsScreen(
        loadRegionCatalog: () async => catalog,
        regionMapBuilder: mapBuilder(),
        onSettingsChanged: (settings) async => changes.add(settings),
      ),
    ));
    await openPicker(tester);
    await tester.tap(find.byKey(const ValueKey('fake-grid-selection')));
    await tester.pumpAndSettle();
    final selected = catalog.regions
        .firstWhere((region) => region.nx == 100 && region.ny == 76);
    expect(changes.single.locationMode, 'MANUAL');
    expect(changes.single.currentRegionId, '100_76');
    expect(changes.single.manualRegionKey, selected.key);
    expect(find.byType(RegionPickerScreen), findsNothing);
    expect(find.text(selected.fullName), findsWidgets);
  });

  testWidgets('제숫자동은 원본 키로 저장하고 화면에는 제를 빼고 표시한다', (tester) async {
    final selected = catalog.search('서울 구로 구로1동').single;
    final changes = <AppSettings>[];
    await tester.pumpWidget(MaterialApp(
      home: SettingsScreen(
        loadRegionCatalog: () async => catalog,
        regionMapBuilder: mapBuilder(
          gridId: selected.gridId,
          nx: selected.nx,
          ny: selected.ny,
          regionKey: selected.key,
        ),
        onSettingsChanged: (settings) async => changes.add(settings),
      ),
    ));
    await openPicker(tester);
    await tester.tap(find.byKey(const ValueKey('fake-grid-selection')));
    await tester.pumpAndSettle();
    expect(changes.single.manualRegionKey, '1153052000|구로제1동|58|125');
    expect(find.text('서울특별시 구로구 구로1동'), findsWidgets);
    expect(find.textContaining('구로제1동'), findsNothing);
  });

  testWidgets('새 격자를 선택하면 표시 지역 키도 함께 교체한다', (tester) async {
    final oldRegion = catalog.search('경기 수원 광교1동').single;
    final changes = <AppSettings>[];
    await tester.pumpWidget(MaterialApp(
      home: SettingsScreen(
        initialSettings: AppSettings.fallback('test').copyWith(
          locationMode: 'MANUAL',
          currentRegionId: oldRegion.gridId,
          manualRegionKey: oldRegion.key,
        ),
        manualRegionName: oldRegion.fullName,
        loadRegionCatalog: () async => catalog,
        regionMapBuilder: mapBuilder(),
        onSettingsChanged: (settings) async => changes.add(settings),
      ),
    ));
    await tester.tap(find.byKey(const ValueKey('location-settings-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('region-change')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('fake-grid-selection')));
    await tester.pumpAndSettle();
    final selected = catalog.regions
        .firstWhere((region) => region.nx == 100 && region.ny == 76);
    expect(changes.single.currentRegionId, '100_76');
    expect(changes.single.manualRegionKey, selected.key);
    expect(find.text(selected.fullName), findsWidgets);
    expect(find.text(oldRegion.fullName), findsNothing);
  });

  testWidgets('표시 지역을 고르지 않거나 다른 격자의 지역을 보내면 저장하지 않는다', (tester) async {
    final otherRegion =
        catalog.regions.firstWhere((region) => region.gridId != '100_76');
    for (final builder in [
      mapBuilder(includeRegionKey: false),
      mapBuilder(regionKey: otherRegion.key),
    ]) {
      await tester.pumpWidget(MaterialApp(
        home: RegionPickerScreen(
          loadCatalog: () async => catalog,
          mapBuilder: builder,
        ),
      ));
      await tester.tap(find.byKey(const ValueKey('fake-grid-selection')));
      await tester.pumpAndSettle();
      expect(find.byType(RegionPickerScreen), findsOneWidget);
      expect(find.textContaining('선택한 예보 구역을 확인하지 못했어요'), findsOneWidget);
    }
  });

  testWidgets('범위를 벗어나거나 로컬 목록에 없는 격자는 저장하지 않는다', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: RegionPickerScreen(
        loadCatalog: () async => catalog,
        mapBuilder: mapBuilder(gridId: '0_999', nx: 0, ny: 999),
      ),
    ));
    await tester.tap(find.byKey(const ValueKey('fake-grid-selection')));
    await tester.pumpAndSettle();
    expect(find.byType(RegionPickerScreen), findsOneWidget);
    expect(find.textContaining('선택한 예보 구역을 확인하지 못했어요'), findsOneWidget);
  });

  testWidgets('위조된 격자 ID는 좌표가 유효해도 거부한다', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: RegionPickerScreen(
        loadCatalog: () async => catalog,
        mapBuilder: mapBuilder(gridId: '60_121'),
      ),
    ));
    await tester.tap(find.byKey(const ValueKey('fake-grid-selection')));
    await tester.pumpAndSettle();
    expect(find.byType(RegionPickerScreen), findsOneWidget);
    expect(find.textContaining('선택한 예보 구역을 확인하지 못했어요'), findsOneWidget);
  });

  testWidgets('360px·2배 글씨에서도 지도 선택 화면을 닫을 수 있다', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: const TextScaler.linear(2),
        ),
        child: child!,
      ),
      home: RegionPickerScreen(
        loadCatalog: () async => catalog,
        mapBuilder: mapBuilder(),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('예보 구역 선택'), findsOneWidget);
    expect(find.byKey(const ValueKey('fake-grid-selection')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
