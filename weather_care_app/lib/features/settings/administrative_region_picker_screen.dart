import 'package:flutter/material.dart';

import '../../models/selectable_region.dart';
import '../../services/region_catalog.dart';
import 'region_selection_notice.dart';

class AdministrativeRegionPickerScreen extends StatefulWidget {
  final Future<RegionCatalog> Function()? loadCatalog;
  final String? selectedRegionKey;
  final Set<String> savedGridIds;

  const AdministrativeRegionPickerScreen({
    super.key,
    this.loadCatalog,
    this.selectedRegionKey,
    this.savedGridIds = const {},
  });

  @override
  State<AdministrativeRegionPickerScreen> createState() =>
      _AdministrativeRegionPickerScreenState();
}

class _AdministrativeRegionPickerScreenState
    extends State<AdministrativeRegionPickerScreen> {
  final _search = TextEditingController();
  final _path = <ForecastRegion>[];
  late Future<RegionCatalog> _catalog;

  @override
  void initState() {
    super.initState();
    _catalog = _loadCatalog();
  }

  Future<RegionCatalog> _loadCatalog() async => widget.loadCatalog != null
      ? await widget.loadCatalog!()
      : await RegionCatalog.load();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _openRegion(RegionCatalog catalog, ForecastRegion region) {
    if (catalog.childrenOf(region.code).isEmpty) {
      if (!canAddForecastGrid(context, region.gridId, widget.savedGridIds)) {
        return;
      }
      // 공식 지역 목록의 격자는 기상청 대표 위치에 연결된 기존 예보 격자다.
      Navigator.pop(
        context,
        ForecastGridSelection(
          nx: region.nx,
          ny: region.ny,
          regionKey: region.key,
          regionName: region.fullName,
        ),
      );
      return;
    }
    final ancestors = <ForecastRegion>[region];
    var parentCode = region.parentCode;
    while (parentCode.isNotEmpty) {
      final parent = catalog.regions.firstWhere((r) => r.code == parentCode);
      ancestors.insert(0, parent);
      parentCode = parent.parentCode;
    }
    setState(() {
      _path
        ..clear()
        ..addAll(ancestors);
      _search.clear();
    });
    FocusScope.of(context).unfocus();
  }

  void _goToLevel(int length) {
    setState(() {
      _path.removeRange(length, _path.length);
      _search.clear();
    });
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('행정지역명으로 선택')),
      body: SafeArea(
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
                      const Text('지역 목록을 불러오지 못했어요.'),
                      const SizedBox(height: 12),
                      FilledButton.tonal(
                        onPressed: () => setState(() {
                          _catalog = _loadCatalog();
                        }),
                        child: const Text('다시 시도'),
                      ),
                    ],
                  ),
                ),
              );
            }
            final catalog = snapshot.data;
            if (catalog == null) {
              return const Center(child: CircularProgressIndicator());
            }
            final searching = _search.text.trim().isNotEmpty;
            final regions = searching
                ? catalog.search(_search.text)
                : catalog.childrenOf(_path.isEmpty ? '' : _path.last.code);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: TextField(
                    controller: _search,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: '지역명 검색',
                      hintText: '예: 서울 구로3동',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _search.text.isEmpty
                          ? null
                          : IconButton(
                              tooltip: '검색어 지우기',
                              icon: const Icon(Icons.close_rounded),
                              onPressed: () => setState(_search.clear),
                            ),
                    ),
                  ),
                ),
                Expanded(
                  child: CustomScrollView(
                    key: ValueKey(searching
                        ? 'search-${_search.text}'
                        : 'children-${_path.lastOrNull?.code ?? ''}'),
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    slivers: [
                      const SliverToBoxAdapter(
                        child: Padding(
                          padding:
                              EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          child: Text('기상청 대표 위치를 기준으로 날씨를 알려드려요.'),
                        ),
                      ),
                      if (!searching)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                TextButton(
                                  onPressed: () => _goToLevel(0),
                                  child: const Text('전체'),
                                ),
                                for (var i = 0; i < _path.length; i++) ...[
                                  const Icon(Icons.chevron_right_rounded,
                                      size: 18),
                                  TextButton(
                                    onPressed: () => _goToLevel(i + 1),
                                    child: Text(_path[i].displayName),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      if (regions.isEmpty)
                        const SliverFillRemaining(
                          hasScrollBody: false,
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(
                                child: Text('검색 결과가 없어요. 다른 지역명을 입력해주세요.')),
                          ),
                        )
                      else
                        SliverList.builder(
                          itemCount: regions.length,
                          itemBuilder: (context, index) {
                            final region = regions[index];
                            final hasChildren =
                                catalog.childrenOf(region.code).isNotEmpty;
                            final selected =
                                region.key == widget.selectedRegionKey;
                            return ListTile(
                              key: ValueKey('admin-region-${region.key}'),
                              title: Text(searching || !hasChildren
                                  ? region.fullName
                                  : region.displayName),
                              trailing: Icon(hasChildren
                                  ? Icons.chevron_right_rounded
                                  : selected
                                      ? Icons.check_circle_rounded
                                      : Icons.add_location_alt_outlined),
                              selected: selected,
                              onTap: () => _openRegion(catalog, region),
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
