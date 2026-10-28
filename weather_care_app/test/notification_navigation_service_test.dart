import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weather_care/services/notification_navigation_service.dart';
import 'package:weather_care/services/notification_destination.dart';

void main() {
  for (final beforeMount in [false, true]) {
    testWidgets('지역 알림 클릭 데이터를 ${beforeMount ? '초기 대기' : '실행 중'} 화면으로 전달한다',
        (tester) async {
      final key = GlobalKey<NavigatorState>();
      final service = NotificationNavigationService(key);
      addTearDown(service.dispose);
      final data = <String, dynamic>{
        'notificationKey': 'CURRENT_RAIN',
        'notificationTarget': 'WEATHER_DETAILS',
        'notificationRegionKey': 'GPS',
        'notificationRegionNx': '58',
        'notificationRegionNy': '125',
        'notificationRegionName': '서울 구로구 구로3동'
      };
      if (beforeMount) service.openMessageData(data);
      await tester.pumpWidget(MaterialApp(navigatorKey: key, routes: {
        '/': (_) => const Scaffold(body: Text('시작')),
        '/weather-details': (context) {
          final destination = ModalRoute.of(context)!.settings.arguments
              as NotificationDestination;
          return Scaffold(
              body: Text(
                  '${destination.region!.name} ${destination.region!.nx}/${destination.region!.ny}'));
        },
      }));
      if (!beforeMount) service.openMessageData(data);
      await tester.pumpAndSettle();
      expect(find.text('서울 구로구 구로3동 58/125'), findsOneWidget);
    });
  }

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
          '/weather-details': (context) {
            final destination = ModalRoute.of(context)?.settings.arguments
                as NotificationDestination?;
            return Text('날씨 상세 화면 ${destination?.topic.name}');
          },
        },
      ),
    );

    openedMessages.add({
      'notificationTarget': 'WEATHER_DETAILS',
      'notificationTopic': 'ROAD_ICE',
    });
    await tester.pumpAndSettle();

    expect(find.text('날씨 상세 화면 roadIce'), findsOneWidget);
    expect(find.text('메인 화면'), findsNothing);

    openedMessages.add({
      'notificationTarget': 'MAIN',
      'notificationTopic': 'OVERVIEW',
    });
    await tester.pumpAndSettle();

    expect(find.text('메인 화면'), findsOneWidget);
    expect(find.textContaining('날씨 상세 화면'), findsNothing);
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
