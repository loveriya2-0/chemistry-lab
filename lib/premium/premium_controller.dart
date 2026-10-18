import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'billing_gateway.dart';
import 'premium_config.dart';
import 'purchase_verifier.dart';

enum PremiumStatus {
  /// Not bought (or refunded).
  free,

  /// Bought, payment not finished; unlocks when Google Play confirms it.
  pending,

  /// Bought and confirmed by the server.
  active,
}

/// The latest thing worth telling the student, shown on the Premium screen.
enum PremiumNotice {
  purchased,
  restored,
  nothingToRestore,
  pending,
  cancelled,
  failed,

  /// Google Play took the payment but the server could not confirm it yet.
  verifyFailed,

  /// A purchase the server rejected (not a real or valid purchase).
  rejected,

  /// Premium was removed: the purchase was refunded or revoked.
  revoked,
}

/// Why the Buy button cannot be used right now.
enum PremiumUnavailable { notConfigured, storeUnavailable, productUnavailable }

/// Premium: a one-time Google Play purchase, unlocked only after the
/// server has verified it with Google Play.
///
/// The verified purchase is remembered on the device so Premium works
/// offline. On every start (and on Restore) Google Play is asked what this
/// account owns and each purchase is verified again, so a refund or
/// revocation removes Premium the next time the app is online.
class PremiumController extends ChangeNotifier {
  PremiumController({
    required this._prefs,
    required this._billing,
    required this._verifier,
    this.productId = PremiumConfig.defaultProductId,
  }) {
    _status = _cachedToken != null ? PremiumStatus.active : PremiumStatus.free;
  }

  /// The verified purchase: `{"token": ..., "orderId": ..., "verifiedAt": ...}`.
  static const entitlementKey = 'premium_entitlement';

  final SharedPreferences _prefs;
  final BillingGateway _billing;
  final PurchaseVerifier _verifier;
  final String productId;

  StreamSubscription<List<StorePurchase>>? _subscription;
  late PremiumStatus _status;
  PremiumNotice? _notice;
  StoreProduct? _product;
  bool _storeAvailable = false;
  bool _busy = false;
  bool _started = false;
  bool _disposed = false;

  PremiumStatus get status => _status;
  bool get isPremium => _status == PremiumStatus.active;
  PremiumNotice? get notice => _notice;

  /// A purchase or restore is in progress.
  bool get busy => _busy;

  /// Google Play's price once loaded; the intended price until then.
  String get price => _product?.price ?? PremiumConfig.intendedPrice;

  PremiumUnavailable? get unavailable {
    if (!_verifier.isConfigured) return PremiumUnavailable.notConfigured;
    if (!_storeAvailable) return PremiumUnavailable.storeUnavailable;
    if (_product == null) return PremiumUnavailable.productUnavailable;
    return null;
  }

  bool get canBuy => unavailable == null && !_busy && _status == PremiumStatus.free;

  String? get _cachedToken {
    final raw = _prefs.getString(entitlementKey);
    if (raw == null) return null;
    try {
      return (jsonDecode(raw) as Map<String, dynamic>)['token'] as String?;
    } on Object {
      return null;
    }
  }

  /// Connects to Google Play and re-checks what this account owns.
  Future<void> start() async {
    if (_started) return;
    _started = true;
    _subscription = _billing.purchaseUpdates.listen(_onUpdates, onError: (_) => _finish(PremiumNotice.failed));
    try {
      _storeAvailable = await _billing.isAvailable();
      if (!_storeAvailable) return;
      _product = await _billing.product(productId);
      await _sync(userAsked: false);
    } on Object {
      // Offline or Play unavailable: keep what was verified before.
    } finally {
      _changed();
    }
  }

  Future<void> buy() async {
    if (!canBuy) return;
    _busy = true;
    _notice = null;
    _changed();
    try {
      if (!await _billing.buy(_product!)) _finish(PremiumNotice.failed);
    } on Object {
      // Already owned on this account, or Play refused: re-check ownership.
      _busy = false;
      await restore();
    }
  }

