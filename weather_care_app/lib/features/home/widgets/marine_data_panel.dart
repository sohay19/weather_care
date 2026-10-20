import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../services/api_client.dart';
import '../../../services/kma_grid.dart';
import '../../../theme/weather_theme.dart';
import '../../../utils/weather_number.dart';
import 'extra_chip_row.dart';
import 'hourly_value_chart.dart';
import 'marine_series.dart';

class MarineDataPanel extends StatefulWidget {
  final ApiClient client;
  final KmaGrid grid;
  final Map<String, dynamic> observationGroup;
  final Map<String, dynamic> forecastGroup;
  final DateTime? now;
  final String? selectedId;
  final ValueChanged<String> onSelected;
  const MarineDataPanel(
      {super.key,
      required this.client,
      required this.grid,
      required this.observationGroup,
      required this.forecastGroup,
      this.now,
      this.selectedId,
      required this.onSelected});

  @override
  State<MarineDataPanel> createState() => _MarineDataPanelState();
}

class _MarineDataPanelState extends State<MarineDataPanel> {
  String? _id;
  String? _metric;
  List<MarinePoint> _observations = [], _forecasts = [];
  String? _observationError, _forecastError;
  Map<String, dynamic>? _forecastTarget;
  bool _loading = false;
  int _request = 0;
  bool get _tide => widget.observationGroup['source'] == 'KHOA_TIDE_OBS';
  List<Map<String, dynamic>> _targets(Map<String, dynamic> group) =>
      (group['targets'] as List? ?? [])
          .whereType<Map>()
          .map((t) => Map<String, dynamic>.from(t))
          .where((t) => t['id'] != 'GRID')
          .toList();
  List<Map<String, dynamic>> get _choices {
    final obs = _targets(widget.observationGroup);
    final predicted = _targets(widget.forecastGroup);
    return _tide
        ? [
            for (final o in obs)
              {
                ...o,
                'hasData': o['hasData'] != false ||
                    predicted.any(
                        (p) => p['id'] == o['id'] && p['hasData'] != false),
              },
            ...predicted.where((p) => !obs.any((o) => o['id'] == p['id']))
          ]
        : obs.isNotEmpty
            ? obs
            : predicted;
  }

  Map<String, dynamic>? get _target =>
      _choices.where((t) => t['id'] == _id).firstOrNull;

  @override
  void initState() {
    super.initState();
    _reset();
  }

