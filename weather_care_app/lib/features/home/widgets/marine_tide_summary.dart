import 'package:flutter/material.dart';

import '../../../services/api_client.dart';
import '../../../services/kma_grid.dart';
import '../../../theme/weather_theme.dart';
import 'data_range_tile.dart';

/// 조위 패널에서 선택한 관측소의 오늘 만조·간조를 표시한다.
class MarineTideSummary extends StatefulWidget {
  final ApiClient? client;
  final KmaGrid? grid;
  final DateTime? now;
  final String? selectedId;
  final VoidCallback? onLoaded;

  const MarineTideSummary(
      {super.key,
      required this.client,
      required this.grid,
      this.now,
      required this.selectedId,
      this.onLoaded});

  @override
  State<MarineTideSummary> createState() => _MarineTideSummaryState();
}

class _MarineTideSummaryState extends State<MarineTideSummary> {
  String? _targetId;
  List<Map<String, dynamic>> _records = [];
  bool _loading = false;
  String? _error;
  int _request = 0;

  DateTime get _now {
    final time =
        (widget.now ?? DateTime.now()).toUtc().add(const Duration(hours: 9));
    return DateTime.utc(
        time.year, time.month, time.day, time.hour, time.minute);
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant MarineTideSummary oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.client != oldWidget.client ||
        widget.grid != oldWidget.grid ||
        widget.selectedId != oldWidget.selectedId ||
        widget.now != oldWidget.now) {
      if (widget.grid != oldWidget.grid) _targetId = null;
      _load();
    }
  }

  Future<void> _load() async {
    final request = ++_request;
    final client = widget.client;
    final grid = widget.grid;
    setState(() {
      _targetId = widget.selectedId;
      _records = [];
      _error = null;
      _loading = client != null && grid != null && _targetId != null;
    });
    if (!_loading) return;
    try {
      final data = await client!.get('/api/v1/weather/extra/records', query: {
        'nx': '${grid!.nx}',
        'ny': '${grid.ny}',
        'source': 'KHOA_TIDE_EXTREME',
        'targetId': _targetId!,
      });
      if (!mounted || request != _request) return;
      setState(() {
        _records = (data['records'] as List? ?? [])
            .whereType<Map>()
            .map((record) => Map<String, dynamic>.from(record))
            .toList();
        _loading = false;
      });
      widget.onLoaded?.call();
    } catch (_) {
      if (!mounted || request != _request) return;
      setState(() {
        _loading = false;
        _error = '만조·간조 자료를 불러오지 못했어요.';
      });
      widget.onLoaded?.call();
    }
  }

  DateTime? _recordTime(Object? value) {
    final raw = '$value';
    if (!RegExp(r'[T ]\d{2}:\d{2}').hasMatch(raw)) return null;
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return null;
    final korea = parsed.isUtc ? parsed.add(const Duration(hours: 9)) : parsed;
    return DateTime.utc(
        korea.year, korea.month, korea.day, korea.hour, korea.minute);
  }

  String _date(DateTime time) => '${time.year}-'
      '${time.month.toString().padLeft(2, '0')}-${time.day.toString().padLeft(2, '0')}';

  String? get _availabilityMessage {
    if (_loading) return null;
    if (_error != null) return _error;
    if (_targetId == null) return '만조·간조를 조회할 관측소가 없어요.';
    final high = _times(true);
    final low = _times(false);
    if (high.isNotEmpty && low.isNotEmpty) return null;
    if (high.isNotEmpty || low.isNotEmpty) {
      return '오늘 ${high.isEmpty ? '만조' : '간조'} 시각이 제공되지 않았어요.';
    }
    final times = _records
        .map((record) => _recordTime(record['time']))
        .whereType<DateTime>()
        .toList()
      ..sort();
    if (times.isEmpty) return '현재 받은 만조·간조 자료가 없어요.';
    if (!times.any((time) => _date(time) == _date(_now))) {
      return '오늘 예보가 없어요. 자료 기준일: ${_date(times.last)}';
    }
    return '오늘 자료에서 만조·간조 구분을 확인할 수 없어요.';
  }

  List<DateTime> _times(bool high) {
    final today = _now;
    final times = <DateTime>{};
    for (final record in _records) {
      final values = record['values'];
      if (values is! Map) continue;
      // 제공처 극치구분: 1/3은 오전/오후 고조, 2/4는 오전/오후 저조.
      final type = '${values['extremeType']}';
      if (!(high ? const ['1', '3'] : const ['2', '4']).contains(type)) {
        continue;
      }
      final korea = _recordTime(record['time']);
      if (korea == null) continue;
      if (korea.year == today.year &&
          korea.month == today.month &&
          korea.day == today.day) {
        times.add(DateTime.utc(
            korea.year, korea.month, korea.day, korea.hour, korea.minute));
      }
    }
    return times.toList()..sort();
  }

  String _clock(DateTime time) =>
      '${time.hour}:${time.minute.toString().padLeft(2, '0')}';

  String _displayTime(bool high) {
    if (_loading) return '--:--';
    final times = _times(high);
    if (times.isEmpty) return '--:--';
    return _clock(
        times.where((time) => !time.isBefore(_now)).firstOrNull ?? times.last);
  }

  @override
  Widget build(BuildContext context) {
    final palette = WeatherCareTheme.of(context);
    final summary = Container(
        key: const ValueKey('marine-tide-summary'),
        decoration: BoxDecoration(
            color: DataRangeTile.backgroundColor(palette),
            borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          Expanded(
              child: DataRangeTile(
                  key: const ValueKey('marine-tide-high'),
                  icon: Icons.arrow_upward_rounded,
                  label: '만조',
                  value: _displayTime(true))),
          Text('·',
              style: palette.microTextStyle.copyWith(
                  color: palette.primaryDeep, fontWeight: FontWeight.w700)),
          Expanded(
              child: DataRangeTile(
                  key: const ValueKey('marine-tide-low'),
                  icon: Icons.arrow_downward_rounded,
                  label: '간조',
                  value: _displayTime(false))),
        ]));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      summary,
      if (_availabilityMessage != null) ...[
        const SizedBox(height: 8),
        Text(_availabilityMessage!,
            key: const ValueKey('marine-tide-status'),
            style: Theme.of(context).textTheme.bodySmall),
        if (_error != null)
          TextButton(onPressed: _load, child: const Text('만조·간조 다시 시도')),
      ],
    ]);
  }
}
