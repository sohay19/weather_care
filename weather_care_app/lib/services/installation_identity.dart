import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

class InstallationIdentity {
  static const _storageKey = 'weather_care_installation_id';

  const InstallationIdentity();

  Future<String?> getExisting() async {
    final stored =
        (await SharedPreferences.getInstance()).getString(_storageKey);
    return stored == null || stored.isEmpty ? null : stored;
  }

  Future<String> getOrCreate() async {
    final existing = await getExisting();
    if (existing != null) return existing;

    final preferences = await SharedPreferences.getInstance();
    final random = Random.secure();
    final bytes = List<int>.generate(18, (_) => random.nextInt(256));
    final generated = 'wc_${base64Url.encode(bytes).replaceAll('=', '')}';
    await preferences.setString(_storageKey, generated);
    return generated;
  }
}
