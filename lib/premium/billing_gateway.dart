import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';

enum StorePurchaseStatus { pending, purchased, restored, cancelled, error }

/// A Google Play purchase, independent of the plugin so it can be faked in
/// tests.
@immutable
class StorePurchase {
  const StorePurchase({
    required this.productId,
    required this.status,
    this.token = '',
    this.orderId,
    this.needsCompletion = false,
    this.errorCode,
    this.handle,
  });

  final String productId;
  final StorePurchaseStatus status;

  /// Play's purchase token: what the server verifies.
  final String token;
  final String? orderId;

  /// Not yet acknowledged; Google refunds it after 3 days unless completed.
  final bool needsCompletion;
  final String? errorCode;

  /// The plugin's own object, passed back when completing.
  final Object? handle;
}

@immutable
class StoreProduct {
  const StoreProduct({required this.id, required this.price, this.handle});

  final String id;

  /// Localised price from Google Play, e.g. "₹99.00".
  final String price;
  final Object? handle;
}

/// Google Play Billing as the app uses it.
abstract class BillingGateway {
  /// New purchases and their changes (pending → purchased, cancelled…).
  Stream<List<StorePurchase>> get purchaseUpdates;

  Future<bool> isAvailable();

  /// Null when the product is not set up (or not active) in Play Console.
  Future<StoreProduct?> product(String id);

  /// Opens Google Play's purchase sheet. The outcome arrives on
  /// [purchaseUpdates].
  Future<bool> buy(StoreProduct product);

  /// What this Play account owns now. Refunded and revoked purchases are
  /// no longer listed. Null when Google Play could not be asked (offline),
  /// so a failed check is never mistaken for a refund.
  Future<List<StorePurchase>?> ownedPurchases();

  /// Acknowledges a verified purchase.
  Future<void> complete(StorePurchase purchase);

  void dispose() {}
}

/// No store: web, desktop, or Android without Google Play.
class UnavailableBillingGateway extends BillingGateway {
  @override
  Stream<List<StorePurchase>> get purchaseUpdates => const Stream.empty();
  @override
  Future<bool> isAvailable() async => false;
  @override
  Future<StoreProduct?> product(String id) async => null;
  @override
  Future<bool> buy(StoreProduct product) async => false;
  @override
  Future<List<StorePurchase>?> ownedPurchases() async => null;
  @override
  Future<void> complete(StorePurchase purchase) async {}
}

/// Google Play Billing through the Flutter team's `in_app_purchase` plugin.
class PlayBillingGateway extends BillingGateway {
  PlayBillingGateway([InAppPurchase? iap]) : _iap = iap ?? InAppPurchase.instance;

  /// Play on Android; nothing elsewhere.
  static BillingGateway forPlatform() =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android ? PlayBillingGateway() : UnavailableBillingGateway();

  final InAppPurchase _iap;

  @override
  Stream<List<StorePurchase>> get purchaseUpdates => _iap.purchaseStream.map((list) => [for (final p in list) _wrap(p)]);

  @override
  Future<bool> isAvailable() => _iap.isAvailable();

  @override
  Future<StoreProduct?> product(String id) async {
    final response = await _iap.queryProductDetails({id});
    if (response.error != null) return null;
    for (final p in response.productDetails) {
      if (p.id == id) return StoreProduct(id: p.id, price: p.price, handle: p);
    }
    return null;
  }

  @override
  Future<bool> buy(StoreProduct product) =>
      _iap.buyNonConsumable(purchaseParam: PurchaseParam(productDetails: product.handle! as ProductDetails));

  @override
  Future<List<StorePurchase>?> ownedPurchases() async {
    final addition = _iap.getPlatformAddition<InAppPurchaseAndroidPlatformAddition>();
    final response = await addition.queryPastPurchases();
    if (response.error != null) return null;
    return [for (final p in response.pastPurchases) _wrap(p)];
  }

  @override
  Future<void> complete(StorePurchase purchase) async {
    final handle = purchase.handle;
    if (handle is PurchaseDetails) await _iap.completePurchase(handle);
  }

  static StorePurchase _wrap(PurchaseDetails p) => StorePurchase(
        productId: p.productID,
        status: switch (p.status) {
          PurchaseStatus.pending => StorePurchaseStatus.pending,
          PurchaseStatus.purchased => StorePurchaseStatus.purchased,
          PurchaseStatus.restored => StorePurchaseStatus.restored,
          PurchaseStatus.canceled => StorePurchaseStatus.cancelled,
          PurchaseStatus.error => StorePurchaseStatus.error,
        },
        token: p.verificationData.serverVerificationData,
        orderId: p.purchaseID,
        // Android: unacknowledged until completed.
        needsCompletion: p is GooglePlayPurchaseDetails ? !p.billingClientPurchase.isAcknowledged : p.pendingCompletePurchase,
        errorCode: p.error?.message,
        handle: p,
      );
}
