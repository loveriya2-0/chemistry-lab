import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../content/content_catalog.dart';
import '../core/theme.dart';
import '../data/bookmark_store.dart';
import '../l10n/app_strings.dart';
import '../l10n/study_strings.dart';
import '../study/study_focus.dart';
import '../study/study_map.dart';
import '../study/study_progress_store.dart';
import '../widgets/study_widgets.dart';
import '../widgets/ui_kit.dart';
import 'main_shell.dart';
import 'my_notes_screen.dart';
import 'question_bank_screen.dart';
import 'revision_screen.dart';
import 'study_timer_screen.dart';
import 'topic_detail_screen.dart';
import 'topic_list_screen.dart';

/// Home: the study path (Learn → My notes → Practice → Lab → Revise), then
/// what to pick up again — recent topics, unfinished chapters, revision and
/// the focus time of today against the daily goal. Everything comes from
/// data saved on this device; empty parts are left out.
class HomeStudyDashboard extends StatelessWidget {
  const HomeStudyDashboard({super.key, required this.curriculum, required this.classLevel, required this.push});

  final LoadedCurriculum curriculum;
  final int classLevel;
  final Future<void> Function(Widget) push;

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    final st = context.study;
    final progress = context.watch<StudyProgressStore>();
    final bookmarks = context.watch<BookmarkStore>();
    final settings = context.watch<FocusSettings>();
    final syllabus = curriculum.classes[classLevel]!;
    final recent = [for (final id in progress.recentTopicIds) ?curriculum.topic(id)].take(3).toList();
    final unfinished = [
      for (final c in syllabus.chapters)
        if (StudyMap.chapter(c, progress) case final cs when cs.isStarted && !cs.isComplete) cs,
    ].take(3).toList();
    final plan = RevisionPlan.build(curriculum, progress, bookmarks);
    final today = focusSummary(context).todaySeconds ~/ 60;
    final goal = settings.dailyGoalMinutes;

    Widget step(IconData icon, String label, Color color, VoidCallback onTap) => Expanded(
          child: Semantics(
            button: true,
            label: label,
            excludeSemantics: true,
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  children: [
                    IconTile(icon: icon, color: color, size: 40),
                    const SizedBox(height: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(label, maxLines: 1, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: LabColors.ink)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(st.studyPath),
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Row(
              children: [
                step(Icons.menu_book_rounded, st.pathLearn, LabColors.primary, () => MainShell.goTo(context, AppTab.learn)),
                step(Icons.edit_note_rounded, st.pathNotes, LabColors.amber, () => push(const MyNotesScreen())),
                step(Icons.quiz_rounded, st.pathPractice, LabColors.teal, () => push(QuestionBankScreen(classLevel: classLevel, title: s.practiceQuestions))),
                step(Icons.science_rounded, st.pathLab, LabColors.secondary, () => MainShell.goTo(context, AppTab.lab)),
                step(Icons.replay_circle_filled_rounded, st.pathRevise, LabColors.warning, () => push(const RevisionScreen())),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _MiniStat(
                icon: Icons.replay_rounded,
                color: LabColors.warning,
                value: st.revisionItems(plan.open),
                label: st.revision,
                onTap: () => push(const RevisionScreen()),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MiniStat(
                icon: Icons.timer_rounded,
                color: LabColors.primary,
                value: st.focusToday(today, goal),
                label: st.dailyGoal,
                progress: goal == 0 ? 0 : today / goal,
                onTap: () => push(const StudyTimerScreen()),
              ),
            ),
          ],
        ),
        if (recent.isNotEmpty) ...[
          const SizedBox(height: 16),
          SectionHeader(st.recentlyStudied),
          for (final loc in recent)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: const IconTile(icon: Icons.history_rounded, color: LabColors.teal, size: 36),
                title: Text('${loc.topic.number} ${s.ct(loc.topic.title)}',
                    maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Align(alignment: Alignment.centerLeft, child: StatusChip(status: progress.effectiveStatus(loc.topic))),
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => push(TopicDetailScreen(syllabus: loc.syllabus, chapter: loc.chapter, topic: loc.topic)),
              ),
            ),
        ],
        if (unfinished.isNotEmpty) ...[
          const SizedBox(height: 8),
          SectionHeader(st.unfinishedChapters),
          for (final cs in unfinished)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => push(TopicListScreen(syllabus: syllabus, chapter: cs.chapter)),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.ct(cs.chapter.title),
                          maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, color: LabColors.ink)),
                      const SizedBox(height: 8),
                      ProgressLine(value: cs.fraction, label: st.topicsStudied(cs.studied, cs.total)),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.icon, required this.color, required this.value, required this.label, required this.onTap, this.progress});

  final IconData icon;
  final Color color;
  final String value;
  final String label;
  final double? progress;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconTile(icon: icon, color: color, size: 32),
              const SizedBox(height: 8),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(value, maxLines: 1, style: const TextStyle(fontWeight: FontWeight.w800, color: LabColors.ink)),
              ),
              Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: LabColors.muted)),
              if (progress case final p?) ...[
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(value: p.clamp(0, 1), minHeight: 4, color: color, backgroundColor: LabColors.line),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
