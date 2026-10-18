import 'package:flutter/foundation.dart';

import '../content_text.dart';
import 'review.dart';
import 'syllabus.dart' show Json;

enum QuestionType {
  mcq,
  assertionReason,
  veryShort,
  shortAnswer,
  longAnswer,
  caseBased,
  numerical;

  static QuestionType parse(String value) => values.byName(value);
}

/// Which sitting of an exam a paper is from.
enum ExamAttempt {
  main,

  /// Optional second board exam (CBSE Class 10 from 2026).
  second,
  term1,
  term2,
  compartment;

  static ExamAttempt parse(String value) => values.byName(value);
}

/// Whether a past question is still covered by the current syllabus.
enum SyllabusStatus {
  inSyllabus,
  formativeOnly,
  removed;

  static SyllabusStatus parse(String value) => values.byName(value);
}

/// A previous-year question, referenced from an official paper.
///
/// The official wording is not copied: [summary], [options] and [answer]
/// are written by us from the paper and its marking scheme, and the paper
/// is linked through [paperUrl].
@immutable
class PyqQuestion {
  const PyqQuestion({
    required this.id,
    required this.boardId,
    required this.classLevel,
    required this.examYear,
    required this.attempt,
    required this.paperCode,
    required this.questionNumber,
    required this.marks,
    required this.type,
    required this.chapterId,
    required this.syllabusStatus,
    required this.paperUrl,
    this.topicId,
    this.conceptIds = const [],
    this.similarGroupId,
    this.summary,
    this.answer,
    this.markingSchemeUrl,
    this.options = const [],
    this.correctOption,
    this.review = ReviewStatus.draft,
  });

  factory PyqQuestion.fromJson(Json json) {
    final paper = json['paper']! as Json;
    final source = json['source']! as Json;
    return PyqQuestion(
      id: json['id']! as String,
      boardId: json['boardId']! as String,
      classLevel: json['classLevel']! as int,
      examYear: json['examYear']! as int,
      attempt: ExamAttempt.parse(json['attempt']! as String),
      paperCode: paper['code']! as String,
      questionNumber: json['questionNumber']! as String,
      marks: json['marks']! as int,
      type: QuestionType.parse(json['type']! as String),
      chapterId: json['chapterId']! as String,
      topicId: json['topicId'] as String?,
      conceptIds: [for (final c in (json['conceptIds'] as List<Object?>? ?? const [])) c! as String],
      syllabusStatus: SyllabusStatus.parse(json['syllabusStatus']! as String),
      similarGroupId: json['similarGroupId'] as String?,
      summary: contentTextOrNull(json['summary']),
      answer: contentTextOrNull(json['answer']),
      paperUrl: source['paperUrl']! as String,
      markingSchemeUrl: source['markingSchemeUrl'] as String?,
      options: [for (final o in (json['options'] as List<Object?>? ?? const [])) ContentText.fromJson(o! as Json)],
      correctOption: json['correctOption'] as int?,
      review: reviewOf(json),
    );
  }

  final String id;
  final String boardId;
  final int classLevel;
  final int examYear;
  final ExamAttempt attempt;
  final String paperCode;
  final String questionNumber;
  final int marks;
  final QuestionType type;
  final String chapterId;
  final String? topicId;
  final List<String> conceptIds;
  final SyllabusStatus syllabusStatus;

  /// Set by a reviewer for questions of the same kind; never guessed.
  final String? similarGroupId;
  final ContentText? summary;
  final ContentText? answer;
  final String paperUrl;
  final String? markingSchemeUrl;

  /// Choices of an MCQ or assertion–reason question, in our words.
  final List<ContentText> options;

  /// Index into [options], from the official marking scheme.
  final int? correctOption;
  final ReviewStatus review;

  bool get isPublishable => review.isPublishable && syllabusStatus == SyllabusStatus.inSyllabus;
}

enum ImportanceLevel { none, low, medium, high }

/// Exam importance computed from PYQ data — never typed in by hand.
@immutable
class ExamImportance {
  const ExamImportance({
    required this.timesAsked,
    required this.yearsInWindow,
    required this.marksAsked,
    required this.repeated,
    required this.askedInYears,
  });

  /// [questions] are the PYQs about one chapter, topic or concept.
  /// Only questions still in the syllabus count. [examYears] is the window
  /// of years with official papers (e.g. 2022–2026).
  factory ExamImportance.fromQuestions(Iterable<PyqQuestion> questions, {required List<int> examYears}) {
    final relevant = questions.where((q) => q.syllabusStatus == SyllabusStatus.inSyllabus && examYears.contains(q.examYear));
    final years = {for (final q in relevant) q.examYear}.toList()..sort();
    final groupYears = <String, Set<int>>{};
    for (final q in relevant) {
      if (q.similarGroupId != null) (groupYears[q.similarGroupId!] ??= {}).add(q.examYear);
    }
    return ExamImportance(
      timesAsked: years.length,
      yearsInWindow: examYears.length,
      marksAsked: relevant.fold(0, (sum, q) => sum + q.marks),
      repeated: groupYears.values.any((y) => y.length >= 2),
      askedInYears: years,
    );
  }

  /// Distinct exam years with at least one question.
  final int timesAsked;
  final int yearsInWindow;
  final int marksAsked;

  /// A reviewer-defined similar group appears in two or more years.
  final bool repeated;
  final List<int> askedInYears;

  /// High: asked in at least 60% of the years; medium: at least 30%;
  /// low: asked at least once.
  ImportanceLevel get level {
    if (timesAsked == 0 || yearsInWindow == 0) return ImportanceLevel.none;
    final share = timesAsked / yearsInWindow;
    if (share >= 0.6) return ImportanceLevel.high;
    if (share >= 0.3) return ImportanceLevel.medium;
    return ImportanceLevel.low;
  }
}
