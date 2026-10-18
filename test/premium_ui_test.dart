import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:virtual_chemistry_lab/content/content_text.dart';
import 'package:virtual_chemistry_lab/content/models/concept.dart';
import 'package:virtual_chemistry_lab/content/models/pyq.dart';
import 'package:virtual_chemistry_lab/content/models/review.dart';
import 'package:virtual_chemistry_lab/data/bookmark_store.dart';
import 'package:virtual_chemistry_lab/data/practical_attempt_store.dart';
import 'package:virtual_chemistry_lab/screens/analytics_screen.dart';
import 'package:virtual_chemistry_lab/screens/bookmarks_screen.dart';
import 'package:virtual_chemistry_lab/screens/concept_screen.dart';
import 'package:virtual_chemistry_lab/screens/exam_zone_screen.dart';
import 'package:virtual_chemistry_lab/screens/focus_setup_screen.dart';
import 'package:virtual_chemistry_lab/screens/lab_list_screen.dart';
import 'package:virtual_chemistry_lab/screens/practical_dashboard_screen.dart';
import 'package:virtual_chemistry_lab/screens/practical_guide_screen.dart';
import 'package:virtual_chemistry_lab/screens/pyq_screens.dart';
import 'package:virtual_chemistry_lab/screens/search_screen.dart';
import 'package:virtual_chemistry_lab/screens/settings_screen.dart';
import 'package:virtual_chemistry_lab/screens/topic_detail_screen.dart';
import 'package:virtual_chemistry_lab/state/app_state.dart';

import 'test_helpers.dart';

Future<void> _tab(WidgetTester tester, String label) async {
  await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text(label)));
  await tester.pumpAndSettle();
}

Future<void> _back(WidgetTester tester) async {
  await tester.binding.handlePopRoute();
  await tester.pumpAndSettle();
}

