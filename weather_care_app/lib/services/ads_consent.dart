import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// UMP, not Analytics consent or a locally cached boolean, owns ad eligibility.
class AdsConsent extends ChangeNotifier {
  AdsConsent(
      {required this.update,
      required this.showRequired,
      required this.showOptions,
      required this.allowed,
      required this.optionsRequired,
      required this.initializeAds});
  final Future<void> Function() update,
      showRequired,
      showOptions,
      initializeAds;
  final Future<bool> Function() allowed, optionsRequired;
  bool busy = false, canRequestAds = false, privacyOptionsRequired = false;
  bool _initialized = false;
  String? error;

  static final instance = AdsConsent(
    update: () {
      final completion = Completer<void>();
      ConsentInformation.instance
          .requestConsentInfoUpdate(ConsentRequestParameters(), () {
        if (!completion.isCompleted) completion.complete();
      }, (_) {
        if (!completion.isCompleted) {
          completion.completeError(StateError('UMP update'));
        }
      });
      return completion.future.timeout(const Duration(seconds: 30));
    },
    showRequired: () async {
      await ConsentForm.loadAndShowConsentFormIfRequired((error) {
        if (error != null) throw StateError('UMP form');
      });
    },
    showOptions: () async {
      await ConsentForm.showPrivacyOptionsForm((error) {
        if (error != null) throw StateError('UMP options');
      });
    },
    allowed: () => ConsentInformation.instance.canRequestAds(),
    optionsRequired: () async =>
        await ConsentInformation.instance
            .getPrivacyOptionsRequirementStatus() ==
        PrivacyOptionsRequirementStatus.required,
    initializeAds: () async {
      await MobileAds.instance.initialize();
    },
  );

  Future<void> refresh() => _run(false);
  Future<void> openPrivacyOptions() => _run(true);

  Future<void> _run(bool options) async {
    if (busy || (options && !privacyOptionsRequired)) return;
    busy = true;
    canRequestAds = false;
    error = null;
    notifyListeners();
    try {
      if (options) {
        await showOptions();
      } else {
        await update();
        // Keep the entry visible even if displaying the required form fails.
        privacyOptionsRequired = await optionsRequired();
        await showRequired();
      }
      privacyOptionsRequired = await optionsRequired();
      final eligible = await allowed();
      if (eligible && !_initialized) {
        await initializeAds();
        _initialized = true;
      }
      canRequestAds = eligible;
    } catch (_) {
      // Conservative: no cached-consent fallback on failure in this app.
      canRequestAds = false;
      error = '광고 개인정보 선택을 확인하지 못했어요. 날씨 기능은 계속 이용할 수 있어요.';
    } finally {
      busy = false;
      notifyListeners();
    }
  }
}
