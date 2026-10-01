import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:weather_care/services/ad_removal_service.dart';

import 'support/fake_ad_removal.dart';

void main() {
  late FakeAdRemovalPurchaseGateway gateway;
  late MemoryAdRemovalOwnershipStore ownership;
  late AdRemovalService service;

  setUp(() {
    gateway = FakeAdRemovalPurchaseGateway();
    ownership = MemoryAdRemovalOwnershipStore();
    service = AdRemovalService(
      gateway: gateway,
      ownershipStore: ownership,
    );
  });

  tearDown(() async {
    service.dispose();
    await gateway.close();
  });

  test('저장된 구매 권한과 스토어 가격을 초기화한다', () async {
    ownership.owned = true;

    await service.initialize();
    await pumpEventQueue();

    expect(service.isOwned, isTrue);
    expect(service.localizedPrice, '₩3,300');
    expect(service.storeAvailable, isTrue);
  });

  test('스토어에서 삭제된 구매는 시작할 때 광고 제거 권한을 해제한다', () async {
    ownership.owned = true;
    gateway.activePurchase = false;

    await service.initialize();
    await pumpEventQueue();

    expect(service.isOwned, isFalse);
    expect(ownership.owned, isFalse);
  });

  test('스토어 상태를 확인하지 못하면 기존 구매 권한을 유지한다', () async {
    ownership.owned = true;
    gateway.failOwnershipCheck = true;

    await service.initialize();
    await pumpEventQueue();

    expect(service.isOwned, isTrue);
    expect(ownership.writes, 0);
  });

  test('구매내역 없이 복원하면 저장된 광고 제거 권한을 해제한다', () async {
    ownership.owned = true;
    await service.initialize();
    await pumpEventQueue();
    gateway.activePurchase = false;

    await service.restore();

    expect(service.isOwned, isFalse);
    expect(ownership.owned, isFalse);
    expect(service.message, '복원할 광고 제거 구매 내역을 찾지 못했어요.');
  });

  test('비소모성 상품 구매 완료 후 권한을 저장하고 구매를 완료 처리한다', () async {
    await service.initialize();
    await pumpEventQueue();

    await service.purchase();
    expect(gateway.purchaseCalls, 1);
    expect(service.action, AdRemovalAction.purchasing);

    final purchase = fakeAdRemovalPurchase();
    gateway.emit(purchase);
    await pumpEventQueue();

    expect(service.isOwned, isTrue);
    expect(ownership.owned, isTrue);
    expect(ownership.writes, 1);
    expect(gateway.completedPurchases, [purchase]);
    expect(service.busy, isFalse);
  });

  test('복원된 구매도 광고 제거 권한으로 적용한다', () async {
    await service.initialize();
    await pumpEventQueue();

    await service.restore();
    expect(gateway.restoreCalls, 1);

    gateway.emit(fakeAdRemovalPurchase(status: PurchaseStatus.restored));
    await pumpEventQueue();

    expect(service.isOwned, isTrue);
    expect(service.message, '구매 내역이 복원됐어요.');
  });

  test('검증 자료가 없는 구매에는 권한을 부여하지 않는다', () async {
    service.dispose();
    service = AdRemovalService(
      gateway: gateway,
      ownershipStore: ownership,
      verifyPurchase: (_) async => false,
    );
    await service.initialize();
    await pumpEventQueue();

    gateway.emit(fakeAdRemovalPurchase());
    await pumpEventQueue();

    expect(service.isOwned, isFalse);
    expect(ownership.writes, 0);
    expect(service.message, contains('구매 정보를 확인하지 못했어요'));
  });
}
