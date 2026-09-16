import 'dart:async';
import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

const _androidChannel = AndroidNotificationChannel(
  'weather_care_alerts',
  '날씨·생활 안내',
  description: '현재 날씨와 준비 행동을 안내합니다.',
  importance: Importance.high,
  showBadge: false,
);

class ForegroundNotificationContent {
  final int id;
  final String? title;
  final String? body;
  final String payload;

  const ForegroundNotificationContent({
    required this.id,
    required this.title,
    required this.body,
    required this.payload,
  });

  static ForegroundNotificationContent? fromRemoteMessage(
    RemoteMessage message,
  ) {
    final notification = message.notification;
    if (notification == null ||
        (!_hasText(notification.title) && !_hasText(notification.body))) {
      return null;
    }

    final semanticKey = message.data['notificationKey']?.toString();
    final idSource = _hasText(semanticKey)
        ? semanticKey!
        : message.messageId ?? '${notification.title}|${notification.body}';
    return ForegroundNotificationContent(
      id: foregroundNotificationId(idSource),
      title: notification.title,
      body: notification.body == null
          ? null
          : _sentenceLineBreaks(notification.body!),
      payload: encodeForegroundNotificationData(message.data),
    );
  }
}

class ForegroundNotificationService {
  final FirebaseMessaging messaging;
  final FlutterLocalNotificationsPlugin localNotifications;

  StreamSubscription<RemoteMessage>? _subscription;
  ValueChanged<Map<String, dynamic>>? _onNotificationSelected;

  ForegroundNotificationService({
    FirebaseMessaging? messaging,
    FlutterLocalNotificationsPlugin? localNotifications,
  })  : messaging = messaging ?? FirebaseMessaging.instance,
        localNotifications =
            localNotifications ?? FlutterLocalNotificationsPlugin();

  Future<Map<String, dynamic>?> initialize({
    required ValueChanged<Map<String, dynamic>> onNotificationSelected,
  }) async {
    _onNotificationSelected = onNotificationSelected;

    Map<String, dynamic>? launchData;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      await localNotifications.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('ic_stat_weather_care'),
        ),
        onDidReceiveNotificationResponse: _handleNotificationResponse,
      );
      await localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_androidChannel);
      final launchDetails =
          await localNotifications.getNotificationAppLaunchDetails();
      if (launchDetails?.didNotificationLaunchApp ?? false) {
        launchData = decodeForegroundNotificationData(
          launchDetails?.notificationResponse?.payload,
        );
      }
    } else if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      await messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
    }

    _subscription ??= FirebaseMessaging.onMessage.listen((message) {
      unawaited(_showAndroidNotification(message));
    });
    return launchData;
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
  }

  Future<void> _showAndroidNotification(RemoteMessage message) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    final content = ForegroundNotificationContent.fromRemoteMessage(message);
    if (content == null) return;

    try {
      await localNotifications.show(
        id: content.id,
        title: content.title,
        body: content.body,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            _androidChannel.id,
            _androidChannel.name,
            channelDescription: _androidChannel.description,
            icon: 'ic_stat_weather_care',
            importance: Importance.high,
            priority: Priority.high,
            channelShowBadge: false,
            styleInformation: _hasText(content.body)
                ? BigTextStyleInformation(content.body!)
                : null,
          ),
        ),
        payload: content.payload,
      );
    } catch (error) {
      debugPrint('전경 알림을 표시하지 못했어요: $error');
    }
  }

  void _handleNotificationResponse(NotificationResponse response) {
    final data = decodeForegroundNotificationData(response.payload);
    if (data != null) _onNotificationSelected?.call(data);
  }
}

String encodeForegroundNotificationData(Map<String, dynamic> data) {
  return jsonEncode(
    data.map((key, value) => MapEntry(key, value.toString())),
  );
}

Map<String, dynamic>? decodeForegroundNotificationData(String? payload) {
  if (!_hasText(payload)) return null;
  try {
    final decoded = jsonDecode(payload!);
    if (decoded is! Map) return null;
    return decoded.map(
      (key, value) => MapEntry(key.toString(), value),
    );
  } catch (_) {
    return null;
  }
}

int foregroundNotificationId(String source) {
  var hash = 0x811c9dc5;
  for (final codeUnit in source.codeUnits) {
    hash ^= codeUnit;
    hash = (hash * 0x01000193) & 0xffffffff;
  }
  return hash & 0x7fffffff;
}

bool _hasText(String? value) => value != null && value.trim().isNotEmpty;

String _sentenceLineBreaks(String value) {
  return value.replaceAllMapped(
    RegExp(r'([.!?])[\t ]+(?=\S)'),
    (match) => '${match.group(1)}\n',
  );
}
