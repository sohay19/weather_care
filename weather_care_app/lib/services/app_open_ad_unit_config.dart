import 'package:flutter/foundation.dart';

class AppOpenAdUnitConfig {
  static const androidTestId = 'ca-app-pub-3940256099942544/9257395921';
  static const iosTestId = 'ca-app-pub-3940256099942544/5575463023';
  static const defaultAndroidReleaseId =
      'ca-app-pub-6152243173470406/2388414592';
  static const defaultIosReleaseId = 'ca-app-pub-6152243173470406/5946806649';

  static const current = AppOpenAdUnitConfig(
    androidReleaseId: String.fromEnvironment(
      'ADMOB_ANDROID_APP_OPEN_ID',
      defaultValue: defaultAndroidReleaseId,
    ),
    iosReleaseId: String.fromEnvironment(
      'ADMOB_IOS_APP_OPEN_ID',
      defaultValue: defaultIosReleaseId,
    ),
  );

  final String androidReleaseId;
  final String iosReleaseId;

  const AppOpenAdUnitConfig({
    this.androidReleaseId = '',
    this.iosReleaseId = '',
  });

  String? resolve({
    TargetPlatform? platform,
    bool? releaseMode,
    bool? web,
  }) {
    if (web ?? kIsWeb) return null;

    final target = platform ?? defaultTargetPlatform;
    if (target != TargetPlatform.android && target != TargetPlatform.iOS) {
      return null;
    }
    if (!(releaseMode ?? kReleaseMode)) {
      return target == TargetPlatform.android ? androidTestId : iosTestId;
    }
    final id = target == TargetPlatform.android
        ? androidReleaseId.trim()
        : iosReleaseId.trim();
    return RegExp(r'^ca-app-pub-\d{16}/\d{10}$').hasMatch(id) ? id : null;
  }
}
