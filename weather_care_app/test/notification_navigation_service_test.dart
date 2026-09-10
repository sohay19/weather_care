import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weather_care/services/notification_navigation_service.dart';

void main() {
  testWidgets('백그라운드에서 선택한 알림은 매핑된 화면을 연다', (tester) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    final openedMessages = StreamController<Map<String, dynamic>>();
    final service = NotificationNavigationService(navigatorKey);
    service.start(openedMessages.stream);
    addTearDown(() async {
      await openedMessages.close();
      await service.dispose();
    });

    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        routes: {
          '/': (_) => const Text('메인 화면'),
          '/weather-details': (_) => const Text('날씨 상세 화면'),
        },
      ),
    );

    openedMessages.add({
      'notificationTarget': 'WEATHER_DETAILS',
      'notificationTopic': 'ROAD_ICE',
    });
    await tester.pumpAndSettle();

    expect(find.text('날씨 상세 화면'), findsOneWidget);
    expect(find.text('메인 화면'), findsNothing);

    openedMessages.add({
      'notificationTarget': 'MAIN',
      'notificationTopic': 'OVERVIEW',
    });
    await tester.pumpAndSettle();

    expect(find.text('메인 화면'), findsOneWidget);
    expect(find.text('날씨 상세 화면'), findsNothing);
  });

  testWidgets('화면 준비 전에 선택한 알림도 첫 프레임 뒤에 연다', (tester) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    final service = NotificationNavigationService(navigatorKey);
    addTearDown(service.dispose);

    service.openMessageData({
      'notificationTarget': 'WEATHER_DETAILS',
      'notificationTopic': 'PRECIPITATION',
    });

    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        routes: {
          '/': (_) => const Text('메인 화면'),
          '/weather-details': (_) => const Text('날씨 상세 화면'),
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('날씨 상세 화면'), findsOneWidget);
  });
}
