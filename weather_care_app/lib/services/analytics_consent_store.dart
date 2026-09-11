import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Both independent stores must grant consent. Missing/legacy values fail closed.
class AnalyticsConsentStore {
  AnalyticsConsentStore({
    required this.readPreference,
    required this.readGuard,
    required this.writePreference,
    required this.writeGuard,
  });

  final Future<bool> Function() readPreference;
  final Future<bool> Function() readGuard;
  final Future<void> Function(bool) writePreference;
  final Future<void> Function(bool) writeGuard;

  static final instance = AnalyticsConsentStore(
    readPreference: () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      return prefs.getBool('analytics_consent_v1') ?? false;
    },
    readGuard: () async =>
        await const FlutterSecureStorage()
            .read(key: 'analytics_consent_guard_v2') ==
        'granted',
    writePreference: (value) async {
      final prefs = await SharedPreferences.getInstance();
      if (!await prefs.setBool('analytics_consent_v1', value)) {
        throw StateError('consent preference persistence failed');
      }
    },
    writeGuard: (value) => const FlutterSecureStorage().write(
        key: 'analytics_consent_guard_v2', value: value ? 'granted' : 'denied'),
  );

  Future<bool> read() async {
    // Read guard first: a persisted withdrawal never depends on the old preference.
    if (!await readGuard()) return false;
    return readPreference();
  }

  Future<void> write(bool value) async {
    if (!value) {
      // Try BOTH stores even if one fails. A single persisted denial blocks restart.
      Object? failure;
      for (final writer in [writeGuard, writePreference]) {
        try {
          await writer(false);
        } catch (error) {
          failure ??= error;
        }
      }
      if (failure != null) throw failure;
      return;
    }
    // Invalidate old grants before starting a new grant transaction.
    await write(false);
    try {
      await writePreference(true);
      await writeGuard(true);
    } catch (_) {
      try {
        await write(false);
      } catch (_) {
        // Caller reports failure and disables the SDK as well.
      }
      rethrow;
    }
  }
}
