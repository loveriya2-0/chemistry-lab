import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../content/models/practice_question.dart';
import '../core/theme.dart';
import '../data/bookmark_store.dart';
import '../l10n/app_strings.dart';
import '../l10n/study_strings.dart';
import '../study/study_progress_store.dart';
import '../widgets/info_pill.dart';
import '../widgets/language_toggle.dart';
import '../widgets/learning_widgets.dart';

/// One answer given in a practice session.
class PracticeAnswer {
  const PracticeAnswer({required this.correct, this.picked});

  final bool correct;

  /// The option picked, for choice questions.
  final int? picked;
}

/// Picks a chapter test: questions shuffled, then taken round-robin across
/// topics so the test mixes the whole chapter.
List<PracticeQuestion> mixedTest(List<PracticeQuestion> pool, {int size = 15, math.Random? random}) {
  final rng = random ?? math.Random();
  final byTopic = <String, List<PracticeQuestion>>{};
  for (final q in pool.toList()..shuffle(rng)) {
    byTopic.putIfAbsent(q.topicId, () => []).add(q);
  }
  final queues = byTopic.values.toList()..shuffle(rng);
  final out = <PracticeQuestion>[];
  while (out.length < size && queues.any((q) => q.isNotEmpty)) {
    for (final q in queues) {
      if (q.isNotEmpty && out.length < size) out.add(q.removeAt(0));
    }
  }
  return out;
}

/// Practice one question at a time.
///
/// Choice questions (MCQ, assertion–reason) are checked against the answer
/// key. Written answers cannot be checked by the app, so the student reads
/// the model answer and marks themselves — the screen says so. Each answer
/// is recorded once in [StudyProgressStore]; reviewing does not record.
class PracticeSessionScreen extends StatefulWidget {
  const PracticeSessionScreen({super.key, required this.title, required this.questions});

  final String title;
  final List<PracticeQuestion> questions;

  @override
  State<PracticeSessionScreen> createState() => _PracticeSessionScreenState();
}

class _PracticeSessionScreenState extends State<PracticeSessionScreen> {
  late List<PracticeQuestion> _questions = widget.questions;
  final _answers = <String, PracticeAnswer>{};
  int _index = 0;
  int? _picked;
  bool _revealed = false;
  bool _finished = false;
  bool _reviewing = false;

  PracticeQuestion get _q => _questions[_index];

  void _record(bool correct, {int? picked}) {
    if (_answers.containsKey(_q.id)) return;
    _answers[_q.id] = PracticeAnswer(correct: correct, picked: picked);
    context.read<StudyProgressStore>().recordAnswer(_q.id, correct: correct);
    setState(() {});
  }

  void _next() {
    setState(() {
      if (_index < _questions.length - 1) {
        _index++;
        _picked = null;
        _revealed = false;
      } else {
        _finished = true;
      }
    });
  }

