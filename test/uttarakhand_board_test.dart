import 'package:flutter_test/flutter_test.dart';
import 'package:virtual_chemistry_lab/content/content_catalog.dart';
import 'package:virtual_chemistry_lab/content/content_repository.dart';
import 'package:virtual_chemistry_lab/content/content_validator.dart';
import 'package:virtual_chemistry_lab/content/models/practical_coverage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late LoadedCurriculum uk;
  late LoadedCurriculum cbse;

  setUpAll(() async {
    final catalog = await ContentCatalog.load(ContentRepository());
    uk = catalog.curriculum('uttarakhand')!;
    cbse = catalog.curriculum('cbse')!;
  });

  group('Uttarakhand Board (UBSE) 2026-27', () {
    test('only Classes 9 and 10, from the official HS Science 2026-27 syllabus', () async {
      expect(uk.classLevels, [9, 10]);
      expect(ContentValidator.curriculum(uk.manifest, await ContentRepository().allClasses('uttarakhand')), isEmpty);
      expect(ContentValidator.learningContent(uk, notesForClasses: {10}), isEmpty);
      expect(uk.classes[9]!.units.single.marks, 25);
      expect(uk.classes[10]!.units.single.marks, 25);
      expect(uk.classes[10]!.examPattern.boardExam, isTrue);
    });

    test('Class 10 reuses all NCERT questions; no PYQs; ids are Uttarakhand ids', () {
      expect(uk.pyqs, isEmpty);
      expect(uk.practiceQuestions(classLevel: 10).length, cbse.practiceQuestions(classLevel: 10).length);
      expect(uk.questions.where((q) => q.id.contains('cbse') || q.id.contains('-up-')), isEmpty);
    });

    test('practical status matches what the labs really do', () {
      final status = {
        for (final level in uk.classLevels)
          for (final p in uk.classes[level]!.practicals) p.id: uk.practicalStatus(p).level,
      };
      expect(status, hasLength(11));
      expect([for (final e in status.entries) if (e.value == PracticalLevel.fullyInteractive) e.key], ['uk-10-p2']);
      expect([for (final e in status.entries) if (e.value == PracticalLevel.partiallyInteractive) e.key], ['uk-9-p3', 'uk-10-p1b', 'uk-10-p3', 'uk-10-p8']);
      for (final l in uk.manifest.labLinks) {
        expect(l.practicalId, startsWith('uk-'), reason: l.labId);
      }
    });
  });
}
