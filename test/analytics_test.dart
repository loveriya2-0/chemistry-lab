import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:virtual_chemistry_lab/analytics/progress_report.dart';
import 'package:virtual_chemistry_lab/content/content_catalog.dart';
import 'package:virtual_chemistry_lab/content/content_repository.dart';
import 'package:virtual_chemistry_lab/data/focus_session_store.dart';
import 'package:virtual_chemistry_lab/data/practical_attempt_store.dart';
import 'package:virtual_chemistry_lab/models/focus_session.dart';
import 'package:virtual_chemistry_lab/models/practical_attempt.dart';
import 'package:virtual_chemistry_lab/screens/analytics_screen.dart';

import 'test_helpers.dart';

late LoadedCurriculum _cbse;
final _now = DateTime(2026, 10, 5, 18);
DateTime _daysAgo(int d, {int hour = 17}) => DateTime(2026, 10, 5 - d, hour);

PracticalAttempt _attempt({
  required DateTime at,
  String practicalId = 'acid_base_titration',
  String chapterId = 'cbse-10-ch02',
  String topicId = 'cbse-10-ch02-t2.1.4',
  int classLevel = 10,
  int correct = 0,
  int wrong = 0,
  int completions = 0,
  int bestSteps = 0,
  int totalSteps = 5,
  String? focusSessionId,
}) =>
    PracticalAttempt(
      id: at.microsecondsSinceEpoch.toString(),
      startedAt: at.subtract(const Duration(minutes: 5)),
      endedAt: at,
      classLevel: classLevel,
      chapterId: chapterId,
      topicId: topicId,
      practicalId: practicalId,
      correctActions: correct,
      wrongActions: wrong,
      completions: completions,
      bestSteps: bestSteps,
      totalSteps: totalSteps,
      focusSessionId: focusSessionId,
    );

FocusSession _session({
  required String id,
  required DateTime at,
  int plannedSeconds = 600,
  int focusedSeconds = 600,
  FocusStatus status = FocusStatus.completed,
  String practicalId = 'acid_base_titration',
  String chapterId = 'cbse-10-ch02',
  String topicId = 'cbse-10-ch02-t2.1.4',
  int classLevel = 10,
  int correct = 0,
  int wrong = 0,
  int completed = 0,
  int steps = 0,
  int totalSteps = 5,
}) =>
    FocusSession(
      id: id,
      startedAt: at.subtract(Duration(seconds: focusedSeconds)),
      endedAt: at,
      plannedSeconds: plannedSeconds,
      focusedSeconds: focusedSeconds,
      status: status,
      classLevel: classLevel,
      chapterId: chapterId,
      topicId: topicId,
      practicalId: practicalId,
      correctActions: correct,
      wrongActions: wrong,
      practicalsCompleted: completed,
      stepsCompleted: steps,
      totalSteps: totalSteps,
    );

