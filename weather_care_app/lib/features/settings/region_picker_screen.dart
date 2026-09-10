import 'package:flutter/material.dart';
import '../../models/selectable_region.dart';
import '../../services/region_catalog.dart';

class RegionPickerScreen extends StatefulWidget {
  final Future<RegionCatalog> Function()? loadCatalog;
  final String? selectedKey;
  const RegionPickerScreen({super.key, this.loadCatalog, this.selectedKey});
  @override
  State<RegionPickerScreen> createState() => _RegionPickerScreenState();
}

class _RegionPickerScreenState extends State<RegionPickerScreen> {
  late Future<RegionCatalog> _catalog;
  final _search = TextEditingController();
  final _scroll = ScrollController();
  final _path = <ForecastRegion>[];
  @override
  void initState() {
    super.initState();
    _catalog = _load();
  }

  Future<RegionCatalog> _load() =>
      widget.loadCatalog?.call() ?? RegionCatalog.load();
  @override
  void dispose() {
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _confirm(ForecastRegion region) async {
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
              scrollable: true,
              title: const Text('이 지역을 사용할까요?'),
              content: Text(
                  '${region.fullName}\n\n이 지역의 대표 예보 지점 기준으로 안내해요. 지역 안에서도 실제 날씨는 다를 수 있어요.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('취소')),
                FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('이 지역 사용'))
              ],
            ));
    if (mounted && confirmed == true) Navigator.pop(context, region);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('지역 직접 선택')),
        body: SafeArea(
            child: Column(children: [
          Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                key: const ValueKey('region-search'),
                controller: _search,
                decoration: InputDecoration(
                    labelText: '지역 이름 검색',
                    hintText: '예: 부산 해운대 좌동',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _search.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: '검색어 지우기',
                            icon: const Icon(Icons.clear),
                            onPressed: () => setState(() => _search.clear()))),
                onChanged: (_) => setState(() {}),
              )),
          Expanded(
              child: FutureBuilder<RegionCatalog>(
                  future: _catalog,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(
                          child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text(
                                        '지역 목록을 불러오지 못했어요. 기존 지역은 변경하지 않았어요.'),
                                    TextButton(
                                        onPressed: () => setState(() {
                                              _catalog = _load();
                                            }),
                                        child: const Text('다시 시도')),
                                  ])));
                    }
                    final catalog = snapshot.data;
                    if (catalog == null) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final searching = _search.text.trim().isNotEmpty;
                    final parent = _path.lastOrNull;
                    final rows = searching
                        ? catalog.search(_search.text)
                        : catalog.childrenOf(parent?.code ?? '');
                    return CustomScrollView(
                        key: const ValueKey('region-results'),
                        controller: _scroll,
                        slivers: [
                          SliverToBoxAdapter(
                              child: Column(children: [
                            if (!searching && parent != null) ...[
                              ListTile(
                                  leading: const Icon(Icons.arrow_back),
                                  title: const Text('상위 지역 보기'),
                                  subtitle: Text(parent.fullName),
                                  onTap: () {
                                    _scroll.jumpTo(0);
                                    setState(() => _path.removeLast());
                                  }),
                              ListTile(
                                  title: Text('${parent.name} 대표 지점 선택'),
                                  trailing: const Icon(Icons.check),
                                  onTap: () => _confirm(parent)),
                            ],
                            if (searching)
                              Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16),
                                  child: Text('검색 결과 ${rows.length}곳')),
                            if (rows.isEmpty)
                              const Padding(
                                  padding: EdgeInsets.all(24),
                                  child: Text(
                                      '일치하는 지역이 없어요. 시·군·구나 읍·면·동 이름으로 다시 검색해주세요.')),
                          ])),
                          SliverList.builder(
                              itemCount: rows.length,
                              itemBuilder: (context, index) {
                                final row = rows[index];
                                final hasChildren =
                                    catalog.childrenOf(row.code).isNotEmpty;
                                return ListTile(
                                    key: ValueKey('region-${row.key}'),
                                    title: Text(row.name),
                                    subtitle: Text(row.fullName == row.name
                                        ? '하위 지역 보기'
                                        : row.fullName),
                                    leading: row.key == widget.selectedKey
                                        ? const Icon(Icons.check_circle_outline)
                                        : null,
                                    trailing: Icon(hasChildren && !searching
                                        ? Icons.chevron_right
                                        : Icons.add_location_alt_outlined),
                                    onTap: () {
                                      if (hasChildren && !searching) {
                                        _scroll.jumpTo(0);
                                        setState(() => _path.add(row));
                                      } else {
                                        _confirm(row);
                                      }
                                    });
                              }),
                          SliverToBoxAdapter(
                              child: Padding(
                                  padding: EdgeInsets.all(16),
                                  child: Text(
                                      '출처: 기상청 날씨누리 지역·예보 격자 목록\n지역 목록은 앱에 저장돼 있어요. 실제 날씨 조회에는 인터넷 연결이 필요해요.\n목록 확인일: ${catalog.retrievedAt.split('T').first}'))),
                        ]);
                  })),
        ])),
      );
}