  @override
  void didUpdateWidget(covariant MarineDataPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.observationGroup != widget.observationGroup ||
        oldWidget.forecastGroup != widget.forecastGroup ||
        oldWidget.grid != widget.grid ||
        oldWidget.client != widget.client) {
      _reset();
    }
  }

  void _reset() {
    final choices = _choices;
    final previous = widget.selectedId;
    final available = choices.where((t) => t['hasData'] != false).toList()
      ..sort((a, b) => ((a['distanceKm'] as num?)?.toDouble() ??
              double.infinity)
          .compareTo((b['distanceKm'] as num?)?.toDouble() ?? double.infinity));
    _id = choices.where((t) => t['id'] == previous).firstOrNull?['id']
            as String? ??
        available.firstOrNull?['id'] as String?;
    _load();
  }

  Map<String, dynamic>? _prediction(Map<String, dynamic> target) {
    final forecasts = _targets(widget.forecastGroup)
        .where((t) => t['hasData'] != false)
        .toList();
    final same = forecasts
        .where((t) =>
            t['id'] == target['id'] ||
            (!_tide && t['id'] == 'BUOY_${target['id']}'))
        .firstOrNull;
    if (same != null || _tide) return same;
    double distance(Map<String, dynamic> p) => target['latitude'] is num &&
            target['longitude'] is num &&
            p['latitude'] is num &&
            p['longitude'] is num
        ? math
                .pow((target['latitude'] as num) - (p['latitude'] as num), 2)
                .toDouble() +
            math
                .pow((target['longitude'] as num) - (p['longitude'] as num), 2)
                .toDouble()
        : (p['distanceKm'] as num?)?.toDouble() ?? double.infinity;
    forecasts.sort((a, b) => distance(a).compareTo(distance(b)));
    return forecasts.firstOrNull;
  }

  Future<void> _load() async {
    final request = ++_request;
    final target = _target;
    _observations = [];
    _forecasts = [];
    _observationError = null;
    _forecastError = null;
    _forecastTarget = target == null ? null : _prediction(target);
    if (target == null) {
      _loading = false;
      return;
    }
    _loading = true;
    final observation = _targets(widget.observationGroup)
        .where((t) => t['id'] == _id)
        .firstOrNull;
    final prediction = _forecastTarget;
    Future<(List<MarinePoint>, String?)> fetch(Map<String, dynamic> group,
        Map<String, dynamic>? selected, String label) async {
      if (selected == null) return (<MarinePoint>[], null);
      try {
        final data =
            await widget.client.get('/api/v1/weather/extra/records', query: {
          'source': '${group['source']}',
          'targetId': '${selected['id']}',
          'nx': '${widget.grid.nx}',
          'ny': '${widget.grid.ny}',
        });
        final records = (data['records'] as List? ?? [])
            .whereType<Map>()
            .map((r) => Map<String, dynamic>.from(r))
            .toList();
        return (
          marinePoints(records,
              buoy: group['source'] == 'KHOA_BUOY_OBS', location: target),
          null
        );
      } catch (_) {
        return (<MarinePoint>[], '$label 자료를 불러오지 못했어요.');
      }
    }

    final results = await Future.wait([
      fetch(widget.observationGroup, observation, '관측'),
      fetch(widget.forecastGroup, prediction, '예측'),
    ]);
    if (!mounted || request != _request) return;
    setState(() {
      _observations = results[0].$1;
      _observationError = results[0].$2;
      _forecasts = results[1].$1;
      _forecastError = results[1].$2;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = WeatherCareTheme.of(context);
    const chartHeight = 196.0;
    final metrics = _tide
        ? ['tideCm']
        : ['waterTempC', 'currentSpeed', 'currentDirectionDeg'];
    final metric = metrics.contains(_metric) ? _metric! : metrics.first;
    final title = {
      'tideCm': '조위',
      'waterTempC': '수온',
      'currentSpeed': '유속',
      'currentDirectionDeg': '유향'
    }[metric]!;
    final unit = {
      'tideCm': 'cm',
      'waterTempC': '℃',
      'currentSpeed': 'm/s',
      'currentDirectionDeg': '°'
    }[metric]!;
    final data = MarineHourlyData(
        now: marineTime(widget.now ?? DateTime.now()),
        observations: _observations,
        forecasts: _forecasts);
    final current = data.latest(metric);
    final range = data.range(metric);
    String value(double? n) =>
        n == null ? '자료 없음' : '${formatWeatherNumber(n)}$unit';
    String time(DateTime d) =>
        '${d.month}/${d.day} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    final observed = data.hourly(metric, forecast: false);
    final predicted = data.hourly(metric, forecast: true);
    final known = [...observed, ...predicted].whereType<double>().toList();
    final bounds = metric == 'currentDirectionDeg'
        ? (0.0, 360.0)
        : known.isEmpty
            ? (0.0, 1.0)
            : (
                known.reduce(math.min) -
                    math.max(
                        (known.reduce(math.max) - known.reduce(math.min)) * .15,
                        .1),
                known.reduce(math.max) +
                    math.max(
                        (known.reduce(math.max) - known.reduce(math.min)) * .15,
                        .1)
              );
    final obsSeries = HourlyChartSeries(
        id: 'marine-observed-$metric',
        title: '관측',
        unit: unit,
        values: observed.map(HourlyChartValue.number).toList(),
        color: palette.primaryDeep);
    final forecastSeries = HourlyChartSeries(
        id: 'marine-forecast-$metric',
        title: '예측',
        unit: unit,
        values: predicted.map(HourlyChartValue.number).toList(),
        color: palette.attentionDeep);
    return Column(
        key: const ValueKey('marine-combined-panel'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<String>(
              key: ValueKey('marine-combined-target-$_id'),
              initialValue: _id,
              isExpanded: true,
              menuMaxHeight: 360,
              decoration: const InputDecoration(
                  labelText: '관측소·해역 선택',
                  prefixIcon: Icon(Icons.place_outlined),
                  border: OutlineInputBorder()),
              hint: const Text('조회 가능한 지점 없음'),
              items: [
                for (final t in _choices)
                  DropdownMenuItem(
                      value: '${t['id']}',
                      child: Text(
                          '${t['name']}${t['distanceKm'] is num ? ' · 약 ${(t['distanceKm'] as num).toStringAsFixed(1)}km' : ''}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis))
              ],
              onChanged: _choices.isEmpty
                  ? null
                  : (id) {
                      if (id == null || id == _id) return;
                      widget.onSelected(id);
                      setState(() {
                        _id = id;
                        _load();
                      });
                    }),
          if (metrics.length > 1) ...[
            const SizedBox(height: 16),
            ExtraChipRow(key: const ValueKey('marine-metric-chips'), children: [
              for (final m in metrics)
                ChoiceChip(
                    key: ValueKey('marine-metric-$m'),
                    label: Text({
                      'tideCm': '조위',
                      'waterTempC': '수온',
                      'currentSpeed': '유속',
                      'currentDirectionDeg': '유향'
                    }[m]!),
                    selected: metric == m,
                    showCheckmark: false,
                    selectedColor: palette.primaryDeep,
                    backgroundColor: palette.surfaceMuted,
                    labelStyle: TextStyle(
                        fontFamily: WeatherCareTheme.fontSuite,
                        color: metric == m
                            ? palette.onPrimary
                            : palette.textPrimary),
                    side: BorderSide(
                        color: metric == m
                            ? palette.primaryDeep
                            : palette.outline),
                    onSelected: (_) => setState(() => _metric = m)),
            ]),
          ],
          if (_loading)
            const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()))
          else ...[
            Container(
                key: const ValueKey('marine-current'),
                margin: const EdgeInsets.only(top: 14),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    color: palette.primarySoft,
                    borderRadius: BorderRadius.circular(16)),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('현재 관측 · $title',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 6),
                      Text(value(current?.values[metric]),
                          style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: palette.primaryDeep)),
                      Text(
                          current == null
                              ? '오늘 관측값이 없어요'
                              : '기준 시간 · ${time(current.time)}',
                          style: Theme.of(context).textTheme.bodySmall),
                    ])),
            const SizedBox(height: 12),
            Container(
                key: const ValueKey('marine-forecast-range'),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                    color: palette.attentionSoft,
                    borderRadius: BorderRadius.circular(16)),
                child: Wrap(spacing: 24, runSpacing: 10, children: [
                  for (final stat in [('최저', range?.$1), ('최고', range?.$2)])
                    Text.rich(
                        TextSpan(children: [
                          TextSpan(
                              text: '${stat.$1} ',
                              style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: palette.attentionDeep)),
                          TextSpan(text: value(stat.$2)),
                        ]),
                        style: const TextStyle(fontSize: 18)),
                ])),
            for (final error
                in [_observationError, _forecastError].whereType<String>())
              Padding(
                  padding: const EdgeInsets.only(top: 8), child: Text(error)),
            if (_observationError != null || _forecastError != null)
              Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                      onPressed: () => setState(() {
                            _load();
                          }),
                      child: const Text('다시 시도'))),
            const SizedBox(height: 18),
            Text('시간대별 $title', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(spacing: 16, children: [
              Text('● 관측', style: TextStyle(color: palette.primaryDeep)),
              Text('● 예측', style: TextStyle(color: palette.attentionDeep)),
            ]),
            const SizedBox(height: 8),
            if (known.isEmpty)
              const Padding(
                  padding: EdgeInsets.all(16), child: Text('표시할 시간별 자료가 없어요.'))
            else
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SizedBox(
                    width: 48,
                    child: HourlyChartAxis(
                        series: obsSeries,
                        title: title,
                        sharedBounds: bounds,
                        height: chartHeight)),
                const SizedBox(width: 12),
                Expanded(
                    child: SingleChildScrollView(
                        key: const ValueKey('marine-hourly-scroll'),
                        scrollDirection: Axis.horizontal,
                        child: Column(children: [
                          HourlyValueChart(
                              series: obsSeries,
                              overlays: [forecastSeries],
                              hours: List.generate(24, (i) => i),
                              pointWidth: 56,
                              height: chartHeight,
                              sharedBounds: bounds,
                              showValues: true),
                          Row(children: [
                            for (var h = 0; h < 24; h++)
                              SizedBox(
                                  width: 56,
                                  child: Padding(
                                      padding: const EdgeInsets.only(
                                          top: 8, bottom: 8),
                                      child: Text('$h시',
                                          textAlign: TextAlign.center,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                                  fontWeight:
                                                      FontWeight.w700))))
                          ]),
                        ]))),
              ]),
          ],
        ]);
  }
}
