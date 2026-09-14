import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weather_care/features/ads/consent_aware_inline_banner.dart';
import 'package:weather_care/services/ads_consent.dart';

void main() {
  late bool eligible;
  late AdsConsent consent;
  late _FakeInlineBannerLoader loader;

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
    loader = _FakeInlineBannerLoader();
  });

  Widget subject({double width = 320}) => MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: width,
              child: ConsentAwareInlineBanner(
                controller: consent,
                loader: loader,
                platformOverride: TargetPlatform.android,
                releaseModeOverride: false,
                webOverride: false,
              ),
            ),
          ),
        ),
      );

  testWidgets('does not request an ad before UMP allows ads', (tester) async {
    await tester.pumpWidget(subject());
    await tester.pump();

    expect(loader.requests, isEmpty);
    expect(find.byKey(const ValueKey('week-inline-banner')), findsNothing);
  });

  testWidgets('loads a test banner after consent and labels it as an ad',
      (tester) async {
    await tester.pumpWidget(subject());
    eligible = true;
    await consent.refresh();
    await tester.pump();
    await tester.pump();

    expect(loader.requests, [
      const _LoadRequest(
        width: 320,
        adUnitId: 'ca-app-pub-3940256099942544/9214589741',
      ),
    ]);
    expect(find.byKey(const ValueKey('week-inline-banner')), findsOneWidget);
    expect(find.text('광고'), findsOneWidget);
    expect(find.byKey(const ValueKey('fake-banner')), findsOneWidget);
  });

  testWidgets('removes and disposes the banner when eligibility is withdrawn',
      (tester) async {
    await tester.pumpWidget(subject());
    eligible = true;
    await consent.refresh();
    await tester.pump();
    await tester.pump();
    final loaded = loader.handles.single;

    await consent.openPrivacyOptions();
    await tester.pump();

    expect(find.byKey(const ValueKey('week-inline-banner')), findsNothing);
    expect(loaded.disposeCount, 1);
  });

  testWidgets('width changes replace the loaded banner', (tester) async {
    await tester.pumpWidget(subject());
    eligible = true;
    await consent.refresh();
    await tester.pump();
    await tester.pump();
    final first = loader.handles.single;

    await tester.pumpWidget(subject(width: 360));
    await tester.pump();
    await tester.pump();

    expect(loader.requests.map((request) => request.width), [320, 360]);
    expect(first.disposeCount, 1);
    expect(loader.handles.last.disposeCount, 0);
  });
}

class _LoadRequest {
  final int width;
  final String adUnitId;

  const _LoadRequest({required this.width, required this.adUnitId});

  @override
  bool operator ==(Object other) =>
      other is _LoadRequest &&
      other.width == width &&
      other.adUnitId == adUnitId;

  @override
  int get hashCode => Object.hash(width, adUnitId);
}

class _FakeInlineBannerLoader implements InlineBannerLoader {
  final List<_LoadRequest> requests = [];
  final List<_FakeInlineBannerHandle> handles = [];

  @override
  Future<InlineBannerHandle?> load({
    required int width,
    required String adUnitId,
  }) async {
    requests.add(_LoadRequest(width: width, adUnitId: adUnitId));
    final handle = _FakeInlineBannerHandle(width: width);
    handles.add(handle);
    return handle;
  }
}

class _FakeInlineBannerHandle implements InlineBannerHandle {
  @override
  final int width;
  int disposeCount = 0;

  _FakeInlineBannerHandle({required this.width});

  @override
  int get height => 50;

  @override
  Widget buildWidget() => const ColoredBox(
        key: ValueKey('fake-banner'),
        color: Colors.grey,
      );

  @override
  Future<void> dispose() async {
    disposeCount += 1;
  }
}
