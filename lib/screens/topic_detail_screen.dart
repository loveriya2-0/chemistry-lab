import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../ai/tutor_context.dart';
import '../content/content_catalog.dart';
import '../content/models/syllabus.dart';
import '../core/theme.dart';
import '../data/bookmark_store.dart';
import '../data/focus_session_store.dart';
import '../l10n/app_strings.dart';
import '../l10n/study_strings.dart';
import '../state/app_state.dart';
import '../study/study_focus.dart';
import '../study/study_map.dart';
import '../study/study_progress_store.dart';
import '../widgets/ask_ai.dart';
import '../widgets/language_toggle.dart';
import '../widgets/learning_widgets.dart';
import '../widgets/study_widgets.dart';
import '../widgets/ui_kit.dart';
import 'chemical_screen.dart';
import 'concept_screen.dart';
import 'my_notes_screen.dart';
import 'pyq_screens.dart';
import 'question_bank_screen.dart';
import 'study_timer_screen.dart';
import 'topic_list_screen.dart';

/// Opens the page for any topic or sub-topic.
void openTopic(BuildContext context, TopicLocation loc, {bool replace = false}) {
  final route = MaterialPageRoute<void>(builder: (_) => TopicDetailScreen(syllabus: loc.syllabus, chapter: loc.chapter, topic: loc.topic));
  replace ? Navigator.of(context).pushReplacement(route) : Navigator.of(context).push(route);
}

/// One verified topic or sub-topic: breadcrumb, the student's status,
/// what content exists for it, sub-topics, labs, notes, the student's own
/// notes, practice questions, concepts, chemicals and PYQs, then links to
/// the previous and next topic.
///
/// Notes appear only once checked content exists; until then the screen
/// says so instead of showing anything made up. Exam importance is
/// computed from entered PYQs, never typed in.
class TopicDetailScreen extends StatefulWidget {
  const TopicDetailScreen({super.key, required this.syllabus, required this.chapter, required this.topic});

  final ClassSyllabus syllabus;
  final Chapter chapter;
  final Topic topic;

  @override
  State<TopicDetailScreen> createState() => _TopicDetailScreenState();
}

