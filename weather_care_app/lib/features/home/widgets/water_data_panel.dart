import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../services/api_client.dart';
import '../../../services/kma_grid.dart';
import '../../../services/data_station_selection.dart';
import '../../../theme/weather_theme.dart';
import '../../../utils/korea_date.dart';
import '../../../utils/weather_number.dart';
import 'extra_chip_row.dart';
import 'hourly_value_chart.dart';
import 'marine_series.dart';
import 'marine_tide_summary.dart';
import 'data_range_tile.dart';

class _TargetSearchField extends StatefulWidget {
  final List<Map<String, dynamic>> targets;
  final String? selectedId;
  final String label;
  final ValueChanged<String> onSelected;
  const _TargetSearchField(
      {super.key,
      required this.targets,
      required this.selectedId,
      required this.label,
      required this.onSelected});

  @override
  State<_TargetSearchField> createState() => _TargetSearchFieldState();
}

class _TargetSearchFieldState extends State<_TargetSearchField> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _clear() {
    _controller.clear();
    setState(() => _query = '');
  }

  @override
  Widget build(BuildContext context) {
    String normalize(String value) =>
        value.toLowerCase().replaceAll(RegExp(r'\s+'), '');
    final query = normalize(_query);
    final targets = widget.targets
        .where((target) => normalize(
                '${target['name']} ${target['id']} ${(target['codes'] as List? ?? []).join(' ')} ${(target['providers'] as List? ?? []).join(' ')}')
            .contains(query))
        .toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      TextField(
        key: const ValueKey('water-target-search-input'),
        controller: _controller,
        enabled: widget.targets.isNotEmpty,
        onChanged: (value) {
          setState(() => _query = value);
          if (value.trim().isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) Scrollable.ensureVisible(context, alignment: 0);
            });
          }
        },
        decoration: InputDecoration(
            labelText: '${widget.label} 검색',
            hintText: '이름 또는 코드 입력',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _query.isEmpty
                ? null
                : IconButton(
                    key: const ValueKey('water-target-search-clear'),
                    tooltip: '검색어 지우기',
                    onPressed: _clear,
                    icon: const Icon(Icons.close)),
            border: const OutlineInputBorder()),
      ),
      if (query.isNotEmpty) ...[
        const SizedBox(height: 8),
        Text('검색 결과 ${targets.length}개'),
        const SizedBox(height: 4),
        Container(
          key: const ValueKey('water-target-search-results'),
          constraints: const BoxConstraints(maxHeight: 320),
          decoration: BoxDecoration(
              border: Border.all(color: WeatherCareTheme.of(context).outline),
              borderRadius: BorderRadius.circular(12)),
          clipBehavior: Clip.antiAlias,
          child: Material(
              color: WeatherCareTheme.of(context).surface,
              child: targets.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(16), child: Text('검색 결과가 없어요.'))
                  : ListView.builder(
                      shrinkWrap: true,
                      primary: false,
                      padding: EdgeInsets.zero,
                      itemCount: targets.length,
                      itemBuilder: (context, index) {
                        final target = targets[index];
                        final id = '${target['id']}';
                        final providers =
                            (target['providers'] as List? ?? []).join(' · ');
                        return ListTile(
                          key: ValueKey('water-search-result-$id'),
                          title: Text('${target['name']}'),
                          subtitle: Text('${(target['codes'] as List? ?? [
                                    id
                                  ]).join(' / ')}${providers.isEmpty ? '' : ' · $providers'}'
                              '${target['hasData'] == false ? '\n오늘 관측 자료 없음' : ''}'),
                          selected: id == widget.selectedId,
                          trailing: id == widget.selectedId
                              ? const Icon(Icons.check)
                              : null,
                          onTap: () {
                            FocusScope.of(context).unfocus();
                            _clear();
                            widget.onSelected(id);
                          },
                        );
                      })),
        ),
      ],
    ]);
  }
}

class WaterDataPanel extends StatefulWidget {
  final ApiClient client;
  final KmaGrid grid;
  final Map<String, dynamic> observationGroup;
  final Map<String, dynamic> forecastGroup;
  final DateTime? now;
  final String? selectedId;
  final ValueChanged<String> onSelected;
  const WaterDataPanel(
      {super.key,
      required this.client,
      required this.grid,
      required this.observationGroup,
      this.forecastGroup = const {'targets': <Map<String, dynamic>>[]},
      this.now,
      this.selectedId,
      required this.onSelected});

