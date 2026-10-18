import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:virtual_chemistry_lab/screens/home_study_dashboard.dart';
import 'package:virtual_chemistry_lab/screens/my_notes_screen.dart';
import 'package:virtual_chemistry_lab/screens/note_editor_screen.dart';
import 'package:virtual_chemistry_lab/screens/question_bank_screen.dart';
import 'package:virtual_chemistry_lab/screens/revision_screen.dart';
import 'package:virtual_chemistry_lab/screens/topic_detail_screen.dart';
import 'package:virtual_chemistry_lab/study/personal_notes_store.dart';
import 'package:virtual_chemistry_lab/study/study_progress_store.dart';

import 'test_helpers.dart';

Future<void> _search(WidgetTester tester, String text) async {
  await tester.tap(find.byTooltip('Search'));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField), text);
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('search', () {
    testWidgets('finds a practice question and opens it in the question bank', (tester) async {
      await launchApp(tester);
      await _search(tester, 'diazonium salt is stable at room temperature');
      await tester.tap(find.text('Questions'));
      await tester.pumpAndSettle();
      expect(find.text('Which diazonium salt is stable at room temperature and insoluble in water?'), findsOneWidget);
      await tester.tap(find.text('Which diazonium salt is stable at room temperature and insoluble in water?'));
      await tester.pumpAndSettle();
      expect(find.byType(QuestionBankScreen), findsOneWidget);
    });

    testWidgets('finds a formula from the notes and opens its topic', (tester) async {
      final catalog = await loadCatalog(tester);
      final note = catalog.curriculum('cbse')!.notes.firstWhere((n) => n.review.isPublishable && n.formulas.isNotEmpty && n.targetId.contains('-t'));
      await launchApp(tester);
      await _search(tester, note.formulas.first);
      await tester.tap(find.text('Formulas'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(note.formulas.first).first);
      await tester.pumpAndSettle();
      expect(find.byType(TopicDetailScreen), findsOneWidget);
    });

    testWidgets('finds my own notes, in any language, and opens the editor', (tester) async {
      final prefs = await launchApp(tester);
      final store = PersonalNotesStore(prefs);
      store.save(store.create(boardId: 'cbse', classLevel: 10, chapterId: 'cbse-10-ch02', topicId: 'cbse-10-ch02-t2.3'), 'नमक का pH सात hota hai');
      await tester.pumpWidget(const SizedBox());
      await launchAppWith(tester, prefs);
      await _search(tester, 'hota hai');
      await tester.tap(find.text('My notes'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('नमक का pH सात hota hai'));
      await tester.pumpAndSettle();
      expect(find.byType(NoteEditorScreen), findsOneWidget);
    });
  });

  group('home dashboard', () {
    testWidgets('fresh start: study path is shown and nothing is invented', (tester) async {
      await launchApp(tester);
      await tester.tap(find.text('Class 10'));
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Your study path'), 300, scrollable: find.byType(Scrollable).first);
      expect(find.byType(HomeStudyDashboard), findsOneWidget);
      expect(find.text('Recently studied'), findsNothing, reason: 'no topic opened yet');
      expect(find.text('Unfinished chapters'), findsNothing);
    });

    testWidgets('after studying: recent topic and unfinished chapter appear and open', (tester) async {
      await launchApp(tester, saved: {
        StudyProgressStore.statusKey: '{"cbse-10-ch02-t2.1": {"s": "completed"}}',
        StudyProgressStore.recentKey: ['cbse-10-ch02-t2.3'],
      });
      // The dashboard follows the class last opened.
      await tester.tap(find.text('Class 10'));
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Unfinished chapters'), 300, scrollable: find.byType(Scrollable).first);
      expect(find.text('Recently studied'), findsOneWidget);
      expect(find.textContaining('Acids, Bases and Salts'), findsWidgets);
      await scrollAndTap(tester, find.textContaining('2.3').first);
      expect(find.byType(TopicDetailScreen), findsOneWidget);
    });

    for (final (name, size) in [('small phone 320×568', const Size(640, 1136)), ('large phone', const Size(1290, 2796))]) {
      testWidgets('home, notes and revision lay out without overflow on a $name', (tester) async {
        await launchApp(tester, size: size, pixelRatio: 2, saved: {
          StudyProgressStore.recentKey: ['cbse-10-ch02-t2.3', 'cbse-12-ch03-t3.1'],
          StudyProgressStore.statusKey: '{"cbse-12-ch03-t3.1": {"s": "reviseAgain"}}',
        });
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        for (final screen in <Widget>[const MyNotesScreen(), const RevisionScreen()]) {
          tester.state<NavigatorState>(find.byType(Navigator).first).push(MaterialPageRoute<void>(builder: (_) => screen));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: screen.runtimeType.toString());
          await tester.binding.handlePopRoute();
          await tester.pumpAndSettle();
        }
      });
    }
  });
}
