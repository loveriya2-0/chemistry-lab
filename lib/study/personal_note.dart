import 'package:flutter/foundation.dart';

/// A note the student wrote themselves, in any language (Hindi, English or
/// Hinglish). Kept apart from the app's checked content and never mixed
/// into it.
///
/// Curriculum items are stored by id, so a note stays attached to the
/// right board, class, chapter and topic whatever the UI language.
@immutable
class PersonalNote {
  const PersonalNote({
    required this.id,
    required this.boardId,
    required this.classLevel,
    required this.chapterId,
    this.topicId,
    required this.text,
    this.pinned = false,
    this.favourite = false,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String boardId;
  final int classLevel;
  final String chapterId;

  /// Null for a note on the whole chapter.
  final String? topicId;
  final String text;

  /// Pinned notes are listed first.
  final bool pinned;
  final bool favourite;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isBlank => text.trim().isEmpty;

  /// First line, for list rows.
  String get headline {
    final line = text.trim().split('\n').first.trim();
    return line.length <= 80 ? line : '${line.substring(0, 80)}…';
  }

  PersonalNote copyWith({String? text, bool? pinned, bool? favourite, DateTime? updatedAt}) => PersonalNote(
        id: id,
        boardId: boardId,
        classLevel: classLevel,
        chapterId: chapterId,
        topicId: topicId,
        text: text ?? this.text,
        pinned: pinned ?? this.pinned,
        favourite: favourite ?? this.favourite,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  static const schemaVersion = 1;

  Map<String, Object?> toJson() => {
        'v': schemaVersion,
        'id': id,
        'boardId': boardId,
        'classLevel': classLevel,
        'chapterId': chapterId,
        'topicId': topicId,
        'text': text,
        'pinned': pinned,
        'favourite': favourite,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory PersonalNote.fromJson(Map<String, Object?> json) => PersonalNote(
        id: json['id']! as String,
        boardId: json['boardId']! as String,
        classLevel: json['classLevel']! as int,
        chapterId: json['chapterId']! as String,
        topicId: json['topicId'] as String?,
        text: json['text']! as String,
        pinned: json['pinned'] as bool? ?? false,
        favourite: json['favourite'] as bool? ?? false,
        createdAt: DateTime.parse(json['createdAt']! as String),
        updatedAt: DateTime.parse(json['updatedAt']! as String),
      );
}
