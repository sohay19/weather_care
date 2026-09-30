import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android keeps SDK auto initialization off and ad permissions enabled',
      () {
    final manifest =
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync();

    expect(manifest, contains('firebase_messaging_auto_init_enabled'));
    expect(
      manifest,
      contains('android:name="firebase_analytics_collection_enabled"'),
    );
    expect(
      RegExp(
        r'firebase_messaging_auto_init_enabled"\s+android:value="false"',
      ).hasMatch(manifest),
      isTrue,
    );
    expect(
      RegExp(
        r'com\.google\.firebase\.provider\.FirebaseInitProvider"\s+tools:node="remove"',
      ).hasMatch(manifest),
      isTrue,
    );
    expect(
      RegExp(
        r'com\.google\.android\.gms\.ads\.MobileAdsInitProvider"\s+tools:node="remove"',
      ).hasMatch(manifest),
      isTrue,
    );
    for (final permission in [
      'com.google.android.gms.permission.AD_ID',
      'android.permission.ACCESS_ADSERVICES_AD_ID',
    ]) {
      expect(
        RegExp(
          'android:name="${RegExp.escape(permission)}"',
        ).hasMatch(manifest),
        isTrue,
      );
      expect(
        RegExp(
          'android:name="${RegExp.escape(permission)}"\\s+tools:node="remove"',
        ).hasMatch(manifest),
        isFalse,
      );
    }
  });

  test('iOS disables FCM and Analytics auto initialization by default', () {
    final plist = File('ios/Runner/Info.plist').readAsStringSync();

    expect(
      RegExp(
        r'<key>FirebaseMessagingAutoInitEnabled</key>\s*<false/>',
      ).hasMatch(plist),
      isTrue,
    );
    expect(
      RegExp(
        r'<key>FIREBASE_ANALYTICS_COLLECTION_ENABLED</key>\s*<false/>',
      ).hasMatch(plist),
      isTrue,
    );
    expect(plist, isNot(contains('NSUserTrackingUsageDescription')));
  });

  test('Android 3-column medium widget renders the short briefing', () {
    final provider = File(
      'android/app/src/main/java/com/weathercare/weather_care/WeatherCareWidgetProvider.java',
    ).readAsStringSync();

    expect(provider, contains('MEDIUM_MIN_WIDTH_DP = 200'));
    expect(
      RegExp(r'WidgetSize\.MEDIUM[\s\S]*?snapshot\.shortMessage')
          .hasMatch(provider),
      isTrue,
    );
    expect(provider, contains('json.optJSONArray("preparationCatalog")'));
  });

  test('Android 2-column widget always matches the iOS small header', () {
    final provider = File(
      'android/app/src/main/java/com/weathercare/weather_care/WeatherCareWidgetProvider.java',
    ).readAsStringSync();
    final smallLayout = File(
      'android/app/src/main/res/layout/weather_widget_small.xml',
    ).readAsStringSync();

    expect(
      provider,
      contains(
        'if (minWidth < MEDIUM_MIN_WIDTH_DP) return WidgetSize.SMALL;',
      ),
    );
    expect(
      RegExp(
        r'if \(minWidth < MEDIUM_MIN_WIDTH_DP\) return WidgetSize\.SMALL;\s*return minHeight >= LARGE_MIN_HEIGHT_DP',
      ).hasMatch(provider),
      isTrue,
    );
    expect(
      RegExp(
        r'<LinearLayout[\s\S]*?android:layout_weight="1"[\s\S]*?widget_region[\s\S]*?widget_refresh_time[\s\S]*?</LinearLayout>[\s\S]*?widget_refresh_button',
      ).hasMatch(smallLayout),
      isTrue,
    );
    expect(
      smallLayout.indexOf('widget_region'),
      lessThan(smallLayout.indexOf('widget_refresh_time')),
    );
  });

  test('iOS widgets share vertical margins and fit the temperature row', () {
    final widget = File(
      'ios/WeatherCareWidget/WeatherCareWidget.swift',
    ).readAsStringSync();

    expect(widget, contains('widgetHorizontalMarginRatio: CGFloat = 0.75'));
    expect(
      widget,
      contains('widgetVerticalMarginRatio: CGFloat = 0.45'),
    );
    expect(widget, isNot(contains('smallWidgetVerticalMarginRatio')));
    expect(widget, isNot(contains('.padding(.vertical, 2 * widget')));
    expect(widget, isNot(contains('.padding(.vertical, 3 * widget')));
    expect(widget, contains('@Environment(\\.widgetContentMargins)'));
    expect(widget, contains('.contentMarginsDisabled()'));
    expect(
      RegExp(r'AdaptiveTemperatureRow\(').allMatches(widget).length,
      3,
    );
    expect(
      widget,
      contains('fittedScale(availableWidth: geometry.size.width)'),
    );
    expect(widget, contains('SmallWidgetHeader(snapshot: snapshot)'));
    expect(
      widget,
      contains(
        'refreshButtonSurface = Color(red: 71 / 255, green: 111 / 255, blue: 152 / 255)',
      ),
    );
    expect(widget, isNot(contains('Link(destination: weatherCareHomeURL)')));
    expect(widget, contains('widgetContent.widgetURL(weatherCareHomeURL)'));
    expect(widget, contains('Button(intent: RefreshWeatherWidgetIntent())'));
    expect(widget, contains('Image(systemName: "arrow.clockwise")'));
    expect(
      widget,
      contains('.frame(width: 30, height: 30)'),
    );
    expect(widget, contains('.background(refreshButtonSurface, in: Circle())'));
    expect(widget, contains('.frame(width: 44, height: 44)'));
    expect(widget, contains('.background(Color.white.opacity(0.001))'));
    expect(widget, contains('.contentShape(.interaction, Rectangle())'));
    expect(widget, contains('.accessibilityLabel("날씨 새로고침")'));
    expect(widget, isNot(contains('weatherWidgetRefreshAvailable()')));
    expect(widget, isNot(contains('WidgetRefreshButtonPlaceholder')));
  });

  test('Android and iOS expose manual widget refresh on supported systems', () {
    final provider = File(
      'android/app/src/main/java/com/weathercare/weather_care/WeatherCareWidgetProvider.java',
    ).readAsStringSync();
    final iosWidget = File(
      'ios/WeatherCareWidget/WeatherCareWidget.swift',
    ).readAsStringSync();
    final iosIntent = File(
      'ios/WeatherCareWidget/WidgetRefreshIntent.swift',
    ).readAsStringSync();
    final androidWorker = File(
      'android/app/src/main/java/com/weathercare/weather_care/WeatherCareWidgetRefreshWorker.java',
    ).readAsStringSync();
    final androidActivity = File(
      'android/app/src/main/java/com/weathercare/weather_care/MainActivity.java',
    ).readAsStringSync();
    final iosAppDelegate =
        File('ios/Runner/AppDelegate.swift').readAsStringSync();
    final androidRefreshBackground = File(
      'android/app/src/main/res/drawable/weather_widget_refresh_background.xml',
    ).readAsStringSync();
    final androidLoadingBackground = File(
      'android/app/src/main/res/drawable/weather_widget_refresh_background_loading.xml',
    ).readAsStringSync();
    final androidRefreshIcon = File(
      'android/app/src/main/res/drawable/ic_widget_refresh.xml',
    ).readAsStringSync();
    final androidLoadingIcon = File(
      'android/app/src/main/res/drawable/ic_widget_refresh_loading.xml',
    ).readAsStringSync();
    final xcodeProject =
        File('ios/Runner.xcodeproj/project.pbxproj').readAsStringSync();

    expect(provider, contains('ACTION_REFRESH'));
    expect(provider, contains('WeatherCareWidgetRefreshWorker.class'));
    expect(provider, contains('REFRESH_IN_PROGRESS_KEY'));
    expect(provider, contains('weather_widget_refresh_background_loading'));
    expect(provider, contains('ic_widget_refresh_loading'));
    expect(
      RegExp(r'setRefreshInProgress\(context, true\)[\s\S]*finally')
          .hasMatch(androidWorker),
      isTrue,
    );
    expect(androidWorker, contains('setRefreshInProgress(context, false)'));
    expect(
      androidWorker,
      contains('MainActivity.preserveSpecificWidgetRegion('),
    );
    expect(
      androidActivity,
      contains('static String preserveSpecificWidgetRegion('),
    );
    expect(androidActivity, contains('!"현재 위치".equals(value)'));
    expect(androidActivity, contains('stored.startsWith(next)'));
    expect(androidRefreshBackground, contains('#476F98'));
    expect(androidLoadingBackground, contains('#D6E8F5'));
    expect(androidRefreshIcon, contains('#FFFFFF'));
    expect(androidLoadingIcon, contains('#476F98'));
    for (final family in ['small', 'medium', 'large']) {
      final layout = File(
        'android/app/src/main/res/layout/weather_widget_$family.xml',
      ).readAsStringSync();
      expect(layout, contains('@+id/widget_refresh_button'));
    }
    expect(iosWidget, contains('if #available(iOS 17.0, *)'));
    expect(
        iosWidget, contains('.fixedSize(horizontal: true, vertical: false)'));
    expect(iosIntent, contains('struct RefreshWeatherWidgetIntent: AppIntent'));
    expect(iosIntent, contains('static var openAppWhenRun = false'));
    expect(
      iosIntent,
      contains('weatherWidgetSnapshotPreservingSpecificRegion('),
    );
    expect(
      iosAppDelegate,
      contains('weatherWidgetSnapshotPreservingSpecificRegion('),
    );
    expect(iosIntent, contains('stored.hasPrefix(incoming)'));
    expect(
      RegExp(r'WidgetRefreshIntent\.swift in Sources')
          .allMatches(xcodeProject)
          .length,
      greaterThanOrEqualTo(4),
    );
  });
}
