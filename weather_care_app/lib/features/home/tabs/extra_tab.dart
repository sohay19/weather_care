import '../../../utils/weather_number.dart';
import 'package:flutter/material.dart';

import '../../../services/api_client.dart';
import '../../../services/current_location_service.dart';
import '../../../services/kma_grid.dart';
import '../../../theme/weather_theme.dart';
import '../widgets/extra_data_overview.dart';
import '../widgets/extra_chip_row.dart';
import '../widgets/marine_data_panel.dart';
import '../widgets/marine_tide_summary.dart';
import '../widgets/tab_page_header.dart';

class _ExtraTopic {
  final String source;
  final String title;
  final String description;
  final String scope;
  final String? alternateSource;
  final String? alternateScope;

  const _ExtraTopic(this.source, this.title, this.description,
      {this.scope = 'station', this.alternateSource, this.alternateScope});

  bool contains(Object? value) =>
      value == source || (alternateSource != null && value == alternateSource);
}

const _waterTopics = [
  [
    _ExtraTopic('KHOA_TIDE_OBS', '조위',
        '선택한 관측소의 현재 조위와 오늘 예측 최저·최고를 함께 확인해요. 시간별 그래프는 과거 관측과 미래 예측을 보여줘요.',
        alternateSource: 'KHOA_TIDE_HOURLY'),
    _ExtraTopic('KHOA_RIP_CURRENT', '이안류',
        '해수욕장을 선택해 바다 쪽으로 빠르게 흐르는 이안류의 위험지수와 안내를 확인해요.',
        scope: 'beach'),
    _ExtraTopic('NIFS_JELLYFISH_DETAIL', '해파리',
        '아래에서 보고서를 선택하면 해당 보고서의 해파리 출현 해역과 내용을 볼 수 있어요.',
        scope: 'report'),
    _ExtraTopic('KHOA_BUOY_OBS', '수온/유속/유향',
        '관측부이의 현재 수온·유속·유향과 인근 해역의 예측을 함께 확인해요. 시간별 그래프는 과거 관측과 미래 예측을 보여줘요.',
        alternateSource: 'KHOA_ROMS', alternateScope: 'area'),
  ],
  [
    _ExtraTopic(
        'HRFCO_RIVER_FLOW', '수위 및 유량', '하천 관측 지점의 물 높이와 초당 흐르는 물의 양을 함께 확인해요.'),
    _ExtraTopic('KWATER_RIVER_LEVEL', 'K-water 하천 수위',
        'K-water가 제공하는 하천 관측소의 수위와 제공된 우량 자료를 확인해요.'),
    _ExtraTopic('KWATER_DAM', '댐 보 운영', '댐·보의 수위와 유입량·방류량 등 제공된 운영 자료를 확인해요.',
        scope: 'dam'),
  ],
];

class ExtraTab extends StatefulWidget {
  final ApiClient? client;
  final KmaGrid? grid;
  final bool active;
  final DateTime? now;
  final DeviceCoordinates? coordinates;

  const ExtraTab(
      {super.key,
      required this.client,
      required this.grid,
      required this.active,
      this.now,
      this.coordinates});

  @override
  State<ExtraTab> createState() => _ExtraTabState();
}

