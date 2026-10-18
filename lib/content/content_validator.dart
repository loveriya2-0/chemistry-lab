import 'content_catalog.dart';
import 'content_text.dart';
import 'models/board.dart';
import 'models/concept.dart';
import 'models/practical_coverage.dart';
import 'models/pyq.dart';
import 'models/review.dart';
import 'models/syllabus.dart';

/// Integrity rules every board's data must pass before it ships.
/// Returns human-readable problems; empty means valid.
abstract final class ContentValidator {
  static List<String> registry(BoardRegistry registry) {
    final issues = <String>[];
    final ids = <String>{};
    for (final b in registry.boards) {
      if (!ids.add(b.id)) issues.add('Duplicate board id "${b.id}"');
      if (b.name.en.trim().isEmpty) issues.add('Board "${b.id}" has no name');
      if (b.isAvailable && b.curricula.isEmpty) {
        issues.add('Board "${b.id}" is available but has no syllabus');
      }
      // A coming-soon board must not carry any syllabus or content.
      if (!b.isAvailable && b.curricula.isNotEmpty) {
        issues.add('Board "${b.id}" is coming soon but lists a syllabus');
      }
    }
    return issues;
  }

  static List<String> curriculum(CurriculumManifest manifest, List<ClassSyllabus> classes) {
    final issues = <String>[];
    final ids = <String>{};
    void unique(String id) {
      if (!ids.add(id)) issues.add('Duplicate id "$id"');
    }

    final sourceIds = {for (final s in manifest.sources) s.id};
    for (final s in manifest.sources) {
      if (!s.url.startsWith('https://')) issues.add('Source "${s.id}" has no https URL');
    }

    final chapterIds = <String>{};
    final practicalIds = <String>{};
    for (final c in classes) {
      for (final ch in c.chapters) {
        chapterIds.add(ch.id);
      }
      for (final p in c.practicals) {
        practicalIds.add(p.id);
      }
    }

    for (final c in classes) {
      final where = '${manifest.boardId} ${manifest.academicYear} Class ${c.classLevel}';
      if (c.boardId != manifest.boardId || c.academicYear != manifest.academicYear) {
        issues.add('$where: file belongs to ${c.boardId} ${c.academicYear}');
      }
      for (final s in c.sourceIds) {
        if (!sourceIds.contains(s)) issues.add('$where: unknown source "$s"');
      }

      for (final ch in c.chapters) {
        unique(ch.id);
        if (ch.title.en.trim().isEmpty) issues.add('$where: chapter ${ch.id} has no title');
        if (!ch.title.hasHindi) issues.add('$where: chapter ${ch.id} has no Hindi title');
        if (ch.inYearEndExam && ch.weightage.scope != WeightageScope.notPublished && ch.weightage.marks <= 0) {
          issues.add('$where: exam chapter ${ch.id} has no marks');
        }
        if (ch.inYearEndExam && ch.weightage.scope == WeightageScope.notPublished && ch.weightage.marks != 0) {
          issues.add('$where: chapter ${ch.id} has marks although the board publishes none');
        }
        if (!ch.inYearEndExam && ch.weightage.scope != WeightageScope.notInYearEndExam) {
          issues.add('$where: formative-only chapter ${ch.id} carries exam marks');
        }
        for (final t in ch.topics.expand((t) => t.selfAndDescendants)) {
          unique(t.id);
          if (t.title.en.trim().isEmpty) issues.add('$where: topic ${t.id} has no title');
        }
        for (final p in ch.practicalIds) {
          if (!practicalIds.contains(p)) issues.add('$where: ${ch.id} links unknown practical "$p"');
        }
      }

      for (final p in c.practicals) {
        unique(p.id);
        for (final id in [...p.chapterIds, ...p.relatedChapterIds]) {
          if (!chapterIds.contains(id)) issues.add('$where: practical ${p.id} links unknown chapter "$id"');
        }
        if (p.mapping != PracticalMapping.general && p.chapterIds.isEmpty && p.relatedChapterIds.isEmpty) {
          issues.add('$where: practical ${p.id} is mapped but links no chapter');
        }
      }

      // Unit marks must agree with the chapters that share them.
      for (final u in c.units) {
        for (final ch in c.chapters.where((x) => x.unitId == u.id && x.inYearEndExam)) {
          if (ch.weightage.scope == WeightageScope.unit && ch.weightage.marks != u.marks) {
            issues.add('$where: ${ch.id} marks ${ch.weightage.marks} ≠ unit ${u.id} marks ${u.marks}');
          }
        }
      }
      // Chapter-scoped marks must add up to the theory total (Chemistry), or
      // stay within it (Science, where only the chemistry chapters are listed).
      final chapterScoped = c.examChapters.where((x) => x.weightage.scope == WeightageScope.chapter);
      if (chapterScoped.isNotEmpty) {
        final total = chapterScoped.fold(0, (sum, x) => sum + x.weightage.marks);
        // A Science paper also has physics and biology chapters, which the app
        // does not list, so only its chemistry chapters must fit inside the total.
        final ok = c.subjectId == 'science' ? total <= c.examPattern.theoryMarks : total == c.examPattern.theoryMarks;
        if (!ok) {
          issues.add('$where: chapter marks add to $total, theory total is ${c.examPattern.theoryMarks}');
        }
      }
    }
    // Interactive labs must sit on real topics.
    final topicIds = {
      for (final c in classes)
        for (final ch in c.chapters)
          for (final t in ch.topics.expand((t) => t.selfAndDescendants)) t.id,
    };
    for (final e in manifest.labPlacements.entries) {
      for (final t in e.value) {
        if (!topicIds.contains(t)) issues.add('Lab ${e.key} is placed on unknown topic "$t"');
      }
    }
    // Legacy ids must point at something that exists (or be null).
    for (final e in manifest.legacyIdMap.entries) {
      final to = e.value;
      if (to != null && !chapterIds.contains(to) && !topicIds.contains(to)) {
        issues.add('Legacy id ${e.key} maps to unknown "$to"');
      }
    }
    return issues;
  }

