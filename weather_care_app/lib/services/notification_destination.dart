enum NotificationTarget {
  main,
  weatherDetails,
  storeUpdate,
}

enum NotificationTopic {
  overview,
  strongWind,
  roadIce,
  pipeFreeze,
  lightning,
  uv,
  precipitation,
  laundry,
  petWalk,
  commute,
  sleep,
  snow,
  airQuality,
  temperature,
  heat,
  weatherWarning,
  unknown,
  appUpdate,
}

class NotificationDestination {
  final NotificationTarget target;
  final NotificationTopic topic;
  final Uri? storeUrl;
  final NotificationRegion? region;

  const NotificationDestination({
    required this.target,
    required this.topic,
    this.storeUrl,
    this.region,
  });

  String get routeName => switch (target) {
        NotificationTarget.main => '/',
        NotificationTarget.weatherDetails => '/weather-details',
        NotificationTarget.storeUpdate => '/store-update',
      };

  static NotificationDestination fromMessageData(
    Map<String, dynamic> data,
  ) {
    final target = _targetFromWireValue(data['notificationTarget']);
    if (target == NotificationTarget.storeUpdate) {
      final url = Uri.tryParse(data['storeUrl']?.toString() ?? '');
      final valid = url != null &&
          url.scheme == 'https' &&
          url.userInfo.isEmpty &&
          (!url.hasPort || url.port == 443) &&
          ((url.host == 'play.google.com' &&
                  url.path == '/store/apps/details' &&
                  url.queryParameters['id'] == 'com.codesoha.weathercare') ||
              (url.host == 'apps.apple.com' &&
                  RegExp(r'/id\d+(?:/|$)').hasMatch(url.path)));
      return NotificationDestination(
        target:
            valid ? NotificationTarget.storeUpdate : NotificationTarget.main,
        topic: valid ? NotificationTopic.appUpdate : NotificationTopic.unknown,
        storeUrl: valid ? url : null,
      );
    }
    if (target != null) {
      return NotificationDestination(
        target: target,
        topic: _topicFromWireValue(data['notificationTopic']),
        region: NotificationRegion.fromMessageData(data),
      );
    }

    final legacy =
        _legacyDestination((data['notificationKey'] ?? '').toString());
    return NotificationDestination(
        target: legacy.target,
        topic: legacy.topic,
        region: NotificationRegion.fromMessageData(data));
  }
}

NotificationTarget? _targetFromWireValue(Object? value) {
  return switch (value?.toString()) {
    'MAIN' => NotificationTarget.main,
    'WEATHER_DETAILS' => NotificationTarget.weatherDetails,
    'STORE_UPDATE' => NotificationTarget.storeUpdate,
    _ => null,
  };
}

NotificationTopic _topicFromWireValue(Object? value) {
  return switch (value?.toString()) {
    'OVERVIEW' => NotificationTopic.overview,
    'APP_UPDATE' => NotificationTopic.appUpdate,
    'STRONG_WIND' => NotificationTopic.strongWind,
    'ROAD_ICE' => NotificationTopic.roadIce,
    'PIPE_FREEZE' => NotificationTopic.pipeFreeze,
    'LIGHTNING' => NotificationTopic.lightning,
    'UV' => NotificationTopic.uv,
    'PRECIPITATION' => NotificationTopic.precipitation,
    'LAUNDRY' => NotificationTopic.laundry,
    'PET_WALK' => NotificationTopic.petWalk,
    'COMMUTE' => NotificationTopic.commute,
    'SLEEP' => NotificationTopic.sleep,
    'SNOW' => NotificationTopic.snow,
    'AIR_QUALITY' => NotificationTopic.airQuality,
    'TEMPERATURE' => NotificationTopic.temperature,
    'HEAT' => NotificationTopic.heat,
    'WEATHER_WARNING' => NotificationTopic.weatherWarning,
    _ => NotificationTopic.unknown,
  };
}

