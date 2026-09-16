import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:weather_care/services/ads_consent.dart';
import 'package:weather_care/services/app_open_ad_controller.dart';

void main() {
  late bool eligible;
  late AdsConsent consent;
  late _FakeAppOpenAdLoader loader;
  late _FakeAppOpenLifecycle lifecycle;
  late AppOpenAdController controller;

  setUp(() async {
    eligible = true;
    consent = AdsConsent(
      update: () async {},
      showRequired: () async {},
      showOptions: () async => eligible = false,
      allowed: () async => eligible,
      optionsRequired: () async => true,
      initializeAds: () async {},
    );
    await consent.refresh();
    loader = _FakeAppOpenAdLoader();
    lifecycle = _FakeAppOpenLifecycle();
    controller = AppOpenAdController(
      consent: consent,
      loader: loader,
      lifecycle: lifecycle,
      platformOverride: TargetPlatform.android,
      releaseModeOverride: false,
      webOverride: false,
    );
  });

  tearDown(() async {
    await controller.dispose();
    await lifecycle.close();
  });

  test('홈이 준비되지 않았으면 초기 광고를 로드 후 표시한다', () async {
    await controller.start(showOnInitialLoad: true);
    await pumpEventQueue();

    expect(loader.requests, [
      'ca-app-pub-3940256099942544/9257395921',
    ]);
    expect(loader.handles.single.showCount, 1);
  });

  test('광고보다 홈이 먼저 준비되면 다음 전경 진입까지 표시를 미룬다', () async {
    loader.deferLoads = true;
    await controller.start(showOnInitialLoad: true);
    await pumpEventQueue();

    controller.markHomeReady();
    loader.completeNextLoad();
    await pumpEventQueue();

    expect(loader.handles.single.showCount, 0);

    lifecycle.background();
    lifecycle.foreground();
    await pumpEventQueue();
    expect(loader.handles.single.showCount, 1);
  });

  test('광고 시작 전에 홈이 준비돼도 초기 표시는 미룬다', () async {
    controller.markHomeReady();
    await controller.start(showOnInitialLoad: true);
    await pumpEventQueue();

    expect(loader.handles.single.showCount, 0);
  });

  test('광고를 닫으면 폐기하고 다음 전경 진입용 광고를 미리 로드한다', () async {
    await controller.start(showOnInitialLoad: true);
    await pumpEventQueue();
    final shown = loader.handles.first;

    shown.dismiss();
    await pumpEventQueue();

    expect(shown.disposeCount, 1);
    expect(loader.requests, hasLength(2));
    expect(loader.handles.last.showCount, 0);

    lifecycle.background();
    lifecycle.foreground();
    await pumpEventQueue();
    expect(loader.handles.last.showCount, 1);
  });

  test('백그라운드 전환 없는 foreground 이벤트에는 미룬 광고를 표시하지 않는다', () async {
    controller.markHomeReady();
    await controller.start(showOnInitialLoad: true);
    await pumpEventQueue();

    lifecycle.foreground();
    await pumpEventQueue();

    expect(loader.handles.single.showCount, 0);
  });

  test('광고 요청 자격이 해제되면 캐시된 광고를 폐기한다', () async {
    await controller.start(showOnInitialLoad: false);
    await pumpEventQueue();
    final cached = loader.handles.single;

    await consent.openPrivacyOptions();
    await pumpEventQueue();

    expect(cached.disposeCount, 1);
  });
}

class _FakeAppOpenAdLoader implements AppOpenAdLoader {
  final List<String> requests = [];
  final List<_FakeAppOpenAdHandle> handles = [];
  bool deferLoads = false;
  Completer<AppOpenAdHandle?>? _pendingLoad;

  @override
  Future<AppOpenAdHandle?> load({required String adUnitId}) async {
    requests.add(adUnitId);
    final handle = _FakeAppOpenAdHandle();
    handles.add(handle);
    if (deferLoads) {
      _pendingLoad = Completer<AppOpenAdHandle?>();
      return _pendingLoad!.future;
    }
    return handle;
  }

  void completeNextLoad() {
    _pendingLoad?.complete(handles.last);
    _pendingLoad = null;
  }
}

class _FakeAppOpenAdHandle implements AppOpenAdHandle {
  int showCount = 0;
  int disposeCount = 0;
  VoidCallback? _onDismissed;

  @override
  Future<void> show({
    required VoidCallback onDismissed,
    required VoidCallback onFailedToShow,
  }) async {
    showCount += 1;
    _onDismissed = onDismissed;
  }

  void dismiss() => _onDismissed?.call();

  @override
  Future<void> dispose() async {
    disposeCount += 1;
  }
}

class _FakeAppOpenLifecycle implements AppOpenLifecycle {
  final _controller = StreamController<AppState>.broadcast();

  @override
  Stream<AppState> get states => _controller.stream;

  @override
  Future<void> startListening() async {}

  @override
  Future<void> stopListening() async {}

  void background() => _controller.add(AppState.background);

  void foreground() => _controller.add(AppState.foreground);

  Future<void> close() => _controller.close();
}
