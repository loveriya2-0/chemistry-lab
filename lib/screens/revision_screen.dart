import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../content/content_catalog.dart';
import '../content/models/practice_question.dart';
import '../content/models/topic_note.dart';
import '../core/theme.dart';
import '../data/bookmark_store.dart';
import '../l10n/app_strings.dart';
import '../l10n/study_strings.dart';
import '../state/app_state.dart';
import '../study/study_progress_store.dart';
import '../widgets/language_toggle.dart';
import '../widgets/learning_widgets.dart';
import '../widgets/ui_kit.dart';
import 'practice_session_screen.dart';
import 'topic_detail_screen.dart';

/// What is waiting to be revised, worked out from saved data only.
class RevisionPlan {
  RevisionPlan._({
    required this.topics,
    required this.mistakes,
    required this.fixedMistakes,
    required this.savedQuestions,
    required this.savedFormulas,
    required this.weakTopics,
    required this.done,
    required this.total,
  });

  factory RevisionPlan.build(LoadedCurriculum curriculum, StudyProgressStore progress, BookmarkStore bookmarks) {
    final questions = {for (final q in curriculum.questions) if (q.review.isPublishable) q.id: q};
    final notes = {for (final n in curriculum.notes) if (n.review.isPublishable) n.id: n};
    final topics = [for (final id in progress.reviseAgainIds) ?curriculum.topic(id)];
    final mistakes = [for (final id in progress.mistakeIds) ?questions[id]];
    final fixed = [for (final id in progress.fixedMistakeIds) ?questions[id]];
    final saved = [for (final id in bookmarks.questionIds) ?questions[id]];
    final formulas = [
      for (final (noteId, f) in bookmarks.formulas)
        if (notes[noteId] case final n? when n.formulas.contains(f)) (n, f),
    ];
    // Top-level topics answered at least 3 times with under 60% correct.
    final weak = <(TopicLocation, QuestionStats)>[];
    for (final level in curriculum.classLevels) {
      for (final ch in curriculum.classes[level]!.chapters) {
        for (final t in ch.topics) {
          final ids = curriculum.practiceQuestions(classLevel: level, topic: t).map((q) => q.id);
          final stats = progress.statsFor(ids);
          if (stats.answers >= 3 && (stats.accuracy ?? 1) < 0.6) {
            weak.add((TopicLocation(syllabus: curriculum.classes[level]!, chapter: ch, topic: t), stats));
          }
        }
      }
    }
    final ticked = saved.where((q) => progress.revisedAt('question:${q.id}') != null).length +
        formulas.where((e) => progress.revisedAt(BookmarkStore.formulaKey(e.$1.id, e.$2)) != null).length;
    return RevisionPlan._(
      topics: topics,
      mistakes: mistakes,
      fixedMistakes: fixed,
      savedQuestions: saved,
      savedFormulas: formulas,
      weakTopics: weak,
      done: fixed.length + ticked,
      total: topics.length + mistakes.length + fixed.length + saved.length + formulas.length,
    );
  }

  final List<TopicLocation> topics;
  final List<PracticeQuestion> mistakes;
  final List<PracticeQuestion> fixedMistakes;
  final List<PracticeQuestion> savedQuestions;
  final List<(TopicNote, String)> savedFormulas;
  final List<(TopicLocation, QuestionStats)> weakTopics;

  /// Revision items finished: mistakes since answered correctly, and saved
  /// questions/formulas ticked as revised.
  final int done;
  final int total;

  /// Items still waiting.
  int get open => total - done;
  bool get isEmpty => total == 0 && weakTopics.isEmpty;
}

