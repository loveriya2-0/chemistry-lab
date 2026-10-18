import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:virtual_chemistry_lab/content/legacy_migration.dart';
import 'package:virtual_chemistry_lab/data/focus_session_store.dart';
import 'package:virtual_chemistry_lab/data/practical_attempt_store.dart';
import 'package:virtual_chemistry_lab/screens/board_selection_screen.dart';
import 'package:virtual_chemistry_lab/screens/class_selection_screen.dart';
import 'package:virtual_chemistry_lab/screens/topic_list_screen.dart';
import 'package:virtual_chemistry_lab/state/app_state.dart';
import 'package:virtual_chemistry_lab/widgets/language_toggle.dart';

import 'test_helpers.dart';

/// A practical attempt as saved by the app before boards existed: no
/// boardId and draft curriculum ids.
String _legacyAttempt({required String chapterId, required String topicId, required String practicalId, int correct = 3}) =>
    jsonEncode({
      'v': 1, 'id': '$chapterId-$topicId', 'startedAt': '2026-10-04T10:00:00.000', 'endedAt': '2026-10-04T10:05:00.000',
      'classLevel': chapterId.startsWith('c9') ? 9 : 10, 'chapterId': chapterId, 'topicId': topicId, 'practicalId': practicalId,
      'correctActions': correct, 'wrongActions': 1, 'completions': 1, 'bestSteps': 5, 'totalSteps': 5, 'focusSessionId': null,
    });

