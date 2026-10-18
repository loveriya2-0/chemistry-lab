import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../content/content_catalog.dart';
import '../content/content_text.dart';
import '../content/models/practice_question.dart';
import '../content/models/pyq.dart';
import '../content/models/review.dart';
import '../content/models/syllabus.dart';
import '../content/models/topic_note.dart';
import '../core/theme.dart';
import '../data/bookmark_store.dart';
import '../l10n/app_strings.dart';
import '../l10n/study_strings.dart';
import '../study/study_progress_store.dart';
import 'info_pill.dart';

/// Card with a coloured heading, used for every content section.
class ContentSection extends StatelessWidget {
  const ContentSection({super.key, required this.title, required this.child, this.color = LabColors.primary});

  final String title;
  final Widget child;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: AppText.display(15, color: color)),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
}

class BodyText extends StatelessWidget {
  const BodyText(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Text(text, style: const TextStyle(height: 1.5, color: LabColors.ink));
}

class BulletList extends StatelessWidget {
  const BulletList(this.items, {super.key, this.color = LabColors.primary});

  final List<String> items;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 7, right: 8),
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                  ),
                ),
                Expanded(child: BodyText(item)),
              ],
            ),
          ),
      ],
    );
  }
}

/// A formula or balanced equation, in a tinted box that scrolls sideways
/// if it is wider than a small phone.
class FormulaBox extends StatelessWidget {
  const FormulaBox(this.formula, {super.key, this.saved, this.onToggleSave});

  final String formula;

  /// With [onToggleSave], a bookmark button saves the formula for revision.
  final bool? saved;
  final VoidCallback? onToggleSave;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: LabColors.primarySoft, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Text(
                formula,
                style: const TextStyle(fontWeight: FontWeight.w700, color: LabColors.ink),
              ),
            ),
          ),
          if (onToggleSave != null)
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: (saved ?? false) ? context.study.formulaSaved : context.study.saveFormula,
              onPressed: onToggleSave,
              icon: Icon((saved ?? false) ? Icons.bookmark_rounded : Icons.bookmark_border_rounded, size: 20, color: LabColors.primary),
            ),
        ],
      ),
    );
  }
}

/// "Source: NCERT … §2.3" plus the review state, under every piece of
/// written content.
class ProvenanceNote extends StatelessWidget {
  const ProvenanceNote({super.key, required this.sources, required this.review, required this.curriculum});

  final List<SourceRef> sources;
  final ReviewStatus review;
  final LoadedCurriculum curriculum;

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    final titles = {for (final src in curriculum.manifest.sources) src.id: src.title};
    final line = [
      for (final r in sources) [titles[r.sourceId] ?? r.sourceId, if (r.section != null) '§${r.section}'].join(' '),
    ].join('; ');
    // The label is earned only by content that cites sources we actually have.
    final checked = sources.isNotEmpty && sources.every((r) => titles.containsKey(r.sourceId));
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (checked && review.isPublishable) ...[ReviewLabel(review: review), const SizedBox(height: 6)],
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.verified_outlined, size: 16, color: LabColors.muted),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  [s.sourceLine(line), if (review != ReviewStatus.verified) s.reviewNote].join('\n'),
                  style: const TextStyle(fontSize: 12, color: LabColors.muted, height: 1.4),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// "Source-checked" or "Teacher-verified" chip. Callers show it only when
/// the item really cites its sources.
class ReviewLabel extends StatelessWidget {
  const ReviewLabel({super.key, required this.review});

  final ReviewStatus review;

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    final verified = review == ReviewStatus.verified;
    final color = verified ? LabColors.success : LabColors.teal;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(verified ? Icons.verified_rounded : Icons.fact_check_outlined, size: 14, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              verified ? s.teacherVerifiedLabel : s.sourceCheckedLabel,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: color),
            ),
          ),
        ],
      ),
    );
  }
}

/// Every section of one topic note, in the approved order: concept,
/// easy explanation, memory trick, main points, reactions/formulas,
/// real-life use, exam importance, common mistakes, quick revision.
/// Optional sections (trick, formulas, quick revision) are hidden when
/// the note has none. Practice questions follow the note on its page.
class NoteView extends StatelessWidget {
  const NoteView({super.key, required this.note, required this.curriculum, this.showHeading = true, this.examImportance});