class _ExtraTabState extends State<ExtraTab>
    with SingleTickerProviderStateMixin {
  late final TabController _waterTabs;
  final _tabSources = <int, String>{};
  final _marineSelections = <String, String>{};
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
    _waterTabs = TabController(length: 2, vsync: this);
    if (widget.active) _loadCatalog();
  }

  @override
  void dispose() {
    _waterTabs.dispose();
    super.dispose();
  }

  int? _waterTabFor(Object? source) {
    if (source == 'KHOA_TIDE_EXTREME') return 0;
    for (var index = 0; index < _waterTopics.length; index++) {
      if (_waterTopics[index].any((topic) => topic.contains(source))) {
        return index;
      }
    }
    return null;
  }

  _ExtraTopic? _topicFor(Object? source) => _waterTopics
      .expand((topics) => topics)
      .where((topic) => topic.contains(source))
      .firstOrNull;

  void _rememberWaterTab(Map<String, dynamic>? group) {
    final index = _waterTabFor(group?['source']);
    if (index == null) return;
    _waterTabs.index = index;
    _tabSources[index] = group!['source'] as String;
  }

  Map<String, dynamic> _groupForTopic(_ExtraTopic topic) {
    final groups = _groups.where((group) => topic.contains(group['source']));
    return groups
            .where((group) => group['source'] == _tabSources[_waterTabs.index])
            .firstOrNull ??
        groups
            .where((group) => _maps(group['targets']).isNotEmpty)
            .firstOrNull ??
        groups.firstOrNull ??
        {
          'source': topic.source,
          'title': topic.title,
          'scope': topic.scope,
          'targets': <Map<String, dynamic>>[]
        };
  }

  bool _isMarine(Object? source) =>
      source == 'KHOA_ROMS' || source == 'KHOA_BUOY_OBS';

  bool get _ripCurrentOutOfSeason {
    final month = (widget.now ?? DateTime.now())
        .toUtc()
        .add(const Duration(hours: 9))
        .month;
    return month < 6 || month > 9;
  }

  bool _unavailableSeason(Map<String, dynamic>? group) =>
      group?['source'] == 'KHOA_RIP_CURRENT' && _ripCurrentOutOfSeason;

  Map<String, dynamic>? _defaultTarget(Map<String, dynamic>? group,
      {String? previousId}) {
    if (_unavailableSeason(group)) return null;
    final targets = _maps(group?['targets']);
    final previous = targets.where((t) => t['id'] == previousId).firstOrNull;
    if (previous != null) return previous;
    if (!_isMarine(group?['source'])) return targets.firstOrNull;
    final candidates = targets
        .where((t) => t['id'] != 'GRID' && t['hasData'] != false)
        .toList();
    candidates.sort((a, b) => ((a['distanceKm'] as num?)?.toDouble() ??
            double.infinity)
        .compareTo((b['distanceKm'] as num?)?.toDouble() ?? double.infinity));
    return candidates.firstOrNull;
  }

  Map<String, dynamic> _groupForSource(_ExtraTopic topic, String source) =>
      _groups.where((group) => group['source'] == source).firstOrNull ??
      {
        'source': source,
        'title': topic.title,
        'scope': source == topic.source
            ? topic.scope
            : topic.alternateScope ?? topic.scope,
        'targets': <Map<String, dynamic>>[],
      };

  void _selectWaterTab(int index) {
    final topics = _waterTopics[index];
    final previous =
        topics.where((topic) => topic.contains(_tabSources[index])).firstOrNull;
    final topic = previous ??
        topics
            .where((topic) => _groups.any((group) =>
                topic.contains(group['source']) &&
                _maps(group['targets']).isNotEmpty))
            .firstOrNull ??
        topics.first;
    _selectGroup(_groupForTopic(topic));
  }

  @override
  void didUpdateWidget(covariant ExtraTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    final positionChanged = oldWidget.grid != widget.grid ||
        oldWidget.coordinates?.latitude != widget.coordinates?.latitude ||
        oldWidget.coordinates?.longitude != widget.coordinates?.longitude;
    if (positionChanged) {
      ++_request;
      _marineSelections.clear();
      _selectedTarget = null;
      _records = [];
      _loadingCatalog = false;
      _loadingRecords = false;
    }
    if (widget.active &&
        (!oldWidget.active ||
            oldWidget.client != widget.client ||
            positionChanged)) {
      _loadCatalog(resetTarget: positionChanged);
    }
  }

  List<Map<String, dynamic>> _maps(Object? value) => value is List
      ? value
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList()
      : [];

  Future<void> _loadCatalog({bool resetTarget = false}) async {
    final client = widget.client;
    final grid = widget.grid;
    if (client == null || grid == null) return;
    final request = ++_request;
    if (resetTarget) _marineSelections.clear();
    setState(() {
      _loadingCatalog = true;
      _loadingRecords = false;
      _error = null;
    });
    try {
      final data = await client.get('/api/v1/weather/extra/catalog', query: {
        'nx': '${grid.nx}',
        'ny': '${grid.ny}',
        if (widget.coordinates != null) ...{
          'latitude': '${widget.coordinates!.latitude}',
          'longitude': '${widget.coordinates!.longitude}',
        }
      });
      if (!mounted || request != _request) return;
      final groups = _maps(data['groups']);
      final selectable = groups
          .where((group) => group['source'] != 'KHOA_TIDE_EXTREME')
          .toList();
      final previousSource = _selectedGroup?['source'];
      final selected = selectable
              .where((group) => group['source'] == previousSource)
              .firstOrNull ??
          selectable
              .where((group) =>
                  _waterTabFor(group['source']) == _waterTabs.index &&
                  _maps(group['targets']).isNotEmpty)
              .firstOrNull ??
          selectable
              .where(
                  (group) => _waterTabFor(group['source']) == _waterTabs.index)
              .firstOrNull ??
          selectable
              .where((group) =>
                  group['scope'] != 'grid' &&
                  _maps(group['targets']).isNotEmpty)
              .firstOrNull ??
          selectable.firstOrNull;
      final target = _defaultTarget(selected,
          previousId: resetTarget || selected?['source'] != previousSource
              ? null
              : _selectedTarget?['id'] as String?);
      setState(() {
        _groups = groups;
        _selectedGroup = selected;
        _rememberWaterTab(selected);
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
        _topicFor(source)?.alternateSource != null ||
        _unavailableSeason(_selectedGroup) ||
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
    final sameTopic = _topicFor(_selectedGroup?['source']) != null &&
        _topicFor(_selectedGroup?['source']) == _topicFor(group['source']);
    final target = _defaultTarget(group,
        previousId: _isMarine(group['source'])
            ? _marineSelections[group['source']]
            : sameTopic
                ? (_selectedTarget?['id'] as String?)
                : null);
    setState(() {
      _selectedGroup = group;
      _rememberWaterTab(group);
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
    if (_isMarine(_selectedGroup?['source'])) {
      _marineSelections[_selectedGroup!['source'] as String] = id!;
    }
    setState(() => _selectedTarget = selected);
    _loadRecords();
  }

  String _category(Map<String, dynamic> group) {
    final source = '${group['source']}';
    final waterTab = _waterTabFor(source);
    if (waterTab != null) return waterTab == 0 ? '바다' : '하천';
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

  String _emptyTargetMessage(Map<String, dynamic> group) =>
      switch (group['scope']) {
        'report' => '보고된 자료가 없어요',
        'beach' => '현재 조회할 해수욕장 자료가 없어요. 자료가 제공되면 아래 목록에서 해수욕장을 선택할 수 있어요.',
        'area' => '현재 조회할 해역 예측 자료가 없어요. 자료가 제공되면 아래 목록에서 해역을 선택할 수 있어요.',
        _ => '현재 선택할 ${_targetLabel(group).replaceAll(' 선택', '')} 자료가 없어요.',
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
          ExtraChipRow(children: [
            for (final group in groups)
              ChoiceChip(
                key: ValueKey('extra-source-${group['source']}'),
                showCheckmark: false,
                label: Text('${group['title']}',
                    style: const TextStyle(
                        fontFamily: WeatherCareTheme.fontSuite)),
                selected: _selectedGroup?['source'] == group['source'],
                onSelected: _loadingCatalog ? null : (_) => _selectGroup(group),
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

  List<Widget> _dataContent() {
    final group = _selectedGroup;
    final topic = _topicFor(group?['source']);
    final targets = _maps(group?['targets']);
    final outOfSeason = _unavailableSeason(group);
    final timeline = group?['scope'] != 'report' &&
        _records.isNotEmpty &&
        _records.every((entry) => _recordTime(entry['time']) != null);
    return [
      if (group != null) ...[
        Text(topic?.title ?? '${group['title']}',
            style: Theme.of(context).textTheme.titleLarge),
        if (topic != null) ...[
          const SizedBox(height: 8),
          Container(
            key: const ValueKey('extra-description-box'),
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                color: WeatherCareTheme.of(context).surfaceMuted,
                borderRadius: BorderRadius.circular(14)),
            child: Text(topic.description,
                key: const ValueKey('extra-topic-description'),
                style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
        const SizedBox(height: 28),
        if (topic?.alternateSource != null &&
            widget.client != null &&
            widget.grid != null)
          MarineDataPanel(
            key: ValueKey('marine-panel-${topic!.source}'),
            client: widget.client!,
            grid: widget.grid!,
            now: widget.now,
            observationGroup: _groupForSource(topic, topic.source),
            forecastGroup: _groupForSource(topic, topic.alternateSource!),
            selectedId: _marineSelections[topic.source],
            onSelected: (id) => _marineSelections[topic.source] = id,
          )
        else ...[
          const SizedBox(height: 12),
          if ((targets.isEmpty || outOfSeason) && !_loadingCatalog) ...[
            Text(
                outOfSeason
                    ? '이안류 정보 제공 시기가 아니에요. 6~9월에 제공돼요.'
                    : _emptyTargetMessage(group),
                key: ValueKey('extra-target-status-${group['source']}'),
                style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 12),
          ],
          if (group['scope'] != 'grid' && !outOfSeason)
            DropdownButtonFormField<String>(
              key: ValueKey(
                  'extra-target-${group['source']}-${_selectedTarget?['id']}'),
              initialValue: _selectedTarget?['id'] as String?,
              isExpanded: true,
              menuMaxHeight: 360,
              decoration: InputDecoration(
                labelText: _targetLabel(group),
                helperText: targets.length == 1
                    ? '현재 조회 가능한 ${_targetLabel(group).replaceAll(' 선택', '')} 자료는 1개예요.'
                    : null,
                helperMaxLines: 2,
                prefixIcon: const Icon(Icons.place_outlined),
                border: const OutlineInputBorder(),
              ),
              hint: Text('${_targetLabel(group).replaceAll(' 선택', '')} 없음'),
              items: [
                for (final target in targets)
                  DropdownMenuItem(
                    value: '${target['id']}',
                    child: Text(
                        _isMarine(group['source']) &&
                                target['distanceKm'] is num
                            ? '${target['name']} · 약 ${(target['distanceKm'] as num).toStringAsFixed(1)}km'
                            : '${target['name']} (${target['id']})',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: targets.isEmpty ? null : _selectTarget,
            ),
          if (_selectedTarget == null && targets.isNotEmpty && !outOfSeason)
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
            Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text(group['scope'] == 'report'
                    ? '보고된 자료가 없어요'
                    : '아직 저장된 자료가 없어요.')),
          if (_records.isNotEmpty && !outOfSeason) ...[
            const SizedBox(height: 16),
            if (timeline)
              ExtraDataOverview(
                key: ValueKey(
                    'extra-overview-${group['source']}-${_selectedTarget?['id']}'),
                records: _records,
                source: '${group['source']}',
                targetName: '${_selectedTarget?['name'] ?? group['title']}',
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
      ],
      if (_error != null) _errorNotice(),
    ];
  }

  Widget _errorNotice() => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(children: [
          Expanded(child: Text(_error!)),
          TextButton(
            onPressed: _selectedTarget == null ? _loadCatalog : _loadRecords,
            child: const Text('다시 시도'),
          ),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final palette = WeatherCareTheme.of(context);
    final topics = _waterTopics[_waterTabs.index];
    final waterSelected = _waterTabFor(_selectedGroup?['source']) != null;
    final otherGroups = _groups
        .where((group) => _waterTabFor(group['source']) == null)
        .toList();
    final categories = <String, List<Map<String, dynamic>>>{};
    for (final group in otherGroups) {
      categories.putIfAbsent(_category(group), () => []).add(group);
    }
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
                subtitle: '바다와 하천 자료를 항목별로 확인해요',
                icon: Icons.query_stats_rounded),
            const SizedBox(height: 20),
            Container(
              key: const ValueKey('extra-water-box'),
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: palette.surfaceDecoration(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AbsorbPointer(
                    absorbing: _loadingCatalog,
                    child: TabBar(
                      key: const ValueKey('extra-water-tabs'),
                      controller: _waterTabs,
                      onTap: _selectWaterTab,
                      tabs: const [
                        Tab(key: ValueKey('extra-tab-sea'), text: '바다'),
                        Tab(key: ValueKey('extra-tab-river'), text: '하천'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Offstage(
                    offstage: _waterTabs.index != 0,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: MarineTideSummary(
                        client: widget.client,
                        grid: widget.grid,
                        group: _groups
                            .where((group) =>
                                group['source'] == 'KHOA_TIDE_EXTREME')
                            .firstOrNull,
                        loadingCatalog: _loadingCatalog,
                        now: widget.now,
                      ),
                    ),
                  ),
                  ExtraChipRow(
                      key: const ValueKey('extra-topic-chips'),
                      children: [
                        for (final topic in topics)
                          ChoiceChip(
                            key: ValueKey('extra-source-${topic.source}'),
                            label: Text(topic.title,
                                style: const TextStyle(
                                    fontFamily: WeatherCareTheme.fontSuite)),
                            showCheckmark: false,
                            selectedColor: palette.primaryDeep,
                            backgroundColor: palette.surfaceMuted,
                            labelStyle: TextStyle(
                                color: topic.contains(_selectedGroup?['source'])
                                    ? palette.onPrimary
                                    : palette.textPrimary),
                            selected: topic.contains(_selectedGroup?['source']),
                            onSelected: _loadingCatalog
                                ? null
                                : (_) => _selectGroup(_groupForTopic(topic)),
                          ),
                      ]),
                  const SizedBox(height: 20),
                  if (_loadingCatalog)
                    const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(child: CircularProgressIndicator()))
                  else if (widget.grid == null)
                    const Text('먼저 날씨 지역을 선택해주세요.')
                  else if (widget.client == null)
                    const Text('서버 연결을 확인하고 있어요.')
                  else if (waterSelected)
                    ..._dataContent()
                  else ...[
                    const Text('위 항목을 선택해 바다·하천 자료를 확인해요.'),
                    if (_error != null && _selectedGroup == null)
                      _errorNotice(),
                  ],
                ],
              ),
            ),
            if (categories.isNotEmpty) ...[
              const SizedBox(height: 16),
              for (final category in categories.entries)
                _categoryBox(category.key, category.value),
              if (_selectedGroup != null && !waterSelected) ..._dataContent(),
            ],
          ],
        ),
      ),
    );
  }
}
