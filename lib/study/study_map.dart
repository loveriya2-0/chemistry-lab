import '../content/content_catalog.dart';
import '../content/models/syllabus.dart';
import 'study_progress_store.dart';

/// Chapter completion counted over the units a student can mark: each
/// top-level topic, or the chapter itself when it has no topics.
class ChapterStudy {
  const ChapterStudy({required this.chapter, required this.studied, required this.total, required this.started});

  final Chapter chapter;

  /// Units counted as studied (see [TopicStatus.isStudied]).
  final int studied;
  final int total;

  /// Units in progress, studied or marked for revision.
  final int started;

  double get fraction => total == 0 ? 0 : studied / total;
  bool get isComplete => total > 0 && studied == total;
  bool get isStarted => started > 0;
}

/// Order and progress helpers over the verified syllabus.
abstract final class StudyMap {
  /// Status of a chapter's unit list: its top-level topics, or the chapter
  /// itself for a chapter without topics.
  static ChapterStudy chapter(Chapter chapter, StudyProgressStore store) {
    final statuses = chapter.topics.isEmpty
        ? [store.statusOf(chapter.id)]
        : [for (final t in chapter.topics) store.effectiveStatus(t)];
    return ChapterStudy(
      chapter: chapter,
      studied: statuses.where((s) => s.isStudied).length,
      total: statuses.length,
      started: statuses.where((s) => s != TopicStatus.notStarted).length,
    );
  }

  /// The status shown for any topic node: a top-level topic uses its
  /// sub-topics too, a sub-topic only its own mark.
  static TopicStatus statusFor(Topic topic, StudyProgressStore store) => store.effectiveStatus(topic);

  /// Previous and next pages for [topic]: top-level topics run through the
  /// whole class in syllabus order (crossing chapters); a sub-topic steps
  /// through its siblings.
  static (TopicLocation?, TopicLocation?) neighbours(LoadedCurriculum curriculum, TopicLocation here) {
    final syllabus = here.syllabus;
    final parent = _parentOf(here.chapter, here.topic);
    final List<TopicLocation> sequence;
    if (parent == null) {
      sequence = [
        for (final ch in syllabus.chapters)
          for (final t in ch.topics) TopicLocation(syllabus: syllabus, chapter: ch, topic: t),
      ];
    } else {
      sequence = [for (final t in parent.subtopics) TopicLocation(syllabus: syllabus, chapter: here.chapter, topic: t)];
    }
    final i = sequence.indexWhere((l) => l.topic.id == here.topic.id);
    if (i < 0) return (null, null);
    return (i > 0 ? sequence[i - 1] : null, i < sequence.length - 1 ? sequence[i + 1] : null);
  }

  /// The topic directly containing [topic], or null for a top-level topic.
  static Topic? parentOf(Chapter chapter, Topic topic) => _parentOf(chapter, topic);

  static Topic? _parentOf(Chapter chapter, Topic topic) {
    Topic? search(Iterable<Topic> list, Topic? parent) {
      for (final t in list) {
        if (t.id == topic.id) return parent;
        final found = search(t.subtopics, t);
        if (found != null) return found;
      }
      return null;
    }

    return search(chapter.topics, null);
  }

  /// The top-level topic that contains [topic] (itself if top-level).
  static Topic topLevel(Chapter chapter, Topic topic) =>
      chapter.topics.firstWhere((t) => t.selfAndDescendants.any((x) => x.id == topic.id), orElse: () => topic);
}