  final TopicNote note;
  final LoadedCurriculum curriculum;
  final bool showHeading;

  /// PYQ-based importance shown inside the exam section, if any.
  final Widget? examImportance;

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    String ct(ContentText t) => s.ct(t);
    final headings = [
      for (final id in note.allTargetIds)
        if (curriculum.topic(id)?.topic case final t?)
          '${t.number} ${s.ct(t.title)}'
        else if (curriculum.chapter(id)?.$2 case final c?)
          s.ct(c.title),
    ];
    final syllabus = curriculum.topic(note.targetId)?.syllabus ?? curriculum.chapter(note.targetId)?.$1;
    final practicals = [
      for (final id in note.practicalIds)
        if (syllabus?.practicals.where((p) => p.id == id).firstOrNull case final BoardPractical p) p,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showHeading)
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 4, 2, 10),
            child: Text(headings.join(' · '), style: AppText.display(17)),
          ),
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: LabColors.primarySoft,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: LabColors.primary.withValues(alpha: 0.18)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(s.definitionTitle, style: AppText.display(14, color: LabColors.primary)),
              const SizedBox(height: 6),
              Text(
                ct(note.definition),
                style: const TextStyle(height: 1.5, color: LabColors.ink, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
        ContentSection(title: s.easyExplanationTitle, child: BodyText(ct(note.explanation))),
        if (note.memoryTricks.isNotEmpty) MemoryTrickCard(tricks: note.memoryTricks),
        ContentSection(title: s.keyPointsTitle, color: LabColors.amber, child: BulletList([for (final p in note.keyPoints) ct(p)], color: LabColors.warning)),
        if (note.formulas.isNotEmpty)
          ContentSection(
            title: s.reactionFormulaTitle,
            child: Column(
              children: [
                for (final f in note.formulas)
                  if (context.watch<BookmarkStore?>() case final b?)
                    FormulaBox(
                      f,
                      saved: b.contains(BookmarkStore.formulaKey(note.id, f)),
                      onToggleSave: () => b.toggle(BookmarkStore.formulaKey(note.id, f)),
                    )
                  else
                    FormulaBox(f),
              ],
            ),
          ),
        ContentSection(title: s.realLifeTitle, color: LabColors.teal, child: BodyText(ct(note.realLife))),
        ContentSection(
          title: s.examFocusTitle,
          color: LabColors.secondary,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BodyText(ct(note.examFocus)),
              if (examImportance case final w?) ...[const Divider(height: 20), w],
            ],
          ),
        ),
        ContentSection(
          title: s.commonMistakesTitle,
          color: LabColors.danger,
          child: BulletList([for (final m in note.commonMistakes) ct(m)], color: LabColors.danger),
        ),
        if (note.quickRevision case final q?) QuickRevisionCard(revision: q),
        if (practicals.isNotEmpty)
          ContentSection(
            title: s.relatedPracticals,
            color: LabColors.amber,
            child: BulletList([for (final p in practicals) '${p.number}. ${s.ct(p.title)}'], color: LabColors.amber),
          ),
        ProvenanceNote(sources: note.sources, review: note.review, curriculum: curriculum),
      ],
    );
  }
}

/// "🧠 Memory trick": the mnemonic in large type, then what it stands for.
class MemoryTrickCard extends StatelessWidget {
  const MemoryTrickCard({super.key, required this.tricks});

  final List<MemoryTrick> tricks;

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: LabColors.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: LabColors.warning.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(s.memoryTrickTitle, style: AppText.display(15, color: LabColors.amber)),
          for (final (i, t) in tricks.indexed) ...[
            SizedBox(height: i == 0 ? 10 : 14),
            Text(
              s.ct(t.trick),
              style: const TextStyle(fontSize: 16, height: 1.4, fontWeight: FontWeight.w800, color: LabColors.ink),
            ),
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 2, right: 6),
                  child: Icon(Icons.arrow_forward_rounded, size: 16, color: LabColors.amber),
                ),
                Expanded(child: BodyText(s.ct(t.recall))),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// "⚡ Quick revision": one-line definition, the key formula and the