ProgressReport _report({
  List<PracticalAttempt> attempts = const [],
  List<FocusSession> sessions = const [],
  int classLevel = 10,
  DateTime? now,
}) =>
    ProgressReport.build(
      curriculum: _cbse,
      attempts: attempts,
      sessions: sessions,
      classLevel: classLevel,
      now: now ?? _now,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    _cbse = (await ContentCatalog.load(ContentRepository())).curriculum('cbse')!;
  });

  group('ProgressReport', () {
    test('no data: everything is zero and the empty state is used', () {
      final r = _report();
      expect(r.hasData, isFalse);
      expect(r.overallProgress, 0);
      // Class 10: 2 hand-built labs + 14 reaction labs on 10 topics of 4 chapters.
      expect((r.chaptersDone, r.chaptersTotal), (0, 4));
      expect((r.topicsDone, r.topicsTotal), (0, 10));
      expect((r.practicalsDone, r.practicalsTotal), (0, 16));
      expect(r.totalFocusSeconds, 0);
      expect(r.focusSessions, 0);
      expect(r.correctActions, 0);
      expect(r.wrongActions, 0);
      expect(r.accuracy, isNull);
      expect(r.attempts, 0);
      expect(r.streakDays, 0);
      expect(r.recent, isEmpty);
      expect(r.lastSevenDays, hasLength(7));
      expect(r.lastSevenDays.every((d) => d.total == 0), isTrue);
      expect(r.lastSevenDays.last.date, DateTime(2026, 10, 5));
    });

    // Titration completed today inside a 10-min focus session, oxygen
    // part-done yesterday without focus, an older 15-min session saved
    // before attempts existed (class 9, oxygen 2/3, still under a draft id
    // with no verified equivalent), and a 15-min session in which nothing
    // was poured.
    final s1 = _session(id: 's1', at: _daysAgo(0), correct: 5, wrong: 2, completed: 1, steps: 5);
    final s2 = _session(
      id: 's2',
      at: _daysAgo(3),
      plannedSeconds: 900,
      focusedSeconds: 400,
      status: FocusStatus.exited,
      practicalId: 'oxygen_preparation',
      chapterId: 'c9_matter_pure',
      topicId: 'c9_chemical_changes',
      classLevel: 9,
      correct: 2,
      steps: 2,
      totalSteps: 3,
    );
    final s3 = _session(
      id: 's3',
      at: _daysAgo(10),
      plannedSeconds: 900,
      focusedSeconds: 60,
      status: FocusStatus.exited,
    );
    final attempts = [
      _attempt(
        at: _daysAgo(0),
        correct: 5,
        wrong: 2,
        completions: 1,
        bestSteps: 5,
        focusSessionId: 's1',
      ),
      _attempt(
        at: _daysAgo(1),
        practicalId: 'oxygen_preparation',
        chapterId: 'cbse-10-ch01',
        topicId: 'cbse-10-ch01-t1.2.2',
        correct: 1,
        wrong: 1,
        bestSteps: 1,
        totalSteps: 3,
      ),
    ];

    test('actions and attempts count each lab visit once', () {
      final r = _report(attempts: attempts, sessions: [s1, s2, s3]);
      expect(r.hasData, isTrue);
      // s1 is covered by its attempt; s2 has no attempt; s3 had no pours.
      expect(r.attempts, 3);
      expect(r.correctActions, 5 + 1 + 2);
      expect(r.wrongActions, 2 + 1 + 0);
      expect(r.accuracy, closeTo(8 / 11, 1e-9));
      expect(r.completionRuns, 1);
    });

    test('focus time and 10 vs 15 minute split come from every session', () {
      final r = _report(attempts: attempts, sessions: [s1, s2, s3]);
      expect(r.focusSessions, 3);
      expect(r.totalFocusSeconds, 600 + 400 + 60);
      expect(r.focusSessionsFinished, 1);
      expect(r.tenMinuteSessions, 1);
      expect(r.fifteenMinuteSessions, 2);
    });

    test('class progress counts the labs placed in the verified syllabus', () {
      final r = _report(attempts: attempts, sessions: [s1, s2, s3]);
      // Titration done (1); oxygen best is 2/3 (from the class 9 session);
      // the 14 reaction labs not started.
      expect(r.overallProgress, closeTo((1 + 2 / 3) / 16, 1e-9));
      expect((r.practicalsDone, r.practicalsTotal), (1, 16));
      expect((r.topicsDone, r.topicsTotal), (1, 10));
      expect((r.chaptersDone, r.chaptersTotal), (0, 4));
      expect(r.chaptersWithoutLab, 0); // every Class 10 chemistry chapter now has a lab

      final reactions = r.chapters.firstWhere((c) => c.chapter.id == 'cbse-10-ch01');
      final acids = r.chapters.firstWhere((c) => c.chapter.id == 'cbse-10-ch02');
      expect([for (final t in reactions.topics) t.topic.number], ['1.2.1', '1.2.2', '1.2.3', '1.2.4']);
      expect([for (final t in acids.topics) t.topic.number], ['2.1.2', '2.1.3', '2.1.4']);
      final decomposition = reactions.topics.firstWhere((t) => t.topic.number == '1.2.2');
      final neutralisation = acids.topics.firstWhere((t) => t.topic.number == '2.1.4');
      // 7 labs in chapter 1 (oxygen + 6 reaction labs); 3 on §1.2.2.
      expect(reactions.progress, closeTo((2 / 3) / 7, 1e-9));
      expect(decomposition.progress, closeTo((2 / 3) / 3, 1e-9));
      expect(reactions.isComplete, isFalse);
      expect(decomposition.attempts, 1); // the class 9 one isn't this topic
      // 6 labs in chapter 2 (zinc + HCl added on §2.1.2); only the titration is done.
      expect(acids.progress, closeTo(1 / 6, 1e-9));
      expect(acids.isComplete, isFalse);
      expect(neutralisation.progress, 1);
      expect(neutralisation.practicalsDone, 1);

      // Class 9 has no interactive lab in the verified syllabus.
      final class9 = _report(attempts: attempts, sessions: [s1, s2, s3], classLevel: 9);
      expect(class9.hasLabs, isFalse);
      expect(class9.chapters, isEmpty);
      expect(class9.overallProgress, 0);
      // …but the old class 9 session still counts towards actions and time.
      expect(class9.correctActions, 8);
      expect(class9.totalFocusSeconds, 1060);
    });

    test('records of other boards are not mixed in', () {
      final other = PracticalAttempt(
        id: 'x', startedAt: _daysAgo(0), endedAt: _daysAgo(0), boardId: 'up', classLevel: 10,
        chapterId: 'up-10-ch01', topicId: 'up-10-t1', practicalId: 'acid_base_titration',
        correctActions: 9, wrongActions: 9, completions: 1, bestSteps: 5, totalSteps: 5,
      );
      final r = _report(attempts: [other]);
      expect(r.hasData, isFalse);
      expect(r.correctActions, 0);
      expect(r.practicalsDone, 0);
    });

    test('recent activity is newest first and links focus sessions', () {
      final r = _report(attempts: attempts, sessions: [s1, s2, s3]);
      expect(r.recent.map((e) => e.endedAt), [_daysAgo(0), _daysAgo(1), _daysAgo(3), _daysAgo(10)]);
      expect(r.recent[0].focus, same(s1));
      expect(r.recent[1].focus, isNull);
      expect(r.recent[2].focus, same(s2));
      expect(r.recent[3].focus, same(s3));
      expect(r.recent[3].correct + r.recent[3].wrong, 0);

      expect(_report(attempts: attempts, sessions: [s1, s2, s3]).recent, hasLength(4));
      expect(
        ProgressReport.build(
          curriculum: _cbse,
          attempts: attempts,
          sessions: [s1, s2, s3],
          classLevel: 10,
          now: _now,
          recentLimit: 2,
        ).recent,
        hasLength(2),
      );
    });

    test('last 7 days chart groups pours by local day', () {
      final r = _report(attempts: attempts, sessions: [s1, s2, s3]);
      final days = r.lastSevenDays;
      expect((days[6].correct, days[6].wrong), (5, 2)); // today
      expect((days[5].correct, days[5].wrong), (1, 1)); // yesterday
      expect((days[3].correct, days[3].wrong), (2, 0)); // 3 days ago
      expect(days[0].date, DateTime(2026, 9, 29));
      expect(days.fold(0, (sum, d) => sum + d.total), 11); // 10 days ago is outside
    });

    group('streak', () {
      int streak(List<int> daysAgo) => _report(attempts: [
            for (final d in daysAgo) _attempt(at: _daysAgo(d), correct: 1),
          ]).streakDays;

      test('counts consecutive days ending today', () => expect(streak([0, 1, 2]), 3));
      test('still counts when today has no practice yet', () => expect(streak([1, 2]), 2));
      test('breaks on a missed day', () => expect(streak([0, 2, 3]), 1));
      test('is 0 when the last activity was 2+ days ago', () => expect(streak([2, 3]), 0));
      test('several visits on one day count once', () => expect(streak([0, 0, 0]), 1));
      test('crosses a month boundary', () {
        final r = _report(
          attempts: [
            _attempt(at: DateTime(2026, 10, 1, 9), correct: 1),
            _attempt(at: DateTime(2026, 9, 30, 9), correct: 1),
          ],
          now: DateTime(2026, 10, 1, 20),
        );
        expect(r.streakDays, 2);
      });
    });
  });

  testWidgets('empty state when nothing has been saved', (tester) async {
    await launchApp(tester);
    await tester.tap(find.text('Progress'));
    await tester.pumpAndSettle();

    expect(find.text('No progress yet'), findsOneWidget);
    expect(find.text('Saved only on this device. No account needed.'), findsOneWidget);
    expect(find.text('Overall Chemistry Progress'), findsNothing);

    await tester.tap(find.text('Start practising'));
    await tester.pumpAndSettle();
    expect(find.text('Class 10'), findsOneWidget); // back on the home screen
  });

  testWidgets('a real lab visit is recorded and shown on the dashboard', (tester) async {
    final prefs = await launchApp(tester);
    await openTitrationSetup(tester);
    await tester.tap(find.text('Start without Focus Mode'));
    await pumpRoute(tester);

    // Wrong, correct, restart, correct → 2 correct, 1 wrong, best step 1.
    await pour(tester, 'HCl');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Try Again'));
    await tester.pump(const Duration(milliseconds: 400));
    await pour(tester, 'NaOH');
    await tester.tap(find.byTooltip('Reset experiment'));
    await tester.pump(const Duration(milliseconds: 400));
    await pour(tester, 'NaOH');

    // Leave the lab (guide, topic labs, topics, chapters) and go home.
    for (var i = 0; i < 5; i++) {
      await tester.binding.handlePopRoute();
      await tester.pump(const Duration(seconds: 1));
    }
    await tester.pumpAndSettle();

    final saved = PracticalAttemptStore(prefs).all().single;
    expect(saved.practicalId, 'acid_base_titration');
    expect(saved.boardId, 'cbse');
    expect(saved.chapterId, 'cbse-10-ch02');
    expect(saved.topicId, 'cbse-10-ch02-t2.1.4');
    expect((saved.correctActions, saved.wrongActions), (2, 1));
    expect((saved.bestSteps, saved.totalSteps, saved.completions), (1, 3, 0));
    expect(saved.classLevel, 10);
    expect(saved.listedPracticalId, isNull);
    expect(saved.focusSessionId, isNull);

    await tester.tap(find.text('Progress'));
    await tester.pumpAndSettle();
    expect(find.byType(AnalyticsScreen), findsOneWidget);
    expect(find.text('Overall Chemistry Progress'), findsOneWidget);
    // Titration 1/3 steps, the other 15 Class 10 labs untouched → 0.33 / 16.
    expect(find.text('2%'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('67%'), 300);
    expect(find.text('67%'), findsOneWidget); // accuracy 2 / 3
    expect(find.text('Chemical actions · last 7 days'), findsOneWidget);

    // Topic 2.1.4 (titration 1/3); the Acids chapter has 6 labs → 6%.
    await tester.scrollUntilVisible(find.text('33%'), 300);
    expect(find.text('33%'), findsOneWidget);
    expect(find.text('6%'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Recent activity'), 300);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('1 of 3 steps'), 300);
    expect(find.text('1 of 3 steps'), findsOneWidget);
  });

  testWidgets('focus visits link the attempt to its session', (tester) async {
    final prefs = await launchApp(tester);
    await openTitrationSetup(tester);
    await tester.tap(find.text('Start Focus Session · 10 min'));
    await pumpRoute(tester);
    await pour(tester, 'NaOH');

    await tester.tap(find.byTooltip('Exit Focus'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('Exit'));
    await tester.pumpAndSettle();

    final session = FocusSessionStore(prefs).all().single;
    final attempt = PracticalAttemptStore(prefs).all().single;
    expect(attempt.focusSessionId, session.id);
    expect(attempt.correctActions, session.correctActions);

    // Counted once on the dashboard even though both records exist.
    final r = _report(attempts: [attempt], sessions: [session], now: DateTime.now());
    expect(r.attempts, 1);
    expect(r.correctActions, 1);
  });

  testWidgets('a visit with no pours is not recorded', (tester) async {
    final prefs = await launchApp(tester);
    await openTitrationSetup(tester);
    await tester.tap(find.text('Start without Focus Mode'));
    await pumpRoute(tester);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(PracticalAttemptStore(prefs).all(), isEmpty);
  });

  testWidgets('dashboard is bilingual and fits a small phone (360×640)', (tester) async {
    final at = DateTime.now().subtract(const Duration(minutes: 30));
    await launchApp(tester, saved: {
      'app_language': 'hi',
      'practical_attempts': [
        jsonEncode(_attempt(at: at, correct: 5, wrong: 1, completions: 1, bestSteps: 5,
                focusSessionId: 'f1')
            .toJson()),
      ],
      'focus_sessions': [
        jsonEncode(_session(id: 'f1', at: at, plannedSeconds: 900, focusedSeconds: 900,
                correct: 5, wrong: 1, completed: 1, steps: 5)
            .toJson()),
      ],
    });
    tester.view.physicalSize = const Size(720, 1280);
    tester.view.devicePixelRatio = 2;
    await tester.pumpAndSettle();

    await tester.tap(find.text('प्रगति'));
    await tester.pumpAndSettle();
    expect(find.text('समग्र रसायन प्रगति'), findsOneWidget);
    expect(find.text('कक्षा 10'), findsWidgets); // chip + overall card
    await tester.scrollUntilVisible(find.text('83%'), 300);
    expect(find.text('83%'), findsOneWidget); // accuracy 5 / 6

    // Scroll the whole dashboard; any overflow fails the test.
    await tester.scrollUntilVisible(find.text('हाल की गतिविधि'), 300);
    await tester.scrollUntilVisible(find.text('फ़ोकस 15 मिनट · पूरा'), 300);
    expect(find.text('पूर्ण'), findsWidgets);
    await tester.scrollUntilVisible(
      find.text('केवल इस डिवाइस पर सहेजा गया। किसी खाते की आवश्यकता नहीं।'),
      300,
    );

    // Switching class updates the curriculum cards.
    // Back to the top, where the class chips are.
    await tester.drag(find.byType(ListView), const Offset(0, 5000));
    await tester.pumpAndSettle();
    await tester.tap(find.text('कक्षा 9'));
    await tester.pumpAndSettle();
    // Class 9 has no interactive lab yet: say so instead of a fake 0%.
    expect(find.text('कक्षा 9 के लिए अभी कोई इंटरैक्टिव लैब नहीं है।'), findsWidgets);
  });
}
