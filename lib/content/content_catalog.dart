import 'package:flutter/foundation.dart';

import 'content_repository.dart';
import 'shared_content.dart';
import 'models/board.dart';
import 'models/chemical_entry.dart';
import 'models/concept.dart';
import 'models/practical_coverage.dart';
import 'models/practical_guide.dart';
import 'models/practice_question.dart';
import 'models/pyq.dart';
import 'models/reaction_lab.dart';
import 'models/syllabus.dart';
import 'models/topic_note.dart';

/// A topic together with the chapter and class it belongs to.
@immutable
class TopicLocation {
  const TopicLocation({required this.syllabus, required this.chapter, required this.topic});

  final ClassSyllabus syllabus;
  final Chapter chapter;
  final Topic topic;
}

/// Where an interactive lab is offered in one syllabus.
@immutable
class LabPlacement {
  const LabPlacement({required this.labId, required this.location});

  final String labId;
  final TopicLocation location;
}

/// One board's latest syllabus, fully loaded and indexed.
class LoadedCurriculum {
  LoadedCurriculum(
    this.manifest,
    List<ClassSyllabus> classes, {
    this.concepts = const {},
    this.chemicals = const {},
    this.notes = const [],
    this.questions = const [],
    this.pyqs = const [],
    this.reagents = const {},
    this.reactions = const {},
    this.guides = const {},
  }) : classes = {for (final c in classes) c.classLevel: c} {
    for (final c in classes) {
      for (final ch in c.chapters) {
        _chapters[ch.id] = (c, ch);
        for (final t in ch.topics.expand((t) => t.selfAndDescendants)) {
          _topics[t.id] = TopicLocation(syllabus: c, chapter: ch, topic: t);
          _topicOrder[t.id] = _topicOrder.length;
        }
      }
    }
    for (final n in notes) {
      if (!n.review.isPublishable) continue;
      for (final id in n.allTargetIds) {
        _noteFor[id] = n;
      }
    }
  }

  final CurriculumManifest manifest;
  final Map<int, ClassSyllabus> classes;

  /// Concept library by id (board-independent).
  final Map<String, Concept> concepts;

  /// Chemical and reaction cards by id (board-independent).
  final Map<String, ChemicalEntry> chemicals;

  /// Topic notes of this syllabus.
  final List<TopicNote> notes;

  /// Practice questions written from the textbook (not PYQs).
  final List<PracticeQuestion> questions;

  /// Previous-year questions entered from official papers.
  final List<PyqQuestion> pyqs;

  /// Reaction-lab shelf items by id (board-independent).
  final Map<String, LabReagent> reagents;

  /// Reaction-engine experiments by id (board-independent); where this
  /// board offers them is [CurriculumManifest.reactionPlacements].
  final Map<String, ReactionLab> reactions;

  /// Published reaction labs placed on [topic] or its sub-topics.
  List<ReactionLab> reactionsForTopic(Topic topic) {
    final ids = {for (final t in topic.selfAndDescendants) t.id};
    return [
      for (final e in manifest.reactionPlacements.entries)
        if (reactions[e.key] case final r? when r.review.isPublishable && e.value.any(ids.contains)) r,
    ];
  }

  /// Every placement of a published reaction lab in one class, in manifest
  /// order (a lab placed on two topics appears twice).
  List<(ReactionLab, TopicLocation)> reactionsForClass(int classLevel) => [
        for (final e in manifest.reactionPlacements.entries)
          if (reactions[e.key] case final r? when r.review.isPublishable)
            for (final t in e.value)
              if (_topics[t] case final loc? when loc.syllabus.classLevel == classLevel) (r, loc),
      ];

  /// Where [reactionId] is first placed in this syllabus.
  TopicLocation? reactionLocation(String reactionId) =>
      manifest.reactionPlacements[reactionId]?.map((t) => _topics[t]).nonNulls.firstOrNull;

  /// Practical guides by lab id (board-independent).
  final Map<String, PracticalGuide> guides;

