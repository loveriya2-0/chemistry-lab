import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:virtual_chemistry_lab/screens/my_notes_screen.dart';
import 'package:virtual_chemistry_lab/screens/note_editor_screen.dart';
import 'package:virtual_chemistry_lab/screens/topic_detail_screen.dart';
import 'package:virtual_chemistry_lab/study/personal_note.dart';
import 'package:virtual_chemistry_lab/study/personal_notes_store.dart';
import 'package:virtual_chemistry_lab/study/study_progress_store.dart';

import 'test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PersonalNotesStore', () {
    late SharedPreferences prefs;
    var now = DateTime(2026, 10, 10, 9);
    PersonalNotesStore store() => PersonalNotesStore(prefs, clock: () => now);

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      now = DateTime(2026, 10, 10, 9);
    });

    PersonalNote add(PersonalNotesStore s, String text, {String topic = 'cbse-10-ch02-t2.1', String chapter = 'cbse-10-ch02'}) {
      final level = int.parse(chapter.split('-')[1]);
      final n = s.create(boardId: 'cbse', classLevel: level, chapterId: chapter, topicId: topic);
      return s.save(n, text);
    }

    test('create, edit, delete — and a blank note is never saved', () {
      final s = store();
      final blank = s.create(boardId: 'cbse', classLevel: 10, chapterId: 'cbse-10-ch02', topicId: 'cbse-10-ch02-t2.1');
      expect(s.all, isEmpty, reason: 'a new empty note is not stored');

      final saved = s.save(blank, 'Acid + base → salt + water');
      expect(s.all.single.text, 'Acid + base → salt + water');
      expect((saved.boardId, saved.classLevel, saved.chapterId, saved.topicId), ('cbse', 10, 'cbse-10-ch02', 'cbse-10-ch02-t2.1'));

      now = now.add(const Duration(minutes: 5));
      final edited = s.save(saved, 'Neutralisation: अम्ल + क्षारक → लवण + जल');
      expect(edited.id, saved.id);
      expect(edited.createdAt, saved.createdAt);
      expect(edited.updatedAt, now);
      expect(s.all, hasLength(1));

      s.delete(saved.id);
      expect(s.all, isEmpty);
    });

    test('emptying a note deletes it instead of keeping clutter', () {
      final s = store();
      final n = add(s, 'temp');
      s.save(n, '   ');
      expect(s.all, isEmpty);
    });

    test('Hindi, English and Hinglish text is kept exactly and survives a restart', () {
      final s = store();
      add(s, 'pH 7 se kam = acidic\npH < 7 अम्लीय');
      add(s, 'Mole = 6.022 × 10²³ particles', topic: 'cbse-11-ch01-t1.8', chapter: 'cbse-11-ch01');
      final reopened = PersonalNotesStore(prefs);
      expect([for (final n in reopened.all) n.text], unorderedEquals(['pH 7 se kam = acidic\npH < 7 अम्लीय', 'Mole = 6.022 × 10²³ particles']));
    });

    test('search matches any language and any case; filters by class, chapter and topic', () {
      final s = store();
      add(s, 'Indicator: litmus नीला → लाल');
      add(s, 'Phenolphthalein PINK in base');
      add(s, 'Mole concept', topic: 'cbse-11-ch01-t1.8', chapter: 'cbse-11-ch01');
      expect(s.search('pink', boardId: 'cbse'), hasLength(1));
      expect(s.search('लाल', boardId: 'cbse'), hasLength(1));
      expect(s.search('zzz', boardId: 'cbse'), isEmpty);
      expect(s.where(boardId: 'cbse', classLevel: 10), hasLength(2));
      expect(s.where(boardId: 'cbse', chapterId: 'cbse-11-ch01'), hasLength(1));
      expect(s.where(boardId: 'cbse', topicId: 'cbse-10-ch02-t2.1'), hasLength(2));
      expect(s.where(boardId: 'up'), isEmpty, reason: 'notes stay with their own board');
    });

    test('pinned notes come first; favourites are remembered', () {
      final s = store();
      final a = add(s, 'older');
      now = now.add(const Duration(minutes: 1));
      add(s, 'newer');
      expect(s.all.first.text, 'newer');
      s.togglePinned(a.id);
      expect(s.all.first.text, 'older');
      s.toggleFavourite(a.id);
      final reopened = PersonalNotesStore(prefs);
      expect(reopened.byId(a.id)!.pinned, isTrue);
      expect(reopened.byId(a.id)!.favourite, isTrue);
    });

    test('an unreadable saved entry is kept, never lost on the next save', () async {
      SharedPreferences.setMockInitialValues({PersonalNotesStore.storageKey: <String>['{"from": "a future version"}']});
      prefs = await SharedPreferences.getInstance();
      final s = store();
      expect(s.unreadableCount, 1);
      add(s, 'new note');
      final raw = prefs.getStringList(PersonalNotesStore.storageKey)!;
      expect(raw, contains('{"from": "a future version"}'));
      expect(raw, hasLength(2));
    });

    test('backup and restore: merge never deletes and only newer copies replace', () async {
      final s = store();
      final a = add(s, 'keep me');
      final backup = s.exportJson();
      expect((jsonDecode(backup) as Map)['kind'], 'personal_notes');

      // A fresh phone restores everything.
      SharedPreferences.setMockInitialValues({});
      final other = PersonalNotesStore(await SharedPreferences.getInstance(), clock: () => now);
      expect(other.importJson(backup), 1);
      expect(other.all.single.text, 'keep me');

      // An older copy does not overwrite a newer edit; importing twice adds nothing.
      now = now.add(const Duration(hours: 1));
      other.save(other.byId(a.id)!, 'edited later');
      expect(other.importJson(backup), 0);
      expect(other.byId(a.id)!.text, 'edited later');
      expect(() => other.importJson('hello'), throwsFormatException);
      expect(() => other.importJson('{"kind": "something else", "notes": []}'), throwsFormatException);
    });
  });

  group('notes in the app', () {
    testWidgets('write a note on a topic, leave, reopen the app — it is still there', (tester) async {
      final prefs = await launchApp(tester, size: const Size(1080, 4000));
      final catalog = await loadCatalog(tester);
      final loc = catalog.curriculum('cbse')!.topic('cbse-10-ch02-t2.3')!;
      tester.state<NavigatorState>(find.byType(Navigator).first).push(MaterialPageRoute<void>(
        builder: (_) => TopicDetailScreen(syllabus: loc.syllabus, chapter: loc.chapter, topic: loc.topic),
      ));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(find.text('Add a note'), 300, scrollable: find.byType(Scrollable).first);
      await tester.tap(find.text('Add a note'));
      await tester.pumpAndSettle();
      expect(find.byType(NoteEditorScreen), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('note-field')), 'pH < 7 matlab acidic — मेरी भाषा में');
      // Autosave after typing stops.
      await tester.pump(const Duration(seconds: 1));
      expect(PersonalNotesStore(prefs).all.single.text, 'pH < 7 matlab acidic — मेरी भाषा में');

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.textContaining('pH < 7 matlab acidic'), findsOneWidget);

      // "Restart": a new app on the same stored data.
      await tester.pumpWidget(const SizedBox());
      await launchAppWith(tester, prefs);
      final store = PersonalNotesStore(prefs);
      final note = store.all.single;
      expect((note.classLevel, note.chapterId, note.topicId), (10, 'cbse-10-ch02', 'cbse-10-ch02-t2.3'));
    });

    testWidgets('My notes lists every note, searches, and shows an empty state first', (tester) async {
      final prefs = await launchApp(tester);
      tester.state<NavigatorState>(find.byType(Navigator).first).push(MaterialPageRoute<void>(builder: (_) => const MyNotesScreen()));
      await tester.pumpAndSettle();
      expect(find.text('No notes yet'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      final store = PersonalNotesStore(prefs);
      store.save(store.create(boardId: 'cbse', classLevel: 9, chapterId: 'cbse-9-ch05', topicId: 'cbse-9-ch05-t5.1'), 'Homogeneous = same everywhere');
      store.save(store.create(boardId: 'cbse', classLevel: 12, chapterId: 'cbse-12-ch02'), 'Nernst equation yaad karo');
      await tester.pumpWidget(const SizedBox());
      await launchAppWith(tester, prefs);
      tester.state<NavigatorState>(find.byType(Navigator).first).push(MaterialPageRoute<void>(builder: (_) => const MyNotesScreen()));
      await tester.pumpAndSettle();
      expect(find.text('2 notes'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'nernst');
      await tester.pumpAndSettle();
      expect(find.text('1 note'), findsOneWidget);
      expect(find.text('Nernst equation yaad karo'), findsOneWidget);
    });

    testWidgets('Reset progress keeps personal notes', (tester) async {
      final prefs = await launchApp(tester, saved: {
        PersonalNotesStore.storageKey: [jsonEncode(PersonalNote(id: 'n1', boardId: 'cbse', classLevel: 10, chapterId: 'cbse-10-ch01', text: 'keep', createdAt: DateTime(2026), updatedAt: DateTime(2026)).toJson())],
        StudyProgressStore.statusKey: '{"cbse-10-ch01-t1.1": {"s": "completed"}}',
      });
      await tester.tap(find.byTooltip('Settings'));
      await tester.pumpAndSettle();
      await scrollAndTap(tester, find.text('Reset progress'));
      await tester.tap(find.text('Reset'));
      await tester.pumpAndSettle();
      expect(prefs.getString(StudyProgressStore.statusKey), isNull);
      expect(PersonalNotesStore(prefs).all.single.text, 'keep');
    });
  });
}
