import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:virtual_chemistry_lab/content/content_catalog.dart';
import 'package:virtual_chemistry_lab/content/content_repository.dart';
import 'package:virtual_chemistry_lab/data/practical_attempt_store.dart';
import 'package:virtual_chemistry_lab/data/practicals_repository.dart';
import 'package:virtual_chemistry_lab/models/focus_session.dart';
import 'package:virtual_chemistry_lab/models/practical.dart';
import 'package:virtual_chemistry_lab/models/practical_path.dart';
import 'package:virtual_chemistry_lab/screens/virtual_lab_screen.dart';
import 'package:virtual_chemistry_lab/state/app_state.dart';
import 'package:virtual_chemistry_lab/state/focus_controller.dart';
import 'package:virtual_chemistry_lab/state/lab_controller.dart';

import 'test_helpers.dart';

late LoadedCurriculum _cbse;
const _repo = PracticalsRepository();

/// Class 10 → Lab tab → [title] → its guide → plain lab (no Focus Mode).
Future<void> _openLab(WidgetTester tester, String title) async {
  await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('Lab')));
  await tester.pumpAndSettle();
  await scrollAndTap(tester, find.text(title));
  await tester.tap(find.text('Start virtual lab'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Start without Focus Mode'));
  await pumpRoute(tester);
  expect(find.byType(VirtualLabScreen), findsOneWidget);
}

Future<void> _dismissWarning(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 400)); // dialog entry
  await tester.tap(find.text('Try Again'));
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    _cbse = (await ContentCatalog.load(ContentRepository())).curriculum('cbse')!;
  });

  group('titration calculations (checked against hand arithmetic)', () {
    final hcl = _repo.byId('acid_base_titration');
    final oxalic = _repo.byId('oxalic_acid_titration');

    test('NaOH + HCl is 1 : 1, so c(NaOH) = c(HCl) × V(HCl) ÷ V(NaOH)', () {
      final calc = hcl.calculation!;
      expect((calc.knownCoefficient, calc.unknownCoefficient), (1, 1));
      // 0.1 × 8.0 ÷ 10.0 = 0.08; 0.1 × 12.5 ÷ 10.0 = 0.125.
      expect(calc.unknownMolarity(8.0), closeTo(0.08, 1e-12));
      expect(calc.unknownMolarity(12.5), closeTo(0.125, 1e-12));
      // Moles of acid run in = moles of base taken, at any reading.
      for (final v in [5.0, 8.0, 9.7]) {
        expect(0.1 * v, closeTo(calc.unknownMolarity(v) * 10.0, 1e-12), reason: '$v mL');
      }
      expect(calc.working(8.0), 'c(NaOH) = 0.1 × 8.0 ÷ 10.0 = 0.080 M');
    });

    test('H₂C₂O₄ + 2NaOH is 1 : 2, so c(NaOH) = 2 × c(H₂C₂O₄) × V(H₂C₂O₄) ÷ V(NaOH)', () {
      final calc = oxalic.calculation!;
      expect((calc.knownCoefficient, calc.unknownCoefficient), (1, 2));
      // 2 × 0.05 × 10.0 ÷ 12.5 = 1.0 ÷ 12.5 = 0.08.
      expect(calc.unknownMolarity(12.5), closeTo(0.08, 1e-12));
      // Moles of NaOH run in = 2 × moles of oxalic acid pipetted (0.5 mmol), at any reading.
      for (final v in [10.0, 12.5, 20.0]) {
        expect(calc.unknownMolarity(v) * v, closeTo(2 * 0.05 * 10.0, 1e-12), reason: '$v mL');
      }
      expect(calc.working(12.5), 'c(NaOH) = 2 × 0.05 × 10.0 ÷ 12.5 = 0.080 M');
    });

    test('each end point is the one the hidden 0.080 M NaOH really needs', () {
      // HCl into 10.0 mL of 0.080 M NaOH: V = 0.080 × 10.0 ÷ 0.1 = 8.0 mL.
      expect(hcl.steps.last.titration!.endPointMl, closeTo(0.080 * 10.0 / 0.1, 1e-12));
      // 0.080 M NaOH into 10.0 mL of 0.05 M oxalic acid: V = 2 × 0.05 × 10.0 ÷ 0.080 = 12.5 mL.
      expect(oxalic.steps.last.titration!.endPointMl, closeTo(2 * 0.05 * 10.0 / 0.080, 1e-12));
      for (final p in [hcl, oxalic]) {
        expect(p.calculation!.unknownMolarity(p.steps.last.titration!.endPointMl), closeTo(0.080, 1e-12), reason: p.id);
      }
    });

    test('the balanced equations shown agree with the mole ratios used', () {
      expect(hcl.conclusion.en, startsWith('NaOH + HCl → NaCl + H₂O'));
      expect(oxalic.conclusion.en, startsWith('H₂C₂O₄ + 2NaOH → Na₂C₂O₄ + 2H₂O'));
      expect(oxalic.conclusion.hi, startsWith('H₂C₂O₄ + 2NaOH → Na₂C₂O₄ + 2H₂O'));
      expect(_cbse.guideFor('oxalic_acid_titration')!.equation, 'H₂C₂O₄(aq) + 2NaOH(aq) → Na₂C₂O₄(aq) + 2H₂O(l)');
      // The end-point step adds the titrant named in the calculation.
      expect(hcl.chemicalById(hcl.steps.last.requiredChemicalId).formula, hcl.calculation!.knownFormula);
      expect(oxalic.chemicalById(oxalic.steps.last.requiredChemicalId).formula, oxalic.calculation!.unknownFormula);
    });

    test('the formula also handles a 2 : 1 ratio with the known solution in the burette', () {
      // Na₂CO₃ + 2HCl: 20.0 mL of 0.1 M HCl neutralises 10.0 mL of 0.1 M Na₂CO₃.
      const calc = TitrationCalculation(
        knownFormula: 'HCl',
        knownMolarity: 0.1,
        knownCoefficient: 2,
        unknownFormula: 'Na₂CO₃',
        unknownVolumeMl: 10,
      );
      expect(calc.unknownMolarity(20.0), closeTo(0.1, 1e-12));
      expect(calc.working(20.0), 'c(Na₂CO₃) = 0.5 × 0.1 × 20.0 ÷ 10.0 = 0.100 M');
    });
  });

  group('Focus Mode tally of burette actions', () {
    test('only finished steps and wrong chemicals count; burette portions and a passed end point do not', () {
      final lab = LabController(_repo.byId('acid_base_titration'));
      final placement = _cbse.placementsOf('acid_base_titration').first;
      final focus = FocusController(
        path: PracticalPath(
          boardId: 'cbse',
          classLevel: 10,
          chapter: placement.location.chapter,
          topic: placement.location.topic,
          practical: lab.practical,
        ),
        duration: const Duration(minutes: 10),
      )..start();

      focus
        ..recordDrop(lab.attemptAdd(Chemicals.hcl)) // wrong: NaOH first
        ..recordDrop(lab.attemptAdd(Chemicals.naoh))
        ..recordDrop(lab.attemptAdd(Chemicals.phenolphthalein))
        ..recordDrop(lab.attemptAdd(Chemicals.hcl)); // fills the burette
      // 7.5 mL, then a whole 1.0 mL portion passes the 8.0 mL end point.
      for (final p in [...List.filled(7, 1.0), ...List.filled(5, 0.1), 1.0]) {
        focus.recordDrop(lab.attemptAdd(Chemicals.hcl, portionMl: p));
      }
      expect((lab.isSpoiled, lab.titrantMl), (true, 8.5));
      focus.recordDrop(lab.attemptAdd(Chemicals.hcl, portionMl: 0.1)); // refused until reset
      expect((focus.correctActions, focus.wrongActions), (2, 1));

      lab.reset();
      for (final c in [Chemicals.naoh, Chemicals.phenolphthalein, Chemicals.hcl]) {
        focus.recordDrop(lab.attemptAdd(c));
      }
      for (var i = 0; i < 8; i++) {
        focus.recordDrop(lab.attemptAdd(Chemicals.hcl, portionMl: 1.0));
      }
      expect(lab.isComplete, isTrue);
      expect((focus.correctActions, focus.wrongActions, focus.practicalsCompleted), (5, 1, 1));
      final session = focus.finish(FocusStatus.completed, stepsCompleted: 3, totalSteps: 3);
      expect(session.accuracy, closeTo(5 / 6, 1e-12));
      focus.dispose();
    });
  });

  group('chemical handling edge cases', () {
    test('dropping the titrant again while the burette is filled changes nothing', () {
      final lab = LabController(_repo.byId('acid_base_titration'))
        ..attemptAdd(Chemicals.naoh)
        ..attemptAdd(Chemicals.phenolphthalein);
      expect(lab.attemptAdd(Chemicals.hcl), isA<TitrantReady>());
      lab.attemptAdd(Chemicals.hcl, portionMl: 1.0);
      expect(lab.attemptAdd(Chemicals.hcl), isA<TitrantReady>());
      expect((lab.titrantMl, lab.stepIndex, lab.mistakes), (1.0, 2, 0));
    });

    test('a wrong chemical leaves the flask exactly as it was', () {
      final lab = LabController(_repo.byId('oxygen_preparation'))
        ..attemptAdd(Chemicals.mno2)
        ..attemptAdd(Chemicals.water);
      final before = (lab.stepIndex, lab.volumeMl, lab.beakerColor, lab.isBubbling, lab.lastObservation, lab.addedChemicals.length);
      expect(lab.attemptAdd(Chemicals.splint), isA<WrongDrop>());
      expect(lab.attemptAdd(Chemicals.hcl), isA<WrongDrop>());
      expect((lab.stepIndex, lab.volumeMl, lab.beakerColor, lab.isBubbling, lab.lastObservation, lab.addedChemicals.length), before);
      expect(lab.mistakes, 2);
    });

    test('a completed lab ignores further drops of any chemical', () {
      for (final p in _repo.all) {
        final lab = LabController(p);
        for (final step in p.steps) {
          final c = p.chemicalById(step.requiredChemicalId);
          if (step.titration case final t?) {
            lab.attemptAdd(c);
            // Whole 1.0 mL portions, then 0.1 mL ones, land exactly on the end point.
            for (var i = 0; i < t.endPointMl.floor(); i++) {
              lab.attemptAdd(c, portionMl: 1.0);
            }
            while (!lab.isComplete) {
              lab.attemptAdd(c, portionMl: 0.1);
            }
          } else {
            lab.attemptAdd(c);
          }
        }
        expect(lab.isComplete, isTrue, reason: p.id);
        final state = (lab.volumeMl, lab.beakerColor, lab.mistakes);
        for (final c in p.chemicals) {
          expect(lab.attemptAdd(c), isA<IgnoredDrop>(), reason: '${p.id}: ${c.id}');
        }
        expect((lab.volumeMl, lab.beakerColor, lab.mistakes), state, reason: p.id);
      }
    });
  });

  group('oxygen preparation in the real lab screen', () {
    testWidgets('drag and drop: wrong order, unsafe chemical, every step, completion, repeat', (tester) async {
      await launchApp(tester, saved: {AppState.classKey: 10});
      await _openLab(tester, 'Oxygen Gas Preparation');
      expect(find.text('STEP 1 OF 4'), findsOneWidget);

      // H₂O₂ belongs to a later step: warning names both chemicals, no step taken.
      await pour(tester, 'H₂O₂');
      expect(find.text('Smart Warning'), findsOneWidget);
      expect(find.textContaining('You were supposed to add Manganese Dioxide (MnO₂), but you added Hydrogen Peroxide (H₂O₂)'), findsOneWidget);
      expect(find.textContaining('is needed in a later step'), findsOneWidget);
      await _dismissWarning(tester);
      expect(find.text('STEP 1 OF 4'), findsOneWidget);

      // HCl is not used at all: the warning explains the chlorine hazard.
      await pour(tester, 'HCl');
      expect(find.textContaining('chlorine'), findsOneWidget);
      expect(find.textContaining('is needed in a later step'), findsNothing);
      await _dismissWarning(tester);
      expect(find.text('STEP 1 OF 4'), findsOneWidget);

      await pour(tester, 'MnO₂');
      expect(find.text('STEP 2 OF 4'), findsOneWidget);
      await pour(tester, 'H₂O');
      expect(find.text('STEP 3 OF 4'), findsOneWidget);
      expect(find.text('O₂ ↑'), findsNothing);
      await pour(tester, 'H₂O₂');
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('STEP 4 OF 4'), findsOneWidget);
      expect(find.text('O₂ ↑'), findsOneWidget);
      expect(find.text('Brisk effervescence: a colourless gas is given off.'), findsOneWidget);

      await pour(tester, 'Glowing Splinter');
      await tester.pump(const Duration(milliseconds: 1500));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Practical Complete!'), findsOneWidget);
      expect(find.textContaining('2H₂O₂ → 2H₂O + O₂'), findsOneWidget);
      expect(find.textContaining('2 mistakes'), findsWidgets);

      // Repeat clears the bench.
      await tester.tap(find.text('Repeat'));
      await pumpRoute(tester);
      expect(find.text('STEP 1 OF 4'), findsOneWidget);
      expect(find.text('O₂ ↑'), findsNothing);
    });
  });

  group('saved lab visit', () {
    testWidgets('a passed end point is not saved as a wrong action', (tester) async {
      final prefs = await launchApp(tester, saved: {AppState.classKey: 10});
      await _openLab(tester, 'Acid-Base Titration');
      await pour(tester, 'H₂O₂'); // a real mistake: not part of the titration
      await _dismissWarning(tester);
      for (final label in ['NaOH', 'Phenolphthalein', 'HCl']) {
        await pour(tester, label);
      }
      // 7.5 mL, then a whole 1.0 mL portion passes the 8.0 mL end point.
      await runBurette(tester, '+ 1.0 mL', times: 7);
      await runBurette(tester, '+ 0.1 mL', times: 5);
      await runBurette(tester, '+ 1.0 mL');
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('End point passed'), findsOneWidget);
      await tester.tap(find.text('Reset experiment'));
      await pumpRoute(tester);

      await tester.binding.handlePopRoute();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      final saved = PracticalAttemptStore(prefs).all().single;
      expect((saved.correctActions, saved.wrongActions), (2, 1));
      expect((saved.bestSteps, saved.totalSteps, saved.completions), (2, 3, 0));
    });
  });
}