  /// The published guide for an interactive lab, if one has been written.
  PracticalGuide? guideFor(String labId) => switch (guides[labId]) {
        final g? when g.review.isPublishable => g,
        _ => null,
      };

  /// Interactive labs for one listed practical: the lab built for it, then
  /// labs related to it.
  List<LabPracticalLink> labLinksForPractical(BoardPractical practical) => [
        if (practical.labId case final id?)
          LabPracticalLink(labId: id, practicalId: practical.id, relation: LabRelation.official),
        for (final l in manifest.labLinks)
          if (l.practicalId == practical.id && l.labId != practical.labId) l,
      ];

  /// What a listed practical can do in the app. Only a practical the
  /// manifest declares covered is (fully or partially) interactive; one
  /// with only related labs, or none, is not implemented.
  PracticalStatus practicalStatus(BoardPractical practical) {
    final labs = [
      for (final l in labLinksForPractical(practical))
        if (guideFor(l.labId) != null) l.labId,
    ];
    final coverage = manifest.practicalCoverage[practical.id];
    return PracticalStatus(
      level: coverage?.level ?? PracticalLevel.notImplemented,
      labIds: labs.toSet().toList(),
      coverage: coverage,
    );
  }

  /// Listed practicals that [labId] is linked to, in class order.
  List<({int classLevel, BoardPractical practical, LabPracticalLink link})> practicalsForLab(String labId) => [
        for (final level in classLevels)
          for (final p in classes[level]!.practicals)
            for (final l in labLinksForPractical(p))
              if (l.labId == labId) (classLevel: level, practical: p, link: l),
      ];

  /// Labs linked to one class's listed practicals (official or related).
  Set<String> labsLinkedToClass(int classLevel) => {
        for (final p in classes[classLevel]?.practicals ?? const <BoardPractical>[])
          for (final l in labLinksForPractical(p)) l.labId,
      };

  /// Every topic placement of [labId], in class and syllabus order.
  List<LabPlacement> placementsOf(String labId) => [
        for (final level in classLevels)
          for (final p in labsForClass(level))
            if (p.labId == labId) p,
      ];

  List<PyqQuestion> pyqsForClass(int classLevel) => [for (final q in pyqs) if (q.classLevel == classLevel) q];
  final _chapters = <String, (ClassSyllabus, Chapter)>{};
  final _topics = <String, TopicLocation>{};
  final _topicOrder = <String, int>{};
  final _noteFor = <String, TopicNote>{};

  /// The published note that explains [topicOrChapterId], if any.
  TopicNote? noteFor(String topicOrChapterId) => _noteFor[topicOrChapterId];

  /// Published notes for [topic] and its sub-topics, each note once, in
  /// textbook order.
  List<TopicNote> notesForTopic(Topic topic) {
    final out = <TopicNote>[];
    for (final t in topic.selfAndDescendants) {
      final n = _noteFor[t.id];
      if (n != null && !out.contains(n)) out.add(n);
    }
    return out;
  }

  /// Topics whose notes link [conceptId], in syllabus order.
  List<TopicLocation> topicsForConcept(String conceptId) => _linkedTopics((n) => n.conceptIds.contains(conceptId));

  /// Topics whose notes link [chemicalId], in syllabus order.
  List<TopicLocation> topicsForChemical(String chemicalId) => _linkedTopics((n) => n.chemicalIds.contains(chemicalId));

  List<TopicLocation> _linkedTopics(bool Function(TopicNote) links) => [
        for (final n in notes)
          if (n.review.isPublishable && links(n)) ?_topics[n.targetId],
      ];

  /// Published practice questions, optionally narrowed to a chapter or to
  /// a topic with its sub-topics.
  List<PracticeQuestion> practiceQuestions({required int classLevel, String? chapterId, Topic? topic}) {
    final topicIds = topic == null ? null : {for (final t in topic.selfAndDescendants) t.id};
    return [
      for (final q in questions)
        if (q.review.isPublishable &&
            q.classLevel == classLevel &&
            (chapterId == null || q.chapterId == chapterId) &&
            (topicIds == null || topicIds.contains(q.topicId)))
          q,
    ];
  }

