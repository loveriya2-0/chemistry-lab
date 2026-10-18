import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:virtual_chemistry_lab/content/content_catalog.dart';
import 'package:virtual_chemistry_lab/content/content_repository.dart';
import 'package:virtual_chemistry_lab/content/content_validator.dart';
import 'package:virtual_chemistry_lab/content/models/practical_coverage.dart';
import 'package:virtual_chemistry_lab/content/shared_content.dart';
import 'package:virtual_chemistry_lab/screens/class_selection_screen.dart';
import 'package:virtual_chemistry_lab/state/app_state.dart';

import 'test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ContentCatalog catalog;
  late LoadedCurriculum up;
  late LoadedCurriculum cbse;

  setUpAll(() async {
    catalog = await ContentCatalog.load(ContentRepository());
    up = catalog.curriculum('up')!;
    cbse = catalog.curriculum('cbse')!;
  });

  group('UP Board (UPMSP) 2026-27', () {
    test('passes every syllabus and content rule', () async {
      expect(ContentValidator.curriculum(up.manifest, await ContentRepository().allClasses('up')), isEmpty);
      expect(ContentValidator.learningContent(up, notesForClasses: {10, 11, 12}), isEmpty);
      // The CBSE content is unaffected.
      expect(ContentValidator.learningContent(cbse, notesForClasses: {9, 10, 11, 12}), isEmpty);
    });

    test('marks and exam pattern are those of the UPMSP syllabus PDFs', () {
      List<int> marks(int level) => [for (final c in up.classes[level]!.examChapters) c.weightage.marks];
      expect(marks(11), [7, 8, 7, 7, 6, 8, 7, 10, 10]);
      expect(marks(12), [8, 7, 7, 6, 7, 7, 7, 8, 6, 7]);
      expect(up.classes[10]!.units.single.marks, 20);
      expect(up.classes[9]!.units.single.marks, 20);
      for (final level in [9, 10, 11, 12]) {
        final p = up.classes[level]!.examPattern;
        expect((p.theoryMarks, p.practicalMarks), (70, 30), reason: 'Class $level');
        expect(p.boardExam, level == 10 || level == 12, reason: 'Class $level');
      }
      expect(up.manifest.sources.where((s) => s.publisher == 'UPMSP').map((s) => s.url), everyElement(startsWith('https://upmsp.edu.in/')));
    });

    test('Classes 10–12 follow the same NCERT chapters and sections as the CBSE content', () {
      for (final level in [10, 11, 12]) {
        final a = up.classes[level]!.examChapters;
        final b = cbse.classes[level]!.examChapters;
        expect([for (final c in a) c.title.en], [for (final c in b) c.title.en], reason: 'Class $level');
        for (final (i, c) in a.indexed) {
          expect([for (final t in c.topics.expand((t) => t.selfAndDescendants)) t.number],
              [for (final t in b[i].topics.expand((t) => t.selfAndDescendants)) t.number], reason: c.id);
        }
      }
    });

    test('shares NCERT notes and practice questions under UP ids — never CBSE previous-year questions', () {
      expect(up.pyqs, isEmpty);
      final perClass = {for (final l in [9, 10, 11, 12]) l: up.practiceQuestions(classLevel: l).length};
      expect(perClass, {9: 54, 10: 193, 11: 226, 12: 242});
      for (final level in [10, 11, 12]) {
        expect(perClass[level], cbse.practiceQuestions(classLevel: level).length, reason: 'Class $level');
      }
      expect(up.notes, hasLength(201));
      for (final n in up.notes) {
        expect(n.id, isNot(contains('cbse')), reason: n.id);
        expect(n.targetId, startsWith('up-'), reason: n.id);
        expect(n.practicalIds, isEmpty, reason: '${n.id}: no CBSE practical links');
      }
      for (final q in up.questions) {
        expect(q.id, isNot(contains('cbse')), reason: q.id);
        expect(up.topic(q.topicId), isNotNull, reason: q.id);
        expect(q.chapterId, up.topic(q.topicId)!.chapter.id, reason: q.id);
      }
      // Same text as the CBSE item it came from.
      final original = cbse.questions.firstWhere((q) => q.id == 'q-cbse-12-ch01-08');
      final shared = up.questions.firstWhere((q) => q.id == 'q-up-12-ch01-08');
      expect(shared.question.en, original.question.en);
      expect(shared.topicId, 'up-12-ch01-t1.6');
    });

    test('Class 9 reuses notes only where the idea is the same; other topics stay empty', () {
      final c9 = up.classes[9]!;
      final topics = [for (final ch in c9.chapters) ...ch.topics.expand((t) => t.selfAndDescendants)];
      expect(topics, hasLength(23));
      final empty = [for (final t in topics) if (up.noteFor(t.id) == null) t.number];
      // "Matter in our surroundings" (except sublimation) and "Elements, compounds and mixtures".
      expect(empty, ['1.1', '1.2', '1.3', '1.4', '2.1']);
    });

    test('practical status: only what the labs really do is marked interactive', () {
      final status = {
        for (final level in up.classLevels)
          for (final p in up.classes[level]!.practicals) p.id: up.practicalStatus(p).level,
      };
      expect(status, hasLength(27));
      expect([for (final e in status.entries) if (e.value == PracticalLevel.fullyInteractive) e.key], ['up-10-p2']);
      expect([for (final e in status.entries) if (e.value == PracticalLevel.partiallyInteractive) e.key],
          ['up-9-p3', 'up-10-p1', 'up-10-p3', 'up-10-p8', 'up-11-p4', 'up-11-p5', 'up-12-p2', 'up-12-p3B']);
      expect(status.values.where((v) => v == PracticalLevel.notImplemented), hasLength(18));
      for (final level in up.classLevels) {
        for (final p in up.classes[level]!.practicals) {
          final s = up.practicalStatus(p);
          if (s.level == PracticalLevel.partiallyInteractive) expect(s.coverage!.notCovered, isNotNull, reason: p.id);
        }
      }
      // Lab links point only at UP practicals.
      for (final l in up.manifest.labLinks) {
        expect(l.practicalId, startsWith('up-'), reason: l.labId);
      }
    });

    test('ids are rewritten so UP and CBSE progress never mix', () {
      expect(SharedContent.rewriteId('qt-cbse-12-ch01-t1.1-1', 'cbse', 'up'), 'qt-up-12-ch01-t1.1-1');
      expect(SharedContent.rewriteId('note-cbse-9-ch05-t5.1', 'cbse', 'up'), 'note-up-9-ch05-t5.1');
      final upIds = {for (final q in up.questions) q.id};
      final cbseIds = {for (final q in cbse.questions) q.id};
      expect(upIds.intersection(cbseIds), isEmpty);
    });

    test('a mapping that names the same source twice is refused', () {
      expect(
        () => SharedContent.fromJson({
          'fromBoard': 'cbse',
          'basis': {'en': 'x', 'hi': 'य'},
          'topics': [
            {'from': 'cbse-9-ch05-t5.1', 'to': 'up-9-ch02-t2.2'},
            {'from': 'cbse-9-ch05-t5.1', 'to': 'up-9-ch02-t2.1'},
          ],
        }, sourceTopicsByChapter: const {}),
        throwsFormatException,
      );
    });

    test('shared lab guides name no board-specific practical letters', () {
      for (final g in up.guides.values) {
        for (final t in g.simulationLimits) {
          expect(t.en, isNot(matches(RegExp(r'Practical [A-Z]\b'))), reason: g.id);
        }
      }
    });
  });

  group('UP Board in the app', () {
    testWidgets('choose UP Board: Class 12 shows its 10 chapters, a shared note and practice questions', (tester) async {
      final prefs = await launchApp(tester, board: null, size: const Size(1080, 6000));
      await tester.tap(find.text('UP Board'));
      await tester.pumpAndSettle();
      expect(find.byType(ClassSelectionScreen), findsOneWidget);
      expect(prefs.getString(AppState.boardKey), 'up');
      expect(find.text('UP Board · Syllabus 2026-27 · Change board'), findsOneWidget);
      expect(find.text('4 chapters'), findsNWidgets(2)); // Classes 9 and 10
      expect(find.text('10 chapters'), findsOneWidget); // Class 12

      await scrollAndTap(tester, find.text('Class 12'));
      await scrollAndTap(tester, find.text('Solutions'));
      await scrollAndTap(tester, find.text('Colligative Properties and Determination of Molar Mass'));
      expect(find.textContaining('not in the app yet'), findsNothing);
      await tester.scrollUntilVisible(find.textContaining('Practice questions ·'), 300, scrollable: find.byType(Scrollable).first);
      expect(find.textContaining('Practice questions ·'), findsOneWidget);
    });

    testWidgets('UP Class 9: a topic with no checked note says so honestly', (tester) async {
      await launchApp(tester, board: 'up', size: const Size(1080, 6000));
      await scrollAndTap(tester, find.text('Class 9'));
      await scrollAndTap(tester, find.text('Matter in Our Surroundings'));
      await scrollAndTap(tester, find.text('Evaporation and Cooling'));
      expect(find.textContaining('not in the app yet'), findsOneWidget);
    });

    testWidgets('UP board selection in Hindi shows UP Board as available', (tester) async {
      await launchApp(tester, board: null, size: const Size(1080, 4000), saved: {'app_language': 'hi'});
      expect(find.text('यूपी बोर्ड'), findsOneWidget);
      expect(find.text('उपलब्ध'), findsNWidgets(7));
    });
  });
}
