import 'package:shared_preferences/shared_preferences.dart';

class PermissionOnboardingStore {
  static const storageKey = 'permission_onboarding_v1_confirmed';

  const PermissionOnboardingStore();

  Future<bool> isConfirmed() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      return preferences.getBool(storageKey) == true;
    } catch (_) {
      return false;
    }
  }

  Future<void> confirm() async {
    final preferences = await SharedPreferences.getInstance();
    if (!await preferences.setBool(storageKey, true)) {
      throw StateError('Permission onboarding confirmation was not saved');
    }
  }
}
