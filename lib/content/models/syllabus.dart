import 'package:flutter/foundation.dart';

import '../content_text.dart';
import 'practical_coverage.dart';

typedef Json = Map<String, Object?>;

List<T> _list<T>(Object? json, T Function(Json) parse) =>
    [for (final e in (json as List<Object?>? ?? const [])) parse(e! as Json)];

List<String> _strings(Object? json) => [for (final e in (json as List<Object?>? ?? const [])) e! as String];

/// Whether a chapter counts in the year-end/board exam.
enum Assessment {
  summative,

  /// In the syllabus but explicitly not assessed in the year-end exam.
  formativeOnly;

  static Assessment parse(String value) => values.byName(value);
}

/// How marks are published for a chapter.
enum WeightageScope {
  /// Marks belong to this chapter alone (e.g. CBSE Classes 11–12).
  chapter,

  /// Marks are given for the whole unit and shared by its chapters
  /// (e.g. CBSE Classes 9–10).
  unit,

  notInYearEndExam,

  /// In the year-end exam, but the board publishes no chapter-wise marks
  /// (e.g. PSEB gives teaching periods only).
  notPublished;

  static WeightageScope parse(String value) => values.byName(value);
}

@immutable
class Weightage {
  const Weightage({required this.marks, required this.scope});

  factory Weightage.fromJson(Json json) => Weightage(
        marks: json['marks']! as int,
        scope: WeightageScope.parse(json['scope']! as String),
      );

  final int marks;
  final WeightageScope scope;
}

/// Who mapped a practical to a chapter.
enum PracticalMapping {
  /// The board's own document names the chapter or unit.
  official,

  /// Our mapping of a listed experiment to the closest chapter; needs review.
  editorial,

  /// A general lab skill not tied to one chapter (e.g. salt analysis).
  general;

  static PracticalMapping parse(String value) => values.byName(value);
}

@immutable
class Source {
  const Source({required this.id, required this.title, required this.url, required this.publisher});

  factory Source.fromJson(Json json) => Source(
        id: json['id']! as String,
        title: json['title']! as String,
        url: json['url']! as String,
        publisher: json['publisher']! as String,
      );

  final String id;
  final String title;
  final String url;
  final String publisher;
}

/// A board's exam rules for one class.
@immutable
class ExamPattern {
  const ExamPattern({
    required this.theoryMarks,
    required this.boardExam,
    this.internalAssessment,
    this.practicalMarks,
    this.attempts = const [],
    this.questionTypes = const [],
  });

  factory ExamPattern.fromJson(Json json) => ExamPattern(
        theoryMarks: json['theoryMarks']! as int,
        boardExam: json['boardExam']! as bool,
        internalAssessment: json['internalAssessment'] as int?,
        practicalMarks: json['practicalMarks'] as int?,
        attempts: _strings(json['attempts']),
        questionTypes: _strings(json['questionTypes']),
      );

  final int theoryMarks;

  /// True for classes with an external board exam (CBSE 10 and 12).
  final bool boardExam;
  final int? internalAssessment;
  final int? practicalMarks;
  final List<String> attempts;
  final List<String> questionTypes;
}

@immutable
class Unit {
  const Unit({required this.id, required this.number, required this.name, required this.marks, required this.chapterNumbers});

  factory Unit.fromJson(Json json) => Unit(
        id: json['id']! as String,
        number: json['number']! as String,
        name: ContentText.fromJson(json['name']! as Json),
        marks: json['marks']! as int,
        chapterNumbers: [for (final n in json['chapterNumbers']! as List<Object?>) n! as int],
      );

  final String id;
  final String number;
  final ContentText name;
  final int marks;
  final List<int> chapterNumbers;
}

/// A textbook section ("2.1") with optional sub-sections ("2.1.4").
@immutable
class Topic {
  const Topic({
    required this.id,
    required this.number,
    required this.title,
    required this.subtopics,
    required this.conceptIds,
  });

  factory Topic.fromJson(Json json) => Topic(
        id: json['id']! as String,
        number: json['number']! as String,
        title: ContentText.fromJson(json['title']! as Json),
        subtopics: _list(json['subtopics'], Topic.fromJson),
        conceptIds: _strings(json['conceptIds']),
      );

