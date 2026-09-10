import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weather_care/features/settings/settings_screen.dart';
import 'package:weather_care/models/app_settings.dart';
import 'package:weather_care/services/notification_permission_service.dart';
import 'package:weather_care/services/settings_save_controller.dart';

void main() {
  Future<void> reveal(WidgetTester tester, String key) async {
    await tester.scrollUntilVisible(find.byKey(ValueKey(key)), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
  }

  testWidgets('서버 실패와 기기 차단을 별도로 안내하고 복구 버튼을 제공한다', (tester) async {
    var retries = 0;
    var requests = 0;
    var opens = 0;
    var reads = 0;
    await tester.pumpWidget(MaterialApp(
        home: SettingsScreen(
      saveState: SettingsSaveState.serverFailed,
      notificationPermission: NotificationPermissionState.denied,
      onRetrySave: () async => retries++,
      onRequestNotificationPermission: () async => requests++,
      onOpenNotificationSettings: () async => opens++,
      onRefreshNotificationPermission: () async => reads++,
    )));
    await reveal(tester, 'settings-save-status');
    expect(find.textContaining('알림은 이전 설정으로 발송될 수 있어요'), findsOneWidget);
    await reveal(tester, 'settings-save-retry');
    await tester.tap(find.byKey(const ValueKey('settings-save-retry')));
    await reveal(tester, 'notification-permission-request');
    await tester
        .tap(find.byKey(const ValueKey('notification-permission-request')));
    await reveal(tester, 'notification-permission-refresh');
    await tester
        .tap(find.byKey(const ValueKey('notification-permission-refresh')));
    await reveal(tester, 'notification-settings');
    await tester.tap(find.byKey(const ValueKey('notification-settings')));
    expect((retries, requests, opens, reads), (1, 1, 1, 1));
  });

  testWidgets('영구 차단은 재요청 버튼 없이 기기 앱 설정으로 안내한다', (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: SettingsScreen(
      notificationPermission: NotificationPermissionState.deniedPermanently,
      onOpenNotificationSettings: () async {},
    )));
    await reveal(tester, 'notification-permission-status');
    expect(find.textContaining('기기 알림이 차단돼 있어요'), findsOneWidget);
    expect(find.byKey(const ValueKey('notification-permission-request')),
        findsNothing);
    expect(find.byKey(const ValueKey('notification-settings')), findsOneWidget);
  });

  testWidgets('권한 허용과 앱 알림 끄기를 혼동하지 않고 하위 값을 보존한다', (tester) async {
    final changes = <AppSettings>[];
    await tester.pumpWidget(MaterialApp(
        home: SettingsScreen(
      initialSettings:
          AppSettings.fallback('test').copyWith(umbrellaEnabled: false),
      saveState: SettingsSaveState.saved,
      notificationPermission: NotificationPermissionState.authorized,
      onSettingsChanged: (settings) async => changes.add(settings),
    )));
    await tester.tap(find.byType(Switch).first);
    await tester.pump();
    await reveal(tester, 'notification-permission-status');
    expect(find.text('기기에서 앱 알림을 허용했어요.'), findsOneWidget);
    expect(find.textContaining('앱의 날씨 알림을 껐어요'), findsOneWidget);
    expect(changes.single.notificationEnabled, false);
    expect(changes.single.umbrellaEnabled, false);
  });

  testWidgets('조회 중 버튼 비활성화와 저장 중 상태를 표시한다', (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: SettingsScreen(
      saveState: SettingsSaveState.saving,
      onOpenNotificationSettings: () async {},
      onRefreshNotificationPermission: () async {},
    )));
    await reveal(tester, 'settings-save-status');
    expect(find.text(SettingsSaveState.saving.message), findsOneWidget);
    await reveal(tester, 'notification-settings');
    expect(
        tester
            .widget<TextButton>(
                find.byKey(const ValueKey('notification-settings')))
            .onPressed,
        isNull);
    expect(
        tester
            .widget<TextButton>(
                find.byKey(const ValueKey('notification-permission-refresh')))
            .onPressed,
        isNull);
    expect(find.byKey(const ValueKey('settings-save-retry')), findsNothing);
  });

  testWidgets('360px 2배 글씨에서도 상태와 버튼이 넘치지 않는다', (tester) async {
    tester.view.physicalSize = const Size(360, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(2)),
          child: child!),
      home: SettingsScreen(
        initialSettings:
            AppSettings.fallback('test').copyWith(notificationEnabled: false),
        saveState: SettingsSaveState.localFailed,
        notificationPermission: NotificationPermissionState.provisional,
        onRetrySave: () async {},
        onOpenNotificationSettings: () async {},
      ),
    ));
    await reveal(tester, 'settings-save-status');
    expect(find.textContaining('기기에 설정을 저장하지 못했어요'), findsOneWidget);
    await reveal(tester, 'notification-permission-status');
    expect(find.textContaining('조용한 알림만 허용했어요'), findsOneWidget);
    await reveal(tester, 'notification-settings');
    expect(tester.takeException(), isNull);
  });
}
