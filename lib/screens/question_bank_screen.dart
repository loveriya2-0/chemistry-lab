import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../content/content_catalog.dart';
import '../content/models/practice_question.dart';
import '../content/models/pyq.dart';
import '../content/models/syllabus.dart';
import '../core/theme.dart';
import '../l10n/app_strings.dart';
import '../l10n/study_strings.dart';
import '../state/app_state.dart';
import '../study/study_progress_store.dart';
import '../widgets/language_toggle.dart';
import '../widgets/learning_widgets.dart';
import '../widgets/ui_kit.dart';
import 'practice_session_screen.dart';

/// Practice questions written from the textbook for one class, chapter or
/// topic, filterable by question type and difficulty, with progress and a
/// one-at-a-time practice mode. Clearly separate from PYQs.
class QuestionBankScreen extends StatefulWidget {
  const QuestionBankScreen({super.key, required this.classLevel, required this.title, this.chapterId, this.topic, this.questions});

  final int classLevel;
  final String title;
  final String? chapterId;
  final Topic? topic;

  /// A fixed list (saved questions, mistakes) instead of a syllabus slice.
  final List<PracticeQuestion>? questions;

  @override
  State<QuestionBankScreen> createState() => _QuestionBankScreenState();
}

class _QuestionBankScreenState extends State<QuestionBankScreen> {
  QuestionType? _type;
  Difficulty? _difficulty;
  bool _unansweredOnly = false;

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    final st = context.study;
    final curriculum = context.read<ContentCatalog>().curriculum(context.read<AppState>().boardId!)!;
    final progress = context.watch<StudyProgressStore>();
    final all = widget.questions ?? curriculum.practiceQuestions(classLevel: widget.classLevel, chapterId: widget.chapterId, topic: widget.topic);
    final types = [for (final t in QuestionType.values) if (all.any((q) => q.type == t)) t];
    final levels = [for (final d in Difficulty.values) if (all.any((q) => q.difficulty == d)) d];
    final shown = [
      for (final q in all)
        if ((_type == null || q.type == _type) &&
            (_difficulty == null || q.difficulty == _difficulty) &&
            (!_unansweredOnly || progress.recordOf(q.id) == null))
          q,
    ];
    final stats = progress.statsFor(all.map((q) => q.id));
    final mistakes = [for (final q in all) if (progress.mistakeIds.contains(q.id)) q];

    void practise(List<PracticeQuestion> list) => Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => PracticeSessionScreen(title: widget.title, questions: list),
        ));

    return Scaffold(
      appBar: AppBar(title: Text(widget.title), actions: const [LanguageToggle()]),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline_rounded, size: 16, color: LabColors.muted),
              const SizedBox(width: 6),
              Expanded(child: Text(s.practiceQuestionsNote, style: const TextStyle(fontSize: 12, color: LabColors.muted, height: 1.4))),
            ],
          ),
          if (all.isNotEmpty) ...[
            const SizedBox(height: 8),
            if (stats.attempted == 0)
              Text('${st.notAttemptedYet} · ${st.questionsAvailable(all.length)}', style: const TextStyle(color: LabColors.muted))
            else
              PracticeStatsCard(stats: stats),
          ],
          const SizedBox(height: 8),
          if (types.length > 1)
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                ChoiceChip(label: Text(s.allTypes), selected: _type == null, onSelected: (_) => setState(() => _type = null)),
                for (final t in types)
                  ChoiceChip(label: Text(s.questionTypeName(t)), selected: _type == t, onSelected: (_) => setState(() => _type = t)),
              ],
            ),
          if (all.isNotEmpty) ...[
            const SizedBox(height: 6),
            // Difficulty and "not yet answered" share one line.
            Row(
              children: [
                if (levels.length > 1) ...[
                  Flexible(
                    child: PopupMenuButton<Difficulty?>(
                      tooltip: st.difficultyLabel,
                      initialValue: _difficulty,
                      onSelected: (d) => setState(() => _difficulty = d),
                      itemBuilder: (_) => [
                        PopupMenuItem(value: null, child: Text(st.allDifficulties)),
                        for (final d in levels) PopupMenuItem(value: d, child: Text(s.difficultyName(d))),
                      ],
                      child: Chip(
                        avatar: const Icon(Icons.speed_rounded, size: 16),
                        label: Text(_difficulty == null ? st.allDifficulties : s.difficultyName(_difficulty!), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Flexible(
                  child: FilterChip(
                    label: Text(st.onlyUnanswered, maxLines: 1, overflow: TextOverflow.ellipsis),
                    selected: _unansweredOnly,
                    onSelected: (v) => setState(() => _unansweredOnly = v),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          if (mistakes.isNotEmpty) ...[
            OutlinedButton.icon(
              onPressed: () => practise(mistakes),
              icon: const Icon(Icons.replay_rounded),
              label: Text(st.retryMistakes(mistakes.length)),
            ),
            const SizedBox(height: 4),
          ],
          if (all.isEmpty)
            ComingSoonPanel(icon: Icons.quiz_rounded, title: s.practiceQuestions, body: s.noPracticeQuestions)
          else if (shown.isEmpty)
            ComingSoonPanel(icon: Icons.filter_alt_off_rounded, title: s.practiceQuestions, body: st.noQuestionsForFilter)
          else ...[
            // The count and the one-at-a-time mode share a line.
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 4,
              children: [
                Text(s.practiceQuestionCount(shown.length), style: const TextStyle(color: LabColors.muted)),
                FilledButton.icon(
                  onPressed: () => practise(shown),
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: Text(st.practiseOneByOne),
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (final (i, q) in shown.indexed) PracticeQuestionCard(key: ValueKey(q.id), question: q, index: i + 1),
          ],
        ],
      ),
    );
  }
}

/// Attempted / correct / accuracy / remaining for a set of questions.
class PracticeStatsCard extends StatelessWidget {
  const PracticeStatsCard({super.key, required this.stats});

  final QuestionStats stats;

  @override
  Widget build(BuildContext context) {
    final st = context.study;
    final acc = stats.accuracy;
    Widget cell(String value, String label, Color color) => Expanded(
          child: Column(
            children: [
              FittedBox(fit: BoxFit.scaleDown, child: Text(value, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: color))),
              Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: LabColors.muted)),
            ],
          ),
        );
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Row(
          children: [
            cell('${stats.attempted}/${stats.total}', st.attemptedLabel, LabColors.primary),
            cell('${stats.correctNow}', st.correctLabel, LabColors.success),
            cell(acc == null ? '—' : '${(acc * 100).round()}%', st.accuracyLabel, LabColors.teal),
            cell('${stats.remaining}', st.remainingLabel, LabColors.muted),
          ],
        ),
      ),
    );
  }
}
