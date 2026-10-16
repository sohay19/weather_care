import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/selectable_region.dart';
import '../../models/postal_address.dart';
import '../../services/address_search_service.dart';
import '../../services/region_catalog.dart';
import '../../theme/weather_theme.dart';
import 'postal_address_picker_screen.dart';
import 'region_selection_notice.dart';

class AddressRegionPickerScreen extends StatefulWidget {
  final AddressSearchService searchService;
  final Future<RegionCatalog> Function()? loadCatalog;
  final PostalAddressPicker? pickAddress;
  final Set<String> savedGridIds;

  const AddressRegionPickerScreen({
    super.key,
    this.searchService = const PlatformAddressSearchService(),
    this.loadCatalog,
    this.pickAddress,
    this.savedGridIds = const {},
  });

  @override
  State<AddressRegionPickerScreen> createState() =>
      _AddressRegionPickerScreenState();
}

class _AddressRegionPickerScreenState extends State<AddressRegionPickerScreen> {
  final _search = TextEditingController();
  List<_AddressMatch> _results = [];
  _AddressMatch? _selected;
  bool _loading = false;
  int _request = 0;
  String _message = '도로명주소나 지번주소를 입력해주세요.';

  @override
  void dispose() {
    _request++;
    _search.dispose();
    super.dispose();
  }

  void _clearResults() {
    setState(() {
      _request++;
      _loading = false;
      _selected = null;
      _results = [];
      _message = '도로명주소나 지번주소를 입력해주세요.';
    });
  }

