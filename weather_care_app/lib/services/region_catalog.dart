import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/selectable_region.dart';

class RegionCatalog {
  final List<ForecastRegion> regions;
  final String retrievedAt;
  late final Map<String, ForecastRegion> _byKey = {
    for (final r in regions) r.key: r
  };
  late final Map<String, List<ForecastRegion>> _children = _groupChildren();

  RegionCatalog(this.regions, {this.retrievedAt = ''});

  static Future<RegionCatalog> load({AssetBundle? bundle}) async {
    final raw =
        await (bundle ?? rootBundle).loadString('assets/data/kma_regions.json');
    return RegionCatalog.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  factory RegionCatalog.fromJson(Map<String, dynamic> json) {
    final rows = json['regions'];
    if (rows is! List || rows.isEmpty) {
      throw const FormatException('Empty region catalog');
    }
    final names = <String, (String, String)>{};
    for (final row in rows) {
      if (row is! List ||
          row.length != 5 ||
          row[0] is! String ||
          !RegExp(r'^\d{10}$').hasMatch(row[0]) ||
          row[1] is! String ||
          row[2] is! String ||
          (row[2] as String).trim().isEmpty ||
          row[3] is! int ||
          row[4] is! int ||
          row[3] < 1 ||
          row[3] > 149 ||
          row[4] < 1 ||
          row[4] > 253) {
        throw const FormatException('Invalid region row');
      }
      // Only non-leaf codes are used as hierarchy parents.
      names.putIfAbsent(row[0], () => (row[1], row[2]));
    }
    final result = <ForecastRegion>[];
    final keys = <String>{};
    for (final row in rows) {
      final parts = <String>[row[2]];
      var parent = row[1] as String;
      final visited = <String>{row[0]};
      while (parent.isNotEmpty) {
        if (!visited.add(parent) || !names.containsKey(parent)) {
          throw const FormatException('Invalid region hierarchy');
        }
        final entry = names[parent]!;
        if (parts.first != entry.$2) parts.insert(0, entry.$2);
        parent = entry.$1;
      }
      final region = ForecastRegion(
          code: row[0],
          parentCode: row[1],
          name: row[2],
          nx: row[3],
          ny: row[4],
          fullName: parts.join(' '));
      if (!keys.add(region.key)) {
        throw const FormatException('Duplicate region');
      }
      result.add(region);
    }
    return RegionCatalog(List.unmodifiable(result),
        retrievedAt: json['retrievedAt']?.toString() ?? '');
  }

  ForecastRegion? find(String? key) => _byKey[key];
  List<ForecastRegion> childrenOf(String code) => _children[code] ?? const [];
  Map<String, List<ForecastRegion>> _groupChildren() {
    final groups = <String, List<ForecastRegion>>{};
    for (final region in regions) {
      (groups[region.parentCode] ??= []).add(region);
    }
    return groups;
  }

  List<ForecastRegion> search(String query) {
    final tokens = query
        .trim()
        .split(RegExp(r'\s+'))
        .map(_normalize)
        .where((s) => s.isNotEmpty)
        .toList();
    if (tokens.isEmpty) return childrenOf('');
    return regions.where((region) {
      final name = _normalize(region.fullName);
      final withoutNumbers = name.replaceAll(RegExp(r'\d+'), '');
      return tokens.every(
          (token) => name.contains(token) || withoutNumbers.contains(token));
    }).toList();
  }

  static String _normalize(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'\s+'), '')
      .replaceAll(RegExp(r'제(?=\d)'), '')
      .replaceAll('서울시', '서울')
      .replaceAll('부산시', '부산')
      .replaceAll('대구시', '대구')
      .replaceAll('인천시', '인천')
      .replaceAll('광주시', '광주')
      .replaceAll('대전시', '대전')
      .replaceAll('울산시', '울산')
      .replaceAll('세종시', '세종')
      .replaceAll('경상남도', '경남')
      .replaceAll('경상북도', '경북')
      .replaceAll('충청남도', '충남')
      .replaceAll('충청북도', '충북')
      .replaceAll('전라남도', '전남')
      .replaceAll('전라북도', '전북')
      .replaceAll('강원도', '강원')
      .replaceAll('전북도', '전북')
      .replaceAll('제주도', '제주');
}
