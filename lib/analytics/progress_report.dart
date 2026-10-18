import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../content/content_catalog.dart';
import '../content/models/syllabus.dart';
import '../models/focus_session.dart';
import '../models/practical_attempt.dart';

/// One lab visit, normalised from either a [PracticalAttempt] or a focus
/// session saved before attempts were recorded.
@immutable
class PracticeRecord {
  const PracticeRecord({
    required this.endedAt,
    required this.classLevel,
    this.chapterId,
    this.topicId,
    required this.practicalId,
    required this.correct,
    required this.wrong,
    required this.completions,
    required this.bestSteps,
    required this.totalSteps,
    this.focus,
  });

  final DateTime endedAt;
  final int classLevel;
  final String? chapterId;

  /// Null for a lab opened from the board's practical list.
  final String? topicId;
  final String practicalId;
  final int correct;
  final int wrong;
  final int completions;
  final int bestSteps;
  final int totalSteps;

  /// The focus session this visit ran in, if any.
  final FocusSession? focus;

  /// 0..1 – full credit once completed, otherwise the furthest step reached.
  double get progress =>
      completions > 0 ? 1 : (totalSteps == 0 ? 0 : bestSteps / totalSteps);
}

@immutable
class TopicProgress {
  const TopicProgress({
    required this.topic,
    required this.progress,
    required this.practicalsDone,
    required this.practicalsTotal,
    required this.attempts,
  });

  /// A verified topic or sub-topic that has at least one interactive lab.
  final Topic topic;
  final double progress;

  /// Interactive labs on this topic: completed / offered.
  final int practicalsDone;
  final int practicalsTotal;
  final int attempts;

  bool get isComplete => practicalsTotal > 0 && practicalsDone == practicalsTotal;
}

@immutable
class ChapterProgress {
  const ChapterProgress({
    required this.chapter,
    required this.progress,
    required this.topics,
  });

  final Chapter chapter;
  final double progress;
  final List<TopicProgress> topics;

  int get topicsDone => topics.where((t) => t.isComplete).length;
  bool get isComplete => topics.isNotEmpty && topicsDone == topics.length;
}

/// Correct / wrong pours on one calendar day.
@immutable
class DayActivity {
  const DayActivity({required this.date, required this.correct, required this.wrong});

  final DateTime date;
  final int correct;
  final int wrong;

  int get total => correct + wrong;
}

/// Everything the Analytics screen shows, computed from saved records only.
///
/// Only records of the curriculum's board count. Curriculum progress is for
/// [classLevel] and is measured by the interactive labs placed in that
/// class's verified syllabus; time, actions, streak and recent activity cover
/// every class of the board. A lab counts as done once it has been completed
/// anywhere, since it is the same experiment.
@immutable
class ProgressReport {
  const ProgressReport._({
    required this.classLevel,
    required this.hasData,
    required this.overallProgress,
    required this.chapters,
    required this.practicalsDone,
    required this.practicalsTotal,
    required this.chaptersWithoutLab,
    required this.totalFocusSeconds,
    required this.focusSessions,
    required this.focusSessionsFinished,
    required this.tenMinuteSessions,
    required this.fifteenMinuteSessions,
    required this.correctActions,
    required this.wrongActions,
    required this.attempts,
    required this.completionRuns,
    required this.streakDays,
    required this.lastSevenDays,
    required this.recent,
  });

