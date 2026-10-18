import 'package:flutter/foundation.dart';

import '../content/content_catalog.dart';
import '../content/content_text.dart';
import '../content/models/chemical_entry.dart';
import '../content/models/concept.dart';
import '../content/models/syllabus.dart';

/// What the student is looking at when they open the AI tutor.
///
/// Built only from the app's verified content, so the tutor knows the
/// board, class, chapter and topic and can stay on the textbook's facts.
/// Board-independent: any board's [LoadedCurriculum] can produce one.
@immutable
class TutorContext {
  const TutorContext({
    required this.boardName,
    required this.academicYear,
    required this.subject,
    this.classLevel,
    this.chapter,
    this.topic,
    this.verifiedFacts = const [],
  });

  /// Context for a syllabus topic and the notes that explain it.
  factory TutorContext.forTopic(LoadedCurriculum c, TopicLocation loc, {required String boardName}) {
    final notes = c.notesForTopic(loc.topic);
    return TutorContext(
      boardName: boardName,
      academicYear: c.manifest.academicYear,
      classLevel: loc.syllabus.classLevel,
      chapter: _chapterLabel(loc.chapter),
      topic: '${loc.topic.number} ${_bilingual(loc.topic.title)}',
      subject: loc.topic.title.en,
      verifiedFacts: [
        for (final n in notes) ...[
          n.definition.en,
          for (final p in n.keyPoints) p.en,
          ...n.formulas,
        ],
      ],
    );
  }

  /// Context for a whole chapter (its topic list, or its note if it has
  /// no topics).
  factory TutorContext.forChapter(LoadedCurriculum c, ClassSyllabus syllabus, Chapter chapter, {required String boardName}) {
    final note = chapter.topics.isEmpty ? c.noteFor(chapter.id) : null;
    return TutorContext(
      boardName: boardName,
      academicYear: c.manifest.academicYear,
      classLevel: syllabus.classLevel,
      chapter: _chapterLabel(chapter),
      subject: chapter.title.en,
      verifiedFacts: [
        for (final t in chapter.topics) 'Topic ${t.number}: ${t.title.en}',
        if (note != null) ...[note.definition.en, for (final p in note.keyPoints) p.en],
      ],
    );
  }

  /// Context for a chemical or named reaction card.
  factory TutorContext.forChemical(LoadedCurriculum c, ChemicalEntry x, {required String boardName}) {
    final where = c.topicsForChemical(x.id).firstOrNull;
    return TutorContext(
      boardName: boardName,
      academicYear: c.manifest.academicYear,
      classLevel: where?.syllabus.classLevel,
      chapter: where == null ? null : _chapterLabel(where.chapter),
      topic: where == null ? null : '${where.topic.number} ${_bilingual(where.topic.title)}',
      subject: [_bilingual(x.name), if (x.formula != null) '(${x.formula})'].join(' '),
      verifiedFacts: [x.explanation.en, ...x.equations, for (final u in x.uses) 'Use: ${u.en}'],
    );
  }

  /// Context for a concept from the concept library.
  factory TutorContext.forConcept(LoadedCurriculum c, Concept k, {required int classLevel, required String boardName}) {
    final where = c.topicsForConcept(k.id).where((l) => l.syllabus.classLevel == classLevel).firstOrNull;
    return TutorContext(
      boardName: boardName,
      academicYear: c.manifest.academicYear,
      classLevel: classLevel,
      chapter: where == null ? null : _chapterLabel(where.chapter),
      topic: where == null ? null : '${where.topic.number} ${_bilingual(where.topic.title)}',
      subject: _bilingual(k.title),
      verifiedFacts: [for (final t in k.sections.values) t.en, ...k.equations],
    );
  }

  final String boardName;
  final String academicYear;
  final int? classLevel;
  final String? chapter;
  final String? topic;

  /// What "Ask AI" was pressed on.
  final String subject;

  /// Lines from the app's checked notes (English), given to the tutor as
  /// the reference it must agree with.
  final List<String> verifiedFacts;

  /// "Class 10 › Ch 2 › 2.3" style breadcrumb for the screen header.
  String breadcrumb(String Function(int) className) => [
        if (classLevel != null) className(classLevel!),
        ?chapter,
        ?topic,
      ].join(' › ');

  static String _chapterLabel(Chapter ch) =>
      [if (ch.number != null) 'Chapter ${ch.number}:', _bilingual(ch.title)].join(' ');

  // Both titles, so Hindi answers use the same NCERT terms as the app.
  static String _bilingual(ContentText t) => t.hasHindi && t.hi != t.en ? '${t.en} (${t.hi})' : t.en;
}
