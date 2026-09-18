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
}
