import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:weather_care/services/region_catalog.dart';

void main() {
  final catalog = RegionCatalog.fromJson(
      jsonDecode(File('assets/data/kma_regions.json').readAsStringSync())
          as Map<String, dynamic>);
  test('공식 전국 목록의 모든 행과 시도 계층을 보존한다', () {
    expect(catalog.regions, hasLength(3838));
    expect(catalog.childrenOf(''), hasLength(16));
    expect(catalog.regions.map((r) => r.key).toSet(), hasLength(3838));
    for (final province in catalog.childrenOf('')) {
      expect(catalog.childrenOf(province.code), isNotEmpty,
          reason: province.name);
      for (final city in catalog.childrenOf(province.code)) {
        expect(catalog.childrenOf(city.code), isNotEmpty,
            reason: city.fullName);
      }
    }
  });
  test('부산·수원·우도·독도의 공식 격자를 보존한다', () {
    expect(catalog.search('부산 해운대 좌1동').single.gridId, '100_76');
    expect(catalog.search('경기 수원 광교1동').single.gridId, '61_121');
    expect(catalog.search('제주 우도면').single.gridId, '60_38');
    expect(catalog.search('독도').single.gridId, '144_123');
  });
  test('시군구와 동 이름을 함께 검색하고 흔한 약칭도 찾는다', () {
    expect(catalog.search('  부산시  해운대 좌동 '), hasLength(4));
    expect(catalog.search('경남 창원'), isNotEmpty);
    expect(catalog.search('충북 청주'), isNotEmpty);
    expect(catalog.search('강원도 강릉'), isNotEmpty);
    expect(catalog.search('없는동네987654'), isEmpty);
    expect(catalog.search('   '), hasLength(16));
  });
  test('동명 지역은 상위 지역 전체 이름으로 구분한다', () {
    final gangseo = catalog.regions.where((r) => r.name == '강서구').toList();
    expect(gangseo, hasLength(2));
    expect(gangseo.map((r) => r.fullName).toSet(), {'서울특별시 강서구', '부산광역시 강서구'});
  });
  test('공식 원본에 중복된 코드는 이름·격자로 구분한다', () {
    final duplicated =
        catalog.regions.where((r) => r.code == '2815555000').toList();
    expect(duplicated.map((r) => r.name).toSet(), {'용유동', '운서2동'});
    expect(duplicated.map((r) => r.key).toSet(), hasLength(2));
    for (final region in duplicated) {
      expect(catalog.find(region.key), region);
    }
  });
  test('세종은 반복된 시명을 한번만 표시한다', () {
    expect(catalog.childrenOf('3600000000').single.fullName, '세종특별자치시');
    expect(catalog.search('세종 조치원읍').single.fullName, '세종특별자치시 조치원읍');
  });
  test('잘못된 행과 없는 상위 지역은 정상 목록으로 읽지 않는다', () {
    for (final rows in [
      [],
      [
        ['1100000000', '', '서울', 0, 127]
      ],
      [
        ['1100000000', 'missing', '서울', 60, 127]
      ],
      [
        ['1100000000', '1100000000', '서울', 60, 127]
      ],
      [
        ['1100000000', '', '서울', 60, 127],
        ['1100000000', '', '서울', 60, 127]
      ],
    ]) {
      expect(() => RegionCatalog.fromJson({'regions': rows}),
          throwsFormatException);
    }
  });
}
