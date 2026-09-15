import 'dart:async';

import 'package:flutter/material.dart';

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
          _serviceError = '온라인 날씨 기능을 준비하지 못했어요. 연결 상태를 확인하고 다시 시도해주세요.';
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
      home: Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_serviceError == null)
                    const Column(
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 18),
                        Text(
                          '첫 실행은 권한 선택 시간을 제외하고 날씨 화면까지 최대 약 2분 걸릴 수 있어요.',
                          textAlign: TextAlign.center,
                        ),
                      ],
                    )
                  else ...[
                    const Icon(Icons.cloud_off_rounded, size: 42),
                    const SizedBox(height: 16),
                    Text(
                      _serviceError!,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      key: const ValueKey('startup-services-retry'),
                      onPressed: _startServices,
                      child: const Text('다시 시도'),
                    ),
                  ],
                ],
              ),
            ),
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
