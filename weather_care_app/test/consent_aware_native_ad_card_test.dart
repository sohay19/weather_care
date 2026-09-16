import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weather_care/features/ads/consent_aware_native_ad_card.dart';
import 'package:weather_care/services/ads_consent.dart';

void main() {
  late bool eligible;
  late AdsConsent consent;
  late _FakeNativeAdCardLoader loader;

  setUp(() {
    eligible = false;
    consent = AdsConsent(
      update: () async {},
      showRequired: () async {},
      showOptions: () async {
        eligible = false;
      },
      allowed: () async => eligible,
      optionsRequired: () async => true,
      initializeAds: () async {},
    );
    loader = _FakeNativeAdCardLoader();
  });

  Widget subject({NativeAdCardSize size = NativeAdCardSize.small}) =>
      MaterialApp(
        home: Scaffold(
          body: ConsentAwareNativeAdCard(
            size: size,
            controller: consent,
            loader: loader,
            platformOverride: TargetPlatform.android,
            releaseModeOverride: false,
            webOverride: false,
          ),
        ),
      );

  testWidgets('UMP가 광고를 허용하기 전에는 네이티브 광고를 요청하지 않는다', (tester) async {
    await tester.pumpWidget(subject());
    await tester.pump();

    expect(loader.requests, isEmpty);
    expect(find.byKey(const ValueKey('week-native-ad-card')), findsNothing);
    expect(
      find.byKey(const ValueKey('week-native-ad-placeholder')),
      findsNothing,
    );
  });

  testWidgets('동의 후 공식 테스트 네이티브 광고를 카드로 표시한다', (tester) async {
    await tester.pumpWidget(subject());
    eligible = true;
    await consent.refresh();
    await tester.pump();

    expect(
      find.byKey(const ValueKey('week-native-ad-placeholder')),
      findsOneWidget,
    );

    await tester.pump();

    expect(loader.requests, [
      'ca-app-pub-3940256099942544/2247696110',
    ]);
    expect(find.byKey(const ValueKey('week-native-ad-card')), findsOneWidget);
    expect(find.byKey(const ValueKey('fake-native-ad')), findsOneWidget);
  });

  testWidgets('광고 요청 가능 상태가 해제되면 카드를 제거하고 폐기한다', (tester) async {
    await tester.pumpWidget(subject());
    eligible = true;
    await consent.refresh();
    await tester.pump();
    await tester.pump();
    final loaded = loader.handles.single;

    await consent.openPrivacyOptions();
    await tester.pump();

    expect(find.byKey(const ValueKey('week-native-ad-card')), findsNothing);
    expect(loaded.disposeCount, 1);
  });

  testWidgets('일반 재빌드로 동일한 광고를 다시 요청하지 않는다', (tester) async {
    await tester.pumpWidget(subject());
    eligible = true;
    await consent.refresh();
    await tester.pump();
    await tester.pump();

    await tester.pumpWidget(subject());
    await tester.pump();

    expect(loader.requests, hasLength(1));
    expect(loader.handles.single.disposeCount, 0);
  });

  testWidgets('중형 카드는 medium 템플릿과 360px 영역을 사용한다', (tester) async {
    await tester.pumpWidget(subject(size: NativeAdCardSize.medium));
    eligible = true;
    await consent.refresh();
    await tester.pump();
    await tester.pump();

    expect(loader.sizes, [NativeAdCardSize.medium]);
    expect(
      tester.getSize(find.byKey(const ValueKey('week-native-ad-card'))).height,
      360,
    );
  });
}

class _FakeNativeAdCardLoader implements NativeAdCardLoader {
  final List<String> requests = [];
  final List<NativeAdCardSize> sizes = [];
  final List<_FakeNativeAdCardHandle> handles = [];

  @override
  Future<NativeAdCardHandle?> load({
    required String adUnitId,
    required NativeAdCardSize size,
  }) async {
    requests.add(adUnitId);
    sizes.add(size);
    final handle = _FakeNativeAdCardHandle();
    handles.add(handle);
    return handle;
  }
}

class _FakeNativeAdCardHandle implements NativeAdCardHandle {
  int disposeCount = 0;

  @override
  Widget buildWidget() => const ColoredBox(
        key: ValueKey('fake-native-ad'),
        color: Colors.grey,
      );

  @override
  Future<void> dispose() async {
    disposeCount += 1;
  }
}
