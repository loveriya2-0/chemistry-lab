import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:virtual_chemistry_lab/content/content_catalog.dart';
import 'package:virtual_chemistry_lab/content/content_repository.dart';
import 'package:virtual_chemistry_lab/content/content_text.dart';
import 'package:virtual_chemistry_lab/content/content_validator.dart';
import 'package:virtual_chemistry_lab/content/models/practical_guide.dart';
import 'package:virtual_chemistry_lab/content/models/review.dart';
import 'package:virtual_chemistry_lab/content/models/syllabus.dart';
import 'package:virtual_chemistry_lab/analytics/progress_report.dart';
import 'package:virtual_chemistry_lab/data/focus_session_store.dart';
import 'package:virtual_chemistry_lab/data/practical_attempt_store.dart';
import 'package:virtual_chemistry_lab/data/practicals_repository.dart';
import 'package:virtual_chemistry_lab/lab/reaction_labs.dart';
import 'package:virtual_chemistry_lab/models/practical_attempt.dart';
import 'package:virtual_chemistry_lab/models/practical_path.dart';
import 'package:virtual_chemistry_lab/screens/focus_setup_screen.dart';
import 'package:virtual_chemistry_lab/screens/practical_guide_screen.dart';
import 'package:virtual_chemistry_lab/screens/virtual_lab_screen.dart';
import 'package:virtual_chemistry_lab/state/app_state.dart';
import 'package:virtual_chemistry_lab/widgets/focus_bar.dart';
import 'package:virtual_chemistry_lab/widgets/workstation_beaker.dart';
import 'package:virtual_chemistry_lab/widgets/language_toggle.dart';

import 'test_helpers.dart';

late ContentCatalog _catalog;
late LoadedCurriculum _cbse;

Json _text(String en, String hi) => {'en': en, 'hi': hi, 'hiSrc': 'translated'};