  final String id;
  final String number;
  final ContentText title;
  final List<Topic> subtopics;

  /// Links into the board-independent concept library.
  final List<String> conceptIds;

  /// This topic and all nested sub-topics.
  Iterable<Topic> get selfAndDescendants sync* {
    yield this;
    for (final s in subtopics) {
      yield* s.selfAndDescendants;
    }
  }
}

@immutable
class Chapter {
  const Chapter({
    required this.id,
    required this.number,
    required this.unitId,
    required this.title,
    required this.curriculumName,
    required this.assessment,
    required this.weightage,
    required this.description,
    required this.topics,
    required this.practicalIds,
    required this.conceptIds,
  });

  factory Chapter.fromJson(Json json) => Chapter(
        id: json['id']! as String,
        number: json['number'] as int?,
        unitId: json['unitId'] as String?,
        title: ContentText.fromJson(json['title']! as Json),
        curriculumName: json['curriculumName'] as String?,
        assessment: Assessment.parse(json['assessment']! as String),
        weightage: Weightage.fromJson(json['weightage']! as Json),
        description: ContentText.fromJson(json['description']! as Json),
        topics: _list(json['topics'], Topic.fromJson),
        practicalIds: _strings(json['practicalIds']),
        conceptIds: _strings(json['conceptIds']),
      );

  final String id;

  /// Textbook chapter number; null for formative-only extras that are not a
  /// chapter of the current textbook.
  final int? number;
  final String? unitId;
  final ContentText title;

  /// The board's name for the chapter when it differs from the textbook title.
  final String? curriculumName;
  final Assessment assessment;
  final Weightage weightage;
  final ContentText description;
  final List<Topic> topics;
  final List<String> practicalIds;
  final List<String> conceptIds;

  bool get inYearEndExam => assessment == Assessment.summative;
}

/// An equation linked to a practical, with its review state.
@immutable
class ReactionRef {
  const ReactionRef({required this.equation, required this.reviewStatus});

  factory ReactionRef.fromJson(Json json) => ReactionRef(
        equation: json['equation']! as String,
        reviewStatus: (json['review']! as Json)['status']! as String,
      );

  final String equation;
  final String reviewStatus;
}

@immutable
class BoardPractical {
  const BoardPractical({
    required this.id,
    required this.number,
    required this.title,
    required this.chapterIds,
    required this.relatedChapterIds,
    required this.mapping,
    required this.reactions,
    required this.labId,
  });

  factory BoardPractical.fromJson(Json json) => BoardPractical(
        id: json['id']! as String,
        number: json['number']! as String,
        title: ContentText.fromJson(json['title']! as Json),
        chapterIds: _strings(json['chapterIds']),
        relatedChapterIds: _strings(json['relatedChapterIds']),
        mapping: PracticalMapping.parse(json['mapping']! as String),
        reactions: _list(json['reactions'], ReactionRef.fromJson),
        labId: json['labId'] as String?,
      );

  final String id;

  /// Number as printed in the board's practical list ("1A", "E").
  final String number;
  final ContentText title;
  final List<String> chapterIds;

  /// Chapters in another class that the experiment relies on.
  final List<String> relatedChapterIds;
  final PracticalMapping mapping;
  final List<ReactionRef> reactions;

  /// Interactive virtual lab, if one has been built for it.
  final String? labId;
}

/// How an interactive lab relates to one practical in a board's list.
enum LabRelation {
  /// The lab is the listed experiment ([BoardPractical.labId]).
  official,

  /// The lab shares the reaction or technique, but is not the listed
  /// experiment; the link's note says how they differ.
  related;

  static LabRelation parse(String value) => switch (value) {
        'official' => official,
        'related' => related,
        _ => throw FormatException('Unknown lab relation "$value"'),
      };
}

/// An interactive lab linked to a practical in the board's list.
@immutable
class LabPracticalLink {
  const LabPracticalLink({required this.labId, required this.practicalId, required this.relation, this.note});

  factory LabPracticalLink.fromJson(String labId, Json json) => LabPracticalLink(
        labId: labId,
        practicalId: json['practicalId']! as String,
        relation: LabRelation.parse(json['relation']! as String),
        note: contentTextOrNull(json['note']),
      );