  /// Marks a question type carries in CBSE papers (numericals vary).
  static const marksForType = {
    QuestionType.mcq: {1},
    QuestionType.assertionReason: {1},
    QuestionType.veryShort: {2},
    QuestionType.shortAnswer: {3},
    QuestionType.caseBased: {4},
    QuestionType.longAnswer: {5},
    QuestionType.numerical: {1, 2, 3, 4, 5},
  };

  static final _placeholder = RegExp(r'\b(todo|tbd|lorem|ipsum|placeholder|fixme|xxx|dummy|sample text)\b|example\.invalid', caseSensitive: false);
  /// Template text left in a memory trick ("ABC…", "mnemonic here").
  static final _trickTemplate = RegExp(r'\.\.\.|…|\bABC\b|\b(mnemonic|trick) (here|goes)|यहाँ (ट्रिक|लिखें)', caseSensitive: false);
  static const maxMemoryTricks = 3;

  /// Every practical guide carries at least this many viva questions.
  static const minVivaQuestions = 4;

  /// Bottles that fit on the lab shelf without scrolling (two rows).
  static const maxShelf = 6;
  static final _devanagari = RegExp(r'[ऀ-ॿ]');
  static final _englishWord = RegExp(r'[a-z]{4,}');

  /// Notes, concepts, chemicals, practice questions and PYQs of one loaded
  /// syllabus. [notesForClasses] lists the classes whose every topic must
  /// already have a note.
  static List<String> learningContent(LoadedCurriculum c, {required Set<int> notesForClasses}) {
    final issues = <String>[];
    final sourceIds = {for (final s in c.manifest.sources) s.id};
    final sharesContent = c.manifest.sharedContent != null;

    void text(String where, ContentText t) {
      if (t.en.trim().isEmpty) issues.add('$where: empty English text');
      if (!t.hasHindi) {
        issues.add('$where: no Hindi text');
      } else {
        if (t.hiSource == null) issues.add('$where: Hindi text has no provenance');
        // Identical text is fine only for formulas, numbers and symbols.
        if (t.hi == t.en ? _englishWord.hasMatch(t.en) : !_devanagari.hasMatch(t.hi!)) {
          issues.add('$where: Hindi text is not Hindi ("${t.hi}")');
        }
      }
      for (final s in [t.en, t.hi ?? '']) {
        if (_placeholder.hasMatch(s)) issues.add('$where: placeholder text "$s"');
      }
    }

    void sources(String where, List<SourceRef> refs) {
      if (refs.isEmpty) issues.add('$where: no source');
      for (final r in refs) {
        if (!sourceIds.contains(r.sourceId)) issues.add('$where: unknown source "${r.sourceId}"');
      }
    }

    void published(String where, ReviewStatus r) {
      if (!r.isPublishable) issues.add('$where: review status ${r.name} is not publishable');
    }

    void choices(String where, QuestionType type, List<ContentText> options, int? correct) {
      final isChoice = type == QuestionType.mcq || type == QuestionType.assertionReason;
      if (isChoice && options.isNotEmpty && options.length != 4) issues.add('$where: needs 4 options, has ${options.length}');
      if (options.isNotEmpty && (correct == null || correct < 0 || correct >= options.length)) {
        issues.add('$where: correct option $correct is out of range');
      }
      if (!isChoice && options.isNotEmpty) issues.add('$where: ${type.name} must not have options');
      for (final (i, o) in options.indexed) {
        text('$where option ${i + 1}', o);
      }
    }

    // Topic must exist and sit in the given chapter.
    void placement(String where, int classLevel, String chapterId, String? topicId) {
      final ch = c.chapter(chapterId);
      if (ch == null) {
        issues.add('$where: unknown chapter "$chapterId"');
        return;
      }
      if (ch.$1.classLevel != classLevel) issues.add('$where: chapter $chapterId is not Class $classLevel');
      if (topicId != null) {
        final loc = c.topic(topicId);
        if (loc == null) {
          issues.add('$where: unknown topic "$topicId"');
        } else if (loc.chapter.id != chapterId) {
          issues.add('$where: topic $topicId is not in $chapterId');
        }
      }
    }

    // ---- Notes: every topic of the listed classes explained exactly once.
    final noteIds = <String>{};
    final coveredBy = <String, String>{};
    final linkedConcepts = <String>{};
    final linkedChemicals = <String>{};
    for (final n in c.notes) {
      final where = 'Note ${n.id}';
      if (!noteIds.add(n.id)) issues.add('Duplicate note id "${n.id}"');
      published(where, n.review);
      sources(where, n.sources);
      for (final id in n.allTargetIds) {
        if (c.topic(id) == null && c.chapter(id) == null) issues.add('$where: unknown topic or chapter "$id"');
        final previous = coveredBy[id];
        if (previous != null) issues.add('$where: "$id" is already explained by $previous');
        coveredBy[id] = n.id;
      }
      for (final (i, t) in n.texts.indexed) {
        text('$where text ${i + 1}', t);
      }
      if (n.keyPoints.isEmpty) issues.add('$where: no key points');
      if (n.commonMistakes.isEmpty) issues.add('$where: no common mistakes');
      // Memory tricks are optional, but any that ship must be complete.
      if (n.memoryTricks.length > maxMemoryTricks) issues.add('$where: more than $maxMemoryTricks memory tricks');
      for (final (i, m) in n.memoryTricks.indexed) {
        final at = '$where memory trick ${i + 1}';
        for (final t in [m.trick, m.recall]) {
          for (final x in [t.en, t.hi ?? '']) {
            if (_trickTemplate.hasMatch(x)) issues.add('$at: template text "$x"');
          }
        }
        if (m.trick.en.trim() == m.recall.en.trim()) issues.add('$at: trick and its meaning are the same text');
      }
      if (n.quickRevision case final q?) {
        if (q.points.isEmpty || q.points.length > 3) issues.add('$where: quick revision needs 1–3 points, has ${q.points.length}');
        // The revision formula must come from the note itself, never be new.
        if (q.formula != null && !n.formulas.contains(q.formula)) {
          issues.add('$where: quick-revision formula "${q.formula}" is not one of the note\'s formulas');
        }
      }
      final classLevel = (c.topic(n.targetId)?.syllabus ?? c.chapter(n.targetId)?.$1)?.classLevel;
      final practicals = {for (final p in c.classes[classLevel]?.practicals ?? const <BoardPractical>[]) p.id};
      for (final p in n.practicalIds) {
        if (!practicals.contains(p)) issues.add('$where: unknown practical "$p" for Class $classLevel');
      }
      for (final id in n.conceptIds) {
        if (!c.concepts.containsKey(id)) issues.add('$where: unknown concept "$id"');
        linkedConcepts.add(id);
      }
      for (final id in n.chemicalIds) {
        if (!c.chemicals.containsKey(id)) issues.add('$where: unknown chemical "$id"');
        linkedChemicals.add(id);
      }
    }
    for (final level in notesForClasses) {
      final syllabus = c.classes[level];
      if (syllabus == null) {
        issues.add('Class $level has no syllabus');
        continue;
      }
      for (final ch in syllabus.chapters) {
        final ids = [for (final t in ch.topics.expand((t) => t.selfAndDescendants)) t.id];
        for (final id in ids.isEmpty ? [ch.id] : ids) {
          if (!coveredBy.containsKey(id)) issues.add('Class $level: "$id" has no note');
        }
      }
    }

    // ---- Concept library.
    for (final k in c.concepts.values) {
      final where = 'Concept ${k.id}';
      published(where, k.review);
      sources(where, k.sources);
      text('$where title', k.title);
      for (final s in const [
        ConceptSection.whatIsIt,
        ConceptSection.howItWorks,
        ConceptSection.whyImportant,
        ConceptSection.realLifeUses,
        ConceptSection.rememberForExam,
      ]) {
        final t = k.sections[s];
        if (t == null) {
          issues.add('$where: missing section ${s.name}');
        } else {
          text('$where ${s.name}', t);
        }
      }
      for (final r in k.relatedConceptIds) {
        if (!c.concepts.containsKey(r)) issues.add('$where: unknown related concept "$r"');
      }
      // The library is shared: a board reusing another board's content covers
      // only some chapters, so library completeness is checked on the source board.
      if (!sharesContent && !linkedConcepts.contains(k.id)) issues.add('$where: no topic links to it');
    }

    // ---- Chemicals and reactions.
    for (final x in c.chemicals.values) {
      final where = 'Chemical ${x.id}';
      published(where, x.review);
      sources(where, x.sources);
      for (final (i, t) in x.texts.indexed) {
        text('$where text ${i + 1}', t);
      }
      if (x.uses.isEmpty) issues.add('$where: no uses');
      if (x.properties.isEmpty) issues.add('$where: no properties');
      if (x.kind.name == 'reaction' && x.equations.isEmpty) issues.add('$where: reaction without an equation');
      if (!sharesContent && !linkedChemicals.contains(x.id)) issues.add('$where: no topic links to it');
    }

    // ---- Reaction labs: only reactions already in the checked content.
    final verifiedEquations = {
      for (final n in c.notes)
        if (n.review.isPublishable) ...n.formulas,
      for (final x in c.chemicals.values)
        if (x.review.isPublishable) ...x.equations,
    };
    for (final x in c.reagents.values) {
      text('Reagent ${x.id} name', x.name);
      if (x.hazard case final h?) text('Reagent ${x.id} hazard', h);
      if (!const {'liquid', 'solid', 'tool'}.contains(x.state)) issues.add('Reagent ${x.id}: unknown state "${x.state}"');
    }
    final placed = c.manifest.reactionPlacements;
    for (final r in c.reactions.values) {
      // A board reusing another board's content offers only the labs placed on
      // its own topics; the rest of the shared library is checked on the source board.
      if (sharesContent && !placed.containsKey(r.id)) continue;
      final where = 'Reaction lab ${r.id}';
      published(where, r.review);
      sources(where, r.sources);
      if (!verifiedEquations.contains(r.equation)) {
        issues.add('$where: equation "${r.equation}" is not in any source-checked note or chemical card');
      }
      for (final (i, t) in r.texts.indexed) {
        text('$where text ${i + 1}', t);
      }
      if (r.reactants.isEmpty || r.products.isEmpty) issues.add('$where: needs reactants and products');
      if (r.steps.isEmpty) issues.add('$where: no steps');
      if (r.shelf.toSet().length != r.shelf.length) issues.add('$where: duplicate shelf item');
      if (r.shelf.length > maxShelf) issues.add('$where: more than $maxShelf items on the shelf');
      for (final id in r.shelf) {
        if (!c.reagents.containsKey(id)) issues.add('$where: unknown reagent "$id"');
      }
      final used = {for (final s in r.steps) s.reagentId};
      for (final id in used) {
        if (!r.shelf.contains(id)) issues.add('$where: step reagent "$id" is not on the shelf');
      }
      if (r.shelf.every(used.contains)) issues.add('$where: the shelf has no wrong choice to learn from');
      for (final id in r.hints.keys) {
        if (!r.shelf.contains(id) || used.contains(id)) issues.add('$where: hint for "$id", which is not a wrong choice on the shelf');
      }
      final ml = r.steps.fold(0.0, (sum, s) => sum + s.volumeMl);
      if (ml > r.beakerMl) issues.add('$where: steps add ${ml}ml to a ${r.beakerMl}ml beaker');
      if (!placed.containsKey(r.id)) issues.add('$where: not placed on any topic');
    }
    // ---- Practical guides and lab–practical links.
    final labIds = {...c.manifest.labPlacements.keys, ...c.reactions.keys};
    for (final g in c.guides.values) {
      final where = 'Practical guide ${g.id}';
      published(where, g.review);
      sources(where, g.sources);
      if (!labIds.contains(g.id)) issues.add('$where: no interactive lab with this id');
      for (final (i, t) in g.texts.indexed) {
        text('$where text ${i + 1}', t);
      }
      if (g.apparatus.isEmpty) issues.add('$where: no apparatus');
      if (g.chemicals.isEmpty) issues.add('$where: no chemicals');
      if (g.steps.isEmpty) issues.add('$where: no steps');
      if (g.safety.isEmpty) issues.add('$where: no safety notes');
      // Students must be told how the simulation differs from the real lab.
      if (g.simulationLimits.isEmpty) issues.add('$where: does not say how the virtual lab differs from a real lab');
      if (g.viva.length < minVivaQuestions) issues.add('$where: has ${g.viva.length} viva questions, needs at least $minVivaQuestions');
      final vivaSeen = <String>{};
      for (final v in g.viva) {
        if (!vivaSeen.add(v.question.en.trim().toLowerCase())) issues.add('$where: viva question repeated: "${v.question.en}"');
      }
      for (final m in g.apparatus) {
        if (m.formula != null || m.hazard != null) issues.add('$where: apparatus "${m.name.en}" has a formula or hazard');
      }
    }
    final practicals = {
      for (final s in c.classes.values)
        for (final p in s.practicals) p.id: p,
    };
    for (final l in c.manifest.labLinks) {
      final where = 'Lab ${l.labId} link to ${l.practicalId}';
      if (!labIds.contains(l.labId)) issues.add('$where: unknown lab');
      final p = practicals[l.practicalId];
      if (p == null) issues.add('$where: unknown practical');
      switch (l.relation) {
        case LabRelation.official:
          if (p != null && p.labId != l.labId) issues.add('$where: official link, but the practical names lab "${p.labId}"');
        case LabRelation.related:
          if (l.note == null) issues.add('$where: a related lab must say how it differs from the practical');
      }
      if (l.note case final n?) text('$where note', n);
    }

    // ---- Practical coverage: a claim must be backed by linked labs.
    for (final cov in c.manifest.practicalCoverage.values) {
      final where = 'Coverage of ${cov.practicalId}';
      final p = practicals[cov.practicalId];
      if (p == null) {
        issues.add('$where: unknown practical');
        continue;
      }
      text('$where covered', cov.covered);
      if (cov.notCovered case final n?) text('$where not covered', n);
      final labs = [for (final l in c.labLinksForPractical(p)) if (c.guideFor(l.labId) != null) l.labId];
      switch (cov.level) {
        case PracticalLevel.fullyInteractive:
          if (cov.notCovered != null) issues.add('$where: fully interactive but lists parts not covered');
          if (labs.isEmpty) issues.add('$where: fully interactive with no lab');
        case PracticalLevel.partiallyInteractive:
          if (cov.notCovered == null) issues.add('$where: partially interactive must say what is not covered');
          if (labs.isEmpty) issues.add('$where: partially interactive with no lab');
        case PracticalLevel.guideOnly || PracticalLevel.notImplemented:
          issues.add('$where: only interactive practicals are declared; the rest are derived');
      }
    }

    for (final e in placed.entries) {
      if (!c.reactions.containsKey(e.key)) issues.add('Reaction placement: unknown reaction lab "${e.key}"');
      if (e.value.isEmpty) issues.add('Reaction placement ${e.key}: no topics');
      for (final t in e.value) {
        if (c.topic(t) == null) issues.add('Reaction placement ${e.key}: unknown topic "$t"');
      }
    }

    // ---- Practice questions.
    final questionIds = <String>{};
    for (final q in c.questions) {
      final where = 'Question ${q.id}';
      if (!questionIds.add(q.id)) issues.add('Duplicate question id "${q.id}"');
      published(where, q.review);
      sources(where, q.sources);
      placement(where, q.classLevel, q.chapterId, q.topicId);
      if (c.chapter(q.chapterId)?.$2.inYearEndExam == false) issues.add('$where: chapter is not in the year-end exam');
      if (!marksForType[q.type]!.contains(q.marks)) issues.add('$where: ${q.type.name} cannot carry ${q.marks} marks');
      choices(where, q.type, q.options, q.correctOption);
      if ((q.type == QuestionType.mcq || q.type == QuestionType.assertionReason) && q.options.isEmpty) {
        issues.add('$where: ${q.type.name} without options');
      }
      for (final (i, t) in [q.question, q.answer, q.explanation].indexed) {
        text('$where text ${i + 1}', t);
      }
    }

    // ---- PYQs: each tied to an entered official paper.
    final papers = {for (final p in c.manifest.pyqPapers) '${p.classLevel}|${p.examYear}|${p.attempt}|${p.paperCode}': p};
    final pyqIds = <String>{};
    final papersUsed = <String>{};
    for (final q in c.pyqs) {
      final where = 'PYQ ${q.id}';
      if (!pyqIds.add(q.id)) issues.add('Duplicate PYQ id "${q.id}"');
      if (q.boardId != c.manifest.boardId) issues.add('$where: belongs to board ${q.boardId}');
      published(where, q.review);
      placement(where, q.classLevel, q.chapterId, q.topicId);
      if (c.classes[q.classLevel]?.examPattern.boardExam != true) issues.add('$where: Class ${q.classLevel} has no board exam');
      final key = '${q.classLevel}|${q.examYear}|${q.attempt.name}|${q.paperCode}';
      final paper = papers[key];
      if (paper == null) {
        issues.add('$where: paper $key is not listed in the manifest');
      } else {
        papersUsed.add(key);
        if (q.paperUrl != paper.paperUrl) issues.add('$where: paper URL differs from the manifest');
        if (q.markingSchemeUrl != paper.markingSchemeUrl) issues.add('$where: marking-scheme URL differs from the manifest');
      }
      if (!c.manifest.pyqExamYears.contains(q.examYear)) issues.add('$where: ${q.examYear} has no official paper');
      if (!marksForType[q.type]!.contains(q.marks)) issues.add('$where: ${q.type.name} cannot carry ${q.marks} marks');
      if (!q.paperUrl.startsWith('https://')) issues.add('$where: paper URL is not https');
      if (q.summary == null || q.answer == null) issues.add('$where: needs a summary and an answer');
      for (final t in [?q.summary, ?q.answer]) {
        text(where, t);
      }
      choices(where, q.type, q.options, q.correctOption);
      for (final id in q.conceptIds) {
        if (!c.concepts.containsKey(id)) issues.add('$where: unknown concept "$id"');
      }
    }
    for (final key in papers.keys) {
      if (!papersUsed.contains(key)) issues.add('Paper $key is listed but has no questions');
    }
    return issues;
  }
}
