import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:virtual_chemistry_lab/content/content_catalog.dart';
import 'package:virtual_chemistry_lab/content/content_repository.dart';
import 'package:virtual_chemistry_lab/data/focus_session_store.dart';
import 'package:virtual_chemistry_lab/data/practicals_repository.dart';
import 'package:virtual_chemistry_lab/models/focus_session.dart';
import 'package:virtual_chemistry_lab/models/practical_path.dart';
import 'package:virtual_chemistry_lab/screens/focus_complete_screen.dart';
import 'package:virtual_chemistry_lab/state/focus_controller.dart';
import 'package:virtual_chemistry_lab/state/lab_controller.dart';
import 'package:virtual_chemistry_lab/widgets/focus_bar.dart';
import 'package:virtual_chemistry_lab/widgets/language_toggle.dart';

import 'test_helpers.dart';

late PracticalPath _path;

/// The titration lab where the verified CBSE syllabus offers it (§2.1.4).
PracticalPath _titrationPath() => _path;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final catalog = await ContentCatalog.load(ContentRepository());
    final loc = catalog.curriculum('cbse')!.topic('cbse-10-ch02-t2.1.4')!;
    _path = PracticalPath(
      boardId: 'cbse',
      classLevel: 10,
      chapter: loc.chapter,
      topic: loc.topic,
      practical: const PracticalsRepository().byId('acid_base_titration'),
    );
  });

  group('FocusController', () {
    test('tallies validated drops and freezes on finish', () {
      final path = _titrationPath();
      final times = [DateTime(2026, 10, 5, 9), DateTime(2026, 10, 5, 9, 10)];
      final focus = FocusController(
        path: path,
        duration: const Duration(minutes: 10),
        clock: () => times.removeAt(0),
      )..start();
      final lab = LabController(path.practical);

      focus
        ..recordDrop(lab.attemptAdd(Chemicals.hcl)) // wrong
        ..recordDrop(lab.attemptAdd(Chemicals.naoh)) // correct
        ..recordDrop(const IgnoredDrop());
      expect(focus.correctActions, 1);
      expect(focus.wrongActions, 1);

      final session = focus.finish(FocusStatus.exited, stepsCompleted: 1, totalSteps: 5);
      expect(session.startedAt, DateTime(2026, 10, 5, 9));
      expect(session.endedAt, DateTime(2026, 10, 5, 9, 10));
      expect(session.status, FocusStatus.exited);
      expect(session.chapterId, 'cbse-10-ch02');
      expect(session.topicId, 'cbse-10-ch02-t2.1.4');
      expect(session.practicalId, 'acid_base_titration');
      expect(session.classLevel, 10);
      expect(session.accuracy, 0.5);

      // Nothing changes after the session is over.
      focus.recordDrop(lab.attemptAdd(Chemicals.water));
      expect(focus.finish(FocusStatus.completed, stepsCompleted: 2, totalSteps: 5), same(session));
      focus.dispose();
    });

    test('clock format', () {
      expect(formatClock(const Duration(minutes: 15)), '15:00');
      expect(formatClock(const Duration(minutes: 9, seconds: 5)), '09:05');
      expect(formatClock(Duration.zero), '00:00');
    });
  });

  group('FocusSessionStore', () {
    final session = FocusSession(
      id: '1',
      startedAt: DateTime.utc(2026, 10, 5, 9),
      endedAt: DateTime.utc(2026, 10, 5, 9, 15),
      plannedSeconds: 900,
      focusedSeconds: 900,
      status: FocusStatus.completed,
      classLevel: 10,
      chapterId: 'cbse-10-ch02',
      topicId: 'cbse-10-ch02-t2.1.4',
      practicalId: 'acid_base_titration',
      correctActions: 7,
      wrongActions: 2,
      practicalsCompleted: 1,
      stepsCompleted: 2,
      totalSteps: 5,
    );

    test('round-trips every field and skips corrupt entries', () async {
      SharedPreferences.setMockInitialValues({
        'focus_sessions': ['not json'],
      });
      final store = FocusSessionStore(await SharedPreferences.getInstance());
      await store.add(session);

      final loaded = store.all().single;
      expect(loaded.toJson(), session.toJson());
      expect(loaded.status, FocusStatus.completed);
      expect(loaded.startedAt, session.startedAt);
    });
  });

  testWidgets('focus session: setup → countdown → time up → summary saved',
      (tester) async {
    final prefs = await launchApp(tester);
    await openTitrationSetup(tester);

    // Setup shows the full curriculum path and both durations.
    expect(find.text('Get ready to focus'), findsOneWidget);
    expect(find.text('CBSE · Class 10'), findsOneWidget);
    expect(find.text('2. Acids, Bases and Salts'), findsOneWidget);
    expect(find.text('2.1.4 How do Acids and Bases React with each other?'), findsOneWidget);
    expect(find.text('Acid-Base Titration'), findsOneWidget);
    await tester.tap(find.text('15 min'));
    await tester.pumpAndSettle();
    expect(find.text('Start Focus Session · 15 min'), findsOneWidget);

    // Setup is bilingual.
    await tester.tap(find.byType(LanguageToggle));
    await tester.pumpAndSettle();
    expect(find.text('सत्र की अवधि'), findsOneWidget);
    expect(find.text('फ़ोकस सत्र प्रारंभ करें · 15 मिनट'), findsOneWidget);
    await tester.tap(find.byType(LanguageToggle));
    await tester.pumpAndSettle();

    await tester.tap(find.text('10 min'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start Focus Session · 10 min'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(FocusBar), findsOneWidget);
    expect(find.text('10:00'), findsOneWidget);
    expect(find.text('Class 10 · Ch 2 · Topic 2.1.4'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('09:59'), findsOneWidget);

    // One wrong and one correct pour; validation is the lab's as always.
    await pour(tester, 'HCl');
    expect(find.text('Smart Warning'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 400)); // let the dialog open
    await tester.tap(find.text('Try Again'));
    await tester.pump(const Duration(milliseconds: 400));
    await pour(tester, 'NaOH');
    expect(find.text('STEP 2 OF 3'), findsOneWidget);

    // Let the clock run out.
    await tester.pump(const Duration(minutes: 10));
    await tester.pumpAndSettle();
    expect(find.byType(FocusCompleteScreen), findsOneWidget);
    expect(find.text('Focus Session Complete!'), findsOneWidget);
    expect(find.text('You stayed focused for 10 minutes.'), findsOneWidget);
    expect(find.text('50%'), findsOneWidget);
    expect(find.text('1 of 3 steps'), findsOneWidget);

    final saved = FocusSessionStore(prefs).all().single;
    expect(saved.status, FocusStatus.completed);
    expect(saved.plannedSeconds, 600);
    expect(saved.focusedSeconds, 600);
    expect(saved.correctActions, 1);
    expect(saved.wrongActions, 1);
    expect(saved.practicalsCompleted, 0);
    expect(saved.stepsCompleted, 1);
    expect(saved.totalSteps, 3);
    expect(saved.practicalId, 'acid_base_titration');
    expect(saved.topicId, 'cbse-10-ch02-t2.1.4');

    await tester.tap(find.text('Back to Practicals'));
    await tester.pumpAndSettle();
    expect(find.text('Acid-Base Titration'), findsOneWidget);
    expect(find.text('Start virtual lab'), findsOneWidget); // back on the guide
  });

  testWidgets('pause freezes the timer; Exit Focus confirms and saves as exited',
      (tester) async {
    final prefs = await launchApp(tester);
    await openTitrationSetup(tester);
    await tester.tap(find.text('Start Focus Session · 10 min'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('09:59'), findsOneWidget);

    await tester.tap(find.byTooltip('Pause'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Your timer is on hold. Take a breath and resume when ready.'),
        findsOneWidget);
    expect(find.text('0 of 3 steps'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    expect(find.text('09:59'), findsWidgets);

    await tester.tap(find.text('Resume'));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('09:58'), findsOneWidget);

    // Exit → Keep Focusing: timer is held while asking, then resumes.
    await tester.tap(find.byTooltip('Exit Focus'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Exit Focus Mode?'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    // The paused overlay behind the dialog shows the clock too.
    expect(find.text('09:58'), findsWidgets);
    await tester.tap(find.text('Keep Focusing'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('09:57'), findsOneWidget);

    // Android Back also asks first; Exit leaves and records the session.
    await tester.binding.handlePopRoute();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Exit Focus Mode?'), findsOneWidget);
    await tester.tap(find.text('Exit'));
    await tester.pumpAndSettle();
    expect(find.text('Acid-Base Titration'), findsOneWidget);
    expect(find.text('Start virtual lab'), findsOneWidget); // back on the guide

    final saved = FocusSessionStore(prefs).all().single;
    expect(saved.status, FocusStatus.exited);
    expect(saved.focusedSeconds, 3);
    expect(saved.correctActions, 0);
    expect(saved.wrongActions, 0);
  });

  testWidgets('finishing the practical during focus records the completion',
      (tester) async {
    final prefs = await launchApp(tester);
    await openTitrationSetup(tester);
    await tester.tap(find.text('Start Focus Session · 10 min'));
    await pumpRoute(tester);

    await completeTitration(tester);
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Practical Complete!'), findsOneWidget);

    await tester.tap(find.text('Back to Practicals'));
    await tester.pumpAndSettle();
    expect(find.text('Start virtual lab'), findsOneWidget); // back on the guide

    final saved = FocusSessionStore(prefs).all().single;
    expect(saved.status, FocusStatus.exited);
    // Three finished steps; burette portions are not separate actions.
    expect(saved.correctActions, 3);
    expect(saved.wrongActions, 0);
    expect(saved.practicalsCompleted, 1);
    expect(saved.stepsCompleted, 3);
  });

  testWidgets('focus screens fit a small phone (360×640) in Hindi', (tester) async {
    await launchApp(tester);
    tester.view.physicalSize = const Size(720, 1280);
    tester.view.devicePixelRatio = 2;
    await tester.tap(find.byType(LanguageToggle));
    await tester.pumpAndSettle();

    await scrollAndTap(tester, find.text('कक्षा 10'));
    await scrollAndTap(tester, find.text('अम्ल, क्षारक एवं लवण'));
    await scrollAndTap(tester, openLabOn('2.1.4', openLab: 'लैब खोलें'));
    await tester.tap(find.text('प्रयोग देखें'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('वर्चुअल लैब शुरू करें'));
    await tester.pumpAndSettle();
    expect(find.text('एकाग्र होने के लिए तैयार हो जाइए'), findsOneWidget);

    await tester.tap(find.text('फ़ोकस सत्र प्रारंभ करें · 10 मिनट'));
    await pumpRoute(tester);
    expect(find.text('कक्षा 10 · अध्याय 2 · विषय 2.1.4'), findsOneWidget);

    await tester.tap(find.byTooltip('रोकें'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('3 में से 0 चरण पूर्ण'), findsOneWidget);
    await tester.tap(find.text('जारी रखें'));
    await tester.pump(const Duration(minutes: 10));
    await tester.pumpAndSettle();
    expect(find.text('फ़ोकस सत्र पूर्ण हुआ!'), findsOneWidget);
    // Any RenderFlex overflow above would already have failed the test.
  });
}
