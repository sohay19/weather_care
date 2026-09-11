import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weather_care/services/ads_consent.dart';
import 'package:weather_care/features/settings/ads_privacy_control.dart';

void main() {
  late List<String> calls;
  late bool eligible;
  late AdsConsent consent;
  setUp(() {
    calls = [];
    eligible = true;
    consent = AdsConsent(
        update: () async {
          calls.add('update');
        },
        showRequired: () async {
          calls.add('form');
        },
        showOptions: () async {
          calls.add('options');
          eligible = false;
        },
        allowed: () async {
          calls.add('allowed');
          return eligible;
        },
        optionsRequired: () async => true,
        initializeAds: () async {
          calls.add('initialize');
        });
  });
  test('form and eligibility precede initialization; initializes only once',
      () async {
    await consent.refresh();
    expect(calls, ['update', 'form', 'allowed', 'initialize']);
    await consent.refresh();
    expect(calls.where((c) => c == 'initialize').length, 1);
    await consent.openPrivacyOptions();
    expect(consent.canRequestAds, isFalse);
  });
  test('not eligible never initializes', () async {
    eligible = false;
    await consent.refresh();
    expect(calls, isNot(contains('initialize')));
  });
  test('failed update blocks ads and supports retry', () async {
    var fail = true;
    final gate = AdsConsent(
        update: () async {
          if (fail) throw StateError('fail');
        },
        showRequired: () async {},
        showOptions: () async {},
        allowed: () async => true,
        optionsRequired: () async => false,
        initializeAds: () async {
          calls.add('initialize');
        });
    await gate.refresh();
    expect(gate.error, isNotNull);
    expect(gate.canRequestAds, isFalse);
    expect(calls, isEmpty);
    fail = false;
    await gate.refresh();
    expect(gate.canRequestAds, isTrue);
  });
  test('concurrent refresh does not duplicate work', () async {
    final pending = Completer<void>();
    final gate = AdsConsent(
        update: () => pending.future,
        showRequired: () async {},
        showOptions: () async {},
        allowed: () async => true,
        optionsRequired: () async => false,
        initializeAds: () async {
          calls.add('initialize');
        });
    final first = gate.refresh();
    await gate.refresh();
    expect(gate.busy, isTrue);
    pending.complete();
    await first;
    expect(calls, ['initialize']);
  });
  testWidgets(
      'options entry appears only when required and updates eligibility',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: AdsPrivacyControl(controller: consent))));
    expect(find.text('광고 개인정보 선택'), findsNothing);
    await consent.refresh();
    await tester.pumpAndSettle();
    await tester.tap(find.text('광고 개인정보 선택'));
    await tester.pumpAndSettle();
    expect(calls, contains('options'));
    expect(consent.canRequestAds, isFalse);
  });
}
