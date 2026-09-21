import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weather_care/features/settings/ad_removal_purchase_screen.dart';
import 'package:weather_care/features/settings/settings_screen.dart';
import 'package:weather_care/theme/weather_theme.dart';

Widget _app(Widget home) => MaterialApp(
      theme: WeatherCareTheme.light(),
      home: home,
    );

void main() {
  testWidgets('광고 제거 배너는 지역 선택 위에서 상세 화면을 연다', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_app(const SettingsScreen()));
    final menu = find.byKey(const ValueKey('ad-removal-menu'));
    final location = find.byKey(const ValueKey('location-settings-menu'));
    expect(
        tester.getTopLeft(menu).dy, lessThan(tester.getTopLeft(location).dy));
    await tester.tap(menu);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('ad-removal-purchase-screen')),
        findsOneWidget);
    expect(find.text('날씨만, 더 편안하게'), findsOneWidget);
    expect(find.text('광고 제거 구매하기'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('UI 미리보기에서 구매와 복원은 실제 결제로 이어지지 않는다', (tester) async {
    await tester.pumpWidget(_app(const AdRemovalPurchaseScreen()));

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('ad-removal-purchase')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -120));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('ad-removal-purchase')));
    await tester.pump();
    expect(find.textContaining('UI 미리보기예요'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('ad-removal-restore')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const ValueKey('ad-removal-restore')));
    await tester.pump();
    expect(find.textContaining('구매 내역 복원은 다음 단계'), findsOneWidget);
  });

  testWidgets('구매 박스 도움말에서 복원 조건과 기존 하단 안내를 확인한다', (tester) async {
    await tester.pumpWidget(_app(const AdRemovalPurchaseScreen()));

    final help = find.byKey(const ValueKey('ad-removal-purchase-help'));
    await tester.scrollUntilVisible(
      help,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(help);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('ad-removal-purchase-help-dialog')),
        findsOneWidget);
    expect(find.textContaining('추가 결제 없이 구매 권한을 다시 적용'), findsOneWidget);
    expect(find.textContaining('같은 플랫폼의 같은 스토어 계정'), findsOneWidget);
    expect(find.textContaining('구매와 복원은 현재 기기의 플랫폼 스토어 계정'), findsOneWidget);
    expect(find.textContaining('Android와 iOS의 구매 내역은 서로 복원되지 않아요'),
        findsOneWidget);
    expect(find.textContaining('실제 가격은 결제 연결 후 스토어에서 불러와'), findsOneWidget);

    await tester
        .tap(find.byKey(const ValueKey('ad-removal-purchase-help-close')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('ad-removal-purchase-help-dialog')),
        findsNothing);
  });

  testWidgets('360px 큰 글씨에서도 구매 화면에 overflow가 없다', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(
      theme: WeatherCareTheme.light(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: const TextScaler.linear(2),
        ),
        child: child!,
      ),
      home: const AdRemovalPurchaseScreen(),
    ));

    final scrollable = find.byType(Scrollable).first;
    for (final key in [
      'ad-removal-price',
      'ad-removal-purchase',
      'ad-removal-restore',
    ]) {
      await tester.scrollUntilVisible(
        find.byKey(ValueKey(key)),
        200,
        scrollable: scrollable,
      );
      expect(tester.takeException(), isNull);
    }
  });
}