NotificationDestination _legacyDestination(String notificationKey) {
  if (notificationKey.startsWith('LIGHTNING_')) {
    return const NotificationDestination(
      target: NotificationTarget.weatherDetails,
      topic: NotificationTopic.lightning,
    );
  }
  if (notificationKey == 'MORNING_BRIEF') {
    return const NotificationDestination(
      target: NotificationTarget.main,
      topic: NotificationTopic.overview,
    );
  }
  if (notificationKey == 'CURRENT_RAIN' ||
      notificationKey == 'IMPORTANT_UMBRELLA') {
    return const NotificationDestination(
      target: NotificationTarget.weatherDetails,
      topic: NotificationTopic.precipitation,
    );
  }
  if (notificationKey == 'PIPE_FREEZE_CAUTION') {
    return const NotificationDestination(
        target: NotificationTarget.weatherDetails,
        topic: NotificationTopic.pipeFreeze);
  }
  if (notificationKey.startsWith('ROAD_ICE_')) {
    return const NotificationDestination(
      target: NotificationTarget.weatherDetails,
      topic: NotificationTopic.roadIce,
    );
  }
  if (notificationKey.startsWith('ROAD_CONTROL_')) {
    return const NotificationDestination(
      target: NotificationTarget.weatherDetails,
      topic: NotificationTopic.commute,
    );
  }
  if (notificationKey.startsWith('IMPORTANT_HEAVY_SNOW_CAUTION')) {
    return const NotificationDestination(
      target: NotificationTarget.weatherDetails,
      topic: NotificationTopic.snow,
    );
  }
  if (notificationKey == 'IMPORTANT_PARASOL' ||
      notificationKey == 'IMPORTANT_SUNSCREEN') {
    return const NotificationDestination(
      target: NotificationTarget.weatherDetails,
      topic: NotificationTopic.uv,
    );
  }
  if (notificationKey == 'IMPORTANT_MASK') {
    return const NotificationDestination(
      target: NotificationTarget.weatherDetails,
      topic: NotificationTopic.airQuality,
    );
  }
  if (notificationKey == 'IMPORTANT_OUTERWEAR') {
    return const NotificationDestination(
      target: NotificationTarget.weatherDetails,
      topic: NotificationTopic.temperature,
    );
  }
  if (notificationKey == 'IMPORTANT_WATER') {
    return const NotificationDestination(
      target: NotificationTarget.weatherDetails,
      topic: NotificationTopic.heat,
    );
  }

  final warningMatch = RegExp(
    r'^OFFICIAL_WARNING_(?:ACTIVE|CHANGED|RELEASED)_([A-Z])_',
  ).firstMatch(notificationKey);
  if (warningMatch != null) {
    return NotificationDestination(
      target: NotificationTarget.weatherDetails,
      topic: _warningTopic(warningMatch.group(1)!),
    );
  }

  return const NotificationDestination(
    target: NotificationTarget.main,
    topic: NotificationTopic.unknown,
  );
}

NotificationTopic _warningTopic(String typeCode) {
  return switch (typeCode) {
    'W' => NotificationTopic.strongWind,
    'R' => NotificationTopic.precipitation,
    'C' => NotificationTopic.temperature,
    'S' => NotificationTopic.snow,
    'Y' => NotificationTopic.airQuality,
    'H' => NotificationTopic.heat,
    'F' => NotificationTopic.commute,
    'K' => NotificationTopic.sleep,
    _ => NotificationTopic.weatherWarning,
  };
}

/// 알림 발송 당시의 구역. GPS 알림을 열 때는 현재 위치를 다시 확인한다.
class NotificationRegion {
  final String key;
  final int nx;
  final int ny;
  final String? name;
  const NotificationRegion(
      {required this.key, required this.nx, required this.ny, this.name});

  static NotificationRegion? fromMessageData(Map<String, dynamic> data) {
    final key = data['notificationRegionKey'];
    final nx = int.tryParse('${data['notificationRegionNx']}');
    final ny = int.tryParse('${data['notificationRegionNy']}');
    if (key is! String ||
        key.isEmpty ||
        key.length > 200 ||
        nx == null ||
        nx < 1 ||
        nx > 149 ||
        ny == null ||
        ny < 1 ||
        ny > 253) {
      return null;
    }
    final rawName = data['notificationRegionName'];
    final name = rawName is String &&
            rawName.trim().isNotEmpty &&
            rawName.length <= 120 &&
            !RegExp(r'[\x00-\x1F]').hasMatch(rawName)
        ? rawName.trim()
        : null;
    return NotificationRegion(key: key, nx: nx, ny: ny, name: name);
  }
}
