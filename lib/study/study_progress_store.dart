import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../content/models/syllabus.dart';

/// Where a student is with one topic. Set by the student (opening a topic
/// for the first time marks it [inProgress]).
enum TopicStatus {
  notStarted,
  inProgress,
  completed,

  /// Studied, but the student wants to come back to it.
  reviseAgain;

  /// Counts as studied for chapter completion.
  bool get isStudied => this == completed || this == reviseAgain;

  static TopicStatus parse(String? value) => values.asNameMap()[value] ?? notStarted;
}

/// The student's answers to one practice question, over all sessions.
@immutable
class QuestionRecord {
  const QuestionRecord({required this.attempts, required this.correct, required this.lastCorrect, required this.lastAt});

  factory QuestionRecord.fromJson(Map<String, Object?> json) => QuestionRecord(
        attempts: json['n']! as int,
        correct: json['c']! as int,
        lastCorrect: json['last']! as bool,
        lastAt: DateTime.parse(json['at']! as String),
      );

  final int attempts;
  final int correct;

  /// The latest answer; a question is a mistake while this is false.
  final bool lastCorrect;
  final DateTime lastAt;

  Map<String, Object?> toJson() => {'n': attempts, 'c': correct, 'last': lastCorrect, 'at': lastAt.toIso8601String()};
}

/// Topic study status, practice-question answers, revision ticks and recently
/// studied topics, saved on this device.
///
/// Ids are syllabus ids, which already name the board ("cbse-10-ch02-t2.3"),
/// so switching board never mixes records. Unreadable entries are skipped
/// on read and kept out of the way, never crash the app.
class StudyProgressStore extends ChangeNotifier {
  StudyProgressStore(this._prefs, {DateTime Function()? clock}) : _clock = clock ?? DateTime.now {
    _status.addAll(_readMap(statusKey, (j) => TopicStatus.parse(j['s'] as String?)));
    _records.addAll(_readMap(recordsKey, QuestionRecord.fromJson));
    _revised.addAll(_readMap(revisedKey, (j) => DateTime.parse(j['at']! as String)));
    _recent.addAll(_prefs.getStringList(recentKey) ?? const []);
  }

  static const statusKey = 'topic_status';
  static const recordsKey = 'question_records';
  static const revisedKey = 'revision_done';
  static const recentKey = 'recent_topics';
  static const maxRecent = 12;

  /// Every key this store writes, for "Reset progress".
  static const keys = [statusKey, recordsKey, revisedKey, recentKey];

  final SharedPreferences _prefs;
  final DateTime Function() _clock;
  final _status = <String, TopicStatus>{};
  final _records = <String, QuestionRecord>{};
  final _revised = <String, DateTime>{};
  final _recent = <String>[];

  Map<String, T> _readMap<T>(String key, T Function(Map<String, Object?>) parse) {
    final raw = _prefs.getString(key);
    if (raw == null) return {};
    try {
      final out = <String, T>{};
      for (final e in (jsonDecode(raw) as Map<String, Object?>).entries) {
        try {
          out[e.key] = parse(e.value! as Map<String, Object?>);
        } catch (err) {
          debugPrint('Skipping unreadable $key entry ${e.key}: $err');
        }
      }
      return out;
    } catch (err) {
      debugPrint('Unreadable $key: $err');
      return {};
    }
  }

  // ---------------------------------------------------------------- topics

  /// The status the student set for exactly this topic id.
  TopicStatus statusOf(String topicId) => _status[topicId] ?? TopicStatus.notStarted;

  /// A top-level topic's status, taking its sub-topics into account when
  /// the student has not set one on the topic itself: all sub-topics
  /// studied → completed; any started → in progress. "Revise again" on the
  /// topic or any sub-topic wins, so it is never hidden.
  TopicStatus effectiveStatus(Topic topic) {
    final own = statusOf(topic.id);
    final subs = [for (final s in topic.subtopics) ...s.selfAndDescendants.map((t) => statusOf(t.id))];
    if (own == TopicStatus.reviseAgain || subs.contains(TopicStatus.reviseAgain)) return TopicStatus.reviseAgain;
    if (own != TopicStatus.notStarted || subs.isEmpty) return own;
    if (subs.every((s) => s.isStudied)) return TopicStatus.completed;
    if (subs.any((s) => s != TopicStatus.notStarted)) return TopicStatus.inProgress;
    return TopicStatus.notStarted;
  }

