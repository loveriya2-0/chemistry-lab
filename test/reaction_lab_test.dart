import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:virtual_chemistry_lab/content/content_catalog.dart';
import 'package:virtual_chemistry_lab/content/content_repository.dart';
import 'package:virtual_chemistry_lab/lab/reaction_labs.dart';
import 'package:virtual_chemistry_lab/models/practical.dart';
import 'package:virtual_chemistry_lab/screens/practical_dashboard_screen.dart';
import 'package:virtual_chemistry_lab/screens/practical_guide_screen.dart';
import 'package:virtual_chemistry_lab/screens/virtual_lab_screen.dart';
import 'package:virtual_chemistry_lab/state/lab_controller.dart';
import 'package:virtual_chemistry_lab/widgets/language_toggle.dart';
import 'package:virtual_chemistry_lab/widgets/reaction_summary.dart';

import 'test_helpers.dart';

late LoadedCurriculum _cbse;
late Map<String, Practical> _labs;

Practical _lab(String id) => _labs[id]!;

/// Runs every step of [p] with the right chemicals.
LabController _runAll(Practical p) {
  final lab = LabController(p);
  for (final step in p.steps) {
    lab.attemptAdd(p.chemicalById(step.requiredChemicalId));
  }
  return lab;
}

/// Class 10 → Chemical Reactions and Equations → "Open lab" on [topic] →
/// the lab titled [title] → plain lab (no Focus Mode).
Future<void> _openReactionLab(
  WidgetTester tester,
  String topic,
  String title, {
  String classTile = 'Class 10',
  String chapter = 'Chemical Reactions and Equations',
  String openLab = 'Open lab',
  String startLab = 'Start virtual lab',
  String withoutFocus = 'Start without Focus Mode',
}) async {
  await tester.tap(find.text(classTile));
  await tester.pumpAndSettle();
  await scrollAndTap(tester, find.text(chapter));
  await scrollAndTap(tester, openLabOn(topic, openLab: openLab));
  expect(find.byType(PracticalDashboardScreen), findsOneWidget);
  await scrollAndTap(tester, find.text(title));
  // Every lab opens its guide first; the guide starts the lab.
  expect(find.byType(PracticalGuideScreen), findsOneWidget);
  await tester.tap(find.text(startLab));
  await tester.pumpAndSettle();
  await tester.tap(find.text(withoutFocus));
  await pumpRoute(tester);
  expect(find.byType(VirtualLabScreen), findsOneWidget);
}

Future<void> _dismissWarning(WidgetTester tester, {String tryAgain = 'Try Again'}) async {
  // Let the dialog's entry animation finish first.
  await tester.pump(const Duration(milliseconds: 400));
  await tester.tap(find.text(tryAgain));
  await tester.pump(const Duration(milliseconds: 400));
}

