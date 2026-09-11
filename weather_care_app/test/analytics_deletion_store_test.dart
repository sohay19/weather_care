import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:weather_care/services/analytics_deletion_store.dart';

void main() {
  test('stores only the identifier and submission state, then clears them',
      () async {
    String? stored;
    final store = AnalyticsDeletionStore(
      readValue: () async => stored,
      writeValue: (value) async => stored = value,
      deleteValue: () async => stored = null,
    );

    await store.saveIdentifier('analytics-instance-1');
    expect(jsonDecode(stored!), {
      'appInstanceId': 'analytics-instance-1',
      'submitted': false,
    });
    await store.markSubmitted('analytics-instance-1');
    expect((await store.read())?.submitted, isTrue);
    await store.clear();
    expect(await store.read(), isNull);
  });

  test('does not overwrite an accepted request for the same identifier',
      () async {
    String? stored = jsonEncode({
      'appInstanceId': 'analytics-instance-1',
      'submitted': true,
    });
    final store = AnalyticsDeletionStore(
      readValue: () async => stored,
      writeValue: (value) async => stored = value,
      deleteValue: () async => stored = null,
    );

    await store.saveIdentifier('analytics-instance-1');

    expect((await store.read())?.submitted, isTrue);
  });

  test('rejects corrupted or mismatched deletion state', () async {
    String? stored = '{bad';
    final store = AnalyticsDeletionStore(
      readValue: () async => stored,
      writeValue: (value) async => stored = value,
      deleteValue: () async => stored = null,
    );
    await expectLater(store.read(), throwsFormatException);
    stored = jsonEncode({
      'appInstanceId': 'analytics-instance-1',
      'submitted': false,
    });
    await expectLater(
        store.markSubmitted('another-instance'), throwsStateError);
  });
}
