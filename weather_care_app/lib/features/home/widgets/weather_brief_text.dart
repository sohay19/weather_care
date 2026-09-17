import 'dart:async';

import 'package:flutter/material.dart';

const _todayOnlyFallback = '오늘은 특별한 예보가 없으나, 외출 전에 시간별 예보를 확인해보세요';
const _legacyTodayOnlyFallback = '오늘은 외출 전에 시간별 예보를 확인하세요';

/// Only the server's time-sensitive summary expires here. Do not change raw
/// forecast/observation timestamps or try to infer a deadline from Korean text.
class WeatherBriefText extends StatefulWidget {
  final String text;
  final String? expiresAt;
  final TextStyle? style;
  final DateTime Function()? now;

  const WeatherBriefText({
    super.key,
    required this.text,
    this.expiresAt,
    this.style,
    this.now,
  });

  @override
  State<WeatherBriefText> createState() => _WeatherBriefTextState();
}

class _WeatherBriefTextState extends State<WeatherBriefText>
    with WidgetsBindingObserver {
  Timer? _timer;
  bool _expired = false;
  bool _invalid = false;
  bool _paused = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _check();
  }

  @override
  void didUpdateWidget(covariant WeatherBriefText oldWidget) {
    super.didUpdateWidget(oldWidget);
    _check();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _paused = state != AppLifecycleState.resumed;
    if (_paused) {
      _timer?.cancel();
    } else {
      setState(_check);
    }
  }

  void _check() {
    _timer?.cancel();
    final raw = widget.expiresAt;
    // Old servers and direct KMA responses have no expiry contract.
    if (raw == null) {
      _expired = false;
      _invalid = false;
      return;
    }
    final expiry = RegExp(r'T.*(?:Z|[+-]\d{2}:\d{2})$').hasMatch(raw)
        ? DateTime.tryParse(raw)
        : null;
    final now = (widget.now ?? DateTime.now)();
    _invalid = expiry == null;
    _expired = expiry == null || !now.isBefore(expiry);
    if (_expired || _paused) return;
    final remaining = expiry!.difference(now);
    // Recheck the wall clock at least once a minute, and at the exact deadline.
    final delay = remaining > const Duration(minutes: 1)
        ? const Duration(minutes: 1)
        : remaining;
    _timer = Timer(delay, () {
      if (mounted) setState(_check);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mentionsAnotherDay =
        ['내일', '모레', '글피', '다음 날'].any(widget.text.contains);
    final usesLegacyFallback = widget.text.trim() == _legacyTodayOnlyFallback;
    return Text(
      _expired
          ? '${_invalid ? '안내 시간을 확인하기 어려워요.' : '안내 시간이 지났어요.'} 화면을 아래로 당겨 최신 예보를 확인하세요.'
          : mentionsAnotherDay || usesLegacyFallback
              ? _todayOnlyFallback
              : widget.text,
      key: const ValueKey('main-weather-brief'),
      style: widget.style,
    );
  }
}
