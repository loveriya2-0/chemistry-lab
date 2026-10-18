import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:virtual_chemistry_lab/data/practical_attempt_store.dart';
import 'package:virtual_chemistry_lab/models/practical_attempt.dart';
import 'package:virtual_chemistry_lab/premium/billing_gateway.dart';
import 'package:virtual_chemistry_lab/premium/premium_controller.dart';
import 'package:virtual_chemistry_lab/premium/purchase_verifier.dart';
import 'package:virtual_chemistry_lab/screens/premium_screen.dart';
import 'package:virtual_chemistry_lab/state/app_state.dart';

import 'fake_billing.dart';
import 'test_helpers.dart';

Future<(PremiumController, FakeBillingGateway, FakeVerifier, SharedPreferences)> _controller({
  Map<String, Object> saved = const {},
  FakeBillingGateway? billing,
  FakeVerifier? verifier,
}) async {
  SharedPreferences.setMockInitialValues(saved);
  final prefs = await SharedPreferences.getInstance();
  billing ??= FakeBillingGateway();
  verifier ??= FakeVerifier();
  final c = PremiumController(prefs: prefs, billing: billing, verifier: verifier);
  addTearDown(c.dispose);
  await c.start();
  return (c, billing, verifier, prefs);
}

/// A cached, earlier-verified purchase with [token].
Map<String, Object> _cached(String token) => {PremiumController.entitlementKey: jsonEncode({'token': token})};

/// One finished titration 30 minutes ago, so the Progress tab has data.
Map<String, Object> _progressData() {
  final at = DateTime.now().subtract(const Duration(minutes: 30));
  final attempt = PracticalAttempt(
    id: '1',
    startedAt: at.subtract(const Duration(minutes: 5)),
    endedAt: at,
    classLevel: 10,
    chapterId: 'cbse-10-ch02',
    topicId: 'cbse-10-ch02-t2.1.4',
    practicalId: 'acid_base_titration',
    correctActions: 5,
    wrongActions: 1,
    completions: 1,
    bestSteps: 5,
    totalSteps: 5,
  );
  return {PracticalAttemptStore.storageKey: [jsonEncode(attempt.toJson())]};
}

