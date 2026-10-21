import '../../../utils/weather_number.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../../../services/api_client.dart';
import '../../../services/current_location_service.dart';
import '../../../services/kma_grid.dart';
import '../../../services/data_station_selection.dart';
import '../../../theme/weather_theme.dart';
import '../widgets/extra_data_overview.dart';
import '../widgets/extra_chip_row.dart';
import '../widgets/water_data_panel.dart';
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

  String get helpTitle {
    final last = title.runes.last;
    final hasFinalConsonant =
        last >= 0xAC00 && last <= 0xD7A3 && (last - 0xAC00) % 28 != 0;
    return '$title${hasFinalConsonant ? '이란' : '란'}?';
  }

  String get help => switch (source) {
        'KHOA_TIDE_OBS' =>
          '만조는 바닷물 높이가 가장 높아질 때, 간조는 가장 낮아질 때예요. 선택한 관측소의 오늘 남은 첫 만조·간조 시각을 표시하고, 모두 지나면 마지막 시각을 표시해요.\n\n조위는 기준면에서 잰 바닷물 표면의 높이예요. 밀물과 썰물에 따라 달라지며 관측소마다 기준면이 달라요.',
        'KHOA_RIP_CURRENT' =>
          '이안류는 해안에서 바다 쪽으로 빠르게 빠져나가는 물의 흐름이에요.\n\n위험지수는 선택한 해수욕장의 이안류 발생 가능성을 나타내요.',
        'NIFS_JELLYFISH_DETAIL' =>
          '해파리 정보는 보고서에 기록된 출현 해역과 종류 등을 알려줘요. 보고가 없다는 뜻은 해파리가 없거나 안전하다는 뜻이 아니에요. 현장의 해파리 특보와 입수 안내도 확인해주세요.',
        'KHOA_BUOY_OBS' =>
          '수온은 바닷물의 온도예요.\n\n유속은 바닷물이 흐르는 빠르기예요.\n\n유향은 흐르는 방향이에요. 북쪽을 0°, 동쪽을 90°, 남쪽을 180°, 서쪽을 270°로 나타내요.\n\n관측과 예측을 구분해 확인해주세요.',
        'HRFCO_RIVER_FLOW' =>
          '한강홍수통제소와 K-water의 하천 관측소를 함께 보여줘요. 같은 관측소 코드는 하나로 합치고, 한강홍수통제소 목록에 없는 K-water 관측소도 포함해요.\n\n수위는 관측소의 기준면에서 잰 물 표면의 높이예요. 관측소마다 기준면이 다를 수 있어요.\n\n유량은 1초 동안 하천의 한 단면을 통과하는 물의 부피예요.',
        'KWATER_DAM' =>
          '댐은 물을 모아 저장하고 조절하는 시설이에요.\n\n보는 하천을 가로질러 수위를 조절하는 시설이에요.\n\n유입량은 시설로 들어오는 물의 양이에요.\n\n방류량은 시설에서 내보내는 물의 양이에요.',
        _ => description,
      };
}

const _waterTopics = [
  [
    _ExtraTopic('KHOA_TIDE_OBS', '만조·간조/조위',
        '선택한 관측소의 만조·간조와 현재 조위, 오늘 예측 최저·최고를 함께 확인해요.',
        alternateSource: 'KHOA_TIDE_HOURLY'),
    _ExtraTopic('KHOA_RIP_CURRENT', '이안류', '해수욕장을 선택해 이안류 위험지수와 안내를 확인해요.',
        scope: 'beach'),
    _ExtraTopic('NIFS_JELLYFISH_DETAIL', '해파리',
        '아래에서 보고서를 선택하면 해당 보고서의 해파리 출현 해역과 내용을 볼 수 있어요.',
        scope: 'report'),
    _ExtraTopic(
        'KHOA_BUOY_OBS', '수온/유속/유향', '관측부이의 현재 수온·유속·유향과 인근 해역의 예측을 함께 확인해요.',
        alternateSource: 'KHOA_ROMS', alternateScope: 'area'),
  ],
  [
    _ExtraTopic('HRFCO_RIVER_FLOW', '수위/유량',
        '선택한 하천 지점의 현재 수위·유량과 오늘 관측 최저·최고를 함께 확인해요.'),
    _ExtraTopic(
        'KWATER_DAM', '댐/보', '댐·보의 현재 수위·유입량·방류량과 오늘 관측 최저·최고를 함께 확인해요.',
        scope: 'dam'),
  ],
];

