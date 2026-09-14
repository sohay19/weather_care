import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AgeEligibility {
  unknown('unknown'),
  atLeast14('at_least_14'),
  under14('under_14');

  final String storageValue;

  const AgeEligibility(this.storageValue);

  static AgeEligibility? fromStorage(String? value) {
    for (final eligibility in values) {
      if (eligibility.storageValue == value) return eligibility;
    }
    return null;
  }
}

/// A positive age boundary is trusted only when both local stores agree.
/// Missing, mismatched, invalid, or partially written values fail closed.
class AgeEligibilityStore {
  AgeEligibilityStore({
    required this.readPreference,
    required this.readGuard,
    required this.writePreference,
    required this.writeGuard,
  });

  static const preferenceKey = 'age_eligibility_v1';
  static const guardKey = 'age_eligibility_guard_v1';

  final Future<String?> Function() readPreference;
  final Future<String?> Function() readGuard;
  final Future<void> Function(String?) writePreference;
  final Future<void> Function(String?) writeGuard;

  static final instance = AgeEligibilityStore(
    readPreference: () async {
      final preferences = await SharedPreferences.getInstance();
      await preferences.reload();
      return preferences.getString(preferenceKey);
    },
    readGuard: () =>
        const FlutterSecureStorage().read(key: AgeEligibilityStore.guardKey),
    writePreference: (value) async {
      final preferences = await SharedPreferences.getInstance();
      final stored = value == null
          ? await preferences.remove(preferenceKey)
          : await preferences.setString(preferenceKey, value);
      if (!stored) throw StateError('age preference persistence failed');
    },
    writeGuard: (value) => value == null
        ? const FlutterSecureStorage().delete(key: guardKey)
        : const FlutterSecureStorage().write(key: guardKey, value: value),
  );

  Future<AgeEligibility> read() async {
    final guard = AgeEligibility.fromStorage(await readGuard());
    if (guard == null || guard == AgeEligibility.unknown) {
      return AgeEligibility.unknown;
    }
    final preference = AgeEligibility.fromStorage(await readPreference());
    return preference == guard ? guard : AgeEligibility.unknown;
  }

  Future<void> write(AgeEligibility eligibility) async {
    if (eligibility == AgeEligibility.unknown) {
      await _invalidate();
      return;
    }

    await _invalidate();
    try {
      await writePreference(eligibility.storageValue);
      await writeGuard(eligibility.storageValue);
    } catch (_) {
      try {
        await _invalidate();
      } catch (_) {
        // A partial value is still fail-closed because reads require agreement.
      }
      rethrow;
    }
  }

  Future<void> _invalidate() async {
    Object? failure;
    for (final writer in [writeGuard, writePreference]) {
      try {
        await writer(null);
      } catch (error) {
        failure ??= error;
      }
    }
    if (failure != null) throw failure;
  }
}
