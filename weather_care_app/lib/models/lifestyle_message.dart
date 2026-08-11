enum LifestyleMessageType {
  veryHotAndHumid,
  laundryGood,
  coolerThanTemperature,
  outerwearUseful,
  outdoorCaution,
}

extension LifestyleMessageTypeLabel on LifestyleMessageType {
  String get title {
    return switch (this) {
      LifestyleMessageType.veryHotAndHumid => '땀이 비 오듯 나는 날',
      LifestyleMessageType.laundryGood => '빨래가 잘 마르는 날',
      LifestyleMessageType.coolerThanTemperature => '아침저녁이 쌀쌀해요',
      LifestyleMessageType.outerwearUseful => '겉옷이 유용할 가능성이 높아요',
      LifestyleMessageType.outdoorCaution => '야외활동 시 주의가 필요해요',
    };
  }

  String get apiName {
    return switch (this) {
      LifestyleMessageType.veryHotAndHumid => 'VERY_HOT_AND_HUMID',
      LifestyleMessageType.laundryGood => 'LAUNDRY_GOOD',
      LifestyleMessageType.coolerThanTemperature => 'COOLER_THAN_TEMPERATURE',
      LifestyleMessageType.outerwearUseful => 'OUTERWEAR_USEFUL',
      LifestyleMessageType.outdoorCaution => 'OUTDOOR_ACTIVITY_CAUTION',
    };
  }
}

class LifestyleMessage {
  final LifestyleMessageType type;
  final String title;
  final String? description;

  LifestyleMessage({
    required this.type,
    required this.title,
    this.description,
  });

  factory LifestyleMessage.fromJson(Map<String, dynamic> json) {
    final type = (json['type'] ?? '').toString();
    final parsed = switch (type) {
      'VERY_HOT_AND_HUMID' => LifestyleMessageType.veryHotAndHumid,
      'LAUNDRY_GOOD' => LifestyleMessageType.laundryGood,
      'COOLER_THAN_TEMPERATURE' => LifestyleMessageType.coolerThanTemperature,
      'OUTERWEAR_USEFUL' => LifestyleMessageType.outerwearUseful,
      'OUTDOOR_ACTIVITY_CAUTION' => LifestyleMessageType.outdoorCaution,
      _ => LifestyleMessageType.veryHotAndHumid,
    };
    return LifestyleMessage(
      type: parsed,
      title: json['title']?.toString() ?? parsed.title,
      description: json['description']?.toString(),
    );
  }
}

