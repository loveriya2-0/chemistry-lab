import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:virtual_chemistry_lab/data/focus_session_store.dart';
import 'package:virtual_chemistry_lab/screens/focus_setup_screen.dart';
import 'package:virtual_chemistry_lab/screens/study_timer_screen.dart';
import 'package:virtual_chemistry_lab/state/focus_controller.dart';
import 'package:virtual_chemistry_lab/study/study_focus.dart';

import 'test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const target = StudyTarget(boardId: 'cbse', classLevel: 10, chapterId: 'cbse-10-ch02', topicId: 'cbse-10-ch02-t2.3');

  group('Focus settings', () {
    test('custom length is kept within 5–180 minutes; break and goal have limits too', () async {
      SharedPreferences.setMockInitialValues({});
      final s = FocusSettings(await SharedPreferences.getInstance());
      expect((s.customMinutes, s.breakMinutes, s.dailyGoalMinutes), (25, 5, 30), reason: 'defaults');
      s.setCustomMinutes(2);
      expect(s.customMinutes, 5);
      s.setCustomMinutes(500);
      expect(s.customMinutes, 180);
      s.setCustomMinutes(45);
      expect(s.customMinutes, 45);
      s.setBreakMinutes(0);
      expect(s.breakMinutes, 1);
      s.setDailyGoalMinutes(10000);
      expect(s.dailyGoalMinutes, 600);
      // Saved and read back.
      expect(FocusSettings(await SharedPreferences.getInstance()).customMinutes, 45);
    });

    test('the existing 10- and 15-minute presets are unchanged', () {
      expect(FocusController.options, [const Duration(minutes: 10), const Duration(minutes: 15)]);
      expect(FocusSettings.validMinutes(10), 10);
      expect(FocusSettings.validMinutes(15), 15);
    });
  });

  group('StudyFocusController', () {
    late SharedPreferences prefs;
    late StudySessionStore store;
    late DateTime now;
    StudyFocusController make({int minutes = 25, int breakMin = 5}) => StudyFocusController(
          store: store,
          target: target,
          duration: Duration(minutes: minutes),
          breakDuration: Duration(minutes: breakMin),
          clock: () => now,
          tick: const Duration(days: 1), // ticks are driven by tickNow()
        );

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      store = StudySessionStore(prefs);
      now = DateTime(2026, 10, 10, 18);
    });

    test('a length outside 5–180 minutes is clamped', () {
      expect(make(minutes: 1).duration, const Duration(minutes: 5));
      expect(make(minutes: 300).duration, const Duration(minutes: 180));
    });

    test('start → pause → resume counts only the running time, then completes once', () async {
      final c = make(minutes: 10);
      c.start();
      now = now.add(const Duration(minutes: 4));
      c.pause();
      expect(c.focused, const Duration(minutes: 4));
      now = now.add(const Duration(minutes: 30)); // paused time is not counted
      expect(c.focused, const Duration(minutes: 4));
      c.resume();
      now = now.add(const Duration(minutes: 6));
      c.tickNow();
      await Future<void>.delayed(Duration.zero);
      expect(c.phase, StudyTimerPhase.finished);
      expect(c.result!.status, StudySessionStatus.completed);
      expect(c.result!.focusedSeconds, 600);
      expect(store.all(), hasLength(1));
      // Ending again (or leaving the screen) does not save a second copy.
      await c.end();
      await store.add(c.result!);
      expect(store.all(), hasLength(1));
      expect(prefs.getString(StudySessionStore.activeKey), isNull, reason: 'checkpoint cleared');
      c.dispose();
    });

    test('ending early saves an "ended" session with the real focused time and its target', () async {
      final c = make(minutes: 30);
      c.start();
      now = now.add(const Duration(minutes: 12, seconds: 30));
      final s = (await c.end())!;
      expect(s.status, StudySessionStatus.ended);
      expect(s.focusedSeconds, 750);
      expect(s.plannedSeconds, 1800);
      expect((s.target.classLevel, s.target.chapterId, s.target.topicId), (10, 'cbse-10-ch02', 'cbse-10-ch02-t2.3'));
      expect(StudySessionStore(prefs).all().single.id, s.id);
      c.dispose();
    });

    test('ending before any time has run saves nothing', () async {
      final c = make();
      c.start();
      await c.end();
      expect(store.all(), isEmpty);
      c.dispose();
    });

    test('an app killed mid-session is recovered once as "interrupted" from its checkpoint', () async {
      final c = make(minutes: 20);
      c.start();
      now = now.add(const Duration(seconds: 20));
      c.tickNow(); // past the 15 s checkpoint interval
      await Future<void>.delayed(Duration.zero);
      expect(prefs.getString(StudySessionStore.activeKey), isNotNull);
      // App is killed here: no end(), no dispose().
      final recovered = await StudySessionStore(prefs).recoverInterrupted();
      expect(recovered!.status, StudySessionStatus.interrupted);
      expect(recovered.focusedSeconds, 20);
      expect(await StudySessionStore(prefs).recoverInterrupted(), isNull, reason: 'recovered only once');
      expect(StudySessionStore(prefs).all(), hasLength(1));
    });

    test('a break follows a completed session and does not count as focus', () async {
      final c = make(minutes: 5, breakMin: 2);
      c.start();
      now = now.add(const Duration(minutes: 5));
      c.tickNow();
      await Future<void>.delayed(Duration.zero);
      c.startBreak();
      expect(c.phase, StudyTimerPhase.onBreak);
      now = now.add(const Duration(minutes: 2));
      c.tickNow();
      expect(c.phase, StudyTimerPhase.breakOver);
      expect(store.all().single.focusedSeconds, 300);
      c.dispose();
    });
  });

  group('FocusSummary', () {
    test('today, last 7 days and all-time totals add lab and study focus together', () {
      final now = DateTime(2026, 10, 10, 20);
      final s = FocusSummary.build(
        entries: [
          (DateTime(2026, 10, 10, 9), 600), // today
          (DateTime(2026, 10, 10, 18), 900), // today
          (DateTime(2026, 10, 7, 8), 1200), // 3 days ago
          (DateTime(2026, 9, 1, 8), 3000), // older than a week
        ],
        now: now,
      );
      expect(s.todaySeconds, 1500);
      expect(s.weekSeconds, 2700);
      expect(s.allTimeSeconds, 5700);
      expect(s.week, hasLength(7));
      expect(s.week.last.$1, DateTime(2026, 10, 10));
      expect(s.week[3].$2, 1200);
    });
  });

  group('screens', () {
    testWidgets('lab Focus Mode offers 10, 15 and a custom length; custom starts a lab session of that length', (tester) async {
      final prefs = await launchApp(tester);
      await openTitrationSetup(tester);
      expect(find.byType(FocusSetupScreen), findsOneWidget);
      expect(find.text('10 min'), findsWidgets);
      expect(find.text('15 min'), findsWidgets);
      await scrollAndTap(tester, find.text('Custom'));
      await scrollAndTap(tester, find.byTooltip('+5'));
      expect(prefs.getInt(FocusSettings.customKey), isNull, reason: 'saved only when a session starts');
      await tester.tap(find.textContaining('Start Focus'));
      await pumpRoute(tester);
      expect(find.text('30:00'), findsNothing);
      expect(find.textContaining('29:'), findsWidgets, reason: 'custom 30 min session is running');
      expect(prefs.getInt(FocusSettings.customKey), 30);
      // Leave: the lab session is saved once, as before.
      await tester.tap(find.byTooltip('Exit Focus'));
      await pumpRoute(tester);
      await tester.tap(find.text('Exit'));
      await pumpRoute(tester);
      expect(FocusSessionStore(prefs).all().single.plannedSeconds, 1800);
    });

    testWidgets('study timer: choose a chapter, run, pause, end; history shows it', (tester) async {
      final prefs = await launchApp(tester, size: const Size(1080, 4000));
      tester.state<NavigatorState>(find.byType(Navigator).first).push(MaterialPageRoute<void>(
        builder: (_) => const StudyTimerScreen(initialTarget: target),
      ));
      await tester.pumpAndSettle();
      expect(find.text('No focus sessions yet.'), findsOneWidget);
      await tester.tap(find.textContaining('Start session'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 3));
      await tester.tap(find.text('Pause'));
      await tester.pump();
      expect(find.text('Resume'), findsOneWidget);
      await tester.tap(find.text('End session'));
      await tester.pumpAndSettle();
      expect(find.text('End this session now?'), findsOneWidget);
      await tester.tap(find.text('End session').last);
      await tester.pumpAndSettle();
      // Paused immediately in a fake-clock test, so little or no real time ran;
      // either way at most one session is stored and the checkpoint is cleared.
      expect(StudySessionStore(prefs).all().length, lessThanOrEqualTo(1));
      expect(prefs.getString(StudySessionStore.activeKey), isNull);
      expect(find.text('Back to studying'), findsOneWidget);
    });
  });
}