class _TopicDetailScreenState extends State<TopicDetailScreen> {
  @override
  void initState() {
    super.initState();
    // Opening a topic is studying it: remember it and mark it started.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<StudyProgressStore>().visitTopic(widget.topic.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final syllabus = widget.syllabus;
    final chapter = widget.chapter;
    final topic = widget.topic;
    final s = context.strings;
    final st = context.study;
    final boardId = context.read<AppState>().boardId!;
    final curriculum = context.read<ContentCatalog>().curriculum(boardId)!;
    final bookmarks = context.watch<BookmarkStore>();
    final progress = context.watch<StudyProgressStore>();
    final key = BookmarkStore.topicKey(topic.id);
    final saved = bookmarks.contains(key);
    final here = TopicLocation(syllabus: syllabus, chapter: chapter, topic: topic);
    final parent = StudyMap.parentOf(chapter, topic);
    final (prev, next) = StudyMap.neighbours(curriculum, here);
    final withLabs = topic.selfAndDescendants.where((t) => curriculum.labsForTopic(t.id).isNotEmpty).toList();
    final notes = curriculum.notesForTopic(topic);
    final concepts = {
      for (final id in [for (final t in topic.selfAndDescendants) ...t.conceptIds, for (final n in notes) ...n.conceptIds])
        if (curriculum.concepts[id] case final c? when c.isPublishable) c,
    }.toList();
    final chemicals = {
      for (final n in notes)
        for (final id in n.chemicalIds)
          if (curriculum.chemicals[id] case final x? when x.review.isPublishable) x,
    }.toList();
    final practice = curriculum.practiceQuestions(classLevel: syllabus.classLevel, topic: topic);
    final stats = progress.statsFor(practice.map((q) => q.id));
    final pyqs = curriculum.pyqsForTopic(topic);
    final boardExam = syllabus.examPattern.boardExam && chapter.inYearEndExam && curriculum.manifest.pyqPapers.isNotEmpty;
    final importance = boardExam
        ? ImportancePanel(
            importance: curriculum.topicImportance(topic),
            curriculum: curriculum,
            classLevel: syllabus.classLevel,
            badge: ImportanceBadge(importance: curriculum.topicImportance(topic)),
          )
        : null;
    // Importance belongs in the 🎯 section of the topic's own note; only
    // a topic explained solely through sub-topic notes shows it separately.
    final ownNote = notes.any((n) => n.targetId == topic.id);
    final practicalIds = {for (final n in notes) ...n.practicalIds};
    final status = StudyMap.statusFor(topic, progress);
    final ownStatus = progress.statusOf(topic.id);
    final focusSeconds = _focusSecondsOn(context, topic);
    void push(Widget w) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => w));
    TutorContext tutorContext() => TutorContext.forTopic(curriculum, here, boardName: currentBoardName(context));

    return Scaffold(
      appBar: AppBar(
        title: Text(s.topicOverline(topic.number)),
        actions: [
          IconButton(
            tooltip: saved ? s.bookmarked : s.bookmark,
            onPressed: () => bookmarks.toggle(key),
            icon: Icon(saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded),
          ),
          AskAiAction(tutorContext: tutorContext),
          const LanguageToggle(),
        ],
      ),
      bottomNavigationBar: (prev == null && next == null) ? null : _PrevNextBar(prev: prev, next: next),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          HeroPanel(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  [
                    s.className(syllabus.classLevel),
                    if (chapter.number != null) s.chapterOverline(chapter.number!),
                    topic.number,
                  ].join(' › ').toUpperCase(),
                  style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.4),
                ),
                const SizedBox(height: 8),
                SizedBox(width: 270, child: Text(s.ct(topic.title), style: AppText.display(22, color: Colors.white, height: 1.25))),
                const SizedBox(height: 6),
                Text(s.ct(chapter.title), style: const TextStyle(color: Colors.white70)),
                if (parent != null) ...[
                  const SizedBox(height: 4),
                  Text('${st.partOfTopic(parent.number)} · ${s.ct(parent.title)}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          _StatusCard(
            status: status,
            ownStatus: ownStatus,
            onChanged: (v) => progress.setStatus(topic.id, v),
          ),
          const SizedBox(height: 12),
          _Availability(
            hasNote: notes.isNotEmpty,
            keyPoints: notes.any((n) => n.keyPoints.isNotEmpty),
            quickRevision: notes.any((n) => n.quickRevision != null),
            tricks: notes.any((n) => n.memoryTricks.isNotEmpty),
            formulas: notes.any((n) => n.formulas.isNotEmpty),
            examples: notes.isNotEmpty,
            practice: practice.length,
            pyqs: syllabus.examPattern.boardExam ? pyqs.length : null,
            practicals: practicalIds.isNotEmpty || withLabs.isNotEmpty,
          ),
          if (topic.subtopics.isNotEmpty) ...[
            const SizedBox(height: 16),
            SectionHeader(s.subtopicsTitle),
            Card(
              margin: EdgeInsets.zero,
              child: Column(
                children: [
                  for (final (i, sub) in topic.subtopics.indexed) ...[
                    if (i > 0) const Divider(height: 1, indent: 16, endIndent: 16),
                    ListTile(
                      leading: Text(sub.number, style: const TextStyle(fontWeight: FontWeight.w800, color: LabColors.primary)),
                      title: Text(s.ct(sub.title), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: LabColors.ink, height: 1.35)),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            StatusChip(status: progress.statusOf(sub.id)),
                            Text(
                              st.questionsAvailable(curriculum.practiceQuestions(classLevel: syllabus.classLevel, topic: sub).length),
                              style: const TextStyle(fontSize: 12, color: LabColors.muted),
                            ),
                          ],
                        ),
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => openTopic(context, TopicLocation(syllabus: syllabus, chapter: chapter, topic: sub)),
                    ),
                  ],
                ],
              ),
            ),
          ],
          if (withLabs.isNotEmpty) ...[
            const SizedBox(height: 16),
            SectionHeader(s.interactiveLab),
            for (final t in withLabs)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: FilledButton.icon(
                  onPressed: () => openLabsForTopic(context, syllabus: syllabus, chapter: chapter, topic: t),
                  icon: const Icon(Icons.science_rounded),
                  label: Text('${s.openLab} · ${t.number}'),
                ),
              ),
          ],
          const SizedBox(height: 16),
          SectionHeader(s.notesTitle),
          if (notes.isEmpty)
            ComingSoonPanel(icon: Icons.auto_stories_rounded, title: s.notesTitle, body: s.notesComingSoon)
          else
            for (final n in notes)
              NoteView(
                note: n,
                curriculum: curriculum,
                showHeading: notes.length > 1 || n.targetId != topic.id,
                examImportance: n.targetId == topic.id ? importance : null,
              ),
          if (importance != null && !ownNote) ...[
            SectionHeader(s.sectionExam),
            Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(padding: const EdgeInsets.all(16), child: importance),
            ),
          ],
          PersonalNotesSection(boardId: boardId, classLevel: syllabus.classLevel, chapterId: chapter.id, topicId: topic.id),
          if (practice.isNotEmpty) ...[
            FilledButton.tonalIcon(
              onPressed: () => push(QuestionBankScreen(classLevel: syllabus.classLevel, title: s.ct(topic.title), topic: topic)),
              icon: const Icon(Icons.quiz_rounded),
              label: Text('${s.practiceQuestions} · ${practice.length}'),
            ),
            const SizedBox(height: 6),
            Text(
              stats.attempted == 0
                  ? st.notAttemptedYet
                  : st.practiceStats(stats.attempted, stats.total, stats.accuracy == null ? '—' : '${(stats.accuracy! * 100).round()}%'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: LabColors.muted),
            ),
            const SizedBox(height: 16),
          ],
          OutlinedButton.icon(
            onPressed: () => push(StudyTimerScreen(
              initialTarget: StudyTarget(boardId: boardId, classLevel: syllabus.classLevel, chapterId: chapter.id, topicId: topic.id),
            )),
            icon: const Icon(Icons.timer_outlined),
            label: Text(focusSeconds > 0 ? '${st.studyTimer} · ${s.duration(focusSeconds)}' : st.studyTimer),
          ),
          const SizedBox(height: 16),
          // AI help comes after the verified content and is labelled as AI.
          AskAiCard(tutorContext: tutorContext),
          if (concepts.isNotEmpty) ...[
            SectionHeader(s.keyConcepts),
            for (final c in concepts)
              LinkTile(
                icon: Icons.lightbulb_outline_rounded,
                color: LabColors.teal,
                title: s.ct(c.title),
                onTap: () => push(ConceptScreen(concept: c, classLevel: syllabus.classLevel)),
              ),
          ],
          if (chemicals.isNotEmpty) ...[
            const SizedBox(height: 8),
            SectionHeader(s.chemicalsAndReactions),
            for (final x in chemicals)
              LinkTile(
                icon: Icons.science_outlined,
                color: LabColors.secondary,
                title: s.ct(x.name),
                subtitle: x.formula ?? s.chemicalKindName(x.kind),
                onTap: () => push(ChemicalScreen(chemical: x)),
              ),
          ],
          if (pyqs.isNotEmpty) ...[
            const SizedBox(height: 16),
            SectionHeader(s.pyqsOnTopic),
            for (final q in pyqs) PyqTile(question: q),
          ],
        ],
      ),
    );
  }

  /// Lab and study focus time saved against this topic or its sub-topics.
  static int _focusSecondsOn(BuildContext context, Topic topic) {
    final ids = {for (final t in topic.selfAndDescendants) t.id};
    final lab = context.read<FocusSessionStore>().all().where((s) => s.topicId != null && ids.contains(s.topicId));
    final study = context.read<StudySessionStore>().all().where((s) => s.target.topicId != null && ids.contains(s.target.topicId));
    return lab.fold(0, (sum, s) => sum + s.focusedSeconds) + study.fold(0, (sum, s) => sum + s.focusedSeconds);
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.status, required this.ownStatus, required this.onChanged});

  /// What the topic counts as (may come from its sub-topics).
  final TopicStatus status;

  /// What the student set on this page.
  final TopicStatus ownStatus;
  final ValueChanged<TopicStatus> onChanged;

  @override
  Widget build(BuildContext context) {
    final st = context.study;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(st.statusTitle, style: AppText.display(15))),
                StatusChip(status: status),
                IconButton(
                  tooltip: st.completionRule,
                  visualDensity: VisualDensity.compact,
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      content: Text(st.completionRule, style: const TextStyle(height: 1.45)),
                      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(ctx.readStudy.done))],
                    ),
                  ),
                  icon: const Icon(Icons.info_outline_rounded, size: 20, color: LabColors.muted),
                ),
              ],
            ),
            const SizedBox(height: 8),
            StatusSelector(status: ownStatus, onChanged: onChanged),
          ],
        ),
      ),
    );
  }
}

