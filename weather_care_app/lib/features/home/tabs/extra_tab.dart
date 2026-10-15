import '../../../utils/weather_number.dart';
import 'package:flutter/material.dart';

import '../../../services/api_client.dart';
import '../../../services/kma_grid.dart';
import '../../../theme/weather_theme.dart';
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
          (groups.isEmpty ? null : groups.first);
      final targets = _maps(selected?['targets']);
      final previousTarget = _selectedTarget?['id'];
      final target =
          targets.where((item) => item['id'] == previousTarget).firstOrNull ??
              (selected?['scope'] == 'grid' || selected?['source'] == 'KHOA_ROMS'
                  ? targets.firstOrNull : null);
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
    final target = group['scope'] == 'grid' || group['source'] == 'KHOA_ROMS'
        ? targets.firstOrNull : null;
    setState(() {
      _selectedGroup = group;
      _selectedTarget = target;
      _records = [];
      _error = null;
      _loadingRecords = false;
    });
    if (target != null) _loadRecords();
  }

  Future<void> _chooseTarget() async {
    final targets = _maps(_selectedGroup?['targets']);
    if (targets.isEmpty) return;
    final selected = await showModalBottomSheet<Map<String, dynamic>>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (context) {
          String search = '';
          return StatefulBuilder(builder: (context, update) {
            final visible = targets
                .where((item) => '${item['name']} ${item['id']}'
                    .toLowerCase()
                    .contains(search.toLowerCase()))
                .take(100)
                .toList();
            return SafeArea(
                child: Padding(
              padding: EdgeInsets.fromLTRB(
                  16, 8, 16, MediaQuery.viewInsetsOf(context).bottom + 16),
              child: SizedBox(
                  height: MediaQuery.sizeOf(context).height * 0.65,
                  child: Column(children: [
                    Text('${_selectedGroup?['title']} 선택',
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 12),
                    TextField(
                        autofocus: true,
                        decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.search),
                            hintText: '이름 또는 코드 검색'),
                        onChanged: (value) => update(() => search = value)),
                    const SizedBox(height: 8),
                    Expanded(
                        child: ListView.builder(
                            itemCount: visible.length,
                            itemBuilder: (context, index) {
                              final item = visible[index];
                              return ListTile(
                                  title: Text('${item['name']}'),
                                  subtitle: Text('${item['id']}'),
                                  onTap: () => Navigator.pop(context, item));
                            })),
                  ])),
            ));
          });
        });
    if (!mounted || selected == null) return;
    setState(() => _selectedTarget = selected);
    _loadRecords();
  }

  String _timeLabel(String raw) {
    final date = raw.length >= 10 ? raw.substring(0, 10) : raw;
    if (raw.length < 16) return date;
    return '$date ${raw.substring(11, 16)}';
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

  @override
  Widget build(BuildContext context) {
    final palette = WeatherCareTheme.of(context);
    final group = _selectedGroup;
    final targets = _maps(group?['targets']);
    final hourly = group?['period'] == 'hourly';
    return Container(
      key: const ValueKey('extra-tab'),
      color: palette.background,
      child: RefreshIndicator(
          onRefresh: _loadCatalog,
          child: ListView(
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
                  Wrap(spacing: 8, runSpacing: 6, children: [
                    for (final item in _groups)
                      ChoiceChip(
                          label: Text('${item['title']}'),
                          selected: group?['source'] == item['source'],
                          onSelected: (_) => _selectGroup(item))
                  ]),
                  const SizedBox(height: 20),
                  if (group != null) ...[
                    Text(hourly ? '시간별 자료' : '일자별 자료',
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 5),
                    Text(
                        group['scope'] == 'grid'
                            ? '현재 격자에서 관측된 발생 이력입니다.'
                            : group['source'] == 'KHOA_ROMS' &&
                                    _selectedTarget?['id'] == 'GRID'
                                ? '현재 격자 안 해양 모델 지점의 예측값입니다.'
                                : '선택한 ${group['title']}의 자료입니다. 격자 전체의 값은 아닙니다.',
                        style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: 12),
                    if (group['scope'] != 'grid')
                      OutlinedButton.icon(
                          onPressed: targets.isEmpty ? null : _chooseTarget,
                          icon: const Icon(Icons.place_outlined),
                          label: Text(targets.isEmpty
                              ? '수집된 선택 대상 없음'
                              : _selectedTarget == null
                                  ? '대상 선택'
                                  : '${_selectedTarget!['name']} 변경')),
                    if (_selectedTarget == null && targets.isNotEmpty)
                      const Padding(
                          padding: EdgeInsets.only(top: 12),
                          child: Text('표시할 관측소·시설·해역을 선택해주세요.')),
                    if (_loadingRecords)
                      const Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(child: CircularProgressIndicator())),
                    if (_error != null)
                      Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Row(children: [
                            Expanded(child: Text(_error!)),
                            TextButton(
                                onPressed: _selectedTarget == null
                                    ? _loadCatalog
                                    : _loadRecords,
                                child: const Text('다시 시도'))
                          ])),
                    if (!_loadingRecords &&
                        _error == null &&
                        _selectedTarget != null &&
                        _records.isEmpty)
                      const Padding(
                          padding: EdgeInsets.only(top: 12),
                          child: Text('아직 저장된 자료가 없어요.')),
                    for (final entry in _records)
                      Card(
                          margin: const EdgeInsets.only(top: 10),
                          child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(_timeLabel('${entry['time']}'),
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium),
                                    const SizedBox(height: 8),
                                    for (final value
                                        in Map<String, dynamic>.from(
                                                entry['values'] is Map
                                                    ? entry['values'] as Map
                                                    : {})
                                            .entries)
                                      if (value.value != null)
                                        Padding(
                                            padding: const EdgeInsets.only(
                                                bottom: 3),
                                            child: Text(
                                                '${_valueLabel(value.key)}  ${value.value is num ? formatWeatherNumber(value.value as num) : value.value}${_unit(value.key)}')),
                                  ]))),
                  ],
                ],
              ])),
    );
  }
}
