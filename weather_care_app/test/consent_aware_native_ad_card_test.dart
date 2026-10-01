import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weather_care/features/ads/consent_aware_native_ad_card.dart';
import 'package:weather_care/services/ad_removal_service.dart';
import 'package:weather_care/services/ads_consent.dart';

import 'support/fake_ad_removal.dart';

void main() {
  late bool eligible;
  late AdsConsent consent;
  late _FakeNativeAdCardLoader loader;
  late FakeAdRemovalPurchaseGateway purchaseGateway;
  late AdRemovalService adRemoval;

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
    purchaseGateway = FakeAdRemovalPurchaseGateway();
    adRemoval = AdRemovalService(
      gateway: purchaseGateway,
      ownershipStore: MemoryAdRemovalOwnershipStore(),
    );
  });

  tearDown(() async {
    adRemoval.dispose();
    await purchaseGateway.close();
  });

  Widget subject({NativeAdCardSize size = NativeAdCardSize.small}) =>
      MaterialApp(
        home: Scaffold(
          body: ConsentAwareNativeAdCard(
            size: size,
            controller: consent,
            adRemoval: adRemoval,
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

  testWidgets('광고 제거 구매가 적용되면 표시 중인 광고를 제거하고 폐기한다', (tester) async {
    await adRemoval.initialize();
    await tester.pumpWidget(subject());
    eligible = true;
    await consent.refresh();
    await tester.pump();
    await tester.pump();
    final loaded = loader.handles.single;

    purchaseGateway.emit(fakeAdRemovalPurchase());
    await tester.pump();
    await tester.pump();

    expect(adRemoval.isOwned, isTrue);
    expect(find.byKey(const ValueKey('week-native-ad-card')), findsNothing);
    expect(loaded.disposeCount, 1);

    purchaseGateway.activePurchase = false;
    await adRemoval.refreshOwnership();
    await tester.pump();
    await tester.pump();

    expect(adRemoval.isOwned, isFalse);
    expect(loader.requests, hasLength(2));
    expect(find.byKey(const ValueKey('week-native-ad-card')), findsOneWidget);
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

  testWidgets('소형 카드는 4:1 비율로 카드와 광고 중심을 맞춘다', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(subject());
    eligible = true;
    await consent.refresh();
    await tester.pump();
    await tester.pump();

    final card = tester.getSize(
      find.byKey(const ValueKey('week-native-ad-card')),
    );
    expect(card.width, 360);
    expect(card.height, 90);
    expect(tester.getCenter(find.byKey(const ValueKey('fake-native-ad'))),
        tester.getCenter(find.byKey(const ValueKey('week-native-ad-card'))));
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