/// Offline revision: topics marked "Revise again", mistakes, saved
/// questions and formulas, and topics that need more practice.
class RevisionScreen extends StatelessWidget {
  const RevisionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    final st = context.study;
    final curriculum = context.read<ContentCatalog>().curriculum(context.read<AppState>().boardId!)!;
    final progress = context.watch<StudyProgressStore>();
    final bookmarks = context.watch<BookmarkStore>();
    final plan = RevisionPlan.build(curriculum, progress, bookmarks);
    void practise(String title, List<PracticeQuestion> qs) =>
        Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => PracticeSessionScreen(title: title, questions: qs)));

    Widget tick(String key) {
      final done = progress.revisedAt(key) != null;
      return TextButton.icon(
        onPressed: () => progress.toggleRevised(key),
        icon: Icon(done ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded, size: 18, color: done ? LabColors.success : LabColors.muted),
        label: Text(done ? st.revised : st.markRevised),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(st.revision), actions: const [LanguageToggle()]),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          if (plan.isEmpty)
            ComingSoonPanel(icon: Icons.replay_circle_filled_rounded, title: st.nothingToRevise, body: st.nothingToReviseHint)
          else ...[
            HeroPanel(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(st.revision.toUpperCase(), style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.6)),
                  const SizedBox(height: 6),
                  Text(st.revisionDone(plan.done, plan.total), style: AppText.display(20, color: Colors.white)),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: plan.total == 0 ? 0 : plan.done / plan.total,
                      minHeight: 8,
                      color: Colors.white,
                      backgroundColor: Colors.white24,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          SectionHeader(st.topicsToRevise),
          if (plan.topics.isEmpty)
            _Empty(st.noTopicsToRevise)
          else
            for (final loc in plan.topics)
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: const IconTile(icon: Icons.replay_rounded, color: LabColors.warning, size: 36),
                  title: Text('${loc.topic.number} ${s.ct(loc.topic.title)}', style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text('${s.className(loc.syllabus.classLevel)} · ${s.ct(loc.chapter.title)}', maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: IconButton(
                    tooltip: st.markRevised,
                    onPressed: () => progress.setStatus(loc.topic.id, TopicStatus.completed),
                    icon: const Icon(Icons.check_rounded, color: LabColors.success),
                  ),
                  onTap: () => openTopic(context, loc),
                ),
              ),
          const SizedBox(height: 12),
          SectionHeader(st.mistakesToFix),
          if (plan.mistakes.isEmpty)
            _Empty(st.noMistakes)
          else ...[
            FilledButton.icon(
              onPressed: () => practise(st.mistakesToFix, plan.mistakes),
              icon: const Icon(Icons.replay_rounded),
              label: Text('${st.practiseMistakes} · ${plan.mistakes.length}'),
            ),
            const SizedBox(height: 8),
            for (final q in plan.mistakes.take(30)) _QuestionRow(question: q, curriculum: curriculum),
          ],
          if (plan.fixedMistakes.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('${st.fixedMistakes}: ${plan.fixedMistakes.length}', style: const TextStyle(color: LabColors.success, fontWeight: FontWeight.w700)),
            ),
          const SizedBox(height: 12),
          SectionHeader(st.savedQuestions),
          if (plan.savedQuestions.isEmpty)
            _Empty(st.noSavedQuestions)
          else ...[
            OutlinedButton.icon(
              onPressed: () => practise(st.savedQuestions, plan.savedQuestions),
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text('${st.practiseSaved} · ${plan.savedQuestions.length}'),
            ),
            const SizedBox(height: 8),
            for (final q in plan.savedQuestions) _QuestionRow(question: q, curriculum: curriculum, trailing: tick('question:${q.id}')),
          ],
          const SizedBox(height: 12),
          SectionHeader(st.savedFormulas),
          if (plan.savedFormulas.isEmpty)
            _Empty(st.noSavedFormulas)
          else
            for (final (note, f) in plan.savedFormulas)
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 4, 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FormulaBox(f, saved: true, onToggleSave: () => bookmarks.toggle(BookmarkStore.formulaKey(note.id, f))),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              switch (curriculum.topic(note.targetId)) {
                                final loc? => '${s.className(loc.syllabus.classLevel)} · ${loc.topic.number} ${s.ct(loc.topic.title)}',
                                null => s.ct(curriculum.chapter(note.targetId)?.$2.title ?? note.definition),
                              },
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12, color: LabColors.muted),
                            ),
                          ),
                          tick(BookmarkStore.formulaKey(note.id, f)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          const SizedBox(height: 12),
          SectionHeader(st.needsPractice),
          Text(st.needsPracticeHint, style: const TextStyle(fontSize: 12, color: LabColors.muted)),
          const SizedBox(height: 8),
          for (final (loc, stats) in plan.weakTopics)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: const IconTile(icon: Icons.trending_down_rounded, color: LabColors.danger, size: 36),
                title: Text('${loc.topic.number} ${s.ct(loc.topic.title)}', style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(st.accuracyShort(((stats.accuracy ?? 0) * 100).round(), stats.answers)),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => practise(s.ct(loc.topic.title), curriculum.practiceQuestions(classLevel: loc.syllabus.classLevel, topic: loc.topic)),
              ),
            ),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text, style: const TextStyle(color: LabColors.muted, height: 1.4)),
      );
}

class _QuestionRow extends StatelessWidget {
  const _QuestionRow({required this.question, required this.curriculum, this.trailing});

  final PracticeQuestion question;
  final LoadedCurriculum curriculum;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    final loc = curriculum.topic(question.topicId);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 4, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.ct(question.question), maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, height: 1.4, color: LabColors.ink)),
            Row(
              children: [
                Expanded(
                  child: Text(
                    [if (loc != null) '${s.className(loc.syllabus.classLevel)} · ${loc.topic.number}', s.difficultyName(question.difficulty)].join(' · '),
                    style: const TextStyle(fontSize: 12, color: LabColors.muted),
                  ),
                ),
                ?trailing,
              ],
            ),
          ],
        ),
      ),
    );
  }
}