Future<void> _openLabTab(WidgetTester tester, int classLevel) async {
  await launchApp(tester, saved: {AppState.classKey: classLevel});
  await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('Lab')));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    _catalog = await ContentCatalog.load(ContentRepository());
    _cbse = _catalog.curriculum('cbse')!;
  });

  group('practical guide models', () {
    test('a guide parses every section; optional fields may be left out', () {
      final g = PracticalGuide.fromJson({
        'id': 'lab-x',
        'aim': _text('Aim text', 'उद्देश्य'),
        'apparatus': [
          {'name': _text('Beaker', 'बीकर')},
        ],
        'chemicals': [
          {
            'name': _text('Water', 'जल'),
            'formula': 'H₂O',
            'quantity': _text('About 10 mL', 'लगभग 10 mL'),
          },
        ],
        'steps': [
          {'instruction': _text('Pour the water', 'जल डालें')},
          {
            'instruction': _text('Watch', 'देखें'),
            'observation': _text('Nothing happens', 'कुछ नहीं होता'),
            'explanation': _text('Water alone does not react', 'केवल जल अभिक्रिया नहीं करता'),
          },
        ],
        'result': _text('Result text', 'परिणाम'),
        'safety': [_text('Wear goggles', 'चश्मा पहनें')],
        'simulationLimits': [_text('Simplified', 'सरल किया गया')],
        'sources': [
          {'sourceId': 'ncert-10-en', 'section': '2.1'},
        ],
        'review': {'status': 'sourceChecked'},
      });
      expect(g.id, 'lab-x');
      expect(g.equation, isNull);
      expect(g.apparatus.single.formula, isNull);
      expect(g.apparatus.single.quantity, isNull);
      expect(g.chemicals.single.formula, 'H₂O');
      expect(g.chemicals.single.hazard, isNull);
      expect(g.steps.first.observation, isNull);
      expect(g.steps.last.explanation!.hi, 'केवल जल अभिक्रिया नहीं करता');
      expect(g.review, ReviewStatus.sourceChecked);
      expect(g.sources.single.section, '2.1');
      // aim, apparatus, chemical name + quantity, 1 + 3 step texts, result, safety, limit
      expect(g.texts, hasLength(11));
    });

    test('lab–practical links parse; an unknown relation is rejected', () {
      final l = LabPracticalLink.fromJson('lab-x', {
        'practicalId': 'cbse-11-pE',
        'relation': 'related',
        'note': _text('Same technique', 'वही तकनीक'),
      });
      expect(l.labId, 'lab-x');
      expect(l.relation, LabRelation.related);
      expect(l.note!.en, 'Same technique');
      expect(() => LabRelation.parse('similar'), throwsFormatException);
    });
  });

  group('practical guides in the CBSE content', () {
    test('every interactive lab has a complete, published guide', () {
      final labs = [for (final p in PracticalsRepository(reactionLabs: ReactionLabs.fromCatalog(_catalog)).all) p.id];
      expect(labs, hasLength(24));
      expect(_cbse.guides.keys, unorderedEquals(labs), reason: 'one guide per lab, and no guide without a lab');
      for (final id in labs) {
        final g = _cbse.guideFor(id)!;
        expect(g.apparatus, isNotEmpty, reason: id);
        expect(g.chemicals.every((c) => c.quantity != null), isTrue, reason: '$id: every chemical has a quantity');
        expect(g.steps.where((s) => s.observation != null), isNotEmpty, reason: id);
        expect(g.steps.where((s) => s.explanation != null), isNotEmpty, reason: id);
        expect(g.safety, isNotEmpty, reason: id);
        expect(g.simulationLimits, isNotEmpty, reason: '$id: must say how the virtual lab differs');
        expect(g.equation, isNotNull, reason: id);
        expect(g.sources, isNotEmpty, reason: id);
      }
    });

    test('each reaction lab guide cites the same NCERT activity as its lab', () {
      for (final r in _cbse.reactions.values) {
        final guide = _cbse.guideFor(r.id)!;
        final labCites = r.sources.first.section!;
        final guideCites = [for (final x in guide.sources) x.section ?? ''].join('; ');
        // Same NCERT activity when the lab names one, else the same section.
        final activity = RegExp(r'Activity \d+\.\d+').firstMatch(labCites)?.group(0);
        expect(guideCites, contains(activity ?? labCites.split(';').first.trim()), reason: r.id);
        expect(guide.equation, r.equation, reason: '${r.id}: the guide and the lab show the same equation');
      }
    });

    test('titration is a Class 10 concept lab related to Class 11 C and E and Class 12 C', () {
      expect([for (final p in _cbse.placementsOf('acid_base_titration')) p.location.topic.id], ['cbse-10-ch02-t2.1.4']);
      expect(
        [for (final l in _cbse.practicalsForLab('acid_base_titration')) '${l.classLevel}${l.practical.number}:${l.link.relation.name}'],
        ['11C:related', '11E:related', '12C:related'],
      );
      // Practical 1B (litmus, zinc, sodium carbonate) is not a titration: its
      // links are only the reaction labs for its parts.
      final p1b = _cbse.classes[10]!.practicals.firstWhere((p) => p.id == 'cbse-10-p1b');
      expect([for (final l in _cbse.labLinksForPractical(p1b)) l.labId],
          unorderedEquals(['rx-zinc-hydrochloric-acid', 'rx-zinc-sodium-hydroxide', 'rx-sodium-carbonate-acid']));
    });

    test('oxygen preparation is a concept lab only: in no CBSE practical list', () {
      expect([for (final p in _cbse.placementsOf('oxygen_preparation')) p.location.topic.id], ['cbse-10-ch01-t1.2.2']);
      expect(_cbse.practicalsForLab('oxygen_preparation'), isEmpty);
    });

    test('the validator accepts the shipped guides and links', () {
      final issues = ContentValidator.learningContent(_cbse, notesForClasses: const {});
      expect(issues.where((i) => i.startsWith('Practical guide') || i.startsWith('Lab ')), isEmpty);
    });

    test('the validator rejects incomplete guides and unexplained links', () {
      const t = ContentText(en: 'Text', hi: 'पाठ', hiSource: HindiSource.translated);
      const guide = PracticalGuide(
        id: 'no-such-lab',
        aim: t,
        apparatus: [],
        chemicals: [GuideMaterial(name: t)],
        steps: [GuideStep(instruction: t)],
        result: t,
        safety: [],
        simulationLimits: [],
        sources: [SourceRef(sourceId: 'ncert-10-en')],
        review: ReviewStatus.draft,
      );
      final manifest = CurriculumManifest(
        id: _cbse.manifest.id,
        boardId: _cbse.manifest.boardId,
        academicYear: _cbse.manifest.academicYear,
        status: _cbse.manifest.status,
        classes: _cbse.manifest.classes,
        sources: _cbse.manifest.sources,
        conceptFiles: const [],
        pyqFiles: const [],
        legacyIdMap: const {},
        labPlacements: _cbse.manifest.labPlacements,
        labLinks: const [
          LabPracticalLink(labId: 'acid_base_titration', practicalId: 'cbse-11-pE', relation: LabRelation.related),
          LabPracticalLink(labId: 'acid_base_titration', practicalId: 'cbse-10-p2', relation: LabRelation.official),
          LabPracticalLink(labId: 'acid_base_titration', practicalId: 'cbse-99-p1', relation: LabRelation.related, note: t),
        ],
      );
      final issues = ContentValidator.learningContent(
        LoadedCurriculum(manifest, _cbse.classes.values.toList(), guides: {guide.id: guide}),
        notesForClasses: const {},
      );
      expect(issues, containsAll([
        'Practical guide no-such-lab: review status draft is not publishable',
        'Practical guide no-such-lab: no interactive lab with this id',
        'Practical guide no-such-lab: no apparatus',
        'Practical guide no-such-lab: no safety notes',
        'Practical guide no-such-lab: does not say how the virtual lab differs from a real lab',
        'Lab acid_base_titration link to cbse-11-pE: a related lab must say how it differs from the practical',
        'Lab acid_base_titration link to cbse-10-p2: official link, but the practical names lab "null"',
        'Lab acid_base_titration link to cbse-99-p1: unknown practical',
      ]));
    });
  });

  group('practical dashboard navigation', () {
    testWidgets('Class 10: a lab card opens its guide, and the guide starts the lab', (tester) async {
      await _openLabTab(tester, 10);
      expect(find.text('View practical'), findsWidgets);
      await scrollAndTap(tester, find.text('Oxygen Gas Preparation'));
      expect(find.byType(PracticalGuideScreen), findsOneWidget);
      expect(find.textContaining('This is a virtual simulation'), findsOneWidget);
      for (final heading in ['🎯 Aim', '🔬 Apparatus', '⚗️ Chemicals and quantities', '📋 Steps in a real lab', '⚠️ Safety', '💻 Virtual lab vs real lab', '📚 Where it is in the syllabus']) {
        await tester.scrollUntilVisible(find.text(heading), 300, scrollable: find.byType(Scrollable).first);
        expect(find.text(heading), findsOneWidget, reason: heading);
      }
      expect(find.text("Not an experiment in the board's list of practicals."), findsOneWidget);
      expect(find.textContaining('Concept lab · Class 10 · 1.2.2'), findsOneWidget);

      await tester.tap(find.text('Start virtual lab'));
      await tester.pumpAndSettle();
      expect(find.byType(FocusSetupScreen), findsOneWidget);
    });

    testWidgets('Class 11: practical E links to the related titration guide', (tester) async {
      await _openLabTab(tester, 11);
      // More Class 11 labs now sit above the practical list; scroll down to it.
      await tester.scrollUntilVisible(find.textContaining('Quantitative estimation'), 300, scrollable: find.byType(Scrollable).first);
      expect(find.text('Related virtual lab: Acid-Base Titration'), findsNWidgets(2)); // practicals C and E
      final practicalE = find.ancestor(of: find.textContaining('Quantitative estimation'), matching: find.byType(ListTile));
      await tester.scrollUntilVisible(practicalE, 300, scrollable: find.byType(Scrollable).first);
      // Practical E links to both titration labs.
      expect(find.descendant(of: practicalE, matching: find.text('Related virtual lab: Titration: NaOH against Oxalic Acid')), findsOneWidget);
      await scrollAndTap(tester, find.descendant(of: practicalE, matching: find.text('Related virtual lab: Acid-Base Titration')));
      expect(find.byType(PracticalGuideScreen), findsOneWidget);
      await tester.scrollUntilVisible(find.textContaining('Class 11 · Practical E'), 300, scrollable: find.byType(Scrollable).first);
      expect(find.text('Class 11 · Practical E — related, not the same experiment'), findsOneWidget);
      // Opened from Class 11 practical E, the lab is saved under Class 11.
      await tester.tap(find.text('Start virtual lab'));
      await tester.pumpAndSettle();
      expect(find.text('CBSE · Class 11'), findsOneWidget);
      expect(find.textContaining('E. Quantitative estimation'), findsOneWidget);
    });

    testWidgets('Class 9 has no lab yet, and its practicals say so', (tester) async {
      await _openLabTab(tester, 9);
      expect(find.text('No interactive labs for Class 9 yet.'), findsOneWidget);
      expect(find.text('Related virtual lab: Acid-Base Titration'), findsNothing);
      expect(find.text('Guide coming soon'), findsNWidgets(3));
    });

    testWidgets('both guides fit a small phone (320×568) in Hindi', (tester) async {
      await launchApp(tester, size: const Size(640, 1136), pixelRatio: 2, saved: {'app_language': 'hi', AppState.classKey: 10});
      await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('लैब')));
      await tester.pumpAndSettle();
      for (final title in ['ऑक्सीजन गैस का निर्माण', 'अम्ल-क्षारक अनुमापन']) {
        await scrollAndTap(tester, find.text(title));
        expect(find.byType(PracticalGuideScreen), findsOneWidget);
        await tester.drag(find.byType(Scrollable).first, const Offset(0, -20000));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: title);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
      }
    });

    testWidgets('the guide is translated into Hindi', (tester) async {
      await _openLabTab(tester, 10);
      await scrollAndTap(tester, find.text('Acid-Base Titration'));
      await tester.tap(find.byType(LanguageToggle));
      await tester.pumpAndSettle();
      expect(find.text('🎯 उद्देश्य'), findsOneWidget);
      expect(find.textContaining('यह एक वर्चुअल सिमुलेशन है'), findsOneWidget);
      expect(find.text('वर्चुअल लैब शुरू करें'), findsOneWidget);
    });
  });

  group('class mapping', () {
    PracticalPath startPath(String labId, int classLevel, {String? topicId, String? listedPracticalId}) {
      final lab = PracticalsRepository(reactionLabs: ReactionLabs.fromCatalog(_catalog)).byId(labId);
      return PracticalGuideScreen(labId: labId, classLevel: classLevel, topicId: topicId, listedPracticalId: listedPracticalId)
          .startPath(_cbse, lab)!;
    }

    test('a lab starts in the class it was opened for', () {
      final c10 = startPath('acid_base_titration', 10);
      expect((c10.classLevel, c10.topic?.id, c10.listedPractical), (10, 'cbse-10-ch02-t2.1.4', null));

      // Class 11: the first listed practical it is linked to (C), with its chapter.
      final c11 = startPath('acid_base_titration', 11);
      expect((c11.classLevel, c11.topic, c11.listedPractical?.id, c11.chapter?.id), (11, null, 'cbse-11-pC', 'cbse-11-ch06'));
      final c11e = startPath('acid_base_titration', 11, listedPracticalId: 'cbse-11-pE');
      expect((c11e.listedPractical?.id, c11e.chapter?.id), ('cbse-11-pE', 'cbse-11-ch01'));

      // Class 12 practical C has no Class 12 chapter.
      final c12 = startPath('acid_base_titration', 12);
      expect((c12.classLevel, c12.listedPractical?.id, c12.chapter), (12, 'cbse-12-pC', null));

      // A class with neither falls back to the lab's own topic.
      expect(startPath('acid_base_titration', 9).classLevel, 10);
      // The oxalic acid lab belongs only to Class 11 practical E.
      final ox = startPath('oxalic_acid_titration', 10);
      expect((ox.classLevel, ox.listedPractical?.id, ox.topic), (11, 'cbse-11-pE', null));
      // An explicit topic wins.
      expect(startPath('rx-quicklime-water', 12, topicId: 'cbse-10-ch01-t1.2.1').topic?.id, 'cbse-10-ch01-t1.2.1');
    });

    test('attempts keep the listed practical; Classes 11–12 progress counts their linked labs', () {
      final now = DateTime.now();
      final attempt = PracticalAttempt(
        id: 'a',
        startedAt: now,
        endedAt: now,
        classLevel: 11,
        chapterId: 'cbse-11-ch01',
        listedPracticalId: 'cbse-11-pE',
        practicalId: 'oxalic_acid_titration',
        correctActions: 3,
        wrongActions: 0,
        completions: 1,
        bestSteps: 3,
        totalSteps: 3,
      );
      final loaded = PracticalAttempt.fromJson(attempt.toJson());
      expect((loaded.topicId, loaded.listedPracticalId, loaded.classLevel), (null, 'cbse-11-pE', 11));

      ProgressReport report(int c) => ProgressReport.build(curriculum: _cbse, attempts: [attempt], sessions: const [], classLevel: c, now: now);
      final r11 = report(11);
      expect(r11.practicalsTotal, 4, reason: 'titration (related to C and E), the oxalic acid and sodium carbonate titrations (E), and the Fe³⁺–SCN⁻ equilibrium lab (6.8, D)');
      expect(r11.practicalsDone, 1);
      expect(r11.recent.single.classLevel, 11);
      expect(r11.recent.single.topicId, isNull);
      expect(report(12).practicalsTotal, 7, reason: 'titration (C), two KMnO₄ titrations (J), and the Tollens, Fehling, phenol–bromine and ethanoic acid labs (H)');
      expect(report(9).practicalsTotal, 0);
      expect(report(10).practicalsTotal, 16, reason: 'Class 10 counts its 16 topic labs (15 before + zinc with HCl)');
    });

    testWidgets('Class 11 Lab tab: the oxalic acid lab is saved under Class 11, practical E', (tester) async {
      final prefs = await launchApp(tester, saved: {AppState.classKey: 11});
      await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('Lab')));
      await tester.pumpAndSettle();
      expect(find.text('Class 11 · Practical E'), findsOneWidget);
      await scrollAndTap(tester, find.text('Titration: NaOH against Oxalic Acid'));
      expect(find.byType(PracticalGuideScreen), findsOneWidget);
      await tester.tap(find.text('Start virtual lab'));
      await tester.pumpAndSettle();
      expect(find.text('CBSE · Class 11'), findsOneWidget);
      expect(find.text('Practical in the syllabus'), findsOneWidget);
      await tester.tap(find.text('Start without Focus Mode'));
      await pumpRoute(tester);
      expect(find.byType(VirtualLabScreen), findsOneWidget);
      await pour(tester, 'H₂C₂O₄');
      expect(find.text('STEP 2 OF 3'), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      final saved = PracticalAttemptStore(prefs).all().single;
      expect(saved.practicalId, 'oxalic_acid_titration');
      expect(saved.classLevel, 11);
      expect(saved.listedPracticalId, 'cbse-11-pE');
      expect(saved.chapterId, 'cbse-11-ch01');
      expect(saved.topicId, isNull);
    });

    testWidgets('Class 12 practical C: Focus Mode shows and saves Class 12', (tester) async {
      final prefs = await launchApp(tester, saved: {AppState.classKey: 12});
      await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('Lab')));
      await tester.pumpAndSettle();
      final practicalC = find.ancestor(of: find.textContaining('Thermochemistry'), matching: find.byType(ListTile));
      await scrollAndTap(tester, find.descendant(of: practicalC, matching: find.text('Related virtual lab: Acid-Base Titration')));
      await tester.tap(find.text('Start virtual lab'));
      await tester.pumpAndSettle();
      expect(find.text('CBSE · Class 12'), findsOneWidget);
      await tester.tap(find.text('Start Focus Session · 10 min'));
      await pumpRoute(tester);
      expect(find.byType(FocusBar), findsOneWidget);
      expect(find.text('Class 12 · Practical C'), findsOneWidget);
      await pour(tester, 'NaOH');

      await tester.tap(find.byTooltip('Exit Focus'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.text('Exit'));
      await tester.pumpAndSettle();
      final session = FocusSessionStore(prefs).all().single;
      expect((session.classLevel, session.listedPracticalId, session.topicId), (12, 'cbse-12-pC', null));
      final attempt = PracticalAttemptStore(prefs).all().single;
      expect((attempt.classLevel, attempt.listedPracticalId, attempt.focusSessionId), (12, 'cbse-12-pC', session.id));
    });
  });

  group('burette and quantities in the titration lab', () {
    Future<void> openTitrationLab(WidgetTester tester) async {
      await _openLabTab(tester, 10);
      await scrollAndTap(tester, find.text('Acid-Base Titration'));
      await tester.tap(find.text('Start virtual lab'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start without Focus Mode'));
      await pumpRoute(tester);
    }

    testWidgets('amounts are labelled honestly; the burette replaces the shelf', (tester) async {
      await openTitrationLab(tester);
      expect(find.text('Measured with a pipette: exactly 10.0 mL.'), findsOneWidget);
      await pour(tester, 'NaOH');
      expect(find.text('Approximate amount — nothing is measured in this step.'), findsOneWidget);
      await pour(tester, 'Phenolphthalein');
      expect(find.textContaining('Burette: run in 1.0 mL portions'), findsOneWidget);
      expect(find.text('Burette'), findsNothing, reason: 'the burette appears once HCl is chosen');

      await pour(tester, 'HCl');
      expect(find.text('Burette'), findsOneWidget);
      expect(find.text('Reading: 0.0 mL'), findsOneWidget);
      expect(find.text('NaOH'), findsNothing, reason: 'the shelf is put away during the titration');
      await runBurette(tester, '+ 1.0 mL', times: 3);
      expect(find.text('Reading: 3.0 mL'), findsOneWidget);
      expect(find.text('STEP 3 OF 3'), findsOneWidget);
    });

    testWidgets('passing the end point asks for a repeat; reset clears the burette', (tester) async {
      await openTitrationLab(tester);
      for (final label in ['NaOH', 'Phenolphthalein', 'HCl']) {
        await pour(tester, label);
      }
      await runBurette(tester, '+ 1.0 mL', times: 7);
      await runBurette(tester, '+ 0.1 mL', times: 5);
      expect(find.text('Reading: 7.5 mL'), findsOneWidget);
      expect(find.textContaining('takes longer to come back'), findsOneWidget, reason: 'the near-end-point cue');
      await runBurette(tester, '+ 1.0 mL');
      await tester.pump(const Duration(milliseconds: 400)); // dialog entry
      expect(find.text('End point passed'), findsOneWidget);
      expect(find.textContaining('between 7.5 and 8.5 mL'), findsOneWidget);
      expect(find.textContaining('0 mistakes'), findsOneWidget, reason: 'a rough titration is not a mistake');

      await tester.tap(find.text('Reset experiment'));
      await pumpRoute(tester);
      expect(find.text('STEP 1 OF 3'), findsOneWidget);
      expect(find.text('Burette'), findsNothing);
      expect(find.text('NaOH'), findsOneWidget, reason: 'the shelf is back');
    });

    testWidgets('the burette fits a small phone (320×568) in Hindi', (tester) async {
      await launchApp(tester, size: const Size(640, 1136), pixelRatio: 2, saved: {'app_language': 'hi', AppState.classKey: 10});
      await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('लैब')));
      await tester.pumpAndSettle();
      await scrollAndTap(tester, find.text('अम्ल-क्षारक अनुमापन'));
      await tester.tap(find.text('वर्चुअल लैब शुरू करें'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('फ़ोकस सत्र प्रारंभ करें · 10 मिनट'));
      await pumpRoute(tester);
      // The compact status bar leaves room on the bench to drop onto.
      expect(tester.getSize(find.byType(WorkstationBeaker)).height, greaterThan(50));
      for (final (i, label) in ['NaOH', 'फ़ीनॉल्फ़्थेलिन', 'HCl'].indexed) {
        await pour(tester, label);
        expect(find.text('चरण ${i + 2} / 3'), i < 2 ? findsOneWidget : findsNothing, reason: label);
      }
      expect(find.text('ब्यूरेट'), findsOneWidget);
      await runBurette(tester, '+ 1.0 mL', times: 7);
      await runBurette(tester, '+ 0.1 mL', times: 9);
      expect(find.text('पाठ्यांक: 7.9 mL'), findsOneWidget);
      // Any RenderFlex overflow above would already have failed the test.
    });

    testWidgets('a full titration shows the reading and the worked concentration', (tester) async {
      await openTitrationLab(tester);
      await completeTitration(tester);
      await tester.pump(const Duration(milliseconds: 1500));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Practical Complete!'), findsOneWidget);
      expect(find.text('Burette reading at the end point: 8.0 mL'), findsOneWidget);
      expect(find.text('c(NaOH) = 0.1 × 8.0 ÷ 10.0 = 0.080 M'), findsOneWidget);
    });
  });
}