/// Which kinds of content exist for this topic; missing ones are greyed.
class _Availability extends StatelessWidget {
  const _Availability({
    required this.hasNote,
    required this.keyPoints,
    required this.quickRevision,
    required this.tricks,
    required this.formulas,
    required this.examples,
    required this.practice,
    required this.pyqs,
    required this.practicals,
  });

  final bool hasNote;
  final bool keyPoints;
  final bool quickRevision;
  final bool tricks;
  final bool formulas;
  final bool examples;
  final int practice;

  /// Null for a class without a board exam (no PYQs exist).
  final int? pyqs;
  final bool practicals;

  @override
  Widget build(BuildContext context) {
    final st = context.study;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(st.whatsHere, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: LabColors.muted, letterSpacing: 0.4)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            AvailabilityChip(label: st.contentExplanation, available: hasNote),
            AvailabilityChip(label: st.contentKeyPoints, available: keyPoints),
            AvailabilityChip(label: st.contentQuickRevision, available: quickRevision),
            AvailabilityChip(label: st.contentMemoryTricks, available: tricks),
            AvailabilityChip(label: st.contentFormulas, available: formulas),
            AvailabilityChip(label: st.contentExamples, available: examples),
            AvailabilityChip(label: st.contentPractice(practice), available: practice > 0),
            if (pyqs case final n?) AvailabilityChip(label: st.contentPyqs(n), available: n > 0),
            AvailabilityChip(label: st.contentPracticals, available: practicals),
          ],
        ),
      ],
    );
  }
}

