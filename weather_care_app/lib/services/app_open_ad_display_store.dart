import 'package:shared_preferences/shared_preferences.dart';

abstract interface class AppOpenAdDisplayStore {
  Future<DateTime?> lastShownAt();
  Future<void> recordShownAt(DateTime time);
}

class SharedPreferencesAppOpenAdDisplayStore implements AppOpenAdDisplayStore {
  static const _lastShownAtKey = 'app_open_ad_last_shown_at_v1';

  const SharedPreferencesAppOpenAdDisplayStore();

  @override
  Future<DateTime?> lastShownAt() async {
    final preferences = await SharedPreferences.getInstance();
    final milliseconds = preferences.getInt(_lastShownAtKey);
    return milliseconds == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(milliseconds);
  }

  @override
  Future<void> recordShownAt(DateTime time) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setInt(_lastShownAtKey, time.millisecondsSinceEpoch);
  }
}
