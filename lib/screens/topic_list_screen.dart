import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../ai/tutor_context.dart';
import '../content/content_catalog.dart';
import '../content/models/syllabus.dart';
import '../core/theme.dart';
import '../data/practicals_repository.dart';
import '../l10n/app_strings.dart';
import '../l10n/study_strings.dart';
import '../state/app_state.dart';
import '../study/study_map.dart';
import '../study/study_progress_store.dart';
import '../widgets/ask_ai.dart';
import '../widgets/language_toggle.dart';
import '../widgets/learning_widgets.dart';
import '../widgets/study_widgets.dart';
import '../widgets/ui_kit.dart';
import 'concept_screen.dart' show ImportanceBadge;
import 'my_notes_screen.dart';
import 'practice_session_screen.dart';
import 'practical_dashboard_screen.dart';
import 'question_bank_screen.dart';
import 'topic_detail_screen.dart';

/// Opens the interactive labs offered on [topic].
void openLabsForTopic(BuildContext context, {required ClassSyllabus syllabus, required Chapter chapter, required Topic topic}) {
  final boardId = context.read<AppState>().boardId!;
  final curriculum = context.read<ContentCatalog>().curriculum(boardId)!;
  final labs = context.read<PracticalsRepository>();
  Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => PracticalDashboardScreen(
      boardId: boardId,
      classLevel: syllabus.classLevel,
      chapter: chapter,
      topic: topic,
      labs: [for (final id in curriculum.labsForTopic(topic.id)) labs.byId(id)],
    ),
  ));
}

/// Screen 3 – a chapter's verified topics and sub-topics, with any
/// interactive lab offered on them and the board's listed practicals.
class TopicListScreen extends StatelessWidget {
  const TopicListScreen({super.key, required this.syllabus, required this.chapter});

  final ClassSyllabus syllabus;
  final Chapter chapter;

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    final boardId = context.read<AppState>().boardId!;
    final curriculum = context.read<ContentCatalog>().curriculum(boardId)!;
    final practicals = syllabus.practicals.where((p) => p.chapterIds.contains(chapter.id)).toList();
    final chapterNote = chapter.topics.isEmpty ? curriculum.noteFor(chapter.id) : null;
    final practice = curriculum.practiceQuestions(classLevel: syllabus.classLevel, chapterId: chapter.id);
    final showImportance = syllabus.examPattern.boardExam && chapter.inYearEndExam && curriculum.manifest.pyqPapers.isNotEmpty;
    final importance = curriculum.chapterImportance(chapter.id);
    final progress = context.watch<StudyProgressStore>();
    final study = StudyMap.chapter(chapter, progress);
    final st = context.study;
    int questionsOn(Topic t) => curriculum.practiceQuestions(classLevel: syllabus.classLevel, topic: t).length;
    void openSub(Topic t) => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => TopicDetailScreen(syllabus: syllabus, chapter: chapter, topic: t),
        ));

    return Scaffold(
      appBar: AppBar(
        title: Text(chapter.number == null ? s.alsoInSyllabus : s.chapterTopics(chapter.number!)),
        actions: [
          AskAiAction(tutorContext: () => TutorContext.forChapter(curriculum, syllabus, chapter, boardName: currentBoardName(context))),
          const LanguageToggle(),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          _ChapterHeader(chapter: chapter, classLevel: syllabus.classLevel),
          const SizedBox(height: 14),
          if (!chapter.inYearEndExam) _Note(icon: Icons.info_outline_rounded, text: s.formativeNote),
          _ChapterProgressCard(
            study: study,
            // A chapter without topics is marked as a whole.
            status: chapter.topics.isEmpty ? progress.statusOf(chapter.id) : null,
            onStatus: (v) => progress.setStatus(chapter.id, v),
          ),
          const SizedBox(height: 14),
          if (chapterNote != null) ...[
            const SizedBox(height: 8),
            SectionHeader(s.notesTitle),
            NoteView(note: chapterNote, curriculum: curriculum, showHeading: false),
          ],
          for (final (i, topic) in chapter.topics.indexed) ...[
            FadeSlideIn(
              index: i,
              child: _TopicCard(
                topic: topic,
                status: StudyMap.statusFor(topic, progress),
                questions: questionsOn(topic),
                onOpenSub: openSub,
                hasLab: (t) => curriculum.labsForTopic(t.id).isNotEmpty,
                onOpenLab: (t) => openLabsForTopic(context, syllabus: syllabus, chapter: chapter, topic: t),
                onOpenTopic: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => TopicDetailScreen(syllabus: syllabus, chapter: chapter, topic: topic),
                )),
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (showImportance) ...[
            const SizedBox(height: 6),
            SectionHeader(s.sectionExam),
            Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ImportancePanel(importance: importance, curriculum: curriculum, classLevel: syllabus.classLevel, badge: ImportanceBadge(importance: importance)),
              ),
            ),
          ],
          if (practice.isNotEmpty) ...[
            FilledButton.tonalIcon(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => QuestionBankScreen(classLevel: syllabus.classLevel, title: s.ct(chapter.title), chapterId: chapter.id),
              )),
              icon: const Icon(Icons.quiz_rounded),
              label: Text('${s.practiceQuestions} · ${practice.length}'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => PracticeSessionScreen(title: '${st.chapterTest} · ${s.ct(chapter.title)}', questions: mixedTest(practice)),
              )),
              icon: const Icon(Icons.assignment_turned_in_outlined),
              label: Text(st.chapterTest),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(st.chapterTestHint(15), textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: LabColors.muted)),
            ),
            const SizedBox(height: 14),
          ],
          PersonalNotesSection(boardId: boardId, classLevel: syllabus.classLevel, chapterId: chapter.id),
          if (practicals.isNotEmpty) ...[
            const SizedBox(height: 6),
            SectionHeader(s.boardPracticals),
            for (final p in practicals)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _Note(icon: Icons.science_outlined, text: s.ct(p.title)),
              ),
          ],
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: Text(s.syllabusSource, style: const TextStyle(fontSize: 12, color: LabColors.muted)),
          ),
        ],
      ),
    );
  }
}

