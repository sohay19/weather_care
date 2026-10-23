import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:weather_care/services/notification_destination.dart';
import 'package:weather_care/services/notification_navigation_service.dart';
import 'package:weather_care/services/foreground_notification_service.dart';
import 'package:weather_care/features/update/store_update_notification_screen.dart';

const playUrl =
    'https://play.google.com/store/apps/details?id=com.codesoha.weathercare';
const iosUrl = 'https://apps.apple.com/kr/app/id6813007678';
const body = '최신버전 업데이트가 준비됐어요. 새로운 버전을 다운받아보세요.';
Map<String, dynamic> data(String url) => {
      'notificationTarget': 'STORE_UPDATE',
      'notificationTopic': 'APP_UPDATE',
      'storeUrl': url,
    };

void main() {
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  test('스토어 전용 이동 대상을 읽고 허용하지 않은 주소는 메인으로 보낸다', () {
    for (final url in [playUrl, iosUrl]) {
      final destination = NotificationDestination.fromMessageData(data(url));
      expect(destination.target, NotificationTarget.storeUpdate);
      expect(destination.routeName, '/store-update');
      expect(destination.storeUrl.toString(), url);
    }
    for (final url in [
      'https://example.com',
      'http://apps.apple.com/kr/app/id123',
      'https://apps.apple.com.evil.test/id123',
      'https://play.google.com/store/apps/details?id=other',
      'https://apps.apple.com:444/kr/app/id123'
    ]) {
      expect(NotificationDestination.fromMessageData(data(url)).target,
          NotificationTarget.main);
    }
  });

  test('Android 전경 알림에서도 확정 문구와 스토어 주소를 보존한다', () {
    final content = ForegroundNotificationContent.fromRemoteMessage(
        RemoteMessage(
            notification:
                const RemoteNotification(title: '날씨챙겨 새 버전이 나왔어요', body: body),
            data: data(playUrl)));
    expect(content?.body, body);
    expect(decodeForegroundNotificationData(content?.payload)?['storeUrl'],
        playUrl);
  });

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets('${platform.name} 푸시 클릭으로 자신의 스토어를 열고 기존 화면으로 돌아온다',
        (tester) async {
      debugDefaultTargetPlatformOverride = platform;
      final url = platform == TargetPlatform.android ? playUrl : iosUrl;
      final opened = <Uri>[];
      final key = GlobalKey<NavigatorState>();
      final navigation = NotificationNavigationService(key);
      addTearDown(navigation.dispose);
      await tester.pumpWidget(MaterialApp(navigatorKey: key, routes: {
        '/': (_) => const Scaffold(body: Text('기존 화면')),
        '/store-update': (context) {
          final destination = ModalRoute.of(context)!.settings.arguments
              as NotificationDestination;
          return StoreUpdateNotificationScreen(
              storeUrl: destination.storeUrl,
              openStore: (uri) async {
                opened.add(uri);
                return true;
              });
        },
      }));
      navigation.openMessageData(data(url));
      await tester.pumpAndSettle();
      expect(opened.map((uri) => uri.toString()), [url]);
      expect(find.text('기존 화면'), findsOneWidget);
      debugDefaultTargetPlatformOverride = null;
    });
  }

  testWidgets('종료 상태 초기 경로에서도 스토어를 자동으로 열고 홈으로 돌아온다', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final opened = <Uri>[];
    await tester.pumpWidget(MaterialApp(initialRoute: '/store-update', routes: {
      '/': (_) => const Scaffold(body: Text('홈 화면')),
      '/store-update': (_) => StoreUpdateNotificationScreen(
          storeUrl: Uri.parse(playUrl),
          openStore: (uri) async {
            opened.add(uri);
            return true;
          }),
    }));
    await tester.pumpAndSettle();
    expect(opened.single.toString(), playUrl);
    expect(find.text('홈 화면'), findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('스토어 열기 실패는 재시도와 앱 복귀를 제공한다', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    var attempts = 0;
    await tester.pumpWidget(MaterialApp(
        home: StoreUpdateNotificationScreen(
            storeUrl: Uri.parse(playUrl),
            openStore: (_) async {
              attempts++;
              return false;
            })));
    await tester.pumpAndSettle();
    expect(find.text('다시 열기'), findsOneWidget);
    await tester.tap(find.text('다시 열기'));
    await tester.pumpAndSettle();
    expect(attempts, 2);
    expect(find.text('앱으로 돌아가기'), findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('다른 OS 스토어 주소는 열지 않는다', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    var attempts = 0;
    await tester.pumpWidget(MaterialApp(
        home: StoreUpdateNotificationScreen(
            storeUrl: Uri.parse(playUrl),
            openStore: (_) async {
              attempts++;
              return true;
            })));
    await tester.pumpAndSettle();
    expect(attempts, 0);
    expect(find.text('다시 열기'), findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
  });
}
