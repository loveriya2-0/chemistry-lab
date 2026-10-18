import 'package:flutter/foundation.dart';

/// One visit to the lab in which the student poured at least one chemical,
/// with or without Focus Mode. Stored locally for Analytics.
///
/// Like [FocusSession], curriculum items are stored by id. No personal data
/// is recorded – only what happened in the practical and when.
@immutable
class PracticalAttempt {
  const PracticalAttempt({
    required this.id,
    required this.startedAt,
    required this.endedAt,
    this.boardId = 'cbse',
    required this.classLevel,
    this.chapterId,
    this.topicId,
    this.listedPracticalId,
    required this.practicalId,
    required this.correctActions,
    required this.wrongActions,
    required this.completions,
    required this.bestSteps,
    required this.totalSteps,
    this.focusSessionId,
  });

  final String id;
  final DateTime startedAt;
  final DateTime endedAt;

  /// Board whose syllabus the ids below belong to. Records saved before
  /// boards existed default to CBSE.
  final String boardId;
  final int classLevel;
  /// Null when the lab was opened from a listed practical with no chapter.
  final String? chapterId;

  /// Null when the lab was opened from the board's practical list.
  final String? topicId;

  /// The board's listed practical ("cbse-11-pE") the lab was opened for.
  final String? listedPracticalId;
  final String practicalId;

  final int correctActions;
  final int wrongActions;

  /// Full runs of the practical finished during this visit.
  final int completions;

  /// Furthest step reached in any run (equals [totalSteps] once completed).
  final int bestSteps;
  final int totalSteps;

  /// [FocusSession.id] when the visit ran inside a focus session.
  final String? focusSessionId;

  bool get completed => completions > 0;

  static const schemaVersion = 1;

  Map<String, Object?> toJson() => {
        'v': schemaVersion,
        'id': id,
        'startedAt': startedAt.toIso8601String(),
        'endedAt': endedAt.toIso8601String(),
        'boardId': boardId,
        'classLevel': classLevel,
        'chapterId': chapterId,
        'topicId': topicId,
        'listedPracticalId': listedPracticalId,
        'practicalId': practicalId,
        'correctActions': correctActions,
        'wrongActions': wrongActions,
        'completions': completions,
        'bestSteps': bestSteps,
        'totalSteps': totalSteps,
        'focusSessionId': focusSessionId,
      };

  factory PracticalAttempt.fromJson(Map<String, Object?> json) => PracticalAttempt(
        id: json['id']! as String,
        startedAt: DateTime.parse(json['startedAt']! as String),
        endedAt: DateTime.parse(json['endedAt']! as String),
        boardId: json['boardId'] as String? ?? 'cbse',
        classLevel: json['classLevel']! as int,
        chapterId: json['chapterId'] as String?,
        topicId: json['topicId'] as String?,
        listedPracticalId: json['listedPracticalId'] as String?,
        practicalId: json['practicalId']! as String,
        correctActions: json['correctActions']! as int,
        wrongActions: json['wrongActions']! as int,
        completions: json['completions']! as int,
        bestSteps: json['bestSteps']! as int,
        totalSteps: json['totalSteps']! as int,
        focusSessionId: json['focusSessionId'] as String?,
      );
}
