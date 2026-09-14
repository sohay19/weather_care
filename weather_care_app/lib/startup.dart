import 'dart:async';

import 'package:flutter/material.dart';

import 'features/age_gate/age_gate_app.dart';
import 'services/age_eligibility.dart';

typedef AuthorizedAppInitializer = Future<Widget> Function();

class WeatherCareStartup extends StatefulWidget {
  final AgeEligibilityController ageController;
  final AuthorizedAppInitializer initializeAuthorizedApp;
  final VoidCallback? onAuthorizedAppMounted;

  const WeatherCareStartup({
    super.key,
    required this.ageController,
    required this.initializeAuthorizedApp,
    this.onAuthorizedAppMounted,
  });

  @override
  State<WeatherCareStartup> createState() => _WeatherCareStartupState();
}

class _WeatherCareStartupState extends State<WeatherCareStartup> {
  Widget? _authorizedApp;
  bool _startingServices = false;
  String? _serviceError;
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
    _generation += 1;
    setState(() {
      _authorizedApp = null;
      _serviceError = null;
      _startingServices = false;
    });
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
    );
  }

  @override
  void dispose() {
    widget.ageController.removeListener(_onAgeChanged);
    _generation += 1;
    super.dispose();
  }
}
