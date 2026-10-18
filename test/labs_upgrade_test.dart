import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:virtual_chemistry_lab/content/content_catalog.dart';
import 'package:virtual_chemistry_lab/content/content_repository.dart';
import 'package:virtual_chemistry_lab/content/content_validator.dart';
import 'package:virtual_chemistry_lab/content/models/practical_coverage.dart';
import 'package:virtual_chemistry_lab/content/models/syllabus.dart';
import 'package:virtual_chemistry_lab/data/practical_attempt_store.dart';
import 'package:virtual_chemistry_lab/data/practicals_repository.dart';
import 'package:virtual_chemistry_lab/lab/lab_tutorial.dart';
import 'package:virtual_chemistry_lab/screens/lab_tutorial_screen.dart';
import 'package:virtual_chemistry_lab/screens/practical_status_screen.dart';
import 'package:virtual_chemistry_lab/screens/virtual_lab_screen.dart';
import 'package:virtual_chemistry_lab/state/lab_controller.dart';

import 'test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const repo = PracticalsRepository();

  List<DropResult> titrate(LabController lab, List<double> portions) {
    final titrant = lab.expectedChemical!;
    expect(lab.attemptAdd(titrant), isA<TitrantReady>());
    return [for (final p in portions) lab.attemptAdd(titrant, portionMl: p)];
  }

  group('new titration labs', () {
    test('HCl against sodium carbonate: Na₂CO₃, methyl orange, HCl to 10.0 mL; 1 : 2 ratio', () {
      final lab = LabController(repo.byId('hcl_sodium_carbonate_titration'));
      // Phenolphthalein is refused with its reason (it marks only the first, NaHCO₃ stage).
      final phph = lab.attemptAdd(Chemicals.phenolphthalein);
      expect(phph, isA<WrongDrop>());
      lab.attemptAdd(Chemicals.sodiumCarbonate);
      final wrong = lab.attemptAdd(Chemicals.phenolphthalein) as WrongDrop;
      expect(wrong.hint!.en, contains('Methyl orange'));
      expect(lab.attemptAdd(Chemicals.methylOrange), isA<CorrectDrop>());
      final results = titrate(lab, List.filled(10, 1.0));
      expect(results.take(9), everyElement(isA<TitrantAdded>()));
      expect(results.last, isA<PracticalCompleted>());
      expect(lab.titrantMl, 10.0);
      expect(lab.mistakes, 2);
      final calc = lab.practical.calculation!;
      expect(calc.unknownMolarity(10.0), closeTo(0.1, 1e-9));
      expect(calc.working(10.0), 'c(HCl) = 2 × 0.05 × 10.0 ÷ 10.0 = 0.100 M');
    });

    test('KMnO₄ against oxalic acid: acidify, warm, then KMnO₄ is its own indicator; 2 : 5 ratio', () {
      final lab = LabController(repo.byId('kmno4_oxalic_titration'));
      lab.attemptAdd(Chemicals.oxalicAcid);
      final hcl = lab.attemptAdd(Chemicals.hcl) as WrongDrop;
      expect(hcl.hint!.en, contains('chloride'), reason: 'HCl is refused: KMnO₄ would oxidise chloride');
      expect(lab.attemptAdd(Chemicals.dilSulphuricAcid), isA<CorrectDrop>());
      expect(lab.attemptAdd(Chemicals.phenolphthalein), isA<WrongDrop>(), reason: 'no indicator needed');
      expect(lab.attemptAdd(Chemicals.burner), isA<CorrectDrop>(), reason: 'warming step');
      final results = titrate(lab, [...List.filled(9, 1.0), ...List.filled(10, 0.1)]);
      expect(results.last, isA<PracticalCompleted>());
      expect(lab.titrantMl, 10.0);
      final calc = lab.practical.calculation!;
      expect(calc.unknownMolarity(10.0), closeTo(0.02, 1e-9));
      expect(calc.working(10.0), 'c(KMnO₄) = 0.4 × 0.05 × 10.0 ÷ 10.0 = 0.020 M');
    });

    test("KMnO₄ against Mohr's salt: no warming; 1 : 5 ratio; overshoot needs a reset", () {
      final lab = LabController(repo.byId('kmno4_mohr_salt_titration'))
        ..attemptAdd(Chemicals.mohrSalt)
        ..attemptAdd(Chemicals.dilSulphuricAcid);
      final burner = lab.attemptAdd(Chemicals.burner) as WrongDrop;
      expect(burner.hint, isNotNull, reason: 'warming would oxidise Fe²⁺ in air — explained');
      // 9.5 mL, then a 1.0 mL portion runs past the 10.0 mL end point.
      final results = titrate(lab, [...List.filled(9, 1.0), ...List.filled(5, 0.1), 1.0]);
      expect(results.last, isA<Overshot>());
      expect(lab.isSpoiled, isTrue);
      expect(lab.attemptAdd(Chemicals.kmno4, portionMl: 0.1), isA<NeedsReset>());
      lab.reset();
      expect((lab.stepIndex, lab.titrantMl, lab.isSpoiled, lab.mistakes), (0, 0.0, false, 0));

      lab
        ..attemptAdd(Chemicals.mohrSalt)
        ..attemptAdd(Chemicals.dilSulphuricAcid);
      expect(titrate(lab, List.filled(10, 1.0)).last, isA<PracticalCompleted>());
      final calc = lab.practical.calculation!;
      expect(calc.unknownMolarity(10.0), closeTo(0.02, 1e-9));
      expect(calc.working(10.0), 'c(KMnO₄) = 0.2 × 0.1 × 10.0 ÷ 10.0 = 0.020 M');
    });

    test('each new lab has a written guide (apparatus, steps, result, safety, limits) and is placed in the syllabus', () async {
      final cbse = (await ContentCatalog.load(ContentRepository())).curriculum('cbse')!;
      for (final id in ['hcl_sodium_carbonate_titration', 'kmno4_oxalic_titration', 'kmno4_mohr_salt_titration']) {
        final g = cbse.guideFor(id);
        expect(g, isNotNull, reason: id);
        expect(g!.apparatus, isNotEmpty, reason: id);
        expect(g.steps, isNotEmpty, reason: id);
        expect(g.result.en, isNotEmpty, reason: id);
        expect(g.safety, isNotEmpty, reason: id);
        expect(g.simulationLimits, isNotEmpty, reason: '$id says what is not simulated');
        expect(cbse.practicalsForLab(id), isNotEmpty, reason: '$id is linked to a listed practical');
      }
      expect({for (final p in cbse.practicalsForLab('hcl_sodium_carbonate_titration')) (p.classLevel, p.practical.number)}, {(11, 'E')});
      expect({for (final p in cbse.practicalsForLab('kmno4_mohr_salt_titration')) (p.classLevel, p.practical.number)}, {(12, 'J')});
    });
  });

  group('practical status', () {
    late LoadedCurriculum cbse;
    setUpAll(() async {
      cbse = (await ContentCatalog.load(ContentRepository())).curriculum('cbse')!;
    });

    Map<String, PracticalLevel> levels() => {
          for (final level in cbse.classLevels)
            for (final p in cbse.classes[level]!.practicals) p.id: cbse.practicalStatus(p).level,
        };

    test('only practicals backed by working labs are marked interactive; everything else says so', () {
      final l = levels();
      expect(l, hasLength(27));
      final full = [for (final e in l.entries) if (e.value == PracticalLevel.fullyInteractive) e.key];
      final partial = [for (final e in l.entries) if (e.value == PracticalLevel.partiallyInteractive) e.key];
      expect(full, hasLength(1));
      expect(partial, hasLength(7));
      expect(l.values.where((v) => v == PracticalLevel.notImplemented), hasLength(19));
      for (final level in cbse.classLevels) {
        for (final p in cbse.classes[level]!.practicals) {
          final s = cbse.practicalStatus(p);
          if (s.level != PracticalLevel.notImplemented) {
            expect(s.labIds, isNotEmpty, reason: p.id);
            for (final id in s.labIds) {
              final isBuilt = repo.all.any((x) => x.id == id) || cbse.reactions.containsKey(id);
              expect(isBuilt, isTrue, reason: '$id for ${p.id} must be a real lab');
            }
          }
          if (s.level == PracticalLevel.partiallyInteractive) expect(s.coverage!.notCovered, isNotNull, reason: p.id);
        }
      }
    });

    test('the validator refuses an unbacked claim', () {
      final raw = jsonDecode(File('assets/content/boards/cbse/2026-27/manifest.json').readAsStringSync()) as Map<String, Object?>;
      final coverage = [...(raw['practicalCoverage']! as List<Object?>)];
      coverage.add({
        'practicalId': cbse.classes[9]!.practicals.first.id,
        'level': 'fullyInteractive',
        'covered': {'en': 'Everything', 'hi': 'सब कुछ'},
      });
      coverage.add({
        'practicalId': cbse.classes[12]!.practicals.firstWhere((p) => p.number == 'J').id,
        'level': 'guideOnly',
        'covered': {'en': 'Guide', 'hi': 'मार्गदर्शिका'},
      });
      final manifest = CurriculumManifest.fromJson({...raw, 'practicalCoverage': coverage});
      final c = LoadedCurriculum(manifest, cbse.classes.values.toList(),
          concepts: cbse.concepts, chemicals: cbse.chemicals, reagents: cbse.reagents, reactions: cbse.reactions, guides: cbse.guides);
      final issues = ContentValidator.learningContent(c, notesForClasses: const {});
      expect(issues.any((i) => i.contains('fully interactive with no lab')), isTrue);
      expect(issues.any((i) => i.contains('only interactive practicals are declared')), isTrue);
    });

    testWidgets('Practical status screen lists every practical of the class with an honest label', (tester) async {
      await launchApp(tester, size: const Size(1080, 30000)); // every card built
      tester.state<NavigatorState>(find.byType(Navigator).first).push(MaterialPageRoute<void>(
        builder: (_) => const PracticalStatusScreen(classLevel: 12),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Partially interactive'), findsNWidgets(2));
      expect(find.text('Not in the app yet'), findsNWidgets(9));
      expect(find.text('Fully interactive'), findsNothing);
    });
  });

  group('first-time lab tutorial', () {
    testWidgets('shown once before the first lab; Skip goes on to the real lab and it is not shown again', (tester) async {
      final prefs = await launchApp(tester, tutorialSeen: false);
      await openTitrationSetup(tester);
      await tester.tap(find.text('Start without Focus Mode'));
      await pumpRoute(tester);
      expect(find.byType(LabTutorialScreen), findsOneWidget);
      expect(find.text('Welcome to the virtual lab!'), findsOneWidget);
      expect(LabTutorial.isSeen(prefs), isTrue, reason: 'marked as seen when shown');
      await tester.tap(find.text('Skip'));
      await pumpRoute(tester);
      expect(find.byType(VirtualLabScreen), findsOneWidget);
      expect(find.text('Acid-Base Titration'), findsWidgets);

      // Second time: straight to the lab.
      await tester.binding.handlePopRoute();
      await pumpRoute(tester);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start virtual lab'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start without Focus Mode'));
      await pumpRoute(tester);
      expect(find.byType(LabTutorialScreen), findsNothing);
      expect(find.byType(VirtualLabScreen), findsOneWidget);
    });

    testWidgets('walk-through: steps in order, a wrong bottle is explained, the right one completes; nothing is saved', (tester) async {
      final prefs = await launchApp(tester, size: const Size(1080, 2340));
      tester.state<NavigatorState>(find.byType(Navigator).first).push(MaterialPageRoute<void>(builder: (_) => const LabTutorialScreen()));
      await pumpRoute(tester);
      for (final title in ['The chemical shelf', 'The workstation', 'Your goal and progress', 'Watch: drag a bottle', 'Right and wrong chemicals', 'Reset', 'Finishing', 'Your turn']) {
        await tester.tap(find.text(tester.any(find.text('Continue')) ? 'Continue' : 'Next'));
        await pumpRoute(tester);
        expect(find.text(title), findsOneWidget, reason: title);
      }
      // Wrong bottle first: refused with the reason.
      await pour(tester, 'HCl');
      await pumpRoute(tester);
      expect(find.textContaining('only need distilled water'), findsWidgets);
      await tester.tap(find.text('Try Again'));
      await pumpRoute(tester);
      expect(find.text('Not that one'), findsOneWidget);

      await pour(tester, 'H₂O');
      await tester.pump(const Duration(seconds: 1));
      await pumpRoute(tester);
      expect(find.text('Well done!'), findsOneWidget);
      expect(find.text('Replay'), findsOneWidget);

      // Replay starts again from the beginning.
      await tester.tap(find.text('Replay'));
      await pumpRoute(tester);
      expect(find.text('Welcome to the virtual lab!'), findsOneWidget);

      // The practice run is never stored as a practical attempt.
      expect(PracticalAttemptStore(prefs).all(), isEmpty);
    });

    testWidgets('Help in a real lab replays the tutorial and returns to the same lab untouched', (tester) async {
      final prefs = await launchApp(tester);
      await openTitrationSetup(tester);
      await tester.tap(find.text('Start without Focus Mode'));
      await pumpRoute(tester);
      await pour(tester, 'NaOH');
      await pumpRoute(tester);
      expect(find.text('STEP 2 OF 3'), findsOneWidget);
      await tester.tap(find.byTooltip('How to use the lab'));
      await pumpRoute(tester);
      expect(find.byType(LabTutorialScreen), findsOneWidget);
      await tester.tap(find.text('Skip'));
      await pumpRoute(tester);
      expect(find.byType(VirtualLabScreen), findsOneWidget);
      expect(find.text('STEP 2 OF 3'), findsOneWidget, reason: 'the real lab kept its step');
      expect(PracticalAttemptStore(prefs).all().where((a) => a.practicalId == 'lab_tutorial'), isEmpty);
    });
  });
}
