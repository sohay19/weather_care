enum NotificationTarget {
  main,
  weatherDetails,
}

enum NotificationTopic {
  overview,
  strongWind,
  roadIce,
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
}

class NotificationDestination {
  final NotificationTarget target;
  final NotificationTopic topic;

  const NotificationDestination({
    required this.target,
    required this.topic,
  });

  String get routeName => switch (target) {
        NotificationTarget.main => '/',
        NotificationTarget.weatherDetails => '/weather-details',
      };

  static NotificationDestination fromMessageData(
    Map<String, dynamic> data,
  ) {
    final target = _targetFromWireValue(data['notificationTarget']);
    if (target != null) {
      return NotificationDestination(
        target: target,
        topic: _topicFromWireValue(data['notificationTopic']),
      );
    }

    return _legacyDestination((data['notificationKey'] ?? '').toString());
  }
}

NotificationTarget? _targetFromWireValue(Object? value) {
  return switch (value?.toString()) {
    'MAIN' => NotificationTarget.main,
    'WEATHER_DETAILS' => NotificationTarget.weatherDetails,
    _ => null,
  };
}

NotificationTopic _topicFromWireValue(Object? value) {
  return switch (value?.toString()) {
    'OVERVIEW' => NotificationTopic.overview,
    'STRONG_WIND' => NotificationTopic.strongWind,
    'ROAD_ICE' => NotificationTopic.roadIce,
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
