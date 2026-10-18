import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:virtual_chemistry_lab/content/content_catalog.dart';
import 'package:virtual_chemistry_lab/content/content_repository.dart';
import 'package:virtual_chemistry_lab/content/content_validator.dart';
import 'package:virtual_chemistry_lab/content/models/practical_coverage.dart';
import 'package:virtual_chemistry_lab/content/models/syllabus.dart';

import 'test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late LoadedCurriculum pb;
  late LoadedCurriculum cbse;

  setUpAll(() async {
    final catalog = await ContentCatalog.load(ContentRepository());
    pb = catalog.curriculum('punjab')!;
    cbse = catalog.curriculum('cbse')!;
  });

  group('Punjab Board (PSEB) 2026-27', () {
    test('passes every rule; chapter marks are marked as not published', () async {
      expect(pb.classLevels, [9, 10, 11, 12]);
      expect(ContentValidator.curriculum(pb.manifest, await ContentRepository().allClasses('punjab')), isEmpty);
      expect(ContentValidator.learningContent(pb, notesForClasses: {10, 11, 12}), isEmpty);
      for (final level in pb.classLevels) {
        for (final c in pb.classes[level]!.examChapters) {
          expect(c.weightage.scope, WeightageScope.notPublished, reason: c.id);
          expect(c.weightage.marks, 0, reason: c.id);
        }
      }
      expect((pb.classes[12]!.examPattern.theoryMarks, pb.classes[12]!.examPattern.practicalMarks), (70, 25));
    });

    test('reuses NCERT questions for 10–12; Class 9 has an unmapped mole-concept topic', () {
      expect(pb.pyqs, isEmpty);
      for (final level in [10, 11, 12]) {
        expect(pb.practiceQuestions(classLevel: level).length, cbse.practiceQuestions(classLevel: level).length);
      }
      expect(pb.noteFor('pb-9-ch03-t3.9'), isNull);
      expect(pb.questions.where((q) => q.id.contains('cbse') || q.id.contains('-rj-')), isEmpty);
    });

    test('practical status: Class 11–12 lists from the PDFs; none fully interactive', () {
      final status = {
        for (final level in pb.classLevels)
          for (final p in pb.classes[level]!.practicals) p.id: pb.practicalStatus(p).level,
      };
      expect(status, hasLength(14));
      expect(status.values.where((v) => v == PracticalLevel.fullyInteractive), isEmpty);
      expect([for (final e in status.entries) if (e.value == PracticalLevel.partiallyInteractive) e.key], ['pb-11-pD', 'pb-11-pE', 'pb-12-pC', 'pb-12-pF']);
    });
  });

  testWidgets('Punjab chapter list shows "Chapter marks not published"', (tester) async {
    await launchApp(tester, board: 'punjab', size: const Size(1080, 6000));
    await scrollAndTap(tester, find.text('Class 12'));
    expect(find.text('Chapter marks not published'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
