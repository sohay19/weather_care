import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import 'package:weather_care/firebase_options.dart';

import 'app.dart';
import 'services/analytics_consent.dart';
import 'services/ads_consent.dart';
import 'services/app_open_ad_controller.dart';
import 'services/app_open_ad_unit_config.dart';
import 'services/app_open_launch_store.dart';
import 'services/native_ad_unit_config.dart';
import 'services/foreground_notification_service.dart';
import 'services/notification_navigation_service.dart';
import 'startup.dart';

final _appNavigatorKey = GlobalKey<NavigatorState>();
final _notificationNavigation = NotificationNavigationService(
  _appNavigatorKey,
);
final _foregroundNotifications = ForegroundNotificationService();
final _appOpenAds = AppOpenAdController();

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
    onHomeReady: _appOpenAds.markHomeReady,
  );
}

void _startAdsAfterAppFrame() {
  unawaited(_startAds());
}

Future<void> _startAds() async {
  final nativeAdsEnabled = NativeAdPlacement.values.any(
    (placement) =>
        NativeAdUnitConfig.current.resolve(placement: placement) != null,
  );
  final appOpenAdEnabled = AppOpenAdUnitConfig.current.resolve() != null;
  if (!nativeAdsEnabled && !appOpenAdEnabled) return;

  if (appOpenAdEnabled) {
    try {
      final shouldShow =
          await const AppOpenLaunchStore().recordLaunchAndShouldShow();
      if (shouldShow) {
        await _appOpenAds.start(showOnInitialLoad: true);
      }
    } catch (error) {
      debugPrint('앱 오프닝 광고 실행 횟수를 확인하지 못했어요: $error');
    }
  }
  await AdsConsent.instance.refresh();
}
