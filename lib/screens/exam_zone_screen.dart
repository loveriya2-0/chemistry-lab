import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../content/content_catalog.dart';
import '../content/models/syllabus.dart';
import '../core/theme.dart';
import '../l10n/app_strings.dart';
import '../l10n/premium_strings.dart';
import '../state/app_state.dart';
import '../widgets/chapter_style.dart';
import '../widgets/language_toggle.dart';
import '../widgets/premium_gate.dart';
import '../widgets/ui_kit.dart';
import 'pyq_screens.dart';
import 'question_bank_screen.dart';

/// Exam tab: board-exam classes only. Weightage comes from the verified
/// syllabus; PYQ lists open with honest empty states until official
/// questions are entered.
class ExamZoneScreen extends StatelessWidget {
  const ExamZoneScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    final app = context.watch<AppState>();
    final curriculum = context.read<ContentCatalog>().curriculum(app.boardId!)!;
    final examClasses = [for (final c in curriculum.classLevels) if (curriculum.classes[c]!.examPattern.boardExam) c];
    final years = curriculum.manifest.pyqExamYears;

    return Scaffold(
      appBar: AppBar(title: Text(s.examZone), actions: const [LanguageToggle()]),
      body: examClasses.isEmpty
          ? Padding(
              padding: const EdgeInsets.all(16),
              child: ComingSoonPanel(icon: Icons.assignment_rounded, title: s.examZone, body: s.examOnlyBoardClasses),
            )
          : _ExamBody(
              classLevel: examClasses.contains(app.selectedClass) ? app.selectedClass! : examClasses.last,
              examClasses: examClasses,
              years: years,
              curriculum: curriculum,
            ),
    );
  }
}

class _ExamBody extends StatelessWidget {
  const _ExamBody({required this.classLevel, required this.examClasses, required this.years, required this.curriculum});

  final int classLevel;
  final List<int> examClasses;
  final List<int> years;
  final LoadedCurriculum curriculum;

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    final syllabus = curriculum.classes[classLevel]!;
    final pyqs = reviewedPyqs(context, classLevel);
    final pyqsLocked = pyqs.isNotEmpty && !context.isPremium;

    void push(Widget w) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => w));

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        Wrap(
          spacing: 8,
          children: [
            for (final c in examClasses)
              ChoiceChip(
                label: Text(s.className(c)),
                selected: c == classLevel,
                onSelected: (_) => context.read<AppState>().selectClass(c),
              ),
          ],
        ),
        const SizedBox(height: 12),
        HeroPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${s.className(classLevel)} · ${s.ct(syllabus.subjectName)}'.toUpperCase(),
                style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.6),
              ),
              const SizedBox(height: 6),
              SizedBox(width: 240, child: Text(s.pyqTitle, style: AppText.display(22, color: Colors.white))),
              if (years.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(s.officialPapers(years.first, years.last), style: const TextStyle(color: Colors.white70)),
              ],
              if (pyqs.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(s.pyqCount(pyqs.length), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                if (curriculum.enteredExamYears.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    s.importanceBasis(curriculum.pyqPaperCount(classLevel), curriculum.enteredExamYears.first, curriculum.enteredExamYears.last),
                    style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
                  ),
                ],
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (pyqs.isEmpty) ComingSoonPanel(icon: Icons.history_edu_rounded, title: s.noPyqsYet, body: s.pyqsBeingAdded),
        const SizedBox(height: 16),
        if (pyqsLocked) ...[
          PremiumLockedCard(body: context.premium.lockedPyqs),
          const SizedBox(height: 16),
        ],
        SectionHeader(s.browsePyqs),
        _BrowseRow(
          locked: pyqsLocked,
          icon: Icons.menu_book_rounded,
          label: s.byChapter,
          onTap: () => push(_ChapterPicker(syllabus: syllabus)),
        ),
        _BrowseRow(
          locked: pyqsLocked,
          icon: Icons.event_rounded,
          label: s.byYear,
          onTap: () => push(_Picker(
            title: s.byYear,
            options: [for (final y in years.reversed) ('$y', y)],
            open: (y) => PyqListScreen(classLevel: classLevel, title: '$y', filter: (q) => q.examYear == y),
          )),
        ),
        _BrowseRow(
          locked: pyqsLocked,
          icon: Icons.grade_rounded,
          label: s.byMarks,
          onTap: () => push(_Picker(
            title: s.byMarks,
            options: [for (final m in const [1, 2, 3, 4, 5]) (s.marksN(m), m)],
            open: (m) => PyqListScreen(classLevel: classLevel, title: s.marksN(m), filter: (q) => q.marks == m),
          )),
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: () => push(PracticeScreen(classLevel: classLevel)),
          icon: const Icon(Icons.quiz_rounded),
          label: Text(s.startPractice),
        ),
        if (curriculum.practiceQuestions(classLevel: classLevel).isNotEmpty) ...[
          const SizedBox(height: 8),
          FilledButton.tonalIcon(
            onPressed: () => push(QuestionBankScreen(classLevel: classLevel, title: s.practiceQuestions)),
            icon: const Icon(Icons.edit_note_rounded),
            label: Text(s.practiceQuestions),
          ),
        ],
        const SizedBox(height: 20),
        SectionHeader(s.chapterWeightage),
        _Weightage(syllabus: syllabus),
        const SizedBox(height: 16),
        for (final note in [s.noPaperNote2021, s.termNote, if (classLevel == 10) s.secondExamNote])
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline_rounded, size: 16, color: LabColors.muted),
                const SizedBox(width: 6),
                Expanded(child: Text(note, style: const TextStyle(fontSize: 12, color: LabColors.muted, height: 1.4))),
              ],
            ),
          ),
      ],
    );
  }
}

