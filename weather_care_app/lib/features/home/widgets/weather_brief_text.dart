import 'dart:async';

import 'package:flutter/material.dart';

import '../../../models/briefing_time.dart';
import '../../../models/weather.dart';
import '../weather_data_phase.dart';

const _todayOnlyFallback = '오늘은 특별한 예보가 없으나, 외출 전에 시간별 예보를 확인해보세요';
const _legacyTodayOnlyFallback = '오늘은 외출 전에 시간별 예보를 확인하세요';

/// Only the server's time-sensitive summary expires here. Do not change raw
/// forecast/observation timestamps or try to infer a deadline from Korean text.
class WeatherBriefText extends StatefulWidget {
  final String text;
  final String? expiresAt;
  final List<BriefingTimelineEntry> timeline;
  final String? generatedAt;
  final DateTime? receivedAt;
  final TextStyle? style;
  final DateTime Function()? now;

  const WeatherBriefText({
    super.key,
    required this.text,
    this.expiresAt,
    this.timeline = const [],
    this.generatedAt,
    this.receivedAt,
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
  String? _timelineText;

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
    final now = responseNow(
      (widget.now ?? DateTime.now)(),
      generatedAt: widget.generatedAt,
      receivedAt: widget.receivedAt,
    );
    if (widget.timeline.isNotEmpty) {
      final valid = <({
        BriefingTimelineEntry entry,
        DateTime from,
        DateTime until,
      })>[];
      for (final entry in widget.timeline) {
        final from = _zonedTime(entry.validFrom);
        final until = _zonedTime(entry.validUntil);
        if (from != null && until != null && from.isBefore(until)) {
          valid.add((entry: entry, from: from, until: until));
        }
      }
      ({
        BriefingTimelineEntry entry,
        DateTime from,
        DateTime until,
      })? active;
      for (final value in valid) {
        if (!now.isBefore(value.from) && now.isBefore(value.until)) {
          active = value;
          break;
        }
      }
      _invalid = valid.isEmpty;
      _expired = active == null;
      _timelineText = active?.entry.copy.medium;
      final nextBoundary = active?.until ??
          valid
              .map((value) => value.from)
              .where((value) => value.isAfter(now))
              .fold<DateTime?>(
                  null,
                  (closest, value) => closest == null || value.isBefore(closest)
                      ? value
                      : closest);
      _schedule(now, nextBoundary);
      return;
    }
    _timelineText = null;
    final raw = widget.expiresAt;
    // Old servers and direct KMA responses have no expiry contract.
    if (raw == null) {
      _expired = false;
      _invalid = false;
      return;
    }
    final expiry = _zonedTime(raw);
    _invalid = expiry == null;
    _expired = expiry == null || !now.isBefore(expiry);
    _schedule(now, _expired ? null : expiry);
  }

  void _schedule(DateTime now, DateTime? boundary) {
    if (boundary == null || _paused) return;
    final remaining = boundary.difference(now);
    if (remaining <= Duration.zero) return;
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
    final phase = WeatherDataPhaseScope.of(context);
    final mentionsAnotherDay =
        ['내일', '모레', '글피', '다음 날'].any(widget.text.contains);
    final usesLegacyFallback = widget.text.trim() == _legacyTodayOnlyFallback;
    return Text(
      phase == WeatherDataPhase.loading
          ? phase.missingText()
          : _expired
              ? '${_invalid ? '안내 시간을 확인하기 어려워요.' : '최신 날씨를 확인해 주세요.'}${_invalid ? ' 화면을 아래로 당겨 다시 확인하세요.' : ''}'
              : _timelineText != null && _timelineText!.isNotEmpty
                  ? _timelineText!
                  : mentionsAnotherDay || usesLegacyFallback
                      ? _todayOnlyFallback
                      : widget.text,
      key: const ValueKey('main-weather-brief'),
      style: widget.style,
    );
  }
}

DateTime? _zonedTime(String? value) {
  if (value == null || !RegExp(r'T.*(?:Z|[+-]\d{2}:\d{2})$').hasMatch(value)) {
    return null;
  }
  return DateTime.tryParse(value);
}
