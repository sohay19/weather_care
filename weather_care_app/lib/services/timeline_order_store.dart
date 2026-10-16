import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Main과 Week에서 같은 기기 설정을 사용한다. null은 계절별 기본 순서다.
class TimelineOrderStore {
  static const storageKey = 'weather_care_timeline_order_v1';
  static const metrics = [
    'weather',
    'precipitation',
    'snowfall',
    'humidity',
    'uv',
    'wind',
  ];
  static final order = ValueNotifier<List<String>?>(null);
  static int _revision = 0;

  static List<String> defaults(int month) => month == 12 || month <= 2
      ? ['weather', 'snowfall', 'precipitation', 'wind', 'humidity', 'uv']
      : ['weather', 'precipitation', 'humidity', 'uv', 'wind', 'snowfall'];

  static Future<void> load() async {
    final revision = _revision;
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getStringList(storageKey);
      if (revision != _revision) return;
      order.value = saved != null &&
              saved.length == metrics.length &&
              saved.toSet().containsAll(metrics)
          ? List.unmodifiable(saved)
          : null;
    } catch (_) {
      // 저장소를 읽지 못하면 현재 순서 또는 계절 기본값으로 표시한다.
    }
  }

  static Future<void> save(List<String>? value) async {
    _revision++;
    final prefs = await SharedPreferences.getInstance();
    try {
      final saved = value == null
          ? await prefs.remove(storageKey)
          : await prefs.setStringList(storageKey, value);
      if (!saved) throw StateError('타임라인 순서를 저장하지 못했어요.');
    } catch (_) {
      await prefs.reload();
      rethrow;
    }
    order.value = value == null ? null : List.unmodifiable(value);
  }
}
