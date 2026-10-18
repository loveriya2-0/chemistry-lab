import 'package:flutter/foundation.dart';

/// Premium purchase settings, supplied at build time — never in source:
///
///   flutter build appbundle --dart-define=PREMIUM_VERIFY_URL=https://.../verifyPurchase
///
/// The product id must match the one-time product created in Google Play
/// Console. Without a verify URL the Premium screen says purchases are not
/// set up and nothing can be unlocked: Premium is only granted after the
/// server has confirmed the purchase with Google Play.
@immutable
class PremiumConfig {
  const PremiumConfig({this.productId = defaultProductId, this.verifyUrl = ''});

  factory PremiumConfig.fromEnvironment() => const PremiumConfig(
        productId: String.fromEnvironment('PREMIUM_PRODUCT_ID', defaultValue: defaultProductId),
        verifyUrl: String.fromEnvironment('PREMIUM_VERIFY_URL'),
      );

  static const defaultProductId = 'premium_lifetime';

  /// The intended Play Console price, shown only until Google Play returns
  /// the real localised price.
  static const intendedPrice = '₹99';

  final String productId;
  final String verifyUrl;

  bool get canVerify => verifyUrl.startsWith('https://');
}