  void setStatus(String topicId, TopicStatus status) {
    if (statusOf(topicId) == status) return;
    if (status == TopicStatus.notStarted) {
      _status.remove(topicId);
    } else {
      _status[topicId] = status;
    }
    // Taking a topic off "revise again" ticks its revision item.
    if (status == TopicStatus.completed) _revised['topic:$topicId'] = _clock();
    _saveStatus();
  }

  /// Called when a topic page opens: remembers it as recently studied and
  /// moves a not-started topic to in progress.
  void visitTopic(String topicId) {
    _recent
      ..remove(topicId)
      ..insert(0, topicId);
    if (_recent.length > maxRecent) _recent.removeRange(maxRecent, _recent.length);
    _prefs.setStringList(recentKey, List.of(_recent));
    if (statusOf(topicId) == TopicStatus.notStarted) {
      _status[topicId] = TopicStatus.inProgress;
      _saveStatus();
    } else {
      notifyListeners();
    }
  }

  /// Most recently opened topic ids, newest first.
  List<String> get recentTopicIds => List.unmodifiable(_recent);

  /// Topic ids marked "revise again".
  List<String> get reviseAgainIds => [for (final e in _status.entries) if (e.value == TopicStatus.reviseAgain) e.key];

  void _saveStatus() {
    notifyListeners();
    _prefs.setString(statusKey, jsonEncode({for (final e in _status.entries) e.key: {'s': e.value.name}}));
  }

  // ------------------------------------------------------------- questions

  QuestionRecord? recordOf(String questionId) => _records[questionId];

  /// Saves one answer. Callers record each answer once (an answer shown
  /// again in review is not recorded again).
  void recordAnswer(String questionId, {required bool correct}) {
    final old = _records[questionId];
    _records[questionId] = QuestionRecord(
      attempts: (old?.attempts ?? 0) + 1,
      correct: (old?.correct ?? 0) + (correct ? 1 : 0),
      lastCorrect: correct,
      lastAt: _clock(),
    );
    if (correct && old != null && !old.lastCorrect) _revised['mistake:$questionId'] = _clock();
    notifyListeners();
    _prefs.setString(recordsKey, jsonEncode({for (final e in _records.entries) e.key: e.value.toJson()}));
    _saveRevised();
  }

  /// Questions whose latest answer was wrong.
  Set<String> get mistakeIds => {for (final e in _records.entries) if (!e.value.lastCorrect) e.key};

  /// Mistakes later answered correctly.
  Set<String> get fixedMistakeIds => {
        for (final k in _revised.keys)
          if (k.startsWith('mistake:') && (_records[k.substring(8)]?.lastCorrect ?? false)) k.substring(8),
      };

  /// Attempted / correct / accuracy over [questionIds].
  QuestionStats statsFor(Iterable<String> questionIds) {
    var attempted = 0, correctLast = 0, answers = 0, correctAnswers = 0, total = 0;
    for (final id in questionIds) {
      total++;
      final r = _records[id];
      if (r == null) continue;
      attempted++;
      if (r.lastCorrect) correctLast++;
      answers += r.attempts;
      correctAnswers += r.correct;
    }
    return QuestionStats(total: total, attempted: attempted, correctNow: correctLast, answers: answers, correctAnswers: correctAnswers);
  }

  // -------------------------------------------------------------- revision

  /// When a revision item (a saved question or formula) was last ticked.
  DateTime? revisedAt(String itemKey) => _revised[itemKey];

  void toggleRevised(String itemKey) {
    _revised.containsKey(itemKey) ? _revised.remove(itemKey) : _revised[itemKey] = _clock();
    notifyListeners();
    _saveRevised();
  }

  void _saveRevised() =>
      _prefs.setString(revisedKey, jsonEncode({for (final e in _revised.entries) e.key: {'at': e.value.toIso8601String()}}));

  /// Clears everything in memory after "Reset progress" removed the keys.
  void clear() {
    _status.clear();
    _records.clear();
    _revised.clear();
    _recent.clear();
    for (final k in keys) {
      _prefs.remove(k);
    }
    notifyListeners();
  }
}

/// Practice progress over a set of questions.
@immutable
class QuestionStats {
  const QuestionStats({required this.total, required this.attempted, required this.correctNow, required this.answers, required this.correctAnswers});

  final int total;

  /// Questions answered at least once.
  final int attempted;

  /// Questions whose latest answer is correct.
  final int correctNow;

  /// Every answer given (a question answered twice counts twice).
  final int answers;
  final int correctAnswers;

  int get remaining => total - attempted;

  /// Share of all answers that were correct; null before any answer.
  double? get accuracy => answers == 0 ? null : correctAnswers / answers;
}
