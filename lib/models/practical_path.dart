import 'package:flutter/foundation.dart';

import '../content/models/syllabus.dart';
import 'practical.dart';

/// Where an interactive lab sits in a board's syllabus:
/// Board → Class → Chapter → Topic → Lab, or, for a lab opened from the
/// board's practical list, Board → Class → Practical → Lab. Passed to Focus
/// Mode and the attempt recorder so they can show and save the context
/// under the right class.
@immutable
class PracticalPath {
  const PracticalPath({
    required this.boardId,
    required this.classLevel,
    required this.practical,
    this.chapter,
    this.topic,
    this.listedPractical,
  }) : assert(topic != null || listedPractical != null, 'a lab is opened from a topic or a listed practical');

  final String boardId;
  final int classLevel;

  /// The chapter of [topic], or the listed practical's chapter if it has one.
  final Chapter? chapter;

  /// The verified topic (or sub-topic) the lab is offered under; null when
  /// it was opened from [listedPractical].
  final Topic? topic;

  /// The practical in the board's list this lab was opened for.
  final BoardPractical? listedPractical;
  final Practical practical;
}
