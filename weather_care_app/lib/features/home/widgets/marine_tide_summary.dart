import 'package:flutter/material.dart';

import '../../../services/api_client.dart';
import '../../../services/kma_grid.dart';
import '../../../theme/weather_theme.dart';

/// 다른 바다 항목의 선택과 독립적으로 오늘의 조석예보를 표시한다.
class MarineTideSummary extends StatefulWidget {
  final ApiClient? client;
  final KmaGrid? grid;
  final Map<String, dynamic>? group;
  final bool loadingCatalog;
  final DateTime? now;

  const MarineTideSummary(
      {super.key,
      required this.client,
      required this.grid,
      required this.group,
      required this.loadingCatalog,
      this.now});

  @override
  State<MarineTideSummary> createState() => _MarineTideSummaryState();
}

class _MarineTideSummaryState extends State<MarineTideSummary> {
  String? _targetId;
  List<Map<String, dynamic>> _records = [];
  bool _loading = false;
  String? _error;
  int _request = 0;

  List<Map<String, dynamic>> get _targets =>
      (widget.group?['targets'] as List? ?? [])
          .whereType<Map>()
          .map((target) => Map<String, dynamic>.from(target))
          .toList();

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
        widget.group != oldWidget.group) {
      _load();
    }
  }

  Future<void> _load([String? targetId]) async {
    final request = ++_request;
    final targets = _targets;
    final selected = targets
            .where((target) => target['id'] == (targetId ?? _targetId))
            .firstOrNull ??
        targets.firstOrNull;
    final client = widget.client;
    final grid = widget.grid;
    setState(() {
      _targetId = selected?['id'] as String?;
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
    } catch (_) {
      if (!mounted || request != _request) return;
      setState(() {
        _loading = false;
        _error = '만조·간조 자료를 불러오지 못했어요.';
      });
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
    if (_loading || widget.loadingCatalog) return null;
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
    if (_loading || widget.loadingCatalog) return '--:--';
    final times = _times(high);
    if (times.isEmpty) return '--:--';
    return _clock(
        times.where((time) => !time.isBefore(_now)).firstOrNull ?? times.last);
  }

  void _showDetails() {
    showDialog<void>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
              builder: (context, update) => AlertDialog(
                title: const Text('만조·간조 안내'),
                content: SizedBox(
                    width: 360,
                    child: SingleChildScrollView(
                        child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('만조는 바닷물 높이가 가장 높아질 때, 간조는 가장 낮아질 때예요. '
                            '국립해양조사원의 선택한 예보지점 기준 시각이며, 현재 격자 전체의 값은 아니에요.'),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          key: ValueKey('marine-tide-target-$_targetId'),
                          initialValue: _targetId,
                          isExpanded: true,
                          decoration: const InputDecoration(
                              labelText: '기준 관측소',
                              border: OutlineInputBorder()),
                          hint: const Text('수집된 관측소 없음'),
                          items: [
                            for (final target in _targets)
                              DropdownMenuItem(
                                  value: '${target['id']}',
                                  child: Text(
                                      '${target['name']} (${target['id']})',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis))
                          ],
                          onChanged: _loading || _targets.isEmpty
                              ? null
                              : (id) async {
                                  final pending = _load(id);
                                  update(() {});
                                  await pending;
                                  if (dialogContext.mounted) update(() {});
                                },
                        ),
                        const SizedBox(height: 12),
                        Text(
                            '${_now.year}-${_now.month.toString().padLeft(2, '0')}-'
                            '${_now.day.toString().padLeft(2, '0')} · 한국 표준시'),
                        if (_error == null && _availabilityMessage != null) ...[
                          const SizedBox(height: 8),
                          Text(_availabilityMessage!),
                        ],
                        const SizedBox(height: 8),
                        if (_loading || widget.loadingCatalog)
                          const Text('만조·간조 자료를 불러오는 중이에요.')
                        else if (_error != null) ...[
                          Text(_error!),
                          TextButton(
                              onPressed: () async {
                                final pending = _load();
                                update(() {});
                                await pending;
                                if (dialogContext.mounted) update(() {});
                              },
                              child: const Text('다시 시도')),
                        ] else ...[
                          for (final high in [true, false])
                            Text('${high ? '만조' : '간조'}: '
                                '${_times(high).isEmpty ? '오늘 자료 없음' : _times(high).map(_clock).join(' / ')}'),
                        ],
                        const SizedBox(height: 12),
                        const Text('상단에는 오늘 남은 첫 만조·간조 시각을 각각 표시해요. '
                            '모두 지난 경우에는 오늘의 마지막 시각을 표시해요. '
                            '오늘 자료가 없거나 극치 구분을 확인할 수 없으면 --:--로 표시해요.'),
                      ],
                    ))),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: const Text('닫기'))
                ],
              ),
            ));
  }

  @override
  Widget build(BuildContext context) {
    final palette = WeatherCareTheme.of(context);
    const style = TextStyle(fontSize: 18, fontWeight: FontWeight.w700);
    final summary = Row(key: const ValueKey('marine-tide-summary'), children: [
      Expanded(
          child: Center(
              child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.arrow_upward_rounded,
                        size: 22, color: palette.primaryDeep),
                    const SizedBox(width: 10),
                    Text('만조 ${_displayTime(true)}', style: style),
                    const SizedBox(width: 28),
                    Icon(Icons.arrow_downward_rounded,
                        size: 22, color: palette.primaryDeep),
                    const SizedBox(width: 10),
                    Text('간조 ${_displayTime(false)}', style: style),
                  ])))),
      IconButton(
          key: const ValueKey('marine-tide-info'),
          tooltip: '만조·간조 설명과 기준 관측소',
          onPressed: _showDetails,
          iconSize: 18,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints.tightFor(width: 32, height: 32),
          style: const ButtonStyle(
              tapTargetSize: MaterialTapTargetSize.shrinkWrap),
          icon: Icon(Icons.error_outline_rounded, color: palette.primaryDeep)),
    ]);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      summary,
      if (_availabilityMessage != null) ...[
        const SizedBox(height: 8),
        Text(_availabilityMessage!,
            key: const ValueKey('marine-tide-status'),
            style: Theme.of(context).textTheme.bodySmall),
      ],
    ]);
  }
}
