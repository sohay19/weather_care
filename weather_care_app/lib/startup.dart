import 'dart:async';

import 'package:flutter/material.dart';

import 'features/home/widgets/weather_status_view.dart';
import 'theme/weather_theme.dart';

typedef WeatherCareAppInitializer = Future<Widget> Function();

class WeatherCareStartup extends StatefulWidget {
  final WeatherCareAppInitializer initializeApp;
  final VoidCallback? onAppMounted;

  const WeatherCareStartup({
    super.key,
    required this.initializeApp,
    this.onAppMounted,
  });

  @override
  State<WeatherCareStartup> createState() => _WeatherCareStartupState();
}

class _WeatherCareStartupState extends State<WeatherCareStartup> {
  Widget? _app;
  bool _startingServices = false;
  String? _serviceError;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _startServices();
    });
  }

  void _startServices() {
    if (_startingServices || _app != null) return;
    final generation = ++_generation;
    setState(() {
      _startingServices = true;
      _serviceError = null;
    });
    unawaited(() async {
      try {
        final app = await widget.initializeApp();
        if (!mounted || generation != _generation) return;
        setState(() {
          _app = app;
          _startingServices = false;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && generation == _generation) {
            widget.onAppMounted?.call();
          }
        });
      } catch (_) {
        if (!mounted || generation != _generation) return;
        setState(() {
          _startingServices = false;
          _serviceError = '온라인 날씨 기능을 준비하지 못했어요.\n연결 상태를 확인하고 다시 시도해주세요.';
        });
      }
    }());
  }

  @override
  Widget build(BuildContext context) {
    final app = _app;
    if (app != null) return app;
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: WeatherCareTheme.light(),
      home: Scaffold(
        body: SafeArea(
          child: WeatherStatusView(
            viewKey: 'startup-services',
            loading: _serviceError == null,
            offline: false,
            title: _serviceError == null ? '앱을 초기화 하고 있어요' : null,
            message: _serviceError ?? '앱에 필요한 날씨·알림 서비스를 준비하고 있어요.',
            onRetry: () async => _startServices(),
            primaryActionLabel: _serviceError == null ? null : '다시 시도',
            onPrimaryAction:
                _serviceError == null ? null : () async => _startServices(),
            primaryActionKey: const ValueKey('startup-services-retry'),
            primaryActionIcon: Icons.refresh_rounded,
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _generation += 1;
    super.dispose();
  }
}