/// Studied topics out of the chapter's topics, with the completion rule.
class _ChapterProgressCard extends StatelessWidget {
  const _ChapterProgressCard({required this.study, required this.status, required this.onStatus});

  final ChapterStudy study;

  /// Set for a chapter without topics, which is marked as one unit.
  final TopicStatus? status;
  final ValueChanged<TopicStatus> onStatus;

  @override
  Widget build(BuildContext context) {
    final st = context.study;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 6, 4, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: ProgressLine(value: study.fraction, label: '${st.chapterProgressTitle} · ${st.topicsStudied(study.studied, study.total)}')),
                IconButton(
                  tooltip: st.completionRule,
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
            if (status case final s?) ...[
              const SizedBox(height: 10),
              Text(st.noTopicsToTrack, style: const TextStyle(fontWeight: FontWeight.w700, color: LabColors.ink)),
              const SizedBox(height: 6),
              StatusSelector(status: s, onChanged: onStatus),
            ],
          ],
        ),
      ),
    );
  }
}

class _ChapterHeader extends StatelessWidget {
  const _ChapterHeader({required this.chapter, required this.classLevel});

  final Chapter chapter;
  final int classLevel;

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    final w = chapter.weightage;
    return HeroPanel(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${s.className(classLevel)}${chapter.number == null ? '' : ' · ${s.chapterOverline(chapter.number!)}'}'.toUpperCase(),
            style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.6),
          ),
          const SizedBox(height: 6),
          SizedBox(width: 270, child: Text(s.ct(chapter.title), style: AppText.display(22, color: Colors.white, height: 1.2))),
          if (chapter.curriculumName != null) ...[
            const SizedBox(height: 4),
            Text(s.inBoardSyllabusAs(chapter.curriculumName!), style: const TextStyle(color: Colors.white70)),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _GlassChip(
                label: switch (w.scope) {
                  WeightageScope.chapter => s.chapterMarks(w.marks),
                  WeightageScope.unit => s.unitMarks(w.marks),
                  WeightageScope.notInYearEndExam => s.notInExam,
                  WeightageScope.notPublished => s.marksNotPublished,
                },
              ),
              if (chapter.topics.isNotEmpty) _GlassChip(label: s.topicCount(chapter.topics.length)),
            ],
          ),
          const SizedBox(height: 12),
          Text(s.ct(chapter.description), style: const TextStyle(color: Colors.white, height: 1.45)),
        ],
      ),
    );
  }
}

class _GlassChip extends StatelessWidget {
  const _GlassChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
    );
  }
}

class _TopicCard extends StatelessWidget {
  const _TopicCard({
    required this.topic,
    required this.status,
    required this.questions,
    required this.onOpenSub,
    required this.hasLab,
    required this.onOpenLab,
    required this.onOpenTopic,
  });

  final Topic topic;
  final TopicStatus status;

  /// Practice questions on the topic and its sub-topics.
  final int questions;
  final void Function(Topic) onOpenSub;
  final bool Function(Topic) hasLab;
  final void Function(Topic) onOpenLab;
  final VoidCallback onOpenTopic;

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: onOpenTopic,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 8, 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.topicOverline(topic.number),
                          style: const TextStyle(color: LabColors.primary, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.6),
                        ),
                        const SizedBox(height: 2),
                        _Row(topic: topic, bold: true, hasLab: hasLab(topic), onOpenLab: () => onOpenLab(topic)),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            StatusChip(status: status),
                            Text(context.study.questionsAvailable(questions), style: const TextStyle(fontSize: 12, color: LabColors.muted)),
                          ],
                        ),
                        const SizedBox(height: 4),
                      ],
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(top: 14),
                    child: Icon(Icons.chevron_right_rounded, color: LabColors.muted),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 12, 10),
            child: Column(
              children: [
                for (final sub in topic.subtopics)
                  InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => onOpenSub(sub),
                    child: _Row(topic: sub, bold: false, hasLab: hasLab(sub), onOpenLab: () => onOpenLab(sub)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One topic or sub-topic line; shows an "Open lab" button when a lab is
/// offered on it.
class _Row extends StatelessWidget {
  const _Row({required this.topic, required this.bold, required this.hasLab, required this.onOpenLab});

  final Topic topic;
  final bool bold;
  final bool hasLab;
  final VoidCallback onOpenLab;

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!bold)
            SizedBox(
              width: 44,
              child: Text(topic.number, style: const TextStyle(fontSize: 12, color: LabColors.muted, fontWeight: FontWeight.w700)),
            ),
          Expanded(
            child: Text(
              s.ct(topic.title),
              style: TextStyle(
                fontSize: bold ? 16 : 14,
                fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
                color: LabColors.ink,
                height: 1.35,
              ),
            ),
          ),
          if (hasLab) ...[
            const SizedBox(width: 8),
            Flexible(
              child: FilledButton.tonalIcon(
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  minimumSize: const Size(0, 40),
                  textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                ),
                onPressed: onOpenLab,
                icon: const Icon(Icons.science_rounded, size: 18),
                label: Text(s.openLab, maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: LabColors.line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: LabColors.muted),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(color: LabColors.ink, height: 1.4))),
        ],
      ),
    );
  }
}
