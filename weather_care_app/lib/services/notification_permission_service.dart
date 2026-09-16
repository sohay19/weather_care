import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:geolocator/geolocator.dart';

enum NotificationPermissionState {
  checking,
  authorized,
  provisional,
  notDetermined,
  denied,
  deniedPermanently,
  unavailable,
}

extension NotificationPermissionMessage on NotificationPermissionState {
  String get message => switch (this) {
        NotificationPermissionState.checking => '기기 알림 권한을 확인하고 있어요.',
        NotificationPermissionState.authorized => '정상적으로 기기에서 앱 알림을 허용했어요.',
        NotificationPermissionState.provisional =>
          '기기에서 조용한 알림만 허용했어요.\n소리나 배너가 표시되지 않을 수 있어요.',
        NotificationPermissionState.notDetermined => '기기 알림 권한을 아직 요청하지 않았어요.',
        NotificationPermissionState.denied =>
          '기기 알림이 허용되지 않았어요.\n앱에서 날씨 알림을 켜도 기기에 표시되지 않아요.',
        NotificationPermissionState.deniedPermanently =>
          '기기 알림이 차단돼 있어요.\n기기 앱 설정에서 알림을 허용해주세요.',
        NotificationPermissionState.unavailable => '기기 알림 권한을 확인하지 못했어요.',
      };
}

class NotificationPermissionService {
  final FirebaseMessaging? _messaging;
  final Future<bool> Function() _openSettings;
  NotificationPermissionService({
    FirebaseMessaging? messaging,
    Future<bool> Function()? openSettings,
  })  : _messaging = messaging,
        _openSettings = openSettings ?? Geolocator.openAppSettings;

  Future<NotificationPermissionState> read({bool request = false}) async {
    try {
      final messaging = _messaging ?? FirebaseMessaging.instance;
      final settings = request
          ? await messaging.requestPermission(
              alert: true, badge: true, sound: true)
          : await messaging.getNotificationSettings();
      return switch (settings.authorizationStatus) {
        AuthorizationStatus.authorized =>
          NotificationPermissionState.authorized,
        AuthorizationStatus.provisional =>
          NotificationPermissionState.provisional,
        AuthorizationStatus.denied => NotificationPermissionState.denied,
        AuthorizationStatus.deniedPermanently =>
          NotificationPermissionState.deniedPermanently,
        AuthorizationStatus.notDetermined =>
          NotificationPermissionState.notDetermined,
      };
    } catch (_) {
      return NotificationPermissionState.unavailable;
    }
  }

  Future<bool> openSettings() async {
    try {
      return await _openSettings();
    } catch (_) {
      return false;
    }
  }
}
