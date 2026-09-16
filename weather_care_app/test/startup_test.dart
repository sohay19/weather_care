import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weather_care/features/home/widgets/weather_status_view.dart';
import 'package:weather_care/startup.dart';

void main() {
  testWidgets('첫 실행 로딩 화면에 최대 소요 시간을 안내한다', (tester) async {
    final pending = Completer<Widget>();

    await tester.pumpWidget(
      WeatherCareStartup(initializeApp: () => pending.future),
    );
    await tester.pump();

    expect(find.byType(WeatherStatusView), findsOneWidget);
    expect(find.text('앱을 초기화 하고 있어요'), findsOneWidget);
    expect(find.text('날씨 정보를 확인하고 있어요'), findsNothing);
    expect(find.textContaining('최대 약 2분'), findsOneWidget);

    pending.complete(const MaterialApp(home: Text('온라인 날씨')));
    await tester.pump();
    await tester.pump();
  });

  testWidgets('연령 질문 없이 앱 서비스를 바로 시작한다', (tester) async {
    var serviceStarts = 0;
    var mountedCalls = 0;

    await tester.pumpWidget(
      WeatherCareStartup(
        initializeApp: () async {
          serviceStarts += 1;
          return const MaterialApp(home: Text('온라인 날씨'));
        },
        onAppMounted: () => mountedCalls += 1,
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('온라인 날씨'), findsOneWidget);
    expect(find.textContaining('14세'), findsNothing);
    expect(serviceStarts, 1);
    expect(mountedCalls, 1);
  });

  testWidgets('앱 서비스 초기화 실패 후 다시 시도할 수 있다', (tester) async {
    var serviceStarts = 0;

    await tester.pumpWidget(
      WeatherCareStartup(
        initializeApp: () async {
          serviceStarts += 1;
          if (serviceStarts == 1) throw StateError('offline');
          return const MaterialApp(home: Text('온라인 날씨'));
        },
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(
        find.byKey(const ValueKey('startup-services-retry')), findsOneWidget);
    expect(find.text('온라인 날씨'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('startup-services-retry')));
    await tester.pump();
    await tester.pump();

    expect(serviceStarts, 2);
    expect(find.text('온라인 날씨'), findsOneWidget);
  });
}
