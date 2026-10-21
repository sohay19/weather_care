import 'package:shared_preferences/shared_preferences.dart';

import 'kma_grid.dart';

Map<String, dynamic>? nearestDataStation(List<Map<String, dynamic>> targets) {
  final located = targets
      .where((target) =>
          target['id'] != 'GRID' &&
          target['distanceKm'] is num &&
          (target['distanceKm'] as num).isFinite &&
          (target['distanceKm'] as num) >= 0)
      .toList()
    ..sort((a, b) {
      final distance =
          (a['distanceKm'] as num).compareTo(b['distanceKm'] as num);
      return distance != 0 ? distance : '${a['id']}'.compareTo('${b['id']}');
    });
  return located.firstOrNull;
}

class DataStationSelection {
  const DataStationSelection();
  String _prefix(KmaGrid grid) =>
      'weather_care_data_station_${grid.nx}_${grid.ny}_';

  Future<Map<String, String>> load(KmaGrid grid) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final prefix = _prefix(grid);
      return {
        for (final key in preferences.getKeys())
          if (key.startsWith(prefix) && preferences.get(key) is String)
            key.substring(prefix.length): preferences.getString(key)!
      };
    } catch (_) {
      return {};
    }
  }

  Future<void> save(KmaGrid grid, String source, String id) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString('${_prefix(grid)}$source', id);
    } catch (_) {
      // 저장소를 사용할 수 없어도 현재 화면의 선택과 자료 조회는 유지한다.
    }
  }
}