void main() {
  group('purchase flow', () {
    test('a new user is free; Buy is offered at Google Play\'s price', () async {
      final (c, _, _, _) = await _controller();
      expect(c.status, PremiumStatus.free);
      expect(c.isPremium, isFalse);
      expect(c.canBuy, isTrue);
      expect(c.price, '₹99.00');
    });

    test('a verified purchase unlocks Premium, is acknowledged and remembered', () async {
      final (c, billing, verifier, prefs) = await _controller();
      verifier.answers['token-1'] = VerifiedState.valid;
      billing.onBuy = [purchase(StorePurchaseStatus.purchased)];
      await c.buy();
      await pumpEventQueue();

      expect(c.isPremium, isTrue);
      expect(c.notice, PremiumNotice.purchased);
      expect(verifier.checked, ['token-1']);
      expect(billing.completed, ['token-1']);
      expect(prefs.getString(PremiumController.entitlementKey), contains('token-1'));
    });

    test('Google Play saying "purchased" is not enough: the server must confirm it', () async {
      final (c, billing, verifier, prefs) = await _controller();
      billing.onBuy = [purchase(StorePurchaseStatus.purchased)]; // server answers invalid
      await c.buy();
      await pumpEventQueue();

      expect(c.isPremium, isFalse);
      expect(c.notice, PremiumNotice.rejected);
      expect(billing.completed, isEmpty, reason: 'unverified purchases are left for Google to refund');
      expect(prefs.getString(PremiumController.entitlementKey), isNull);
    });

    test('server unreachable after paying: stays locked, asks to restore, not acknowledged', () async {
      final (c, billing, verifier, _) = await _controller();
      verifier.unreachable = true;
      billing.onBuy = [purchase(StorePurchaseStatus.purchased)];
      await c.buy();
      await pumpEventQueue();

      expect(c.isPremium, isFalse);
      expect(c.notice, PremiumNotice.verifyFailed);
      expect(billing.completed, isEmpty);

      // Back online: Restore finds the purchase and verifies it.
      verifier
        ..unreachable = false
        ..answers['token-1'] = VerifiedState.valid;
      billing.owned = [purchase(StorePurchaseStatus.purchased)];
      await c.restore();
      expect(c.isPremium, isTrue);
      expect(c.notice, PremiumNotice.restored);
      expect(billing.completed, ['token-1']);
    });

    test('pending payment waits, then unlocks when Google Play confirms it', () async {
      final (c, billing, verifier, _) = await _controller();
      billing.onBuy = [purchase(StorePurchaseStatus.pending)];
      await c.buy();
      await pumpEventQueue();
      expect(c.status, PremiumStatus.pending);
      expect(c.isPremium, isFalse);
      expect(c.notice, PremiumNotice.pending);
      expect(c.canBuy, isFalse, reason: 'no second purchase while one is pending');

      verifier.answers['token-1'] = VerifiedState.valid;
      billing.emit([purchase(StorePurchaseStatus.purchased)]);
      await pumpEventQueue();
      expect(c.isPremium, isTrue);
    });

    test('a pending payment that is never completed goes back to free', () async {
      final (c, billing, _, _) = await _controller();
      billing.onBuy = [purchase(StorePurchaseStatus.pending)];
      await c.buy();
      await pumpEventQueue();
      billing.owned = [];
      await c.restore();
      expect(c.status, PremiumStatus.free);
      expect(c.notice, PremiumNotice.cancelled);
    });

    test('server still reports pending: Premium stays locked', () async {
      final (c, billing, verifier, _) = await _controller();
      verifier.answers['token-1'] = VerifiedState.pending;
      billing.onBuy = [purchase(StorePurchaseStatus.purchased)];
      await c.buy();
      await pumpEventQueue();
      expect(c.status, PremiumStatus.pending);
      expect(billing.completed, isEmpty);
    });

    test('cancelled and failed purchases change nothing and say so', () async {
      final (c, billing, _, _) = await _controller();
      billing.onBuy = [purchase(StorePurchaseStatus.cancelled)];
      await c.buy();
      await pumpEventQueue();
      expect(c.isPremium, isFalse);
      expect(c.notice, PremiumNotice.cancelled);
      expect(c.busy, isFalse);

      billing.onBuy = [purchase(StorePurchaseStatus.error)];
      await c.buy();
      await pumpEventQueue();
      expect(c.isPremium, isFalse);
      expect(c.notice, PremiumNotice.failed);
      expect(c.canBuy, isTrue);
    });

    test('other products on the stream are ignored', () async {
      final (c, billing, verifier, _) = await _controller();
      verifier.answers['x'] = VerifiedState.valid;
      billing.emit([const StorePurchase(productId: 'something_else', status: StorePurchaseStatus.purchased, token: 'x')]);
      await pumpEventQueue();
      expect(c.isPremium, isFalse);
      expect(verifier.checked, isEmpty);
    });
  });

  group('cannot buy', () {
    test('without a verify server nothing can be bought or unlocked', () async {
      final (c, billing, _, _) = await _controller(
        billing: FakeBillingGateway(owned: [purchase(StorePurchaseStatus.purchased)]),
        verifier: FakeVerifier(isConfigured: false),
      );
      expect(c.unavailable, PremiumUnavailable.notConfigured);
      expect(c.canBuy, isFalse);
      await c.buy();
      expect(billing.buyCalls, 0);
    });

    test('Google Play missing or product not set up', () async {
      final (c1, _, _, _) = await _controller(billing: FakeBillingGateway(available: false));
      expect(c1.unavailable, PremiumUnavailable.storeUnavailable);
      expect(c1.price, '₹99', reason: 'intended price until Play answers');

      final (c2, _, _, _) = await _controller(billing: FakeBillingGateway(hasProduct: false));
      expect(c2.unavailable, PremiumUnavailable.productUnavailable);
      expect(c2.canBuy, isFalse);
    });
  });

  group('restore and refunds', () {
    test('Restore on a new phone finds and verifies the purchase', () async {
      final (c, billing, verifier, _) = await _controller();
      verifier.answers['token-1'] = VerifiedState.valid;
      billing.owned = [purchase(StorePurchaseStatus.purchased, needsCompletion: false)];
      await c.restore();
      expect(c.isPremium, isTrue);
      expect(c.notice, PremiumNotice.restored);
      expect(billing.completed, isEmpty, reason: 'already acknowledged');
    });

    test('purchases are re-checked at start, so Premium returns after reinstall', () async {
      final (c, _, _, _) = await _controller(
        billing: FakeBillingGateway(owned: [purchase(StorePurchaseStatus.purchased)]),
        verifier: FakeVerifier(answers: {'token-1': VerifiedState.valid}),
      );
      expect(c.isPremium, isTrue);
    });

    test('Restore with nothing bought says so', () async {
      final (c, _, _, _) = await _controller();
      await c.restore();
      expect(c.isPremium, isFalse);
      expect(c.notice, PremiumNotice.nothingToRestore);
    });

    test('refunded purchase (no longer owned on Play) removes Premium at start', () async {
      final (c, _, _, prefs) = await _controller(saved: _cached('token-1'), billing: FakeBillingGateway(owned: []));
      expect(c.isPremium, isFalse);
      expect(c.notice, PremiumNotice.revoked);
      expect(prefs.getString(PremiumController.entitlementKey), isNull);
    });

    test('refund reported by the server removes Premium', () async {
      final (c, _, _, prefs) = await _controller(
        saved: _cached('token-1'),
        billing: FakeBillingGateway(owned: [purchase(StorePurchaseStatus.purchased, needsCompletion: false)]),
        verifier: FakeVerifier(answers: {'token-1': VerifiedState.invalid}),
      );
      expect(c.isPremium, isFalse);
      expect(c.notice, PremiumNotice.revoked);
      expect(prefs.getString(PremiumController.entitlementKey), isNull);
    });

    test('offline: a verified purchase keeps working', () async {
      final (c1, _, _, _) = await _controller(saved: _cached('token-1'), billing: FakeBillingGateway()..reachable = false);
      expect(c1.isPremium, isTrue, reason: 'Play unreachable is not a refund');

      final verifier = FakeVerifier()..unreachable = true;
      final (c2, _, _, _) = await _controller(
        saved: _cached('token-1'),
        billing: FakeBillingGateway(owned: [purchase(StorePurchaseStatus.purchased)]),
        verifier: verifier,
      );
      expect(c2.isPremium, isTrue, reason: 'server unreachable is not a refund');
    });
  });

  group('HttpPurchaseVerifier', () {
    test('sends the token and reads the state', () async {
      late Map<String, dynamic> sent;
      final v = HttpPurchaseVerifier('https://example.test/verify', client: MockClient((req) async {
        sent = jsonDecode(req.body) as Map<String, dynamic>;
        return http.Response('{"state":"valid"}', 200);
      }));
      expect(await v.verify(productId: productId, token: 'abc'), VerifiedState.valid);
      expect(sent, {'productId': productId, 'purchaseToken': 'abc'});
    });

    test('server errors and bad replies are "no answer", never invalid', () async {
      for (final response in [http.Response('oops', 500), http.Response('not json', 200), http.Response('{"state":"maybe"}', 200)]) {
        final v = HttpPurchaseVerifier('https://example.test/verify', client: MockClient((_) async => response));
        await expectLater(v.verify(productId: productId, token: 'abc'), throwsA(isA<VerifyUnavailable>()));
      }
    });

    test('only https URLs count as configured', () {
      expect(HttpPurchaseVerifier('').isConfigured, isFalse);
      expect(HttpPurchaseVerifier('http://insecure.test').isConfigured, isFalse);
      expect(HttpPurchaseVerifier('https://ok.test').isConfigured, isTrue);
    });
  });

  group('locked features in the app', () {
    Future<void> tab(WidgetTester tester, String label) async {
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
    }

    testWidgets('free user: PYQs are locked; basic practice stays free', (tester) async {
      await launchApp(tester, premium: false, saved: {AppState.classKey: 10});
      await tester.pumpAndSettle();
      await tab(tester, 'Exam');

      expect(find.byKey(const Key('premium-locked')), findsOneWidget);
      expect(find.byIcon(Icons.lock_rounded), findsWidgets);

      await scrollAndTap(tester, find.text('Chapter-wise'));
      await scrollAndTap(tester, find.text('Acids, Bases and Salts'));
      expect(find.text('Premium feature'), findsOneWidget);
      expect(find.text('Previous-year questions with answers are part of Premium.'), findsOneWidget);
      expect(find.byType(ListTile).evaluate().where((e) => (e.widget as ListTile).subtitle != null), isEmpty,
          reason: 'no PYQ rows behind the lock');
    });

    testWidgets('buying from the lock card unlocks PYQs', (tester) async {
      final billing = FakeBillingGateway()..onBuy = [purchase(StorePurchaseStatus.purchased)];
      final verifier = FakeVerifier(answers: {'token-1': VerifiedState.valid});
      await launchApp(tester, premium: false, billing: billing, verifier: verifier, saved: {AppState.classKey: 10});
      await tester.pumpAndSettle();
      await tab(tester, 'Exam');

      await tester.tap(find.text('Unlock for ₹99.00'));
      await tester.pumpAndSettle();
      expect(find.byType(PremiumScreen), findsOneWidget);
      expect(find.byKey(const Key('premium-price')), findsOneWidget);
      expect(find.text('Chapter-wise PYQs'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Extra mock tests and practice questions'), 300, scrollable: find.byType(Scrollable).first);
      expect(find.text('Coming soon · included at no extra cost'), findsNWidgets(2));

      await tester.tap(find.byKey(const Key('buy-premium')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('buy-premium')), findsNothing);
      await tester.scrollUntilVisible(find.text('Premium is active'), -300, scrollable: find.byType(Scrollable).first);
      expect(find.text('Premium is active'), findsOneWidget);
      expect(billing.completed, ['token-1']);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('premium-locked')), findsNothing);
      expect(find.byIcon(Icons.lock_rounded), findsNothing);
    });

    testWidgets('Premium screen explains why Buy is disabled', (tester) async {
      await launchApp(tester, premium: false, verifier: FakeVerifier(isConfigured: false), saved: {AppState.classKey: 10});
      await tester.pumpAndSettle();
      await tab(tester, 'Exam');
      await tester.tap(find.text('Unlock for ₹99.00'));
      await tester.pumpAndSettle();

      final buy = tester.widget<ButtonStyleButton>(find.byKey(const Key('buy-premium')));
      expect(buy.onPressed, isNull);
      expect(find.text('Purchases are not set up in this version of the app.'), findsOneWidget);
    });

    testWidgets('Progress: overview free, detailed analysis locked', (tester) async {
      await launchApp(tester, premium: false, saved: _progressData());
      await tester.pumpAndSettle();
      await tab(tester, 'Progress');
      expect(find.text('Overall Chemistry Progress'), findsOneWidget);
      await tester.scrollUntilVisible(find.byKey(const Key('premium-locked')), 300, scrollable: find.byType(Scrollable).first);
      expect(find.text('Accuracy breakdown and chapter-wise progress are part of Premium.'), findsOneWidget);
      expect(find.text('Chapter & topic progress'), findsNothing);
    });

    testWidgets('Progress: Premium shows the detailed analysis', (tester) async {
      await launchApp(tester, saved: _progressData()); // Premium owned
      await tester.pumpAndSettle();
      await tab(tester, 'Progress');
      await tester.scrollUntilVisible(find.text('Chapter & topic progress'), 300, scrollable: find.byType(Scrollable).first);
      expect(find.byKey(const Key('premium-locked')), findsNothing);
    });

    testWidgets('Premium screen and Settings entry in Hindi', (tester) async {
      await launchApp(tester, premium: false, saved: {'app_language': 'hi', AppState.classKey: 10});
      await tester.pumpAndSettle();
      await tab(tester, 'परीक्षा');
      await tester.tap(find.text('₹99.00 में अनलॉक करें'));
      await tester.pumpAndSettle();
      expect(find.text('प्रीमियम खरीदें · ₹99.00'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('खरीद रीस्टोर करें'), 300, scrollable: find.byType(Scrollable).first);
      expect(tester.takeException(), isNull);
    });
  });
}
