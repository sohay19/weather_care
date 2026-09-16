import 'package:shared_preferences/shared_preferences.dart';

class AppOpenLaunchStore {
  static const _launchedBeforeKey = 'app_open_ad_launched_before_v1';

  const AppOpenLaunchStore();

  /// The first launch is recorded but does not show an app open ad.
  Future<bool> recordLaunchAndShouldShow() async {
    final preferences = await SharedPreferences.getInstance();
    final launchedBefore = preferences.getBool(_launchedBeforeKey) ?? false;
    if (!launchedBefore) {
      await preferences.setBool(_launchedBeforeKey, true);
    }
    return launchedBefore;
  }
}
