import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:weather_care/firebase_options.dart';

import 'app.dart';
import 'services/analytics_consent.dart';
import 'services/ads_consent.dart';
import 'services/banner_ad_unit_config.dart';
import 'services/foreground_notification_service.dart';
import 'services/notification_navigation_service.dart';
import 'startup.dart';

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

  runApp(
    WeatherCareStartup(
      initializeApp: _initializeApp,
      onAppMounted: _startAdsAfterAppFrame,
    ),
  );
}

Future<Widget> _initializeApp() async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  // Keep the persisted native default off. Notification registration requests
  // a token explicitly after notification permission is granted.
  await FirebaseMessaging.instance.setAutoInitEnabled(false);
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

  return WeatherCareApp(
    navigatorKey: _appNavigatorKey,
    initialNotificationData: initialNotificationData,
  );
}

void _startAdsAfterAppFrame() {
  // Release ads remain off unless the separate build-time kill switch is set.
  if (!kReleaseMode || BannerAdUnitConfig.current.releaseServingEnabled) {
    unawaited(AdsConsent.instance.refresh());
  }
}
