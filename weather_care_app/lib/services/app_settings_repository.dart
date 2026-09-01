import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_settings.dart';

class AppSettingsRepository {
  static const _storageKey = 'weather_care_app_settings';

  const AppSettingsRepository();

  Future<AppSettings> load(String installationId) async {
    final preferences = await SharedPreferences.getInstance();
    final encoded = preferences.getString(_storageKey);
    if (encoded == null) return AppSettings.fallback(installationId);
    try {
      final json = jsonDecode(encoded);
      if (json is! Map) return AppSettings.fallback(installationId);
      return AppSettings.fromJson(
        Map<String, dynamic>.from(json),
        installationId,
      );
    } catch (_) {
      return AppSettings.fallback(installationId);
    }
  }

  Future<void> save(AppSettings settings) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_storageKey, jsonEncode(settings.toJson()));
  }
}
