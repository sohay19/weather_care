import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weather_care/features/update/app_update_gate.dart';
import 'package:weather_care/services/store_update_service.dart';

final update = StoreUpdate(
  currentVersion: '1.0.0',
  latestVersion: '1.1.0',
  storeName: 'App Store',
  storeUrl: Uri.parse('https://apps.apple.com/kr/app/id1234567890'),
);

class _Updates extends StoreUpdateService {
  final Future<StoreUpdate?> Function() check;
  int calls = 0;
  _Updates(this.check);
  @override
  Future<StoreUpdate?> checkForUpdate() {
    calls++;
    return check();
  }
}

const home = MaterialApp(home: Scaffold(body: Text('날씨 홈')));
final openStore = find.byKey(const ValueKey('app-update-open-store'));

void resumeApp(WidgetTester tester) {
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
}

void main() {
  testWidgets('버전 검사를 끄면 스토어 조회 없이 홈과 후속 시작 처리를 한 번 실행한다',
      (tester) async {
    var completed = 0;
    final service = _Updates(() async => throw StateError('조회하면 안 됨'));
    final gate = AppUpdateGate(
        checkVersion: false,
        service: service,
        onComplete: () => completed++,
        child: home);
    await tester.pumpWidget(gate);
    await tester.pumpAndSettle();
    await tester.pumpWidget(gate);
    await tester.pumpAndSettle();
    resumeApp(tester);
    await tester.pumpAndSettle();
    expect(find.text('날씨 홈'), findsOneWidget);
    expect(service.calls, 0);
    expect(completed, 1);
  });

  testWidgets('업데이트가 없으면 홈과 후속 시작 처리를 한 번 실행한다', (tester) async {
    var completed = 0;
    final service = _Updates(() async => null);
    final gate = AppUpdateGate(
        service: service, onComplete: () => completed++, child: home);
    await tester.pumpWidget(gate);
    await tester.pumpAndSettle();
    await tester.pumpWidget(gate);
    await tester.pumpAndSettle();
    expect(find.text('날씨 홈'), findsOneWidget);
    expect(completed, 1);
    expect(service.calls, 1);
  });

  testWidgets('나중에 버튼이 없고 바깥 터치와 시스템 뒤로가기를 차단한다', (tester) async {
    var completed = 0;
    await tester.pumpWidget(AppUpdateGate(
        service: _Updates(() async => update),
        onComplete: () => completed++,
        child: home));
    await tester.pumpAndSettle();
    expect(find.text('나중에'), findsNothing);
    expect(find.text('업데이트 확인'), findsNothing);
    expect(find.byType(TextButton), findsNothing);
    expect(find.byType(FilledButton), findsOneWidget);
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('새로운 버전이 있어요'), findsOneWidget);
    expect(find.text('날씨 홈'), findsNothing);
    expect(completed, 0);
  });

  testWidgets('스토어만 열거나 업데이트하지 않고 복귀해도 홈을 차단한다', (tester) async {
    final opened = <Uri>[];
    final service = _Updates(() async => update);
    await tester.pumpWidget(AppUpdateGate(
        service: service,
        openStore: (uri) async {
          opened.add(uri);
          return true;
        },
        child: home));
    await tester.pumpAndSettle();
    await tester.tap(openStore);
    await tester.pumpAndSettle();
    expect(opened, [update.storeUrl]);
    expect(find.text('날씨 홈'), findsNothing);
    resumeApp(tester);
    await tester.pumpAndSettle();
    expect(service.calls, 2);
    expect(find.textContaining('아직 업데이트가 완료되지 않았어요'), findsOneWidget);
    expect(find.text('날씨 홈'), findsNothing);
  });

  testWidgets('스토어 복귀 자동 확인으로 업데이트 불필요가 확인되어야 홈으로 진행한다', (tester) async {
    StoreUpdate? available = update;
    var completed = 0;
    await tester.pumpWidget(AppUpdateGate(
        service: _Updates(() async => available),
        onComplete: () => completed++,
        child: home));
    await tester.pumpAndSettle();
    available = null;
    resumeApp(tester);
    await tester.pumpAndSettle();
    expect(find.text('날씨 홈'), findsOneWidget);
    expect(completed, 1);
  });

  testWidgets('복귀 자동 조회 실패는 차단을 유지하고 다음 복귀 때 다시 확인한다', (tester) async {
    var fail = false;
    await tester.pumpWidget(AppUpdateGate(
        service: _Updates(() async {
          if (fail) throw StateError('offline');
          return update;
        }),
        child: home));
    await tester.pumpAndSettle();
    fail = true;
    resumeApp(tester);
    await tester.pumpAndSettle();
    expect(find.textContaining('버전을 확인하지 못했어요'), findsOneWidget);
    expect(find.text('날씨 홈'), findsNothing);
    fail = false;
    resumeApp(tester);
    await tester.pumpAndSettle();
    expect(find.textContaining('아직 업데이트가 완료되지 않았어요'), findsOneWidget);
  });

  testWidgets('첫 조회 실패도 홈 대신 재시도를 제공한다', (tester) async {
    var fail = true;
    await tester.pumpWidget(AppUpdateGate(
        service: _Updates(() async {
          if (fail) throw StateError('offline');
          return null;
        }),
        child: home));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('날씨 홈'), findsNothing);
    expect(find.text('다시 확인'), findsOneWidget);
    fail = false;
    await tester.tap(find.text('다시 확인'));
    await tester.pumpAndSettle();
    expect(find.text('날씨 홈'), findsOneWidget);
  });

  testWidgets('재조회 대기 중 중복 요청과 업데이트 버튼을 막는다', (tester) async {
    final pending = Completer<StoreUpdate?>();
    var calls = 0;
    final service =
        _Updates(() => ++calls == 1 ? Future.value(update) : pending.future);
    await tester.pumpWidget(AppUpdateGate(service: service, child: home));
    await tester.pumpAndSettle();
    resumeApp(tester);
    await tester.pump();
    resumeApp(tester);
    await tester.pump();
    expect(tester.widget<FilledButton>(openStore).onPressed, isNull);
    expect(service.calls, 2);
    pending.complete(null);
    await tester.pumpAndSettle();
    expect(service.calls, 2);
    expect(find.text('날씨 홈'), findsOneWidget);
  });

  testWidgets('푸시 경로에서도 바깥 기존 화면으로 뒤로갈 수 없다', (tester) async {
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(MaterialApp(
        navigatorKey: navigator,
        home: const Scaffold(body: Text('기존 화면')),
        routes: {
          '/store-update': (_) => AppUpdateGate(
              service: _Updates(() async => update),
              child: const Text('스토어 이동')),
        }));
    navigator.currentState!.pushNamed('/store-update');
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('새로운 버전이 있어요'), findsOneWidget);
    expect(find.text('기존 화면'), findsNothing);
    expect(find.text('스토어 이동'), findsNothing);
  });

  testWidgets('스토어 열기 재시도가 성공해도 업데이트 확인 전에는 차단한다', (tester) async {
    var calls = 0;
    await tester.pumpWidget(AppUpdateGate(
        service: _Updates(() async => update),
        openStore: (_) async {
          if (++calls == 1) throw StateError('unavailable');
          return true;
        },
        child: home));
    await tester.pumpAndSettle();
    await tester.tap(openStore);
    await tester.pumpAndSettle();
    expect(find.textContaining('스토어를 열지 못했어요'), findsOneWidget);
    await tester.tap(openStore);
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(find.text('날씨 홈'), findsNothing);
  });

  testWidgets('조회 대기 중 화면이 닫혀도 팝업이나 예외가 발생하지 않는다', (tester) async {
    final pending = Completer<StoreUpdate?>();
    await tester.pumpWidget(
        AppUpdateGate(service: _Updates(() => pending.future), child: home));
    await tester.pumpWidget(const SizedBox());
    pending.complete(update);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('작은 화면과 큰 글씨에서도 업데이트 버튼에 접근할 수 있다', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(
        AppUpdateGate(service: _Updates(() async => update), child: home));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(openStore);
    expect(tester.widget<FilledButton>(openStore).onPressed, isNotNull);
    await tester.pumpAndSettle();
    expect(find.text('날씨 홈'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
