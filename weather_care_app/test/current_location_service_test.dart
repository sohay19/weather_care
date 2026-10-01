import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:weather_care/services/current_location_service.dart';

final _now = DateTime.utc(2026, 9, 10, 7);

Position _position(
        {double latitude = 37.57,
        double longitude = 126.98,
        double accuracy = 20,
        bool hasAccuracy = true,
        DateTime? timestamp}) =>
    Position(
      latitude: latitude,
      longitude: longitude,
      timestamp: timestamp ?? _now,
      accuracy: accuracy,
      hasAccuracy: hasAccuracy,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );

class _Platform extends GeolocatorPlatform {
  bool enabled = true;
  LocationPermission permission = LocationPermission.whileInUse;
  LocationPermission requested = LocationPermission.whileInUse;
  LocationAccuracyStatus accuracy = LocationAccuracyStatus.precise;
  Position position = _position();
  Position? lastKnownPosition;
  Object? failure;
  bool failSettings = false;
  int requests = 0;
  int reads = 0;
  int cachedReads = 0;
  LocationSettings? settings;

  @override
  Future<bool> isLocationServiceEnabled() async => enabled;
  @override
  Future<LocationPermission> checkPermission() async => permission;
  @override
  Future<LocationPermission> requestPermission() async {
    requests++;
    return requested;
  }

  @override
  Future<Position> getCurrentPosition(
      {LocationSettings? locationSettings}) async {
    reads++;
    settings = locationSettings;
    if (failure != null) throw failure!;
    return position;
  }

  @override
  Future<Position?> getLastKnownPosition({
    bool forceLocationManager = false,
  }) async {
    cachedReads++;
    return lastKnownPosition;
  }

  @override
  Future<LocationAccuracyStatus> getLocationAccuracy() async => accuracy;
  @override
  Future<bool> openAppSettings() async {
    if (failSettings) throw StateError('unavailable');
    return true;
  }

  @override
  Future<bool> openLocationSettings() => openAppSettings();
}

