import 'package:flutter/foundation.dart';

import 'content_text.dart';
import 'models/syllabus.dart' show Json;

/// A board whose syllabus follows the same textbook chapters as another
/// board reuses that board's source-checked notes and practice questions
/// instead of keeping a second copy.
///
/// Only explicitly mapped chapters and topics are shared. Previous-year
/// questions are never shared (they belong to the other board's papers),
/// and links to the other board's practical list are dropped.
@immutable
class SharedContent {
  const SharedContent({required this.fromBoard, required this.topicMap, required this.basis});

  /// `{"fromBoard": "cbse", "basis": {...}, "chapters": [{"from", "to"}], "topics": [{"from", "to"}]}`.
  /// A chapter pair shares the chapter and every topic under it, with the
  /// chapter id as the topic-id prefix ("cbse-12-ch01-t1.1" →
  /// "up-12-ch01-t1.1"). A topic pair shares that one topic only.
  factory SharedContent.fromJson(Json json, {required Map<String, List<String>> sourceTopicsByChapter}) {
    final map = <String, String>{};
    void add(String from, String to) {
      if (map.containsKey(from)) throw FormatException('Shared content maps "$from" twice');
      map[from] = to;
    }

    for (final c in (json['chapters'] as List<Object?>? ?? const [])) {
      final from = (c! as Json)['from']! as String;
      final to = (c as Json)['to']! as String;
      add(from, to);
      for (final t in sourceTopicsByChapter[from] ?? const <String>[]) {
        if (!t.startsWith('$from-')) throw FormatException('Topic "$t" does not start with its chapter id "$from"');
        add(t, '$to${t.substring(from.length)}');
      }
    }
    for (final t in (json['topics'] as List<Object?>? ?? const [])) {
      add((t! as Json)['from']! as String, (t as Json)['to']! as String);
    }
    return SharedContent(
      fromBoard: json['fromBoard']! as String,
      topicMap: map,
      basis: ContentText.fromJson(json['basis']! as Json),
    );
  }

  /// Board whose notes and questions are reused.
  final String fromBoard;

  /// Source chapter/topic id → this board's chapter/topic id.
  final Map<String, String> topicMap;

  /// Why sharing is valid (e.g. the same textbook chapters), shown nowhere
  /// as an official claim; kept for review.
  final ContentText basis;

  /// Rewrites an id belonging to [fromBoard] for [toBoard]
  /// ("qt-cbse-12-ch01-t1.1-1" → "qt-up-12-ch01-t1.1-1"), so saved progress
  /// and bookmarks never mix between boards.
  static String rewriteId(String id, String fromBoard, String toBoard) {
    final from = '$fromBoard-';
    final i = id.indexOf(from);
    if (i < 0) return '$toBoard~$id';
    return '${id.substring(0, i)}$toBoard-${id.substring(i + from.length)}';
  }

  /// The note re-targeted at this board, or null when its topic is not shared.
  Json? mapNote(Json note, String toBoard) {
    final target = topicMap[note['targetId']! as String];
    if (target == null) return null;
    return {
      ...note,
      'id': rewriteId(note['id']! as String, fromBoard, toBoard),
      'targetId': target,
      'covers': [
        for (final c in (note['covers'] as List<Object?>? ?? const []))
          ?topicMap[c! as String],
      ],
      // The other board's practical list does not apply here.
      'practicalIds': const <String>[],
    };
  }

  /// The question re-targeted at this board, or null when its topic is not shared.
  Json? mapQuestion(Json question, String toBoard, {required String Function(String topicId) chapterOf, required int Function(String topicId) classOf}) {
    final target = topicMap[question['topicId']! as String];
    if (target == null) return null;
    return {
      ...question,
      'id': rewriteId(question['id']! as String, fromBoard, toBoard),
      'topicId': target,
      'chapterId': chapterOf(target),
      'classLevel': classOf(target),
    };
  }
}
