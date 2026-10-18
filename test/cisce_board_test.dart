import 'package:flutter_test/flutter_test.dart';
import 'package:virtual_chemistry_lab/content/content_catalog.dart';
import 'package:virtual_chemistry_lab/content/content_repository.dart';
import 'package:virtual_chemistry_lab/content/content_validator.dart';
import 'package:virtual_chemistry_lab/content/models/practical_coverage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late LoadedCurriculum isc;
  late LoadedCurriculum cbse;

  setUpAll(() async {
    final catalog = await ContentCatalog.load(ContentRepository());
    isc = catalog.curriculum('cisce')!;
    cbse = catalog.curriculum('cbse')!;
  });

  group('CISCE ISC 2027 (session 2026-27)', () {
    test('ISC Classes 11 and 12 only; passes every rule', () async {
      expect(isc.classLevels, [11, 12]);
      expect(ContentValidator.curriculum(isc.manifest, await ContentRepository().allClasses('cisce')), isEmpty);
      expect(ContentValidator.learningContent(isc, notesForClasses: {11, 12}), isEmpty);
    });

    test('branch weightage from the ISC table: 41/6/23 and 25/14/31', () {
      expect([for (final u in isc.classes[11]!.units) u.marks], [41, 6, 23]);
      expect([for (final u in isc.classes[12]!.units) u.marks], [25, 14, 31]);
      for (final level in [11, 12]) {
        expect(isc.classes[level]!.units.fold(0, (s, u) => s + u.marks), 70);
      }
    });

    test('reuses NCERT questions under ISC ids; no PYQs', () {
      expect(isc.pyqs, isEmpty);
      for (final level in [11, 12]) {
        expect(isc.practiceQuestions(classLevel: level).length, cbse.practiceQuestions(classLevel: level).length);
      }
      expect(isc.questions.where((q) => q.id.contains('cbse')), isEmpty);
    });

    test('practical status is honest: nothing fully interactive', () {
      final status = {
        for (final level in isc.classLevels)
          for (final p in isc.classes[level]!.practicals) p.id: isc.practicalStatus(p).level,
      };
      expect(status, hasLength(12));
      expect(status.values.where((v) => v == PracticalLevel.fullyInteractive), isEmpty);
      expect([for (final e in status.entries) if (e.value == PracticalLevel.partiallyInteractive) e.key], ['isc-11-p2', 'isc-12-p1', 'isc-12-p3']);
    });
  });
}
