import 'package:flutter/foundation.dart';

/// How a focus session ended.
enum FocusStatus {
  /// The timer ran down to zero.
  completed,

  /// The student left before the timer finished.
  exited,
}

/// One finished Focus Mode session, stored locally for Analytics.
///
/// Curriculum items are stored by id (not title) so records stay valid in
/// every language and survive content wording changes.
@immutable
class FocusSession {
  const FocusSession({
    required this.id,
    required this.startedAt,
    required this.endedAt,
    required this.plannedSeconds,
    required this.focusedSeconds,
    required this.status,
    this.boardId = 'cbse',
    required this.classLevel,
    this.chapterId,
    this.topicId,
    this.listedPracticalId,
    required this.practicalId,
    required this.correctActions,
    required this.wrongActions,
    required this.practicalsCompleted,
    required this.stepsCompleted,
    required this.totalSteps,
  });

  final String id;
  final DateTime startedAt;
  final DateTime endedAt;

  /// Length the student chose (600 or 900).
  final int plannedSeconds;

  /// Time the timer actually ran, excluding pauses.
  final int focusedSeconds;
  final FocusStatus status;

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

  /// Correct chemicals poured (every step completed counts once).
  final int correctActions;

  /// Wrong chemicals poured (each Smart Warning).
  final int wrongActions;

  /// Full runs of the practical finished during the session.
  final int practicalsCompleted;

  /// Steps done in the current run when the session ended.
  final int stepsCompleted;
  final int totalSteps;

  int get totalActions => correctActions + wrongActions;

  /// 0..1, or null when nothing was poured.
  double? get accuracy => totalActions == 0 ? null : correctActions / totalActions;

  /// Bumped if the stored shape changes, so old records can be migrated.
  static const schemaVersion = 1;

  Map<String, Object?> toJson() => {
        'v': schemaVersion,
        'id': id,
        'startedAt': startedAt.toIso8601String(),
        'endedAt': endedAt.toIso8601String(),
        'plannedSeconds': plannedSeconds,
        'focusedSeconds': focusedSeconds,
        'status': status.name,
        'boardId': boardId,
        'classLevel': classLevel,
        'chapterId': chapterId,
        'topicId': topicId,
        'listedPracticalId': listedPracticalId,
        'practicalId': practicalId,
        'correctActions': correctActions,
        'wrongActions': wrongActions,
        'practicalsCompleted': practicalsCompleted,
        'stepsCompleted': stepsCompleted,
        'totalSteps': totalSteps,
      };

  factory FocusSession.fromJson(Map<String, Object?> json) => FocusSession(
        id: json['id']! as String,
        startedAt: DateTime.parse(json['startedAt']! as String),
        endedAt: DateTime.parse(json['endedAt']! as String),
        plannedSeconds: json['plannedSeconds']! as int,
        focusedSeconds: json['focusedSeconds']! as int,
        status: FocusStatus.values.byName(json['status']! as String),
        boardId: json['boardId'] as String? ?? 'cbse',
        classLevel: json['classLevel']! as int,
        chapterId: json['chapterId'] as String?,
        topicId: json['topicId'] as String?,
        listedPracticalId: json['listedPracticalId'] as String?,
        practicalId: json['practicalId']! as String,
        correctActions: json['correctActions']! as int,
        wrongActions: json['wrongActions']! as int,
        practicalsCompleted: json['practicalsCompleted']! as int,
        stepsCompleted: json['stepsCompleted']! as int,
        totalSteps: json['totalSteps']! as int,
      );
}
