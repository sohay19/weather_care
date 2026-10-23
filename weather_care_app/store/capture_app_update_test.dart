// 창을 띄우지 않고 실제 업데이트 팝업을 예시 응답으로 렌더링한다.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weather_care/features/update/app_update_gate.dart';
import 'package:weather_care/services/store_update_service.dart';
import 'package:weather_care/services/theme_mode_settings.dart';

class _PreviewUpdates extends StoreUpdateService {
  const _PreviewUpdates();

  @override
  Future<StoreUpdate?> checkForUpdate() async => StoreUpdate(
        currentVersion: '1.0.0',
        storeName: 'Google Play',
        storeUrl: Uri.https('play.google.com', '/store/apps/details',
            {'id': 'com.codesoha.weathercare'}),
      );
}

void main() {
  testWidgets('업데이트 팝업의 밝은 화면과 어두운 화면을 캡처한다', (tester) async {
    tester.view.physicalSize = const Size(412, 892);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final previous = ThemeModeSettings.instance.value;
    addTearDown(() => ThemeModeSettings.instance.value = previous);
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
      ThemeModeSettings.instance.value =
          dark ? ThemeMode.dark : ThemeMode.light;
      final boundary = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(
        key: boundary,
        child: const AppUpdateGate(
          service: _PreviewUpdates(),
          child: SizedBox(),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text('새로운 버전이 있어요'), findsOneWidget);
      // 테스트 엔진에는 Android/iOS의 시스템 한글 대체 글꼴이 없다.
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
        File('${output.path}/app-update-${dark ? 'dark' : 'light'}.png')
            .writeAsBytesSync(bytes!.buffer.asUint8List());
        bitmap.dispose();
      });
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    }
  });
}
