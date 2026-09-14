import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weather_care/services/age_eligibility.dart';
import 'package:weather_care/services/age_eligibility_store.dart';
import 'package:weather_care/startup.dart';

void main() {
  group('AgeEligibilityStore', () {
    test('positive access requires two matching valid values', () async {
      for (final record in [
        ('at_least_14', 'at_least_14', AgeEligibility.atLeast14),
        ('under_14', 'under_14', AgeEligibility.under14),
        ('at_least_14', 'under_14', AgeEligibility.unknown),
        ('at_least_14', null, AgeEligibility.unknown),
        ('invalid', 'invalid', AgeEligibility.unknown),
      ]) {
        final store = AgeEligibilityStore(
          readPreference: () async => record.$1,
          readGuard: () async => record.$2,
          writePreference: (_) async {},
          writeGuard: (_) async {},
        );

        expect(await store.read(), record.$3);
      }
    });

    test('a partial grant is invalidated and never becomes authorized',
        () async {
      String? preference = 'under_14';
      String? guard = 'under_14';
      var failGuardGrant = true;
      final store = AgeEligibilityStore(
        readPreference: () async => preference,
        readGuard: () async => guard,
        writePreference: (value) async => preference = value,
        writeGuard: (value) async {
          if (value == 'at_least_14' && failGuardGrant) {
            failGuardGrant = false;
            throw StateError('guard failure');
          }
          guard = value;
        },
      );

      await expectLater(
        store.write(AgeEligibility.atLeast14),
        throwsStateError,
      );
      expect(await store.read(), AgeEligibility.unknown);
      expect(preference, isNull);
      expect(guard, isNull);
    });
  });

  test('read and persistence errors fail closed', () async {
    final readFailure = AgeEligibilityController(
      read: () async => throw StateError('read failure'),
      write: (_) async {},
    );
    await readFailure.initialize();
    expect(readFailure.sdkAccessAllowed, isFalse);
    expect(readFailure.eligibility, AgeEligibility.unknown);
    expect(readFailure.error, isNotNull);

    final writeFailure = AgeEligibilityController(
      read: () async => AgeEligibility.unknown,
      write: (_) async => throw StateError('write failure'),
    );
    await writeFailure.initialize();
    await writeFailure.select(AgeEligibility.atLeast14);
    expect(writeFailure.sdkAccessAllowed, isFalse);
    expect(writeFailure.eligibility, AgeEligibility.unknown);
    expect(writeFailure.error, isNotNull);
  });

  testWidgets('unknown age shows neutral choices before any service starts',
      (tester) async {
    final writes = <AgeEligibility>[];
    var serviceStarts = 0;
    final controller = AgeEligibilityController(
      read: () async => AgeEligibility.unknown,
      write: (value) async => writes.add(value),
    );

    await tester.pumpWidget(
      WeatherCareStartup(
        ageController: controller,
        initializeAuthorizedApp: () async {
          serviceStarts += 1;
          return const MaterialApp(home: Text('온라인 날씨'));
        },
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const ValueKey('age-at-least-14')), findsOneWidget);
    expect(find.byKey(const ValueKey('age-under-14')), findsOneWidget);
    expect(find.text('온라인 날씨'), findsNothing);
    expect(serviceStarts, 0);
    expect(writes, isEmpty);
    expect(
      find.byWidgetPredicate((widget) => widget is OutlinedButton),
      findsNWidgets(2),
    );
  });

  testWidgets('under 14 remains local and can correct the selection',
      (tester) async {
    final writes = <AgeEligibility>[];
    var serviceStarts = 0;
    final controller = AgeEligibilityController(
      read: () async => AgeEligibility.unknown,
      write: (value) async => writes.add(value),
    );

    await tester.pumpWidget(
      WeatherCareStartup(
        ageController: controller,
        initializeAuthorizedApp: () async {
          serviceStarts += 1;
          return const MaterialApp(home: Text('온라인 날씨'));
        },
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('age-under-14')));
    await tester.pump();
    await tester.pump();

    expect(find.text('날씨챙겨를 이용할 수 없어요'), findsOneWidget);
    expect(find.textContaining('앱 서비스를 이용할 수 없어요'), findsOneWidget);
    expect(find.textContaining('온라인 서비스와 기기 권한 요청은 시작하지 않았어요'), findsOneWidget);
    expect(find.text('온라인 날씨'), findsNothing);
    expect(serviceStarts, 0);
    expect(writes, [AgeEligibility.under14]);

    await tester.tap(find.byKey(const ValueKey('age-choose-again')));
    await tester.pump();
    await tester.pump();
    expect(writes, [AgeEligibility.under14, AgeEligibility.unknown]);
    expect(find.byKey(const ValueKey('age-at-least-14')), findsOneWidget);
  });

  testWidgets('matching 14+ choice starts services exactly once',
      (tester) async {
    var stored = AgeEligibility.unknown;
    var serviceStarts = 0;
    var mountedCalls = 0;
    final controller = AgeEligibilityController(
      read: () async => stored,
      write: (value) async => stored = value,
    );

    await tester.pumpWidget(
      WeatherCareStartup(
        ageController: controller,
        initializeAuthorizedApp: () async {
          serviceStarts += 1;
          return const MaterialApp(home: Text('온라인 날씨'));
        },
        onAuthorizedAppMounted: () => mountedCalls += 1,
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('age-at-least-14')));
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(stored, AgeEligibility.atLeast14);
    expect(find.text('온라인 날씨'), findsOneWidget);
    expect(serviceStarts, 1);
    expect(mountedCalls, 1);
  });

  testWidgets('service initialization failure stays gated and supports retry',
      (tester) async {
    var serviceStarts = 0;
    final controller = AgeEligibilityController(
      read: () async => AgeEligibility.atLeast14,
      write: (_) async {},
    );

    await tester.pumpWidget(
      WeatherCareStartup(
        ageController: controller,
        initializeAuthorizedApp: () async {
          serviceStarts += 1;
          if (serviceStarts == 1) throw StateError('offline');
          return const MaterialApp(home: Text('온라인 날씨'));
        },
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const ValueKey('age-services-retry')), findsOneWidget);
    expect(find.text('온라인 날씨'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('age-services-retry')));
    await tester.pump();
    await tester.pump();

    expect(serviceStarts, 2);
    expect(find.text('온라인 날씨'), findsOneWidget);
  });
}
