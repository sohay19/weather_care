import 'package:flutter/material.dart';
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
    await tester.tap(find.text('확인'));
    await tester.pumpAndSettle();
  }
  await tester.tap(find.byIcon(Icons.keyboard_outlined));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextFormField).first, '$hour');
  await tester.enterText(find.byType(TextFormField).last, '$minute');
  await tester.tap(find.text('확인'));
  await tester.pumpAndSettle();
  if (editStart) {
    await tester.tap(find.text('확인'));
    await tester.pumpAndSettle();
  }
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
  for (final cancelEnd in [false, true]) {
    testWidgets('${cancelEnd ? '종료' : '시작'} 시각 설정 중 취소하면 구간 전체를 적용하지 않는다',
        (tester) async {
      final changed = <AppSettings>[];
      await start(tester, changed: changed.add);
      await _open(tester, true);
      expect(find.byType(NotificationTimePickerDialog), findsOneWidget);
      expect(find.byKey(const ValueKey('commute-range-dialog')), findsNothing);
      if (cancelEnd) {
        await tester.tap(find.byIcon(Icons.keyboard_outlined));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextFormField).first, '9');
        await tester.enterText(find.byType(TextFormField).last, '23');
        await tester.tap(find.text('확인'));
        await tester.pumpAndSettle();
        expect(find.text('출근 종료 시각'), findsOneWidget);
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
    expect(find.text('시작과 종료 시각을 다르게 선택해주세요.'), findsOneWidget);
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
      await tester.tap(find.text('확인'));
      await tester.pumpAndSettle();
      expect(find.text(toWork ? '출근 종료 시각' : '퇴근 종료 시각'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('취소'));
      await tester.pumpAndSettle();
    }
  });
}
