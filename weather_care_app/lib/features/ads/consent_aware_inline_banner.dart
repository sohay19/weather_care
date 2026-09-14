import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../services/ads_consent.dart';
import '../../services/banner_ad_unit_config.dart';
import '../../theme/weather_theme.dart';

abstract interface class InlineBannerHandle {
  int get width;
  int get height;
  Widget buildWidget();
  Future<void> dispose();
}

abstract interface class InlineBannerLoader {
  Future<InlineBannerHandle?> load({
    required int width,
    required String adUnitId,
  });
}

class GoogleInlineBannerLoader implements InlineBannerLoader {
  const GoogleInlineBannerLoader();

  @override
  Future<InlineBannerHandle?> load({
    required int width,
    required String adUnitId,
  }) async {
    if (width <= 0) return null;

    final completion = Completer<InlineBannerHandle?>();
    final requestedSize =
        AdSize.getCurrentOrientationInlineAdaptiveBannerAdSize(width);
    late final BannerAd banner;
    banner = BannerAd(
      adUnitId: adUnitId,
      size: requestedSize,
      // The product policy is non-personalized advertising only.
      request: const AdRequest(nonPersonalizedAds: true),
      listener: BannerAdListener(
        onAdLoaded: (ad) async {
          try {
            final loaded = ad as BannerAd;
            if (completion.isCompleted) {
              await loaded.dispose();
              return;
            }
            final actualSize = await loaded.getPlatformAdSize();
            if (actualSize == null) {
              await loaded.dispose();
              if (!completion.isCompleted) completion.complete(null);
              return;
            }
            if (!completion.isCompleted) {
              completion
                  .complete(_GoogleInlineBannerHandle(loaded, actualSize));
            }
          } catch (_) {
            await ad.dispose();
            if (!completion.isCompleted) completion.complete(null);
          }
        },
        onAdFailedToLoad: (ad, _) async {
          await ad.dispose();
          if (!completion.isCompleted) completion.complete(null);
        },
      ),
    );

    try {
      await banner.load();
      return await completion.future.timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          unawaited(banner.dispose());
          return null;
        },
      );
    } catch (_) {
      await banner.dispose();
      if (!completion.isCompleted) completion.complete(null);
      return null;
    }
  }
}

class _GoogleInlineBannerHandle implements InlineBannerHandle {
  final BannerAd _ad;
  final AdSize _size;

  const _GoogleInlineBannerHandle(this._ad, this._size);

  @override
  int get width => _size.width;

  @override
  int get height => _size.height;

  @override
  Widget buildWidget() => AdWidget(ad: _ad);

  @override
  Future<void> dispose() => _ad.dispose();
}

class ConsentAwareInlineBanner extends StatefulWidget {
  final AdsConsent? controller;
  final InlineBannerLoader loader;
  final BannerAdUnitConfig adUnitConfig;
  final TargetPlatform? platformOverride;
  final bool? releaseModeOverride;
  final bool? webOverride;

  const ConsentAwareInlineBanner({
    super.key,
    this.controller,
    this.loader = const GoogleInlineBannerLoader(),
    this.adUnitConfig = BannerAdUnitConfig.current,
    this.platformOverride,
    this.releaseModeOverride,
    this.webOverride,
  });

  @override
  State<ConsentAwareInlineBanner> createState() =>
      _ConsentAwareInlineBannerState();
}

class _ConsentAwareInlineBannerState extends State<ConsentAwareInlineBanner> {
  InlineBannerHandle? _banner;
  String? _loadedKey;
  String? _loadingKey;
  String? _failedKey;
  int _generation = 0;

  AdsConsent get _controller => widget.controller ?? AdsConsent.instance;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onConsentChanged);
  }

  @override
  void didUpdateWidget(covariant ConsentAwareInlineBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldController = oldWidget.controller ?? AdsConsent.instance;
    if (oldController != _controller) {
      oldController.removeListener(_onConsentChanged);
      _controller.addListener(_onConsentChanged);
      _clearBanner(notify: false);
    } else if (oldWidget.loader != widget.loader ||
        oldWidget.adUnitConfig != widget.adUnitConfig ||
        oldWidget.platformOverride != widget.platformOverride ||
        oldWidget.releaseModeOverride != widget.releaseModeOverride ||
        oldWidget.webOverride != widget.webOverride) {
      _clearBanner(notify: false);
    }
  }

  void _onConsentChanged() {
    if (!_controller.canRequestAds) {
      _clearBanner();
      return;
    }
    _failedKey = null;
    if (mounted) setState(() {});
  }

  void _clearBanner({bool notify = true}) {
    _generation += 1;
    _loadingKey = null;
    _loadedKey = null;
    _failedKey = null;
    final previous = _banner;
    _banner = null;
    if (previous != null) unawaited(previous.dispose());
    if (notify && mounted) setState(() {});
  }

  void _scheduleLoad(int width, String adUnitId) {
    final requestKey = '$width:$adUnitId';
    if (_loadedKey == requestKey ||
        _loadingKey == requestKey ||
        _failedKey == requestKey) {
      return;
    }
    _loadingKey = requestKey;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _loadingKey != requestKey) return;
      unawaited(_load(width, adUnitId, requestKey));
    });
  }

  Future<void> _load(
    int width,
    String adUnitId,
    String requestKey,
  ) async {
    if (!_controller.canRequestAds) {
      _loadingKey = null;
      return;
    }

    final generation = ++_generation;
    final previous = _banner;
    _banner = null;
    _loadedKey = null;
    if (previous != null) await previous.dispose();
    if (mounted) setState(() {});

    if (kDebugMode) debugPrint('배너 광고 로드 요청');
    final loaded = await widget.loader.load(
      width: width,
      adUnitId: adUnitId,
    );
    if (!mounted ||
        generation != _generation ||
        !_controller.canRequestAds ||
        _loadingKey != requestKey) {
      if (loaded != null) await loaded.dispose();
      return;
    }

    setState(() {
      _loadingKey = null;
      if (loaded == null) {
        if (kDebugMode) debugPrint('배너 광고 로드 실패');
        _failedKey = requestKey;
      } else {
        if (kDebugMode) debugPrint('배너 광고 로드 완료');
        _banner = loaded;
        _loadedKey = requestKey;
        _failedKey = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final adUnitId = widget.adUnitConfig.resolve(
      platform: widget.platformOverride,
      releaseMode: widget.releaseModeOverride,
      web: widget.webOverride,
    );
    if (!_controller.canRequestAds || adUnitId == null) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(builder: (context, constraints) {
      final width = constraints.maxWidth.floor();
      if (width > 0) _scheduleLoad(width, adUnitId);
      final banner = _banner;
      if (banner == null) return const SizedBox.shrink();

      return Semantics(
        container: true,
        label: '광고',
        child: Column(
          key: const ValueKey('week-inline-banner'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '광고',
              style: WeatherCareTheme.microTextStyle.copyWith(fontSize: 10),
            ),
            const SizedBox(height: 4),
            Center(
              child: SizedBox(
                width: banner.width.toDouble(),
                height: banner.height.toDouble(),
                child: banner.buildWidget(),
              ),
            ),
          ],
        ),
      );
    });
  }

  @override
  void dispose() {
    _controller.removeListener(_onConsentChanged);
    _generation += 1;
    final banner = _banner;
    if (banner != null) unawaited(banner.dispose());
    super.dispose();
  }
}
