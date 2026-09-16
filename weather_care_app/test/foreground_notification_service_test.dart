import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weather_care/services/foreground_notification_service.dart';

void main() {
  test('FCM 알림을 제목·본문·이동 데이터가 있는 전경 알림으로 변환한다', () {
    const message = RemoteMessage(
      messageId: 'firebase-message-id',
      data: {
        'notificationKey': 'CURRENT_RAIN',
        'notificationTarget': 'WEATHER_DETAILS',
        'notificationTopic': 'PRECIPITATION',
      },
      notification: RemoteNotification(
        title: '현재 강수 안내',
        body: '비가 내리고 있을 수 있어요. 지금 외출한다면 우산을 챙기세요',
      ),
    );

    final content = ForegroundNotificationContent.fromRemoteMessage(message);

    expect(content, isNotNull);
    expect(content?.id, foregroundNotificationId('CURRENT_RAIN'));
    expect(content?.title, '현재 강수 안내');
    expect(content?.body, '비가 내리고 있을 수 있어요.\n지금 외출한다면 우산을 챙기세요');
    expect(
      decodeForegroundNotificationData(content?.payload),
      message.data,
    );
  });

  test('표시할 제목과 본문이 없는 데이터 전용 메시지는 알림을 만들지 않는다', () {
    const message = RemoteMessage(
      messageId: 'data-only',
      data: {'notificationTarget': 'WEATHER_DETAILS'},
    );

    expect(ForegroundNotificationContent.fromRemoteMessage(message), isNull);
  });

  test('손상된 선택 payload는 이동 데이터로 사용하지 않는다', () {
    expect(decodeForegroundNotificationData(null), isNull);
    expect(decodeForegroundNotificationData('not-json'), isNull);
    expect(decodeForegroundNotificationData('["not", "a", "map"]'), isNull);
  });

  test('같은 의미키는 같은 알림 ID를 사용하고 다른 키는 구분한다', () {
    expect(
      foregroundNotificationId('CURRENT_RAIN'),
      foregroundNotificationId('CURRENT_RAIN'),
    );
    expect(
      foregroundNotificationId('CURRENT_RAIN'),
      isNot(foregroundNotificationId('ROAD_ICE_100_2')),
    );
  });
}
