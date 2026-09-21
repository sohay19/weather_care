import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:weather_care/firebase_options.dart';

import 'app.dart';
import 'services/analytics_consent.dart';
import 'services/ad_removal_service.dart';
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
  await AdRemovalService.instance.initialize();
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
    adRemoval: AdRemovalService.instance,
  );
}

void _startAdsAfterAppFrame() {
  if (kDebugMode) debugPrint('광고 시작 예약');
  unawaited(_startAds());
}

Future<void> _startAds() async {
  if (AdRemovalService.instance.isOwned) return;
  final nativeAdsEnabled = NativeAdPlacement.values.any(
    (placement) =>
        NativeAdUnitConfig.current.resolve(placement: placement) != null,
  );
  final appOpenAdEnabled = AppOpenAdUnitConfig.current.resolve() != null;
  if (kDebugMode) {
    debugPrint(
      '광고 설정 확인: 네이티브=$nativeAdsEnabled, 오프닝=$appOpenAdEnabled',
    );
  }
  if (!nativeAdsEnabled && !appOpenAdEnabled) return;

  if (kDebugMode) debugPrint('광고 동의 확인 호출');
  await AdsConsent.instance.refresh();

  if (appOpenAdEnabled) {
    try {
      final shouldShow =
          await const AppOpenLaunchStore().recordLaunchAndShouldShow();
      if (kDebugMode) debugPrint('앱 오프닝 광고 대상: $shouldShow');
      if (shouldShow) {
        await _appOpenAds.start(showOnInitialLoad: true);
        if (kDebugMode) debugPrint('앱 오프닝 광고 시작 완료');
      }
    } catch (error) {
      debugPrint('앱 오프닝 광고 실행 횟수를 확인하지 못했어요: $error');
    }
  }
}