class _BrowseRow extends StatelessWidget {
  const _BrowseRow({required this.icon, required this.label, required this.onTap, this.locked = false});

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: IconTile(icon: icon, color: LabColors.primary, size: 36),
        title: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        trailing: Icon(locked ? Icons.lock_rounded : Icons.chevron_right_rounded),
        onTap: onTap,
      ),
    );
  }
}

/// Unit (or chapter) marks as horizontal bars, out of the theory total.
class _Weightage extends StatelessWidget {
  const _Weightage({required this.syllabus});

  final ClassSyllabus syllabus;

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    final total = syllabus.examPattern.theoryMarks;
    final rows = <(String, int)>[
      if (syllabus.units.isNotEmpty)
        for (final u in syllabus.units) (s.ct(u.name), u.marks)
      else
        for (final c in syllabus.examChapters)
          if (c.weightage.scope == WeightageScope.chapter) (s.ct(c.title), c.weightage.marks),
    ];
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            for (final (i, (label, marks)) in rows.indexed) ...[
              Row(
                children: [
                  Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, color: LabColors.ink))),
                  const SizedBox(width: 8),
                  Text(s.marksN(marks), style: const TextStyle(fontWeight: FontWeight.w800, color: LabColors.ink)),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: total == 0 ? 0 : marks / total,
                  minHeight: 8,
                  color: chapterAccent(i),
                  backgroundColor: LabColors.line,
                ),
              ),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }
}

class _ChapterPicker extends StatelessWidget {
  const _ChapterPicker({required this.syllabus});

  final ClassSyllabus syllabus;

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    return _Picker(
      title: s.byChapter,
      options: [for (final c in syllabus.examChapters) (s.ct(c.title), c)],
      open: (Chapter c) => PyqListScreen(classLevel: syllabus.classLevel, title: s.ct(c.title), filter: (q) => q.chapterId == c.id),
    );
  }
}

class _Picker<T> extends StatelessWidget {
  const _Picker({required this.title, required this.options, required this.open});

  final String title;
  final List<(String, T)> options;
  final Widget Function(T) open;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title), actions: const [LanguageToggle()]),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          for (final (label, value) in options)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => open(value))),
              ),
            ),
        ],
      ),
    );
  }
}
