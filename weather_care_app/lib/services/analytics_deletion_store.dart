import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AnalyticsDeletionRecord {
  final String appInstanceId;
  final bool submitted;

  const AnalyticsDeletionRecord({
    required this.appInstanceId,
    required this.submitted,
  });
}

abstract class AnalyticsDeletionPersistence {
  Future<AnalyticsDeletionRecord?> read();
  Future<void> saveIdentifier(String appInstanceId);
  Future<void> markSubmitted(String appInstanceId);
  Future<void> clear();
}

class AnalyticsDeletionStore implements AnalyticsDeletionPersistence {
  AnalyticsDeletionStore({
    required this.readValue,
    required this.writeValue,
    required this.deleteValue,
  });

  static const _key = 'analytics_deletion_record_v1';
  final Future<String?> Function() readValue;
  final Future<void> Function(String) writeValue;
  final Future<void> Function() deleteValue;

  static final instance = AnalyticsDeletionStore(
    readValue: () => const FlutterSecureStorage().read(key: _key),
    writeValue: (value) =>
        const FlutterSecureStorage().write(key: _key, value: value),
    deleteValue: () => const FlutterSecureStorage().delete(key: _key),
  );

  @override
  Future<AnalyticsDeletionRecord?> read() async {
    final encoded = await readValue();
    if (encoded == null) return null;
    final value = jsonDecode(encoded);
    if (value is! Map) throw const FormatException('Invalid deletion record');
    final id = value['appInstanceId'];
    final submitted = value['submitted'];
    if (id is! String || id.isEmpty || id.length > 256 || submitted is! bool) {
      throw const FormatException('Invalid deletion record');
    }
    return AnalyticsDeletionRecord(appInstanceId: id, submitted: submitted);
  }

  @override
  Future<void> saveIdentifier(String appInstanceId) async {
    if (appInstanceId.isEmpty || appInstanceId.length > 256) {
      throw ArgumentError.value(appInstanceId.length, 'appInstanceId');
    }
    final current = await read();
    if (current?.appInstanceId == appInstanceId) return;
    await _write(AnalyticsDeletionRecord(
        appInstanceId: appInstanceId, submitted: false));
  }

  @override
  Future<void> markSubmitted(String appInstanceId) async {
    final current = await read();
    if (current?.appInstanceId != appInstanceId) {
      throw StateError('Analytics deletion identifier changed');
    }
    await _write(
        AnalyticsDeletionRecord(appInstanceId: appInstanceId, submitted: true));
  }

  @override
  Future<void> clear() => deleteValue();

  Future<void> _write(AnalyticsDeletionRecord record) => writeValue(jsonEncode({
        'appInstanceId': record.appInstanceId,
        'submitted': record.submitted,
      }));
}
