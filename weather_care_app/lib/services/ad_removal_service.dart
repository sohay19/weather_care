import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';

const adRemovalProductId = String.fromEnvironment(
  'AD_REMOVAL_PRODUCT_ID',
  defaultValue: 'ad_free_lifetime',
);

enum AdRemovalAction { none, purchasing, restoring }

abstract interface class AdRemovalPurchaseGateway {
  Stream<List<PurchaseDetails>> get purchaseStream;

  Future<bool> isAvailable();

  Future<ProductDetailsResponse> queryProductDetails(Set<String> identifiers);

  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam});

  Future<void> restorePurchases();

  Future<void> completePurchase(PurchaseDetails purchase);

  Future<bool?> hasActivePurchase(String productId);
}

class StoreAdRemovalPurchaseGateway implements AdRemovalPurchaseGateway {
  const StoreAdRemovalPurchaseGateway();

  static const _iosOwnershipChannel =
      MethodChannel('com.codesoha.weathercare/ad-removal');

  InAppPurchase get _store => InAppPurchase.instance;

  @override
  Stream<List<PurchaseDetails>> get purchaseStream => _store.purchaseStream;

  @override
  Future<bool> isAvailable() => _store.isAvailable();

  @override
  Future<ProductDetailsResponse> queryProductDetails(
    Set<String> identifiers,
  ) =>
      _store.queryProductDetails(identifiers);

  @override
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam}) =>
      _store.buyNonConsumable(purchaseParam: purchaseParam);

  @override
  Future<void> restorePurchases() => _store.restorePurchases();

  @override
  Future<void> completePurchase(PurchaseDetails purchase) =>
      _store.completePurchase(purchase);

  @override
  Future<bool?> hasActivePurchase(String productId) async {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final owned = await _iosOwnershipChannel.invokeMethod<bool>(
        'hasActivePurchase',
        productId,
      );
      if (owned == null) throw StateError('스토어 구매 상태가 비어 있습니다.');
      return owned;
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      final response = await _store
          .getPlatformAddition<InAppPurchaseAndroidPlatformAddition>()
          .queryPastPurchases();
      if (response.error != null) throw response.error!;
      return response.pastPurchases.any(
        (purchase) =>
            purchase.productID == productId &&
            (purchase.status == PurchaseStatus.purchased ||
                purchase.status == PurchaseStatus.restored) &&
            (purchase.verificationData.serverVerificationData.isNotEmpty ||
                purchase.verificationData.localVerificationData.isNotEmpty),
      );
    }
    return null;
  }
}

abstract interface class AdRemovalOwnershipStore {
  Future<bool> read();

  Future<void> write(bool owned);
}

class SecureAdRemovalOwnershipStore implements AdRemovalOwnershipStore {
  static const _storageKey = 'weather_care_ad_removal_owned_v1';

  const SecureAdRemovalOwnershipStore();

  @override
  Future<bool> read() async =>
      await const FlutterSecureStorage().read(key: _storageKey) == 'true';

  @override
  Future<void> write(bool owned) => const FlutterSecureStorage().write(
        key: _storageKey,
        value: owned ? 'true' : 'false',
      );
}

class AdRemovalException implements Exception {
  final String message;

  const AdRemovalException(this.message);

  @override
  String toString() => message;
}

typedef AdRemovalPurchaseVerifier = Future<bool> Function(
  PurchaseDetails purchase,
);

class AdRemovalService extends ChangeNotifier {
  AdRemovalService({
    AdRemovalPurchaseGateway gateway = const StoreAdRemovalPurchaseGateway(),
    AdRemovalOwnershipStore ownershipStore =
        const SecureAdRemovalOwnershipStore(),
    AdRemovalPurchaseVerifier? verifyPurchase,
    this.productId = adRemovalProductId,
  })  : _gateway = gateway,
        _ownershipStore = ownershipStore,
        _verifyPurchase = verifyPurchase ?? _hasStoreVerificationData;

  static final instance = AdRemovalService();

