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

  static const _debugBypassRequested =
      bool.fromEnvironment('ADMOB_TEST_BYPASS_UMP', defaultValue: false);

  static bool debugBypassAllowed({
    required bool requested,
    required bool releaseMode,
    bool debugMode = false,
  }) =>
      !releaseMode && (requested || debugMode);

  static final bool _debugBypass = debugBypassAllowed(
    requested: _debugBypassRequested,
    releaseMode: kReleaseMode,
    debugMode: kDebugMode,
  );

  static final instance = AdsConsent(
    update: _debugBypass
        ? () async {}
        : () {
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
    showRequired: _debugBypass
        ? () async {}
        : () async {
            await ConsentForm.loadAndShowConsentFormIfRequired((error) {
              if (error != null) throw StateError('UMP form');
            });
          },
    showOptions: _debugBypass
        ? () async {}
        : () async {
            await ConsentForm.showPrivacyOptionsForm((error) {
              if (error != null) throw StateError('UMP options');
            });
          },
    allowed: _debugBypass
        ? () async => true
        : () => ConsentInformation.instance.canRequestAds(),
    optionsRequired: _debugBypass
        ? () async => false
        : () async =>
            await ConsentInformation.instance
                .getPrivacyOptionsRequirementStatus() ==
            PrivacyOptionsRequirementStatus.required,
    initializeAds: () async {
      await MobileAds.instance.updateRequestConfiguration(
        RequestConfiguration(maxAdContentRating: MaxAdContentRating.g),
      );
      await MobileAds.instance.initialize();
    },
  );

  Future<void> refresh() => _run(false);
  Future<void> openPrivacyOptions() => _run(true);

  Future<void> _run(bool options) async {
    if (busy || (options && !privacyOptionsRequired)) return;
    if (kDebugMode) {
      debugPrint(
        _debugBypass ? '광고 동의 확인: Debug 테스트 우회 사용' : '광고 동의 확인: UMP 사용',
      );
    }
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
      if (kDebugMode) debugPrint('광고 요청 가능 상태: $eligible');
    } catch (caught) {
      // Conservative: no cached-consent fallback on failure in this app.
      canRequestAds = false;
      error = '광고 개인정보 선택을 확인하지 못했어요.\n날씨 기능은 계속 이용할 수 있어요.';
      if (kDebugMode) {
        debugPrint('광고 동의 확인 실패: ${caught.runtimeType}');
      }
    } finally {
      busy = false;
      notifyListeners();
    }
  }
}
