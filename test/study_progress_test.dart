import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:virtual_chemistry_lab/content/content_catalog.dart';
import 'package:virtual_chemistry_lab/content/content_repository.dart';
import 'package:virtual_chemistry_lab/content/models/practice_question.dart';
import 'package:virtual_chemistry_lab/content/models/pyq.dart';
import 'package:virtual_chemistry_lab/data/bookmark_store.dart';
import 'package:virtual_chemistry_lab/data/focus_session_store.dart';
import 'package:virtual_chemistry_lab/data/practical_attempt_store.dart';
import 'package:virtual_chemistry_lab/screens/practice_session_screen.dart';
import 'package:virtual_chemistry_lab/screens/revision_screen.dart';
import 'package:virtual_chemistry_lab/screens/topic_detail_screen.dart';
import 'package:virtual_chemistry_lab/study/study_map.dart';
import 'package:virtual_chemistry_lab/study/study_progress_store.dart';

import 'test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late LoadedCurriculum cbse;

  setUpAll(() async {
    cbse = (await ContentCatalog.load(ContentRepository())).curriculum('cbse')!;
  });

  Future<StudyProgressStore> freshStore([Map<String, Object> saved = const {}]) async {
    SharedPreferences.setMockInitialValues(saved);
    return StudyProgressStore(await SharedPreferences.getInstance());
  }

  group('topic status and chapter progress', () {
    test('opening a topic marks it in progress and remembers it as recent', () async {
      final s = await freshStore();
      expect(s.statusOf('cbse-10-ch02-t2.3'), TopicStatus.notStarted);
      s.visitTopic('cbse-10-ch02-t2.3');
      s.visitTopic('cbse-10-ch02-t2.1');
      s.visitTopic('cbse-10-ch02-t2.3');
      expect(s.statusOf('cbse-10-ch02-t2.3'), TopicStatus.inProgress);
      expect(s.recentTopicIds, ['cbse-10-ch02-t2.3', 'cbse-10-ch02-t2.1']);
      // A topic already marked completed stays completed when reopened.
      s.setStatus('cbse-10-ch02-t2.1', TopicStatus.completed);
      s.visitTopic('cbse-10-ch02-t2.1');
      expect(s.statusOf('cbse-10-ch02-t2.1'), TopicStatus.completed);
    });

    test('status survives a restart and old unreadable data is skipped, not fatal', () async {
      final s = await freshStore({StudyProgressStore.statusKey: '{"cbse-10-ch01-t1.1": {"s": "reviseAgain"}, "bad": 5}'});
      expect(s.statusOf('cbse-10-ch01-t1.1'), TopicStatus.reviseAgain);
      s.setStatus('cbse-10-ch01-t1.2', TopicStatus.completed);
      final prefs = await SharedPreferences.getInstance();
      final again = StudyProgressStore(prefs);
      expect(again.statusOf('cbse-10-ch01-t1.2'), TopicStatus.completed);
      expect(again.reviseAgainIds, ['cbse-10-ch01-t1.1']);
    });

    test('chapter progress counts top-level topics; sub-topics complete a topic only when all are studied', () async {
      final s = await freshStore();
      final ch = cbse.chapter('cbse-10-ch01')!.$2; // topics 1.1, 1.2, 1.3
      expect(StudyMap.chapter(ch, s).total, 3);
      expect(StudyMap.chapter(ch, s).studied, 0);

      s.setStatus('cbse-10-ch01-t1.1', TopicStatus.completed);
      expect(StudyMap.chapter(ch, s).studied, 1);

      // 1.3 has two sub-topics: one studied → in progress; both → completed.
      final t13 = ch.topics.firstWhere((t) => t.number == '1.3');
      s.setStatus('cbse-10-ch01-t1.3.1', TopicStatus.completed);
      expect(s.effectiveStatus(t13), TopicStatus.inProgress);
      s.setStatus('cbse-10-ch01-t1.3.2', TopicStatus.reviseAgain);
      expect(s.effectiveStatus(t13), TopicStatus.reviseAgain, reason: 'revise-again is never hidden');
      expect(StudyMap.chapter(ch, s).studied, 2, reason: 'revise-again counts as studied');
      s.setStatus('cbse-10-ch01-t1.3.2', TopicStatus.completed);
      expect(s.effectiveStatus(t13), TopicStatus.completed);

      s.setStatus('cbse-10-ch01-t1.2', TopicStatus.completed);
      expect(StudyMap.chapter(ch, s).isComplete, isTrue);
    });

    test('a chapter without topics (formative-only) is one unit marked as a whole', () async {
      final s = await freshStore();
      final ch = cbse.chapter('cbse-10-periodic')!.$2;
      expect(ch.topics, isEmpty);
      expect(StudyMap.chapter(ch, s).total, 1);
      s.setStatus(ch.id, TopicStatus.completed);
      expect(StudyMap.chapter(ch, s).isComplete, isTrue);
    });

    test('marking a revise-again topic completed ticks its revision item', () async {
      final s = await freshStore();
      s.setStatus('cbse-11-ch06-t6.8', TopicStatus.reviseAgain);
      expect(s.revisedAt('topic:cbse-11-ch06-t6.8'), isNull);
      s.setStatus('cbse-11-ch06-t6.8', TopicStatus.completed);
      expect(s.revisedAt('topic:cbse-11-ch06-t6.8'), isNotNull);
      expect(s.reviseAgainIds, isEmpty);
    });
  });

  group('chapter and topic navigation', () {
    test('top-level topics run through the class in order, crossing chapters', () {
      final last = cbse.topic('cbse-10-ch01-t1.3')!;
      final (prev, next) = StudyMap.neighbours(cbse, last);
      expect(prev!.topic.id, 'cbse-10-ch01-t1.2');
      expect(next!.topic.id, 'cbse-10-ch02-t2.1', reason: 'next chapter');
      final first = cbse.topic('cbse-10-ch01-t1.1')!;
      expect(StudyMap.neighbours(cbse, first).$1, isNull);
    });

    test('a sub-topic steps through its siblings only', () {
      final sub = cbse.topic('cbse-10-ch02-t2.1.2')!;
      final (prev, next) = StudyMap.neighbours(cbse, sub);
      expect(prev!.topic.id, 'cbse-10-ch02-t2.1.1');
      expect(next!.topic.id, 'cbse-10-ch02-t2.1.3');
      expect(StudyMap.parentOf(sub.chapter, sub.topic)!.id, 'cbse-10-ch02-t2.1');
    });

    test('every chapter and topic of Classes 9–12 is reachable and in textbook order', () {
      for (final level in [9, 10, 11, 12]) {
        final chapters = cbse.classes[level]!.chapters;
        final numbers = [for (final c in chapters) if (c.number != null) c.number!];
        expect(numbers, [...numbers]..sort(), reason: 'Class $level chapter order');
        for (final c in chapters) {
          for (final t in c.topics.expand((t) => t.selfAndDescendants)) {
            expect(cbse.topic(t.id)!.chapter.id, c.id);
          }
        }
      }
    });

    testWidgets('topic page: status, what is available, sub-topic link and Next', (tester) async {
      final prefs = await launchApp(tester, size: const Size(1080, 6000));
      final loc = cbse.topic('cbse-10-ch02-t2.1')!;
      tester.state<NavigatorState>(find.byType(Navigator).first).push(MaterialPageRoute<void>(
        builder: (_) => TopicDetailScreen(syllabus: loc.syllabus, chapter: loc.chapter, topic: loc.topic),
      ));
      await tester.pumpAndSettle();
      expect(StudyProgressStore(prefs).statusOf('cbse-10-ch02-t2.1'), TopicStatus.inProgress);
      expect(find.text('In this topic'), findsOneWidget);
      expect(find.text('Explanation'), findsOneWidget);
      expect(find.text('21 practice questions'), findsOneWidget);

      await tester.tap(find.text('Completed'));
      await tester.pumpAndSettle();
      expect(StudyProgressStore(prefs).statusOf('cbse-10-ch02-t2.1'), TopicStatus.completed);

      // Sub-topics open directly.
      await tester.tap(find.text('Acids and Bases in the Laboratory').first);
      await tester.pumpAndSettle();
      expect(find.text('TOPIC 2.1.1'), findsOneWidget);
      expect(find.textContaining('Part of topic 2.1'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      // Next goes to 2.2 (replacing the page).
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('TOPIC 2.2'), findsOneWidget);
    });

    testWidgets('chapter page shows chapter progress and a chapter test', (tester) async {
      await launchApp(tester, saved: {StudyProgressStore.statusKey: '{"cbse-12-ch03-t3.1": {"s": "completed"}}'});
      await scrollAndTap(tester, find.text('Class 12'));
      await scrollAndTap(tester, find.text('Chemical Kinetics'));
      expect(find.textContaining('1 of 5 topics studied'), findsWidgets);
      await tester.scrollUntilVisible(find.text('Chapter test'), 300, scrollable: find.byType(Scrollable).first);
      await tester.tap(find.text('Chapter test'));
      await tester.pumpAndSettle();
      expect(find.byType(PracticeSessionScreen), findsOneWidget);
      expect(find.textContaining('Question 1 of 15'), findsOneWidget);
    });
  });

  group('question bank', () {
    test('every topic and sub-topic of every exam chapter has at least 3 of its own questions', () {
      for (final level in [9, 10, 11, 12]) {
        for (final ch in cbse.classes[level]!.examChapters) {
          for (final t in ch.topics.expand((t) => t.selfAndDescendants)) {
            final own = cbse.questions.where((q) => q.topicId == t.id);
            expect(own.length, greaterThanOrEqualTo(3), reason: t.id);
          }
        }
      }
    });

    test('every original question is still there, unchanged in id, topic, type, marks, text and answer key', () {
      final original = jsonDecode(File('test/fixtures/original_question_ids.json').readAsStringSync()) as Map<String, Object?>;
      final byId = {for (final q in cbse.questions) q.id: q};
      expect(original, hasLength(313));
      for (final e in original.entries) {
        final q = byId[e.key];
        expect(q, isNotNull, reason: '${e.key} was removed');
        final want = e.value! as Map<String, Object?>;
        expect(q!.topicId, want['topicId'], reason: e.key);
        expect(q.correctOption, want['correctOption'], reason: e.key);
        expect(q.type.name, want['type'], reason: e.key);
        expect(q.marks, want['marks'], reason: e.key);
        expect(q.question.en, want['question'], reason: e.key);
      }
    });

    test('questions are well formed: answer, explanation, sensible difficulty and options', () {
      for (final q in cbse.questions) {
        expect(q.answer.en.trim(), isNotEmpty, reason: q.id);
        expect(q.explanation.en.trim(), isNotEmpty, reason: q.id);
        expect(q.answer.hi, isNotNull, reason: q.id);
        if (q.type == QuestionType.mcq || q.type == QuestionType.assertionReason) {
          expect(q.options, hasLength(4), reason: q.id);
          // Some original answers differ from the option only in case or a final full stop.
          String norm(String t) => t.toLowerCase().replaceAll(RegExp(r'[.\s]+$'), '');
          expect(norm(q.answer.en), contains(norm(q.options[q.correctOption!].en)), reason: '${q.id}: answer matches the key');
        }
        // Every numerical shows its working, in the answer or the explanation.
        if (q.type == QuestionType.numerical) {
          expect('${q.answer.en} ${q.explanation.en}', anyOf(contains('='), contains('÷'), contains('×')), reason: '${q.id}: shows working');
        }
      }
    });

    test('new questions are never labelled as previous-year questions', () {
      final pyqIds = {for (final p in cbse.pyqs) p.id};
      for (final q in cbse.questions.where((q) => q.id.startsWith('qt-'))) {
        expect(pyqIds, isNot(contains(q.id)));
        expect(q.sources.every((s) => s.sourceId.startsWith('ncert-') || s.sourceId.startsWith('cbse-sci') || s.sourceId.startsWith('cbse-chem')), isTrue, reason: q.id);
      }
      expect(cbse.questions.where((q) => q.id.startsWith('qt-')), hasLength(477)); // 476 + the 22-carat item moved to 3.5.1 in the audit
    });

    test('a chapter test mixes topics and never repeats a question', () {
      final pool = cbse.practiceQuestions(classLevel: 12, chapterId: 'cbse-12-ch02');
      final test = mixedTest(pool, size: 15, random: math.Random(7));
      expect(test, hasLength(15));
      expect({for (final q in test) q.id}, hasLength(15));
      expect({for (final q in test) q.topicId}.length, greaterThanOrEqualTo(8), reason: 'covers all 8 topics');
    });

    test('answers are recorded once each; accuracy and remaining are counted from records', () async {
      final s = await freshStore();
      s.recordAnswer('a', correct: false);
      s.recordAnswer('a', correct: true);
      s.recordAnswer('b', correct: true);
      final st = s.statsFor(['a', 'b', 'c']);
      expect((st.total, st.attempted, st.correctNow, st.remaining), (3, 2, 2, 1));
      expect(st.answers, 3);
      expect(st.accuracy, closeTo(2 / 3, 1e-9));
      expect(s.mistakeIds, isEmpty);
      expect(s.fixedMistakeIds, {'a'});
    });
  });

  group('practice session', () {
    testWidgets('check MCQ answers, self-mark written answers, retry the wrong ones, review', (tester) async {
      final prefs = await launchApp(tester, size: const Size(1080, 4000));
      final mcqs = cbse.questions.where((q) => q.type == QuestionType.mcq && q.topicId.startsWith('cbse-12-ch02-')).take(2).toList();
      final written = cbse.questions.firstWhere((q) => q.type == QuestionType.veryShort && q.topicId == 'cbse-12-ch02-t2.1');
      final qs = <PracticeQuestion>[...mcqs, written];
      tester.state<NavigatorState>(find.byType(Navigator).first).push(MaterialPageRoute<void>(
        builder: (_) => PracticeSessionScreen(title: 'Practice', questions: qs),
      ));
      await tester.pumpAndSettle();

      // Q1: pick a wrong option.
      final wrong = (mcqs[0].correctOption! + 1) % 4;
      await tester.tap(find.text(mcqs[0].options[wrong].en));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Check answer'));
      await tester.pumpAndSettle();
      expect(find.text('Not quite — the correct answer is marked.'), findsOneWidget);
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      // Q2: the right option.
      await tester.tap(find.text(mcqs[1].options[mcqs[1].correctOption!].en));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Check answer'));
      await tester.pumpAndSettle();
      expect(find.text('Correct!'), findsOneWidget);
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      // Q3: written — reveal, then mark honestly.
      await tester.tap(find.text('Show model answer'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('I got it right'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Finish'));
      await tester.pumpAndSettle();
      expect(find.text('2 of 3 correct'), findsOneWidget);

      final store = StudyProgressStore(prefs);
      expect(store.recordOf(mcqs[0].id)!.lastCorrect, isFalse);
      expect(store.recordOf(mcqs[1].id)!.lastCorrect, isTrue);
      expect(store.recordOf(written.id)!.attempts, 1);

      // Review does not record again.
      await tester.tap(find.text('Review answers'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Your answer'), findsOneWidget);
      expect(StudyProgressStore(prefs).recordOf(mcqs[0].id)!.attempts, 1);
      await tester.tap(find.text('Practice complete'));
      await tester.pumpAndSettle();

      // Retry only the wrong one, answer it right: the mistake is fixed.
      await tester.tap(find.textContaining('Retry wrong answers'));
      await tester.pumpAndSettle();
      expect(find.text('Question 1 of 1'), findsOneWidget);
      await tester.tap(find.text(mcqs[0].options[mcqs[0].correctOption!].en));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Check answer'));
      await tester.pumpAndSettle();
      final after = StudyProgressStore(prefs);
      expect(after.mistakeIds, isEmpty);
      expect(after.recordOf(mcqs[0].id)!.attempts, 2);
    });
  });

  group('revision', () {
    test('the plan gathers revise-again topics, mistakes, saved questions and formulas; ticks count as done', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final progress = StudyProgressStore(prefs);
      final bookmarks = BookmarkStore(prefs);
      final q1 = cbse.questions.firstWhere((q) => q.topicId == 'cbse-12-ch03-t3.1');
      final q2 = cbse.questions.lastWhere((q) => q.topicId == 'cbse-12-ch03-t3.1');
      final note = cbse.noteFor('cbse-12-ch03-t3.1')!;

      expect(RevisionPlan.build(cbse, progress, bookmarks).isEmpty, isTrue);
      progress.setStatus('cbse-12-ch03-t3.1', TopicStatus.reviseAgain);
      progress.recordAnswer(q1.id, correct: false);
      bookmarks.toggle(BookmarkStore.questionKey(q2.id));
      bookmarks.toggle(BookmarkStore.formulaKey(note.id, note.formulas.first));
      var plan = RevisionPlan.build(cbse, progress, bookmarks);
      expect((plan.topics.length, plan.mistakes.length, plan.savedQuestions.length, plan.savedFormulas.length), (1, 1, 1, 1));
      expect((plan.done, plan.total), (0, 4));

      progress.recordAnswer(q1.id, correct: true); // mistake fixed
      progress.toggleRevised('question:${q2.id}');
      plan = RevisionPlan.build(cbse, progress, bookmarks);
      expect(plan.mistakes, isEmpty);
      expect(plan.fixedMistakes.single.id, q1.id);
      expect((plan.done, plan.open), (2, 2));
    });

    test('weak topics: at least 3 answers with under 60% correct', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final progress = StudyProgressStore(prefs);
      final ids = [for (final q in cbse.practiceQuestions(classLevel: 11, topic: cbse.topic('cbse-11-ch05-t5.6')!.topic)) q.id];
      progress.recordAnswer(ids[0], correct: false);
      progress.recordAnswer(ids[1], correct: false);
      expect(RevisionPlan.build(cbse, progress, BookmarkStore(prefs)).weakTopics, isEmpty, reason: 'only 2 answers');
      progress.recordAnswer(ids[2], correct: true);
      final weak = RevisionPlan.build(cbse, progress, BookmarkStore(prefs)).weakTopics;
      expect(weak.single.$1.topic.id, 'cbse-11-ch05-t5.6');
    });

    testWidgets('Revision screen: empty state first, then items with practise buttons', (tester) async {
      final prefs = await launchApp(tester);
      tester.state<NavigatorState>(find.byType(Navigator).first).push(MaterialPageRoute<void>(builder: (_) => const RevisionScreen()));
      await tester.pumpAndSettle();
      expect(find.text('Nothing to revise yet'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      StudyProgressStore(prefs).recordAnswer(cbse.questions.first.id, correct: false);
      await tester.pumpWidget(const SizedBox());
      await launchAppWith(tester, prefs);
      tester.state<NavigatorState>(find.byType(Navigator).first).push(MaterialPageRoute<void>(builder: (_) => const RevisionScreen()));
      await tester.pumpAndSettle();
      expect(find.textContaining('Practise mistakes · 1'), findsOneWidget);
    });
  });

  test('old saved lab and focus records are still read after the update', () async {
    SharedPreferences.setMockInitialValues({
      PracticalAttemptStore.storageKey: [
        '{"v":1,"id":"1","startedAt":"2026-01-01T10:00:00.000","endedAt":"2026-01-01T10:05:00.000","classLevel":10,"chapterId":"cbse-10-ch02","topicId":"cbse-10-ch02-t2.1.4","practicalId":"acid_base_titration","correctActions":3,"wrongActions":0,"completions":1,"bestSteps":3,"totalSteps":3}',
      ],
      FocusSessionStore.storageKey: [
        '{"v":1,"id":"9","startedAt":"2026-01-01T10:00:00.000","endedAt":"2026-01-01T10:10:00.000","plannedSeconds":600,"focusedSeconds":600,"status":"completed","classLevel":10,"practicalId":"acid_base_titration","correctActions":3,"wrongActions":0,"practicalsCompleted":1,"stepsCompleted":3,"totalSteps":3}',
      ],
      BookmarkStore.storageKey: ['topic:cbse-10-ch02-t2.1', 'lab:cbse-10-ch02-t2.1.4:acid_base_titration'],
    });
    final prefs = await SharedPreferences.getInstance();
    expect(PracticalAttemptStore(prefs).all().single.boardId, 'cbse');
    expect(FocusSessionStore(prefs).all().single.focusedSeconds, 600);
    final b = BookmarkStore(prefs);
    expect(b.topicIds, ['cbse-10-ch02-t2.1']);
    expect(b.labs, [('cbse-10-ch02-t2.1.4', 'acid_base_titration')]);
    expect(b.questionIds, isEmpty);
    expect(b.formulas, isEmpty);
  });
}
