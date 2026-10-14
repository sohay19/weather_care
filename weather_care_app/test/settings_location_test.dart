import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weather_care/features/settings/settings_screen.dart';

void main() {
  testWidgets('설정에서 지역 메뉴를 제거하고 데이터 권한 안내에 위치 설명을 둔다', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));
    expect(find.byKey(const ValueKey('location-settings-menu')), findsNothing);
    final menu = find.byKey(const ValueKey('data-permission-menu'));
    await tester.ensureVisible(menu);
    await tester.tap(menu);
    await tester.pumpAndSettle();
    expect(find.text('데이터 권한 안내'), findsWidgets);
    expect(find.text('위치 권한은 어디에 쓰이나요?'), findsOneWidget);
  });
}
