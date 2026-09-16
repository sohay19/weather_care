import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../services/ads_consent.dart';
import '../../services/native_ad_unit_config.dart';
import '../../theme/weather_theme.dart';

enum NativeAdCardSize { small, medium }

abstract interface class NativeAdCardHandle {
  Widget buildWidget();
  Future<void> dispose();
}

abstract interface class NativeAdCardLoader {
  Future<NativeAdCardHandle?> load({
    required String adUnitId,
    required NativeAdCardSize size,
  });
}

class GoogleNativeAdCardLoader implements NativeAdCardLoader {
  const GoogleNativeAdCardLoader();

  @override
  Future<NativeAdCardHandle?> load({
    required String adUnitId,
    required NativeAdCardSize size,
  }) async {
    final completion = Completer<NativeAdCardHandle?>();
    late final NativeAd nativeAd;
    nativeAd = NativeAd(
      adUnitId: adUnitId,
      request: const AdRequest(nonPersonalizedAds: true),
      listener: NativeAdListener(
        onAdLoaded: (ad) {
          final loaded = ad as NativeAd;
          if (completion.isCompleted) {
            unawaited(loaded.dispose());
            return;
          }
          completion.complete(_GoogleNativeAdCardHandle(loaded));
        },
        onAdFailedToLoad: (ad, _) {
          unawaited(ad.dispose());
          if (!completion.isCompleted) completion.complete(null);
        },
      ),
      nativeTemplateStyle: NativeTemplateStyle(
        templateType: size == NativeAdCardSize.medium
            ? TemplateType.medium
            : TemplateType.small,
        mainBackgroundColor: WeatherCareTheme.surface,
        cornerRadius: 22,
        callToActionTextStyle: NativeTemplateTextStyle(
          textColor: Colors.white,
          backgroundColor: WeatherCareTheme.primary,
          style: NativeTemplateFontStyle.bold,
          size: size == NativeAdCardSize.medium ? 15 : 13,
        ),
        primaryTextStyle: NativeTemplateTextStyle(
          textColor: WeatherCareTheme.textPrimary,
          backgroundColor: WeatherCareTheme.surface,
          style: NativeTemplateFontStyle.bold,
          size: size == NativeAdCardSize.medium ? 16 : 14,
        ),
        secondaryTextStyle: NativeTemplateTextStyle(
          textColor: WeatherCareTheme.textSecondary,
          backgroundColor: WeatherCareTheme.surface,
          style: NativeTemplateFontStyle.normal,
          size: size == NativeAdCardSize.medium ? 13 : 11,
        ),
        tertiaryTextStyle: NativeTemplateTextStyle(
          textColor: WeatherCareTheme.textSecondary,
          backgroundColor: WeatherCareTheme.surface,
          style: NativeTemplateFontStyle.normal,
          size: size == NativeAdCardSize.medium ? 12 : 10,
        ),
      ),
    );

    try {
      await nativeAd.load();
      return await completion.future.timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          if (!completion.isCompleted) completion.complete(null);
          unawaited(nativeAd.dispose());
          return null;
        },
      );
    } catch (_) {
      await nativeAd.dispose();
      if (!completion.isCompleted) completion.complete(null);
      return null;
    }
  }
}

class _GoogleNativeAdCardHandle implements NativeAdCardHandle {
  final NativeAd _ad;

  const _GoogleNativeAdCardHandle(this._ad);

  @override
  Widget buildWidget() => AdWidget(ad: _ad);

  @override
  Future<void> dispose() => _ad.dispose();
}

class ConsentAwareNativeAdCard extends StatefulWidget {
  final NativeAdPlacement placement;
  final NativeAdCardSize size;
  final AdsConsent? controller;
  final NativeAdCardLoader loader;
  final NativeAdUnitConfig adUnitConfig;
  final TargetPlatform? platformOverride;
  final bool? releaseModeOverride;
  final bool? webOverride;

  const ConsentAwareNativeAdCard({
    super.key,
    this.placement = NativeAdPlacement.week,
    this.size = NativeAdCardSize.small,
    this.controller,
    this.loader = const GoogleNativeAdCardLoader(),
    this.adUnitConfig = NativeAdUnitConfig.current,
    this.platformOverride,
    this.releaseModeOverride,
    this.webOverride,
  });

  @override
  State<ConsentAwareNativeAdCard> createState() =>
      _ConsentAwareNativeAdCardState();
}

class _ConsentAwareNativeAdCardState extends State<ConsentAwareNativeAdCard> {
  NativeAdCardHandle? _nativeAd;
  String? _loadedId;
  String? _loadingId;
  String? _failedId;
  int _generation = 0;