  /// Published, in-syllabus PYQs.
  Iterable<PyqQuestion> get publishedPyqs => pyqs.where((q) => q.isPublishable);

  /// Exam years whose papers have been entered; the importance window.
  List<int> get enteredExamYears => {for (final p in manifest.pyqPapers) p.examYear}.toList()..sort();

  /// Number of official papers entered for [classLevel].
  int pyqPaperCount(int classLevel) => manifest.pyqPapers.where((p) => p.classLevel == classLevel).length;

  /// Importance of a chapter, computed from the entered PYQs.
  ExamImportance chapterImportance(String chapterId) => ExamImportance.fromQuestions(
        publishedPyqs.where((q) => q.chapterId == chapterId),
        examYears: enteredExamYears,
      );

  /// Importance of a topic (with its sub-topics), computed from the PYQs.
  ExamImportance topicImportance(Topic topic) {
    final ids = {for (final t in topic.selfAndDescendants) t.id};
    return ExamImportance.fromQuestions(
      publishedPyqs.where((q) => q.topicId != null && ids.contains(q.topicId)),
      examYears: enteredExamYears,
    );
  }

  /// PYQs about [topic] or its sub-topics.
  List<PyqQuestion> pyqsForTopic(Topic topic) {
    final ids = {for (final t in topic.selfAndDescendants) t.id};
    return [for (final q in publishedPyqs) if (q.topicId != null && ids.contains(q.topicId)) q];
  }

  List<int> get classLevels => classes.keys.toList()..sort();

  (ClassSyllabus, Chapter)? chapter(String id) => _chapters[id];
  TopicLocation? topic(String id) => _topics[id];

  /// Lab id -> topic ids for every interactive lab: the hand-built labs
  /// plus the published reaction labs.
  Iterable<MapEntry<String, List<String>>> get _allLabPlacements => [
        ...manifest.labPlacements.entries,
        for (final e in manifest.reactionPlacements.entries)
          if (reactions[e.key]?.review.isPublishable ?? false) e,
      ];

  /// Interactive labs offered under [topicId] (exact topic only).
  List<String> labsForTopic(String topicId) => [
        for (final e in _allLabPlacements)
          if (e.value.contains(topicId)) e.key,
      ];

  /// All lab placements in one class, in chapter/topic order.
  List<LabPlacement> labsForClass(int classLevel) {
    final out = <LabPlacement>[];
    for (final e in _allLabPlacements) {
      for (final t in e.value) {
        final loc = _topics[t];
        if (loc != null && loc.syllabus.classLevel == classLevel) {
          out.add(LabPlacement(labId: e.key, location: loc));
        }
      }
    }
    // Syllabus order; labs on the same topic keep their manifest order.
    final indexed = out.indexed.toList()
      ..sort((a, b) {
        final byTopic = _topicOrder[a.$2.location.topic.id]!.compareTo(_topicOrder[b.$2.location.topic.id]!);
        return byTopic != 0 ? byTopic : a.$1.compareTo(b.$1);
      });
    return [for (final (_, p) in indexed) p];
  }
}

/// Every board in the registry plus the syllabus of each available board,
/// loaded once at startup so screens can read it synchronously.
class ContentCatalog {
  ContentCatalog(this.registry, this._curricula);

