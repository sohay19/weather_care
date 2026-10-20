import 'dart:async';

import 'package:flutter/material.dart';

import '../../../services/api_client.dart';
import '../../../services/kma_grid.dart';
import '../../../theme/weather_theme.dart';

class LightningDetailsCard extends StatefulWidget {
  final ApiClient? client;
  final KmaGrid? grid;
  final bool active;
  final bool focused;
  final int refreshId;
  final VoidCallback? onLoaded;
  final DateTime Function()? clock;

  const LightningDetailsCard(
      {super.key,
      required this.client,
      required this.grid,
      required this.active,
      this.focused = false,
      this.refreshId = 0,
      this.onLoaded,
      this.clock});

  @override
  State<LightningDetailsCard> createState() => _LightningDetailsCardState();
}

class _LightningDetailsCardState extends State<LightningDetailsCard>
    with WidgetsBindingObserver {
  Map<String, dynamic>? _data;
  bool _failed = false;
  bool _loading = false;
  bool _foreground = true;
  Timer? _timer;
  int _request = 0;

  DateTime get _now => (widget.clock?.call() ?? DateTime.now()).toUtc();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.active) _load();
  }

  @override
  void didUpdateWidget(covariant LightningDetailsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final changed =
        oldWidget.grid != widget.grid || oldWidget.client != widget.client;
    if (changed || !widget.active) {
      ++_request;
      _timer?.cancel();
      _loading = false;
      if (changed) {
        _data = null;
        _failed = false;
      }
    }
    if (widget.active &&
        (changed ||
            !oldWidget.active ||
            oldWidget.refreshId != widget.refreshId)) {
      _load();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (!_foreground) {
      _timer?.cancel();
    } else if (widget.active) {
      _load();
    }
  }

  @override
  void dispose() {
    ++_request;
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  DateTime? _time(Object? value) =>
      value is String ? DateTime.tryParse(value)?.toUtc() : null;

  List<DateTime> get _observations {
    final raw = _data?['observations'];
    if (raw is! List) return [];
    return raw.map(_time).whereType<DateTime>().where((time) {
      final age = _now.difference(time);
      return !age.isNegative && age < const Duration(minutes: 30);
    }).toList()
      ..sort((a, b) => b.compareTo(a));
  }

  Future<void> _load() async {
    _timer?.cancel();
    final client = widget.client;
    final grid = widget.grid;
    if (client == null || grid == null || !widget.active || !_foreground) {
      return;
    }
    final request = ++_request;
    setState(() => _loading = true);
    try {
      final data = await client.get('/api/v1/weather/extra/lightning',
          query: {'nx': '${grid.nx}', 'ny': '${grid.ny}'});
      if (!mounted || request != _request) return;
      if (!['AVAILABLE', 'FAILED', 'STALE', 'UNAVAILABLE']
          .contains(data['status'])) {
        throw const FormatException('낙뢰 자료 상태 오류');
      }
      setState(() {
        _data = data;
        _failed = false;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || request != _request) return;
      setState(() {
        _data = null;
        _failed = true;
        _loading = false;
      });
    }
    if (!mounted || request != _request || !widget.active || !_foreground) {
      return;
    }
    var delay = const Duration(minutes: 1);
    final deadlines = [
      _time(_data?['feedExpiresAt']),
      ..._observations.map((time) => time.add(const Duration(minutes: 30))),
    ].whereType<DateTime>();
    for (final deadline in deadlines) {
      final remaining = deadline.difference(_now);
      if (remaining > Duration.zero && remaining < delay) delay = remaining;
    }
    _timer = Timer(delay, () {
      if (!mounted) return;
      setState(() {}); // 응답 대기 중에도 관측·수집의 만료를 즉시 적용한다.
      _load();
    });
    widget.onLoaded?.call();
  }

  String _label(DateTime time) {
    final local = time.add(const Duration(hours: 9));
    String two(int n) => n.toString().padLeft(2, '0');
    return '${local.month}월 ${local.day}일 ${two(local.hour)}:${two(local.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final palette = WeatherCareTheme.of(context);
    final feedExpiry = _time(_data?['feedExpiresAt']);
    final available = !_failed &&
        _data?['status'] == 'AVAILABLE' &&
        feedExpiry != null &&
        _now.isBefore(feedExpiry);
    final observations = available ? _observations : <DateTime>[];
    final failed = _failed ||
        (_data != null && !available) ||
        (widget.focused && (widget.client == null || widget.grid == null));
    if (!failed && observations.isEmpty && !widget.focused) {
      return const SizedBox.shrink();
    }
    final checkedAt = _time(_data?['checkedAt']);
    return Card(
      key: const ValueKey('lightning-details-card'),
      child: ExpansionTile(
        key:
            ValueKey('lightning-details-${widget.focused}-${widget.refreshId}'),
        initiallyExpanded: widget.focused,
        leading: Icon(Icons.bolt_rounded, color: palette.attentionDeep),
        title: const Text('낙뢰 관측'),
        subtitle: Text(failed
            ? '낙뢰 자료를 확인하지 못했어요'
            : observations.isNotEmpty
                ? '최근 30분 이내 낙뢰가 관측됐어요'
                : _loading
                    ? '낙뢰 자료를 확인하고 있어요'
                    : '표시할 최근 낙뢰 관측이 없어요'),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (observations.isNotEmpty) ...[
            Text('관측 지역: 선택 지역의 기상 격자'),
            Text('최근 발생: ${_label(observations.first)} (한국시간)'),
            Text('최근 30분 수집 자료: ${observations.length}회'),
            const SizedBox(height: 8),
            const Text(
                '안전한 건물이나 자동차 안으로 이동하세요. 마지막 번개·천둥 후 최소 30분은 안전한 장소에서 기다리세요.'),
          ],
          if (checkedAt != null) Text('자료 확인: ${_label(checkedAt)} (한국시간)'),
          if (failed) ...[
            Text(_data?['status'] == 'STALE' ||
                    (_data?['status'] == 'AVAILABLE' && !available)
                ? '최신 자료 갱신이 지연되고 있어요. 오래된 관측은 표시하지 않아요.'
                : '낙뢰 자료 조회에 실패했거나 수집 자료가 아직 준비되지 않았어요.'),
            TextButton(
                onPressed:
                    _loading || widget.client == null || widget.grid == null
                        ? null
                        : _load,
                child: const Text('다시 시도')),
          ],
          const SizedBox(height: 8),
          const Text(
              '출처: 기상청 낙뢰 관측 · 발생 후 30분 미만 자료만 표시해요. 수집·전송이 지연될 수 있으며, 표시가 없다고 안전을 뜻하지는 않아요.'),
        ],
      ),
    );
  }
}