/// must-remember points.
class QuickRevisionCard extends StatelessWidget {
  const QuickRevisionCard({super.key, required this.revision});

  final QuickRevision revision;

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: LabColors.success.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: LabColors.success.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(s.quickRevisionTitle, style: AppText.display(15, color: LabColors.success)),
          const SizedBox(height: 8),
          Text(
            s.ct(revision.oneLine),
            style: const TextStyle(height: 1.5, color: LabColors.ink, fontWeight: FontWeight.w700),
          ),
          if (revision.formula case final f?) ...[const SizedBox(height: 8), FormulaBox(f)],
          const SizedBox(height: 8),
          Text(s.mustRemember, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: LabColors.muted)),
          const SizedBox(height: 4),
          BulletList([for (final p in revision.points) s.ct(p)], color: LabColors.success),
        ],
      ),
    );
  }
}

/// Exam importance from entered PYQs, with the basis spelled out. Shows
/// "not asked yet" instead of inventing a level.
class ImportancePanel extends StatelessWidget {
  const ImportancePanel({super.key, required this.importance, required this.curriculum, required this.classLevel, required this.badge});

  final ExamImportance importance;
  final LoadedCurriculum curriculum;

  /// Class whose entered papers are counted in the basis line.
  final int classLevel;

  /// The badge widget for a non-zero level (kept outside to reuse
  /// [ImportanceBadge] from the concept screen).
  final Widget badge;

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    final years = curriculum.enteredExamYears;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (importance.level == ImportanceLevel.none) BodyText(s.notAskedYet) else badge,
        if (years.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            s.importanceBasis(curriculum.pyqPaperCount(classLevel), years.first, years.last),
            style: const TextStyle(fontSize: 12, color: LabColors.muted, height: 1.4),
          ),
        ],
      ],
    );
  }
}

/// Tappable row linking to a concept, chemical or topic.
class LinkTile extends StatelessWidget {
  const LinkTile({super.key, required this.icon, required this.title, this.subtitle, required this.onTap, this.color = LabColors.primary});

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(11)),
          child: Icon(icon, color: color, size: 18),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w700, color: LabColors.ink),
        ),
        subtitle: subtitle == null ? null : Text(subtitle!, maxLines: 2, overflow: TextOverflow.ellipsis),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      ),
    );
  }
}

/// One practice question: tap an option (MCQ / assertion–reason) or
/// reveal the answer, then read the explanation.
class PracticeQuestionCard extends StatefulWidget {
  const PracticeQuestionCard({super.key, required this.question, this.index});

  final PracticeQuestion question;
  final int? index;

  @override
  State<PracticeQuestionCard> createState() => _PracticeQuestionCardState();
}

class _PracticeQuestionCardState extends State<PracticeQuestionCard> {
  int? _picked;
  bool _revealed = false;

  /// Self-mark for a written answer, once per showing of the card.
  bool? _selfMarked;