  static Future<ContentCatalog> load(ContentRepository repository) async {
    final registry = await repository.boards();
    final curricula = <String, LoadedCurriculum>{};
    final manifests = {for (final board in registry.available) board.id: await repository.curriculum(board.id)};
    // Boards that reuse another board's content load after it.
    final order = [
      ...registry.available.where((b) => manifests[b.id]!.sharedContent == null),
      ...registry.available.where((b) => manifests[b.id]!.sharedContent != null),
    ];
    for (final board in order) {
      final manifest = manifests[board.id]!;
      final classes = await repository.allClasses(board.id, academicYear: manifest.academicYear);
      final shared = await _sharedContent(repository, board.id, manifest, classes, curricula, manifests);
      curricula[board.id] = LoadedCurriculum(
        manifest,
        classes,
        concepts: {
          for (final file in manifest.conceptFiles)
            for (final c in (await repository.jsonList(file)).map(Concept.fromJson)) c.id: c,
        },
        chemicals: {
          for (final file in manifest.chemicalFiles)
            for (final c in (await repository.jsonList(file)).map(ChemicalEntry.fromJson)) c.id: c,
        },
        notes: [
          for (final file in manifest.noteFiles)
            for (final n in await repository.jsonList(file)) TopicNote.fromJson(n),
          ...shared.notes.map(TopicNote.fromJson),
        ],
        questions: [
          for (final file in manifest.questionFiles)
            for (final q in await repository.jsonList(file)) PracticeQuestion.fromJson(q),
          ...shared.questions.map(PracticeQuestion.fromJson),
        ],
        pyqs: [
          for (final file in manifest.pyqFiles)
            for (final q in await repository.jsonList(file)) PyqQuestion.fromJson(q),
        ],
        reagents: {
          for (final file in manifest.reagentFiles)
            for (final r in (await repository.jsonList(file)).map(LabReagent.fromJson)) r.id: r,
        },
        reactions: {
          for (final file in manifest.reactionFiles)
            for (final r in (await repository.jsonList(file)).map(ReactionLab.fromJson)) r.id: r,
        },
        guides: {
          for (final file in manifest.guideFiles)
            for (final g in (await repository.jsonList(file)).map(PracticalGuide.fromJson)) g.id: g,
        },
      );
    }
    return ContentCatalog(registry, curricula);
  }

  /// Notes and questions [boardId] reuses from another board, re-targeted at
  /// its own topic ids. Previous-year questions are never shared.
  static Future<({List<Json> notes, List<Json> questions})> _sharedContent(
    ContentRepository repository,
    String boardId,
    CurriculumManifest manifest,
    List<ClassSyllabus> classes,
    Map<String, LoadedCurriculum> loaded,
    Map<String, CurriculumManifest> manifests,
  ) async {
    final json = manifest.sharedContent;
    if (json == null) return (notes: const <Json>[], questions: const <Json>[]);
    final fromBoard = json['fromBoard']! as String;
    final source = loaded[fromBoard];
    final sourceManifest = manifests[fromBoard];
    if (source == null || sourceManifest == null) {
      throw StateError('Board "$boardId" shares content from "$fromBoard", which is not available');
    }
    final shared = SharedContent.fromJson(json, sourceTopicsByChapter: {
      for (final c in source.classes.values)
        for (final ch in c.chapters) ch.id: [for (final t in ch.topics.expand((t) => t.selfAndDescendants)) t.id],
    });
    final chapterOf = <String, String>{};
    final classOf = <String, int>{};
    for (final c in classes) {
      for (final ch in c.chapters) {
        chapterOf[ch.id] = ch.id;
        classOf[ch.id] = c.classLevel;
        for (final t in ch.topics.expand((t) => t.selfAndDescendants)) {
          chapterOf[t.id] = ch.id;
          classOf[t.id] = c.classLevel;
        }
      }
    }
    String chapter(String id) => chapterOf[id] ?? (throw StateError('Shared content targets unknown "$id" in $boardId'));
    int level(String id) => classOf[id] ?? (throw StateError('Shared content targets unknown "$id" in $boardId'));
    return (
      notes: [
        for (final file in sourceManifest.noteFiles)
          for (final n in await repository.jsonList(file))
            ?shared.mapNote(n, boardId),
      ],
      questions: [
        for (final file in sourceManifest.questionFiles)
          for (final q in await repository.jsonList(file))
            ?shared.mapQuestion(q, boardId, chapterOf: chapter, classOf: level),
      ],
    );
  }

  final BoardRegistry registry;
  final Map<String, LoadedCurriculum> _curricula;

  /// Null for unknown boards and boards that are coming soon.
  LoadedCurriculum? curriculum(String boardId) => _curricula[boardId];

  ClassSyllabus? classSyllabus(String boardId, int classLevel) =>
      _curricula[boardId]?.classes[classLevel];
}
