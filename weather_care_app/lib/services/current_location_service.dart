import 'dart:async';

import 'package:geolocator/geolocator.dart';

class DeviceCoordinates {
  final double latitude;
  final double longitude;

  const DeviceCoordinates({
    required this.latitude,
    required this.longitude,
  });
}

enum LocationState {
  idle,
  checking,
  ready,
  approximate,
  serviceDisabled,
  denied,
  deniedForever,
  timedOut,
  unavailable,
  outsideServiceArea,
}

class LocationResult {
  final LocationState state;
  final DeviceCoordinates? coordinates;
  final DateTime? measuredAt;

  const LocationResult(this.state, {this.coordinates, this.measuredAt});

  bool get hasLocation =>
      coordinates != null &&
      (state == LocationState.ready || state == LocationState.approximate);
  bool get canUseLocalAnalysis =>
      state == LocationState.ready && coordinates != null;

  String get message => switch (state) {
        LocationState.idle => '현재 위치를 확인하면 해당 지역의 날씨를 안내해요',
        LocationState.checking => '현재 위치를 확인하고 있어요',
        LocationState.ready => '확인한 현재 위치를 기준으로 안내해요',
        LocationState.approximate =>
          '대략적인 위치로 지역 예보를 안내해요.\n세밀한 강수·도로 분석은 사용하지 않아요',
        LocationState.serviceDisabled => '기기의 위치 기능이 꺼져 있어요.\n위치 설정에서 켜주세요',
        LocationState.denied => '위치 권한이 없어 현재 위치를 확인하지 못했어요',
        LocationState.deniedForever => '앱 설정에서 위치 권한을 허용한 뒤 다시 확인해주세요',
        LocationState.timedOut => '시간 안에 위치를 확인하지 못했어요.\n잠시 후 다시 시도해주세요',
        LocationState.unavailable => '현재 위치를 확인하지 못했어요.\n잠시 후 다시 시도해주세요',
        LocationState.outsideServiceArea => '국내 날씨를 제공하는 범위 밖의 위치예요',
      };
}

class CurrentLocationService {
  final GeolocatorPlatform? platform;
  final DateTime Function()? now;

  const CurrentLocationService({this.platform, this.now});

  GeolocatorPlatform get _platform => platform ?? GeolocatorPlatform.instance;

  Future<LocationResult> locate({bool requestPermission = false}) async {
    try {
      if (!await _platform.isLocationServiceEnabled()) {
        return const LocationResult(LocationState.serviceDisabled);
      }
      var permission = await _platform.checkPermission();
      if (permission == LocationPermission.denied && requestPermission) {
        permission = await _platform.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        return const LocationResult(LocationState.deniedForever);
      }
      if (permission != LocationPermission.whileInUse &&
          permission != LocationPermission.always) {
        return const LocationResult(LocationState.denied);
      }
      try {
        final lastKnown = await _platform.getLastKnownPosition();
        if (lastKnown != null) {
          final cachedResult = await _resultFromPosition(lastKnown);
          if (cachedResult.hasLocation) return cachedResult;
        }
      } catch (_) {
        // A missing platform cache must not prevent a fresh location request.
      }
      final position = await _platform.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      );
      return _resultFromPosition(position);
    } on TimeoutException {
      return const LocationResult(LocationState.timedOut);
    } on LocationServiceDisabledException {
      return const LocationResult(LocationState.serviceDisabled);
    } on PermissionDeniedException {
      return const LocationResult(LocationState.denied);
    } catch (_) {
      return const LocationResult(LocationState.unavailable);
    }
  }

  Future<LocationResult> _resultFromPosition(Position position) async {
    if (!position.latitude.isFinite || !position.longitude.isFinite) {
      return const LocationResult(LocationState.unavailable);
    }
    // Match the server's supported coordinate envelope, not a city fallback.
    if (position.latitude < 30 ||
        position.latitude > 44 ||
        position.longitude < 120 ||
        position.longitude > 134) {
      return const LocationResult(LocationState.outsideServiceArea);
    }
    final age = (now?.call() ?? DateTime.now())
        .toUtc()
        .difference(position.timestamp.toUtc());
    if (age > const Duration(minutes: 2) || age < const Duration(minutes: -1)) {
      return const LocationResult(LocationState.unavailable);
    }
    LocationAccuracyStatus accuracy;
    try {
      accuracy = await _platform.getLocationAccuracy();
    } catch (_) {
      accuracy = LocationAccuracyStatus.unknown;
    }
    // Device uncertainty is not 500m-cell forecast accuracy. With coarse or
    // unknown precision, send only the regional grid, never local-analysis coordinates.
    final precise = accuracy == LocationAccuracyStatus.precise &&
        position.accuracy.isFinite &&
        position.accuracy > 0 &&
        position.accuracy <= 500;
    return LocationResult(
      precise ? LocationState.ready : LocationState.approximate,
      coordinates: DeviceCoordinates(
        latitude: position.latitude,
        longitude: position.longitude,
      ),
      measuredAt: position.timestamp.toUtc(),
    );
  }

  Future<bool> openAppSettings() async {
    try {
      return await _platform.openAppSettings();
    } catch (_) {
      return false;
    }
  }

  Future<bool> openLocationSettings() async {
    try {
      return await _platform.openLocationSettings();
    } catch (_) {
      return false;
    }
  }

  Future<DeviceCoordinates?> currentCoordinates({
    required bool gpsEnabled,
  }) async {
    return gpsEnabled ? (await locate()).coordinates : null;
  }
}
