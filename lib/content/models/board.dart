import 'package:flutter/foundation.dart';

import '../content_text.dart';

/// Whether a board's syllabus is in the app yet.
enum BoardStatus {
  available,

  /// Listed for selection but has no syllabus data: never show chapters,
  /// PYQs or any content for it.
  comingSoon;

  static BoardStatus parse(String value) => switch (value) {
        'available' => available,
        'comingSoon' => comingSoon,
        _ => throw FormatException('Unknown board status "$value"'),
      };
}

enum BoardScope {
  national,
  state;

  static BoardScope parse(String value) => values.byName(value);
}

/// A syllabus a board publishes for one academic year.
@immutable
class CurriculumRef {
  const CurriculumRef({
    required this.academicYear,
    required this.manifestPath,
    required this.status,
  });

  factory CurriculumRef.fromJson(Map<String, Object?> json) => CurriculumRef(
        academicYear: json['academicYear']! as String,
        manifestPath: json['manifest']! as String,
        status: json['status']! as String,
      );

  final String academicYear;

  /// Relative to `assets/content/`.
  final String manifestPath;
  final String status;
}

/// An exam board (CBSE, CISCE, a state board…).
///
/// Every board's syllabus is stored separately, so adding one never touches
/// another board's data.
@immutable
class Board {
  const Board({
    required this.id,
    required this.order,
    required this.scope,
    required this.state,
    required this.status,
    required this.name,
    required this.officialName,
    required this.curricula,
  });

  factory Board.fromJson(Map<String, Object?> json) => Board(
        id: json['id']! as String,
        order: json['order']! as int,
        scope: BoardScope.parse(json['scope']! as String),
        state: json['state'] as String?,
        status: BoardStatus.parse(json['status']! as String),
        name: ContentText.fromJson(json['name']! as Map<String, Object?>),
        officialName: contentTextOrNull(json['officialName']),
        curricula: [
          for (final c in json['curricula']! as List<Object?>)
            CurriculumRef.fromJson(c! as Map<String, Object?>),
        ],
      );

  final String id;
  final int order;
  final BoardScope scope;

  /// Indian state for state boards, null for national boards.
  final String? state;
  final BoardStatus status;
  final ContentText name;

  /// Filled only once verified from the board's own website.
  final ContentText? officialName;
  final List<CurriculumRef> curricula;

  bool get isAvailable => status == BoardStatus.available;

  /// Most recent academic year, or null for a coming-soon board.
  CurriculumRef? get latestCurriculum => curricula.isEmpty
      ? null
      : (curricula.toList()..sort((a, b) => b.academicYear.compareTo(a.academicYear))).first;
}

/// All boards the app knows about, in display order.
@immutable
class BoardRegistry {
  const BoardRegistry(this.boards);

  factory BoardRegistry.fromJson(Map<String, Object?> json) => BoardRegistry(
        [
          for (final b in json['boards']! as List<Object?>)
            Board.fromJson(b! as Map<String, Object?>),
        ]..sort((a, b) => a.order.compareTo(b.order)),
      );

  final List<Board> boards;

  List<Board> get available => boards.where((b) => b.isAvailable).toList();
  List<Board> get comingSoon => boards.where((b) => !b.isAvailable).toList();

  Board? byId(String id) {
    for (final b in boards) {
      if (b.id == id) return b;
    }
    return null;
  }
}
