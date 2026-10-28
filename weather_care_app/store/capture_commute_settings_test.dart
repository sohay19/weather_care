// 실제 설정 화면을 창을 띄우지 않고 렌더링해 캡처한다.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weather_care/features/settings/settings_screen.dart';
import 'package:weather_care/models/app_settings.dart';
import 'package:weather_care/theme/weather_theme.dart';

void main() {
  testWidgets('알림·출퇴근 시간 설정과 선택기를 밝은·어두운 화면으로 캡처한다', (tester) async {
    tester.view.physicalSize = const Size(412, 892);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final entry in <String, List<String>>{
      'Ahem': ['SUITE-Regular.ttf'],
      'Roboto': ['SUITE-Regular.ttf'],
      'sans-serif': ['SUITE-Regular.ttf'],
      'SUITE': ['SUITE-Regular.ttf', 'SUITE-Bold.ttf'],
      'NeoHyundai': ['NeoHyundai R.ttf', 'NeoHyundai B.ttf'],
      'ChosunSg': ['ChosunSg.TTF', 'ChosunKg.TTF'],
      'Mona': ['Mona10.ttf', 'Mona10-Bold.ttf'],
    }.entries) {
      final loader = FontLoader(entry.key);
      for (final name in entry.value) {
        loader.addFont(Future.value(ByteData.sublistView(
            File('assets/fonts/$name').readAsBytesSync())));
      }
      await loader.load();
    }
    await (FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
        .load();
    final output = Directory('build/previews')..createSync(recursive: true);
    for (final dark in [false, true]) {
      final boundary = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(
        key: boundary,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: WeatherCareTheme.light(),
          darkTheme: WeatherCareTheme.dark(),
          themeMode: dark ? ThemeMode.dark : ThemeMode.light,
          builder: WeatherCareTheme.textScaleBuilder,
          home:
              SettingsScreen(initialSettings: AppSettings.fallback('capture')),
        ),
      ));
      await tester.pumpAndSettle();
      await tester
          .ensureVisible(find.byKey(const ValueKey('weather-alerts-menu')));
      await tester.tap(find.byKey(const ValueKey('weather-alerts-menu')));
      await tester.pumpAndSettle();
      Future<void> capture(String name) async {
        // 테스트 엔진의 시스템 한글 대체 글꼴만 실제 앱의 SUITE로 보완한다.
        InlineSpan fallback(InlineSpan span) {
          if (span is! TextSpan) return span;
          return TextSpan(
            text: span.text,
            style: (span.style ?? const TextStyle()).copyWith(
              fontFamily: span.style?.fontFamily ?? 'SUITE',
              fontFamilyFallback: ['SUITE'],
            ),
            children: span.children?.map(fallback).toList(),
          );
        }

        for (final element in find.byType(RichText).evaluate()) {
          final paragraph = element.renderObject;
          if (paragraph is RenderParagraph) {
            paragraph.text = fallback(paragraph.text);
          }
        }
        await tester.pump();
        expect(tester.takeException(), isNull);
        await tester.runAsync(() async {
          final bitmap = await (boundary.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary)
              .toImage(pixelRatio: 2);
          final bytes = await bitmap.toByteData(format: ui.ImageByteFormat.png);
          File('${output.path}/$name.png')
              .writeAsBytesSync(bytes!.buffer.asUint8List());
          bitmap.dispose();
        });
      }

      expect(find.textContaining('알림 시간과 받을'), findsNothing);
      expect(find.textContaining('서버 확인 시각'), findsNothing);
      await capture('notification-settings-${dark ? 'dark' : 'light'}');
      await tester.ensureVisible(
          find.byKey(const ValueKey('commute-notification-menu')));
      await tester.tap(find.byKey(const ValueKey('commute-notification-menu')));
      await tester.pumpAndSettle();
      expect(find.text('출퇴근 알림 시간'), findsOneWidget);
      for (final time in ['07:00', '10:00', '17:00', '20:00']) {
        expect(find.text(time), findsOneWidget);
      }
      await capture('commute-settings-${dark ? 'dark' : 'light'}');
      await tester.tap(find.byKey(const ValueKey('commute-to-start')));
      await tester.pumpAndSettle();
      expect(find.byType(TimePickerDialog), findsOneWidget);
      await capture('commute-time-picker-${dark ? 'dark' : 'light'}');
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    }
  });
}
