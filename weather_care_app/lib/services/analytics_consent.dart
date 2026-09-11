import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import 'analytics_consent_store.dart';

/// Separate from notification permission and server registration.
class AnalyticsConsent extends ChangeNotifier {
  AnalyticsConsent(
      {required this.read, required this.write, required this.apply});
  final Future<bool> Function() read;
  final Future<void> Function(bool) write;
  final Future<void> Function(bool) apply;
  bool enabled = false;
  bool busy = false;
  bool ready = false;
  bool requested = false;
  String? error;

  static final instance = AnalyticsConsent(
    read: AnalyticsConsentStore.instance.read,
    write: AnalyticsConsentStore.instance.write,
    apply: (value) async {
      final analytics = FirebaseAnalytics.instance;
      // Disable first; consent mode alone is not a no-collection switch.
      await analytics.setAnalyticsCollectionEnabled(false);
      await analytics.setConsent(
        analyticsStorageConsentGranted: value,
        adStorageConsentGranted: false,
        adUserDataConsentGranted: false,
        adPersonalizationSignalsConsentGranted: false,
      );
      if (value) await analytics.setAnalyticsCollectionEnabled(true);
    },
  );

  Future<void> initialize() async {
    if (ready || busy) return;
    busy = true;
    try {
      // Never re-enable from persisted preferences before stopping SDK collection.
      await apply(false);
      enabled = await read();
      await apply(enabled);
      ready = true;
      error = null;
    } catch (_) {
      enabled = false;
      try {
        await apply(false);
      } catch (_) {/* Keep the error visible. */}
      error = '이용 통계 설정을 확인하지 못했어요. 다시 시도해주세요.';
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> change(bool value) async {
    if (busy || !ready) return;
    busy = true;
    requested = value;
    error = null;
    notifyListeners();
    try {
      // Stop immediately on withdrawal, even if storing the choice fails.
      if (!value) {
        Object? failure;
        try {
          await apply(false);
        } catch (error) {
          failure = error;
        }
        // SDK failure must not prevent persisting the withdrawal.
        try {
          await write(false);
        } catch (error) {
          failure ??= error;
        }
        if (failure != null) throw failure;
        enabled = false;
        return;
      }
      await write(value);
      await apply(value);
      enabled = value;
    } catch (_) {
      try {
        await write(false);
      } catch (_) {/* Never treat a failed persistence as success. */}
      try {
        await apply(false);
      } catch (_) {/* Report failure, never success. */}
      enabled = false;
      error = '이용 통계 설정을 적용하지 못했어요. 수집 중단과 설정 저장을 완료하려면 다시 시도해주세요.';
    } finally {
      busy = false;
      notifyListeners();
    }
  }
}