  factory ProgressReport.build({
    required LoadedCurriculum curriculum,
    required List<PracticalAttempt> attempts,
    required List<FocusSession> sessions,
    required int classLevel,
    required DateTime now,
    int recentLimit = 8,
  }) {
    final boardId = curriculum.manifest.boardId;
    attempts = [for (final a in attempts) if (a.boardId == boardId) a];
    sessions = [for (final s in sessions) if (s.boardId == boardId) s];
    final sessionsById = {for (final s in sessions) s.id: s};
    final linkedIds = {for (final a in attempts) ?a.focusSessionId};

    final records = <PracticeRecord>[
      for (final a in attempts)
        PracticeRecord(
          endedAt: a.endedAt,
          classLevel: a.classLevel,
          chapterId: a.chapterId,
          topicId: a.topicId,
          practicalId: a.practicalId,
          correct: a.correctActions,
          wrong: a.wrongActions,
          completions: a.completions,
          bestSteps: a.bestSteps,
          totalSteps: a.totalSteps,
          focus: sessionsById[a.focusSessionId],
        ),
      // Focus sessions with pours but no attempt (saved before attempts
      // existed). Linked sessions are already covered by their attempt.
      for (final s in sessions)
        if (!linkedIds.contains(s.id) && s.totalActions > 0)
          PracticeRecord(
            endedAt: s.endedAt,
            classLevel: s.classLevel,
            chapterId: s.chapterId,
            topicId: s.topicId,
            practicalId: s.practicalId,
            correct: s.correctActions,
            wrong: s.wrongActions,
            completions: s.practicalsCompleted,
            bestSteps: s.practicalsCompleted > 0 ? s.totalSteps : s.stepsCompleted,
            totalSteps: s.totalSteps,
            focus: s,
          ),
    ];

    // Best progress per practical id, across all records.
    final bestByPractical = <String, double>{};
    final attemptsByTopic = <String, int>{};
    for (final r in records) {
      bestByPractical[r.practicalId] =
          math.max(bestByPractical[r.practicalId] ?? 0, r.progress);
      if (r.topicId case final t?) attemptsByTopic[t] = (attemptsByTopic[t] ?? 0) + 1;
    }
    double practicalProgress(String labId) => bestByPractical[labId] ?? 0;
    bool practicalDone(String labId) => practicalProgress(labId) >= 1;

    final syllabus = curriculum.classes[classLevel];
    final chapters = <ChapterProgress>[];
    var chaptersWithoutLab = 0;
    for (final c in syllabus?.chapters ?? const <Chapter>[]) {
      final topics = [
        for (final t in c.topics.expand((t) => t.selfAndDescendants))
          if (curriculum.labsForTopic(t.id) case final labs when labs.isNotEmpty)
            TopicProgress(
              topic: t,
              progress: _average(labs.map(practicalProgress)),
              practicalsDone: labs.where(practicalDone).length,
              practicalsTotal: labs.length,
              attempts: attemptsByTopic[t.id] ?? 0,
            ),
      ];
      if (topics.isEmpty) {
        if (c.inYearEndExam) chaptersWithoutLab++;
        continue;
      }
      chapters.add(ChapterProgress(
        chapter: c,
        progress: _average([
          for (final t in c.topics.expand((t) => t.selfAndDescendants)) ...curriculum.labsForTopic(t.id).map(practicalProgress),
        ]),
        topics: topics,
      ));
    }
    final classPracticals = {
      for (final p in curriculum.labsForClass(classLevel)) p.labId,
      // Labs for the class's listed practicals count too (Classes 11–12).
      ...curriculum.labsLinkedToClass(classLevel),
    };

    // Visits with no pours never become records, so add focus sessions that
    // had none to the activity list on their own.
    final recent = [
      ...records,
      for (final s in sessions)
        if (!linkedIds.contains(s.id) && s.totalActions == 0)
          PracticeRecord(
            endedAt: s.endedAt,
            classLevel: s.classLevel,
            chapterId: s.chapterId,
            topicId: s.topicId,
            practicalId: s.practicalId,
            correct: 0,
            wrong: 0,
            completions: 0,
            bestSteps: s.stepsCompleted,
            totalSteps: s.totalSteps,
            focus: s,
          ),
    ]..sort((a, b) => b.endedAt.compareTo(a.endedAt));

    final today = _day(now);
    final lastSevenDays = [
      for (var i = 6; i >= 0; i--)
        () {
          final day = DateTime(today.year, today.month, today.day - i);
          final onDay = records.where((r) => _day(r.endedAt) == day);
          return DayActivity(
            date: day,
            correct: onDay.fold(0, (sum, r) => sum + r.correct),
            wrong: onDay.fold(0, (sum, r) => sum + r.wrong),
          );
        }(),
    ];

    return ProgressReport._(
      classLevel: classLevel,
      hasData: attempts.isNotEmpty || sessions.isNotEmpty,
      overallProgress: _average(classPracticals.map(practicalProgress)),
      chapters: chapters,
      practicalsDone: classPracticals.where(practicalDone).length,
      practicalsTotal: classPracticals.length,
      chaptersWithoutLab: chaptersWithoutLab,
      totalFocusSeconds: sessions.fold(0, (sum, s) => sum + s.focusedSeconds),
      focusSessions: sessions.length,
      focusSessionsFinished: sessions.where((s) => s.status == FocusStatus.completed).length,
      tenMinuteSessions: sessions.where((s) => s.plannedSeconds == 600).length,
      fifteenMinuteSessions: sessions.where((s) => s.plannedSeconds == 900).length,
      correctActions: records.fold(0, (sum, r) => sum + r.correct),
      wrongActions: records.fold(0, (sum, r) => sum + r.wrong),
      attempts: records.length,
      completionRuns: records.fold(0, (sum, r) => sum + r.completions),
      streakDays: _streak(
        {for (final r in recent) _day(r.endedAt)},
        today,
      ),
      lastSevenDays: lastSevenDays,
      recent: recent.take(recentLimit).toList(),
    );
  }