/// Waits for the completion dialog (shown after the pour animation).
Future<void> _waitForCompletion(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 1500));
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final catalog = await ContentCatalog.load(ContentRepository());
    _cbse = catalog.curriculum('cbse')!;
    _labs = {for (final p in ReactionLabs.fromCatalog(catalog)) p.id: p};
  });

  group('verified reactions only', () {
    test('all 18 NCERT reaction labs (13 Class 10 + 5 from the practicals expansion) are loaded and published', () {
      expect(_cbse.reactions, hasLength(18));
      expect(_labs.keys, unorderedEquals(_cbse.reactions.keys));
      for (final r in _cbse.reactions.values) {
        expect(r.review.isPublishable, isTrue, reason: r.id);
        expect(r.sources, isNotEmpty, reason: r.id);
        expect(r.sources.every((s) => s.sourceId.startsWith('ncert-')), isTrue, reason: r.id);
      }
    });

    test('every equation is already in a source-checked note or chemical card', () {
      final checked = {
        for (final n in _cbse.notes)
          if (n.review.isPublishable) ...n.formulas,
        for (final x in _cbse.chemicals.values)
          if (x.review.isPublishable) ...x.equations,
      };
      for (final r in _cbse.reactions.values) {
        expect(checked, contains(r.equation), reason: r.id);
      }
    });

    test('each lab is placed on the NCERT topic its source cites', () {
      const expected = {
        'rx-quicklime-water': (10, '1.2.1'),
        'rx-ferrous-sulphate-heat': (10, '1.2.2'),
        'rx-silver-chloride-sunlight': (10, '1.2.2'),
        'rx-iron-copper-sulphate': (10, '1.2.3'),
        'rx-barium-sulphate': (10, '1.2.4'),
        'rx-lead-iodide': (10, '1.2.4'),
        'rx-zinc-sulphuric-acid': (10, '2.1.2'),
        'rx-zinc-sodium-hydroxide': (10, '2.1.2'),
        'rx-zinc-hydrochloric-acid': (10, '2.1.2'),
        'rx-sodium-carbonate-acid': (10, '2.1.3'),
        'rx-baking-soda-acid': (10, '2.1.3'),
        'rx-magnesium-acid': (10, '3.2.3'),
        'rx-zinc-copper-sulphate': (10, '3.2.4'),
        'rx-ethanoic-acid-baking-soda': (10, '4.4.2'),
        'rx-ferric-thiocyanate': (11, '6.8'),
        'rx-phenol-bromine-water': (12, '7.4'),
        'rx-tollens-test': (12, '8.4'),
        'rx-fehling-test': (12, '8.4'),
      };
      expect(_cbse.manifest.reactionPlacements.keys, unorderedEquals(expected.keys));
      for (final MapEntry(key: id, value: (level, number)) in expected.entries) {
        final loc = _cbse.reactionLocation(id)!;
        expect(loc.topic.number, number, reason: id);
        expect(loc.syllabus.classLevel, level, reason: id);
        expect(_cbse.labsForTopic(loc.topic.id), contains(id));
        expect(_cbse.reactions[id]!.sources.first.section, startsWith(number), reason: id);
      }
      // Hand-built labs keep their places.
      expect(_cbse.labsForTopic('cbse-10-ch02-t2.1.4'), ['acid_base_titration']);
      expect(_cbse.labsForTopic('cbse-10-ch01-t1.2.2'), ['oxygen_preparation', 'rx-ferrous-sulphate-heat', 'rx-silver-chloride-sunlight']);
    });

    test('the lab list is in syllabus order', () {
      final numbers = [for (final p in _cbse.labsForClass(10)) p.location.topic.number];
      expect(numbers, ['1.2.1', '1.2.2', '1.2.2', '1.2.2', '1.2.3', '1.2.4', '1.2.4', '2.1.2', '2.1.2', '2.1.2', '2.1.3', '2.1.3', '2.1.4', '3.2.3', '3.2.4', '4.4.2']);
      expect(_cbse.labsForClass(9), isEmpty);
      expect([for (final p in _cbse.labsForClass(11)) p.location.topic.number], ['6.8']);
      expect([for (final p in _cbse.labsForClass(12)) p.location.topic.number], ['4.4', '7.4', '8.4', '8.4']);
    });

    test('every text has English and Hindi, and the completion card has every part', () {
      for (final r in _cbse.reactions.values) {
        for (final t in r.texts) {
          expect(t.en.trim(), isNotEmpty, reason: r.id);
          expect(t.hi?.trim(), isNotEmpty, reason: '${r.id}: ${t.en}');
        }
        final info = _lab(r.id).reaction!;
        expect(info.equation, r.equation);
        expect(info.reactants, isNotEmpty);
        expect(info.products, isNotEmpty);
        for (final t in [info.kind, info.whatHappened, info.why, info.realLife, info.examPoint]) {
          expect(t.en, isNotEmpty, reason: r.id);
          expect(t.hi, isNotEmpty, reason: r.id);
        }
      }
    });
  });

  group('reaction engine', () {
    test('the right chemicals in the right order complete every lab with no mistakes', () {
      for (final p in _labs.values) {
        final lab = LabController(p);
        for (final (i, step) in p.steps.indexed) {
          final result = lab.attemptAdd(p.chemicalById(step.requiredChemicalId));
          expect(result, i == p.steps.length - 1 ? isA<PracticalCompleted>() : isA<CorrectDrop>(), reason: '${p.id} step ${i + 1}');
        }
        expect(lab.isComplete, isTrue, reason: p.id);
        expect((lab.mistakes, lab.stars), (0, 3), reason: p.id);
        expect(lab.beakerColor, p.steps.last.resultColor, reason: p.id);
        expect(lab.attemptAdd(p.chemicals.first), isA<IgnoredDrop>());
      }
    });

    test('a wrong chemical is refused: warning, mistake counted, beaker unchanged', () {
      for (final p in _labs.values) {
        final used = {for (final s in p.steps) s.requiredChemicalId};
        final wrong = p.chemicals.firstWhere((c) => !used.contains(c.id));
        final lab = LabController(p);
        final result = lab.attemptAdd(wrong);
        expect(result, isA<WrongDrop>(), reason: p.id);
        result as WrongDrop;
        expect(result.expected.id, p.steps.first.requiredChemicalId);
        expect(result.outOfOrder, isFalse);
        expect(result.hint, p.hints[wrong.id]);
        expect((lab.stepIndex, lab.mistakes, lab.volumeMl), (0, 1, 0));
        expect(lab.beakerColor, LabController.emptyColor);
        expect(lab.addedChemicals, isEmpty);
      }
    });

    test('distractors explain why they do not react (reactivity series, conditions)', () {
      final iron = _lab('rx-iron-copper-sulphate');
      final lab = LabController(iron)..attemptAdd(iron.chemicalById('copper-sulphate'));
      final silver = lab.attemptAdd(iron.chemicalById('silver')) as WrongDrop;
      expect(silver.hint!.en, contains('less reactive than copper'));
      expect(silver.hint!.hi, isNotEmpty);

      final agcl = _lab('rx-silver-chloride-sunlight');
      final lab2 = LabController(agcl)..attemptAdd(agcl.chemicalById('silver-chloride'));
      final burner = lab2.attemptAdd(agcl.chemicalById('burner')) as WrongDrop;
      expect(burner.hint, isNotNull);
      expect(burner.expected.id, 'sunlight');
    });

    test('a chemical from a later step is flagged as the wrong order', () {
      final p = _lab('rx-lead-iodide');
      final result = LabController(p).attemptAdd(p.chemicalById('potassium-iodide')) as WrongDrop;
      expect(result.outOfOrder, isTrue);
      expect(result.expected.id, 'lead-nitrate');
    });

    test('precipitation: yellow lead iodide, white barium sulphate', () {
      final pbi2 = _runAll(_lab('rx-lead-iodide'));
      expect(pbi2.precipitateColor, const Color(0xFFF2D21B));
      expect(pbi2.isBubbling, isFalse);
      final baso4 = _runAll(_lab('rx-barium-sulphate'));
      expect(baso4.precipitateColor, const Color(0xFFFFFFFF));
    });

    test('gas evolution: H₂ from metals and acids, CO₂ from carbonates', () {
      for (final (id, gas) in [
        ('rx-zinc-sulphuric-acid', 'H₂ ↑'),
        ('rx-magnesium-acid', 'H₂ ↑'),
        ('rx-zinc-sodium-hydroxide', 'H₂ ↑'),
        ('rx-sodium-carbonate-acid', 'CO₂ ↑'),
        ('rx-baking-soda-acid', 'CO₂ ↑'),
        ('rx-ethanoic-acid-baking-soda', 'CO₂ ↑'),
      ]) {
        final lab = _runAll(_lab(id));
        expect((lab.isBubbling, lab.gasLabel), (true, gas), reason: id);
      }
      // Zinc in NaOH only reacts once it is warmed.
      final p = _lab('rx-zinc-sodium-hydroxide');
      final lab = LabController(p)
        ..attemptAdd(p.chemicalById('sodium-hydroxide'))
        ..attemptAdd(p.chemicalById('zinc'));
      expect((lab.isBubbling, lab.isHeating), (false, false));
    });

    test('colour change and metal coating in displacement', () {
      for (final id in ['rx-iron-copper-sulphate', 'rx-zinc-copper-sulphate']) {
        final p = _lab(id);
        final lab = LabController(p)..attemptAdd(p.chemicalById('copper-sulphate'));
        expect(lab.beakerColor, const Color(0xFF3D8BD9), reason: '$id: blue CuSO₄');
        lab.attemptAdd(p.chemicals.firstWhere((c) => c.id == p.steps.last.requiredChemicalId));
        expect(lab.beakerColor, isNot(const Color(0xFF3D8BD9)), reason: '$id: blue fades');
        expect(lab.solidColor, const Color(0xFFA0522D), reason: '$id: brown copper coat');
      }
    });

    test('heat, sunlight and exothermic warmth', () {
      final feso4 = _runAll(_lab('rx-ferrous-sulphate-heat'));
      expect(feso4.isHeating, isTrue);
      expect(feso4.fumesColor, isNotNull);
      expect(feso4.gasLabel, 'SO₂ + SO₃ ↑');
      expect(feso4.solidColor, const Color(0xFF8B2E16)); // reddish-brown Fe₂O₃

      final agcl = _runAll(_lab('rx-silver-chloride-sunlight'));
      expect(agcl.inSunlight, isTrue);
      expect(agcl.solidColor, const Color(0xFF7D7D7D)); // grey silver

      final lime = _runAll(_lab('rx-quicklime-water'));
      expect(lime.isWarm, isTrue);
    });

    test('Reset Experiment clears every effect and the step count', () {
      final lab = _runAll(_lab('rx-ferrous-sulphate-heat'));
      lab.reset();
      expect((lab.stepIndex, lab.mistakes, lab.volumeMl, lab.isComplete), (0, 0, 0, false));
      expect(lab.beakerColor, LabController.emptyColor);
      expect([lab.solidColor, lab.precipitateColor, lab.fumesColor, lab.gasLabel, lab.lastObservation], everyElement(isNull));
      expect([lab.isBubbling, lab.isHeating, lab.inSunlight, lab.isWarm], everyElement(isFalse));
      expect(lab.addedChemicals, isEmpty);
    });
  });

  group('reaction lab screens', () {
    testWidgets('precipitation lab: warnings, yellow precipitate, full reaction card, reset', (tester) async {
      await launchApp(tester);
      await _openReactionLab(tester, '1.2.4', 'Lead nitrate and potassium iodide');
      expect(find.text('STEP 1 OF 2'), findsOneWidget);

      // Wrong chemical.
      await pour(tester, 'BaCl₂');
      expect(find.text('Smart Warning'), findsOneWidget);
      expect(find.textContaining('You were supposed to add Lead nitrate solution (Pb(NO₃)₂)'), findsOneWidget);
      await _dismissWarning(tester);

      // Right chemical, wrong time.
      await pour(tester, 'KI');
      expect(find.textContaining('is needed in a later step'), findsOneWidget);
      await _dismissWarning(tester);
      expect(find.textContaining('2 mistakes'), findsOneWidget);

      await pour(tester, 'Pb(NO₃)₂');
      expect(find.text('STEP 2 OF 2'), findsOneWidget);
      await pour(tester, 'KI');
      expect(find.text('Precipitate'), findsOneWidget);
      await _waitForCompletion(tester);

      expect(find.text('Practical Complete!'), findsOneWidget);
      expect(find.byType(ReactionSummary), findsOneWidget);
      expect(find.text('Double displacement (precipitation) reaction'), findsOneWidget);
      expect(find.text('Balanced equation'), findsOneWidget);
      expect(find.text('Pb(NO₃)₂(aq) + 2KI(aq) → PbI₂(s) + 2KNO₃(aq)'), findsOneWidget);
      expect(find.text('Reactants'), findsOneWidget);
      expect(find.text('Products'), findsOneWidget);
      expect(find.text('What happened'), findsOneWidget);
      expect(find.text('Why it happens'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('🎯 Exam importance'), 200, scrollable: find.byType(Scrollable).last);
      expect(find.text('🌍 Real-life use'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Source-checked'), 200, scrollable: find.byType(Scrollable).last);

      // Repeat resets the bench.
      await tester.tap(find.text('Repeat'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('STEP 1 OF 2'), findsOneWidget);
      expect(find.text('Precipitate'), findsNothing);
      expect(find.textContaining('0 mistakes'), findsOneWidget);
    });

    testWidgets('heating lab: burner effects and gas, Reset Experiment mid-way', (tester) async {
      await launchApp(tester);
      await _openReactionLab(tester, '1.2.2', 'Heating ferrous sulphate crystals');

      // Water is on the shelf, but the crystals are heated dry.
      await pour(tester, 'FeSO₄·7H₂O');
      await pour(tester, 'H₂O');
      expect(find.textContaining('heated dry'), findsOneWidget);
      await _dismissWarning(tester);

      await tester.tap(find.byTooltip('Reset experiment'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('STEP 1 OF 2'), findsOneWidget);
      expect(find.textContaining('0 mistakes'), findsOneWidget);

      await pour(tester, 'FeSO₄·7H₂O');
      await pour(tester, 'Heat (burner)');
      expect(find.text('Heating'), findsOneWidget);
      expect(find.text('Fumes'), findsOneWidget);
      expect(find.text('SO₂ + SO₃ ↑'), findsOneWidget);
      await _waitForCompletion(tester);
      expect(find.text('2FeSO₄(s) →(heat) Fe₂O₃(s) + SO₂(g) + SO₃(g)'), findsOneWidget);
      expect(find.text('Thermal decomposition reaction'), findsOneWidget);
    });

    testWidgets('Hindi on a small phone (320×568): lab, warning and reaction card', (tester) async {
      await launchApp(tester, size: const Size(640, 1136), pixelRatio: 2);
      await tester.tap(find.byType(LanguageToggle));
      await tester.pumpAndSettle();
      final r = _cbse.reactions['rx-zinc-sulphuric-acid']!;

      await _openReactionLab(
        tester,
        '2.1.2',
        r.title.hi!,
        classTile: 'कक्षा 10',
        chapter: 'अम्ल, क्षारक एवं लवण',
        openLab: 'लैब खोलें',
        startLab: 'वर्चुअल लैब शुरू करें',
        withoutFocus: 'फ़ोकस मोड के बिना प्रारंभ करें',
      );
      expect(find.text('चरण 1 / 2'), findsOneWidget);
      expect(find.text(r.steps.first.instruction.hi!), findsOneWidget);

      // Copper is below hydrogen in the reactivity series.
      await pour(tester, 'Cu');
      expect(find.text('स्मार्ट चेतावनी'), findsOneWidget);
      expect(find.text('यह क्यों काम नहीं करेगा'), findsOneWidget);
      expect(find.text(r.hints['copper']!.hi!), findsOneWidget);
      await _dismissWarning(tester, tryAgain: 'पुनः प्रयास करें');

      await pour(tester, 'Zn');
      await pour(tester, 'H₂SO₄');
      expect(find.text('H₂ ↑'), findsOneWidget);
      await _waitForCompletion(tester);
      expect(find.text('प्रयोग पूर्ण हुआ!'), findsOneWidget);
      expect(find.text('संतुलित समीकरण'), findsOneWidget);
      expect(find.text(r.equation), findsOneWidget);
      expect(find.text('अभिकारक'), findsOneWidget);
      expect(find.text('उत्पाद'), findsOneWidget);
      expect(find.text(r.whatHappened.hi!), findsOneWidget);
      await tester.scrollUntilVisible(find.text(r.examPoint.hi!), 200, scrollable: find.byType(Scrollable).last);
      expect(find.text('🎯 परीक्षा में महत्व'), findsOneWidget);
    });

    testWidgets('every reaction lab opens from the Lab tab list', (tester) async {
      await launchApp(tester);
      await tester.tap(find.text('Lab'));
      await tester.pumpAndSettle();
      for (final title in ['Quicklime and water', 'Iron nails in copper sulphate solution', 'Ethanoic acid and baking soda']) {
        await tester.scrollUntilVisible(find.text(title), 300, scrollable: find.byType(Scrollable).first);
        expect(find.text(title), findsOneWidget);
      }
      await scrollAndTap(tester, find.text('Ethanoic acid and baking soda'));
      expect(find.byType(PracticalGuideScreen), findsOneWidget);
      expect(find.text('Ethanoic acid and baking soda'), findsOneWidget);
      await tester.scrollUntilVisible(find.textContaining('Activity 4.9'), 300, scrollable: find.byType(Scrollable).first);
      expect(find.textContaining('Activity 4.9'), findsOneWidget);
    });
  });
}
