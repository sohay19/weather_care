import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weather_care/services/notification_permission_service.dart';

class _Settings implements NotificationSettings {
  @override
  final AuthorizationStatus authorizationStatus;
  _Settings(this.authorizationStatus);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Messaging implements FirebaseMessaging {
  AuthorizationStatus state = AuthorizationStatus.notDetermined;
  bool fails = false;
  int reads = 0;
  int requests = 0;
  @override
  Future<NotificationSettings> getNotificationSettings() async {
    reads++;
    if (fails) throw StateError('platform');
    return _Settings(state);
  }

  @override
  Future<NotificationSettings> requestPermission({
    bool alert = true,
    bool announcement = false,
    bool badge = true,
    bool carPlay = false,
    bool criticalAlert = false,
    bool provisional = false,
    bool sound = true,
    bool providesAppNotificationSettings = false,
  }) async {
    requests++;
    if (fails) throw StateError('platform');
    return _Settings(state);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _Messaging messaging;
  late NotificationPermissionService service;
  setUp(() {
    messaging = _Messaging();
    service = NotificationPermissionService(messaging: messaging);
  });
  for (final entry in {
    AuthorizationStatus.notDetermined:
        NotificationPermissionState.notDetermined,
    AuthorizationStatus.denied: NotificationPermissionState.denied,
    AuthorizationStatus.deniedPermanently:
        NotificationPermissionState.deniedPermanently,
    AuthorizationStatus.authorized: NotificationPermissionState.authorized,
    AuthorizationStatus.provisional: NotificationPermissionState.provisional,
  }.entries) {
    test('${entry.key} 상태를 권한 요청 없이 읽는다', () async {
      messaging.state = entry.key;
      expect(await service.read(), entry.value);
      expect(messaging.reads, 1);
      expect(messaging.requests, 0);
    });
  }
  test('명시적 동작일 때만 요청하고 반환된 결과를 사용한다', () async {
    messaging.state = AuthorizationStatus.authorized;
    expect(await service.read(request: true),
        NotificationPermissionState.authorized);
    expect(messaging.requests, 1);
    expect(messaging.reads, 0);
  });
  test('플랫폼 오류를 거부나 허용으로 표시하지 않는다', () async {
    messaging.fails = true;
    expect(await service.read(), NotificationPermissionState.unavailable);
    expect(await service.read(request: true),
        NotificationPermissionState.unavailable);
  });
  test('앱 설정 열기 성공·거부·예외를 구분한다', () async {
    for (final opened in [true, false]) {
      final service =
          NotificationPermissionService(openSettings: () async => opened);
      expect(await service.openSettings(), opened);
    }
    final service = NotificationPermissionService(
        openSettings: () async => throw StateError('platform'));
    expect(await service.openSettings(), false);
  });
}
