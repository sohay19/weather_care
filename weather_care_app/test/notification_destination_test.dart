import 'package:flutter_test/flutter_test.dart';
import 'package:weather_care/services/notification_destination.dart';

void main() {
  test('서버가 지정한 오전 브리핑은 메인으로 이동한다', () {
    final destination = NotificationDestination.fromMessageData({
      'notificationTarget': 'MAIN',
      'notificationTopic': 'OVERVIEW',
      'notificationKey': 'MORNING_BRIEF',
    });

    expect(destination.routeName, '/');
    expect(destination.topic, NotificationTopic.overview);
  });

  test('서버가 지정한 상황 알림은 실제 날씨 상세로 이동한다', () {
    for (final entry in {
      'PRECIPITATION': NotificationTopic.precipitation,
      'SNOW': NotificationTopic.snow,
      'STRONG_WIND': NotificationTopic.strongWind,
      'ROAD_ICE': NotificationTopic.roadIce,
      'UV': NotificationTopic.uv,
      'LAUNDRY': NotificationTopic.laundry,
      'PET_WALK': NotificationTopic.petWalk,
      'AIR_QUALITY': NotificationTopic.airQuality,
      'TEMPERATURE': NotificationTopic.temperature,
      'HEAT': NotificationTopic.heat,
      'COMMUTE': NotificationTopic.commute,
      'SLEEP': NotificationTopic.sleep,
      'WEATHER_WARNING': NotificationTopic.weatherWarning,
    }.entries) {
      final destination = NotificationDestination.fromMessageData({
        'notificationTarget': 'WEATHER_DETAILS',
        'notificationTopic': entry.key,
      });

      expect(destination.routeName, '/weather-details');
      expect(destination.topic, entry.value);
    }
  });

  test('이전 서버에서 받은 알림 키도 같은 대상으로 이동한다', () {
    final cases = {
      'CURRENT_RAIN': NotificationTopic.precipitation,
      'ROAD_ICE_100_2_202609101200': NotificationTopic.roadIce,
      'ROAD_CONTROL_event_FULL': NotificationTopic.commute,
      'IMPORTANT_HEAVY_SNOW_CAUTION': NotificationTopic.snow,
      'OFFICIAL_WARNING_ACTIVE_W_202609101200': NotificationTopic.strongWind,
      'OFFICIAL_WARNING_CHANGED_H_202609101200': NotificationTopic.heat,
      'OFFICIAL_WARNING_RELEASED_K_202609101200': NotificationTopic.sleep,
    };

    for (final entry in cases.entries) {
      final destination = NotificationDestination.fromMessageData({
        'notificationKey': entry.key,
      });

      expect(destination.routeName, '/weather-details');
      expect(destination.topic, entry.value);
    }
  });

  test('알 수 없는 알림은 안전하게 메인으로 이동한다', () {
    final destination = NotificationDestination.fromMessageData({
      'notificationKey': 'FUTURE_NOTIFICATION',
    });

    expect(destination.routeName, '/');
    expect(destination.topic, NotificationTopic.unknown);
  });
}
