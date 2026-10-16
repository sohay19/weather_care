import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geocoding/geocoding.dart';
import 'package:weather_care/services/address_search_service.dart';

class _Geocoding implements Geocoding {
  final List<String> queries = [];
  final List<Locale?> locales = [];
  final List<(double, double)> reverseQueries = [];
  Future<List<Location>> Function()? forward;
  List<Location> locations = const [
    Location(latitude: 37.57, longitude: 126.98)
  ];
  List<Placemark> placemarks = const [
    Placemark(
      isoCountryCode: 'KR',
      administrativeArea: '서울특별시',
      locality: '종로구',
      thoroughfare: '세종대로',
      subThoroughfare: '175',
    )
  ];

  @override
  Future<List<Location>> locationFromAddress(String address,
      {Locale? locale}) async {
    queries.add(address);
    locales.add(locale);
    return forward == null ? locations : await forward!();
  }

  @override
  Future<List<Placemark>> placemarkFromCoordinates(
      double latitude, double longitude,
      {Locale? locale}) async {
    reverseQueries.add((latitude, longitude));
    locales.add(locale);
    return placemarks;
  }

  @override
  Future<List<Placemark>> placemarkFromAddress(String address,
          {Locale? locale}) =>
      throw UnimplementedError();
  @override
  Future<bool> isPresent() async => true;
  @override
  void setLocaleIdentifier(String localeIdentifier) {}
}

void main() {
  test('한글 주소를 한국어로 조회하고 확인된 좌표를 기존 격자로 변환한다', () async {
    final geocoding = _Geocoding();
    final service =
        PlatformAddressSearchService(createGeocoding: () => geocoding);
    final results = await service.search('  서울 종로구 세종대로 175  ');
    expect(geocoding.queries, ['서울 종로구 세종대로 175']);
    expect(geocoding.locales, everyElement(const Locale('ko', 'KR')));
    expect(results.single.address, '서울특별시 종로구 세종대로 175');
    expect(results.single.grid.nx, 60);
    expect(results.single.grid.ny, 127);
  });

  test('빈 입력·중복·잘못된 좌표를 검색하거나 중복 역변환하지 않는다', () async {
    final geocoding = _Geocoding()
      ..locations = const [
        Location(latitude: 37.57, longitude: 126.98),
        Location(latitude: 37.57, longitude: 126.98),
        Location(latitude: double.nan, longitude: 126.98),
        Location(latitude: 90, longitude: 180),
      ];
    final service =
        PlatformAddressSearchService(createGeocoding: () => geocoding);
    expect(await service.search('   '), isEmpty);
    expect(geocoding.queries, isEmpty);
    expect(await service.search('서울'), hasLength(1));
    expect(geocoding.reverseQueries, hasLength(1));
  });

  test('국내 주소로 확인되지 않은 결과를 국내 격자로 저장하지 않는다', () async {
    final geocoding = _Geocoding()
      ..placemarks = const [
        Placemark(isoCountryCode: 'CN', street: '외국 주소'),
        Placemark(street: '국가 불명 주소'),
      ];
    final service =
        PlatformAddressSearchService(createGeocoding: () => geocoding);
    expect(await service.search('주소'), isEmpty);
    geocoding.placemarks = const [
      Placemark(
        isoCountryCode: 'KR',
        administrativeArea: '서울특별시',
        locality: '종로구',
        street: '서울특별시 종로구 세종대로 175',
      )
    ];
    expect((await service.search('주소')).single.address, '서울특별시 종로구 세종대로 175');
  });

  test('끝나지 않는 주소 검색은 제한 시간 후 실패한다', () async {
    final geocoding = _Geocoding()
      ..forward = () => Completer<List<Location>>().future;
    final service = PlatformAddressSearchService(
      createGeocoding: () => geocoding,
      timeout: const Duration(milliseconds: 10),
    );
    await expectLater(service.search('서울'), throwsA(isA<TimeoutException>()));
  });
}
