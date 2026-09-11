import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:weather_care/features/settings/analytics_consent_control.dart';
import 'package:weather_care/services/analytics_consent.dart';

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
    await tester.tap(find.text('동의하지 않음'));
    await tester.pumpAndSettle();
    expect(values, [false]);
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    await tester.tap(find.text('동의'));
    await tester.pumpAndSettle();
    expect(consent.enabled, isTrue);
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(consent.enabled, isFalse);
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
    expect(calls, ['apply:false']);
    await consent.change(true);
    expect(calls, ['apply:false', 'write:true', 'apply:true']);
    expect(consent.enabled, isTrue);
    await consent.change(false);
    expect(calls.sublist(3), ['apply:false', 'write:false', 'apply:false']);
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
    expect(calls, [false]);
  });
}
