import 'package:flutter_test/flutter_test.dart';
import 'package:weather_care/services/analytics_consent.dart';
import 'package:weather_care/services/analytics_consent_store.dart';

void main() {
  for (final failingStore in ['preference', 'guard']) {
    test('withdrawal survives restart when $failingStore write fails',
        () async {
      final disk = _Disk();
      final first = disk.controller();
      await first.initialize();
      expect(first.enabled, isTrue);
      disk.failPreference = failingStore == 'preference';
      disk.failGuard = failingStore == 'guard';
      await first.change(false);
      expect(first.error, isNotNull);
      expect(first.enabled, isFalse);
      disk.calls.clear();
      final restarted = disk.controller();
      await restarted.initialize();
      expect(restarted.enabled, isFalse);
      expect(disk.calls, everyElement(false));
    });
  }

  test('SDK stop failure still persists withdrawal for restart', () async {
    final disk = _Disk();
    final first = disk.controller();
    await first.initialize();
    disk.failSdk = true;
    await first.change(false);
    expect(first.error, isNotNull);
    expect(disk.preference, isFalse);
    expect(disk.guard, isFalse);
    disk.failSdk = false;
    final restarted = disk.controller();
    await restarted.initialize();
    expect(restarted.enabled, isFalse);
  });

  test('legacy grant without guard requires fresh consent', () async {
    final disk = _Disk()..guard = false;
    final controller = disk.controller();
    await controller.initialize();
    expect(controller.enabled, isFalse);
    await controller.change(true);
    expect(controller.enabled, isTrue);
    expect(disk.preference && disk.guard, isTrue);
    await controller.change(false);
    expect(disk.preference || disk.guard, isFalse);
  });

  test('guard read failure never enables SDK', () async {
    final disk = _Disk()..failRead = true;
    final controller = disk.controller();
    await controller.initialize();
    expect(controller.ready, isFalse);
    expect(controller.error, isNotNull);
    expect(disk.calls, everyElement(false));
  });

  test('failed grant rolls back and stays disabled on restart', () async {
    final disk = _Disk()
      ..preference = false
      ..guard = false;
    final controller = disk.controller();
    await controller.initialize();
    disk.failGrantGuard = true;
    await controller.change(true);
    expect(controller.error, isNotNull);
    expect(disk.preference || disk.guard, isFalse);
    final restarted = disk.controller();
    await restarted.initialize();
    expect(restarted.enabled, isFalse);
  });

  test('all persistence failures are reported, retry persists denial',
      () async {
    final disk = _Disk();
    final controller = disk.controller();
    await controller.initialize();
    disk.failPreference = disk.failGuard = true;
    await controller.change(false);
    expect(controller.error, isNotNull);
    expect(disk.calls.last, isFalse);
    // No claim that denial survived total storage failure.
    expect(disk.preference && disk.guard, isTrue);
    disk.failPreference = disk.failGuard = false;
    await controller.change(false);
    expect(controller.error, isNull);
    final restarted = disk.controller();
    await restarted.initialize();
    expect(restarted.enabled, isFalse);
  });
}

class _Disk {
  bool preference = true, guard = true;
  bool failPreference = false, failGuard = false, failSdk = false;
  bool failRead = false, failGrantGuard = false;
  final calls = <bool>[];

  AnalyticsConsent controller() {
    final store = AnalyticsConsentStore(
      readPreference: () async => preference,
      readGuard: () async {
        if (failRead) throw StateError('read');
        return guard;
      },
      writePreference: (value) async {
        if (failPreference) throw StateError('preference');
        preference = value;
      },
      writeGuard: (value) async {
        if (failGuard || (value && failGrantGuard)) throw StateError('guard');
        guard = value;
      },
    );
    return AnalyticsConsent(
      read: store.read,
      write: store.write,
      apply: (value) async {
        calls.add(value);
        if (failSdk) throw StateError('sdk');
      },
    );
  }
}
