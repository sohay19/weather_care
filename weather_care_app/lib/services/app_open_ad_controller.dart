import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ad_removal_service.dart';
import 'ads_consent.dart';
import 'app_open_ad_unit_config.dart';

abstract interface class AppOpenAdHandle {
  Future<void> show({
    required VoidCallback onDismissed,
    required VoidCallback onFailedToShow,
  });

  Future<void> dispose();
}

abstract interface class AppOpenAdLoader {
  Future<AppOpenAdHandle?> load({required String adUnitId});
}

class GoogleAppOpenAdLoader implements AppOpenAdLoader {
  const GoogleAppOpenAdLoader();

  @override
  Future<AppOpenAdHandle?> load({required String adUnitId}) async {
    final completion = Completer<AppOpenAdHandle?>();
    try {
      unawaited(AppOpenAd.load(
        adUnitId: adUnitId,
        request: const AdRequest(nonPersonalizedAds: true),
        adLoadCallback: AppOpenAdLoadCallback(
          onAdLoaded: (ad) {
            if (completion.isCompleted) {
              unawaited(ad.dispose());
              return;
            }
            completion.complete(_GoogleAppOpenAdHandle(ad));
          },
          onAdFailedToLoad: (_) {
            if (!completion.isCompleted) completion.complete(null);
          },
        ),
      ).catchError((_) {
        if (!completion.isCompleted) completion.complete(null);
      }));
    } catch (_) {
      if (!completion.isCompleted) completion.complete(null);
    }
    return completion.future.timeout(
      const Duration(seconds: 65),
      onTimeout: () {
        if (!completion.isCompleted) completion.complete(null);
        return null;
      },
    );
  }
}

class _GoogleAppOpenAdHandle implements AppOpenAdHandle {
  final AppOpenAd _ad;
  bool _disposed = false;

  _GoogleAppOpenAdHandle(this._ad);

  @override
  Future<void> show({
    required VoidCallback onDismissed,
    required VoidCallback onFailedToShow,
  }) {
    _ad.fullScreenContentCallback = FullScreenContentCallback<AppOpenAd>(
      onAdDismissedFullScreenContent: (_) => onDismissed(),
      onAdFailedToShowFullScreenContent: (_, __) => onFailedToShow(),
    );
    return _ad.show();
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _ad.dispose();
  }
}

abstract interface class AppOpenLifecycle {
  Stream<AppState> get states;
  Future<void> startListening();
  Future<void> stopListening();
}

class GoogleAppOpenLifecycle implements AppOpenLifecycle {
  const GoogleAppOpenLifecycle();

  @override
  Stream<AppState> get states => AppStateEventNotifier.appStateStream;

  @override
  Future<void> startListening() => AppStateEventNotifier.startListening();

  @override
  Future<void> stopListening() => AppStateEventNotifier.stopListening();
}

class AppOpenAdController {
  static const maxCacheDuration = Duration(hours: 4);

  final AdsConsent consent;
  final AdRemovalService adRemoval;
  final AppOpenAdLoader loader;
  final AppOpenLifecycle lifecycle;
  final AppOpenAdUnitConfig adUnitConfig;
  final TargetPlatform? platformOverride;
  final bool? releaseModeOverride;
  final bool? webOverride;
  final DateTime Function() now;

  AppOpenAdController({
    AdsConsent? consent,
    AdRemovalService? adRemoval,
    this.loader = const GoogleAppOpenAdLoader(),
    this.lifecycle = const GoogleAppOpenLifecycle(),
    this.adUnitConfig = AppOpenAdUnitConfig.current,
    this.platformOverride,
    this.releaseModeOverride,
    this.webOverride,
    DateTime Function()? now,
  })  : consent = consent ?? AdsConsent.instance,
        adRemoval = adRemoval ?? AdRemovalService.instance,
        now = now ?? DateTime.now;

  AppOpenAdHandle? _ad;
  DateTime? _loadedAt;
  StreamSubscription<AppState>? _lifecycleSubscription;
  bool _started = false;
  bool _loading = false;
  bool _showing = false;
  bool _initialShowPending = false;
  bool _homeReady = false;
  bool _wentToBackground = false;

