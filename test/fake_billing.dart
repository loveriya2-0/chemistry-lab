import 'dart:async';

import 'package:virtual_chemistry_lab/premium/billing_gateway.dart';
import 'package:virtual_chemistry_lab/premium/premium_config.dart';
import 'package:virtual_chemistry_lab/premium/purchase_verifier.dart';

const productId = PremiumConfig.defaultProductId;

StorePurchase purchase(StorePurchaseStatus status, {String token = 'token-1', bool needsCompletion = true}) =>
    StorePurchase(productId: productId, status: status, token: token, orderId: 'GPA.0000-$token', needsCompletion: needsCompletion);

/// Google Play stand-in: tests decide what the account owns and what the
/// purchase sheet reports.
class FakeBillingGateway extends BillingGateway {
  FakeBillingGateway({this.available = true, this.hasProduct = true, List<StorePurchase>? owned}) : owned = owned ?? [];

  /// False: Google Play cannot be asked (offline).
  bool reachable = true;

  bool available;
  bool hasProduct;

  /// What queryPastPurchases returns.
  List<StorePurchase> owned;

  /// Sent on the purchase stream when buy() is called; nothing when null
  /// (the sheet is still open).
  List<StorePurchase>? onBuy;

  final _updates = StreamController<List<StorePurchase>>.broadcast();
  final completed = <String>[];
  int buyCalls = 0;

  void emit(List<StorePurchase> purchases) => _updates.add(purchases);

  @override
  Stream<List<StorePurchase>> get purchaseUpdates => _updates.stream;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<StoreProduct?> product(String id) async => hasProduct ? StoreProduct(id: id, price: '₹99.00') : null;

  @override
  Future<bool> buy(StoreProduct product) async {
    buyCalls++;
    if (onBuy case final list?) scheduleMicrotask(() => emit(list));
    return true;
  }

  @override
  Future<List<StorePurchase>?> ownedPurchases() async => reachable ? List.of(owned) : null;

  @override
  Future<void> complete(StorePurchase purchase) async => completed.add(purchase.token);

  @override
  void dispose() => _updates.close();
}

/// The verify server stand-in: answers per token, or is unreachable.
class FakeVerifier implements PurchaseVerifier {
  FakeVerifier({this.isConfigured = true, Map<String, VerifiedState>? answers}) : answers = answers ?? {};

  @override
  bool isConfigured;

  final Map<String, VerifiedState> answers;

  /// Throws [VerifyUnavailable] when true (server down / offline).
  bool unreachable = false;
  final checked = <String>[];

  @override
  Future<VerifiedState> verify({required String productId, required String token}) async {
    checked.add(token);
    if (unreachable) throw const VerifyUnavailable('offline');
    return answers[token] ?? VerifiedState.invalid;
  }
}
