import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:virtual_chemistry_lab/content/content_catalog.dart';
import 'package:virtual_chemistry_lab/content/content_repository.dart';
import 'package:virtual_chemistry_lab/content/content_text.dart';
import 'package:virtual_chemistry_lab/content/content_validator.dart';
import 'package:virtual_chemistry_lab/content/models/practice_question.dart';
import 'package:virtual_chemistry_lab/content/models/pyq.dart';
import 'package:virtual_chemistry_lab/content/models/review.dart';
import 'package:virtual_chemistry_lab/content/models/syllabus.dart';
import 'package:virtual_chemistry_lab/content/models/topic_note.dart';
import 'package:virtual_chemistry_lab/l10n/app_language.dart';
import 'package:virtual_chemistry_lab/screens/chemical_screen.dart';
import 'package:virtual_chemistry_lab/screens/question_bank_screen.dart';
import 'package:virtual_chemistry_lab/screens/topic_detail_screen.dart';

import 'test_helpers.dart';

/// In-memory asset bundle for test-only fixtures.
class _MapBundle extends CachingAssetBundle {
  _MapBundle(this.files);

  final Map<String, String> files;

  @override
  Future<ByteData> load(String key) async {
    final text = files[key];
    if (text == null) throw StateError('Missing asset $key');
    return ByteData.sublistView(Uint8List.fromList(utf8.encode(text)));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ContentCatalog catalog;
  late LoadedCurriculum cbse;

  setUpAll(() async {
    catalog = await ContentCatalog.load(ContentRepository());
    cbse = catalog.curriculum('cbse')!;
  });

  group('CBSE 2026-27 learning content', () {
    test('passes every content rule (ids, references, Hindi, marks, sources)', () {
      expect(ContentValidator.learningContent(cbse, notesForClasses: {9, 10, 11, 12}), isEmpty);
    });

    test('every topic of Classes 9–12 is explained by exactly one note', () {
      for (final level in [9, 10, 11, 12]) {
        for (final ch in cbse.classes[level]!.chapters) {
          final ids = [for (final t in ch.topics.expand((t) => t.selfAndDescendants)) t.id];
          for (final id in ids.isEmpty ? [ch.id] : ids) {
            expect(cbse.noteFor(id), isNotNull, reason: id);
          }
        }
      }
      expect(cbse.notes, hasLength(224));
    });

    test('Classes 11–12 have practice questions; PYQs only for Class 12 (Class 11 has no board exam)', () {
      // 108 and 120 originally, plus the topic-wise batch (118 and 122).
      expect(cbse.practiceQuestions(classLevel: 11), hasLength(226));
      expect(cbse.practiceQuestions(classLevel: 12), hasLength(242));
      for (final level in [11, 12]) {
        for (final ch in cbse.classes[level]!.examChapters) {
          expect(cbse.practiceQuestions(classLevel: level, chapterId: ch.id), isNotEmpty, reason: ch.id);
        }
      }
      expect(cbse.pyqsForClass(11), isEmpty);
      expect(cbse.pyqsForClass(12), hasLength(134));
    });

    test('every note has all ten parts in English and Hindi', () {
      for (final n in cbse.notes) {
        expect(n.keyPoints, isNotEmpty, reason: n.id);
        expect(n.commonMistakes, isNotEmpty, reason: n.id);
        expect(n.sources, isNotEmpty, reason: n.id);
        for (final t in n.texts) {
          expect(t.hasHindi, isTrue, reason: n.id);
          expect(t.hiSource, HindiSource.translated, reason: '${n.id}: our own Hindi must be flagged for review');
          expect(t.of(AppLanguage.hi), isNot(t.en), reason: n.id);
        }
      }
    });

    test('Class 9 notes follow the new "Exploration" textbook, not the old one', () {
      final ch5 = cbse.noteFor('cbse-9-ch05-t5.2')!;
      expect(ch5.formulas.join(), allOf(contains('% = (mass of solute in g ÷ volume of solution in mL)'), contains('Volume by volume')));
      final sublimation = cbse.noteFor('cbse-9-ch05-t5.4.2')!;
      expect(sublimation.definition.en, contains('deposition'));
      expect(cbse.noteFor('cbse-9-ch08-t8.6'), same(cbse.noteFor('cbse-9-ch08-t8.5')));
    });

    test('bleaching powder follows the current NCERT reprint (Ca(ClO)₂)', () {
      final note = cbse.noteFor('cbse-10-ch02-t2.4.3')!;
      expect(note.formulas, contains('2Ca(OH)₂ + 2Cl₂ → Ca(ClO)₂ + CaCl₂ + 2H₂O'));
      expect(cbse.chemicals['bleaching-powder']!.formula, 'Ca(ClO)₂');
    });

    test('formative-only Periodic Classification has a note but no exam questions', () {
      expect(cbse.noteFor('cbse-10-periodic'), isNotNull);
      expect(cbse.practiceQuestions(classLevel: 10, chapterId: 'cbse-10-periodic'), isEmpty);
      expect(cbse.pyqs.where((q) => q.chapterId == 'cbse-10-periodic'), isEmpty);
    });

    test('concept and chemical libraries: every entry is linked from a note', () {
      expect(cbse.concepts, hasLength(84));
      expect(cbse.chemicals, hasLength(31));
      for (final id in cbse.concepts.keys) {
        expect(cbse.notes.any((n) => n.conceptIds.contains(id)), isTrue, reason: id);
      }
      expect(cbse.topicsForConcept('neutralisation').map((l) => l.topic.id), ['cbse-10-ch02-t2.1.4', 'cbse-10-ch02-t2.4']);
      for (final id in cbse.chemicals.keys) {
        expect(cbse.topicsForChemical(id), isNotEmpty, reason: id);
      }
    });

    test('practice questions cover every exam chapter and question type', () {
      final all = [...cbse.practiceQuestions(classLevel: 9), ...cbse.practiceQuestions(classLevel: 10)];
      expect(all, hasLength(322)); // 85 originally + 237 topic-wise
      for (final level in [9, 10]) {
        for (final ch in cbse.classes[level]!.examChapters) {
          final qs = cbse.practiceQuestions(classLevel: level, chapterId: ch.id);
          expect(qs.length, greaterThanOrEqualTo(12), reason: ch.id);
          expect({for (final q in qs) q.type}, containsAll([QuestionType.mcq, QuestionType.assertionReason, QuestionType.longAnswer, QuestionType.caseBased]), reason: ch.id);
        }
      }
      expect(all.where((q) => q.type == QuestionType.numerical), isNotEmpty);
      expect({for (final q in all) q.difficulty}, Difficulty.values.toSet());
    });

    test('PYQs: Class 10 chemistry questions and complete Class 12 papers from the entered sets', () {
      final byPaper = <(int, int), int>{};
      final class12Marks = <int, int>{};
      for (final q in cbse.pyqs) {
        byPaper[(q.classLevel, q.examYear)] = (byPaper[(q.classLevel, q.examYear)] ?? 0) + 1;
        if (q.classLevel == 12) class12Marks[q.examYear] = (class12Marks[q.examYear] ?? 0) + q.marks;
        expect(q.boardId, 'cbse');
        expect(q.classLevel, anyOf(10, 12));
        expect(q.paperUrl, startsWith('https://www.cbse.gov.in/'));
        expect(q.markingSchemeUrl, startsWith('https://www.cbse.gov.in/'));
      }
      expect(byPaper, {
        (10, 2023): 13, (10, 2024): 13, (10, 2025): 13, (10, 2026): 13,
        (12, 2023): 35, (12, 2024): 33, (12, 2025): 33, (12, 2026): 33,
      });
      expect(class12Marks, {2023: 70, 2024: 70, 2025: 70, 2026: 70}, reason: 'every Class 12 paper is entered in full');
      expect(cbse.enteredExamYears, [2023, 2024, 2025, 2026]);
      expect(cbse.pyqPaperCount(10), 4);
      expect(cbse.pyqPaperCount(12), 4);
    });

    test('PYQ answers match the official marking schemes (spot checks)', () {
      PyqQuestion q(int year, String no) => cbse.pyqs.singleWhere((x) => x.classLevel == 10 && x.examYear == year && x.questionNumber == no);
      PyqQuestion q12(int year, String no) => cbse.pyqs.singleWhere((x) => x.classLevel == 12 && x.examYear == year && x.questionNumber == no);
      String picked(PyqQuestion x) => x.options[x.correctOption!].en;
      expect(picked(q(2025, '1')), '1 : 8');
      expect(picked(q(2025, '6')), 'Calcium and magnesium');
      expect(picked(q(2024, '5')), 'Na₂CO₃');
      expect(picked(q(2024, '7')), 'MnO₂ is reduced and HCl is oxidised');
      expect(picked(q(2023, '7')), '10');
      expect(picked(q(2023, '17')), 'A is false, but R is true.');
      expect(picked(q(2026, '17')), '(ii) and (iii)');
      expect(picked(q(2026, '22')), 'Sodium hydrogencarbonate + tartaric acid');
      expect(q(2026, '29').marks, 5);
      expect(q(2025, '37').type, QuestionType.caseBased);
      // Class 12 Chemistry (043): 2023, 2024 and 2026 set 56/1/1; 2025 set 56/4/1.
      expect(picked(q12(2023, '1')), 'Osmotic pressure');
      expect(picked(q12(2023, '16')), 'A is true, but R is false.');
      expect(picked(q12(2024, '1')), 'Manganese (Z = 25)');
      expect(picked(q12(2024, '13')), 'Both A and R are true, but R is not the correct explanation of A.');
      expect(picked(q12(2025, '8')), 'Benzene (C₆H₆)');
      expect(picked(q12(2025, '11')), '5 F');
      expect(picked(q12(2026, '10')), '51% para, 47% meta, 2% ortho');
      expect(picked(q12(2026, '16')), 'A is true, but R is false.');
      expect(q12(2024, '23').answer!.en, contains('k = 8 L² mol⁻² s⁻¹'));
      expect(q12(2026, '33').answer!.en, contains('3.052 V'));
      expect(q12(2025, '33').paperCode, '56/4/1');
      expect(q12(2025, '33').type, QuestionType.longAnswer);
    });

    test('exam importance is computed from PYQs, never stored in content files', () {
      expect(cbse.chapterImportance('cbse-10-ch01').askedInYears, [2023, 2024, 2025, 2026]);
      expect(cbse.chapterImportance('cbse-10-ch01').level, ImportanceLevel.high);
      expect(cbse.chapterImportance('cbse-12-ch02').askedInYears, [2023, 2024, 2025, 2026]);
      for (final level in [9, 11]) {
        for (final ch in cbse.classes[level]!.chapters) {
          expect(cbse.chapterImportance(ch.id).level, ImportanceLevel.none, reason: 'Class $level has no board exam');
        }
      }
      // No hand-typed importance or weightage in any learning-content file.
      final dirs = ['assets/content/library', 'assets/content/boards/cbse/2026-27/notes', 'assets/content/boards/cbse/2026-27/questions', 'assets/content/boards/cbse/2026-27/pyq'];
      for (final d in dirs) {
        for (final f in Directory(d).listSync(recursive: true).whereType<File>()) {
          final text = f.readAsStringSync();
          expect(text.contains('"importance"') || text.contains('"weightage"') || text.contains('"timesAsked"'), isFalse, reason: f.path);
        }
      }
    });

    test('coming-soon boards get no content', () {
      for (final b in catalog.registry.comingSoon) {
        expect(catalog.curriculum(b.id), isNull, reason: b.id);
      }
      for (final id in [...cbse.notes.map((n) => n.targetId), ...cbse.questions.map((q) => q.chapterId), ...cbse.pyqs.map((q) => q.chapterId)]) {
        expect(id, startsWith('cbse-'));
      }
    });
  });

  group('validator catches bad content (test fixtures, not app content)', () {
    const hi = HindiSource.translated;
    TopicNote note({String id = 'fx-note', String target = 'cbse-10-ch01-t1.1', String hiText = 'हिंदी पाठ', List<String> concepts = const []}) => TopicNote(
          id: id,
          targetId: target,
          coveredIds: const [],
          definition: ContentText(en: 'Definition text', hi: hiText, hiSource: hi),
          explanation: const ContentText(en: 'Text', hi: 'पाठ', hiSource: hi),
          keyPoints: const [ContentText(en: 'Point', hi: 'बिंदु', hiSource: hi)],
          realLife: const ContentText(en: 'Use', hi: 'उपयोग', hiSource: hi),
          examFocus: const ContentText(en: 'Focus', hi: 'ध्यान', hiSource: hi),
          commonMistakes: const [ContentText(en: 'Mistake', hi: 'ग़लती', hiSource: hi)],
          formulas: const [],
          practicalIds: const [],
          conceptIds: concepts,
          chemicalIds: const [],
          sources: const [SourceRef(sourceId: 'ncert-10-en')],
          review: ReviewStatus.sourceChecked,
        );

    LoadedCurriculum with_({List<TopicNote> notes = const [], List<PracticeQuestion> questions = const [], List<PyqQuestion> pyqs = const []}) =>
        LoadedCurriculum(cbse.manifest, cbse.classes.values.toList(), concepts: cbse.concepts, chemicals: cbse.chemicals, notes: notes, questions: questions, pyqs: pyqs);

    test('unknown topic, missing Hindi, placeholder text, unknown concept, double coverage', () {
      final issues = ContentValidator.learningContent(
        with_(notes: [
          note(target: 'cbse-10-ch01-t9.9'),
          note(id: 'fx-2', hiText: 'Definition text'),
          note(id: 'fx-3', hiText: 'TODO हिंदी'),
          note(id: 'fx-4', concepts: ['no-such-concept']),
        ]),
        notesForClasses: const {},
      );
      expect(issues, contains('Note fx-note: unknown topic or chapter "cbse-10-ch01-t9.9"'));
      expect(issues.any((i) => i.startsWith('Note fx-2') && i.contains('not Hindi')), isTrue);
      expect(issues.any((i) => i.startsWith('Note fx-3') && i.contains('placeholder')), isTrue);
      expect(issues, contains('Note fx-4: unknown concept "no-such-concept"'));
      expect(issues.any((i) => i.contains('is already explained by')), isTrue);
    });

    test('a missing topic note is reported', () {
      final issues = ContentValidator.learningContent(with_(), notesForClasses: {10});
      expect(issues, contains('Class 10: "cbse-10-ch01-t1.1" has no note'));
    });

    test('wrong marks, bad option index and a PYQ from an unlisted paper', () {
      const t = ContentText(en: 'Question text', hi: 'प्रश्न', hiSource: hi);
      final q = PracticeQuestion(
        id: 'fx-q', classLevel: 10, chapterId: 'cbse-10-ch01', topicId: 'cbse-10-ch02-t2.1', type: QuestionType.mcq,
        marks: 3, difficulty: Difficulty.easy, question: t, answer: t, explanation: t,
        options: const [t, t, t, t], correctOption: 7, sources: const [SourceRef(sourceId: 'ncert-10-en')], review: ReviewStatus.sourceChecked,
      );
      final pyq = PyqQuestion(
        id: 'fx-pyq', boardId: 'cbse', classLevel: 10, examYear: 2019, attempt: ExamAttempt.main, paperCode: '99/9/9',
        questionNumber: '1', marks: 1, type: QuestionType.mcq, chapterId: 'cbse-10-ch01', syllabusStatus: SyllabusStatus.inSyllabus,
        paperUrl: 'https://www.cbse.gov.in/x.zip', summary: t, answer: t, review: ReviewStatus.sourceChecked,
      );
      final issues = ContentValidator.learningContent(with_(questions: [q], pyqs: [pyq]), notesForClasses: const {});
      expect(issues, contains('Question fx-q: topic cbse-10-ch02-t2.1 is not in cbse-10-ch01'));
      expect(issues, contains('Question fx-q: mcq cannot carry 3 marks'));
      expect(issues, contains('Question fx-q: correct option 7 is out of range'));
      expect(issues, contains('PYQ fx-pyq: paper 10|2019|main|99/9/9 is not listed in the manifest'));
      expect(issues, contains('PYQ fx-pyq: 2019 has no official paper'));
    });

    test('a PYQ for a class without a board exam is rejected', () {
      const t = ContentText(en: 'Question text', hi: 'प्रश्न', hiSource: hi);
      final pyq = PyqQuestion(
        id: 'fx-9', boardId: 'cbse', classLevel: 9, examYear: 2025, attempt: ExamAttempt.main, paperCode: '31/1/1',
        questionNumber: '1', marks: 2, type: QuestionType.veryShort, chapterId: 'cbse-9-ch05', syllabusStatus: SyllabusStatus.inSyllabus,
        paperUrl: 'https://www.cbse.gov.in/x.zip', summary: t, answer: t, review: ReviewStatus.sourceChecked,
      );
      final issues = ContentValidator.learningContent(with_(pyqs: [pyq]), notesForClasses: const {});
      expect(issues, contains('PYQ fx-9: Class 9 has no board exam'));
    });

    test('unchecked (draft) content is not shown', () {
      final draft = TopicNote(
        id: 'fx-draft', targetId: 'cbse-10-ch01-t1.1', coveredIds: const [], definition: const ContentText(en: 'x', hi: 'य'),
        explanation: const ContentText(en: 'x'), keyPoints: const [], realLife: const ContentText(en: 'x'),
        examFocus: const ContentText(en: 'x'), commonMistakes: const [], formulas: const [], practicalIds: const [],
        conceptIds: const [], chemicalIds: const [], sources: const [], review: ReviewStatus.draft,
      );
      expect(with_(notes: [draft]).noteFor('cbse-10-ch01-t1.1'), isNull);
    });
  });

  test('a file-level hiSrc applies to every bilingual text that has none', () async {
    final repo = ContentRepository(bundle: _MapBundle({
      'assets/content/x.json': '{"hiSrc":"translated","items":[{"a":{"en":"A","hi":"अ"},"b":{"en":"B","hi":"ब","hiSrc":"ncert"},"c":{"en":"C"}}]}',
    }));
    final item = (await repo.jsonList('x.json')).single;
    expect(ContentText.fromJson(item['a']! as Json).hiSource, HindiSource.translated);
    expect(ContentText.fromJson(item['b']! as Json).hiSource, HindiSource.ncert);
    expect(ContentText.fromJson(item['c']! as Json).hiSource, isNull);
  });

  group('screens show the content (English and Hindi)', () {
    Future<void> openTopic(WidgetTester tester, {bool hindi = false}) async {
      await launchApp(tester, saved: {if (hindi) 'app_language': 'hi'});
      await tester.tap(find.text(hindi ? 'कक्षा 10' : 'Class 10'));
      await tester.pumpAndSettle();
      await scrollAndTap(tester, find.text(hindi ? 'अम्ल, क्षारक एवं लवण' : 'Acids, Bases and Salts'));
      await scrollAndTap(tester, find.text(hindi ? 'विषय 2.4' : 'TOPIC 2.4'));
      expect(find.byType(TopicDetailScreen), findsOneWidget);
    }

    testWidgets('topic notes, concepts, chemicals and practice are reachable', (tester) async {
      await openTopic(tester);
      final scroll = find.byType(Scrollable).first;
      await tester.scrollUntilVisible(find.textContaining('Common salt (sodium chloride) is the raw material'), 300, scrollable: scroll);
      await tester.scrollUntilVisible(find.text('Bleaching powder'), 300, scrollable: scroll);
      await tester.tap(find.text('Bleaching powder'));
      await tester.pumpAndSettle();
      expect(find.byType(ChemicalScreen), findsOneWidget);
      expect(find.text('Formula: Ca(ClO)₂'), findsOneWidget);
    });

    testWidgets('Hindi topic page shows Hindi notes', (tester) async {
      await openTopic(tester, hindi: true);
      await tester.scrollUntilVisible(find.textContaining('समान धनात्मक या ऋणात्मक मूलक वाले लवण'), 300, scrollable: find.byType(Scrollable).first);
      expect(find.text('परिभाषा'), findsWidgets);
      expect(find.textContaining('लवण परिवार'), findsWidgets);
      expect(find.textContaining('Awaiting review'), findsNothing);
      expect(find.textContaining('विषय-शिक्षक की समीक्षा शेष है'), findsWidgets);
    });

    testWidgets('MCQ: picking an option reveals right/wrong and the explanation', (tester) async {
      await launchApp(tester);
      final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
      nav.push(MaterialPageRoute<void>(
        builder: (_) => const QuestionBankScreen(classLevel: 9, title: 'Practice', chapterId: 'cbse-9-ch05'),
      ));
      await tester.pumpAndSettle();
      expect(find.textContaining('not previous-year questions'), findsOneWidget);
      expect(find.textContaining('Which of the following is a homogeneous mixture?'), findsOneWidget);
      await tester.tap(find.text('Sand in water'));
      await tester.pumpAndSettle();
      expect(find.text('Not quite — the correct answer is marked.'), findsOneWidget);
      expect(find.textContaining('Vinegar is acetic acid dissolved in water'), findsOneWidget);
    });

    testWidgets('formative-only chapter shows its note on the chapter page', (tester) async {
      await launchApp(tester);
      await tester.tap(find.text('Class 10'));
      await tester.pumpAndSettle();
      await scrollAndTap(tester, find.text('Periodic Classification of Elements'));
      await tester.scrollUntilVisible(find.textContaining('modern periodic law'), 300, scrollable: find.byType(Scrollable).first);
      expect(find.text('Practice questions · 0'), findsNothing);
    });
  });
}
