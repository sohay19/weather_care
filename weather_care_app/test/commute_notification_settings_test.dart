import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weather_care/features/settings/commute_notification_settings_screen.dart';
import 'package:weather_care/features/settings/settings_screen.dart';
import 'package:weather_care/models/app_settings.dart';
import 'package:weather_care/theme/weather_theme.dart';

Future<void> _chooseTime(
    WidgetTester tester, String key, int hour, int minute) async {
  final control = find.byKey(ValueKey(key));
  await tester.ensureVisible(control);
  await tester.tap(control);
  await tester.pumpAndSettle();
  await tester.tap(find.byIcon(Icons.keyboard_outlined));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextFormField).first, '$hour');
  await tester.enterText(find.byType(TextFormField).last, '$minute');
  await tester.tap(find.text('확인'));
  await tester.pumpAndSettle();
}

void main() {
  for (final entry in {
    'commute-to-start': 'commuteToWorkStart',
    'commute-to-end': 'commuteToWorkEnd',
    'commute-from-start': 'commuteFromWorkStart',
    'commute-from-end': 'commuteFromWorkEnd',
  }.entries) {
    testWidgets('${entry.value}만 바꾸고 다른 알림 설정을 보존한다', (tester) async {
      final initial = AppSettings.fallback('test');
      final changed = <AppSettings>[];
      await tester.pumpWidget(MaterialApp(
        theme: WeatherCareTheme.light(),
        home: CommuteNotificationSettingsScreen(
            initialSettings: initial,
            enabled: true,
            onSettingsChanged: changed.add),
      ));
      await _chooseTime(tester, entry.key, 22, 35);
      expect(changed, hasLength(1));
      expect(
          changed.single.toJson(), {...initial.toJson(), entry.value: '22:35'});
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('설정 메뉴에서 변경한 시간을 다시 열어도 유지한다', (tester) async {
    final changed = <AppSettings>[];
    await tester.pumpWidget(MaterialApp(
      home: SettingsScreen(
          initialSettings: AppSettings.fallback('test'),
          onSettingsChanged: (settings) async => changed.add(settings)),
    ));
    await tester
        .ensureVisible(find.byKey(const ValueKey('weather-alerts-menu')));
    await tester.tap(find.byKey(const ValueKey('weather-alerts-menu')));
    await tester.pumpAndSettle();
    await tester
        .ensureVisible(find.byKey(const ValueKey('commute-notification-menu')));
    await tester.tap(find.byKey(const ValueKey('commute-notification-menu')));
    await tester.pumpAndSettle();
    await _chooseTime(tester, 'commute-to-start', 8, 10);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.textContaining('출근 08:10~10:00'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('commute-notification-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('commute-to-start')));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<TimePickerDialog>(find.byType(TimePickerDialog))
            .initialTime,
        const TimeOfDay(hour: 8, minute: 10));
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    expect(changed, hasLength(1));
  });

  testWidgets('같은 시작·종료를 거부하고 야간 구간은 다음 날 종료로 표시한다', (tester) async {
    final changed = <AppSettings>[];
    await tester.pumpWidget(MaterialApp(
        home: CommuteNotificationSettingsScreen(
      initialSettings: AppSettings.fallback('test'),
      enabled: true,
      onSettingsChanged: changed.add,
    )));
    await _chooseTime(tester, 'commute-to-start', 10, 0);
    expect(changed, isEmpty);
    expect(find.text('시작과 종료 시각을 다르게 선택해주세요.'), findsOneWidget);
    await _chooseTime(tester, 'commute-to-start', 23, 0);
    expect(changed.single.commuteToWorkStart, '23:00');
    expect(find.text('종료 시각은 다음 날이에요.'), findsOneWidget);
  });

  testWidgets('전체 알림이 꺼져 있으면 출퇴근 시간을 변경하지 못한다', (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: CommuteNotificationSettingsScreen(
      initialSettings: AppSettings.fallback('test'),
      enabled: false,
      onSettingsChanged: (_) => fail('비활성 설정이 변경됨'),
    )));
    for (final button
        in tester.widgetList<OutlinedButton>(find.byType(OutlinedButton))) {
      expect(button.onPressed, isNull);
    }
  });

  testWidgets('320px·글자 2배에서 시간 선택과 안내가 넘치지 않는다', (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(2)),
          child: child!),
      home: CommuteNotificationSettingsScreen(
          initialSettings: AppSettings.fallback('test'),
          enabled: true,
          onSettingsChanged: (_) {}),
    ));
    for (final key in [
      'commute-to-start',
      'commute-to-end',
      'commute-from-start',
      'commute-from-end'
    ]) {
      await tester.ensureVisible(find.byKey(ValueKey(key)));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });
}