  final String labId;
  final String practicalId;
  final LabRelation relation;

  /// What the lab covers of the practical and what it leaves out.
  final ContentText? note;
}

/// One board's syllabus for one class and academic year.
@immutable
class ClassSyllabus {
  const ClassSyllabus({
    required this.boardId,
    required this.academicYear,
    required this.classLevel,
    required this.label,
    required this.subjectId,
    required this.subjectCode,
    required this.subjectName,
    required this.examPattern,
    required this.units,
    required this.chapters,
    required this.practicals,
    required this.sourceIds,
  });

  factory ClassSyllabus.fromJson(Json json) {
    final subject = json['subject']! as Json;
    return ClassSyllabus(
      boardId: json['boardId']! as String,
      academicYear: json['academicYear']! as String,
      classLevel: json['classLevel']! as int,
      label: ContentText.fromJson(json['label']! as Json),
      subjectId: subject['id']! as String,
      subjectCode: subject['code'] as String?,
      subjectName: ContentText.fromJson(subject['name']! as Json),
      examPattern: ExamPattern.fromJson(json['examPattern']! as Json),
      units: _list(json['units'], Unit.fromJson),
      chapters: _list(json['chapters'], Chapter.fromJson),
      practicals: _list(json['practicals'], BoardPractical.fromJson),
      sourceIds: _strings(json['sourceIds']),
    );
  }

  final String boardId;
  final String academicYear;

  /// Normalised 9–12; [label] carries the board's own name ("Class 11",
  /// "I PUC", "Intermediate 1st year").
  final int classLevel;
  final ContentText label;
  final String subjectId;
  final String? subjectCode;
  final ContentText subjectName;
  final ExamPattern examPattern;
  final List<Unit> units;
  final List<Chapter> chapters;
  final List<BoardPractical> practicals;
  final List<String> sourceIds;

  List<Chapter> get examChapters => chapters.where((c) => c.inYearEndExam).toList();
}

@immutable
class ClassRef {
  const ClassRef({required this.classLevel, required this.path});

  factory ClassRef.fromJson(Json json) =>
      ClassRef(classLevel: json['classLevel']! as int, path: json['file']! as String);

  final int classLevel;
  final String path;
}

/// One official question paper whose questions have been entered as PYQs.
@immutable
class PyqPaper {
  const PyqPaper({
    required this.examYear,
    required this.attempt,
    required this.paperCode,
    required this.classLevel,
    required this.paperUrl,
    this.markingSchemeUrl,
  });

  factory PyqPaper.fromJson(Json json) => PyqPaper(
        examYear: json['examYear']! as int,
        attempt: json['attempt']! as String,
        paperCode: json['paperCode']! as String,
        classLevel: json['classLevel']! as int,
        paperUrl: json['paperUrl']! as String,
        markingSchemeUrl: json['markingSchemeUrl'] as String?,
      );

  final int examYear;
  final String attempt;
  final String paperCode;
  final int classLevel;
  final String paperUrl;
  final String? markingSchemeUrl;
}

/// Index of one board's syllabus for one academic year.
@immutable
class CurriculumManifest {
  const CurriculumManifest({
    required this.id,
    required this.boardId,
    required this.academicYear,
    required this.status,
    required this.classes,
    required this.sources,
    required this.conceptFiles,
    required this.pyqFiles,
    required this.legacyIdMap,
    required this.labPlacements,
    this.pyqExamYears = const [],
    this.noteFiles = const [],
    this.questionFiles = const [],
    this.chemicalFiles = const [],
    this.pyqPapers = const [],
    this.reagentFiles = const [],
    this.reactionFiles = const [],
    this.reactionPlacements = const {},
    this.guideFiles = const [],
    this.labLinks = const [],
    this.practicalCoverage = const {},
    this.sharedContent,
  });