  void _restartWith(List<PracticeQuestion> questions) {
    setState(() {
      _questions = questions;
      _answers.clear();
      _index = 0;
      _picked = null;
      _revealed = false;
      _finished = false;
      _reviewing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final st = context.study;
    final bookmarks = context.watch<BookmarkStore>();
    final current = _finished || _questions.isEmpty ? null : _q;
    final saved = current != null && bookmarks.contains(BookmarkStore.questionKey(current.id));
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          if (current != null)
            IconButton(
              tooltip: saved ? st.questionSaved : st.saveQuestion,
              onPressed: () => bookmarks.toggle(BookmarkStore.questionKey(current.id)),
              icon: Icon(saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded),
            ),
          const LanguageToggle(),
        ],
      ),
      body: _questions.isEmpty
          ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(st.noQuestionsForFilter, textAlign: TextAlign.center)))
          : _finished
              ? (_reviewing ? _review(context) : _results(context))
              : _question(context),
    );
  }

  Widget _question(BuildContext context) {
    final s = context.strings;
    final st = context.study;
    final q = _q;
    final answer = _answers[q.id];
    final checked = answer != null;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        Text(st.questionXofY(_index + 1, _questions.length), style: const TextStyle(color: LabColors.muted)),
        const SizedBox(height: 8),
        LinearProgressIndicator(value: (_index + 1) / _questions.length, borderRadius: BorderRadius.circular(8)),
        const SizedBox(height: 14),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            InfoPill(icon: Icons.category_outlined, label: s.questionTypeName(q.type)),
            InfoPill(icon: Icons.grade_rounded, label: s.marksN(q.marks)),
            InfoPill(icon: Icons.speed_rounded, label: s.difficultyName(q.difficulty)),
          ],
        ),
        const SizedBox(height: 10),
        Text(s.ct(q.question), style: const TextStyle(fontSize: 16, height: 1.5, color: LabColors.ink, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        if (q.isChoice) ...[
          for (final (i, o) in q.options.indexed)
            ChoiceOption(
              label: String.fromCharCode(65 + i),
              text: s.ct(o),
              state: checked
                  ? (i == q.correctOption ? ChoiceState.correct : (i == answer.picked ? ChoiceState.wrong : ChoiceState.idle))
                  : (i == _picked ? ChoiceState.selected : ChoiceState.idle),
              onTap: checked ? null : () => setState(() => _picked = i),
            ),
          if (!checked)
            FilledButton(
              onPressed: _picked == null ? null : () => _record(_picked == q.correctOption, picked: _picked),
              child: Text(st.checkAnswer),
            ),
        ] else ...[
          if (!_revealed) ...[
            Text(st.selfCheckHint, style: const TextStyle(color: LabColors.muted, height: 1.4)),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: () => setState(() => _revealed = true),
              icon: const Icon(Icons.visibility_rounded),
              label: Text(st.showModelAnswer),
            ),
          ],
        ],
        if (checked || _revealed) ...[
          const SizedBox(height: 12),
          if (q.isChoice)
            Text(
              answer!.correct ? s.correctAnswer : s.notQuite,
              style: TextStyle(fontWeight: FontWeight.w800, color: answer.correct ? LabColors.success : LabColors.danger),
            )
          else ...[
            Text(s.modelAnswer, style: AppText.display(14, color: LabColors.success)),
            const SizedBox(height: 4),
            BodyText(s.ct(q.answer)),
          ],
          const SizedBox(height: 10),
          Text(q.type.name == 'numerical' ? st.solutionSteps : s.explanationLabel, style: AppText.display(14, color: LabColors.primary)),
          const SizedBox(height: 4),
          BodyText(s.ct(q.explanation)),
          const SizedBox(height: 16),
          if (!q.isChoice && !checked)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(foregroundColor: LabColors.danger),
                    onPressed: () => _record(false),
                    icon: const Icon(Icons.close_rounded),
                    label: Text(st.iGotItWrong),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: LabColors.success),
                    onPressed: () => _record(true),
                    icon: const Icon(Icons.check_rounded),
                    label: Text(st.iGotItRight),
                  ),
                ),
              ],
            )
          else
            FilledButton(onPressed: _next, child: Text(_index < _questions.length - 1 ? st.next : st.finish)),
        ],
      ],
    );
  }

  Widget _results(BuildContext context) {
    final st = context.study;
    final answered = [for (final q in _questions) if (_answers[q.id] case final a?) (q, a)];
    final correct = answered.where((e) => e.$2.correct).length;
    final wrong = [for (final (q, a) in answered) if (!a.correct) q];
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Icon(Icons.emoji_events_rounded, size: 56, color: LabColors.warning),
        const SizedBox(height: 8),
        Text(st.sessionComplete, textAlign: TextAlign.center, style: AppText.display(22)),
        const SizedBox(height: 6),
        Text(st.scoreLine(correct, answered.length), textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, color: LabColors.ink)),
        if (_questions.any((q) => !q.isChoice)) ...[
          const SizedBox(height: 4),
          Text(st.selfMarkedNote, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: LabColors.muted)),
        ],
        const SizedBox(height: 20),
        if (wrong.isNotEmpty)
          FilledButton.icon(onPressed: () => _restartWith(wrong), icon: const Icon(Icons.replay_rounded), label: Text('${st.retryWrong} · ${wrong.length}')),
        const SizedBox(height: 8),
        OutlinedButton.icon(onPressed: () => setState(() => _reviewing = true), icon: const Icon(Icons.fact_check_outlined), label: Text(st.reviewAnswers)),
        const SizedBox(height: 8),
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(st.done)),
      ],
    );
  }

  Widget _review(BuildContext context) {
    final s = context.strings;
    final st = context.study;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(onPressed: () => setState(() => _reviewing = false), icon: const Icon(Icons.arrow_back_rounded), label: Text(st.sessionComplete)),
        ),
        for (final (i, q) in _questions.indexed)
          Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text('${i + 1}. ${s.questionTypeName(q.type)} · ${s.difficultyName(q.difficulty)}', style: const TextStyle(color: LabColors.muted, fontSize: 12))),
                      if (_answers[q.id] case final a?)
                        Icon(a.correct ? Icons.check_circle_rounded : Icons.cancel_rounded, color: a.correct ? LabColors.success : LabColors.danger, size: 20),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(s.ct(q.question), style: const TextStyle(fontWeight: FontWeight.w600, height: 1.45, color: LabColors.ink)),
                  if (q.isChoice) ...[
                    const SizedBox(height: 6),
                    if (_answers[q.id]?.picked case final p? when p != q.correctOption)
                      Text('${st.yourAnswer}: ${String.fromCharCode(65 + p)}. ${s.ct(q.options[p])}', style: const TextStyle(color: LabColors.danger, height: 1.4)),
                    Text('${st.correctOptionLabel}: ${String.fromCharCode(65 + q.correctOption!)}. ${s.ct(q.options[q.correctOption!])}',
                        style: const TextStyle(color: LabColors.success, fontWeight: FontWeight.w700, height: 1.4)),
                  ] else ...[
                    const SizedBox(height: 6),
                    Text(s.modelAnswer, style: AppText.display(13, color: LabColors.success)),
                    BodyText(s.ct(q.answer)),
                  ],
                  const SizedBox(height: 6),
                  BodyText(s.ct(q.explanation)),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

enum ChoiceState { idle, selected, correct, wrong }

/// One option of a choice question.
class ChoiceOption extends StatelessWidget {
  const ChoiceOption({super.key, required this.label, required this.text, required this.state, required this.onTap});

  final String label;
  final String text;
  final ChoiceState state;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = switch (state) {
      ChoiceState.correct => LabColors.success,
      ChoiceState.wrong => LabColors.danger,
      ChoiceState.selected => LabColors.primary,
      ChoiceState.idle => LabColors.muted,
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: state == ChoiceState.idle ? Colors.white : color.withValues(alpha: 0.1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: state == ChoiceState.idle ? LabColors.line : color, width: state == ChoiceState.idle ? 1 : 1.5),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Text('$label.', style: TextStyle(fontWeight: FontWeight.w800, color: color)),
                  const SizedBox(width: 8),
                  Expanded(child: Text(text, style: const TextStyle(height: 1.4, color: LabColors.ink))),
                  if (state == ChoiceState.correct || state == ChoiceState.wrong)
                    Icon(state == ChoiceState.correct ? Icons.check_circle_rounded : Icons.cancel_rounded, size: 18, color: color),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
