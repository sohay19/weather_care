import 'dart:async';

import 'package:flutter/material.dart';

import 'features/age_gate/age_gate_app.dart';
import 'services/age_eligibility.dart';
import 'services/age_eligibility_store.dart';

typedef AuthorizedAppInitializer = Future<Widget> Function();
typedef Under14ServerDataRevoker = Future<void> Function();

class WeatherCareStartup extends StatefulWidget {
  final AgeEligibilityController ageController;
  final AuthorizedAppInitializer initializeAuthorizedApp;
  final VoidCallback? onAuthorizedAppMounted;
  final Under14ServerDataRevoker? revokeUnder14ServerData;

  const WeatherCareStartup({
    super.key,
    required this.ageController,
    required this.initializeAuthorizedApp,
    this.onAuthorizedAppMounted,
    this.revokeUnder14ServerData,
  });

  @override
  State<WeatherCareStartup> createState() => _WeatherCareStartupState();
}

class _WeatherCareStartupState extends State<WeatherCareStartup> {
  Widget? _authorizedApp;
  bool _startingServices = false;
  String? _serviceError;
  bool _revokingUnder14ServerData = false;
  bool _under14RevocationAttempted = false;
  String? _under14RevocationError;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    widget.ageController.addListener(_onAgeChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(() async {
        await widget.ageController.initialize();
        if (mounted) _onAgeChanged();
      }());
    });
  }

  @override
  void didUpdateWidget(covariant WeatherCareStartup oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.ageController == widget.ageController) return;
    oldWidget.ageController.removeListener(_onAgeChanged);
    widget.ageController.addListener(_onAgeChanged);
    _authorizedApp = null;
    _serviceError = null;
    _startingServices = false;
    _generation += 1;
    unawaited(() async {
      await widget.ageController.initialize();
      if (mounted) _onAgeChanged();
    }());
  }

  void _onAgeChanged() {
    if (!mounted) return;
    if (widget.ageController.sdkAccessAllowed) {
      _startAuthorizedServices();
      return;
    }
    final under14 = widget.ageController.ready &&
        widget.ageController.eligibility == AgeEligibility.under14;
    if (!under14) {
      _under14RevocationAttempted = false;
      _revokingUnder14ServerData = false;
      _under14RevocationError = null;
    }
    _generation += 1;
    setState(() {
      _authorizedApp = null;
      _serviceError = null;
      _startingServices = false;
    });
    if (under14 && !_under14RevocationAttempted) {
      _startUnder14Revocation();
    }
  }

  void _startUnder14Revocation() {
    if (_revokingUnder14ServerData) return;
    final revoker = widget.revokeUnder14ServerData;
    _under14RevocationAttempted = true;
    if (revoker == null) return;
    setState(() {
      _revokingUnder14ServerData = true;
      _under14RevocationError = null;
    });
    unawaited(() async {
      try {
        await revoker();
        if (!mounted ||
            widget.ageController.eligibility != AgeEligibility.under14) {
          return;
        }
        setState(() => _revokingUnder14ServerData = false);
      } catch (_) {
        if (!mounted ||
            widget.ageController.eligibility != AgeEligibility.under14) {
          return;
        }
        setState(() {
          _revokingUnder14ServerData = false;
          _under14RevocationError =
              '이전에 등록한 서버 알림을 정리하지 못했어요. 앱 기능은 차단되어 있지만 기존 알림이 도착할 수 있으니 다시 시도해주세요.';
        });
      }
    }());
  }

  void _startAuthorizedServices() {
    if (_startingServices || _authorizedApp != null) return;
    final generation = ++_generation;
    setState(() {
      _startingServices = true;
      _serviceError = null;
    });
    unawaited(() async {
      try {
        final app = await widget.initializeAuthorizedApp();
        if (!mounted || generation != _generation) return;
        setState(() {
          _authorizedApp = app;
          _startingServices = false;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && generation == _generation) {
            widget.onAuthorizedAppMounted?.call();
          }
        });
      } catch (_) {
        if (!mounted || generation != _generation) return;
        setState(() {
          _startingServices = false;
          _serviceError = '온라인 날씨 기능을 준비하지 못했어요. 연결 상태를 확인하고 다시 시도해주세요.';
        });
      }
    }());
  }

  @override
  Widget build(BuildContext context) {
    final app = _authorizedApp;
    if (app != null) return app;
    return AgeGateApp(
      controller: widget.ageController,
      startingServices: _startingServices,
      serviceError: _serviceError,
      onRetryServices: _startAuthorizedServices,
      revokingUnder14ServerData: _revokingUnder14ServerData,
      under14RevocationError: _under14RevocationError,
      onRetryUnder14Revocation: _startUnder14Revocation,
    );
  }

  @override
  void dispose() {
    widget.ageController.removeListener(_onAgeChanged);
    _generation += 1;
    super.dispose();
  }
}
