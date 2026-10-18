import 'package:flutter/foundation.dart';

import '../content_text.dart';
import 'pyq.dart' show QuestionType;
import 'review.dart';
import 'syllabus.dart' show Json;

enum Difficulty {
  easy,
  medium,
  hard;

  static Difficulty parse(String value) => values.byName(value);
}

/// A practice question written by us from the textbook — never presented
/// as a previous-year question.
@immutable
class PracticeQuestion {
  const PracticeQuestion({
    required this.id,
    required this.classLevel,
    required this.chapterId,
    required this.topicId,
    required this.type,
    required this.marks,
    required this.difficulty,
    required this.question,
    required this.answer,
    required this.explanation,
    this.options = const [],
    this.correctOption,
    this.sources = const [],
    this.review = ReviewStatus.draft,
  });

  factory PracticeQuestion.fromJson(Json json) => PracticeQuestion(
        id: json['id']! as String,
        classLevel: json['classLevel']! as int,
        chapterId: json['chapterId']! as String,
        topicId: json['topicId']! as String,
        type: QuestionType.parse(json['type']! as String),
        marks: json['marks']! as int,
        difficulty: Difficulty.parse(json['difficulty']! as String),
        question: ContentText.fromJson(json['question']! as Json),
        options: [for (final o in (json['options'] as List<Object?>? ?? const [])) ContentText.fromJson(o! as Json)],
        correctOption: json['correctOption'] as int?,
        answer: ContentText.fromJson(json['answer']! as Json),
        explanation: ContentText.fromJson(json['explanation']! as Json),
        sources: sourceRefsOf(json['sources']),
        review: reviewOf(json),
      );

  final String id;
  final int classLevel;
  final String chapterId;
  final String topicId;
  final QuestionType type;
  final int marks;
  final Difficulty difficulty;
  final ContentText question;

  /// Choices for MCQ and assertion–reason questions.
  final List<ContentText> options;

  /// Index into [options].
  final int? correctOption;
  final ContentText answer;
  final ContentText explanation;
  final List<SourceRef> sources;
  final ReviewStatus review;

  bool get isChoice => options.isNotEmpty;

  Iterable<ContentText> get texts sync* {
    yield question;
    yield* options;
    yield answer;
    yield explanation;
  }
}