  AdsConsent get _controller => widget.controller ?? AdsConsent.instance;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onConsentChanged);
  }

  @override
  void didUpdateWidget(covariant ConsentAwareNativeAdCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldController = oldWidget.controller ?? AdsConsent.instance;
    if (oldController != _controller) {
      oldController.removeListener(_onConsentChanged);
      _controller.addListener(_onConsentChanged);
      _clearAd(notify: false);
    } else if (oldWidget.loader != widget.loader ||
        oldWidget.adUnitConfig != widget.adUnitConfig ||
        oldWidget.placement != widget.placement ||
        oldWidget.size != widget.size ||
        oldWidget.platformOverride != widget.platformOverride ||
        oldWidget.releaseModeOverride != widget.releaseModeOverride ||
        oldWidget.webOverride != widget.webOverride) {
      _clearAd(notify: false);
    }
  }

  void _onConsentChanged() {
    if (!_controller.canRequestAds) {
      _clearAd();
      return;
    }
    _failedId = null;
    if (mounted) setState(() {});
  }

  void _clearAd({bool notify = true}) {
    _generation += 1;
    _loadingId = null;
    _loadedId = null;
    _failedId = null;
    final previous = _nativeAd;
    _nativeAd = null;
    if (previous != null) unawaited(previous.dispose());
    if (notify && mounted) setState(() {});
  }

  void _scheduleLoad(String adUnitId) {
    if (_loadedId == adUnitId ||
        _loadingId == adUnitId ||
        _failedId == adUnitId) {
      return;
    }
    _loadingId = adUnitId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _loadingId != adUnitId) return;
      unawaited(_load(adUnitId));
    });
  }

  Future<void> _load(String adUnitId) async {
    if (!_controller.canRequestAds) {
      _loadingId = null;
      return;
    }

    final generation = ++_generation;
    final previous = _nativeAd;
    _nativeAd = null;
    _loadedId = null;
    if (previous != null) await previous.dispose();
    if (mounted) setState(() {});

    if (kDebugMode) debugPrint('네이티브 광고 로드 요청');
    final loaded = await widget.loader.load(
      adUnitId: adUnitId,
      size: widget.size,
    );
    if (!mounted ||
        generation != _generation ||
        !_controller.canRequestAds ||
        _loadingId != adUnitId) {
      if (loaded != null) await loaded.dispose();
      return;
    }

    setState(() {
      _loadingId = null;
      if (loaded == null) {
        if (kDebugMode) debugPrint('네이티브 광고 로드 실패');
        _failedId = adUnitId;
      } else {
        if (kDebugMode) debugPrint('네이티브 광고 로드 완료');
        _nativeAd = loaded;
        _loadedId = adUnitId;
        _failedId = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final adUnitId = widget.adUnitConfig.resolve(
      placement: widget.placement,
      platform: widget.platformOverride,
      releaseMode: widget.releaseModeOverride,
      web: widget.webOverride,
    );
    if (!_controller.canRequestAds || adUnitId == null) {
      return const SizedBox.shrink();
    }

    _scheduleLoad(adUnitId);
    final nativeAd = _nativeAd;
    if (nativeAd == null) {
      if (_failedId == adUnitId) return const SizedBox.shrink();
      return _NativeAdLoadingPlaceholder(widget.placement, widget.size);
    }

    return Semantics(
      container: true,
      label: '광고',
      child: _NativeAdFrame(
        frameKey: ValueKey('${widget.placement.name}-native-ad-card'),
        size: widget.size,
        decoration: WeatherCareTheme.surfaceDecoration(radius: 22),
        child: nativeAd.buildWidget(),
      ),
    );
  }

  @override
  void dispose() {
    _controller.removeListener(_onConsentChanged);
    _generation += 1;
    final nativeAd = _nativeAd;
    if (nativeAd != null) unawaited(nativeAd.dispose());
    super.dispose();
  }
}

class _NativeAdLoadingPlaceholder extends StatelessWidget {
  final NativeAdPlacement placement;
  final NativeAdCardSize size;

  const _NativeAdLoadingPlaceholder(this.placement, this.size);

  @override
  Widget build(BuildContext context) {
    return _NativeAdFrame(
      frameKey: ValueKey('${placement.name}-native-ad-placeholder'),
      size: size,
      decoration: BoxDecoration(
        color: WeatherCareTheme.surfaceSubtle,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: WeatherCareTheme.outline),
      ),
      child: Center(
        child: Text(
          '광고를 불러오고 있어요',
          style: WeatherCareTheme.microTextStyle,
        ),
      ),
    );
  }
}

class _NativeAdFrame extends StatelessWidget {
  final Key frameKey;
  final NativeAdCardSize size;
  final Decoration decoration;
  final Widget child;

  const _NativeAdFrame({
    required this.frameKey,
    required this.size,
    required this.decoration,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.constrainWidth(400);
        final height = switch (size) {
          // Google의 소형 네이티브 템플릿은 Android와 iOS 모두 4:1이다.
          // 템플릿보다 높은 고정 영역을 만들면 내용이 위로 치우쳐 보인다.
          NativeAdCardSize.small => width / 4,
          NativeAdCardSize.medium => 360.0,
        };
        return Center(
          child: Container(
            key: frameKey,
            width: width,
            height: height,
            clipBehavior: Clip.antiAlias,
            decoration: decoration,
            child: child,
          ),
        );
      },
    );
  }
}
