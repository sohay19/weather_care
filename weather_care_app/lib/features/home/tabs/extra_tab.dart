import '../../../utils/weather_number.dart';
import 'package:flutter/material.dart';

import '../../../services/api_client.dart';
import '../../../services/kma_grid.dart';
import '../../../theme/weather_theme.dart';
import '../widgets/extra_data_overview.dart';
import '../widgets/tab_page_header.dart';

class ExtraTab extends StatefulWidget {
  final ApiClient? client;
  final KmaGrid? grid;
  final bool active;

  const ExtraTab(
      {super.key,
      required this.client,
      required this.grid,
      required this.active});

  @override
  State<ExtraTab> createState() => _ExtraTabState();
}

class _ExtraTabState extends State<ExtraTab> {
  List<Map<String, dynamic>> _groups = [];
  Map<String, dynamic>? _selectedGroup;
  Map<String, dynamic>? _selectedTarget;
  List<Map<String, dynamic>> _records = [];
  bool _loadingCatalog = false;
  bool _loadingRecords = false;
  String? _error;
  int _request = 0;

  @override
  void initState() {
    super.initState();
    if (widget.active) _loadCatalog();
  }

  @override
  void didUpdateWidget(covariant ExtraTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active &&
        (!oldWidget.active ||
            oldWidget.client != widget.client ||
            oldWidget.grid != widget.grid)) {
      _loadCatalog();
    }
  }

  List<Map<String, dynamic>> _maps(Object? value) => value is List
      ? value
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList()
      : [];

  Future<void> _loadCatalog() async {
    final client = widget.client;
    final grid = widget.grid;
    if (client == null || grid == null) return;
    final request = ++_request;
    setState(() {
      _loadingCatalog = true;
      _loadingRecords = false;
      _error = null;
    });
    try {
      final data = await client.get('/api/v1/weather/extra/catalog',
          query: {'nx': '${grid.nx}', 'ny': '${grid.ny}'});
      if (!mounted || request != _request) return;
      final groups = _maps(data['groups']);
      final previousSource = _selectedGroup?['source'];
      final selected = groups
              .where((group) => group['source'] == previousSource)
              .firstOrNull ??
          groups
              .where((group) =>
                  group['scope'] != 'grid' &&
                  _maps(group['targets']).isNotEmpty)
              .firstOrNull ??
          groups.firstOrNull;
      final targets = _maps(selected?['targets']);
      final previousTarget = _selectedTarget?['id'];
      final target =
          targets.where((item) => item['id'] == previousTarget).firstOrNull ??
              targets.firstOrNull;
      setState(() {
        _groups = groups;
        _selectedGroup = selected;
        _selectedTarget = target;
        _records = [];
        _loadingCatalog = false;
      });
      if (target != null) _loadRecords();
    } catch (_) {
      if (!mounted || request != _request) return;
      setState(() {
        _loadingCatalog = false;
        _error = '자료 목록을 불러오지 못했어요.';
      });
    }
  }

  Future<void> _loadRecords() async {
    final client = widget.client;
    final grid = widget.grid;
    final source = _selectedGroup?['source'];
    final targetId = _selectedTarget?['id'];
    if (client == null ||
        grid == null ||
        source is! String ||
        targetId is! String) {
      return;
    }
    final request = ++_request;
    setState(() {
      _loadingRecords = true;
      _error = null;
      _records = [];
    });
    try {
      final data = await client.get('/api/v1/weather/extra/records', query: {
        'nx': '${grid.nx}',
        'ny': '${grid.ny}',
        'source': source,
        'targetId': targetId,
      });
      if (!mounted || request != _request) return;
      setState(() {
        _records = _maps(data['records']);
        _loadingRecords = false;
      });
    } catch (_) {
      if (!mounted || request != _request) return;
      setState(() {
        _loadingRecords = false;
        _error = '자료를 불러오지 못했어요.';
      });
    }
  }

  void _selectGroup(Map<String, dynamic> group) {
    if (_selectedGroup?['source'] == group['source']) return;
    ++_request;
    final targets = _maps(group['targets']);
    final target = targets.firstOrNull;
    setState(() {
      _selectedGroup = group;
      _selectedTarget = target;
      _records = [];
      _error = null;
      _loadingRecords = false;
    });
    if (target != null) _loadRecords();
  }

  void _selectTarget(String? id) {
    final targets = _maps(_selectedGroup?['targets']);
    final selected = targets.where((item) => item['id'] == id).firstOrNull;
    if (selected == null || id == _selectedTarget?['id']) return;
    setState(() => _selectedTarget = selected);
    _loadRecords();
  }

  String _category(Map<String, dynamic> group) {
    final source = '${group['source']}';
    if (source.startsWith('KHOA_')) return '해양';
    if (source.startsWith('KWATER_') || source.startsWith('HRFCO_')) {
      return '댐·하천';
    }
    if (group['scope'] == 'report') return '보고서';
    return '기상';
  }

  String _targetLabel(Map<String, dynamic> group) => switch (group['scope']) {
        'station' => '관측소 선택',
        'dam' => '댐·보 선택',
        'beach' => '해수욕장 선택',
        'area' => '해역 선택',
        'report' => '보고서 선택',
        _ => '구역 선택',
      };

  DateTime? _recordTime(Object? raw) {
    final text = '$raw';
    // 날짜만 있는 자료에 임의의 시각을 붙이지 않는다.
    if (!RegExp(r'[T ]\d{2}:\d{2}').hasMatch(text)) return null;
    final time = DateTime.tryParse(text);
    if (time == null) return null;
    final korea = time.isUtc ? time.add(const Duration(hours: 9)) : time;
    // 한국 달력 시각을 동일한 좌표로 만들어 기기 시간대에 따른 그래프 간격 차이를 막는다.
    return DateTime.utc(korea.year, korea.month, korea.day, korea.hour,
        korea.minute, korea.second, korea.millisecond, korea.microsecond);
  }

  String _timeLabel(String raw) {
    final time = _recordTime(raw);
    if (time != null) {
      String two(int value) => value.toString().padLeft(2, '0');
      return '${time.year}-${two(time.month)}-${two(time.day)} '
          '${two(time.hour)}:${two(time.minute)}';
    }
    final date = raw.length >= 10 ? raw.substring(0, 10) : raw;
    return date;
  }

  String _valueLabel(String key) =>
      const {
        'count': '낙뢰 발생',
        'tideCm': '조위',
        'waterTempC': '수온',
        'currentSpeedMs': '유속',
        'currentSpeedCmPerSec': '유속',
        'currentSpeed': '유속',
        'currentDirectionDeg': '유향',
        'extremeType': '만조·간조',
        'riskIndex': '위험지수',
        'riskMessage': '위험 안내',
        'levelM': '수위',
        'inflowM3PerSec': '유입량',
        'dischargeM3PerSec': '방류량',
        'flowM3PerSec': '유량',
        'rainfallMm': '우량',
        'latitude': '위도',
        'longitude': '경도',
      }[key] ??
      key;

  String _unit(String key) =>
      const {
        'count': '회',
        'tideCm': 'cm',
        'waterTempC': '℃',
        'currentSpeedMs': 'm/s',
        'currentSpeedCmPerSec': 'cm/s',
        'currentDirectionDeg': '°',
        'levelM': 'm',
        'inflowM3PerSec': '㎥/s',
        'dischargeM3PerSec': '㎥/s',
        'flowM3PerSec': '㎥/s',
        'rainfallMm': 'mm',
      }[key] ??
      '';

  Widget _categoryBox(String title, List<Map<String, dynamic>> groups) {
    final palette = WeatherCareTheme.of(context);
    return Card(
      key: ValueKey('extra-category-$title'),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(
                switch (title) {
                  '해양' => Icons.waves_rounded,
                  '댐·하천' => Icons.water_rounded,
                  '보고서' => Icons.article_outlined,
                  _ => Icons.bolt_rounded,
                },
                size: 18,
                color: palette.primaryDeep),
            const SizedBox(width: 8),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const Spacer(),
            Text('${groups.length}종', style: palette.microTextStyle),
          ]),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 6, children: [
            for (final group in groups)
              ChoiceChip(
                key: ValueKey('extra-source-${group['source']}'),
                showCheckmark: false,
                label: Text('${group['title']}',
                    style: const TextStyle(
                        fontFamily: WeatherCareTheme.fontSuite)),
                selected: _selectedGroup?['source'] == group['source'],
                onSelected: (_) => _selectGroup(group),
              ),
          ]),
        ]),
      ),
    );
  }

  Widget _recordCard(Map<String, dynamic> entry, {bool showTime = true}) {
    final palette = WeatherCareTheme.of(context);
    final report = _selectedGroup?['scope'] == 'report';
    final values = Map<String, dynamic>.from(
        entry['values'] is Map ? entry['values'] as Map : {});
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: palette.outline)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (showTime) ...[
            Row(children: [
              Icon(
                  report
                      ? Icons.article_outlined
                      : Icons.calendar_today_outlined,
                  size: 16,
                  color: palette.primaryDeep),
              const SizedBox(width: 8),
              Expanded(
                  child: Text(_timeLabel('${entry['time']}'),
                      style: TextStyle(
                          color: palette.primaryDeep,
                          fontWeight: FontWeight.w700,
                          fontSize: 12))),
            ]),
            const SizedBox(height: 12),
            Divider(height: 1, color: palette.outline),
            const SizedBox(height: 12),
          ],
          for (final value in values.entries)
            if (value.value != null)
              Padding(
                padding: EdgeInsets.only(bottom: report ? 12 : 7),
                child: Text.rich(
                    TextSpan(children: [
                      TextSpan(
                          text: '${_valueLabel(value.key)}  ',
                          style: TextStyle(color: palette.textSecondary)),
                      TextSpan(
                          text:
                              '${value.value is num ? formatWeatherNumber(value.value as num) : value.value}${_unit(value.key)}',
                          style: TextStyle(
                              fontWeight: value.value is num
                                  ? FontWeight.w800
                                  : FontWeight.w500)),
                    ]),
                    style: const TextStyle(fontSize: 13, height: 1.6)),
              ),
        ]),
      ),
    );
  }

  Widget _timeline(List<Map<String, dynamic>> records) {
    final palette = WeatherCareTheme.of(context);
    final sorted = [...records]..sort((a, b) =>
        _timeLabel('${a['time']}').compareTo(_timeLabel('${b['time']}')));
    String? previousDate;
    final children = <Widget>[];
    for (final entry in sorted) {
      final label = _timeLabel('${entry['time']}');
      final date = label.substring(0, 10);
      if (date != previousDate) {
        children.add(Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 12),
          child: Text(date, style: Theme.of(context).textTheme.titleMedium),
        ));
        previousDate = date;
      }
      children.add(Stack(children: [
        Positioned(
          left: 63,
          top: 0,
          bottom: 0,
          child: Container(width: 2, color: palette.primaryBorder),
        ),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
            width: 52,
            child: Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(label.substring(11),
                  style: Theme.of(context).textTheme.labelLarge),
            ),
          ),
          SizedBox(
            width: 24,
            child: Padding(
              padding: const EdgeInsets.only(top: 20),
              child: Center(
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                      color: palette.primary, shape: BoxShape.circle),
                ),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 8, bottom: 12),
              child: _recordCard(entry, showTime: false),
            ),
          ),
        ]),
      ]));
    }
    return Column(
      key: const ValueKey('extra-timeline'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = WeatherCareTheme.of(context);
    final group = _selectedGroup;
    final targets = _maps(group?['targets']);
    final categories = <String, List<Map<String, dynamic>>>{};
    for (final item in _groups) {
      categories.putIfAbsent(_category(item), () => []).add(item);
    }
    final timeline = group?['scope'] != 'report' &&
        _records.isNotEmpty &&
        _records.every((entry) => _recordTime(entry['time']) != null);
    return Container(
      key: const ValueKey('extra-tab'),
      color: palette.background,
      child: RefreshIndicator(
          onRefresh: _loadCatalog,
          child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              children: [
                const TabPageHeader(
                    eyebrow: 'OBSERVATION & DATA',
                    title: '지역 자료',
                    subtitle: '격자와 관측 지점을 구분해서 확인해요',
                    icon: Icons.query_stats_rounded),
                const SizedBox(height: 20),
                if (widget.grid != null)
                  Text('기준 격자 ${widget.grid!.nx}, ${widget.grid!.ny}',
                      style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 16),
                if (_loadingCatalog)
                  const Center(child: CircularProgressIndicator())
                else if (widget.grid == null)
                  const Text('먼저 날씨 지역을 선택해주세요.')
                else if (widget.client == null)
                  const Text('서버 연결을 확인하고 있어요.')
                else ...[
                  for (final category in categories.entries)
                    _categoryBox(category.key, category.value),
                  if (_groups.isEmpty && _error == null)
                    const Text('표시할 자료 종류가 없어요.'),
                  const SizedBox(height: 8),
                  if (group != null) ...[
                    Text('${group['title']}',
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 5),
                    Text(
                        group['scope'] == 'grid'
                            ? '현재 격자에서 관측된 발생 이력입니다.'
                            : group['source'] == 'KHOA_ROMS' &&
                                    _selectedTarget?['id'] == 'GRID'
                                ? '현재 격자 안 해양 모델 지점의 예측값입니다.'
                                : group['scope'] == 'report'
                                    ? '선택한 보고서의 내용입니다.'
                                    : '선택한 관측소·시설·해역의 자료입니다. 격자 전체의 값은 아닙니다.',
                        style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: 12),
                    if (group['scope'] != 'grid')
                      DropdownButtonFormField<String>(
                        key: ValueKey(
                            'extra-target-${group['source']}-${_selectedTarget?['id']}'),
                        initialValue: _selectedTarget?['id'] as String?,
                        isExpanded: true,
                        menuMaxHeight: 360,
                        decoration: InputDecoration(
                          labelText: _targetLabel(group),
                          prefixIcon: const Icon(Icons.place_outlined),
                          border: const OutlineInputBorder(),
                        ),
                        hint: const Text('수집된 선택 대상 없음'),
                        items: [
                          for (final target in targets)
                            DropdownMenuItem(
                              value: '${target['id']}',
                              child: Text('${target['name']} (${target['id']})',
                                  maxLines: 1, overflow: TextOverflow.ellipsis),
                            ),
                        ],
                        onChanged: targets.isEmpty ? null : _selectTarget,
                      ),
                    if (_selectedTarget == null && targets.isNotEmpty)
                      const Padding(
                          padding: EdgeInsets.only(top: 12),
                          child: Text('표시할 관측소·시설·해역을 선택해주세요.')),
                    if (_loadingRecords)
                      const Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(child: CircularProgressIndicator())),
                    if (!_loadingRecords &&
                        _error == null &&
                        _selectedTarget != null &&
                        _records.isEmpty)
                      const Padding(
                          padding: EdgeInsets.only(top: 12),
                          child: Text('아직 저장된 자료가 없어요.')),
                    if (_records.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      if (timeline)
                        ExtraDataOverview(
                          key: ValueKey(
                              'extra-overview-${group['source']}-${_selectedTarget?['id']}'),
                          records: _records,
                          source: '${group['source']}',
                          targetName:
                              '${_selectedTarget?['name'] ?? group['title']}',
                          labelFor: _valueLabel,
                          unitFor: _unit,
                          timeFor: _recordTime,
                          timeLabel: _timeLabel,
                        ),
                      Text(
                          timeline
                              ? '시간대별 타임라인 · 한국 표준시'
                              : group['scope'] == 'report'
                                  ? '보고서 내용'
                                  : '일자별 자료',
                          style: Theme.of(context).textTheme.titleMedium),
                      if (timeline)
                        _timeline(_records)
                      else
                        for (final entry in _records)
                          Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: _recordCard(entry),
                          ),
                    ],
                  ],
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(children: [
                        Expanded(child: Text(_error!)),
                        TextButton(
                          onPressed: _selectedTarget == null
                              ? _loadCatalog
                              : _loadRecords,
                          child: const Text('다시 시도'),
                        ),
                      ]),
                    ),
                ],
              ])),
    );
  }
}
