import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:virtual_chemistry_lab/content/content_repository.dart';
import 'package:virtual_chemistry_lab/content/content_text.dart';
import 'package:virtual_chemistry_lab/content/content_validator.dart';
import 'package:virtual_chemistry_lab/content/models/board.dart';
import 'package:virtual_chemistry_lab/content/models/pyq.dart';
import 'package:virtual_chemistry_lab/content/models/syllabus.dart';
import 'package:virtual_chemistry_lab/l10n/app_language.dart';

/// In-memory asset bundle for test-only fixtures.
class _MapBundle extends CachingAssetBundle {
  _MapBundle(this.files);

  final Map<String, String> files;

  @override
  Future<ByteData> load(String key) async {
    final text = files[key];
    if (text == null) throw StateError('Missing asset $key');
    return ByteData.sublistView(Uint8List.fromList(utf8.encode(text)));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final repo = ContentRepository();

  group('board registry', () {
    test('lists every planned board; only the seven verified boards have data', () async {
      final registry = await repo.boards();
      expect(registry.boards.map((b) => b.id), [
        'cbse', 'cisce', 'up', 'bihar', 'mp', 'rajasthan', 'haryana', 'punjab', 'maharashtra', 'gujarat',
        'west-bengal', 'jharkhand', 'chhattisgarh', 'uttarakhand', 'odisha', 'karnataka', 'tamil-nadu',
        'andhra-pradesh', 'telangana', 'kerala',
      ]);
      expect(registry.available.map((b) => b.id), ['cbse', 'cisce', 'up', 'rajasthan', 'haryana', 'punjab', 'uttarakhand']);
      expect(registry.comingSoon, hasLength(13));
      expect(ContentValidator.registry(registry), isEmpty);
    });

    test('coming-soon boards carry no syllabus and cannot be loaded', () async {
      final registry = await repo.boards();
      for (final b in registry.comingSoon) {
        expect(b.curricula, isEmpty, reason: b.id);
        expect(b.officialName, isNull, reason: '${b.id}: official name not verified yet');
        expect(b.name.hasHindi, isTrue, reason: b.id);
        await expectLater(repo.curriculum(b.id), throwsStateError);
      }
    });

    test('validator rejects a coming-soon board that lists a syllabus', () {
      final bad = BoardRegistry([
        Board(
          id: 'x', order: 1, scope: BoardScope.state, state: 'X', status: BoardStatus.comingSoon,
          name: const ContentText(en: 'X Board'), officialName: null,
          curricula: const [CurriculumRef(academicYear: '2026-27', manifestPath: 'm.json', status: 'draft')],
        ),
      ]);
      expect(ContentValidator.registry(bad), contains('Board "x" is coming soon but lists a syllabus'));
    });
  });

  group('CBSE 2026-27', () {
    test('has Classes 9–12 and passes every integrity rule', () async {
      final manifest = await repo.curriculum('cbse');
      expect(manifest.academicYear, '2026-27');
      expect(manifest.classLevels, [9, 10, 11, 12]);
      final classes = await repo.allClasses('cbse');
      expect(ContentValidator.curriculum(manifest, classes), isEmpty);
    });

    // Locks the verified chapter lists (CBSE curriculum + NCERT textbooks).
    test('exam chapters match the official 2026-27 lists, in order', () async {
      Future<List<String>> titles(int c) async =>
          [for (final ch in (await repo.classSyllabus('cbse', c)).examChapters) ch.title.en];
      expect(await titles(9), ['Exploring Mixtures and their Separation', 'Journey Inside the Atom', 'Atomic Foundations of Matter']);
      expect(await titles(10), ['Chemical Reactions and Equations', 'Acids, Bases and Salts', 'Metals and Non-metals', 'Carbon and its Compounds']);
      expect(await titles(11), [
        'Some Basic Concepts of Chemistry', 'Structure of Atom', 'Classification of Elements and Periodicity in Properties',
        'Chemical Bonding and Molecular Structure', 'Thermodynamics', 'Equilibrium', 'Redox Reactions',
        'Organic Chemistry – Some Basic Principles and Techniques', 'Hydrocarbons',
      ]);
      expect(await titles(12), [
        'Solutions', 'Electrochemistry', 'Chemical Kinetics', 'The d- and f-Block Elements', 'Coordination Compounds',
        'Haloalkanes and Haloarenes', 'Alcohols, Phenols and Ethers', 'Aldehydes, Ketones and Carboxylic Acids', 'Amines', 'Biomolecules',
      ]);
      final c9 = await repo.classSyllabus('cbse', 9);
      expect(c9.chapters.map((c) => c.number), [5, 8, 9]);
      expect(c9.chapters[1].curriculumName, 'Structure of an Atom');
    });

    test('formative-only topics are kept out of the exam', () async {
      Future<List<String>> formative(int c) async => [
            for (final ch in (await repo.classSyllabus('cbse', c)).chapters)
              if (!ch.inYearEndExam) ch.title.en,
          ];
      expect(await formative(9), isEmpty);
      expect(await formative(10), ['Periodic Classification of Elements']);
      expect(await formative(11), ['s & p Block Elements', 'The Gaseous State']);
      expect(await formative(12), ['Surface Chemistry', 'General Principles and Processes of Isolation of Elements', 'Polymers', 'Chemistry in Everyday Life']);
    });

    test('marks follow the curriculum course structure', () async {
      final c9 = await repo.classSyllabus('cbse', 9);
      final c10 = await repo.classSyllabus('cbse', 10);
      expect(c9.units.single.marks, 25);
      expect(c10.units.single.marks, 25);
      expect(c10.examPattern.attempts, ['main', 'second']);
      for (final c in [11, 12]) {
        final s = await repo.classSyllabus('cbse', c);
        expect(s.examChapters.fold(0, (sum, ch) => sum + ch.weightage.marks), 70);
        expect(s.examPattern.practicalMarks, 30);
      }
    });

    test('every chapter and topic has a Hindi title with its provenance', () async {
      for (final s in await repo.allClasses('cbse')) {
        for (final ch in s.chapters) {
          expect(ch.title.hasHindi, isTrue, reason: ch.id);
          expect(ch.title.hiSource, isNotNull, reason: ch.id);
          for (final t in ch.topics.expand((t) => t.selfAndDescendants)) {
            expect(t.title.hasHindi, isTrue, reason: t.id);
            expect(t.title.hiSource, isNotNull, reason: t.id);
          }
        }
      }
      final ch5 = (await repo.classSyllabus('cbse', 9)).chapters.first;
      expect(ch5.title.of(AppLanguage.hi), 'मिश्रण एवं उनके पृथक्करण का अन्वेषण');
      expect(ch5.title.hiSource, HindiSource.ncert);
    });

    test('practicals follow the official list and mapping basis', () async {
      final c9 = await repo.classSyllabus('cbse', 9);
      expect(c9.practicals.map((p) => p.mapping).toSet(), {PracticalMapping.official});
      expect(c9.practicals.last.chapterIds, ['cbse-9-ch09']);
      final c10 = await repo.classSyllabus('cbse', 10);
      expect(c10.practicals.map((p) => p.number), ['1A', '1B', '2', '3', '8', '9']);
      final total = [for (final s in await repo.allClasses('cbse')) s.practicals.length].fold(0, (a, b) => a + b);
      expect(total, 27);
    });

    test('learning content ships for Classes 9–12; PYQs for the board-exam Classes 10 and 12', () async {
      final manifest = await repo.curriculum('cbse');
      expect(manifest.conceptFiles, isNotEmpty);
      for (final level in [9, 10, 11, 12]) {
        expect(manifest.noteFiles.where((f) => f.contains('/class-$level-')), isNotEmpty, reason: 'Class $level');
      }
      expect(manifest.questionFiles, [for (final level in [9, 10, 11, 12]) 'boards/cbse/2026-27/questions/class-$level.json']);
      expect(manifest.pyqFiles, ['boards/cbse/2026-27/pyq/class-10.json', 'boards/cbse/2026-27/pyq/class-12.json']);
      expect(manifest.pyqPapers.map((p) => (p.classLevel, p.examYear, p.paperCode)), [
        (10, 2023, '31/2/1'), (10, 2024, '31/1/1'), (10, 2025, '31/1/1'), (10, 2026, '31/2/1'),
        (12, 2023, '56/1/1'), (12, 2024, '56/1/1'), (12, 2025, '56/4/1'), (12, 2026, '56/1/1'),
      ]);
      expect(manifest.legacyIdMap['c10_acids_bases'], 'cbse-10-ch02');
    });
  });

  test('a new board loads from its own files without touching CBSE', () async {
    // Test-only fixture board — not app content.
    const board = '{"boards":[{"id":"cbse","order":1,"scope":"national","state":null,"status":"available",'
        '"name":{"en":"CBSE","hi":"सीबीएसई","hiSrc":"translated"},"officialName":null,'
        '"curricula":[{"academicYear":"2026-27","manifest":"boards/cbse/2026-27/manifest.json","status":"verified"}]},'
        '{"id":"demo","order":2,"scope":"state","state":"Demo","status":"available",'
        '"name":{"en":"Demo Board"},"officialName":null,'
        '"curricula":[{"academicYear":"2027-28","manifest":"boards/demo/2027-28/manifest.json","status":"draft"}]}]}';
    const manifest = '{"id":"demo-2027-28","boardId":"demo","academicYear":"2027-28","status":"draft",'
        '"classes":[{"classLevel":11,"file":"boards/demo/2027-28/class-11.json"}],"sources":[],"concepts":[],"pyq":{"files":[]}}';
    const class11 = '{"boardId":"demo","academicYear":"2027-28","classLevel":11,'
        '"label":{"en":"I PUC"},"subject":{"id":"chemistry","code":null,"name":{"en":"Chemistry"}},'
        '"examPattern":{"theoryMarks":70,"boardExam":false},"units":[],"practicals":[],'
        '"chapters":[{"id":"demo-11-ch01","number":1,"unitId":null,"title":{"en":"Fixture chapter","hi":"परीक्षण","hiSrc":"translated"},'
        '"assessment":"summative","weightage":{"marks":70,"scope":"chapter"},"description":{"en":"Fixture"},"topics":[],"practicalIds":[]}],"sourceIds":[]}';
    final fixtures = ContentRepository(
      bundle: _MapBundle({
        'assets/content/boards.json': board,
        'assets/content/boards/demo/2027-28/manifest.json': manifest,
        'assets/content/boards/demo/2027-28/class-11.json': class11,
      }),
    );
    final demo = await fixtures.classSyllabus('demo', 11);
    expect(demo.label.en, 'I PUC');
    expect(ContentValidator.curriculum(await fixtures.curriculum('demo'), [demo]), isEmpty);
    // CBSE in the real bundle is unaffected.
    expect((await repo.classSyllabus('cbse', 11)).label.en, 'Class 11');
  });

  group('ExamImportance (test fixtures, not real PYQs)', () {
    PyqQuestion q(int year, int marks, {String? group, SyllabusStatus status = SyllabusStatus.inSyllabus}) => PyqQuestion(
          id: 'fx-$year-$marks-$group', boardId: 'cbse', classLevel: 10, examYear: year, attempt: ExamAttempt.main,
          paperCode: 'fixture', questionNumber: '1', marks: marks, type: QuestionType.shortAnswer,
          chapterId: 'cbse-10-ch02', syllabusStatus: status, paperUrl: 'https://example.invalid/fixture', similarGroupId: group,
        );
    const window = [2022, 2023, 2024, 2025, 2026];

    test('nothing asked → none', () {
      final i = ExamImportance.fromQuestions(const [], examYears: window);
      expect((i.timesAsked, i.marksAsked, i.repeated, i.level), (0, 0, false, ImportanceLevel.none));
    });

    test('counts distinct years, marks and repeats; ignores removed topics', () {
      final i = ExamImportance.fromQuestions([
        q(2022, 3, group: 'g'), q(2022, 1), q(2024, 3, group: 'g'), q(2025, 2),
        q(2023, 5, status: SyllabusStatus.removed), q(2019, 3),
      ], examYears: window);
      expect(i.askedInYears, [2022, 2024, 2025]);
      expect(i.marksAsked, 9);
      expect(i.repeated, isTrue);
      expect(i.level, ImportanceLevel.high);
    });

    test('levels by share of years', () {
      expect(ExamImportance.fromQuestions([q(2022, 1)], examYears: window).level, ImportanceLevel.low);
      expect(ExamImportance.fromQuestions([q(2022, 1), q(2023, 1)], examYears: window).level, ImportanceLevel.medium);
    });
  });

  test('missing Hindi falls back to English', () {
    const t = ContentText(en: 'Thermodynamics');
    expect(t.of(AppLanguage.hi), 'Thermodynamics');
    expect(t.hasHindi, isFalse);
  });
}
