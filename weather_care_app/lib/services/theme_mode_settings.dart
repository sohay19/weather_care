import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeModeSettings extends ValueNotifier<ThemeMode> {
  static final instance = ThemeModeSettings._();
  static const _storageKey = 'weather_care_theme_mode';

  ThemeModeSettings._() : super(ThemeMode.system);

  Future<void> load() async {
    final preferences = await SharedPreferences.getInstance();
    final saved = preferences.getString(_storageKey);
    value = ThemeMode.values.firstWhere(
      (mode) => mode.name == saved,
      orElse: () => ThemeMode.system,
    );
  }

  Future<void> save(ThemeMode mode) async {
    if (value == mode) return;
    final previous = value;
    value = mode;
    try {
      final preferences = await SharedPreferences.getInstance();
      if (!await preferences.setString(_storageKey, mode.name)) {
        throw StateError('Theme mode write failed');
      }
    } catch (_) {
      value = previous;
      rethrow;
    }
  }
}
