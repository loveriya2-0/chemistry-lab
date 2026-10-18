import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:virtual_chemistry_lab/content/content_catalog.dart';
import 'package:virtual_chemistry_lab/content/content_repository.dart';
import 'package:virtual_chemistry_lab/content/content_text.dart';
import 'package:virtual_chemistry_lab/content/content_validator.dart';
import 'package:virtual_chemistry_lab/content/models/review.dart';
import 'package:virtual_chemistry_lab/content/models/topic_note.dart';
import 'package:virtual_chemistry_lab/l10n/app_language.dart';
import 'package:virtual_chemistry_lab/screens/topic_detail_screen.dart';
import 'package:virtual_chemistry_lab/widgets/learning_widgets.dart';

import 'test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late LoadedCurriculum cbse;

  setUpAll(() async {
    cbse = (await ContentCatalog.load(ContentRepository())).curriculum('cbse')!;
  });

  group('memory tricks and quick revision in the CBSE content', () {
    test('every trick has English and Hindi, with Hindi flagged for review', () {
      final tricks = [for (final n in cbse.notes) ...n.memoryTricks];
      expect(tricks, isNotEmpty);
      for (final t in tricks) {
        for (final x in [t.trick, t.recall]) {
          expect(x.en.trim(), isNotEmpty);
          expect(x.hasHindi, isTrue, reason: x.en);
          expect(x.hiSource, HindiSource.translated, reason: x.en);
          expect(x.of(AppLanguage.hi), isNot(x.en), reason: x.en);
          expect(x.of(AppLanguage.hi), matches(RegExp('[ऀ-ॿ]')), reason: x.en);
        }
        expect(t.trick.en, isNot(t.recall.en));
      }
    });

    test('tricks are optional: only added where they help, at most three per note', () {
      final withTricks = cbse.notes.where((n) => n.memoryTricks.isNotEmpty);
      final without = cbse.notes.where((n) => n.memoryTricks.isEmpty);
      expect(withTricks, isNotEmpty);
      expect(without, isNotEmpty, reason: 'tricks must not be forced onto every topic');
      for (final n in cbse.notes) {
        expect(n.memoryTricks.length, lessThanOrEqualTo(ContentValidator.maxMemoryTricks), reason: n.id);
      }
    });

    test('every Class 9–10 note has a quick revision built from its own formulas', () {
      for (final n in cbse.notes) {
        final q = n.quickRevision;
        expect(q, isNotNull, reason: n.id);
        expect(q!.oneLine.hasHindi, isTrue, reason: n.id);
        expect(q.points.length, inInclusiveRange(1, 3), reason: n.id);
        if (q.formula != null) expect(n.formulas, contains(q.formula), reason: n.id);
      }
    });

    test('no placeholder or template text in any trick or revision', () {
      final bad = RegExp(r'\.\.\.|…|\bABC\b|\b(todo|tbd|lorem|placeholder|xxx|dummy)\b', caseSensitive: false);
      for (final n in cbse.notes) {
        final texts = [
          for (final t in n.memoryTricks) ...[t.trick, t.recall],
          if (n.quickRevision case final q?) ...[q.oneLine, ...q.points],
        ];
        for (final t in texts) {
          expect(bad.hasMatch(t.en) || bad.hasMatch(t.hi!), isFalse, reason: '${n.id}: ${t.en}');
        }
      }
    });

    test('tricks match the facts in their notes (spot checks)', () {
      final series = cbse.noteFor('cbse-10-ch03-t3.2.4')!;
      expect(series.memoryTricks.first.recall.en, contains(series.quickRevision!.formula!));
      expect(series.formulas, contains('K > Na > Ca > Mg > Al > Zn > Fe > Pb > H > Cu > Hg > Ag > Au'));
      expect(cbse.noteFor('cbse-9-ch08-t8.9.2')!.memoryTricks.single.trick.en, contains('isobArs → same A'));
      expect(cbse.noteFor('cbse-10-ch02-t2.3')!.quickRevision!.formula, 'pH < 7 acidic; pH = 7 neutral; pH > 7 basic');
      expect(cbse.noteFor('cbse-10-ch02-t2.1.3')!.memoryTricks, isEmpty);
    });

    test('the validator accepts the shipped tricks', () {
      expect(ContentValidator.learningContent(cbse, notesForClasses: {9, 10}), isEmpty);
    });
  });

  group('memory-trick schema and rules (test fixtures, not app content)', () {
    const hi = HindiSource.translated;
    TopicNote note({List<MemoryTrick> tricks = const [], QuickRevision? revision, List<String> formulas = const []}) => TopicNote(
          id: 'fx-note',
          targetId: 'cbse-10-ch01-t1.1',
          coveredIds: const [],
          definition: const ContentText(en: 'Definition text', hi: 'परिभाषा पाठ', hiSource: hi),
          explanation: const ContentText(en: 'Text', hi: 'पाठ', hiSource: hi),
          keyPoints: const [ContentText(en: 'Point', hi: 'बिंदु', hiSource: hi)],
          realLife: const ContentText(en: 'Use', hi: 'उपयोग', hiSource: hi),
          examFocus: const ContentText(en: 'Focus', hi: 'ध्यान', hiSource: hi),
          commonMistakes: const [ContentText(en: 'Mistake', hi: 'ग़लती', hiSource: hi)],
          formulas: formulas,
          practicalIds: const [],
          conceptIds: const [],
          chemicalIds: const [],
          sources: const [SourceRef(sourceId: 'ncert-10-en')],
          review: ReviewStatus.sourceChecked,
          memoryTricks: tricks,
          quickRevision: revision,
        );
    List<String> issues(TopicNote n) => ContentValidator.learningContent(
          LoadedCurriculum(cbse.manifest, cbse.classes.values.toList(), concepts: cbse.concepts, chemicals: cbse.chemicals, notes: [n]),
          notesForClasses: const {},
        ).where((i) => i.startsWith('Note fx-note')).toList();
    MemoryTrick trick(String en, String? hiText, {String recall = 'What it means'}) =>
        MemoryTrick(trick: ContentText(en: en, hi: hiText, hiSource: hi), recall: ContentText(en: recall, hi: 'अर्थ', hiSource: hi));

    test('JSON without the fields: no tricks and no quick revision', () {
      final n = TopicNote.fromJson({
        'id': 'fx', 'targetId': 'x', 'definition': {'en': 'a'}, 'explanation': {'en': 'b'},
        'realLife': {'en': 'c'}, 'examFocus': {'en': 'd'},
      });
      expect(n.memoryTricks, isEmpty);
      expect(n.quickRevision, isNull);
    });

    test('JSON with the fields parses English and Hindi', () {
      final n = TopicNote.fromJson({
        'id': 'fx', 'targetId': 'x', 'definition': {'en': 'a'}, 'explanation': {'en': 'b'},
        'realLife': {'en': 'c'}, 'examFocus': {'en': 'd'}, 'formulas': ['A = B'],
        'memoryTricks': [
          {'trick': {'en': 'Trick', 'hi': 'ट्रिक'}, 'recall': {'en': 'Meaning', 'hi': 'अर्थ'}},
        ],
        'quickRevision': {
          'oneLine': {'en': 'Line', 'hi': 'पंक्ति'},
          'formula': 'A = B',
          'points': [{'en': 'P', 'hi': 'बि'}],
        },
      });
      expect(n.memoryTricks.single.trick.of(AppLanguage.hi), 'ट्रिक');
      expect(n.memoryTricks.single.recall.of(AppLanguage.en), 'Meaning');
      expect(n.quickRevision!.oneLine.of(AppLanguage.hi), 'पंक्ति');
      expect(n.quickRevision!.formula, 'A = B');
      expect(n.quickRevision!.points, hasLength(1));
    });

    test('an empty trick list and no revision are valid', () {
      expect(issues(note()), isEmpty);
    });

    test('missing Hindi, template and placeholder tricks are rejected', () {
      expect(issues(note(tricks: [trick('Real trick', null)])), contains(contains('no Hindi text')));
      expect(issues(note(tricks: [trick('"ABC..." → remember', 'याद रखें')])), contains(contains('template text')));
      expect(issues(note(tricks: [trick('Trick goes here', 'ट्रिक')])), contains(contains('template text')));
      expect(issues(note(tricks: [trick('TODO', 'ट्रिक')])), contains(contains('placeholder')));
      expect(issues(note(tricks: [trick('Same', 'समान', recall: 'Same')])), contains(contains('trick and its meaning are the same')));
      expect(issues(note(tricks: [for (var i = 0; i < 4; i++) trick('Trick $i', 'ट्रिक')])), contains(contains('more than 3 memory tricks')));
    });

    test('quick revision: 1–3 points and only the note\'s own formulas', () {
      const line = ContentText(en: 'One line', hi: 'एक पंक्ति', hiSource: hi);
      const p = ContentText(en: 'Point', hi: 'बिंदु', hiSource: hi);
      expect(issues(note(revision: const QuickRevision(oneLine: line, points: []))), contains(contains('quick revision needs 1–3 points')));
      expect(issues(note(revision: const QuickRevision(oneLine: line, points: [p, p, p, p]))), contains(contains('quick revision needs 1–3 points')));
      expect(issues(note(revision: const QuickRevision(oneLine: line, formula: 'X = Y', points: [p]))), contains(contains('is not one of the note')));
      expect(issues(note(formulas: ['X = Y'], revision: const QuickRevision(oneLine: line, formula: 'X = Y', points: [p]))), isEmpty);
    });
  });

  group('notes page shows the sections in the approved order', () {
    Future<void> openTopic(WidgetTester tester, {bool hindi = false, String number = '2.3'}) async {
      // A very tall window so the whole topic page is built at once.
      await launchApp(tester, size: const Size(1080, 40000), saved: {if (hindi) 'app_language': 'hi'});
      final loc = cbse.topic('cbse-10-ch02-t$number')!;
      tester.state<NavigatorState>(find.byType(Navigator).first).push(MaterialPageRoute<void>(
        builder: (_) => TopicDetailScreen(syllabus: loc.syllabus, chapter: loc.chapter, topic: loc.topic),
      ));
      await tester.pumpAndSettle();
    }

    double y(WidgetTester tester, Finder f) => tester.getTopLeft(f.first).dy;

    testWidgets('English: concept → … → quick revision → practice questions', (tester) async {
      await openTopic(tester);
      final order = [
        find.text('Definition'),
        find.text('Easy explanation'),
        find.text('🧠 Memory trick'),
        find.text('⭐ Main points'),
        find.text('🧪 Reactions & formulas'),
        find.text('🌍 Real-life use'),
        find.text('🎯 Exam importance'),
        find.text('⚠️ Common mistakes'),
        find.text('⚡ Quick revision'),
        find.textContaining('Practice questions ·'),
      ];
      for (final f in order) {
        expect(f, findsWidgets);
      }
      for (var i = 1; i < order.length; i++) {
        expect(y(tester, order[i]), greaterThan(y(tester, order[i - 1])), reason: '${order[i]}');
      }
      expect(find.text('A comes before B: Acidic below 7, Basic above 7'), findsOneWidget);
      expect(find.text('Must remember'), findsOneWidget);
      // PYQ-based importance now sits inside the 🎯 section, not as a separate block.
      expect(find.byType(ImportancePanel), findsOneWidget);
      expect(y(tester, find.byType(ImportancePanel)), greaterThan(y(tester, find.text('🎯 Exam importance'))));
      expect(y(tester, find.byType(ImportancePanel)), lessThan(y(tester, find.text('⚠️ Common mistakes'))));
    });

    testWidgets('Hindi headings and Hindi trick text', (tester) async {
      await openTopic(tester, hindi: true);
      for (final t in ['🧠 याद करने की ट्रिक', '⭐ मुख्य बिंदु', '🧪 अभिक्रिया / सूत्र', '🎯 परीक्षा में महत्व', '⚠️ आम गलतियाँ', '⚡ त्वरित पुनरावृत्ति', 'ज़रूर याद रखें']) {
        expect(find.text(t), findsWidgets, reason: t);
      }
      expect(find.textContaining('A पहले, B बाद में'), findsOneWidget);
      expect(find.text('🧠 Memory trick'), findsNothing);
    });

    testWidgets('a note without a trick hides the trick card', (tester) async {
      await openTopic(tester, number: '2.1.3');
      expect(find.byType(MemoryTrickCard), findsNothing);
      expect(find.byType(QuickRevisionCard), findsOneWidget);
      expect(find.text('⭐ Main points'), findsOneWidget);
    });
  });
}
