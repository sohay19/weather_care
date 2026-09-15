import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weather_care/features/settings/settings_screen.dart';
import 'package:weather_care/features/settings/notification_schedule.dart';
import 'package:weather_care/models/app_settings.dart';

void main() {
  Future<void> reveal(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(finder, 250,
        scrollable: find.byType(Scrollable).first, maxScrolls: 60);
    await tester.pumpAndSettle();
  }

  const fields = {
    'umbrellaEnabled': '우산',
    'parasolEnabled': '양산',
    'outerwearEnabled': '겉옷',
    'maskEnabled': '마스크',
    'waterEnabled': '물',
    'sunscreenEnabled': '선크림',
    'heavyRainEnabled': '호우특보 안내',
    'heavySnowEnabled': '대설·많은 눈 안내',
    'heatwaveEnabled': '폭염특보 안내',
    'coldWaveEnabled': '한파특보 안내',
    'showerAndLightRainEnabled': '현재 비 안내',
    'dailyWeatherEnabled': '준비물 요약 알림',
  };
  const carryFields = {
    'umbrellaEnabled',
    'parasolEnabled',
    'outerwearEnabled',
    'maskEnabled',
    'waterEnabled',
    'sunscreenEnabled',
  };
  for (final entry in fields.entries) {
    testWidgets('${entry.value} 스위치는 ${entry.key}만 변경한다', (tester) async {
      final initial = AppSettings.fallback('test');
      final changed = <AppSettings>[];
      await tester.pumpWidget(MaterialApp(
          home: SettingsScreen(
        initialSettings: initial,
        onSettingsChanged: (settings) async => changed.add(settings),
      )));
      if (carryFields.contains(entry.key)) {
        final menu = find.byKey(const ValueKey('carry-notification-menu'));
        await reveal(tester, menu);
        await tester.tap(menu);
        await tester.pumpAndSettle();
        expect(
            find.byKey(const ValueKey('carry-settings-back')), findsOneWidget);
      }
      final toggle = find.byKey(ValueKey('notification-toggle-${entry.key}'));
      await reveal(tester, toggle);
      expect(find.text(entry.value), findsOneWidget);
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(changed, hasLength(1));
      expect(changed.single.toJson(), {...initial.toJson(), entry.key: false});
    });
  }

  testWidgets('챙겨요 알림은 별도 화면으로 열리고 뒤로가기로 설정 목록에 복귀한다', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));
    final menu = find.byKey(const ValueKey('carry-notification-menu'));
    await reveal(tester, menu);
    await tester.tap(menu);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('carry-notification-settings')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('carry-settings-back')), findsOneWidget);
    expect(find.text('세부 메뉴'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('carry-settings-back')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('carry-notification-settings')),
        findsNothing);
    expect(menu, findsOneWidget);
  });

  for (final entry in {
    '00:00': '00:00',
    '07:00': '07:00',
    '07:05': '07:10',
    '07:35': '07:40',
    '10:59': '11:00',
    '23:50': '23:50',
    '23:55': '다음 날 00:00',
    '23:59': '다음 날 00:00',
  }.entries) {
    test('${entry.key}의 서버 확인 시각을 ${entry.value}로 표시한다', () {
      expect(notificationScheduleDescription(entry.key),
          startsWith('서버 확인 시각: ${entry.value} (한국시간)'));
      expect(notificationScheduleDescription(entry.key),
          contains('도착은 늦어질 수 있어요'));
    });
  }
  test('잘못된 저장 시간을 임의 시각으로 대체하지 않는다', () {
    for (final time in ['24:00', '07:60', '7:00', '', 'unknown']) {
      expect(notificationScheduleDescription(time), '알림 시간을 다시 선택해주세요.');
    }
  });

  testWidgets('요약 끄기와 확인 시각은 안내하되 저장된 시각은 바꾸지 않는다', (tester) async {
    final settings = AppSettings.fallback('test')
        .copyWith(dailyWeatherEnabled: false, notificationTime: '07:35');
    await tester.pumpWidget(
        MaterialApp(home: SettingsScreen(initialSettings: settings)));
    await reveal(tester,
        find.byKey(const ValueKey('notification-schedule-description')));
    expect(find.text('07:35'), findsOneWidget);
    expect(find.textContaining('서버 확인 시각: 07:40'), findsOneWidget);
    expect(find.text('준비물 요약 알림을 켜야 설정한 시간이 적용돼요.'), findsOneWidget);
    expect(settings.notificationTime, '07:35');
  });

  testWidgets('날씨 알림 뒤에 시간·챙겨요·기상생활·저장 상태 순서로 표시한다', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));

    final titles = [
      '날씨 알림',
      '알림 시간',
      '챙겨요 알림',
      '기상·생활 알림',
      '저장·기기 알림 상태',
    ];
    final scrollable = find.byType(Scrollable).first;
    var previousOffset = 0.0;
    for (final title in titles) {
      await tester.scrollUntilVisible(
        find.text(title),
        250,
        scrollable: scrollable,
        maxScrolls: 60,
      );
      final offset = tester.state<ScrollableState>(scrollable).position.pixels;
      expect(offset, greaterThanOrEqualTo(previousOffset));
      previousOffset = offset;
    }
  });

  testWidgets('현재 비의 자료·우산 조건과 개별 스위치 없는 안내를 명시한다', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));
    await reveal(
        tester,
        find.byKey(
            const ValueKey('notification-toggle-showerAndLightRainEnabled')));
    expect(find.textContaining('소나기 예보 알림은 아니에요'), findsOneWidget);
    expect(find.textContaining('우산도 켜고 GPS 정밀 위치'), findsOneWidget);
    expect(find.textContaining('가랑비'), findsNothing);
    await reveal(
        tester, find.byKey(const ValueKey('additional-notification-contract')));
    expect(find.textContaining('개별 스위치 없이 전체 날씨 알림 설정'), findsOneWidget);
  });

  testWidgets('360px 2배 글씨에서 긴 설명과 스위치가 넘치지 않는다', (tester) async {
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
              AppSettings.fallback('test').copyWith(notificationTime: '23:55')),
    ));
    await reveal(tester,
        find.byKey(const ValueKey('notification-schedule-description')));
    expect(find.textContaining('다음 날 00:00'), findsOneWidget);
    await reveal(
        tester,
        find.byKey(
            const ValueKey('notification-toggle-showerAndLightRainEnabled')));
    await reveal(
        tester, find.byKey(const ValueKey('additional-notification-contract')));
    expect(tester.takeException(), isNull);
  });
}
