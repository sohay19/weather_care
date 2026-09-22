import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:weather_care/features/settings/settings_screen.dart';

void main() {
  testWidgets('설정 화면 우측 하단에 앱 버전을 작게 표시한다', (tester) async {
    PackageInfo.setMockInitialValues(
      appName: '날씨챙겨',
      packageName: 'com.codesoha.weathercare',
      version: '1.2.3',
      buildNumber: '4',
      buildSignature: '',
    );

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: SettingsScreen())),
    );
    await tester.pumpAndSettle();

    final label = find.byKey(const ValueKey('settings-app-version'));
    expect(label, findsOneWidget);
    expect(find.text('버전 1.2.3'), findsOneWidget);
    expect(tester.getTopRight(label).dx, greaterThan(340));
  });
}
