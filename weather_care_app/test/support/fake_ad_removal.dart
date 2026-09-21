import 'dart:async';

import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:weather_care/services/ad_removal_service.dart';

class FakeAdRemovalPurchaseGateway implements AdRemovalPurchaseGateway {
  final StreamController<List<PurchaseDetails>> _purchases =
      StreamController<List<PurchaseDetails>>.broadcast();

  bool available = true;
  ProductDetails? product = fakeAdRemovalProduct();
  int purchaseCalls = 0;
  int restoreCalls = 0;
  final List<PurchaseDetails> completedPurchases = [];

  @override
  Stream<List<PurchaseDetails>> get purchaseStream => _purchases.stream;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<ProductDetailsResponse> queryProductDetails(
    Set<String> identifiers,
  ) async {
    final selected = product;
    return ProductDetailsResponse(
      productDetails: selected != null && identifiers.contains(selected.id)
          ? [selected]
          : const [],
      notFoundIDs: selected == null ? identifiers.toList() : const [],
    );
  }

  @override
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam}) async {
    purchaseCalls += 1;
    return true;
  }

  @override
  Future<void> restorePurchases() async {
    restoreCalls += 1;
  }

  @override
  Future<void> completePurchase(PurchaseDetails purchase) async {
    completedPurchases.add(purchase);
  }

  void emit(PurchaseDetails purchase) => _purchases.add([purchase]);

  Future<void> close() => _purchases.close();
}

class MemoryAdRemovalOwnershipStore implements AdRemovalOwnershipStore {
  MemoryAdRemovalOwnershipStore([this.owned = false]);

  bool owned;
  int writes = 0;

  @override
  Future<bool> read() async => owned;

  @override
  Future<void> write(bool owned) async {
    this.owned = owned;
    writes += 1;
  }
}

ProductDetails fakeAdRemovalProduct({String id = adRemovalProductId}) =>
    ProductDetails(
      id: id,
      title: '평생 광고 제거',
      description: '모든 광고를 제거합니다.',
      price: '₩3,300',
      rawPrice: 3300,
      currencyCode: 'KRW',
      currencySymbol: '₩',
    );

PurchaseDetails fakeAdRemovalPurchase({
  PurchaseStatus status = PurchaseStatus.purchased,
  bool pendingCompletePurchase = true,
  String id = adRemovalProductId,
}) {
  final purchase = PurchaseDetails(
    purchaseID: 'purchase-1',
    productID: id,
    verificationData: PurchaseVerificationData(
      localVerificationData: 'local-proof',
      serverVerificationData: 'server-proof',
      source: 'test',
    ),
    transactionDate: '1',
    status: status,
  );
  purchase.pendingCompletePurchase = pendingCompletePurchase;
  return purchase;
}
