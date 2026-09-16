import 'dart:async';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import 'analytics_consent_store.dart';
import 'analytics_deletion_store.dart';

/// Separate from notification permission and server registration.
class AnalyticsConsent extends ChangeNotifier {
  AnalyticsConsent(
      {required this.read,
      required this.write,
      required this.apply,
      this.deletionStore,
      this.fetchAppInstanceId,
      this.resetAnalyticsData});
  final Future<bool> Function() read;
  final Future<void> Function(bool) write;
  final Future<void> Function(bool) apply;
  final AnalyticsDeletionPersistence? deletionStore;
  final Future<String?> Function()? fetchAppInstanceId;
  final Future<void> Function()? resetAnalyticsData;
  bool enabled = false;
  bool busy = false;
  bool ready = false;
  bool requested = false;
  String? error;
  String? deletionStatus;
  String? deletionError;

  static final instance = AnalyticsConsent(
    read: AnalyticsConsentStore.instance.read,
    write: AnalyticsConsentStore.instance.write,
    deletionStore: AnalyticsDeletionStore.instance,
    fetchAppInstanceId: () => FirebaseAnalytics.instance.appInstanceId,
    resetAnalyticsData: () => FirebaseAnalytics.instance.resetAnalyticsData(),
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
      await _finishSubmittedDeletion();
      await apply(enabled);
      if (enabled) await _captureIdentifierBestEffort();
      ready = true;
      error = null;
    } catch (_) {
      enabled = false;
      try {
        await apply(false);
      } catch (_) {/* Keep the error visible. */}
      error = '이용 통계 설정을 확인하지 못했어요.\n다시 시도해주세요.';
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
        // Start the local identifier capture first, but never delay the SDK
        // stop while waiting for it to finish.
        final identifierCapture = _captureLiveIdentifierBestEffort();
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
        await identifierCapture;
        if (failure != null) throw failure;
        enabled = false;
        return;
      }
      await write(value);
      await apply(value);
      enabled = value;
      await _captureIdentifierBestEffort();
    } catch (_) {
      try {
        await write(false);
      } catch (_) {/* Never treat a failed persistence as success. */}
      try {
        await apply(false);
      } catch (_) {/* Report failure, never success. */}
      enabled = false;
      error = '이용 통계 설정을 적용하지 못했어요.\n수집 중단과 설정 저장을 완료하려면 다시 시도해주세요.';
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> deleteCollectedData(
      Future<void> Function(String appInstanceId) submitDeletion) async {
    if (busy ||
        !ready ||
        deletionStore == null ||
        fetchAppInstanceId == null ||
        resetAnalyticsData == null) {
      return;
    }
    busy = true;
    requested = false;
    deletionStatus = null;
    deletionError = null;
    error = null;
    notifyListeners();
    AnalyticsDeletionRecord? record;
    try {
      try {
        record = await _deletionRecord(allowFetch: enabled);
      } catch (_) {
        // Collection withdrawal below must still run when identifier storage fails.
      }

      Object? withdrawalFailure;
      try {
        await apply(false);
      } catch (failure) {
        withdrawalFailure = failure;
      }
      try {
        await write(false);
      } catch (failure) {
        withdrawalFailure ??= failure;
      }
      enabled = false;
      if (withdrawalFailure != null) {
        error = '이용 통계 수집 중단을 완료하지 못했어요.\n다시 시도해주세요.';
        deletionError = '수집 중단을 완료한 뒤 삭제를 다시 요청해주세요.';
        return;
      }
      if (record == null) {
        deletionError = '삭제 요청에 사용할 이용 통계 식별자를 확인하지 못했어요.\n이후 수집은 중단했어요.';
        return;
      }

      var submitted = record.submitted;
      if (!submitted) {
        await submitDeletion(record.appInstanceId);
        submitted = true;
        try {
          await deletionStore!.markSubmitted(record.appInstanceId);
        } catch (_) {
          // This process still knows that Google accepted the request. Continue
          // local cleanup; a crash may cause a safe duplicate submission.
        }
      }
      try {
        await resetAnalyticsData!();
        await deletionStore!.clear();
      } catch (_) {
        deletionError = submitted
            ? 'Google Analytics 삭제 요청은 접수됐지만 기기의 분석 데이터 초기화를 완료하지 못했어요.\n다시 시도해주세요.'
            : 'Google Analytics 삭제 요청을 완료하지 못했어요.\n다시 시도해주세요.';
        return;
      }
      deletionStatus = 'Google Analytics에 삭제 요청이 접수됐어요.\n기기의 분석 데이터도 초기화했어요.';
    } catch (_) {
      deletionError =
          'Google Analytics 삭제 요청을 접수하지 못했어요.\n이용 통계 수집은 중단했으며 다시 시도할 수 있어요.';
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<AnalyticsDeletionRecord?> _deletionRecord(
      {required bool allowFetch}) async {
    final existing = await deletionStore?.read();
    if (existing != null || !allowFetch) return existing;
    final id =
        await fetchAppInstanceId?.call().timeout(const Duration(seconds: 3));
    if (id == null || id.isEmpty || id.length > 256) return null;
    await deletionStore!.saveIdentifier(id);
    return AnalyticsDeletionRecord(appInstanceId: id, submitted: false);
  }

  Future<void> _captureIdentifierBestEffort() async {
    if (deletionStore == null || fetchAppInstanceId == null) return;
    try {
      await _deletionRecord(allowFetch: true);
    } catch (_) {
      // Consent and especially withdrawal must not be blocked by this cache.
    }
  }

  Future<void> _captureLiveIdentifierBestEffort() async {
    if (deletionStore == null || fetchAppInstanceId == null) return;
    try {
      // Calling the getter happens synchronously before this method reaches its
      // first await, so the following SDK stop does not get ahead of the request.
      final id =
          await fetchAppInstanceId!.call().timeout(const Duration(seconds: 3));
      if (id == null || id.isEmpty || id.length > 256) return;
      await deletionStore!.saveIdentifier(id);
    } catch (_) {
      // Withdrawal proceeds even when the identifier cannot be preserved.
    }
  }

  Future<void> _finishSubmittedDeletion() async {
    if (deletionStore == null || resetAnalyticsData == null) return;
    AnalyticsDeletionRecord? record;
    try {
      record = await deletionStore!.read();
    } catch (_) {
      deletionError = '기기에 저장된 이용 통계 삭제 상태를 확인하지 못했어요.';
      return;
    }
    if (record?.submitted != true) return;
    await resetAnalyticsData!();
    await deletionStore!.clear();
  }
}
