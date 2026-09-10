import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:weather_care/firebase_options.dart';
import 'app.dart';
import 'services/notification_navigation_service.dart';

final _appNavigatorKey = GlobalKey<NavigatorState>();
final _notificationNavigation = NotificationNavigationService(
  _appNavigatorKey,
);

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

  Map<String, dynamic>? initialNotificationData;
  try {
    initialNotificationData =
        (await FirebaseMessaging.instance.getInitialMessage())?.data;
  } catch (error) {
    debugPrint('초기 알림을 확인하지 못했어요: $error');
  }

  _notificationNavigation.start(
    FirebaseMessaging.onMessageOpenedApp.map((message) => message.data),
  );

  await MobileAds.instance.initialize();

  runApp(
    WeatherCareApp(
      navigatorKey: _appNavigatorKey,
      initialNotificationData: initialNotificationData,
    ),
  );
}
