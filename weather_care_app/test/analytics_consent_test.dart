import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:weather_care/features/settings/analytics_consent_control.dart';
import 'package:weather_care/services/analytics_consent.dart';
import 'package:weather_care/services/analytics_deletion_store.dart';

class _DeletionStore implements AnalyticsDeletionPersistence {
  AnalyticsDeletionRecord? value;
  final calls = <String>[];

  _DeletionStore([this.value]);

  @override
  Future<AnalyticsDeletionRecord?> read() async => value;

  @override
  Future<void> saveIdentifier(String appInstanceId) async {
    calls.add('save:$appInstanceId');
    if (value?.appInstanceId != appInstanceId) {
      value = AnalyticsDeletionRecord(
          appInstanceId: appInstanceId, submitted: false);
    }
  }

  @override
  Future<void> markSubmitted(String appInstanceId) async {
    calls.add('submitted:$appInstanceId');
    value =
        AnalyticsDeletionRecord(appInstanceId: appInstanceId, submitted: true);
  }

  @override
  Future<void> clear() async {
    calls.add('clear');
    value = null;
  }
}

void main() {
  testWidgets('grant requires confirmation and withdrawal needs no permission',
      (tester) async {
    final values = <bool>[];
    final consent = AnalyticsConsent(
        read: () async => false,
        write: (_) async {},
        apply: (v) async {
          values.add(v);
        });
    await consent.initialize();
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: AnalyticsConsentControl(controller: consent))));
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(find.textContaining('Google LLC(googlekrsupport@google.com)'),
        findsOneWidget);
    expect(find.textContaining('2개월 보관'), findsOneWidget);
    await tester.tap(find.text('동의하지 않음'));
    await tester.pumpAndSettle();
    expect(values, [false, false]);
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    await tester.tap(find.text('동의'));
    await tester.pumpAndSettle();
    expect(consent.enabled, isTrue);
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(consent.enabled, isFalse);
  });

  testWidgets('explicit deletion explains scope and reports accepted request',
      (tester) async {
    final store = _DeletionStore(AnalyticsDeletionRecord(
        appInstanceId: 'analytics-instance-1', submitted: false));
    final consent = AnalyticsConsent(
      read: () async => true,
      write: (_) async {},
      apply: (_) async {},
      deletionStore: store,
      fetchAppInstanceId: () async => 'analytics-instance-1',
      resetAnalyticsData: () async {},
    );
    await consent.initialize();
    var submitted = false;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: AnalyticsConsentControl(
      controller: consent,
      onDeleteCollectedData: (_) async => submitted = true,
    ))));
    await tester.tap(find.byKey(const ValueKey('analytics-data-delete')));
    await tester.pumpAndSettle();
    expect(find.textContaining('실제 삭제 완료는 달라요'), findsOneWidget);
    await tester
        .tap(find.byKey(const ValueKey('analytics-data-confirm-delete')));
    await tester.pumpAndSettle();
    expect(submitted, isTrue);
    expect(find.byKey(const ValueKey('analytics-deletion-status')),
        findsOneWidget);
  });
  test('no consent defaults off; explicit grant persists before enabling',
      () async {
    final calls = <String>[];
    final consent = AnalyticsConsent(
        read: () async => false,
        write: (v) async {
          calls.add('write:$v');
        },
        apply: (v) async {
          calls.add('apply:$v');
        });
    await consent.initialize();
    expect(calls, ['apply:false', 'apply:false']);
    await consent.change(true);
    expect(calls, ['apply:false', 'apply:false', 'write:true', 'apply:true']);
    expect(consent.enabled, isTrue);
    await consent.change(false);
    expect(calls.sublist(4), ['apply:false', 'write:false']);
    expect(consent.enabled, isFalse);
  });
  test('failed persistence cannot enable and withdrawal retry stays off',
      () async {
    final calls = <bool>[];
    final consent = AnalyticsConsent(
        read: () async => true,
        write: (_) async {
          throw StateError('disk');
        },
        apply: (v) async {
          calls.add(v);
        });
    await consent.initialize();
    await consent.change(false);
    expect(consent.error, isNotNull);
    expect(consent.requested, isFalse);
    expect(calls.last, isFalse);
    await consent.change(true);
    expect(consent.enabled, isFalse);
    expect(calls.last, isFalse);
  });
  test('read error does not block app or enable collection', () async {
    final calls = <bool>[];
    final consent = AnalyticsConsent(
        read: () async {
          throw StateError('disk');
        },
        write: (_) async {},
        apply: (v) async {
          calls.add(v);
        });
    await consent.initialize();
    expect(consent.ready, isFalse);
    expect(calls, [false, false]);
  });

  test('withdrawal preserves the instance ID before disabling collection',
      () async {
    final order = <String>[];
    final store = _DeletionStore();
    final consent = AnalyticsConsent(
      read: () async => true,
      write: (value) async => order.add('write:$value'),
      apply: (value) async => order.add('apply:$value'),
      deletionStore: store,
      fetchAppInstanceId: () async {
        order.add('fetch');
        return 'analytics-instance-1';
      },
      resetAnalyticsData: () async {},
    );
    await consent.initialize();
    order.clear();

    await consent.change(false);

    expect(order, ['fetch', 'apply:false', 'write:false']);
    expect(store.value?.appInstanceId, 'analytics-instance-1');
    expect(consent.enabled, isFalse);
  });

  test('deletion stops collection, submits once, resets locally and clears ID',
      () async {
    final order = <String>[];
    final store = _DeletionStore(AnalyticsDeletionRecord(
        appInstanceId: 'analytics-instance-1', submitted: false));
    final consent = AnalyticsConsent(
      read: () async => true,
      write: (value) async => order.add('write:$value'),
      apply: (value) async => order.add('apply:$value'),
      deletionStore: store,
      fetchAppInstanceId: () async => 'analytics-instance-1',
      resetAnalyticsData: () async => order.add('reset'),
    );
    await consent.initialize();
    order.clear();
    store.calls.clear();

    await consent.deleteCollectedData((id) async {
      order.add('submit:$id');
    });

    expect(order,
        ['apply:false', 'write:false', 'submit:analytics-instance-1', 'reset']);
    expect(store.calls, ['submitted:analytics-instance-1', 'clear']);
    expect(store.value, isNull);
    expect(consent.enabled, isFalse);
    expect(consent.deletionStatus, contains('삭제 요청이 접수됐어요'));
  });

  test('failed remote deletion stays disabled and keeps the ID for retry',
      () async {
    final store = _DeletionStore(AnalyticsDeletionRecord(
        appInstanceId: 'analytics-instance-1', submitted: false));
    var resetCount = 0;
    final consent = AnalyticsConsent(
      read: () async => true,
      write: (_) async {},
      apply: (_) async {},
      deletionStore: store,
      fetchAppInstanceId: () async => 'analytics-instance-1',
      resetAnalyticsData: () async => resetCount++,
    );
    await consent.initialize();

    await consent.deleteCollectedData((_) async => throw StateError('network'));

    expect(consent.enabled, isFalse);
    expect(consent.deletionError, contains('접수하지 못했어요'));
    expect(store.value?.appInstanceId, 'analytics-instance-1');
    expect(store.value?.submitted, isFalse);
    expect(resetCount, 0);
  });

  test('a persisted accepted request skips duplicate remote submission',
      () async {
    final store = _DeletionStore(AnalyticsDeletionRecord(
        appInstanceId: 'analytics-instance-1', submitted: true));
    var submissions = 0;
    var resets = 0;
    final consent = AnalyticsConsent(
      read: () async => false,
      write: (_) async {},
      apply: (_) async {},
      deletionStore: store,
      fetchAppInstanceId: () async => null,
      resetAnalyticsData: () async => resets++,
    );
    await consent.initialize();
    // initialize completes the pending local reset before the screen is ready.
    expect(resets, 1);
    expect(store.value, isNull);
    await consent.deleteCollectedData((_) async => submissions++);
    expect(submissions, 0);
  });
}
