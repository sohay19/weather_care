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

  test('iOS widgets use 75 percent outer margins and fit the temperature row', () {
    final widget = File(
      'ios/WeatherCareWidget/WeatherCareWidget.swift',
    ).readAsStringSync();

    expect(widget, contains('widgetOuterMarginRatio: CGFloat = 0.75'));
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
  });
}