  final AdRemovalPurchaseGateway _gateway;
  final AdRemovalOwnershipStore _ownershipStore;
  final AdRemovalPurchaseVerifier _verifyPurchase;
  final String productId;

  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;
  ProductDetails? _product;
  bool _initialized = false;
  bool _storeLoading = false;
  bool _storeAvailable = false;
  bool _owned = false;
  bool _checkingOwnership = false;
  int _ownershipRevision = 0;
  AdRemovalAction _action = AdRemovalAction.none;
  String? _message;

  bool get initialized => _initialized;
  bool get storeLoading => _storeLoading;
  bool get storeAvailable => _storeAvailable;
  bool get isOwned => _owned;
  bool get busy => _action != AdRemovalAction.none;
  bool get canPurchase =>
      _initialized && _storeAvailable && _product != null && !_owned && !busy;
  bool get canRestore => _initialized && _storeAvailable && !busy;
  AdRemovalAction get action => _action;
  String? get localizedPrice => _product?.price;
  String? get message => _message;

  Future<void> initialize() async {
    if (_initialized) return;
    _purchaseSubscription = _gateway.purchaseStream.listen(
      (purchases) => unawaited(_handlePurchases(purchases)),
      onError: _handlePurchaseStreamError,
    );
    try {
      _owned = await _ownershipStore.read();
    } catch (_) {
      _owned = false;
    }
    _initialized = true;
    if (_owned) await refreshOwnership();
    notifyListeners();
    unawaited(refreshStore());
  }

  Future<void> refreshOwnership() async {
    if (!_initialized || _checkingOwnership || busy) return;
    _checkingOwnership = true;
    final revision = _ownershipRevision;
    try {
      final active = await _gateway.hasActivePurchase(productId);
      if (active != null && revision == _ownershipRevision) {
        await _setOwned(active);
        notifyListeners();
      }
    } catch (_) {
      // Keep the last known state when the store cannot confirm ownership.
    } finally {
      _checkingOwnership = false;
    }
  }

  Future<void> refreshStore() async {
    if (!_initialized || _storeLoading) return;
    _storeLoading = true;
    _message = null;
    notifyListeners();
    try {
      _storeAvailable = await _gateway.isAvailable();
      if (!_storeAvailable) {
        _product = null;
        _message = '스토어에 연결할 수 없어요. 스토어 설치본에서 다시 확인해주세요.';
        return;
      }
      final response = await _gateway.queryProductDetails({productId});
      if (response.error != null) {
        _product = null;
        _message = '광고 제거 상품 정보를 불러오지 못했어요.';
        return;
      }
      _product = response.productDetails
          .where((product) => product.id == productId)
          .firstOrNull;
      if (_product == null) {
        _message = '스토어에서 광고 제거 상품을 찾지 못했어요.';
      }
    } catch (_) {
      _storeAvailable = false;
      _product = null;
      _message = '스토어에 연결하지 못했어요. 잠시 후 다시 시도해주세요.';
    } finally {
      _storeLoading = false;
      notifyListeners();
    }
  }

  Future<void> purchase() async {
    if (!_initialized) {
      throw const AdRemovalException('결제 기능을 준비하고 있어요. 잠시 후 다시 시도해주세요.');
    }
    if (_owned) return;
    final product = _product;
    if (!_storeAvailable || product == null) {
      await refreshStore();
    }
    final availableProduct = _product;
    if (!_storeAvailable || availableProduct == null) {
      throw AdRemovalException(
        _message ?? '광고 제거 상품을 불러오지 못했어요.',
      );
    }

    _action = AdRemovalAction.purchasing;
    _message = null;
    notifyListeners();
    try {
      final started = await _gateway.buyNonConsumable(
        purchaseParam: PurchaseParam(productDetails: availableProduct),
      );
      if (!started) {
        _action = AdRemovalAction.none;
        _message = '결제 화면을 열지 못했어요. 잠시 후 다시 시도해주세요.';
        notifyListeners();
        throw AdRemovalException(_message!);
      }
    } catch (error) {
      if (_action == AdRemovalAction.purchasing) {
        _action = AdRemovalAction.none;
        _message = error is AdRemovalException
            ? error.message
            : '결제를 시작하지 못했어요. 잠시 후 다시 시도해주세요.';
        notifyListeners();
      }
      if (error is AdRemovalException) rethrow;
      throw AdRemovalException(_message!);
    }
  }

