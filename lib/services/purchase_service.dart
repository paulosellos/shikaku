import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../models/store_product.dart';

typedef PurchaseGrantCallback = Future<void> Function(String sku);

/// Google Play Billing wrapper (Android-first).
class PurchaseService extends ChangeNotifier {
  InAppPurchase? _iap;
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  bool _available = false;
  bool _loading = false;
  String? _lastError;
  final Map<String, ProductDetails> _products = {};

  bool get isAvailable => _available;
  bool get isLoading => _loading;
  String? get lastError => _lastError;
  Map<String, ProductDetails> get products => Map.unmodifiable(_products);

  ProductDetails? productFor(String sku) => _products[sku];

  String? priceFor(String sku) => _products[sku]?.price;

  Future<void> initialize({
    required Future<void> Function() onRemoveAdsPurchased,
    PurchaseGrantCallback? onConsumablePurchased,
  }) async {
    _onRemoveAdsPurchased = onRemoveAdsPurchased;
    _onConsumablePurchased = onConsumablePurchased;

    try {
      _iap = InAppPurchase.instance;
      _available = await _iap!.isAvailable();
    } catch (e) {
      debugPrint('IAP unavailable: $e');
      _available = false;
      return;
    }

    if (!_available) return;

    _subscription ??= _iap!.purchaseStream.listen(
      _onPurchaseUpdates,
      onError: (Object error) {
        _lastError = error.toString();
        notifyListeners();
      },
    );

    await queryProducts();
  }

  Future<void> Function()? _onRemoveAdsPurchased;
  PurchaseGrantCallback? _onConsumablePurchased;

  Future<void> queryProducts() async {
    if (!_available || _iap == null) return;
    _loading = true;
    _lastError = null;
    notifyListeners();

    final response = await _iap!.queryProductDetails(StoreSkus.all.toSet());
    if (response.error != null) {
      _lastError = response.error!.message;
    }
    _products
      ..clear()
      ..addEntries(response.productDetails.map((p) => MapEntry(p.id, p)));
    for (final id in response.notFoundIDs) {
      debugPrint('IAP product not found: $id');
    }

    _loading = false;
    notifyListeners();
  }

  Future<bool> buy(String sku) async {
    if (!_available || _iap == null) return false;
    final product = _products[sku];
    if (product == null) {
      _lastError = 'Product unavailable: $sku';
      notifyListeners();
      return false;
    }

    final purchaseParam = PurchaseParam(productDetails: product);
    if (StoreSkus.nonConsumables.contains(sku)) {
      return _iap!.buyNonConsumable(purchaseParam: purchaseParam);
    }
    return _iap!.buyConsumable(purchaseParam: purchaseParam);
  }

  Future<void> restorePurchases() async {
    if (!_available || _iap == null) return;
    await _iap!.restorePurchases();
  }

  Future<void> _onPurchaseUpdates(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (purchase.status == PurchaseStatus.pending) continue;

      if (purchase.status == PurchaseStatus.error) {
        _lastError = purchase.error?.message;
        notifyListeners();
        continue;
      }

      if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        await _deliverPurchase(purchase);
      }

      if (purchase.pendingCompletePurchase && _iap != null) {
        await _iap!.completePurchase(purchase);
      }
    }
  }

  Future<void> _deliverPurchase(PurchaseDetails purchase) async {
    final sku = purchase.productID;
    if (sku == StoreSkus.removeAds) {
      await _onRemoveAdsPurchased?.call();
      return;
    }
    if (StoreSkus.consumables.contains(sku)) {
      await _onConsumablePurchased?.call(sku);
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
