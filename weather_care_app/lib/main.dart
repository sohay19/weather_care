import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:weather_care/firebase_options.dart';
import 'app.dart';
import 'services/foreground_notification_service.dart';
import 'services/notification_navigation_service.dart';
import 'services/analytics_consent.dart';
import 'services/ads_consent.dart';

final _appNavigatorKey = GlobalKey<NavigatorState>();
final _notificationNavigation = NotificationNavigationService(
  _appNavigatorKey,
);
final _foregroundNotifications = ForegroundNotificationService();

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  await AnalyticsConsent.instance.initialize();

  Map<String, dynamic>? initialNotificationData;
  try {
    initialNotificationData =
        (await FirebaseMessaging.instance.getInitialMessage())?.data;
  } catch (error) {
    debugPrint('초기 알림을 확인하지 못했어요: $error');
  }

  try {
    final localNotificationData = await _foregroundNotifications.initialize(
      onNotificationSelected: _notificationNavigation.openMessageData,
    );
    initialNotificationData ??= localNotificationData;
  } catch (error) {
    debugPrint('전경 알림 표시를 준비하지 못했어요: $error');
  }

  _notificationNavigation.start(
    FirebaseMessaging.onMessageOpenedApp.map((message) => message.data),
  );

  runApp(
    WeatherCareApp(
      navigatorKey: _appNavigatorKey,
      initialNotificationData: initialNotificationData,
    ),
  );
  // Native consent forms need a visible activity; never delay weather startup.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(AdsConsent.instance.refresh());
  });
}
