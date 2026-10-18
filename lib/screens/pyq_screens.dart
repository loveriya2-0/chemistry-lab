import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../content/content_catalog.dart';
import '../content/models/pyq.dart';
import '../core/theme.dart';
import '../data/bookmark_store.dart';
import '../l10n/app_strings.dart';
import '../state/app_state.dart';
import '../widgets/info_pill.dart';
import '../widgets/language_toggle.dart';
import '../l10n/premium_strings.dart';
import '../widgets/learning_widgets.dart' show ReviewLabel;
import '../widgets/premium_gate.dart';
import '../widgets/ui_kit.dart';

/// Reviewed PYQs of one class, optionally narrowed to a chapter, year or
/// marks value. Shows an honest empty state while none are entered.
List<PyqQuestion> reviewedPyqs(BuildContext context, int classLevel) {
  final curriculum = context.read<ContentCatalog>().curriculum(context.read<AppState>().boardId!)!;
  return [
    for (final q in curriculum.pyqsForClass(classLevel))
      if (q.isPublishable) q,
  ];
}

class PyqListScreen extends StatelessWidget {
  const PyqListScreen({super.key, required this.classLevel, required this.title, this.filter});

  final int classLevel;
  final String title;
  final bool Function(PyqQuestion)? filter;

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    final questions = reviewedPyqs(context, classLevel).where(filter ?? (_) => true).toList()
      ..sort((a, b) => b.examYear.compareTo(a.examYear));
    return PremiumGate(title: title, body: context.premium.lockedPyqs, locked: questions.isNotEmpty, child: Scaffold(
      appBar: AppBar(title: Text(title), actions: const [LanguageToggle()]),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          if (questions.isEmpty)
            ComingSoonPanel(icon: Icons.history_edu_rounded, title: s.noPyqsYet, body: s.pyqsBeingAdded)
          else ...[
            Text(s.pyqCount(questions.length), style: const TextStyle(color: LabColors.muted)),
            const SizedBox(height: 8),
            for (final q in questions) PyqTile(question: q),
          ],
        ],
      ),
    ));
  }
}

class PyqTile extends StatelessWidget {
  const PyqTile({super.key, required this.question});

  final PyqQuestion question;

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    final q = question;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(q.summary == null ? s.questionRef(q.questionNumber, q.paperCode) : s.ct(q.summary!), maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Text('${q.examYear} · ${s.marksN(q.marks)} · ${s.questionTypeName(q.type)}'),
        trailing: Icon(context.isPremium ? Icons.chevron_right_rounded : Icons.lock_rounded),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => PyqDetailScreen(question: q))),
      ),
    );
  }
}

/// One PYQ: reference to the official paper, our summary, and the answer
/// hidden until the student asks for it.
class PyqDetailScreen extends StatefulWidget {
  const PyqDetailScreen({super.key, required this.question});

  final PyqQuestion question;

  @override
  State<PyqDetailScreen> createState() => _PyqDetailScreenState();
}

