// 스토어용 현재 UI 렌더링. 실제 날씨·사용자 설정과 분리된 예시 데이터를 사용한다.
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:weather_care/features/home/tabs/main_tab.dart';
import 'package:weather_care/features/home/tabs/week_tab.dart';
import 'package:weather_care/features/home/tabs/extra_tab.dart';
import 'package:weather_care/features/settings/settings_screen.dart';
import 'package:weather_care/models/weather.dart';
import 'package:weather_care/models/app_settings.dart';
import 'package:weather_care/services/api_client.dart';
import 'package:weather_care/services/kma_grid.dart';
import 'package:weather_care/theme/weather_theme.dart';

final now = DateTime.parse('2026-10-22T08:00:00+09:00');
String at(int hour, [int day = 22]) =>
    DateTime.utc(2026, 10, day, hour - 9).toIso8601String();
final hourlyJson = [
  for (var day = 22; day <= 28; day++)
    for (var h = 0; h < 24; h++)
      {
        'forecastAt': at(h, day),
        'forecastDate': '2026-10-$day',
        'time': h.toString().padLeft(2, '0'),
        'temperature': (16 + 6 * math.sin((h - 7) / 24 * math.pi * 2)).round(),
        'apparentTemperature':
            (15 + 6 * math.sin((h - 7) / 24 * math.pi * 2)).round(),
        'skyCondition': h >= 17 && h <= 20 ? '비' : '구름 많음',
        'precipitationProbability': h >= 17 && h <= 20 ? 70 : 10,
        'precipitationAmount': h >= 17 && h <= 20 ? 1.5 : 0,
        'precipitationType': h >= 17 && h <= 20 ? '비' : '없음',
        'precipitationPeriod': {'start': at(h - 1, day), 'end': at(h, day)},
        'snowExpected': false,
        'snowfallAmount': 0,
        'uvIndex': h >= 10 && h <= 15 ? 5 : 1,
        'humidity': 65,
        'windSpeed': 2.4,
        'windDirection': 225,
        'pm10': 32,
        'pm25': 15,
      }
];
final today = TodayWeatherResponse.fromJson({
  'dataSource': 'store-example',
  'generatedAt': at(8),
  'region': {'name': '서울시 중구', 'nx': 60, 'ny': 127},
  'brief': '아침에는 선선하고 저녁에는 비가 내려요. 우산과 겉옷을 챙기세요.',
  'current': {
    'temperature': 18,
    'apparentTemperature': 17,
    'skyCondition': '구름 많음',
    'observedAt': at(8),
    'humidity': 65,
    'windSpeed': 2.4,
    'windDirection': 225,
    'uvIndex': 3,
    'pm10': 32,
    'pm25': 15,
    'precipitationAmount': 0
  },
  'recommendations': [
    {
      'type': 'UMBRELLA',
      'recommended': true,
      'priority': 90,
      'title': '우산을 챙기세요',
      'description': '저녁에 비가 예상돼요.',
      'notificationEligible': true,
      'validFrom': at(0),
      'validUntil': at(24)
    },
    {
      'type': 'LIGHT_OUTERWEAR',
      'recommended': true,
      'priority': 80,
      'title': '얇은 겉옷을 챙기세요',
      'description': '아침저녁으로 선선해요.',
      'notificationEligible': true,
      'validFrom': at(0),
      'validUntil': at(24)
    },
  ],
  'hourly': hourlyJson,
  'timelineHourly': hourlyJson,
}, receivedAt: DateTime.now());
final comparison = ComparisonResponse.fromJson({
  'comparisonAvailable': true,
  'targetDate': '2026-10-21',
  'current': {'temperature': 18, 'apparentTemperature': 17},
  'comparison': {'temperature': 21, 'apparentTemperature': 20},
});
final weekly = WeeklyWeatherResponse.fromJson({
  'generatedAt': at(8),
  'days': [
    for (var d = 18; d <= 24; d++)
      {
        'forecastDate': '2026-10-$d',
        'weatherLabel': d == 22 || d == 24 ? '비' : '맑음',
        'min': [12, 13, 12, 11, 13, 14, 12][d - 18],
        'max': [21, 23, 22, 20, 21, 23, 22][d - 18],
        'precipitationProbability': d == 22 || d == 24 ? 70 : 10,
        'precipitationAmount': d == 22 || d == 24 ? 4 : 0,
        'snowfallAmount': 0,
        'snowProbability': 0,
        'snowProbabilitySource': 'KMA_PRECIPITATION_FORECAST',
        'weatherDataComplete': true,
        'precipitationDetail': d < 22
            ? {
                'kind': 'OBSERVATION',
                'hours': [],
                'observedAmount': 0,
              }
            : {
                'kind': 'HOURLY',
                'hours': [
                  for (var h = 1; h <= 24; h++)
                    {
                      'forecastAt': at(h, d),
                      'probability':
                          (d == 22 || d == 24) && h >= 17 && h <= 20 ? 70 : 10,
                      'amountText': (d == 22 || d == 24) && h >= 17 && h <= 20
                          ? '1.5mm'
                          : '강수없음',
                    }
                ],
              },
        'recommendations': d == 22 || d == 24
            ? [
                {
                  'type': 'UMBRELLA',
                  'recommended': true,
                  'title': '우산',
                  'priority': 90,
                  'notificationEligible': true
                }
              ]
            : [],
      }
  ],
});