  @override
  State<WaterDataPanel> createState() => _WaterDataPanelState();
}

class _WaterDataPanelState extends State<WaterDataPanel>
    with WidgetsBindingObserver {
  Timer? _hourTimer;
  final _chartScroll = ScrollController();
  final _selectedDataKey = GlobalKey();
  bool _scrollAfterSelection = false;
  String? _scrollRequest;
  String? _id;
  String? _metric;
  List<MarinePoint> _observations = [], _forecasts = [];
  String? _observationError, _forecastError;
  Map<String, dynamic>? _forecastTarget;
  bool _loading = false;
  int _request = 0;
  bool get _tide => widget.observationGroup['source'] == 'KHOA_TIDE_OBS';
  bool get _river => const [
        'HRFCO_RIVER_FLOW',
        'KWATER_RIVER_LEVEL',
        'KWATER_DAM'
      ].contains(widget.observationGroup['source']);
  String get _prefix => _river ? 'river' : 'marine';
  String get _targetLabel => widget.observationGroup['source'] == 'KWATER_DAM'
      ? '댐·보'
      : _river
          ? '관측소'
          : '관측소·해역';
  List<String> get _metrics => switch (widget.observationGroup['source']) {
        'KHOA_TIDE_OBS' => ['tideCm'],
        'HRFCO_RIVER_FLOW' => ['levelM', 'flowM3PerSec'],
        'KWATER_RIVER_LEVEL' => ['levelM', 'flowM3PerSec'],
        'KWATER_DAM' => ['levelM', 'inflowM3PerSec', 'dischargeM3PerSec'],
        _ => ['waterTempC', 'currentSpeed', 'currentDirectionDeg'],
      };
  static const _labels = {
    'tideCm': '조위',
    'waterTempC': '수온',
    'currentSpeed': '유속',
    'currentDirectionDeg': '유향',
    'levelM': '수위',
    'flowM3PerSec': '유량',
    'rainfallMm': '우량',
    'inflowM3PerSec': '유입량',
    'dischargeM3PerSec': '방류량',
  };
  static const _units = {
    'tideCm': 'cm',
    'waterTempC': '℃',
    'currentSpeed': 'm/s',
    'currentDirectionDeg': '°',
    'levelM': 'm',
    'flowM3PerSec': '㎥/s',
    'rainfallMm': 'mm',
    'inflowM3PerSec': '㎥/s',
    'dischargeM3PerSec': '㎥/s',
  };

  List<Map<String, dynamic>> _targets(Map<String, dynamic> group) =>
      (group['targets'] as List? ?? [])
          .whereType<Map>()
          .map((t) => Map<String, dynamic>.from(t))
          .where((t) => t['id'] != 'GRID')
          .toList();
  List<Map<String, dynamic>> get _choices {
    final obs = _targets(widget.observationGroup);
    final predicted = _targets(widget.forecastGroup);
    if (_river) return obs;
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
    WidgetsBinding.instance.addObserver(this);
    _scheduleHour();
    _reset();
  }

  void _scheduleHour() {
    _hourTimer?.cancel();
    if (widget.now != null) return;
    _hourTimer = Timer(untilNextKoreaHour(DateTime.now()), () {
      if (!mounted) return;
      setState(() {});
      _scheduleHour();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      setState(() {});
      _scheduleHour();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _hourTimer?.cancel();
    _chartScroll.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant WaterDataPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    _scheduleHour();
    if (oldWidget.observationGroup != widget.observationGroup ||
        oldWidget.forecastGroup != widget.forecastGroup ||
        oldWidget.grid != widget.grid ||
        oldWidget.client != widget.client) {
      _reset();
    }
  }

  void _reset() {
    _scrollAfterSelection = false;
    final choices = _choices;
    final previous = widget.selectedId;
    _id = choices.where((t) => t['id'] == previous).firstOrNull?['id']
            as String? ??
        nearestDataStation(choices)?['id'] as String? ??
        choices.where((t) => t['hasData'] != false).firstOrNull?['id']
            as String?;
    _load();
  }

  Map<String, dynamic>? _prediction(Map<String, dynamic> target) {
    if (_river) return null;
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
              buoy: group['source'] == 'KHOA_BUOY_OBS',
              location: target,
              metrics: _metrics),
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
    if (_scrollAfterSelection && !_tide) {
      _scrollAfterSelection = false;
      _scrollToSelectedData();
    }
  }

  void _scrollToSelectedData() {
    final request = _request;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final dataContext = _selectedDataKey.currentContext;
      if (!mounted || request != _request || _loading || dataContext == null) {
        return;
      }
      Scrollable.ensureVisible(dataContext,
          alignment: .5,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut);
    });
  }

  void _select(String? id) {
    if (id == null) return;
    widget.onSelected(id);
    if (id == _id) {
      if (_loading) {
        _scrollAfterSelection = true;
      } else {
        _scrollToSelectedData();
      }
      return;
    }
    _scrollAfterSelection = true;
    setState(() {
      _id = id;
      _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = WeatherCareTheme.of(context);
    final nearest = nearestDataStation(_choices);
    final chartHeight = detailedHourlyChartHeight *
        math.min(MediaQuery.textScalerOf(context).scale(1), 1.3);
    final metrics = _metrics;
    final metric = metrics.contains(_metric) ? _metric! : metrics.first;
    final title = _labels[metric]!;
    final unit = _units[metric]!;
    final data = MarineHourlyData(
        now: marineTime(widget.now ?? DateTime.now()),
        observations: _observations,
        forecasts: _forecasts);
    final current = data.latest(metric);
    final range = data.range(metric, observed: _river);
    String value(double? n) =>
        n == null ? '자료 없음' : '${formatWeatherNumber(n)}$unit';
    String time(DateTime d) =>
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    Widget timeLabel(int hour) {
      final isCurrent = hour == data.now.hour;
      return Semantics(
          label: isCurrent ? '현재 시간 $hour시' : null,
          child: Container(
              key: isCurrent ? ValueKey('$_prefix-current-time') : null,
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: isCurrent
                  ? BoxDecoration(
                      color: palette.primaryDeep,
                      borderRadius: BorderRadius.circular(8))
                  : null,
              child: Text('$hour시',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color:
                          isCurrent ? palette.onPrimary : palette.primaryDeep,
                      fontFamily: WeatherCareTheme.fontSuite,
                      fontWeight: FontWeight.w800))));
    }

    final observed = data.hourly(metric, forecast: false);
    final predicted = _river
        ? List<double?>.filled(24, null)
        : data.hourly(metric, forecast: true);
    final known = [...observed, ...predicted].whereType<double>().toList();
    // 자료를 불러온 첫 화면은 현재 시간부터 보여준다.
    final scrollRequest = '$_request';
    if (known.isNotEmpty && _scrollRequest != scrollRequest) {
      _scrollRequest = scrollRequest;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted ||
            _scrollRequest != scrollRequest ||
            !_chartScroll.hasClients) {
          return;
        }
        final offset = data.now.hour * 56.0;
        _chartScroll
            .jumpTo(offset.clamp(0.0, _chartScroll.position.maxScrollExtent));
      });
    }
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
        key: ValueKey('$_prefix-combined-panel'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _TargetSearchField(
              key: ValueKey('$_prefix-target-search'),
              targets: _choices,
              selectedId: _id,
              label: _targetLabel,
              onSelected: _select),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
              key: ValueKey('$_prefix-combined-target-$_id'),
              initialValue: _id,
              isExpanded: true,
              menuMaxHeight: 360,
              decoration: InputDecoration(
                  labelText: '$_targetLabel 선택',
                  prefixIcon: const Icon(Icons.place_outlined),
                  border: OutlineInputBorder()),
              hint: Text(_river ? '$_targetLabel 없음' : '조회 가능한 지점 없음'),
              items: [
                for (final t in _choices)
                  DropdownMenuItem(
                      value: '${t['id']}',
                      child: Text(
                          '${t['name']}${t['distanceKm'] is num ? ' · 약 ${(t['distanceKm'] as num).toStringAsFixed(1)}km' : ''}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis))
              ],
              onChanged: _choices.isEmpty ? null : _select),
          Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                  key: ValueKey('$_prefix-nearest-target'),
                  style: TextButton.styleFrom(
                      textStyle: const TextStyle(fontSize: 12),
                      iconSize: 16,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: const Size(0, 32),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                  onPressed: nearest == null
                      ? null
                      : () => _select('${nearest['id']}'),
                  icon: const Icon(Icons.near_me_outlined),
                  label: Text('가장 가까운 $_targetLabel 자동선택'))),
          if (widget.observationGroup['source'] != 'HRFCO_RIVER_FLOW' &&
              _choices.isNotEmpty &&
              _choices.any((target) => target['distanceKm'] is! num))
            Text(
                nearest == null
                    ? '관측소 위치 정보가 아직 제공되지 않았어요.'
                    : '위치가 제공된 관측소 기준으로 선택해요.',
                style: palette.microTextStyle),
          if (_river && _target?['providers'] is List) ...[
            const SizedBox(height: 8),
            Text('자료 제공 · ${(_target!['providers'] as List).join(' · ')}',
                style: palette.microTextStyle),
          ],
          if (metrics.length > 1) ...[
            const SizedBox(height: 16),
            ExtraChipRow(key: ValueKey('$_prefix-metric-chips'), children: [
              for (final m in metrics)
                ChoiceChip(
                    key: ValueKey('$_prefix-metric-$m'),
                    label: Text(_labels[m]!),
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
                key: ValueKey('$_prefix-current'),
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    color: palette.primarySoft,
                    borderRadius: BorderRadius.circular(16)),
                child: Column(
                    key: _selectedDataKey,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Expanded(
                            flex: 3,
                            child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text('현재 관측 · $title',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium))),
                        const SizedBox(width: 8),
                        Expanded(
                            flex: 2,
                            child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerRight,
                                child: Text(
                                    '기준 시간 · ${current == null ? '--:--' : time(current.time)}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(fontSize: 10)))),
                      ]),
                      const SizedBox(height: 6),
                      KeyedSubtree(
                          key: ValueKey('$_prefix-current-value'),
                          child: Text(value(current?.values[metric]),
                              style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w800,
                                  color: palette.primaryDeep))),
                      if (current == null)
                        Text('오늘 관측값이 없어요',
                            style: Theme.of(context).textTheme.bodySmall),
                      if (_tide) ...[
                        const SizedBox(height: 12),
                        MarineTideSummary(
                            client: widget.client,
                            grid: widget.grid,
                            now: widget.now,
                            selectedId: _id,
                            onLoaded: () {
                              if (_scrollAfterSelection) {
                                _scrollAfterSelection = false;
                                _scrollToSelectedData();
                              }
                            }),
                      ],
                      const SizedBox(height: 12),
                      Row(
                          key: ValueKey(_river
                              ? 'river-observed-range'
                              : 'marine-forecast-range'),
                          children: [
                            Expanded(
                                child: DataRangeTile(
                                    label: '최저', value: value(range?.$1))),
                            const SizedBox(width: 8),
                            Expanded(
                                child: DataRangeTile(
                                    label: '최고', value: value(range?.$2))),
                          ]),
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
              if (!_river)
                Text('● 예측', style: TextStyle(color: palette.attentionDeep)),
            ]),
            const SizedBox(height: 24),
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
                        controller: _chartScroll,
                        key: ValueKey('$_prefix-hourly-scroll'),
                        scrollDirection: Axis.horizontal,
                        child: Column(children: [
                          HourlyValueChart(
                              series: obsSeries,
                              overlays: _river ? [] : [forecastSeries],
                              hours: List.generate(24, (i) => i),
                              pointWidth: 56,
                              height: chartHeight,
                              sharedBounds: bounds,
                              avoidLineOverlaps: true,
                              showValues: true),
                          Row(children: [
                            for (var h = 0; h < 24; h++)
                              SizedBox(
                                  width: 56,
                                  child: Padding(
                                      padding: const EdgeInsets.only(
                                          top: 8, bottom: 8),
                                      child: Center(child: timeLabel(h))))
                          ]),
                        ]))),
              ]),
          ],
        ]);
  }
}
