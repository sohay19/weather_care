import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weather_care/features/settings/background_location_control.dart';
import 'package:weather_care/services/background_location_service.dart';

void main() {
  const channel = MethodChannel(BackgroundLocationService.channelName);
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  testWidgets('Android는 실행 알림 설정만 열고 위치 갱신은 끄지 않는다', (tester) async {
    final service = BackgroundLocationService();
    final calls = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      return true;
    });
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: BackgroundLocationControl(
      service: service,
      enabled: true,
      available: true,
      onChanged: (_) async => fail('알림 표시 설정은 위치 갱신을 끄면 안 된다'),
      onPermission: () async => fail('위치 권한을 변경하면 안 된다'),
    ))));
    expect(find.text('백그라운드 위치 갱신'), findsOneWidget);
    await tester.tap(find
        .byKey(const ValueKey('background-location-notification-settings')));
    await tester.pumpAndSettle();
    expect(calls, ['openNotificationSettings']);
    service.dispose();
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('iOS에는 실행 알림 설정 버튼과 안내가 없다', (tester) async {
    final service = BackgroundLocationService();
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: BackgroundLocationControl(
      service: service,
      enabled: true,
      available: true,
      onChanged: (_) async {},
      onPermission: () async {},
    ))));
    expect(find.byKey(const ValueKey('background-location-switch')),
        findsOneWidget);
    expect(
        find.byKey(const ValueKey('background-location-notification-settings')),
        findsNothing);
    expect(find.text('실행 알림 표시 설정'), findsNothing);
    expect(find.textContaining('시스템 설정에서 이 알림만'), findsNothing);
    expect(await service.openNotificationSettings(), false);
    service.dispose();
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('실행 알림 설정을 열지 못하면 안내한다', (tester) async {
    final service = BackgroundLocationService();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            channel, (_) async => throw PlatformException(code: 'unavailable'));
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: BackgroundLocationControl(
      service: service,
      enabled: false,
      available: false,
      onChanged: (_) async {},
      onPermission: () async {},
    ))));
    await tester.tap(find
        .byKey(const ValueKey('background-location-notification-settings')));
    await tester.pumpAndSettle();
    expect(find.textContaining('실행 알림 설정을 열지 못했어요.'), findsOneWidget);
    service.dispose();
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('320px 큰 글씨에서도 이동 설정과 동의 안내가 넘치지 않는다', (tester) async {
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final service = BackgroundLocationService();
    await tester.pumpWidget(MaterialApp(
      builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(1.3)),
          child: child!),
      home: Scaffold(
          body: SingleChildScrollView(
              child: BackgroundLocationControl(
        service: service,
        enabled: false,
        available: true,
        onChanged: (_) async {},
        onPermission: () async {},
      ))),
    ));
    await tester.tap(find.byKey(const ValueKey('background-location-switch')));
    await tester.pumpAndSettle();
    expect(find.text('백그라운드 위치 사용 안내'), findsOneWidget);
    final dialog = find.byType(AlertDialog);
    final ownPlatform = switch (defaultTargetPlatform) {
      TargetPlatform.android => 'Android',
      TargetPlatform.iOS => 'iOS',
      _ => null,
    };
    for (final platform in ['Android', 'iOS']) {
      expect(
          find.descendant(of: dialog, matching: find.textContaining(platform)),
          platform == ownPlatform ? findsOneWidget : findsNothing);
    }
    expect(find.text('계속'), findsOneWidget);
    expect(find.text('동의하고 설정'), findsNothing);
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      expect(find.textContaining('실행 알림'), findsNothing);
    }
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    service.dispose();
  }, variant: TargetPlatformVariant.mobile());
  testWidgets('사용 안내에 동의한 다음에만 저장하고 권한을 요청한다', (tester) async {
    final service = BackgroundLocationService();
    final events = <String>[];
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: BackgroundLocationControl(
      service: service,
      enabled: false,
      available: true,
      onChanged: (value) async => events.add('save:$value'),
      onPermission: () async => events.add('permission'),
    ))));
    await tester.tap(find.byKey(const ValueKey('background-location-switch')));
    await tester.pumpAndSettle();
    expect(find.text('백그라운드 위치 사용 안내'), findsOneWidget);
    expect(events, isEmpty);
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    expect(events, isEmpty);
    await tester.tap(find.byKey(const ValueKey('background-location-switch')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('계속'));
    await tester.pumpAndSettle();
    expect(events, ['save:true', 'permission']);
    service.dispose();
  });
  testWidgets('사용할 수 없는 상태에서도 켜진 기능은 끌 수 있다', (tester) async {
    final service = BackgroundLocationService();
    final events = <bool>[];
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: BackgroundLocationControl(
      service: service,
      enabled: true,
      available: false,
      onChanged: (value) async => events.add(value),
      onPermission: () async {},
    ))));
    await tester.tap(find.byKey(const ValueKey('background-location-switch')));
    await tester.pumpAndSettle();
    expect(events, [false]);
    expect(find.byType(AlertDialog), findsNothing);
    service.dispose();
  });

  testWidgets('위치 권한이 필요할 때만 재확인하고 허용되면 정상 안내로 바뀐다', (tester) async {
    final service = BackgroundLocationService()..status = 'permissionRequired';
    addTearDown(service.dispose);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => {'status': 'active'});
    var requests = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: BackgroundLocationControl(
          service: service,
          enabled: true,
          available: true,
          onChanged: (_) async {},
          onPermission: () async {
            requests++;
            await service.refreshStatus();
          },
        ),
      ),
    ));
    final button =
        find.byKey(const ValueKey('background-location-permission-refresh'));
    expect(button, findsOneWidget);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(requests, 1);
    expect(button, findsNothing);
    expect(find.textContaining('정상적으로 백그라운드 위치 권한이 허용되어 있어요.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('위치 갱신이 꺼져 있으면 권한 요청 버튼과 허용 안내를 표시하지 않는다', (tester) async {
    final service = BackgroundLocationService()..status = 'permissionRequired';
    addTearDown(service.dispose);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: BackgroundLocationControl(
          service: service,
          enabled: false,
          available: true,
          onChanged: (_) async {},
          onPermission: () async => fail('꺼진 기능에서 권한을 요청하면 안 된다'),
        ),
      ),
    ));
    expect(find.text('현재 꺼져 있어요.'), findsOneWidget);
    expect(find.byKey(const ValueKey('background-location-permission-refresh')),
        findsNothing);
    expect(find.textContaining('정상적으로 백그라운드 위치 권한이 허용되어 있어요.'), findsNothing);
  });
}