class _PyqDetailScreenState extends State<PyqDetailScreen> {
  bool _showAnswer = false;

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    final q = widget.question;
    final bookmarks = context.watch<BookmarkStore>();
    final key = 'pyq:${q.id}';
    final curriculum = context.read<ContentCatalog>().curriculum(context.read<AppState>().boardId!);
    final chapter = curriculum?.chapter(q.chapterId)?.$2;
    final topic = q.topicId == null ? null : curriculum?.topic(q.topicId!)?.topic;
    return PremiumGate(title: '${q.examYear}', body: context.premium.lockedPyqs, child: Scaffold(
      appBar: AppBar(
        title: Text('${q.examYear}'),
        actions: [
          IconButton(
            tooltip: bookmarks.contains(key) ? s.bookmarked : s.bookmark,
            onPressed: () => bookmarks.toggle(key),
            icon: Icon(bookmarks.contains(key) ? Icons.bookmark_rounded : Icons.bookmark_border_rounded),
          ),
          const LanguageToggle(),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              InfoPill(icon: Icons.event_rounded, label: '${q.examYear}'),
              InfoPill(icon: Icons.grade_rounded, label: s.marksN(q.marks)),
              InfoPill(icon: Icons.description_outlined, label: s.questionRef(q.questionNumber, q.paperCode)),
              InfoPill(icon: Icons.category_outlined, label: s.questionTypeName(q.type)),
            ],
          ),
          if (chapter != null) ...[
            const SizedBox(height: 8),
            Text(
              [s.ct(chapter.title), if (topic != null) '${topic.number} ${s.ct(topic.title)}'].join(' › '),
              style: const TextStyle(color: LabColors.muted, fontWeight: FontWeight.w600),
            ),
          ],
          const SizedBox(height: 12),
          if (q.summary != null)
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.ct(q.summary!), style: const TextStyle(fontSize: 16, height: 1.5, color: LabColors.ink)),
                    for (final (i, o) in q.options.indexed)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          '${String.fromCharCode(65 + i)}. ${s.ct(o)}',
                          style: TextStyle(
                            height: 1.4,
                            color: _showAnswer && i == q.correctOption ? LabColors.success : LabColors.ink,
                            fontWeight: _showAnswer && i == q.correctOption ? FontWeight.w800 : FontWeight.w400,
                          ),
                        ),
                      ),
                    const SizedBox(height: 8),
                    Text(s.summaryNote, style: const TextStyle(fontSize: 12, color: LabColors.muted)),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 8),
          SelectableText('${s.officialPaperLink}: ${q.paperUrl}', style: const TextStyle(fontSize: 12, color: LabColors.muted)),
          if (q.isPublishable && q.paperUrl.startsWith('https://')) ...[
            const SizedBox(height: 8),
            ReviewLabel(review: q.review),
          ],
          const SizedBox(height: 16),
          if (q.answer != null) ...[
            if (!_showAnswer) Text(s.tryFirst, style: const TextStyle(color: LabColors.muted)),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => setState(() => _showAnswer = !_showAnswer),
              icon: Icon(_showAnswer ? Icons.visibility_off_rounded : Icons.visibility_rounded),
              label: Text(_showAnswer ? s.hideAnswer : s.showAnswer),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 250),
              child: _showAnswer
                  ? Card(
                      margin: const EdgeInsets.only(top: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(s.modelAnswer, style: AppText.display(15, color: LabColors.success)),
                            const SizedBox(height: 8),
                            Text(s.ct(q.answer!), style: const TextStyle(height: 1.5)),
                          ],
                        ),
                      ),
                    )
                  : const SizedBox(width: double.infinity),
            ),
          ],
        ],
      ),
    ));
  }
}

/// Self-check practice over reviewed PYQs: read, reveal, next.
class PracticeScreen extends StatefulWidget {
  const PracticeScreen({super.key, required this.classLevel});

  final int classLevel;

  @override
  State<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends State<PracticeScreen> {
  int _index = 0;
  bool _revealed = false;

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    final questions = [for (final q in reviewedPyqs(context, widget.classLevel)) if (q.summary != null && q.answer != null) q];
    return PremiumGate(title: s.practiceMode, body: context.premium.lockedPyqs, locked: questions.isNotEmpty, child: Scaffold(
      appBar: AppBar(title: Text(s.practiceMode), actions: const [LanguageToggle()]),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          if (questions.isEmpty)
            ComingSoonPanel(icon: Icons.quiz_rounded, title: s.practiceMode, body: s.practiceEmpty)
          else ...[
            Text(s.questionOf(_index + 1, questions.length), style: const TextStyle(color: LabColors.muted)),
            const SizedBox(height: 8),
            LinearProgressIndicator(value: (_index + 1) / questions.length, borderRadius: BorderRadius.circular(8)),
            const SizedBox(height: 16),
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.ct(questions[_index].summary!), style: const TextStyle(fontSize: 16, height: 1.5)),
                    for (final (i, o) in questions[_index].options.indexed)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          '${String.fromCharCode(65 + i)}. ${s.ct(o)}',
                          style: TextStyle(
                            height: 1.4,
                            color: _revealed && i == questions[_index].correctOption ? LabColors.success : LabColors.ink,
                            fontWeight: _revealed && i == questions[_index].correctOption ? FontWeight.w800 : FontWeight.w400,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (_revealed)
              Card(
                margin: EdgeInsets.zero,
                child: Padding(padding: const EdgeInsets.all(16), child: Text(s.ct(questions[_index].answer!))),
              ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => setState(() {
                if (!_revealed) {
                  _revealed = true;
                } else {
                  _revealed = false;
                  _index = (_index + 1) % questions.length;
                }
              }),
              child: Text(_revealed ? s.nextQuestion : s.showAnswer),
            ),
          ],
        ],
      ),
    ));
  }
}
