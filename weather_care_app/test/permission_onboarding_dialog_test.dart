import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weather_care/features/home/widgets/permission_onboarding_dialog.dart';

void main() {
  testWidgets('작은 화면과 큰 글씨에서도 백그라운드 안내와 두 선택을 확인한다', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: const TextScaler.linear(1.3)),
        child: child!,
      ),
      home: const Scaffold(body: PermissionOnboardingDialog()),
    ));
    expect(find.text('백그라운드 위치 갱신 · 선택'), findsOneWidget);
    expect(find.textContaining('홈 위젯 날씨'), findsOneWidget);
    if (defaultTargetPlatform == TargetPlatform.android) {
      expect(find.textContaining('Android 11'), findsOneWidget);
      expect(find.textContaining('실행 알림'), findsOneWidget);
      expect(find.textContaining('iOS'), findsNothing);
      expect(find.textContaining('앱을 사용하는 동안 허용'), findsNothing);
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      expect(find.textContaining('iOS'), findsOneWidget);
      expect(find.textContaining('앱을 사용하는 동안 허용'), findsOneWidget);
      expect(find.textContaining('Android'), findsNothing);
      expect(find.textContaining('실행 알림'), findsNothing);
    } else {
      expect(find.textContaining('Android'), findsNothing);
      expect(find.textContaining('iOS'), findsNothing);
      expect(find.textContaining('실행 알림'), findsNothing);
    }
    expect(find.textContaining('GPS 사용으로 배터리'), findsOneWidget);
    expect(find.textContaining('권한을 거부해도'), findsOneWidget);
    expect(find.text('백그라운드 제외'), findsOneWidget);
    expect(find.text('계속'), findsOneWidget);
    expect(find.text('동의하고 계속'), findsNothing);
    await tester.drag(
        find.byType(SingleChildScrollView), const Offset(0, -650));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.mobile());
}