  /// Asks Google Play what this account owns and verifies it.
  Future<void> restore() async {
    if (_busy) return;
    _busy = true;
    _notice = null;
    _changed();
    try {
      if (!_storeAvailable) _storeAvailable = await _billing.isAvailable();
      if (_storeAvailable) _product ??= await _billing.product(productId);
      if (!_storeAvailable) {
        _notice = PremiumNotice.failed;
      } else {
        await _sync(userAsked: true);
      }
    } on Object {
      _notice = PremiumNotice.failed;
    } finally {
      _busy = false;
      _changed();
    }
  }

  Future<void> _sync({required bool userAsked}) async {
    final owned = await _billing.ownedPurchases();
    if (owned == null) {
      if (userAsked) _notice = PremiumNotice.failed;
      return;
    }
    final mine = [for (final p in owned) if (p.productId == productId) p];
    if (mine.isEmpty) {
      if (_status == PremiumStatus.active) {
        _revoke();
      } else if (_status == PremiumStatus.pending) {
        // The pending payment was never completed.
        _status = PremiumStatus.free;
        _notice = PremiumNotice.cancelled;
      }
      if (userAsked && _notice == null) _notice = PremiumNotice.nothingToRestore;
      return;
    }
    for (final p in mine) {
      await _handle(p, restored: true, userAsked: userAsked);
    }
  }

  Future<void> _onUpdates(List<StorePurchase> purchases) async {
    for (final p in purchases) {
      if (p.productId != productId) continue;
      await _handle(p, restored: p.status == StorePurchaseStatus.restored, userAsked: true);
    }
    _busy = false;
    _changed();
  }

  Future<void> _handle(StorePurchase p, {required bool restored, required bool userAsked}) async {
    switch (p.status) {
      case StorePurchaseStatus.pending:
        if (_status != PremiumStatus.active) _status = PremiumStatus.pending;
        if (userAsked) _notice = PremiumNotice.pending;
      case StorePurchaseStatus.cancelled:
        if (_status == PremiumStatus.pending) _status = PremiumStatus.free;
        _notice = PremiumNotice.cancelled;
      case StorePurchaseStatus.error:
        if (_status == PremiumStatus.pending) _status = PremiumStatus.free;
        _notice = PremiumNotice.failed;
      case StorePurchaseStatus.purchased || StorePurchaseStatus.restored:
        await _verify(p, restored: restored, userAsked: userAsked);
    }
  }

  Future<void> _verify(StorePurchase p, {required bool restored, required bool userAsked}) async {
    final VerifiedState result;
    try {
      result = await _verifier.verify(productId: p.productId, token: p.token);
    } on VerifyUnavailable {
      // No answer: a purchase verified before stays; a new one waits.
      if (_cachedToken != p.token && userAsked) _notice = PremiumNotice.verifyFailed;
      return;
    }
    switch (result) {
      case VerifiedState.valid:
        await _prefs.setString(
          entitlementKey,
          jsonEncode({'token': p.token, 'orderId': p.orderId, 'verifiedAt': DateTime.now().toIso8601String()}),
        );
        final wasActive = _status == PremiumStatus.active;
        _status = PremiumStatus.active;
        if (userAsked || !wasActive) _notice = restored ? PremiumNotice.restored : PremiumNotice.purchased;
        // Acknowledge only verified purchases; anything else is refunded
        // by Google after 3 days.
        if (p.needsCompletion) await _billing.complete(p);
      case VerifiedState.pending:
        if (_status != PremiumStatus.active) _status = PremiumStatus.pending;
        if (userAsked) _notice = PremiumNotice.pending;
      case VerifiedState.invalid:
        if (_cachedToken == p.token || _status == PremiumStatus.active) {
          _revoke();
        } else {
          _status = PremiumStatus.free;
          _notice = PremiumNotice.rejected;
        }
    }
  }

  void _revoke() {
    _prefs.remove(entitlementKey);
    _status = PremiumStatus.free;
    _notice = PremiumNotice.revoked;
  }

  void _finish(PremiumNotice notice) {
    _busy = false;
    _notice = notice;
    _changed();
  }

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _subscription?.cancel();
    _billing.dispose();
    super.dispose();
  }
}