class StoreApi extends ApiClient {
  StoreApi() : super(baseUrl: 'https://example.invalid');
  @override
  Future<Map<String, dynamic>> get(String path,
      {Map<String, String>? query}) async {
    if (path.endsWith('/catalog')) {
      return {
        'groups': [
          for (final source in [
            'KHOA_TIDE_OBS',
            'KHOA_TIDE_HOURLY',
            'KHOA_TIDE_EXTREME'
          ])
            {
              'source': source,
              'title': '조위',
              'scope': 'station',
              'period': 'hourly',
              'targets': [
                {
                  'id': 'DT_0001',
                  'name': '인천',
                  'distanceKm': 3.2,
                  'latitude': 37.4519,
                  'longitude': 126.5922
                }
              ]
            },
        ]
      };
    }
    if (query?['source'] == 'KHOA_TIDE_EXTREME') {
      return {
        'records': [
          {
            'time': at(11),
            'values': {'extremeType': 3, 'tideCm': 730}
          },
          {
            'time': at(17),
            'values': {'extremeType': 4, 'tideCm': 120}
          },
        ]
      };
    }
    final forecast = query?['source'] == 'KHOA_TIDE_HOURLY';
    return {
      'records': [
        for (var h = 0; h <= (forecast ? 23 : 8); h++)
          {
            'time': at(h),
            'values': {
              'tideCm':
                  (425 + 300 * math.sin((h - 8) / 12 * math.pi * 2)).round()
            }
          }
      ]
    };
  }
}

class StoreShell extends StatelessWidget {
  final Widget screen;
  final int index;
  const StoreShell(this.screen, this.index, {super.key});
  @override
  Widget build(BuildContext context) {
    final colors = WeatherCareTheme.of(context);
    NavigationDestination destination(
            String label, IconData icon, IconData selected) =>
        NavigationDestination(
            icon: Icon(icon, color: colors.textSecondary),
            selectedIcon: Icon(selected, color: colors.primaryDeep),
            label: label);
    return Scaffold(
      body: SafeArea(child: screen),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        height: 74,
        backgroundColor: WeatherCareTheme.of(context).surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: WeatherCareTheme.of(context).primarySoft,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        onDestinationSelected: (_) {},
        destinations: [
          destination('Today', Icons.work_outline_rounded, Icons.work_rounded),
          destination(
              'Advanced', Icons.sensors_outlined, Icons.sensors_rounded),
          destination('Main', Icons.home_outlined, Icons.home_rounded),
          destination('Week', Icons.calendar_month_outlined,
              Icons.calendar_month_rounded),
          destination('Setting', Icons.tune_outlined, Icons.tune_rounded),
        ],
      ),
    );
  }
}