void main() {
  group('bottom navigation', () {
    testWidgets('every tab opens its screen and Home keeps the class tiles', (tester) async {
      await launchApp(tester);
      expect(find.byType(NavigationBar), findsOneWidget);
      for (final c in ['Class 9', 'Class 10', 'Class 11', 'Class 12']) {
        expect(find.text(c), findsOneWidget);
      }
      expect(find.text('Start your first lab'), findsOneWidget); // nothing saved yet

      await _tab(tester, 'Learn');
      expect(find.text('Class 9 Chapters'), findsOneWidget);
      await _tab(tester, 'Lab');
      expect(find.byType(LabListScreen), findsOneWidget);
      await _tab(tester, 'Exam');
      expect(find.byType(ExamZoneScreen), findsOneWidget);
      await _tab(tester, 'Progress');
      expect(find.byType(AnalyticsScreen), findsOneWidget);
      await tester.tap(find.text('Start practising'));
      await tester.pumpAndSettle();
      expect(find.text('Class 10'), findsOneWidget); // back on Home
    });

    testWidgets('Hindi labels in the bar and on Home', (tester) async {
      await launchApp(tester, saved: {'app_language': 'hi'});
      for (final l in ['होम', 'पढ़ाई', 'लैब', 'परीक्षा', 'प्रगति']) {
        expect(find.descendant(of: find.byType(NavigationBar), matching: find.text(l)), findsOneWidget);
      }
      expect(find.text('अपनी कक्षा चुनें'), findsOneWidget);
      expect(find.text('कक्षा 12'), findsOneWidget);
    });

    testWidgets('Continue learning resumes the last real lab visit', (tester) async {
      await launchApp(tester);
      await openTitrationSetup(tester);
      await tester.tap(find.text('Start without Focus Mode'));
      await pumpRoute(tester);
      await pour(tester, 'NaOH'); // a visit is saved once something happens
      // Lab, guide, topic labs, topics, chapters.
      for (var i = 0; i < 5; i++) {
        await tester.binding.handlePopRoute();
        await tester.pump(const Duration(seconds: 1));
      }
      await tester.pumpAndSettle();
      expect(find.text('Acid-Base Titration'), findsOneWidget);
      await scrollAndTap(tester, find.text('Resume'));
      await tester.pumpAndSettle();
      expect(find.byType(PracticalDashboardScreen), findsOneWidget);
    });
  });

  group('search', () {
    testWidgets('finds verified topics in English and Hindi and opens them', (tester) async {
      await launchApp(tester);
      await tester.tap(find.byTooltip('Search'));
      await tester.pumpAndSettle();
      expect(find.text('Search works in English and Hindi.'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'sparingly soluble');
      await tester.pumpAndSettle();
      expect(find.text('Solubility Equilibria of Sparingly Soluble Salts'), findsOneWidget);
      await tester.tap(find.text('Solubility Equilibria of Sparingly Soluble Salts'));
      await tester.pumpAndSettle();
      expect(find.byType(TopicDetailScreen), findsOneWidget);
      await _back(tester);

      await tester.enterText(find.byType(TextField), 'साम्यावस्था');
      await tester.pumpAndSettle();
      expect(find.text('Equilibrium'), findsWidgets); // Hindi query, English UI

      await tester.enterText(find.byType(TextField), 'zzqx');
      await tester.pumpAndSettle();
      expect(find.text('No results for "zzqx"'), findsOneWidget);
    });

    testWidgets('labs are searchable and open their practical', (tester) async {
      await launchApp(tester);
      await tester.tap(find.byTooltip('Search'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'titration');
      await tester.pumpAndSettle();
      // The Class 11 labs sit on no topic, so they are found by their practical
      // (NaOH–oxalic acid and HCl–sodium carbonate, both parts of practical E).
      expect(find.text('Titration: NaOH against Oxalic Acid'), findsOneWidget);
      expect(find.text('Titration: HCl against Sodium Carbonate'), findsOneWidget);
      expect(find.text('Class 11 · Practical E'), findsNWidgets(2));
      await tester.tap(find.text('Acid-Base Titration'));
      await tester.pumpAndSettle();
      expect(find.byType(PracticalGuideScreen), findsOneWidget);
    });
  });

  group('topic, bookmarks and empty states', () {
    testWidgets('topic shows its notes and can be bookmarked', (tester) async {
      final prefs = await launchApp(tester);
      await tester.tap(find.text('Class 10'));
      await tester.pumpAndSettle();
      await scrollAndTap(tester, find.text('Acids, Bases and Salts'));
      await scrollAndTap(tester, find.text('TOPIC 2.1'));
      expect(find.byType(TopicDetailScreen), findsOneWidget);
      await tester.scrollUntilVisible(find.textContaining('Acids are sour and turn blue litmus red'), 200, scrollable: find.byType(Scrollable).first);
      expect(find.textContaining('not in the app yet'), findsNothing);
      expect(find.textContaining('Awaiting review by a subject teacher'), findsWidgets);
      await tester.scrollUntilVisible(find.text('Practice questions · 21'), 300, scrollable: find.byType(Scrollable).first);

      await tester.tap(find.byTooltip('Bookmark'));
      await tester.pumpAndSettle();
      expect(prefs.getStringList(BookmarkStore.storageKey), ['topic:cbse-10-ch02-t2.1']);

      for (var i = 0; i < 3; i++) {
        await _back(tester);
      }
      await scrollAndTap(tester, find.text('Bookmarks'));
      expect(find.byType(BookmarksScreen), findsOneWidget);
      expect(find.byType(ListTile), findsOneWidget);
      await tester.tap(find.text('PYQs'));
      await tester.pumpAndSettle();
      expect(find.text('No questions added yet'), findsOneWidget);
    });

    testWidgets('lab list: placed labs open (guided labs via their guide), other practicals say guide coming soon', (tester) async {
      await launchApp(tester, saved: {AppState.classKey: 10});
      await _tab(tester, 'Lab');
      // Syllabus order: §1.2.1 quicklime, then the §1.2.2 labs.
      expect(find.text('Quicklime and water'), findsOneWidget);
      expect(find.text('Oxygen Gas Preparation'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Acid-Base Titration'), 300, scrollable: find.byType(Scrollable).first);
      expect(find.text('Acid-Base Titration'), findsOneWidget);
      await tester.drag(find.byType(ListView), const Offset(0, -8000));
      await tester.pumpAndSettle();
      expect(find.text('Guide coming soon'), findsWidgets);

      await tester.drag(find.byType(ListView), const Offset(0, 8000));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Oxygen Gas Preparation'));
      await tester.pumpAndSettle();
      expect(find.byType(PracticalGuideScreen), findsOneWidget);
      await _back(tester);

      // Reaction labs have guides too.
      await tester.tap(find.text('Quicklime and water'));
      await tester.pumpAndSettle();
      expect(find.byType(PracticalGuideScreen), findsOneWidget);
    });

    testWidgets('exam zone: Class 10 and Class 12 PYQs from entered papers', (tester) async {
      await launchApp(tester, saved: {AppState.classKey: 10});
      await _tab(tester, 'Exam');
      expect(find.text('Official papers, 2022–2026'), findsOneWidget);
      expect(find.text('52 questions'), findsOneWidget);
      expect(find.textContaining('Based on the 4 official papers entered so far'), findsOneWidget);
      expect(find.text('No questions added yet'), findsNothing);
      await scrollAndTap(tester, find.text('Year-wise'));
      await tester.tap(find.text('2024'));
      await tester.pumpAndSettle();
      expect(find.byType(PyqListScreen), findsOneWidget);
      expect(find.text('13 questions'), findsOneWidget);
      await _back(tester);
      await _back(tester);
      await scrollAndTap(tester, find.text('Start practice mode'));
      expect(find.text('Practice questions will appear here once PYQs are added.'), findsNothing);
      expect(find.text('Question 1 of 52'), findsOneWidget);
      await _back(tester);
      await tester.drag(find.byType(Scrollable).first, const Offset(0, 4000));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Class 12'));
      await tester.pumpAndSettle();
      expect(find.text('No questions added yet'), findsNothing);
      await tester.scrollUntilVisible(find.text('134 questions'), -300, scrollable: find.byType(Scrollable).first);
      // The basis counts this class's own papers, not every class's.
      expect(find.textContaining('Based on the 4 official papers entered so far'), findsOneWidget);
      await tester.tap(find.text('Class 10'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Chapter weightage'), 300, scrollable: find.byType(Scrollable).first);
      expect(find.text('25 marks'), findsWidgets); // verified unit marks
      await tester.scrollUntilVisible(find.textContaining('optional second board exam'), 300, scrollable: find.byType(Scrollable).first);
    });

    testWidgets('class 9 has no board exam, so exam zone shows class 12', (tester) async {
      await launchApp(tester, saved: {AppState.classKey: 9});
      await _tab(tester, 'Exam');
      expect(find.text('CLASS 12 · CHEMISTRY'), findsOneWidget);
    });
  });

  group('settings', () {
    testWidgets('language, default focus length and reset progress', (tester) async {
      final prefs = await launchApp(tester, saved: {
        PracticalAttemptStore.storageKey: <String>['{}'],
        BookmarkStore.storageKey: ['topic:cbse-10-ch02-t2.1'],
      });
      await tester.tap(find.byTooltip('Settings'));
      await tester.pumpAndSettle();
      expect(find.byType(SettingsScreen), findsOneWidget);

      await tester.tap(find.text('15 min'));
      await tester.pumpAndSettle();
      expect(prefs.getInt(AppState.focusKey), 15);

      await scrollAndTap(tester, find.text('Reset progress'));
      expect(find.text('Reset all progress?'), findsOneWidget);
      await tester.tap(find.text('Reset'));
      await tester.pumpAndSettle();
      expect(prefs.getStringList(PracticalAttemptStore.storageKey), isNull);
      expect(prefs.getStringList(BookmarkStore.storageKey), isNull);

      await tester.drag(find.byType(ListView), const Offset(0, 5000));
      await tester.pumpAndSettle();
      await tester.tap(find.text('हिंदी'));
      await tester.pumpAndSettle();
      expect(find.text('सेटिंग्स'), findsOneWidget);

      // Focus setup now starts on 15 minutes.
      await _back(tester);
      await tester.tap(find.text('कक्षा 10'));
      await tester.pumpAndSettle();
      await scrollAndTap(tester, find.text('अम्ल, क्षारक एवं लवण'));
      await scrollAndTap(tester, openLabOn('2.1.4', openLab: 'लैब खोलें'));
      await tester.tap(find.text('प्रयोग देखें'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('वर्चुअल लैब शुरू करें'));
      await tester.pumpAndSettle();
      expect(find.byType(FocusSetupScreen), findsOneWidget);
      expect(find.textContaining('15 मिनट'), findsWidgets);
    });
  });

  group('concept and PYQ screens render reviewed data (test fixtures only)', () {
    // Not shipped content: these fixtures only check how the screens would
    // present reviewed data once it exists.
    const concept = Concept(
      id: 'fixture',
      type: ConceptType.concept,
      title: ContentText(en: 'Fixture concept', hi: 'परीक्षण अवधारणा'),
      sections: {
        ConceptSection.howItWorks: ContentText(en: 'HOW-TEXT'),
        ConceptSection.whatIsIt: ContentText(en: 'WHAT-TEXT'),
      },
      equations: ['A + B → C'],
      labIds: [],
      sources: [],
      review: ReviewStatus.verified,
    );
    const question = PyqQuestion(
      id: 'fixture-q',
      boardId: 'cbse',
      classLevel: 10,
      examYear: 2024,
      attempt: ExamAttempt.main,
      paperCode: '31/1/1',
      questionNumber: '7',
      marks: 2,
      type: QuestionType.shortAnswer,
      chapterId: 'cbse-10-ch02',
      syllabusStatus: SyllabusStatus.inSyllabus,
      paperUrl: 'https://example.invalid/paper.pdf',
      summary: ContentText(en: 'SUMMARY-TEXT'),
      answer: ContentText(en: 'ANSWER-TEXT'),
      review: ReviewStatus.verified,
    );

    testWidgets('concept sections follow the approved order; empty ones are hidden', (tester) async {
      await launchApp(tester);
      final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
      nav.push(MaterialPageRoute<void>(builder: (_) => const ConceptScreen(concept: concept, classLevel: 10)));
      await tester.pumpAndSettle();
      final what = tester.getTopLeft(find.text('What is it?')).dy;
      final how = tester.getTopLeft(find.text('How does it work?')).dy;
      expect(what, lessThan(how));
      expect(find.text('Why is it important?'), findsNothing);
      expect(find.text('Exam importance'), findsNothing); // no PYQs → no claim
      expect(find.text('A + B → C'), findsOneWidget);
    });

    testWidgets('PYQ answer stays hidden until asked for', (tester) async {
      await launchApp(tester);
      final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
      nav.push(MaterialPageRoute<void>(builder: (_) => const PyqDetailScreen(question: question)));
      await tester.pumpAndSettle();
      expect(find.text('SUMMARY-TEXT'), findsOneWidget);
      expect(find.text('ANSWER-TEXT'), findsNothing);
      await tester.tap(find.text('Show answer'));
      await tester.pumpAndSettle();
      expect(find.text('ANSWER-TEXT'), findsOneWidget);
    });

    test('exam importance is computed from questions, never typed in', () {
      final imp = ExamImportance.fromQuestions([question], examYears: const [2022, 2023, 2024, 2025, 2026]);
      expect(imp.level, ImportanceLevel.low);
      expect(ExamImportance.fromQuestions(const [], examYears: const [2024]).level, ImportanceLevel.none);
    });
  });

  group('small phone 320×568: every new screen fits', () {
    Future<void> walk(WidgetTester tester, {bool hindi = false}) async {
      await launchApp(tester, size: const Size(640, 1136), pixelRatio: 2, saved: {
        if (hindi) 'app_language': 'hi',
        AppState.classKey: 10,
      });
      Future<void> scrollAll() async {
        await tester.drag(find.byType(Scrollable).first, const Offset(0, -6000));
        await tester.pumpAndSettle();
      }

      await scrollAll(); // Home
      for (final tab in hindi ? ['पढ़ाई', 'लैब', 'परीक्षा', 'प्रगति'] : ['Learn', 'Lab', 'Exam', 'Progress']) {
        await _tab(tester, tab);
        await scrollAll();
      }
      await _tab(tester, hindi ? 'होम' : 'Home');
      for (final screen in [const SearchScreen(), const SettingsScreen(), const BookmarksScreen()]) {
        final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
        nav.push(MaterialPageRoute<void>(builder: (_) => screen));
        await tester.pumpAndSettle();
        await scrollAll();
        await _back(tester);
      }
      await tester.tap(find.text(hindi ? 'कक्षा 10' : 'Class 10'));
      await tester.pumpAndSettle();
      await scrollAndTap(tester, find.text(hindi ? 'अम्ल, क्षारक एवं लवण' : 'Acids, Bases and Salts'));
      await scrollAndTap(tester, find.text(hindi ? 'विषय 2.1' : 'TOPIC 2.1'));
      await scrollAll();
      // Any RenderFlex overflow above fails the test.
    }

    testWidgets('English', (tester) => walk(tester));
    testWidgets('Hindi', (tester) => walk(tester, hindi: true));
  });
}
