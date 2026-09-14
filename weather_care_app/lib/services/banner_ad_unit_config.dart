import 'package:flutter/foundation.dart';

class BannerAdUnitConfig {
  static const androidTestId = 'ca-app-pub-3940256099942544/9214589741';
  static const iosTestId = 'ca-app-pub-3940256099942544/2435281174';

  static const current = BannerAdUnitConfig(
    androidReleaseId: String.fromEnvironment('ADMOB_ANDROID_BANNER_ID'),
    iosReleaseId: String.fromEnvironment('ADMOB_IOS_BANNER_ID'),
    releaseServingEnabled:
        bool.fromEnvironment('ADMOB_RELEASE_ENABLED', defaultValue: false),
  );

  final String androidReleaseId;
  final String iosReleaseId;
  final bool releaseServingEnabled;

  const BannerAdUnitConfig({
    this.androidReleaseId = '',
    this.iosReleaseId = '',
    this.releaseServingEnabled = false,
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

    if (!releaseServingEnabled) return null;
    final id = target == TargetPlatform.android
        ? androidReleaseId.trim()
        : iosReleaseId.trim();
    return _validAdMobUnitId(id) ? id : null;
  }

  static bool _validAdMobUnitId(String value) =>
      RegExp(r'^ca-app-pub-\d{16}/\d{10}$').hasMatch(value);
}
