import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weather_care/features/settings/commute_notification_settings_screen.dart';
import 'package:weather_care/features/settings/notification_time_picker.dart';
import 'package:weather_care/features/settings/settings_screen.dart';
import 'package:weather_care/features/settings/settings_time_control.dart';
import 'package:weather_care/models/app_settings.dart';
import 'package:weather_care/theme/weather_theme.dart';

Future<void> _open(WidgetTester tester, bool toWork) async {
  final row = find
      .byKey(ValueKey(toWork ? 'commute-to-control' : 'commute-from-control'));
  await tester.ensureVisible(row);
  await tester.tap(row);
  await tester.pumpAndSettle();
}

Future<void> _choose(
    WidgetTester tester, String key, int hour, int minute) async {
  await _open(tester, key.startsWith('commute-to-'));
  final editStart = key.endsWith('-start');
  if (!editStart) {
    await tester.tap(find.byKey(const ValueKey('notification-range-end')));
    await tester.pumpAndSettle();
  }
  await tester.tap(find.byIcon(Icons.keyboard_outlined));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextFormField).first, '$hour');
  await tester.enterText(find.byType(TextFormField).last, '$minute');
  await tester.tap(find.text('확인'));
  await tester.pumpAndSettle();
}

void main() {
  Future<void> start(WidgetTester tester,
      {required ValueChanged<AppSettings> changed,
      bool enabled = true,
      double scale = 1}) async {
    await tester.pumpWidget(MaterialApp(
        theme: WeatherCareTheme.light(),
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!),
        home: Scaffold(
            body: SingleChildScrollView(
                padding: const EdgeInsets.all(34),
                child: CommuteNotificationTimeControls(
                    settings: AppSettings.fallback('test'),
                    enabled: enabled,
                    onSettingsChanged: changed)))));
  }

  testWidgets('출근·퇴근을 설정 시각과 같은 UI의 두 행으로 표시한다', (tester) async {
    await start(tester, changed: (_) {});
    final rows = tester
        .widgetList<SettingsTimeControl>(find.byType(SettingsTimeControl))
        .toList();
    expect(rows.map((row) => row.label), ['출근', '퇴근']);
    expect(rows.map((row) => row.value), ['07:00~10:00', '17:00~20:00']);
    expect(
        tester
            .getBottomLeft(find.byKey(const ValueKey('commute-to-control')))
            .dy,
        lessThan(tester
            .getTopLeft(find.byKey(const ValueKey('commute-from-control')))
            .dy));
  });
  for (final entry in {
    'commute-to-start': 'commuteToWorkStart',
    'commute-to-end': 'commuteToWorkEnd',
    'commute-from-start': 'commuteFromWorkStart',
    'commute-from-end': 'commuteFromWorkEnd'
  }.entries) {
    testWidgets('${entry.value}만 변경하고 다른 설정을 보존한다', (tester) async {
      final changed = <AppSettings>[];
      await start(tester, changed: changed.add);
      await _choose(tester, entry.key, 22, 35);
      expect(changed, hasLength(1));
      expect(changed.single.toJson(),
          {...AppSettings.fallback('test').toJson(), entry.value: '22:35'});
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('알림 화면에서 바로 편집하고 다시 열어도 저장한 시간이 유지된다', (tester) async {
    final changed = <AppSettings>[];
    await tester.pumpWidget(MaterialApp(
        home: SettingsScreen(
            initialSettings: AppSettings.fallback('test'),
            onSettingsChanged: (value) async => changed.add(value))));
    await tester
        .ensureVisible(find.byKey(const ValueKey('weather-alerts-menu')));
    await tester.tap(find.byKey(const ValueKey('weather-alerts-menu')));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<SettingsTimeControl>(
                find.byKey(const ValueKey('notification-time-control')))
            .label,
        '알림');
    await _choose(tester, 'commute-to-start', 8, 10);
    expect(find.text('08:10~10:00'), findsOneWidget);
    await _open(tester, true);
    expect(
        tester
            .widget<NotificationTimePickerDialog>(
                find.byType(NotificationTimePickerDialog))
            .initialTime,
        const TimeOfDay(hour: 8, minute: 10));
    await tester.tap(find.descendant(
        of: find.byType(NotificationTimePickerDialog),
        matching: find.text('취소')));
    await tester.pumpAndSettle();
    expect(changed, hasLength(1));
  });

  testWidgets('한 팝업에서 시작·끝을 번갈아 바꾸고 두 값을 한 번에 저장한다', (tester) async {
    final changed = <AppSettings>[];
    await start(tester, changed: changed.add);
    await _open(tester, false);
    expect(find.text('퇴근 알림 시간 범위'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.keyboard_outlined));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, '18');
    await tester.enterText(find.byType(TextFormField).last, '23');
    await tester.pump();
    expect(
        tester
            .widget<Text>(
                find.byKey(const ValueKey('notification-range-start-value')))
            .data,
        '18:23');
    await tester.tap(find.byKey(const ValueKey('notification-range-end')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, '22');
    await tester.enterText(find.byType(TextFormField).last, '41');
    await tester.tap(find.byKey(const ValueKey('notification-range-start')));
    await tester.pumpAndSettle();
    expect(
        tester.widget<TextField>(find.byType(TextField).first).controller!.text,
        '18');
    expect(
        tester.widget<TextField>(find.byType(TextField).last).controller!.text,
        '23');
    expect(
        tester
            .widget<Text>(
                find.byKey(const ValueKey('notification-range-end-value')))
            .data,
        '22:41');
    expect(changed, isEmpty);
    await tester.tap(find.text('확인'));
    await tester.pumpAndSettle();
    expect(changed, hasLength(1));
    expect(changed.single.toJson(), {
      ...AppSettings.fallback('test').toJson(),
      'commuteFromWorkStart': '18:23',
      'commuteFromWorkEnd': '22:41'
    });
  });

  testWidgets('시작 시간이 기본 선택되고 스크롤 변경은 선택한 시간에만 반영된다', (tester) async {
    final changed = <AppSettings>[];
    await start(tester, changed: changed.add);
    await _open(tester, true);
    CupertinoPicker wheel(String part) => tester.widget<CupertinoPicker>(
        find.byKey(ValueKey('notification-$part-wheel')));
    expect(wheel('hour').scrollController!.selectedItem, 7);
    wheel('hour').scrollController!.jumpToItem(8);
    wheel('minute').scrollController!.jumpToItem(5);
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<Text>(
                find.byKey(const ValueKey('notification-range-start-value')))
            .data,
        '08:25');
    expect(
        tester
            .widget<Text>(
                find.byKey(const ValueKey('notification-range-end-value')))
            .data,
        '10:00');
    await tester.tap(find.byKey(const ValueKey('notification-range-end')));
    await tester.pumpAndSettle();
    expect(wheel('hour').scrollController!.selectedItem, 10);
    wheel('hour').scrollController!.jumpToItem(21);
    wheel('minute').scrollController!.jumpToItem(11);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('notification-range-start')));
    await tester.pumpAndSettle();
    expect(wheel('hour').scrollController!.selectedItem, 8);
    expect(wheel('minute').scrollController!.selectedItem, 5);
    await tester.tap(find.text('확인'));
    await tester.pumpAndSettle();
    expect(changed.single.commuteToWorkStart, '08:25');
    expect(changed.single.commuteToWorkEnd, '21:55');
  });
  for (final cancelEnd in [false, true]) {
    testWidgets('${cancelEnd ? '종료' : '시작'} 시각 설정 중 취소하면 구간 전체를 적용하지 않는다',
        (tester) async {
      final changed = <AppSettings>[];
      await start(tester, changed: changed.add);
      await _open(tester, true);
      expect(find.byType(NotificationTimePickerDialog), findsOneWidget);
      expect(find.byKey(const ValueKey('commute-range-dialog')), findsNothing);
      if (cancelEnd) {
        await tester.tap(find.byKey(const ValueKey('notification-range-end')));
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Icons.keyboard_outlined));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextFormField).first, '9');
        await tester.enterText(find.byType(TextFormField).last, '23');
        expect(find.text('출근 알림 시간 범위'), findsOneWidget);
      }
      await tester.tap(find.text('취소'));
      await tester.pumpAndSettle();
      expect(find.text('07:00~10:00'), findsOneWidget);
      expect(changed, isEmpty);
    });
  }
  testWidgets('동일 시작·종료는 거부하고 야간 구간을 보존한다', (tester) async {
    final changed = <AppSettings>[];
    await start(tester, changed: changed.add);
    await _choose(tester, 'commute-to-start', 10, 0);
    expect(changed, isEmpty);
    expect(find.text('시작과 끝 시간을 다르게 선택해주세요.'), findsOneWidget);
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    await _choose(tester, 'commute-to-start', 23, 0);
    expect(changed.single.commuteToWorkStart, '23:00');
    expect(changed.single.commuteToWorkEnd, '10:00');
  });
  testWidgets('전체 알림이 꺼지면 두 행 모두 비활성화한다', (tester) async {
    await start(tester, enabled: false, changed: (_) => fail('비활성 설정 변경'));
    final rows = tester
        .widgetList<SettingsTimeControl>(find.byType(SettingsTimeControl));
    expect(rows, hasLength(2));
    expect(rows.every((row) => row.onTap == null), isTrue);
  });
  testWidgets('320px·글자 2배에서 두 행과 구간 설정이 넘치지 않는다', (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await start(tester, scale: 2, changed: (_) {});
    for (final toWork in [true, false]) {
      await _open(tester, toWork);
      expect(find.byType(NotificationTimePickerDialog), findsOneWidget);
      expect(tester.takeException(), isNull);
      expect(find.text(toWork ? '출근 알림 시간 범위' : '퇴근 알림 시간 범위'), findsOneWidget);
      final startBox = tester
          .getRect(find.byKey(const ValueKey('notification-range-start')));
      final endBox =
          tester.getRect(find.byKey(const ValueKey('notification-range-end')));
      expect(startBox.center.dy, closeTo(endBox.center.dy, 1));
      await tester.tap(find.byKey(const ValueKey('notification-range-end')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('취소'));
      await tester.pumpAndSettle();
    }
  });
}