  Future<void> start({required bool showOnInitialLoad}) async {
    _initialShowPending |= showOnInitialLoad && !_homeReady;
    if (_started) {
      _syncConsent();
      return;
    }
    _started = true;
    consent.addListener(_syncConsent);
    adRemoval.addListener(_syncConsent);
    _lifecycleSubscription = lifecycle.states.listen(_onAppStateChanged);
    try {
      await lifecycle.startListening().timeout(const Duration(seconds: 3));
    } catch (_) {
      // Cold-start loading still works if lifecycle events are unavailable.
    }
    _syncConsent();
  }

  /// Defers a cold-start ad that has not begun showing yet.
  /// A loaded ad stays cached for the next foreground opportunity.
  void markHomeReady() {
    _homeReady = true;
    _initialShowPending = false;
  }

  void _syncConsent() {
    if (adRemoval.isOwned || !consent.canRequestAds) {
      _clearCachedAd();
      return;
    }
    unawaited(_load(showWhenLoaded: _initialShowPending));
  }

  void _onAppStateChanged(AppState state) {
    if (state == AppState.background) {
      _wentToBackground = true;
      return;
    }
    if (state != AppState.foreground || !_wentToBackground) return;
    _wentToBackground = false;
    _onForeground();
  }

  void _onForeground() {
    if (adRemoval.isOwned || !consent.canRequestAds || _showing) return;
    if (_hasValidAd) {
      unawaited(_show());
    } else {
      unawaited(_load(showWhenLoaded: false));
    }
  }

  bool get _hasValidAd {
    final loadedAt = _loadedAt;
    if (_ad == null || loadedAt == null) return false;
    if (now().difference(loadedAt) < maxCacheDuration) return true;
    _clearCachedAd();
    return false;
  }

  Future<void> _load({required bool showWhenLoaded}) async {
    _initialShowPending |= showWhenLoaded && !_homeReady;
    if (_loading ||
        _showing ||
        _hasValidAd ||
        adRemoval.isOwned ||
        !consent.canRequestAds) {
      return;
    }

    final adUnitId = adUnitConfig.resolve(
      platform: platformOverride,
      releaseMode: releaseModeOverride,
      web: webOverride,
    );
    if (adUnitId == null) {
      _initialShowPending = false;
      return;
    }

    _loading = true;
    if (kDebugMode) debugPrint('앱 오프닝 광고 로드 요청');
    final loaded = await loader.load(adUnitId: adUnitId);
    _loading = false;
    if (!_started || adRemoval.isOwned || !consent.canRequestAds) {
      await loaded?.dispose();
      return;
    }
    if (loaded == null) {
      if (kDebugMode) debugPrint('앱 오프닝 광고 로드 실패');
      _initialShowPending = false;
      return;
    }

    if (kDebugMode) debugPrint('앱 오프닝 광고 로드 완료');
    _ad = loaded;
    _loadedAt = now();
    if (_initialShowPending && !_homeReady) {
      _initialShowPending = false;
      await _show();
    }
  }

  Future<void> _show() async {
    if (_showing ||
        !_hasValidAd ||
        adRemoval.isOwned ||
        !consent.canRequestAds) {
      return;
    }
    final ad = _ad!;
    _ad = null;
    _loadedAt = null;
    _showing = true;
    var finished = false;

    void finish() {
      if (finished) return;
      finished = true;
      _showing = false;
      unawaited(ad.dispose());
      if (_started && !adRemoval.isOwned && consent.canRequestAds) {
        unawaited(_load(showWhenLoaded: false));
      }
    }

    try {
      await ad.show(onDismissed: finish, onFailedToShow: finish);
    } catch (_) {
      finish();
    }
  }

  void _clearCachedAd() {
    final ad = _ad;
    _ad = null;
    _loadedAt = null;
    if (ad != null) unawaited(ad.dispose());
  }

  Future<void> dispose() async {
    if (!_started) return;
    _started = false;
    consent.removeListener(_syncConsent);
    adRemoval.removeListener(_syncConsent);
    await _lifecycleSubscription?.cancel();
    _lifecycleSubscription = null;
    await lifecycle.stopListening();
    final ad = _ad;
    _ad = null;
    _loadedAt = null;
    await ad?.dispose();
  }
}
