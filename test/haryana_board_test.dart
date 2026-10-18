import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:virtual_chemistry_lab/content/content_catalog.dart';
import 'package:virtual_chemistry_lab/content/content_repository.dart';
import 'package:virtual_chemistry_lab/content/content_validator.dart';
import 'package:virtual_chemistry_lab/content/models/practical_coverage.dart';
import 'package:virtual_chemistry_lab/screens/class_selection_screen.dart';

import 'test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late LoadedCurriculum hr;
  late LoadedCurriculum cbse;

  setUpAll(() async {
    final catalog = await ContentCatalog.load(ContentRepository());
    hr = catalog.curriculum('haryana')!;
    cbse = catalog.curriculum('cbse')!;
  });

  group('Haryana Board (BSEH) 2026-27', () {
    test('only Classes 11 and 12, whose official 2026-27 documents were read', () async {
      expect(hr.classLevels, [11, 12]);
      expect(ContentValidator.curriculum(hr.manifest, await ContentRepository().allClasses('haryana')), isEmpty);
      expect(ContentValidator.learningContent(hr, notesForClasses: {11, 12}), isEmpty);
    });

    test('marks are those of the BSEH 2026-27 documents', () {
      List<int> marks(int level) => [for (final c in hr.classes[level]!.examChapters) c.weightage.marks];
      expect(marks(11), [7, 8, 6, 9, 7, 7, 6, 10, 10]);
      expect(marks(12), [8, 8, 7, 7, 7, 6, 6, 8, 6, 7]);
      expect(hr.classes[12]!.examPattern.boardExam, isTrue);
      expect(hr.classes[11]!.examPattern.boardExam, isFalse);
    });

    test('reuses the NCERT questions under Haryana ids; no PYQs', () {
      expect(hr.pyqs, isEmpty);
      for (final level in [11, 12]) {
        expect(hr.practiceQuestions(classLevel: level).length, cbse.practiceQuestions(classLevel: level).length);
      }
      expect(hr.questions.where((q) => q.id.contains('cbse')), isEmpty);
    });

    test('practicals: the three labs that do the whole listed task are fully interactive', () {
      final status = {for (final p in hr.classes[11]!.practicals) p.id: hr.practicalStatus(p).level};
      expect(status, hasLength(8));
      expect([for (final e in status.entries) if (e.value == PracticalLevel.fullyInteractive) e.key], ['hr-11-p3', 'hr-11-p6', 'hr-11-p7']);
      expect(status.values.where((v) => v == PracticalLevel.notImplemented), hasLength(5));
      expect(hr.classes[12]!.practicals, isEmpty, reason: 'the Class 12 course structure lists no practicals');
    });
  });

  testWidgets('choosing Haryana shows only Classes 11 and 12 and opens a chapter', (tester) async {
    await launchApp(tester, board: null, size: const Size(1080, 6000));
    await scrollAndTap(tester, find.text('Haryana Board'));
    expect(find.byType(ClassSelectionScreen), findsOneWidget);
    expect(find.text('Class 9'), findsNothing);
    expect(find.text('Class 10'), findsNothing);
    expect(find.text('Class 11'), findsOneWidget);
    expect(find.text('Class 12'), findsOneWidget);
    await scrollAndTap(tester, find.text('Class 12'));
    await scrollAndTap(tester, find.text('Solutions'));
    expect(tester.takeException(), isNull);
  });
}
