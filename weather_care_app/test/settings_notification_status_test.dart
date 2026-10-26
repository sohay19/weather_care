import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weather_care/features/settings/settings_screen.dart';
import 'package:weather_care/models/app_settings.dart';
import 'package:weather_care/services/background_location_service.dart';
import 'package:weather_care/services/notification_permission_service.dart';
import 'package:weather_care/services/settings_save_controller.dart';

void main() {
  Future<void> reveal(WidgetTester tester, String key) async {
    if (find.byKey(ValueKey(key)).evaluate().isEmpty) {
      final menu = find.byKey(const ValueKey('notification-status-menu'));
      if (menu.evaluate().isEmpty) {
        await tester.scrollUntilVisible(menu, 200,
            scrollable: find.byType(Scrollable).first);
      }
      if (menu.evaluate().isNotEmpty) {
        await tester.drag(find.byType(ListView).first, const Offset(0, -350));
        await tester.pumpAndSettle();
      }
      await tester.ensureVisible(
          find.byKey(const ValueKey('notification-status-menu')));
      await tester.tap(find.byKey(const ValueKey('notification-status-menu')));
      await tester.pumpAndSettle();
    }
    await tester.ensureVisible(find.byKey(ValueKey(key)));
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
    expect(find.text('데이터 저장·기기 권한 상태'), findsOneWidget);
    expect(find.text('데이터·기기 상태'), findsNothing);
    expect(find.textContaining('알림은 이전 설정으로 발송될 수 있어요'), findsOneWidget);
    await reveal(tester, 'settings-save-retry');
    await tester.tap(find.byKey(const ValueKey('settings-save-retry')));
    await reveal(tester, 'notification-permission-refresh');
    await tester
        .tap(find.byKey(const ValueKey('notification-permission-refresh')));
    await reveal(tester, 'notification-settings');
    await tester.tap(find.byKey(const ValueKey('notification-settings')));
    expect((retries, requests, opens, reads), (1, 1, 1, 0));
  });

  testWidgets('영구 차단의 재확인은 기기 앱 설정으로 안내한다', (tester) async {
    var opens = 0;
    await tester.pumpWidget(MaterialApp(
        home: SettingsScreen(
      notificationPermission: NotificationPermissionState.deniedPermanently,
      onOpenNotificationSettings: () async => opens++,
    )));
    await reveal(tester, 'notification-permission-status');
    expect(find.textContaining('기기 알림이 차단돼 있어요'), findsOneWidget);
    expect(find.byKey(const ValueKey('notification-permission-request')),
        findsNothing);
    expect(find.byKey(const ValueKey('notification-settings')), findsOneWidget);
    await reveal(tester, 'notification-permission-refresh');
    await tester
        .tap(find.byKey(const ValueKey('notification-permission-refresh')));
    expect(opens, 1);
  });

  testWidgets('미요청 알림을 허용하면 열린 상세 화면에서 버튼이 사라진다', (tester) async {
    final permission = ValueNotifier(NotificationPermissionState.notDetermined);
    addTearDown(permission.dispose);
    var requests = 0;
    await tester.pumpWidget(MaterialApp(
      home: ValueListenableBuilder<NotificationPermissionState>(
        valueListenable: permission,
        builder: (_, state, __) => SettingsScreen(
          notificationPermission: state,
          onRequestNotificationPermission: () async {
            requests++;
            permission.value = NotificationPermissionState.authorized;
          },
        ),
      ),
    ));
    await reveal(tester, 'notification-permission-refresh');
    await tester
        .tap(find.byKey(const ValueKey('notification-permission-refresh')));
    await tester.pumpAndSettle();
    expect(requests, 1);
    expect(find.text(NotificationPermissionState.authorized.message),
        findsOneWidget);
    expect(find.byKey(const ValueKey('notification-permission-refresh')),
        findsNothing);
    permission.value = NotificationPermissionState.denied;
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('notification-permission-refresh')),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('위치 갱신을 권한 상태 안에서 변경하고 재진입해도 유지한다', (tester) async {
    final service = BackgroundLocationService();
    service.status = 'permissionRequired';
    addTearDown(service.dispose);
    final changes = <AppSettings>[];
    var locationRequests = 0;
    await tester.pumpWidget(MaterialApp(
      home: SettingsScreen(
        initialSettings: AppSettings.fallback('test'),
        backgroundLocation: service,
        notificationPermission: NotificationPermissionState.authorized,
        onBackgroundLocationPermission: () async => locationRequests++,
        onSettingsChanged: (value) async => changes.add(value),
      ),
    ));
    expect(
        find.byKey(const ValueKey('background-location-switch')), findsNothing);
    await reveal(tester, 'notification-permission-status');
    expect(find.text('기기 권한 상태'), findsOneWidget);
    expect(find.text('기기 권한 상태를 확인해요'), findsOneWidget);
    expect(find.text('앱 알림'), findsOneWidget);
    expect(find.byKey(const ValueKey('notification-permission-refresh')),
        findsNothing);
    await reveal(tester, 'background-location-switch');
    await tester.tap(find.byKey(const ValueKey('background-location-switch')));
    await tester.pumpAndSettle();
    expect(changes, isEmpty);
    expect(locationRequests, 0);
    await tester.tap(find.text('계속'));
    await tester.pumpAndSettle();
    expect(changes.single.backgroundLocationEnabled, isTrue);
    expect(locationRequests, 1);
    expect(
        tester
            .widget<SwitchListTile>(
                find.byKey(const ValueKey('background-location-switch')))
            .value,
        isTrue);
    await reveal(tester, 'background-location-permission-refresh');
    await tester.tap(
        find.byKey(const ValueKey('background-location-permission-refresh')));
    expect(locationRequests, 2);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(
        find.byKey(const ValueKey('background-location-switch')), findsNothing);
    await reveal(tester, 'background-location-switch');
    expect(
        tester
            .widget<SwitchListTile>(
                find.byKey(const ValueKey('background-location-switch')))
            .value,
        isTrue);
    await tester.tap(find.byKey(const ValueKey('background-location-switch')));
    await tester.pumpAndSettle();
    expect(changes.last.backgroundLocationEnabled, isFalse);
    expect(locationRequests, 2);
    expect(tester.takeException(), isNull);
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
    await tester.tap(find.byKey(const ValueKey('weather-alerts-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Switch).first);
    await tester.pump();
    await tester.pageBack();
    await tester.pumpAndSettle();
    await reveal(tester, 'settings-save-status');
    expect(find.text('정상적으로 기기에 설정을 저장하고 서버에 반영했어요.'), findsOneWidget);
    await reveal(tester, 'notification-permission-status');
    expect(find.text('정상적으로 기기에서 앱 알림을 허용했어요.'), findsOneWidget);
    expect(find.byKey(const ValueKey('notification-permission-refresh')),
        findsNothing);
    expect(find.textContaining('날씨 알림이 꺼져 있어요'), findsOneWidget);
    expect(changes.single.notificationEnabled, false);
    expect(changes.single.umbrellaEnabled, false);
  });

  testWidgets('권한 조회 중 재확인 버튼을 숨기고 저장 중 상태를 표시한다', (tester) async {
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
    expect(find.byKey(const ValueKey('notification-permission-refresh')),
        findsNothing);
    expect(find.byKey(const ValueKey('settings-save-retry')), findsNothing);
  });

  testWidgets('360px 2배 글씨에서도 상태와 버튼이 넘치지 않는다', (tester) async {
    final service = BackgroundLocationService();
    addTearDown(service.dispose);
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
        backgroundLocation: service,
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
    expect(find.text('권한 다시 확인'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