  factory CurriculumManifest.fromJson(Json json) => CurriculumManifest(
        id: json['id']! as String,
        boardId: json['boardId']! as String,
        academicYear: json['academicYear']! as String,
        status: json['status']! as String,
        classes: _list(json['classes'], ClassRef.fromJson),
        sources: _list(json['sources'], Source.fromJson),
        conceptFiles: _strings(json['concepts']),
        pyqFiles: _strings((json['pyq'] as Json?)?['files']),
        pyqPapers: _list((json['pyq'] as Json?)?['papers'], PyqPaper.fromJson),
        noteFiles: _strings(json['notes']),
        questionFiles: _strings(json['questions']),
        chemicalFiles: _strings(json['chemicals']),
        reagentFiles: _strings((json['reactionLab'] as Json?)?['reagents']),
        reactionFiles: _strings((json['reactionLab'] as Json?)?['reactions']),
        reactionPlacements: {
          for (final l in ((json['reactionLab'] as Json?)?['placements'] as List<Object?>? ?? const []))
            (l! as Json)['id']! as String: _strings((l as Json)['topicIds']),
        },
        legacyIdMap: {
          for (final e in ((json['legacyIdMap'] as Json?) ?? const {}).entries) e.key: e.value as String?,
        },
        pyqExamYears: [
          for (final y in ((((json['pyq'] as Json?)?['availability'] as Json?)?['examYears'] as List<Object?>?) ?? const []))
            y! as int,
        ],
        labPlacements: {
          for (final l in (json['labs'] as List<Object?>? ?? const []))
            (l! as Json)['id']! as String: _strings((l as Json)['topicIds']),
        },
        guideFiles: _strings(json['practicalGuides']),
        labLinks: [
          // Hand-built labs and reaction labs both link to listed practicals.
          for (final l in [
            ...(json['labs'] as List<Object?>? ?? const []),
            ...(((json['reactionLab'] as Json?)?['placements'] as List<Object?>?) ?? const []),
          ])
            for (final link in ((l! as Json)['practicalLinks'] as List<Object?>? ?? const []))
              LabPracticalLink.fromJson((l as Json)['id']! as String, link! as Json),
        ],
        practicalCoverage: {
          for (final c in (json['practicalCoverage'] as List<Object?>? ?? const []))
            (c! as Json)['practicalId']! as String: PracticalCoverage.fromJson(c as Json),
        },
        sharedContent: json['sharedContent'] as Json?,
      );

  final String id;
  final String boardId;
  final String academicYear;
  final String status;
  final List<ClassRef> classes;
  final List<Source> sources;

  /// Concept files from the shared, board-independent content library.
  final List<String> conceptFiles;

  /// Chemical and reaction cards from the shared content library.
  final List<String> chemicalFiles;

  /// Topic notes for this syllabus, one file per class.
  final List<String> noteFiles;

  /// Practice questions written from the textbook, one file per class.
  final List<String> questionFiles;

  /// PYQ files, entered from official papers.
  final List<String> pyqFiles;

  /// The official papers whose questions are in [pyqFiles].
  final List<PyqPaper> pyqPapers;

  /// Ids used by earlier app versions, for migrating saved progress.
  /// A null value means the old item has no equivalent in this syllabus.
  final Map<String, String?> legacyIdMap;

  /// Exam years with official papers on the board's website, oldest
  /// first. Exam importance uses only the years of [pyqPapers].
  final List<int> pyqExamYears;

  /// Interactive lab id -> topic ids where the lab is offered.
  final Map<String, List<String>> labPlacements;

  /// Reaction-engine shelf items and experiments from the shared library.
  final List<String> reagentFiles;
  final List<String> reactionFiles;

  /// Reaction lab id -> topic ids where this board offers it.
  final Map<String, List<String>> reactionPlacements;

  /// Practical guides (apparatus, procedure, safety) from the shared library.
  final List<String> guideFiles;

  /// Interactive labs linked to practicals in the board's list.
  final List<LabPracticalLink> labLinks;

  /// What each listed practical can do in the app, by practical id.
  /// Practicals not listed here have no lab doing part of them.
  final Map<String, PracticalCoverage> practicalCoverage;

  /// Notes and practice questions reused from another board whose syllabus
  /// follows the same textbook chapters (see SharedContent). Raw JSON: it
  /// is resolved against the other board's syllabus when content loads.
  final Json? sharedContent;

  List<int> get classLevels => [for (final c in classes) c.classLevel];
}
