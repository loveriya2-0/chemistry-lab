import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:virtual_chemistry_lab/ai/tutor_service.dart';
import 'package:virtual_chemistry_lab/content/content_catalog.dart';
import 'package:virtual_chemistry_lab/content/content_repository.dart';
import 'package:virtual_chemistry_lab/lab/lab_tutorial.dart';
import 'package:virtual_chemistry_lab/main.dart';
import 'package:virtual_chemistry_lab/premium/billing_gateway.dart';
import 'package:virtual_chemistry_lab/premium/premium_controller.dart';
import 'package:virtual_chemistry_lab/premium/purchase_verifier.dart';
import 'package:virtual_chemistry_lab/state/app_state.dart';
import 'package:virtual_chemistry_lab/widgets/workstation_beaker.dart';

import 'fake_billing.dart';

ContentCatalog? _catalog;

/// The real verified content from assets/content, loaded once per test file.
/// Asset loading is real I/O, so it runs outside the fake test clock.
Future<ContentCatalog> loadCatalog(WidgetTester tester) async =>
    _catalog ??= (await tester.runAsync(() => ContentCatalog.load(ContentRepository())))!;

/// The purchase token of the Premium every test owns by default.
const ownedToken = 'owned-token';

FakeBillingGateway ownedPremiumBilling() =>
    FakeBillingGateway(owned: [purchase(StorePurchaseStatus.purchased, token: ownedToken, needsCompletion: false)]);

/// Pumps the app on a typical Android phone (393×851 dp) with [saved] as
/// the device's stored data. [board] is pre-selected (CBSE by default);
/// pass null to start on the Board Selection screen. The first-time lab
/// tutorial counts as already seen unless [tutorialSeen] is false, so lab
/// tests open the lab directly as before.
///
/// Premium is owned and verified unless [premium] is false, so existing
/// tests see PYQs and the full analysis as before; premium tests pass
/// their own [billing] and [verifier].
Future<SharedPreferences> launchApp(
  WidgetTester tester, {
  Map<String, Object> saved = const {},
  String? board = 'cbse',
  Size size = const Size(1080, 2340),
  double pixelRatio = 2.75,
  bool migrate = false,
  TutorService? tutor,
  bool tutorialSeen = true,
  bool premium = true,
  FakeBillingGateway? billing,
  FakeVerifier? verifier,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = pixelRatio;
  addTearDown(tester.view.reset);

  final catalog = await loadCatalog(tester);
  SharedPreferences.setMockInitialValues({
    AppState.boardKey: ?board,
    if (tutorialSeen) LabTutorial.seenKey: true,
    if (premium && billing == null) PremiumController.entitlementKey: '{"token":"$ownedToken"}',
    ...saved,
  });
  final prefs = await SharedPreferences.getInstance();
  if (migrate) await migrateLegacyProgress(prefs, catalog);
  billing ??= premium ? ownedPremiumBilling() : FakeBillingGateway();
  verifier ??= FakeVerifier(answers: {ownedToken: VerifiedState.valid});
  await tester.pumpWidget(VirtualChemistryLabApp(prefs: prefs, catalog: catalog, tutor: tutor, billing: billing, verifier: verifier));
  return prefs;
}

/// "Restarts" the app on data already saved in [prefs] (as after closing
/// and reopening it), without resetting the stored values.
Future<void> launchAppWith(WidgetTester tester, SharedPreferences prefs, {TutorService? tutor, FakeBillingGateway? billing, FakeVerifier? verifier}) async {
  final catalog = await loadCatalog(tester);
  await tester.pumpWidget(VirtualChemistryLabApp(
    prefs: prefs,
    catalog: catalog,
    tutor: tutor,
    billing: billing ?? ownedPremiumBilling(),
    verifier: verifier ?? FakeVerifier(answers: {ownedToken: VerifiedState.valid}),
  ));
  await tester.pump();
}

/// Scrolls the first scrollable until [finder] is on screen, then taps it.
Future<void> scrollAndTap(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(finder, 200, scrollable: find.byType(Scrollable).first);
  await tester.pumpAndSettle();
  // Centre it so a sticky header can't cover the tap point.
  await Scrollable.ensureVisible(tester.element(finder), alignment: 0.5); // zero duration: jumps
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// The "Open lab" button on sub-topic [number]'s row of a chapter's topic
/// list (several sub-topics of a chapter can offer labs).
Finder openLabOn(String number, {String openLab = 'Open lab'}) => find.descendant(
      // Not `.first`: the row may not be built yet while scrolling to it.
      of: find.ancestor(of: find.text(number), matching: find.byType(Row)),
      matching: find.text(openLab),
    );

/// CBSE Class 10 → Acids, Bases and Salts → §2.1.4 "Open lab" → View
/// practical → its guide → Start virtual lab (titration). Ends on the Focus
/// Mode setup screen.
Future<void> openTitrationSetup(WidgetTester tester, {String openLab = 'Open lab', String view = 'View practical', String start = 'Start virtual lab'}) async {
  await tester.tap(find.text('Class 10'));
  await tester.pumpAndSettle();
  await scrollAndTap(tester, find.text('Acids, Bases and Salts'));
  await scrollAndTap(tester, openLabOn('2.1.4', openLab: openLab));
  await tester.tap(find.text(view));
  await tester.pumpAndSettle();
  await tester.tap(find.text(start));
  await tester.pumpAndSettle();
}

/// Taps the burette button for [portion] ("+ 1.0 mL") [times] times.
Future<void> runBurette(WidgetTester tester, String portion, {int times = 1}) async {
  for (var i = 0; i < times; i++) {
    await tester.tap(find.text(portion));
    await tester.pump(const Duration(milliseconds: 300));
  }
}

/// Runs the whole titration (end point at 8.0 mL) with no mistakes:
/// NaOH, phenolphthalein, HCl into the burette, then 8 × 1.0 mL.
Future<void> completeTitration(WidgetTester tester) async {
  for (final label in ['NaOH', 'Phenolphthalein', 'HCl']) {
    await pour(tester, label);
  }
  await runBurette(tester, '+ 1.0 mL', times: 8);
}

/// Drags the bottle labelled [label] onto the beaker.
Future<void> pour(WidgetTester tester, String label) async {
  final gesture = await tester.startGesture(tester.getCenter(find.text(label)));
  await gesture.moveBy(const Offset(0, -40));
  await gesture.moveTo(tester.getCenter(find.byType(WorkstationBeaker)));
  await gesture.up();
  await tester.pump(const Duration(milliseconds: 400));
}

/// Settles a route that contains the endlessly animated beaker, where
/// pumpAndSettle would never return.
Future<void> pumpRoute(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}
