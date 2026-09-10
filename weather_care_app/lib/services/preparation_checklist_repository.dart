import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/recommendation.dart';

String preparationDateInKorea(DateTime instant) => instant
    .toUtc()
    .add(const Duration(hours: 9))
    .toIso8601String()
    .substring(0, 10);

Duration untilPreparationMidnight(DateTime instant) {
  final korea = instant.toUtc().add(const Duration(hours: 9));
  return DateTime.utc(korea.year, korea.month, korea.day + 1).difference(korea);
}

class PreparationChecklistRepository {
  static const _storageKey = 'weather_care_preparation_checklist_v1';
  // A new screen must not read before a previous screen's save finishes.
  static Future<void>? _operations;

  const PreparationChecklistRepository();

  Future<Set<RecommendationType>> load(String date) =>
      _withStorage((prefs) async {
        final raw = prefs.get(_storageKey);
        if (raw is! String) return <RecommendationType>{};
        try {
          final json = jsonDecode(raw);
          if (json is! Map ||
              json['date'] != date ||
              json['checked'] is! List) {
            return <RecommendationType>{};
          }
          final checked = json['checked'] as List;
          return RecommendationType.values
              .where((type) => checked.contains(type.apiName))
              .toSet();
        } on FormatException {
          return <RecommendationType>{};
        }
      });

  Future<void> save(String date, Set<RecommendationType> checked) {
    final encoded = jsonEncode({
      'date': date,
      'checked': checked.map((type) => type.apiName).toList(),
    });
    return _withStorage((prefs) async {
      try {
        if (!await prefs.setString(_storageKey, encoded)) {
          throw StateError('Preparation checklist was not saved');
        }
      } catch (_) {
        // A failed write may already have changed the in-memory cache.
        await prefs.reload();
        rethrow;
      }
    });
  }

  Future<T> _withStorage<T>(
    Future<T> Function(SharedPreferences preferences) operation,
  ) {
    final result = (_operations ?? Future<void>.value()).then(
      (_) async => operation(await SharedPreferences.getInstance()),
    );
    late final Future<void> completion;
    void complete() {
      if (identical(_operations, completion)) _operations = null;
    }

    completion = result.then<void>(
      (_) => complete(),
      onError: (Object _, StackTrace __) => complete(),
    );
    _operations = completion;
    return result;
  }
}
