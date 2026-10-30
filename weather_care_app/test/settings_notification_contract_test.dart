import 'package:weather_care/features/settings/notification_time_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weather_care/features/settings/settings_screen.dart';
import 'package:weather_care/features/settings/notification_schedule.dart';
import 'package:weather_care/models/app_settings.dart';

void main() {
  Future<void> reveal(WidgetTester tester, Finder finder) async {
    if (finder.evaluate().isEmpty) {
      await tester.scrollUntilVisible(finder, 250,
          scrollable: find.byType(Scrollable).first, maxScrolls: 60);
    } else {
      await tester.ensureVisible(finder);
    }
    await tester.pumpAndSettle();
  }

  Future<void> openWeatherAlerts(WidgetTester tester) async {
    final menu = find.byKey(const ValueKey('weather-alerts-menu'));
    await reveal(tester, menu);
    await tester.tap(menu);
    await tester.pumpAndSettle();
  }

  const fields = {
    'umbrellaEnabled': '비',
    'snowPreparationEnabled': '눈',
    'outerwearEnabled': '추위',
    'maskEnabled': '대기질',
    'waterEnabled': '더위',
    'uvPreparationEnabled': '자외선',
    'drynessEnabled': '건조도',
    'pollenEnabled': '꽃가루',
    'blackIceEnabled': '블랙아이스 안내',
    'heavyRainEnabled': '호우특보 안내',
    'heavySnowEnabled': '대설·많은 눈 안내',
    'heatwaveEnabled': '폭염특보 안내',
    'coldWaveEnabled': '한파특보 안내',
    'pipeFreezeEnabled': '수도관 동파 대비 안내',
    'showerAndLightRainEnabled': '현재 비 안내',
    'lightningEnabled': '낙뢰 감지 알림',
    'todayVisibilityEnabled': '가시거리',
    'todayOzoneEnabled': '오존',
    'todayWindEnabled': '바람',
    'todayHumidityEnabled': '습도',
    'todayApparentTemperatureEnabled': '체감온도',
    'dailyWeatherEnabled': '챙겨요·Today 알림',
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
      await openWeatherAlerts(tester);
      final toggle = find.byKey(ValueKey('notification-toggle-${entry.key}'));
      await reveal(tester, toggle);
      expect(find.text(entry.value), findsOneWidget);
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(changed, hasLength(1));
      expect(changed.single.toJson(),
          {...initial.toJson(), entry.key: !initial.toJson()[entry.key]});
    });
  }

  testWidgets('날씨 알림 화면에서 시간·챙겨요·기상생활 영역을 함께 제공한다', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));
    await openWeatherAlerts(tester);
    expect(find.textContaining('알림 시간과 받을'), findsNothing);
    expect(find.textContaining('저장에 실패하면'), findsOneWidget);
    expect(
      tester
          .getTopLeft(find.byKey(const ValueKey('notification-save-notice')))
          .dy,
      greaterThan(tester
          .getTopLeft(
              find.byKey(const ValueKey('weather-alerts-master-section')))
          .dy),
    );
    for (final key in [
      'weather-alerts-master-section',
      'notification-time-section',
      'carry-notification-section',
      'today-notification-section',
      'weather-notification-section',
    ]) {
      await reveal(tester, find.byKey(ValueKey(key)));
      expect(find.byKey(ValueKey(key)), findsOneWidget);
    }
    await tester.tap(find.byKey(const ValueKey('settings-detail-back')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('weather-alerts-menu')), findsOneWidget);
  });

  testWidgets('설정 최상위에는 묶인 날씨 알림과 상태 메뉴만 표시한다', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));
    for (final key in [
      'weather-alerts-menu',
      'notification-status-menu',
      'data-permission-menu',
    ]) {
      final menu = find.byKey(ValueKey(key));
      await reveal(tester, menu);
      expect(menu, findsOneWidget);
    }
    expect(find.byKey(const ValueKey('location-settings-menu')), findsNothing);
    expect(find.byKey(const ValueKey('notification-time-menu')), findsNothing);
    expect(find.byKey(const ValueKey('carry-notification-menu')), findsNothing);
    expect(
        find.byKey(const ValueKey('weather-notification-menu')), findsNothing);
  });

  for (final time in [
    const TimeOfDay(hour: 22, minute: 35),
    const TimeOfDay(hour: 0, minute: 0),
  ]) {
    testWidgets('${time.hour}:${time.minute} 선택을 저장하고 다시 열어도 유지한다',
        (tester) async {
      final initial = AppSettings.fallback('test');
      final changed = <AppSettings>[];
      await tester.pumpWidget(MaterialApp(
        home: SettingsScreen(
          initialSettings: initial,
          onSettingsChanged: (settings) async => changed.add(settings),
        ),
      ));
      await openWeatherAlerts(tester);
      final control = find.byKey(const ValueKey('notification-time-control'));
      await reveal(tester, control);
      await tester.tap(control);
      await tester.pumpAndSettle();
      expect(
          tester
              .widget<NotificationTimePickerDialog>(
                  find.byType(NotificationTimePickerDialog))
              .initialTime,
          const TimeOfDay(hour: 7, minute: 0));

      await tester.tap(find.byIcon(Icons.keyboard_outlined));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byType(TextFormField).first, time.hour.toString());
      await tester.enterText(
          find.byType(TextFormField).last, time.minute.toString());
      await tester.tap(find.text('확인'));
      await tester.pumpAndSettle();

      final savedTime =
          '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
      expect(changed, hasLength(1));
      expect(changed.single.toJson(), {
        ...initial.toJson(),
        'notificationTime': savedTime,
      });
      expect(find.text(savedTime), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('settings-detail-back')));
      await tester.pumpAndSettle();
      await openWeatherAlerts(tester);
      await reveal(tester, control);
      await tester.tap(control);
      await tester.pumpAndSettle();
      expect(
          tester
              .widget<NotificationTimePickerDialog>(
                  find.byType(NotificationTimePickerDialog))
              .initialTime,
          time);
      await tester.tap(find.text('취소'));
      await tester.pumpAndSettle();
      expect(changed, hasLength(1));
      expect(find.text(savedTime), findsOneWidget);
    });
  }

  test('알림 시각에 관계없이 확인 주기만 한 줄로 안내한다', () {
    for (final time in [
      '00:00',
      '07:00',
      '07:05',
      '07:35',
      '10:59',
      '23:50',
      '23:55',
      '23:59'
    ]) {
      expect(notificationScheduleDescription(time),
          '10분 단위로 확인하며 실제 도착은 늦어질 수 있어요.');
    }
  });
  test('잘못된 저장 시간을 임의 시각으로 대체하지 않는다', () {
    for (final time in ['24:00', '07:60', '7:00', '', 'unknown']) {
      expect(notificationScheduleDescription(time), '알림 시간을 다시 선택해주세요.');
    }
  });

  testWidgets('요약 끄기와 확인 주기는 안내하되 저장된 시각은 바꾸지 않는다', (tester) async {
    final settings = AppSettings.fallback('test')
        .copyWith(dailyWeatherEnabled: false, notificationTime: '07:35');
    await tester.pumpWidget(
        MaterialApp(home: SettingsScreen(initialSettings: settings)));
    await openWeatherAlerts(tester);
    await reveal(tester,
        find.byKey(const ValueKey('notification-schedule-description')));
    expect(find.text('07:35'), findsOneWidget);
    expect(find.textContaining('서버 확인 시각'), findsNothing);
    expect(find.textContaining('10분 단위로 확인'), findsOneWidget);
    expect(find.text('챙겨요·Today 알림을 켜야 설정한 시간이 적용돼요.'), findsOneWidget);
    expect(settings.notificationTime, '07:35');
  });

  testWidgets('날씨 알림 안에서 전체·시간·챙겨요·기상생활 순서로 표시한다', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));
    await openWeatherAlerts(tester);

    final titles = <Finder>[
      find.byKey(const ValueKey('weather-alerts-master-section')),
      find.byKey(const ValueKey('notification-time-section')),
      find.byKey(const ValueKey('carry-notification-section')),
      find.byKey(const ValueKey('today-notification-section')),
      find.byKey(const ValueKey('weather-notification-section')),
    ];
    final scrollable = find.byType(Scrollable).first;
    var previousOffset = 0.0;
    for (final title in titles) {
      if (title.evaluate().isEmpty) {
        await tester.scrollUntilVisible(
          title,
          250,
          scrollable: scrollable,
          maxScrolls: 60,
        );
      }
      final offset = tester.state<ScrollableState>(scrollable).position.pixels;
      expect(offset, greaterThanOrEqualTo(previousOffset));
      previousOffset = offset;
    }
  });

  testWidgets('현재 비의 자료·우산 조건과 개별 스위치 없는 안내를 명시한다', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));
    await openWeatherAlerts(tester);
    await reveal(
        tester,
        find.byKey(
            const ValueKey('notification-toggle-showerAndLightRainEnabled')));
    expect(find.textContaining('소나기 예보 알림은 아니에요'), findsOneWidget);
    expect(find.textContaining('비 항목도 켜야 하며, 저장 지역은 예보 격자 기준'), findsOneWidget);
    expect(find.textContaining('안내해요.\n비 항목도'), findsOneWidget);
    expect(find.textContaining('가랑비'), findsNothing);
    expect(find.byKey(const ValueKey('commute-notification-contract')),
        findsNothing);
    expect(find.byKey(const ValueKey('additional-notification-contract')),
        findsNothing);
    expect(find.textContaining('해당 자료가 있어야 해요'), findsNothing);
    expect(find.textContaining('도로통제 알림은 설정한 출퇴근 시간'), findsNothing);
  });

  testWidgets('Today 박스는 챙겨요 바로 아래에서 지정한 설명과 다섯 항목을 표시한다', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));
    await openWeatherAlerts(tester);
    final today = find.byKey(const ValueKey('today-notification-section'));
    await reveal(tester, today);
    expect(find.descendant(of: today, matching: find.text('Today 알림')),
        findsOneWidget);
    expect(
        find.descendant(of: today, matching: find.text('챙겨요 알림과 발송되는 시각은 같아요')),
        findsOneWidget);
    final toggles = find.descendant(of: today, matching: find.byType(Switch));
    expect(toggles, findsNWidgets(5));
    expect(tester.widgetList<Switch>(toggles).every((toggle) => toggle.value),
        isTrue);
    final labels = ['가시거리', '오존', '바람', '습도', '체감온도'];
    for (final label in labels) {
      expect(find.descendant(of: today, matching: find.text(label)),
          findsOneWidget);
    }
  });

  testWidgets('최상단 알림 사용여부는 스위치와 한 줄이며 챙겨요는 설명 없는 8항목이다', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));
    await openWeatherAlerts(tester);
    final label = tester.getRect(find.text('알림 사용여부'));
    final toggle = tester.getRect(
        find.byKey(const ValueKey('notification-toggle-notificationEnabled')));
    expect(label.center.dy, closeTo(toggle.center.dy, 1));
    final carry = find.byKey(const ValueKey('carry-notification-section'));
    await reveal(tester, carry);
    final text = tester
        .widgetList<Text>(
            find.descendant(of: carry, matching: find.byType(Text)))
        .map((item) => item.data)
        .toList();
    expect(text, [
      '챙겨요 알림',
      '준비물 요약에 포함할 항목을 선택해요',
      '비',
      '눈',
      '추위',
      '더위',
      '자외선',
      '대기질',
      '꽃가루',
      '건조도'
    ]);
    expect(find.descendant(of: carry, matching: find.byType(Switch)),
        findsNWidgets(8));
  });

  testWidgets('전체 알림 OFF일 때 Today 스위치는 저장값을 유지한 채 비활성화된다', (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: SettingsScreen(
            initialSettings: AppSettings.fallback('test').copyWith(
                notificationEnabled: false, todayWindEnabled: false))));
    await openWeatherAlerts(tester);
    final today = find.byKey(const ValueKey('today-notification-section'));
    await reveal(tester, today);
    final switches = tester
        .widgetList<Switch>(
            find.descendant(of: today, matching: find.byType(Switch)))
        .toList();
    expect(switches, hasLength(5));
    expect(switches.every((toggle) => toggle.onChanged == null), isTrue);
    expect(switches.map((toggle) => toggle.value),
        [true, true, false, true, true]);
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
    await openWeatherAlerts(tester);
    await reveal(tester,
        find.byKey(const ValueKey('notification-schedule-description')));
    expect(find.textContaining('서버 확인 시각'), findsNothing);
    final description =
        find.byKey(const ValueKey('notification-schedule-description'));
    expect(tester.widget<Text>(description).maxLines, 1);
    expect(tester.getRect(description).width, lessThanOrEqualTo(360));
    await reveal(
        tester,
        find.byKey(
            const ValueKey('notification-toggle-showerAndLightRainEnabled')));
    await reveal(
        tester, find.byKey(const ValueKey('today-notification-section')));
    expect(find.text('챙겨요 알림과 발송되는 시각은 같아요'), findsOneWidget);
    await reveal(tester,
        find.byKey(const ValueKey('notification-toggle-blackIceEnabled')));
    expect(tester.takeException(), isNull);
  });
}