  final int classLevel;

  /// False until anything at all has been saved – drives the empty state.
  final bool hasData;

  // Curriculum progress for [classLevel], measured by interactive labs.
  final double overallProgress;

  /// Chapters that have at least one interactive lab.
  final List<ChapterProgress> chapters;
  final int practicalsDone;
  final int practicalsTotal;

  /// Exam chapters of the class with no interactive lab yet.
  final int chaptersWithoutLab;

  /// False when the class has no interactive lab at all.
  bool get hasLabs => practicalsTotal > 0;

  int get chaptersDone => chapters.where((c) => c.isComplete).length;
  int get chaptersTotal => chapters.length;
  int get topicsDone => chapters.fold(0, (sum, c) => sum + c.topicsDone);
  int get topicsTotal => chapters.fold(0, (sum, c) => sum + c.topics.length);

  // Focus time, all classes.
  final int totalFocusSeconds;
  final int focusSessions;
  final int focusSessionsFinished;
  final int tenMinuteSessions;
  final int fifteenMinuteSessions;

  // Lab actions, all classes.
  final int correctActions;
  final int wrongActions;
  final int attempts;
  final int completionRuns;

  int get totalActions => correctActions + wrongActions;

  /// 0..1, or null when nothing has been poured yet.
  double? get accuracy => totalActions == 0 ? null : correctActions / totalActions;

  /// Consecutive days with activity, ending today (or yesterday, so the
  /// streak isn't lost before today's practice). 0 if neither.
  final int streakDays;

  /// Oldest first, ending today.
  final List<DayActivity> lastSevenDays;

  /// Newest first.
  final List<PracticeRecord> recent;

  static double _average(Iterable<double> values) {
    final list = values.toList();
    return list.isEmpty ? 0 : list.reduce((a, b) => a + b) / list.length;
  }

  /// Local calendar day. Dates are saved in device-local time.
  static DateTime _day(DateTime t) {
    final local = t.toLocal();
    return DateTime(local.year, local.month, local.day);
  }

  static int _streak(Set<DateTime> days, DateTime today) {
    var cursor = days.contains(today) ? today : _previousDay(today);
    if (!days.contains(cursor)) return 0;
    var count = 0;
    while (days.contains(cursor)) {
      count++;
      cursor = _previousDay(cursor);
    }
    return count;
  }

  // Calendar arithmetic (not 24h subtraction) so DST changes can't skip a day.
  static DateTime _previousDay(DateTime d) => DateTime(d.year, d.month, d.day - 1);
}
