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
    expect(find.textContaining('Android 11'), findsOneWidget);
    expect(find.textContaining('iOS'), findsOneWidget);
    expect(find.text('백그라운드 제외'), findsOneWidget);
    expect(find.text('동의하고 계속'), findsOneWidget);
    await tester.drag(
        find.byType(SingleChildScrollView), const Offset(0, -650));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