  /// Saves the answer once (the store may be absent in isolated previews).
  void _record(bool correct) => context.read<StudyProgressStore?>()?.recordAnswer(widget.question.id, correct: correct);

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    final q = widget.question;
    final answered = q.isChoice ? _picked != null : _revealed;
    final right = q.isChoice && _picked == q.correctOption;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                InfoPill(icon: Icons.category_outlined, label: s.questionTypeName(q.type)),
                InfoPill(icon: Icons.grade_rounded, label: s.marksN(q.marks)),
                InfoPill(icon: Icons.speed_rounded, label: s.difficultyName(q.difficulty)),
                if (context.watch<BookmarkStore?>() case final b?) _SaveQuestionButton(store: b, questionId: q.id),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              '${widget.index == null ? '' : '${widget.index}. '}${s.ct(q.question)}',
              style: const TextStyle(fontSize: 15, height: 1.5, color: LabColors.ink, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            if (q.isChoice)
              for (final (i, o) in q.options.indexed)
                _OptionTile(
                  label: String.fromCharCode(65 + i),
                  text: s.ct(o),
                  state: !answered
                      ? _OptionState.idle
                      : i == q.correctOption
                      ? _OptionState.correct
                      : i == _picked
                      ? _OptionState.wrong
                      : _OptionState.idle,
                  onTap: answered
                      ? null
                      : () {
                          setState(() => _picked = i);
                          _record(i == q.correctOption);
                        },
                )
            else
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: () => setState(() => _revealed = !_revealed),
                  icon: Icon(_revealed ? Icons.visibility_off_rounded : Icons.visibility_rounded),
                  label: Text(_revealed ? s.hideAnswer : s.showAnswer),
                ),
              ),
            if (answered) ...[
              const SizedBox(height: 8),
              if (q.isChoice)
                Text(
                  right ? s.correctAnswer : s.notQuite,
                  style: TextStyle(fontWeight: FontWeight.w800, color: right ? LabColors.success : LabColors.danger),
                ),
              if (!q.isChoice) ...[
                Text(s.modelAnswer, style: AppText.display(14, color: LabColors.success)),
                const SizedBox(height: 4),
                BodyText(s.ct(q.answer)),
              ],
              const SizedBox(height: 8),
              Text(s.explanationLabel, style: AppText.display(14, color: LabColors.primary)),
              const SizedBox(height: 4),
              BodyText(s.ct(q.explanation)),
              if (!q.isChoice && context.read<StudyProgressStore?>() != null) ...[
                const SizedBox(height: 10),
                _SelfMark(
                  marked: _selfMarked,
                  onMark: (right) {
                    setState(() => _selfMarked = right);
                    _record(right);
                  },
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

/// "I got it right / wrong" for a written answer; shows the choice once made.
class _SelfMark extends StatelessWidget {
  const _SelfMark({required this.marked, required this.onMark});

  final bool? marked;
  final ValueChanged<bool> onMark;

  @override
  Widget build(BuildContext context) {
    final st = context.study;
    if (marked case final m?) {
      return Row(
        children: [
          Icon(m ? Icons.check_circle_rounded : Icons.cancel_rounded, size: 18, color: m ? LabColors.success : LabColors.danger),
          const SizedBox(width: 6),
          Text(m ? st.markedRight : st.markedWrong, style: TextStyle(fontWeight: FontWeight.w700, color: m ? LabColors.success : LabColors.danger)),
        ],
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(foregroundColor: LabColors.danger),
          onPressed: () => onMark(false),
          icon: const Icon(Icons.close_rounded, size: 18),
          label: Text(st.iGotItWrong),
        ),
        FilledButton.tonalIcon(onPressed: () => onMark(true), icon: const Icon(Icons.check_rounded, size: 18), label: Text(st.iGotItRight)),
      ],
    );
  }
}

/// Bookmark toggle for one practice question.
class _SaveQuestionButton extends StatelessWidget {
  const _SaveQuestionButton({required this.store, required this.questionId});

  final BookmarkStore store;
  final String questionId;

  @override
  Widget build(BuildContext context) {
    final st = context.study;
    final key = BookmarkStore.questionKey(questionId);
    final saved = store.contains(key);
    return Semantics(
      button: true,
      label: saved ? st.questionSaved : st.saveQuestion,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => store.toggle(key),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          child: Icon(saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded, size: 20, color: LabColors.primary),
        ),
      ),
    );
  }
}

enum _OptionState { idle, correct, wrong }

class _OptionTile extends StatelessWidget {
  const _OptionTile({required this.label, required this.text, required this.state, required this.onTap});

  final String label;
  final String text;
  final _OptionState state;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = switch (state) {
      _OptionState.correct => LabColors.success,
      _OptionState.wrong => LabColors.danger,
      _OptionState.idle => LabColors.muted,
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: state == _OptionState.idle ? LabColors.background : color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$label.',
                  style: TextStyle(fontWeight: FontWeight.w800, color: color),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(text, style: const TextStyle(height: 1.4, color: LabColors.ink)),
                ),
                if (state != _OptionState.idle)
                  Icon(state == _OptionState.correct ? Icons.check_circle_rounded : Icons.cancel_rounded, size: 18, color: color),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