  Future<void> restore() async {
    if (!_initialized) {
      throw const AdRemovalException('결제 기능을 준비하고 있어요. 잠시 후 다시 시도해주세요.');
    }
    if (!_storeAvailable) await refreshStore();
    if (!_storeAvailable) {
      throw AdRemovalException(
        _message ?? '스토어에 연결할 수 없어요.',
      );
    }

    _action = AdRemovalAction.restoring;
    _message = null;
    notifyListeners();
    try {
      await _gateway.restorePurchases();
      final active = await _gateway.hasActivePurchase(productId);
      if (active != null) {
        await _setOwned(active);
        _action = AdRemovalAction.none;
        _message = active ? '구매 내역이 적용됐어요.' : '복원할 광고 제거 구매 내역을 찾지 못했어요.';
      } else if (_action == AdRemovalAction.restoring) {
        _action = AdRemovalAction.none;
        _message = _owned ? '구매 내역이 적용됐어요.' : '복원할 광고 제거 구매 내역을 찾지 못했어요.';
      }
    } catch (_) {
      _action = AdRemovalAction.none;
      _message = '구매 내역을 복원하지 못했어요. 잠시 후 다시 시도해주세요.';
      notifyListeners();
      throw AdRemovalException(_message!);
    }
    notifyListeners();
  }

  Future<void> _handlePurchases(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (purchase.productID != productId) continue;
      switch (purchase.status) {
        case PurchaseStatus.pending:
          _action = AdRemovalAction.purchasing;
          _message = '스토어에서 결제를 처리하고 있어요.';
          break;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          try {
            final verified = await _verifyPurchase(purchase);
            if (verified) {
              await _setOwned(true);
              _message = purchase.status == PurchaseStatus.restored
                  ? '구매 내역이 복원됐어요.'
                  : '광고 제거 구매가 적용됐어요.';
            } else {
              _message = '구매 정보를 확인하지 못했어요. 구매 내역 복원을 다시 시도해주세요.';
            }
          } catch (_) {
            _message = '구매 권한을 저장하지 못했어요. 구매 내역 복원을 다시 시도해주세요.';
          } finally {
            _action = AdRemovalAction.none;
            if (purchase.pendingCompletePurchase) {
              try {
                await _gateway.completePurchase(purchase);
              } catch (_) {
                _message = '구매는 적용됐지만 스토어 처리를 마치지 못했어요. 앱을 다시 실행해주세요.';
              }
            }
          }
          break;
        case PurchaseStatus.error:
          _action = AdRemovalAction.none;
          _message = '결제를 완료하지 못했어요. 잠시 후 다시 시도해주세요.';
          break;
        case PurchaseStatus.canceled:
          _action = AdRemovalAction.none;
          _message = '결제가 취소됐어요.';
          break;
      }
      notifyListeners();
    }
  }

  Future<void> _setOwned(bool owned) async {
    if (_owned == owned) return;
    await _ownershipStore.write(owned);
    _owned = owned;
    _ownershipRevision += 1;
  }

  void _handlePurchaseStreamError(Object _) {
    _action = AdRemovalAction.none;
    _message = '스토어 결제 상태를 확인하지 못했어요.';
    notifyListeners();
  }

  static Future<bool> _hasStoreVerificationData(
      PurchaseDetails purchase) async {
    final verification = purchase.verificationData;
    return verification.serverVerificationData.isNotEmpty ||
        verification.localVerificationData.isNotEmpty;
  }

  @override
  void dispose() {
    unawaited(_purchaseSubscription?.cancel());
    super.dispose();
  }
}
