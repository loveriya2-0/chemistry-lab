import 'package:flutter_test/flutter_test.dart';
import 'package:virtual_chemistry_lab/content/content_catalog.dart';
import 'package:virtual_chemistry_lab/content/content_repository.dart';
import 'package:virtual_chemistry_lab/content/content_validator.dart';
import 'package:virtual_chemistry_lab/content/models/practical_coverage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late LoadedCurriculum rj;
  late LoadedCurriculum cbse;

  setUpAll(() async {
    final catalog = await ContentCatalog.load(ContentRepository());
    rj = catalog.curriculum('rajasthan')!;
    cbse = catalog.curriculum('cbse')!;
  });

  group('Rajasthan Board (BSER) 2026-27', () {
    test('passes every syllabus and content rule', () async {
      expect(ContentValidator.curriculum(rj.manifest, await ContentRepository().allClasses('rajasthan')), isEmpty);
      expect(ContentValidator.learningContent(rj, notesForClasses: {9, 10, 11, 12}), isEmpty);
    });

    test('marks and exam pattern are those of the BSER examination-2027 syllabus', () {
      List<int> marks(int level) => [for (final c in rj.classes[level]!.examChapters) c.weightage.marks];
      expect(marks(9), [7, 6, 9, 8]);
      expect(marks(10), [6, 7, 5, 7]);
      expect(marks(11), [6, 7, 7, 10, 8, 8, 6, 10, 8]);
      expect(marks(12), [6, 6, 6, 5, 5, 6, 6, 7, 5, 4]);
      expect(rj.classes[12]!.examPattern.theoryMarks, 56);
      expect(rj.classes[12]!.examPattern.internalAssessment, 14);
      expect(rj.classes[10]!.examPattern.theoryMarks, 80);
      expect(rj.classes[10]!.examPattern.boardExam, isTrue);
      expect(rj.classes[11]!.examPattern.boardExam, isFalse);
      expect(rj.manifest.sources.where((s) => s.publisher == 'BSER').map((s) => s.url), everyElement(startsWith('https://rajeduboard.rajasthan.gov.in/')));
    });

    test('Classes 10–12 reuse the NCERT notes and questions under Rajasthan ids; no PYQs', () {
      expect(rj.pyqs, isEmpty);
      for (final level in [10, 11, 12]) {
        expect(rj.practiceQuestions(classLevel: level).length, cbse.practiceQuestions(classLevel: level).length, reason: 'Class $level');
      }
      for (final q in rj.questions) {
        expect(q.id, isNot(contains('cbse')), reason: q.id);
        expect(rj.topic(q.topicId), isNotNull, reason: q.id);
      }
      for (final n in rj.notes) {
        expect(n.targetId, startsWith('rj-'), reason: n.id);
        expect(n.practicalIds, isEmpty, reason: n.id);
      }
    });

    test('Class 9: every topic has a note; old-NCERT topics use Rajasthan\'s own notes', () {
      final topics = [for (final ch in rj.classes[9]!.chapters) ...ch.topics.expand((t) => t.selfAndDescendants)];
      expect([for (final t in topics) if (rj.noteFor(t.id) == null) t.number], isEmpty);
      final own = [for (final t in topics) if (rj.noteFor(t.id)!.sources.single.sourceId == 'rj-sci-9') t.number];
      expect(own, ['1.1', '1.2', '1.3', '1.4', '1.5', '2.5', '2.6']);
    });

    test('practical status is honest', () {
      final status = {
        for (final level in rj.classLevels)
          for (final p in rj.classes[level]!.practicals) p.id: rj.practicalStatus(p).level,
      };
      expect(status, hasLength(16));
      expect(status.values.where((v) => v == PracticalLevel.fullyInteractive), isEmpty);
      expect([for (final e in status.entries) if (e.value == PracticalLevel.partiallyInteractive) e.key],
          ['rj-11-pD', 'rj-11-pF', 'rj-12-p1', 'rj-12-p3A']);
      for (final l in rj.manifest.labLinks) {
        expect(l.practicalId, startsWith('rj-'), reason: l.labId);
      }
    });
  });
}