  Future<void> _searchAddress() async {
    final query = _search.text.trim();
    if (query.isEmpty || _loading) return;
    final request = ++_request;
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _selected = null;
      _results = [];
      _message = '주소를 찾고 있어요.';
    });
    try {
      final postal =
          await (widget.pickAddress ?? showPostalAddressPicker)(context, query);
      if (!mounted || request != _request) return;
      if (postal == null) {
        setState(() {
          _loading = false;
          _message = '도로명주소나 지번주소를 입력해주세요.';
        });
        return;
      }
      final catalog =
          await (widget.loadCatalog?.call() ?? RegionCatalog.load());
      if (!mounted || request != _request) return;
      final results = await widget.searchService
          .search(postal.locationQuery)
          .timeout(const Duration(seconds: 12));
      if (!mounted || request != _request) return;
      final matches = <_AddressMatch>[];
      for (final address in results) {
        if (!address.latitude.isFinite ||
            !address.longitude.isFinite ||
            address.latitude < 32 ||
            address.latitude > 39 ||
            address.longitude < 124 ||
            address.longitude > 132) {
          continue;
        }
        final grid = address.grid;
        final regions = catalog.regions
            .where((r) =>
                r.nx == grid.nx &&
                r.ny == grid.ny &&
                catalog.childrenOf(r.code).isEmpty)
            .toList();
        int nameMatch(ForecastRegion region) =>
            region.fullName.split(' ').where(address.address.contains).length;
        regions.sort((a, b) => nameMatch(b).compareTo(nameMatch(a)));
        matches.add(_AddressMatch(address, regions, postal));
      }
      setState(() {
        _loading = false;
        _results = matches;
        _message = matches.isEmpty ? '국내 주소를 찾지 못했어요. 시·군·구와 번지까지 입력해보세요.' : '';
      });
    } catch (error) {
      if (!mounted || request != _request) return;
      setState(() {
        _loading = false;
        _message = switch (error) {
          TimeoutException() => '주소 검색이 지연되고 있어요. 잠시 후 다시 검색해주세요.',
          MissingPluginException() ||
          UnsupportedError() =>
            '이 기기에서는 주소 검색을 사용할 수 없어요. 행정지역명이나 지도에서 선택해주세요.',
          _ => '주소를 검색하지 못했어요. 인터넷 연결을 확인하고 다시 검색해주세요.',
        };
      });
    }
  }

  void _selectRegion(ForecastRegion region) {
    if (!canAddForecastGrid(context, region.gridId, widget.savedGridIds)) {
      return;
    }
    Navigator.pop(
        context,
        ForecastGridSelection(
          nx: region.nx,
          ny: region.ny,
          regionKey: region.key,
          regionName: region.fullName,
        ));
  }

  void _showAddressSearchInfo() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('주소 검색 안내'),
        content: const Text('검색어는 카카오 주소 검색에, 선택한 주소는 기기의 주소 변환 서비스에 전달돼요. '
            '앱에는 주소와 좌표를 저장하지 않고 선택한 예보 구역만 저장해요.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selected;
    return Scaffold(
      appBar: AppBar(title: const Text('주소로 선택')),
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _search,
              textInputAction: TextInputAction.search,
              onChanged: (_) => _clearResults(),
              onSubmitted: (_) => unawaited(_searchAddress()),
              decoration: InputDecoration(
                labelText: '주소 검색',
                hintText: '시·군·구와 도로명 또는 지번',
                suffixIcon: IconButton(
                  tooltip: '주소 검색',
                  onPressed: _loading ? null : _searchAddress,
                  icon: const Icon(Icons.search_rounded),
                ),
              ),
            ),
          ),
          Expanded(
              child: ListView(
            key: ValueKey(selected?.address ?? _message),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            children: [
              Row(children: [
                const Expanded(
                  child: Text('주소의 위치에 해당하는 예보 구역을 찾아요.'),
                ),
                IconButton(
                  key: const ValueKey('address-search-info'),
                  tooltip: '주소 검색 안내',
                  onPressed: _showAddressSearchInfo,
                  icon: const Icon(Icons.info_outline_rounded, size: 18),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: WeatherCareTheme.of(context).primary,
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              if (_loading) const LinearProgressIndicator(),
              if (selected == null) ...[
                if (_message.isNotEmpty) ...[
                  Text(_message),
                  const SizedBox(height: 12),
                ],
                for (final result in _results)
                  Card(
                      child: ListTile(
                    contentPadding: const EdgeInsets.fromLTRB(20, 12, 12, 12),
                    title: _PostalAddressText(address: result.postal),
                    subtitle: result.regions.isEmpty
                        ? const Text('이 주소에 해당하는 예보 구역이 없어요. 지도에서 구역을 선택해주세요.')
                        : null,
                    trailing: result.regions.isEmpty
                        ? null
                        : const Icon(Icons.chevron_right_rounded),
                    onTap: result.regions.isEmpty
                        ? null
                        : () => setState(() => _selected = result),
                  )),
              ] else ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => setState(() => _selected = null),
                    icon: const Icon(Icons.arrow_back_rounded),
                    label: const Text('검색 결과로 돌아가기'),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: WeatherCareTheme.of(context)
                      .surfaceDecoration(radius: 16),
                  child: Material(
                    color: Colors.transparent,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: WeatherCareTheme.of(context).primarySoft,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text('저장할 지역명 선택',
                                  style:
                                      Theme.of(context).textTheme.titleMedium),
                              const SizedBox(height: 8),
                              const Text(
                                  '예보 구역은 약 5km × 5km라 여러 행정지역이 포함될 수 있어요. 표시할 지역명을 선택해주세요.'),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        for (final region in selected.regions)
                          ListTile(
                            key: ValueKey('address-region-${region.key}'),
                            contentPadding: EdgeInsets.zero,
                            title: Text(region.fullName),
                            trailing:
                                const Icon(Icons.add_location_alt_outlined),
                            onTap: () => _selectRegion(region),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          )),
        ]),
      ),
    );
  }
}

class _AddressMatch {
  final AddressSearchResult address;
  final List<ForecastRegion> regions;
  final PostalAddress postal;

  const _AddressMatch(this.address, this.regions, this.postal);
}

class _PostalAddressText extends StatelessWidget {
  final PostalAddress address;
  const _PostalAddressText({required this.address});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(address.roadEstimated ? '도로명주소 · 예상' : '도로명주소',
              style: Theme.of(context)
                  .textTheme
                  .labelMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
          Text(address.roadAddress.isEmpty
              ? '제공된 도로명주소 없음'
              : address.roadAddress),
          const SizedBox(height: 8),
          Text(address.jibunEstimated ? '지번주소 · 예상' : '지번주소',
              style: Theme.of(context)
                  .textTheme
                  .labelMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
          Text(address.jibunAddress.isEmpty
              ? '제공된 지번주소 없음'
              : address.jibunAddress),
        ],
      );
}