void main() {
  testWidgets('현재 Android 스토어 화면을 사용자 창 없이 렌더링한다', (tester) async {
    // store 아래에서 직접 실행하는 캡처 전용 테스트다.
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues({});
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final entry in <String, List<String>>{
      'Ahem': ['SUITE-Regular.ttf'],
      'Roboto': ['SUITE-Regular.ttf'],
      'sans-serif': ['SUITE-Regular.ttf'],
      'SUITE': ['SUITE-Regular.ttf', 'SUITE-Bold.ttf'],
      'ChosunSg': ['ChosunSg.TTF', 'ChosunKg.TTF'],
      'Mona': ['Mona10.ttf', 'Mona10-Bold.ttf'],
      'NeoHyundai': ['NeoHyundai R.ttf', 'NeoHyundai B.ttf'],
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
    for (final format in ['phone', 'tablet']) {
      final out = Directory('store/screenshots/source-20261022/$format')
        ..createSync(recursive: true);
      tester.view.physicalSize =
          format == 'phone' ? const Size(412, 1000) : const Size(800, 1280);
      Future<void> render(Widget screen, int index, String name,
          {bool dark = false, Future<void> Function()? action}) async {
        const selected = String.fromEnvironment('STORE_CAPTURE_SCREEN');
        if (selected.isNotEmpty && selected != name) return;
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
        final boundary = GlobalKey();
        await tester.pumpWidget(RepaintBoundary(
            key: boundary,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: dark ? WeatherCareTheme.dark() : WeatherCareTheme.light(),
              builder: WeatherCareTheme.textScaleBuilder,
              home: StoreShell(screen, index),
            )));
        await tester.pumpAndSettle();
        await tester.runAsync(() async {
          for (final image in ['prep_umbrella.png', 'prep_outerwear.png']) {
            await precacheImage(
                AssetImage('assets/icons/$image'), boundary.currentContext!);
          }
        });
        await tester.pumpAndSettle();
        if (action != null) {
          await action();
          await tester.pumpAndSettle();
        }
        // Android의 시스템 한글 대체 글꼴이 없는 테스트 엔진에서만 보완한다.
        InlineSpan fallback(InlineSpan span) {
          if (span is! TextSpan) return span;
          final style = span.style;
          return TextSpan(
              text: span.text,
              style: style?.copyWith(
                  fontFamily: style.fontFamily ?? 'SUITE',
                  fontFamilyFallback: ['SUITE']),
              children: span.children?.map(fallback).toList());
        }

        for (final element in find.byType(RichText).evaluate()) {
          final paragraph = element.renderObject;
          if (paragraph is RenderParagraph) {
            paragraph.text = fallback(paragraph.text);
          }
        }
        await tester.pump();
        expect(tester.takeException(), isNull, reason: '$format/$name');
        await tester.runAsync(() async {
          final bitmap = await (boundary.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary)
              .toImage(pixelRatio: format == 'phone' ? 3 : 2);
          final bytes = await bitmap.toByteData(format: ui.ImageByteFormat.png);
          File('${out.path}/$name.png')
              .writeAsBytesSync(bytes!.buffer.asUint8List());
          bitmap.dispose();
        });
      }

      MainTab mainTab() => MainTab(
          today: today,
          dateLabel: '2026년 10월 22일 목요일',
          mood: 'cloudy',
          serverFeaturesAvailable: true,
          yesterdayComparison: comparison,
          onRefresh: () async {},
          onDetail: (_) {});
      await render(mainTab(), 2, 'main');
      await render(mainTab(), 2, 'timeline', action: () async {
        final chip = find.byKey(const ValueKey('main-hourly-filter-weather'));
        await tester.scrollUntilVisible(chip, 240,
            scrollable: find.byType(Scrollable).first);
        await Scrollable.ensureVisible(tester.element(chip), alignment: 0.10);
      });
      await render(mainTab(), 2, 'dark-main', dark: true);
      await render(
          ExtraTab(
              client: StoreApi(),
              grid: const KmaGrid(nx: 60, ny: 127),
              active: true,
              now: now),
          1,
          'advanced');
      await render(
          ExtraTab(
              client: StoreApi(),
              grid: const KmaGrid(nx: 60, ny: 127),
              active: true,
              now: now),
          1,
          'advanced-chart', action: () async {
        await tester.drag(
            find.byKey(const ValueKey('extra-tab')), const Offset(0, -440));
      });
      await render(
          WeekTab(
              weekly: weekly,
              serverFeaturesAvailable: true,
              onRefresh: () async {},
              now: () => now,
              hourly: today.hourly,
              timelineHourly: today.hourly),
          3,
          'week');
      SettingsScreen settings() => SettingsScreen(
          embedded: true,
          initialSettings: AppSettings.fallback('store-example').copyWith(
              parasolEnabled: false,
              waterEnabled: false,
              sunscreenEnabled: false),
          onSettingsChanged: (_) async {});
      await render(settings(), 4, 'settings');
      await render(settings(), 4, 'notification-settings', action: () async {
        await tester.tap(find.byKey(const ValueKey('weather-alerts-menu')));
        await tester.pumpAndSettle();
        await Scrollable.ensureVisible(
            tester.element(
                find.byKey(const ValueKey('carry-notification-section'))),
            alignment: 0);
      });
      await render(settings(), 4, 'weather-alert-settings', action: () async {
        await tester.tap(find.byKey(const ValueKey('weather-alerts-menu')));
        await tester.pumpAndSettle();
        await Scrollable.ensureVisible(
            tester.element(
                find.byKey(const ValueKey('weather-notification-section'))),
            alignment: 0);
      });
    }
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
}
