import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// What Google Play says about a purchase token, as reported by our server.
enum VerifiedState {
  /// Paid and not refunded.
  valid,

  /// Payment not finished yet (e.g. cash at a store).
  pending,

  /// Cancelled, refunded, charged back or not a real purchase.
  invalid,
}

/// The server could not give an answer (offline, server error). Never
/// treated as a refund.
class VerifyUnavailable implements Exception {
  const VerifyUnavailable([this.detail]);

  final String? detail;

  @override
  String toString() => 'VerifyUnavailable($detail)';
}

/// Checks a purchase with Google Play from a server, which holds the
/// Google Play Developer API access. The app holds no credentials.
abstract class PurchaseVerifier {
  bool get isConfigured;

  /// Throws [VerifyUnavailable] when no answer could be had.
  Future<VerifiedState> verify({required String productId, required String token});
}

/// POSTs `{productId, purchaseToken}` to the verify function (see
/// server/README.md) and reads back `{state: valid|pending|invalid}`.
class HttpPurchaseVerifier implements PurchaseVerifier {
  HttpPurchaseVerifier(this.url, {http.Client? client}) : _client = client ?? http.Client();

  final String url;
  final http.Client _client;

  static const timeout = Duration(seconds: 20);

  @override
  bool get isConfigured => url.startsWith('https://');

  @override
  Future<VerifiedState> verify({required String productId, required String token}) async {
    if (!isConfigured) throw const VerifyUnavailable('not configured');
    final http.Response response;
    try {
      response = await _client
          .post(
            Uri.parse(url),
            headers: const {'content-type': 'application/json'},
            body: jsonEncode({'productId': productId, 'purchaseToken': token}),
          )
          .timeout(timeout);
    } on Exception catch (e) {
      throw VerifyUnavailable('$e');
    }
    if (response.statusCode != 200) throw VerifyUnavailable('HTTP ${response.statusCode}');
    final Object? body;
    try {
      body = jsonDecode(response.body);
    } on FormatException {
      throw const VerifyUnavailable('bad response');
    }
    return switch (body) {
      {'state': 'valid'} => VerifiedState.valid,
      {'state': 'pending'} => VerifiedState.pending,
      {'state': 'invalid'} => VerifiedState.invalid,
      _ => throw const VerifyUnavailable('bad response'),
    };
  }
}