class ExtraTab extends StatefulWidget {
  final ApiClient? client;
  final KmaGrid? grid;
  final bool active;
  final DateTime? now;
  final DeviceCoordinates? coordinates;
  final Widget? advertisement;

  const ExtraTab(
      {super.key,
      required this.client,
      required this.grid,
      required this.active,
      this.now,
      this.advertisement,
      this.coordinates});

  @override
  State<ExtraTab> createState() => _ExtraTabState();
}

class _ExtraTabState extends State<ExtraTab>
    with SingleTickerProviderStateMixin {
  late final TabController _waterTabs;
  final _tabSources = <int, String>{};
  final _marineSelections = <String, String>{};
  final _stationSelection = const DataStationSelection();
  final _selectedDataKey = GlobalKey();
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
    final nearest = nearestDataStation(targets);
    if (nearest != null) return nearest;
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
      final remembered = _stationSelection.load(grid);
      final data = await client.get('/api/v1/weather/extra/catalog', query: {
        'nx': '${grid.nx}',
        'ny': '${grid.ny}',
        if (widget.coordinates != null) ...{
          'latitude': '${widget.coordinates!.latitude}',
          'longitude': '${widget.coordinates!.longitude}',
        }
      });
      final selections = await remembered;
      if (!mounted || request != _request) return;
      _marineSelections
        ..clear()
        ..addAll(selections);
      final groups = _maps(data['groups'])
          .where((group) => !['KMA_LIGHTNING', 'KWATER_RIVER_LEVEL']
              .contains(group['source']))
          .toList();
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
          previousId: _marineSelections[selected?['source']]);
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
        _waterTabFor(source) == 1 ||
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
        previousId: _marineSelections[group['source']] ??
            (sameTopic ? (_selectedTarget?['id'] as String?) : null));
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
    if (selected == null) return;
    _rememberStation(_selectedGroup!['source'] as String, id!);
    if (id == _selectedTarget?['id']) {
      _scrollToSelectedData();
      return;
    }
    setState(() => _selectedTarget = selected);
    final source = _selectedGroup?['source'];
    final pending = _loadRecords();
    final request = _request;
    pending.then((_) {
      if (mounted &&
          request == _request &&
          _selectedGroup?['source'] == source &&
          _selectedTarget?['id'] == id) {
        _scrollToSelectedData();
      }
    });
  }

  void _scrollToSelectedData() {
    final request = _request;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final dataContext = _selectedDataKey.currentContext;
      if (!mounted || request != _request || dataContext == null) return;
      Scrollable.ensureVisible(dataContext,
          alignment: .5,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut);
    });
  }

  void _rememberStation(String source, String id) {
    _marineSelections[source] = id;
    final grid = widget.grid;
    if (grid != null) _stationSelection.save(grid, source, id);
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
        'report' => '보고된 자료없음',
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
        Row(children: [
          Expanded(
              child: Text(topic?.title ?? '${group['title']}',
                  style: Theme.of(context).textTheme.titleLarge)),
          if (topic != null)
            IconButton(
              key: ValueKey('extra-help-${topic.source}'),
              tooltip: '${topic.title} 설명',
              iconSize: 18,
              icon: const Icon(Icons.error_outline_rounded),
              onPressed: () => showDialog<void>(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text(topic.helpTitle),
                  content: SingleChildScrollView(child: Text(topic.help)),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('확인'))
                  ],
                ),
              ),
            ),
        ]),
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
        if ((topic?.alternateSource != null ||
                _waterTabFor(group['source']) == 1) &&
            widget.client != null &&
            widget.grid != null)
          WaterDataPanel(
            key: ValueKey('water-panel-${topic!.source}'),
            client: widget.client!,
            grid: widget.grid!,
            now: widget.now,
            observationGroup: _groupForSource(topic, topic.source),
            forecastGroup: topic.alternateSource == null
                ? const {'targets': <Map<String, dynamic>>[]}
                : _groupForSource(topic, topic.alternateSource!),
            selectedId: _marineSelections[topic.source],
            onSelected: (id) => _rememberStation(topic.source, id),
          )
        else ...[
          const SizedBox(height: 12),
          if ((targets.isEmpty || outOfSeason) &&
              !_loadingCatalog &&
              group['scope'] != 'report') ...[
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
              hint: Text(group['scope'] == 'report'
                  ? '보고된 자료없음'
                  : '${_targetLabel(group).replaceAll(' 선택', '')} 없음'),
              disabledHint:
                  group['scope'] == 'report' ? const Text('보고된 자료없음') : null,
              selectedItemBuilder: group['scope'] == 'report'
                  ? (context) => [
                        for (final target in targets)
                          Text(
                              !_loadingRecords &&
                                      _error == null &&
                                      _records.isEmpty &&
                                      target['id'] == _selectedTarget?['id']
                                  ? '보고된 자료없음'
                                  : '${target['name']}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                      ]
                  : null,
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
          if (group['scope'] == 'report') const SizedBox(height: 24),
          if (['station', 'beach', 'dam', 'area'].contains(group['scope']) &&
              !outOfSeason)
            Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                    key: ValueKey('extra-nearest-${group['source']}'),
                    style: TextButton.styleFrom(
                        textStyle: const TextStyle(fontSize: 12),
                        iconSize: 16,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: const Size(0, 32),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                    onPressed: nearestDataStation(targets) == null
                        ? null
                        : () => _selectTarget(
                            '${nearestDataStation(targets)!['id']}'),
                    icon: const Icon(Icons.near_me_outlined),
                    label: Text(
                        '가장 가까운 ${_targetLabel(group).replaceAll(' 선택', '')} 자동선택'))),
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
              _records.isEmpty &&
              group['scope'] != 'report')
            Padding(
                padding: EdgeInsets.only(top: 12),
                child: const Text('아직 저장된 자료가 없어요.')),
          if (kDebugMode && group['source'] == 'NIFS_JELLYFISH_DETAIL')
            const Card(
                child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      key: ValueKey('jellyfish-example'),
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('[예시] 해파리 보고서',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w700)),
                        SizedBox(height: 16),
                        Text(
                            '화면 확인용 가상 자료이며 실제 관측·특보가 아니에요.\n\n출현 해역: 부산 연안(예시)\n해파리 종류: 노무라입깃해파리(예시)\n출현 내용: 일부 해역에서 출현 보고(예시)\n현장 안내: 해파리를 만지지 말고 해수욕장 안내를 확인해주세요.')
                      ],
                    ))),
          if (_records.isNotEmpty && !outOfSeason) ...[
            const SizedBox(height: 16),
            if (timeline)
              ExtraDataOverview(
                currentKey: _selectedDataKey,
                key: ValueKey(
                    'extra-overview-${group['source']}-${_selectedTarget?['id']}'),
                records: _records,
                source: '${group['source']}',
                targetName: '${_selectedTarget?['name'] ?? group['title']}',
                labelFor: _valueLabel,
                unitFor: _unit,
                timeFor: _recordTime,
                timeLabel: _timeLabel,
              )
            else
              SizedBox(key: _selectedDataKey),
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
                eyebrow: 'ADVANCED',
                title: '심화 날씨 정보',
                subtitle: '바다와 하천의 전문 관측 정보를 확인해요',
                icon: Icons.sensors_rounded),
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
            if (widget.advertisement != null) ...[
              const SizedBox(height: 16),
              widget.advertisement!,
            ],
          ],
        ),
      ),
    );
  }
}