void main() {
  group('board selection', () {
    testWidgets('first launch asks for a board; coming-soon boards open nothing', (tester) async {
      final prefs = await launchApp(tester, board: null, size: const Size(1080, 4000)); // every available board on screen
      expect(find.byType(BoardSelectionScreen), findsOneWidget);
      expect(find.text('Choose your board'), findsOneWidget);
      expect(find.text('CBSE'), findsOneWidget);
      expect(find.text('UP Board'), findsOneWidget);
      expect(find.text('Available'), findsNWidgets(7)); // seven available boards
      expect(find.text('Syllabus 2026-27'), findsNWidgets(7));

      await tester.scrollUntilVisible(find.text('Kerala Board'), 300);
      expect(find.text('Coming soon'), findsNWidgets(13));
      for (final name in ['ICSE / ISC (CISCE)', 'UP Board', 'Bihar Board', 'Tamil Nadu Board', 'Kerala Board']) {
        expect(find.text(name), findsOneWidget, reason: name);
      }

      // Tapping a coming-soon board does nothing: no chapters, no class screen.
      await tester.tap(find.text('Bihar Board'));
      await tester.pumpAndSettle();
      expect(find.byType(BoardSelectionScreen), findsOneWidget);
      expect(find.byType(ClassSelectionScreen), findsNothing);
      expect(prefs.getString(AppState.boardKey), isNull);

      await tester.drag(find.byType(ListView), const Offset(0, 3000));
      await tester.pumpAndSettle();
      await tester.tap(find.text('CBSE'));
      await tester.pumpAndSettle();
      expect(find.byType(ClassSelectionScreen), findsOneWidget);
      expect(prefs.getString(AppState.boardKey), 'cbse');
    });

    testWidgets('saved board opens class selection; board can be changed', (tester) async {
      await launchApp(tester);
      expect(find.byType(ClassSelectionScreen), findsOneWidget);
      expect(find.text('CBSE · Syllabus 2026-27 · Change board'), findsOneWidget);
      for (final c in [9, 10, 11, 12]) {
        expect(find.text('Class $c'), findsOneWidget);
      }
      expect(find.text('3 chapters'), findsOneWidget); // Class 9
      expect(find.text('10 chapters'), findsOneWidget); // Class 12

      await tester.tap(find.text('CBSE · Syllabus 2026-27 · Change board'));
      await tester.pumpAndSettle();
      expect(find.byType(BoardSelectionScreen), findsOneWidget);
      await tester.tap(find.text('CBSE'));
      await tester.pumpAndSettle();
      expect(find.byType(ClassSelectionScreen), findsOneWidget);
    });

    testWidgets('board selection is in Hindi too', (tester) async {
      await launchApp(tester, board: null, size: const Size(1080, 4000), saved: {'app_language': 'hi'});
      expect(find.text('अपना बोर्ड चुनें'), findsOneWidget);
      expect(find.text('उपलब्ध'), findsNWidgets(7));
      await tester.scrollUntilVisible(find.text('केरल बोर्ड'), 300);
      expect(find.text('जल्द आ रहा है'), findsNWidgets(13));
    });
  });

  group('verified CBSE syllabus in the app', () {
    testWidgets('class 9 shows the three verified chapters with their CBSE names', (tester) async {
      final prefs = await launchApp(tester);
      await tester.tap(find.text('Class 9'));
      await tester.pumpAndSettle();
      expect(prefs.getInt(AppState.classKey), 9);
      expect(find.text('Class 9 Chapters'), findsOneWidget);
      expect(find.text('Unit: 25 marks'), findsWidgets);
      for (final t in ['Exploring Mixtures and their Separation', 'Journey Inside the Atom', 'Atomic Foundations of Matter']) {
        await tester.scrollUntilVisible(find.text(t), 200);
        expect(find.text(t), findsOneWidget);
      }
      expect(find.text('Is Matter Around Us Pure?'), findsNothing); // old draft chapter is gone

      await scrollAndTap(tester, find.text('Journey Inside the Atom'));
      expect(find.byType(TopicListScreen), findsOneWidget);
      expect(find.text('Board syllabus name: Structure of an Atom'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Testing Thomson’s model: The gold foil experiment'.replaceAll('’', "'")), 200);
      expect(find.text('8.2.2'), findsOneWidget);
    });

    testWidgets('class 12 lists formative-only chapters separately', (tester) async {
      await launchApp(tester);
      await scrollAndTap(tester, find.text('Class 12'));
      await tester.scrollUntilVisible(find.text('Biomolecules'), 400);
      await tester.scrollUntilVisible(find.text('Also in the syllabus'), 300);
      expect(find.text('Also in the syllabus'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Surface Chemistry'), 300);
      expect(find.text('Not in year-end exam'), findsWidgets);

      await scrollAndTap(tester, find.text('Surface Chemistry'));
      expect(find.text('Taught in class but not assessed in the year-end exam.'), findsWidgets);
      expect(find.text('Open lab'), findsNothing);
    });

    testWidgets('topics, sub-topics and the board practical list load; Hindi switches', (tester) async {
      await launchApp(tester);
      await scrollAndTap(tester, find.text('Class 11'));
      await scrollAndTap(tester, find.text('Equilibrium'));
      expect(find.text('Chapter 6 Topics'), findsOneWidget);
      expect(find.text('7 marks'), findsWidgets);
      await tester.scrollUntilVisible(find.text('TOPIC 6.13'), 300);
      expect(find.text('Solubility Equilibria of Sparingly Soluble Salts'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Practicals in the syllabus'), 300);

      await tester.drag(find.byType(ListView), const Offset(0, 5000));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(LanguageToggle));
      await tester.pumpAndSettle();
      expect(find.text('अध्याय 6 के विषय'), findsOneWidget);
      expect(find.text('साम्यावस्था'), findsOneWidget);
      expect(find.text('भौतिक प्रक्रमों में साम्यावस्था'), findsOneWidget);
    });

    testWidgets('labs appear only where the syllabus places them', (tester) async {
      await launchApp(tester);
      await tester.tap(find.text('Class 10'));
      await tester.pumpAndSettle();
      await scrollAndTap(tester, find.text('Chemical Reactions and Equations'));
      // Labs on §1.2.1–1.2.4 (one per reaction type), none on 1.1 or 1.3.
      for (final n in ['1.2.1', '1.2.2', '1.2.3', '1.2.4']) {
        await tester.scrollUntilVisible(find.text(n), 200);
        expect(openLabOn(n), findsOneWidget, reason: n);
      }
      for (final n in ['1.1.1', '1.1.2', '1.2.5', '1.3.1', '1.3.2']) {
        await tester.scrollUntilVisible(find.text(n), 200);
        expect(openLabOn(n), findsNothing, reason: n);
      }
      await tester.drag(find.byType(ListView).first, const Offset(0, 3000));
      await tester.pumpAndSettle();
      await scrollAndTap(tester, openLabOn('1.2.2')); // Decomposition Reaction
      expect(find.text('Oxygen Gas Preparation'), findsOneWidget);
      expect(find.text('Heating ferrous sulphate crystals'), findsOneWidget);
      expect(find.text('Silver chloride in sunlight'), findsOneWidget);
      expect(find.text('Acid-Base Titration'), findsNothing);
      expect(find.text('Quicklime and water'), findsNothing);
    });
  });

  group('legacy progress migration', () {
    test('rewrites draft ids once, keeps everything, survives bad records', () async {
      SharedPreferences.setMockInitialValues({
        PracticalAttemptStore.storageKey: [
          _legacyAttempt(chapterId: 'c10_acids_bases', topicId: 'c10_neutralisation', practicalId: 'acid_base_titration'),
          _legacyAttempt(chapterId: 'c9_matter_pure', topicId: 'c9_chemical_changes', practicalId: 'oxygen_preparation'),
          'not json',
        ],
      });
      final prefs = await SharedPreferences.getInstance();
      final map = <String, String?>{'c10_acids_bases': 'cbse-10-ch02', 'c10_neutralisation': 'cbse-10-ch02-t2.1.4', 'c9_matter_pure': null};

      expect(await LegacyProgressMigration.run(prefs, map), 1);
      final raw = prefs.getStringList(PracticalAttemptStore.storageKey)!;
      expect(raw, hasLength(3));
      expect(raw.last, 'not json');
      final attempts = PracticalAttemptStore(prefs).all();
      expect(attempts.first.chapterId, 'cbse-10-ch02');
      expect(attempts.first.topicId, 'cbse-10-ch02-t2.1.4');
      expect(attempts.first.boardId, 'cbse'); // old records default to CBSE
      expect(attempts.last.chapterId, 'c9_matter_pure'); // no equivalent: kept, not deleted

      // Second run is a no-op.
      expect(await LegacyProgressMigration.run(prefs, map), 0);
    });

    testWidgets('old progress shows up under the verified chapter after upgrade', (tester) async {
      final prefs = await launchApp(tester, migrate: true, saved: {
        AppState.classKey: 10,
        PracticalAttemptStore.storageKey: [
          _legacyAttempt(chapterId: 'c10_acids_bases', topicId: 'c10_neutralisation', practicalId: 'acid_base_titration', correct: 5),
        ],
        FocusSessionStore.storageKey: <String>[],
      });
      expect(prefs.getBool(LegacyProgressMigration.doneKey), isTrue);
      expect(PracticalAttemptStore(prefs).all().single.topicId, 'cbse-10-ch02-t2.1.4');

      await tester.tap(find.text('Progress'));
      await tester.pumpAndSettle();
      expect(find.text('No progress yet'), findsNothing);
      await tester.scrollUntilVisible(find.text('2.1.4 How do Acids and Bases React with each other?'), 300);
      expect(find.text('Acids, Bases and Salts'), findsWidgets);
    });
  });

  group('layouts', () {
    Future<void> walk(WidgetTester tester, {required Size size, required double ratio, bool hindi = false}) async {
      await launchApp(tester, board: null, size: size, pixelRatio: ratio, saved: {if (hindi) 'app_language': 'hi'});
      await tester.drag(find.byType(ListView), const Offset(0, -3000)); // board list end
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView), const Offset(0, 3000));
      await tester.pumpAndSettle();
      await tester.tap(find.text(hindi ? 'सीबीएसई' : 'CBSE'));
      await tester.pumpAndSettle();
      await scrollAndTap(tester, find.text(hindi ? 'कक्षा 11' : 'Class 11'));
      final organic = hindi ? 'कार्बनिक रसायन : कुछ आधारभूत सिद्धांत तथा तकनीकें' : 'Organic Chemistry – Some Basic Principles and Techniques';
      await scrollAndTap(tester, find.text(organic));
      await tester.drag(find.byType(ListView), const Offset(0, -6000));
      await tester.pumpAndSettle();
      // Any RenderFlex overflow above fails the test.
    }

    testWidgets('small phone 320×568, English', (tester) => walk(tester, size: const Size(640, 1136), ratio: 2));
    testWidgets('small phone 320×568, Hindi', (tester) => walk(tester, size: const Size(640, 1136), ratio: 2, hindi: true));
    testWidgets('landscape phone 851×393', (tester) => walk(tester, size: const Size(2340, 1080), ratio: 2.75));
  });
}
