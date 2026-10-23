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

void main() {
  testWidgets('업데이트 푸시로 시작하면 일반 업데이트 팝업을 거치지 않는다', (tester) async {
    final service = _Updates(() async => update);
    await tester.pumpWidget(
        AppUpdateGate(skipCheck: true, service: service, child: home));
    await tester.pumpAndSettle();
    expect(service.calls, 0);
    expect(find.text('새로운 버전이 있어요'), findsNothing);
    expect(find.text('날씨 홈'), findsOneWidget);
  });
  testWidgets('업데이트가 없으면 홈과 후속 시작 처리를 바로 실행한다', (tester) async {
    var completed = 0;
    await tester.pumpWidget(AppUpdateGate(
      service: _Updates(() async => null),
      onComplete: () => completed++,
      child: home,
    ));
    await tester.pumpAndSettle();
    expect(find.text('날씨 홈'), findsOneWidget);
    expect(completed, 1);
  });

  testWidgets('팝업을 닫기 전에는 홈 권한 안내와 광고 시작을 지연한다', (tester) async {
    var completed = 0;
    final service = _Updates(() async => update);
    final gate = AppUpdateGate(
      service: service,
      onComplete: () => completed++,
      child: home,
    );
    await tester.pumpWidget(gate);
    await tester.pumpAndSettle();
    expect(find.text('새로운 버전이 있어요'), findsOneWidget);
    expect(find.text('날씨 홈'), findsNothing);
    expect(completed, 0);

    await tester.tap(find.byKey(const ValueKey('app-update-later')));
    await tester.pumpAndSettle();
    expect(find.text('날씨 홈'), findsOneWidget);
    expect(completed, 1);
    await tester.pumpWidget(gate);
    await tester.pumpAndSettle();
    expect(service.calls, 1);
    expect(find.text('새로운 버전이 있어요'), findsNothing);
  });

  testWidgets('업데이트 버튼은 해당 앱 스토어를 열고 홈으로 진행한다', (tester) async {
    final opened = <Uri>[];
    await tester.pumpWidget(AppUpdateGate(
      service: _Updates(() async => update),
      openStore: (uri) async {
        opened.add(uri);
        return true;
      },
      child: home,
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('app-update-open-store')));
    await tester.pumpAndSettle();
    expect(opened, [update.storeUrl]);
    expect(find.text('날씨 홈'), findsOneWidget);
  });

  testWidgets('스토어 열기 실패를 표시하고 다시 시도할 수 있다', (tester) async {
    var calls = 0;
    await tester.pumpWidget(AppUpdateGate(
      service: _Updates(() async => update),
      openStore: (_) async {
        calls++;
        if (calls == 1) throw StateError('unavailable');
        return true;
      },
      child: home,
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('app-update-open-store')));
    await tester.pumpAndSettle();
    expect(find.textContaining('스토어를 열지 못했어요'), findsOneWidget);
    expect(find.text('날씨 홈'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('app-update-open-store')));
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(find.text('날씨 홈'), findsOneWidget);
  });

  testWidgets('스토어 응답 대기 중 화면이 닫혀도 팝업을 띄우지 않는다', (tester) async {
    final pending = Completer<StoreUpdate?>();
    await tester.pumpWidget(AppUpdateGate(
      service: _Updates(() => pending.future),
      child: home,
    ));
    await tester.pumpWidget(const SizedBox());
    pending.complete(update);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('작은 화면·큰 글씨에서도 모든 버튼에 접근할 수 있다', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(AppUpdateGate(
      service: _Updates(() async => update),
      child: home,
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final later = find.byKey(const ValueKey('app-update-later'));
    await tester.ensureVisible(later);
    await tester.tap(later);
    await tester.pumpAndSettle();
    expect(find.text('날씨 홈'), findsOneWidget);
  });
}
