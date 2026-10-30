import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weather_care/features/settings/notification_time_picker.dart';
import 'package:weather_care/theme/weather_theme.dart';

void main() {
  late List<TimeOfDay?> results;

  setUp(() => results = []);

  Future<void> open(WidgetTester tester,
      {TimeOfDay initial = const TimeOfDay(hour: 7, minute: 20),
      double scale = 1,
      bool dark = false}) async {
    await tester.pumpWidget(MaterialApp(
      theme: dark ? WeatherCareTheme.dark() : WeatherCareTheme.light(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: Scaffold(
          body: Builder(
              builder: (context) => TextButton(
                    onPressed: () async => results.add(
                        await showNotificationTimePicker(
                            context: context,
                            initialTime: initial,
                            title: '알림 시간 선택')),
                    child: const Text('열기'),
                  ))),
    ));
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
  }

  Future<void> type(WidgetTester tester, String hour, String minute) async {
    await tester.tap(find.text('숫자로 입력'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('notification-hour-input')), hour);
    await tester.enterText(
        find.byKey(const ValueKey('notification-minute-input')), minute);
  }

  CupertinoPicker wheel(WidgetTester tester, String part) =>
      tester.widget<CupertinoPicker>(
          find.byKey(ValueKey('notification-$part-wheel')));

  testWidgets('시계판 없이 시는 1시간·분은 5분 간격으로 스크롤해 저장한다', (tester) async {
    await open(tester);
    expect(find.byType(TimePickerDialog), findsNothing);
    expect(find.byType(CupertinoPicker), findsNWidgets(2));
    wheel(tester, 'hour').scrollController!.jumpToItem(8);
    wheel(tester, 'minute').scrollController!.jumpToItem(5);
    await tester.pumpAndSettle();
    await tester.tap(find.text('확인'));
    await tester.pumpAndSettle();
    expect(results, [const TimeOfDay(hour: 8, minute: 25)]);
  });

  for (final time in [
    const TimeOfDay(hour: 0, minute: 0),
    const TimeOfDay(hour: 7, minute: 23),
    const TimeOfDay(hour: 23, minute: 59),
  ]) {
    testWidgets('${time.hour}:${time.minute}를 숫자키보드로 입력하고 스크롤 전환 후에도 유지한다',
        (tester) async {
      await open(tester);
      await type(tester, '${time.hour}', '${time.minute}');
      expect(
          tester
              .widget<TextField>(find.byType(TextField).first)
              .keyboardType,
          TextInputType.number);
      await tester.tap(find.text('스크롤로 선택'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('확인'));
      await tester.pumpAndSettle();
      expect(results, [time]);
    });
  }

  testWidgets('5분 배수가 아닌 저장 시각을 다시 열어도 반올림하지 않는다', (tester) async {
    const initial = TimeOfDay(hour: 6, minute: 17);
    await open(tester, initial: initial);
    await tester.tap(find.text('확인'));
    await tester.pumpAndSettle();
    expect(results, [initial]);
  });

  testWidgets('빈 값·24시·60분은 저장하지 않고 수정할 수 있다', (tester) async {
    await open(tester);
    await type(tester, '', '60');
    await tester.tap(find.text('확인'));
    await tester.pumpAndSettle();
    expect(find.text('0~23 입력'), findsOneWidget);
    expect(find.text('0~59 입력'), findsOneWidget);
    expect(results, isEmpty);
    await tester.enterText(find.byType(TextFormField).first, '24');
    await tester.tap(find.text('스크롤로 선택'));
    await tester.pumpAndSettle();
    expect(find.byType(TextFormField), findsNWidgets(2));
    expect(results, isEmpty);
    await tester.enterText(find.byType(TextFormField).first, '9');
    await tester.enterText(find.byType(TextFormField).last, '3');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(results, [const TimeOfDay(hour: 9, minute: 3)]);
  });

  for (final typing in [false, true]) {
    testWidgets('${typing ? '입력' : '스크롤'} 중 취소하면 변경을 적용하지 않는다', (tester) async {
      await open(tester);
      if (typing) {
        await type(tester, '22', '41');
      } else {
        wheel(tester, 'hour').scrollController!.jumpToItem(23);
        await tester.pumpAndSettle();
      }
      await tester.tap(find.text('취소'));
      await tester.pumpAndSettle();
      expect(results, [null]);
    });
  }

  testWidgets('320px·큰 글자·어두운 테마에서 두 입력 방식을 사용할 수 있다', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await open(tester, scale: 2, dark: true);
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('숫자로 입력'));
    await type(tester, '23', '57');
    await tester.ensureVisible(find.text('확인'));
    await tester.tap(find.text('확인'));
    await tester.pumpAndSettle();
    expect(results, [const TimeOfDay(hour: 23, minute: 57)]);
    expect(tester.takeException(), isNull);
  });
}