void main() {
  late _Platform platform;
  late CurrentLocationService service;
  setUp(() {
    platform = _Platform();
    service = CurrentLocationService(platform: platform, now: () => _now);
  });

  test('자동 확인은 권한을 요청하거나 다른 지역으로 대체하지 않는다', () async {
    platform.permission = LocationPermission.denied;
    final result = await service.locate();
    expect(result.state, LocationState.denied);
    expect(result.coordinates, isNull);
    expect(platform.requests, 0);
    expect(platform.reads, 0);
  });
  test('명시적인 확인에서만 권한을 요청하고 측정 시각을 보존한다', () async {
    platform.permission = LocationPermission.denied;
    final result = await service.locate(requestPermission: true);
    expect(platform.requests, 1);
    expect(result.state, LocationState.ready);
    expect(result.canUseLocalAnalysis, isTrue);
    expect(result.coordinates?.latitude, 37.57);
    expect(result.measuredAt, _now);
    expect(platform.settings?.timeLimit, const Duration(seconds: 8));
  });
  test('2분 이내의 마지막 위치가 있으면 새 GPS 측정을 기다리지 않는다', () async {
    platform.lastKnownPosition = _position(
      latitude: 37.43,
      longitude: 126.80,
      timestamp: _now.subtract(const Duration(seconds: 30)),
    );

    final result = await service.locate();

    expect(result.state, LocationState.ready);
    expect(result.coordinates?.latitude, 37.43);
    expect(platform.cachedReads, 1);
    expect(platform.reads, 0);
  });
  test('위치 다시 확인은 최근 캐시가 있어도 현재 위치를 새로 측정한다', () async {
    platform.lastKnownPosition = _position(
      latitude: 37.43,
      longitude: 126.80,
      timestamp: _now.subtract(const Duration(seconds: 30)),
    );
    platform.position = _position(latitude: 35.18, longitude: 129.07);

    final result = await service.locate(forceRefresh: true);

    expect(result.coordinates?.latitude, 35.18);
    expect(platform.cachedReads, 0);
    expect(platform.reads, 1);
  });
  test('오래된 마지막 위치는 버리고 현재 위치를 측정한다', () async {
    platform.lastKnownPosition = _position(
      timestamp: _now.subtract(const Duration(minutes: 3)),
    );

    final result = await service.locate();

    expect(result.state, LocationState.ready);
    expect(platform.reads, 1);
  });
  test('영구 거부와 기기 위치 기능 꺼짐을 구분한다', () async {
    platform.permission = LocationPermission.deniedForever;
    expect((await service.locate(requestPermission: true)).state,
        LocationState.deniedForever);
    expect(platform.requests, 0);
    platform.enabled = false;
    expect((await service.locate()).state, LocationState.serviceDisabled);
    expect(platform.reads, 0);
  });
  test('권한 요청 후 영구 거부 상태도 보존한다', () async {
    platform.permission = LocationPermission.denied;
    platform.requested = LocationPermission.deniedForever;
    expect((await service.locate(requestPermission: true)).state,
        LocationState.deniedForever);
    expect(platform.reads, 0);
  });
  for (final status in [
    LocationAccuracyStatus.reduced,
    LocationAccuracyStatus.unknown
  ]) {
    test('$status 위치는 지역 예보에만 사용한다', () async {
      platform.accuracy = status;
      final result = await service.locate();
      expect(result.state, LocationState.approximate);
      expect(result.hasLocation, isTrue);
      expect(result.canUseLocalAnalysis, isFalse);
    });
  }
  for (final position in [
    _position(accuracy: 501),
    _position(accuracy: 0),
    _position(accuracy: double.nan),
  ]) {
    test('정확도 값 ${position.accuracy}는 정밀 분석에서 제외한다', () async {
      platform.position = position;
      expect((await service.locate()).canUseLocalAnalysis, isFalse);
    });
  }
  test('Android 변환에서 hasAccuracy가 누락돼도 유효한 정밀도 값은 사용한다', () async {
    platform.position = _position(accuracy: 5, hasAccuracy: false);

    final result = await service.locate();

    expect(result.state, LocationState.ready);
    expect(result.canUseLocalAnalysis, isTrue);
  });
  test('오래되거나 미래인 위치는 현재 위치로 사용하지 않는다', () async {
    for (final timestamp in [
      _now.subtract(const Duration(minutes: 3)),
      _now.add(const Duration(minutes: 2))
    ]) {
      platform.position = _position(timestamp: timestamp);
      expect((await service.locate()).state, LocationState.unavailable);
    }
  });
  test('잘못된 좌표와 서비스 범위 밖 좌표를 구분한다', () async {
    platform.position = _position(latitude: double.nan);
    expect((await service.locate()).state, LocationState.unavailable);
    platform.position = _position(longitude: -122);
    expect((await service.locate()).state, LocationState.outsideServiceArea);
  });
  test('시간 초과·권한 변경·기능 꺼짐·일반 오류를 구분한다', () async {
    for (final entry in <Object, LocationState>{
      TimeoutException('timeout'): LocationState.timedOut,
      const PermissionDeniedException('denied'): LocationState.denied,
      const LocationServiceDisabledException(): LocationState.serviceDisabled,
      StateError('unavailable'): LocationState.unavailable,
    }.entries) {
      platform.failure = entry.key;
      expect((await service.locate()).state, entry.value);
    }
  });
  test('기기 설정 열기 실패는 처리 가능한 false를 반환한다', () async {
    expect(await service.openAppSettings(), isTrue);
    platform.failSettings = true;
    expect(await service.openAppSettings(), isFalse);
    expect(await service.openLocationSettings(), isFalse);
  });
  test('GPS 미사용은 플랫폼 위치를 읽지 않는다', () async {
    expect(await service.currentCoordinates(gpsEnabled: false), isNull);
    expect(platform.reads, 0);
  });
}
