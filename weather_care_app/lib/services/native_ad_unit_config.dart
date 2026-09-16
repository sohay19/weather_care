import 'package:flutter/foundation.dart';

enum NativeAdPlacement { today, main, week }

class NativeAdUnitConfig {
  static const androidTestId = 'ca-app-pub-3940256099942544/2247696110';
  static const iosTestId = 'ca-app-pub-3940256099942544/3986624511';

  static const current = NativeAdUnitConfig(
    androidTodayReleaseId:
        String.fromEnvironment('ADMOB_ANDROID_TODAY_NATIVE_ID'),
    iosTodayReleaseId: String.fromEnvironment('ADMOB_IOS_TODAY_NATIVE_ID'),
    androidMainReleaseId:
        String.fromEnvironment('ADMOB_ANDROID_MAIN_NATIVE_ID'),
    iosMainReleaseId: String.fromEnvironment('ADMOB_IOS_MAIN_NATIVE_ID'),
    androidWeekReleaseId: String.fromEnvironment(
      'ADMOB_ANDROID_WEEK_NATIVE_ID',
      defaultValue: String.fromEnvironment('ADMOB_ANDROID_NATIVE_ID'),
    ),
    iosWeekReleaseId: String.fromEnvironment(
      'ADMOB_IOS_WEEK_NATIVE_ID',
      defaultValue: String.fromEnvironment('ADMOB_IOS_NATIVE_ID'),
    ),
  );

  final String androidTodayReleaseId;
  final String iosTodayReleaseId;
  final String androidMainReleaseId;
  final String iosMainReleaseId;
  final String androidWeekReleaseId;
  final String iosWeekReleaseId;

  const NativeAdUnitConfig({
    this.androidTodayReleaseId = '',
    this.iosTodayReleaseId = '',
    this.androidMainReleaseId = '',
    this.iosMainReleaseId = '',
    this.androidWeekReleaseId = '',
    this.iosWeekReleaseId = '',
  });

  String? resolve({
    NativeAdPlacement placement = NativeAdPlacement.week,
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

    final id = switch ((target, placement)) {
      (TargetPlatform.android, NativeAdPlacement.today) =>
        androidTodayReleaseId.trim(),
      (TargetPlatform.iOS, NativeAdPlacement.today) => iosTodayReleaseId.trim(),
      (TargetPlatform.android, NativeAdPlacement.main) =>
        androidMainReleaseId.trim(),
      (TargetPlatform.iOS, NativeAdPlacement.main) => iosMainReleaseId.trim(),
      (TargetPlatform.android, NativeAdPlacement.week) =>
        androidWeekReleaseId.trim(),
      (TargetPlatform.iOS, NativeAdPlacement.week) => iosWeekReleaseId.trim(),
      _ => '',
    };
    return _validAdMobUnitId(id) ? id : null;
  }

  static bool _validAdMobUnitId(String value) =>
      RegExp(r'^ca-app-pub-\d{16}/\d{10}$').hasMatch(value);
}
