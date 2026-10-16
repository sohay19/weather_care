import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weather_care/features/settings/address_region_picker_screen.dart';
import 'package:weather_care/models/selectable_region.dart';
import 'package:weather_care/models/postal_address.dart';
import 'package:weather_care/services/address_search_service.dart';
import 'package:weather_care/services/region_catalog.dart';

const _address = AddressSearchResult(
    address: '서울특별시 종로구 세종대로 175', latitude: 37.57, longitude: 126.98);

class _Search extends AddressSearchService {
  final Future<List<AddressSearchResult>> Function(String) lookup;
  final queries = <String>[];
  _Search(this.lookup);
  @override
  Future<List<AddressSearchResult>> search(String address) {
    queries.add(address);
    return lookup(address);
  }
}

void main() {
  final catalog = RegionCatalog.fromJson(
      jsonDecode(File('assets/data/kma_regions.json').readAsStringSync())
          as Map<String, dynamic>);
  final region = catalog.regions.firstWhere(
      (r) => r.gridId == '60_127' && catalog.childrenOf(r.code).isEmpty);

  Future<void> open(
    WidgetTester tester,
    AddressSearchService service, {
    ValueChanged<ForecastGridSelection?>? onSelected,
    double textScale = 1,
    Set<String> savedGridIds = const {},
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
                  final result =
                      await Navigator.of(context).push<ForecastGridSelection>(
                    MaterialPageRoute(
                        builder: (_) => AddressRegionPickerScreen(
                              searchService: service,
                              savedGridIds: savedGridIds,
                              loadCatalog: () async => catalog,
                              pickAddress: (_, query) async =>
                                  const PostalAddress(
                                roadAddress: '서울특별시 종로구 세종대로 175',
                                jibunAddress: '서울특별시 종로구 세종로 1-68',
                              ),
                            )),
                  );
                  onSelected?.call(result);
                },
                child: const Text('주소 선택 열기'),
              ))),
    ));
    await tester.tap(find.text('주소 선택 열기'));
    await tester.pumpAndSettle();
  }

  Future<void> search(WidgetTester tester, [String query = '세종대로 175']) async {
    await tester.enterText(find.byType(TextField), query);
    await tester.pump();
    await tester.tap(find.byTooltip('주소 검색'));
    await tester.pumpAndSettle();
  }

  Future<void> reveal(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(finder, 180,
        scrollable: find.descendant(
          of: find.byType(ListView),
          matching: find.byType(Scrollable),
        ));
    await tester.pumpAndSettle();
  }

  testWidgets('주소의 실제 좌표에 해당하는 기존 격자에서 지역명을 선택해 반환한다', (tester) async {
    ForecastGridSelection? result;
    final service = _Search((_) async => [_address]);
    await open(tester, service, onSelected: (value) => result = value);
    expect(service.queries, isEmpty);
    await search(tester);
    expect(service.queries, [_address.address]);
    expect(find.textContaining('검색어는 카카오 주소 검색에'), findsNothing);
    expect(find.text('검색된 주소가 맞는지 확인한 뒤 선택해주세요.'), findsNothing);
    await tester.tap(find.byTooltip('주소 검색 안내'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.textContaining('검색어는 카카오 주소 검색에'), findsOneWidget);
    await tester.tap(find.text('확인'));
    await tester.pumpAndSettle();
    expect(find.text('도로명주소'), findsOneWidget);
    expect(find.text('지번주소'), findsOneWidget);
    for (final title in ['도로명주소', '지번주소']) {
      expect(tester.widget<Text>(find.text(title)).style?.fontWeight,
          FontWeight.bold);
    }
    expect(find.text('서울특별시 종로구 세종로 1-68'), findsOneWidget);
    await tester.tap(find.text(_address.address));
    await tester.pumpAndSettle();
    expect(find.text('도로명주소'), findsNothing);
    expect(find.text('지번주소'), findsNothing);
    expect(find.textContaining('예보 구역은 약 5km × 5km'), findsOneWidget);
    final firstRegion = tester.widget<ListTile>(find.byType(ListTile).first);
    expect((firstRegion.title as Text).data, contains('종로구'));
    await reveal(tester, find.byKey(ValueKey('address-region-${region.key}')));
    await tester.tap(find.byKey(ValueKey('address-region-${region.key}')));
    await tester.pumpAndSettle();
    expect(result?.gridId, '60_127');
    expect(result?.regionKey, region.key);
    expect(result?.regionName, region.fullName);
  });

  testWidgets('중복 구역 안내를 닫아도 주소 선택 화면에서 다시 검색할 수 있다', (tester) async {
    ForecastGridSelection? result;
    final service = _Search((_) async => [_address]);
    await open(tester, service,
        savedGridIds: {region.gridId}, onSelected: (value) => result = value);
    await search(tester);
    await tester.tap(find.text(_address.address));
    await tester.pumpAndSettle();
    await reveal(tester, find.byKey(ValueKey('address-region-${region.key}')));
    await tester.tap(find.byKey(ValueKey('address-region-${region.key}')));
    await tester.pumpAndSettle();
    expect(find.text('이미 추가된 구역입니다'), findsOneWidget);
    expect(result, isNull);
    await tester.tap(find.text('확인'));
    await tester.pumpAndSettle();
    expect(find.byType(AddressRegionPickerScreen), findsOneWidget);
    expect(find.text('저장할 지역명 선택'), findsOneWidget);
    await search(tester, '다른 주소');
    expect(service.queries, hasLength(2));
    expect(find.text('도로명주소'), findsOneWidget);
  });

  testWidgets('다른 격자의 주소를 임의로 가까운 지역에 연결하지 않는다', (tester) async {
    const unsupported = AddressSearchResult(
        address: '격자 밖 주소', latitude: 32.5, longitude: 124.5);
    final service = _Search((_) async => [unsupported]);
    await open(tester, service);
    await search(tester);
    expect(find.textContaining('이 주소에 해당하는 예보 구역이 없어요'), findsOneWidget);
    await tester.tap(find.text(_address.address));
    await tester.pumpAndSettle();
    expect(find.text('저장할 지역명 선택'), findsNothing);
    expect(find.byType(AddressRegionPickerScreen), findsOneWidget);
  });

  testWidgets('지번으로 검색해도 도로명주소와 지번주소를 함께 표시한다', (tester) async {
    final service = _Search((_) async => [_address]);
    await open(tester, service);
    await search(tester, '서울 종로구 세종로 1-68');
    expect(find.text('도로명주소'), findsOneWidget);
    expect(find.text('지번주소'), findsOneWidget);
    expect(find.text('서울특별시 종로구 세종대로 175'), findsOneWidget);
    expect(find.text('서울특별시 종로구 세종로 1-68'), findsOneWidget);
    expect(service.queries, [_address.address]);
  });

  testWidgets('검색 결과 없음·실패 이후 새 주소로 다시 검색할 수 있다', (tester) async {
    var attempts = 0;
    final service = _Search((query) async {
      if (attempts++ == 0) return [];
      if (attempts == 2) throw StateError('네트워크');
      return [_address];
    });
    await open(tester, service);
    await search(tester, '없음');
    expect(find.textContaining('국내 주소를 찾지 못했어요'), findsOneWidget);
    await search(tester, '실패');
    expect(find.textContaining('주소를 검색하지 못했어요'), findsOneWidget);
    await search(tester);
    expect(find.text(_address.address), findsOneWidget);
  });

  testWidgets('이전 검색의 늦은 결과·오류와 검색어 변경은 새 결과를 덮어쓰지 않는다', (tester) async {
    final pending = Completer<List<AddressSearchResult>>();
    var attempts = 0;
    final service = _Search(
        (query) => attempts++ == 0 ? pending.future : Future.value([_address]));
    await open(tester, service);
    await tester.enterText(find.byType(TextField), '이전');
    await tester.tap(find.byTooltip('주소 검색'));
    await tester.pump();
    await search(tester, '새 주소');
    pending.completeError(StateError('이전 검색 실패'));
    await tester.pumpAndSettle();
    expect(find.text(_address.address), findsOneWidget);
    expect(find.textContaining('주소를 검색하지 못했어요'), findsNothing);
    await tester.enterText(find.byType(TextField), '수정한 주소');
    await tester.pumpAndSettle();
    expect(find.text(_address.address), findsNothing);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('주소 선택 열기'), findsOneWidget);
  });

  testWidgets('320px·2배 글씨·키보드에서도 결과를 확인하고 취소할 수 있다', (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    await open(tester, _Search((_) async => [_address]), textScale: 2);
    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    await search(tester);
    await reveal(tester, find.text(_address.address));
    await tester.tap(find.text(_address.address));
    await tester.pumpAndSettle();
    await reveal(tester, find.byKey(ValueKey('address-region-${region.key}')));
    expect(tester.takeException(), isNull);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('주소 선택 열기'), findsOneWidget);
  });
}
