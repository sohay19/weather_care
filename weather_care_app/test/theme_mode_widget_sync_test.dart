import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:weather_care/services/home_widget_service.dart';
import 'package:weather_care/services/theme_mode_settings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.codesoha.weathercare/home-widget');
  final calls = <MethodCall>[];

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return null;
    });
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('시작 시 저장된 테마를 위젯에 동기화하고 기존 설치의 다크 테마도 복원한다', () async {
    await ThemeModeSettings.instance.load();
    expect(calls.single.method, 'setThemeMode');
    expect(calls.single.arguments, 'system');

    SharedPreferences.setMockInitialValues({'weather_care_theme_mode': 'dark'});
    await ThemeModeSettings.instance.load();
    expect(ThemeModeSettings.instance.value, ThemeMode.dark);
    expect(calls.last.arguments, 'dark');
  });

  test('양 플랫폼에서 테마 선택만으로 위젯을 갱신하며 시스템 모드도 전달한다', () async {
    for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
      debugDefaultTargetPlatformOverride = platform;
      await ThemeModeSettings.instance.load();
      calls.clear();
      for (final mode in [ThemeMode.dark, ThemeMode.light, ThemeMode.system]) {
        await ThemeModeSettings.instance.save(mode);
        expect(calls.last.method, 'setThemeMode');
        expect(calls.last.arguments, mode.name);
        expect(
            (await SharedPreferences.getInstance())
                .getString('weather_care_theme_mode'),
            mode.name);
      }
      expect(calls.length, 3);
    }
  });

  test('위젯 갱신 실패가 앱 테마 저장을 취소하지 않는다', () async {
    await ThemeModeSettings.instance.load();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async {
      throw PlatformException(code: 'WIDGET_UNAVAILABLE');
    });
    await ThemeModeSettings.instance.save(ThemeMode.dark);
    expect(ThemeModeSettings.instance.value, ThemeMode.dark);
    expect(
        (await SharedPreferences.getInstance())
            .getString('weather_care_theme_mode'),
        'dark');
  });

  test('위젯 미지원 플랫폼에서는 네이티브 호출을 생략한다', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    await const HomeWidgetService().setThemeMode(ThemeMode.dark);
    expect(calls, isEmpty);
  });
}