/// Previous / next topic, pinned to the bottom of the topic page.
class _PrevNextBar extends StatelessWidget {
  const _PrevNextBar({required this.prev, required this.next});

  final TopicLocation? prev;
  final TopicLocation? next;

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    final st = context.study;
    String label(TopicLocation l) => '${l.topic.number} ${s.ct(l.topic.title)}';
    return Material(
      color: Colors.white,
      elevation: 6,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
          child: Row(
            children: [
              Expanded(
                child: prev == null
                    ? const SizedBox.shrink()
                    : TextButton(
                        style: TextButton.styleFrom(minimumSize: const Size(0, 48), alignment: Alignment.centerLeft),
                        onPressed: () => openTopic(context, prev!, replace: true),
                        child: Row(
                          children: [
                            const Icon(Icons.chevron_left_rounded),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(st.previousTopic, style: const TextStyle(fontSize: 11, color: LabColors.muted)),
                                  Text(label(prev!), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: next == null
                    ? const SizedBox.shrink()
                    : TextButton(
                        style: TextButton.styleFrom(minimumSize: const Size(0, 48), alignment: Alignment.centerRight),
                        onPressed: () => openTopic(context, next!, replace: true),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(st.nextTopic, style: const TextStyle(fontSize: 11, color: LabColors.muted)),
                                  Text(label(next!),
                                      maxLines: 1, textAlign: TextAlign.end, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right_rounded),
                          ],
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
