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

    expect(provider, contains('MEDIUM_MIN_WIDTH_DP = 150'));
    expect(
      RegExp(r'WidgetSize\.MEDIUM[\s\S]*?snapshot\.shortMessage')
          .hasMatch(provider),
      isTrue,
    );
    expect(provider, contains('json.optJSONArray("preparationCatalog")'));
  });

  test('iOS widgets use family margins and fit the temperature row', () {
    final widget = File(
      'ios/WeatherCareWidget/WeatherCareWidget.swift',
    ).readAsStringSync();

    expect(widget, contains('widgetOuterMarginRatio: CGFloat = 0.75'));
    expect(
      widget,
      contains('smallWidgetVerticalMarginRatio: CGFloat = 0.45'),
    );
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
    expect(
      widget,
      contains(
        'refreshButtonLoadingSurface = Color(red: 214 / 255, green: 232 / 255, blue: 245 / 255)',
      ),
    );
    expect(
      widget,
      contains('isRefreshing ? refreshButtonLoadingSurface'),
    );
    expect(widget, contains('.invalidatableContent()'));
    expect(widget, contains('redactionReasons.contains(.invalidated)'));
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
    final xcodeProject =
        File('ios/Runner.xcodeproj/project.pbxproj').readAsStringSync();

    expect(provider, contains('ACTION_REFRESH'));
    expect(provider, contains('WeatherCareWidgetRefreshWorker.class'));
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
      RegExp(r'WidgetRefreshIntent\.swift in Sources')
          .allMatches(xcodeProject)
          .length,
      greaterThanOrEqualTo(4),
    );
  });
}
