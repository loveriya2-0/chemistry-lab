import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../content/content_catalog.dart';
import '../content/models/syllabus.dart';
import '../core/theme.dart';
import '../l10n/app_strings.dart';
import '../l10n/study_strings.dart';
import '../state/app_state.dart';
import '../study/study_map.dart';
import '../study/study_progress_store.dart';
import '../widgets/chapter_style.dart';
import '../widgets/empty_state.dart';
import '../widgets/info_pill.dart';
import '../widgets/language_toggle.dart';
import '../widgets/ui_kit.dart';
import 'search_screen.dart';
import 'topic_list_screen.dart';

/// All chapters of the selected board, one class at a time. Used as the
/// Learn tab and when a class is picked on Home.
class ChapterListScreen extends StatelessWidget {
  const ChapterListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final curriculum = context.read<ContentCatalog>().curriculum(app.boardId!)!;
    final classLevel = curriculum.classes.containsKey(app.selectedClass) ? app.selectedClass! : curriculum.classLevels.first;
    final syllabus = curriculum.classes[classLevel]!;
    final s = context.strings;
    final examChapters = syllabus.examChapters;
    final extras = syllabus.chapters.where((c) => !c.inYearEndExam).toList();
    final progress = context.watch<StudyProgressStore>();

    void open(Chapter chapter) => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => TopicListScreen(syllabus: syllabus, chapter: chapter),
        ));

    Widget card(Chapter chapter, int index) => FadeSlideIn(
          index: index,
          child: _ChapterCard(
            chapter: chapter,
            study: StudyMap.chapter(chapter, progress),
            accent: chapterAccent(index),
            hasLab: chapter.topics
                .expand((t) => t.selfAndDescendants)
                .any((t) => curriculum.labsForTopic(t.id).isNotEmpty),
            onTap: () => open(chapter),
          ),
        );

    return Scaffold(
      appBar: AppBar(
        title: Text(s.classChapters(classLevel)),
        actions: [
          IconButton(
            tooltip: s.search,
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SearchScreen())),
            icon: const Icon(Icons.search_rounded),
          ),
          const LanguageToggle(),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final c in curriculum.classLevels)
                ChoiceChip(
                  label: Text(s.className(c)),
                  selected: c == classLevel,
                  onSelected: (_) => context.read<AppState>().selectClass(c),
                ),
            ],
          ),
          const SizedBox(height: 12),
          _SubjectHeader(syllabus: syllabus, academicYear: curriculum.manifest.academicYear),
          const SizedBox(height: 16),
          if (syllabus.chapters.isEmpty) EmptyState(message: s.noChapters),
          for (final (i, chapter) in examChapters.indexed) ...[card(chapter, i), const SizedBox(height: 12)],
          if (extras.isNotEmpty) ...[
            const SizedBox(height: 6),
            SectionHeader(s.alsoInSyllabus),
            Text(s.formativeNote, style: const TextStyle(color: LabColors.muted, height: 1.4)),
            const SizedBox(height: 12),
            for (final (i, chapter) in extras.indexed) ...[
              card(chapter, examChapters.length + i),
              const SizedBox(height: 12),
            ],
          ],
          _SourceNote(text: s.syllabusSource),
        ],
      ),
    );
  }
}

class _ChapterCard extends StatelessWidget {
  const _ChapterCard({required this.chapter, required this.study, required this.accent, required this.hasLab, required this.onTap});

  final Chapter chapter;
  final ChapterStudy study;
  final Color accent;
  final bool hasLab;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    final subtopics = chapter.topics.fold(0, (n, t) => n + t.subtopics.length);
    final number = chapter.number;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ElementTile(number: number == null ? '+' : number.toString().padLeft(2, '0'), color: accent, size: 52),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          number == null ? s.alsoInSyllabus.toUpperCase() : s.chapterOverline(number),
                          style: TextStyle(color: accent, fontWeight: FontWeight.w800, fontSize: 11, letterSpacing: 0.6),
                        ),
                        const SizedBox(height: 2),
                        Text(s.ct(chapter.title), style: AppText.display(16, height: 1.25)),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: accent),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                s.ct(chapter.description),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: LabColors.muted, height: 1.4),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  if (chapter.topics.isNotEmpty) InfoPill(icon: Icons.topic_rounded, label: s.topicCount(chapter.topics.length)),
                  if (subtopics > 0) InfoPill(icon: Icons.segment_rounded, label: s.subtopicCount(subtopics)),
                  switch (chapter.weightage.scope) {
                    WeightageScope.chapter => InfoPill(icon: Icons.grade_rounded, label: s.chapterMarks(chapter.weightage.marks)),
                    WeightageScope.unit => InfoPill(icon: Icons.grade_rounded, label: s.unitMarks(chapter.weightage.marks)),
                    WeightageScope.notInYearEndExam => InfoPill(icon: Icons.info_outline_rounded, label: s.notInExam),
                    WeightageScope.notPublished => InfoPill(icon: Icons.grade_outlined, label: s.marksNotPublished),
                  },
                  if (hasLab) InfoPill(icon: Icons.science_rounded, label: s.interactiveLab),
                  if (study.isStarted) InfoPill(icon: Icons.check_circle_outline_rounded, label: context.study.topicsStudied(study.studied, study.total)),
                ],
              ),
              if (study.isStarted) ...[
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(value: study.fraction, minHeight: 4, color: accent, backgroundColor: LabColors.line),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Subject, syllabus year and unit marks above the chapter list.
class _SubjectHeader extends StatelessWidget {
  const _SubjectHeader({required this.syllabus, required this.academicYear});

  final ClassSyllabus syllabus;
  final String academicYear;

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    return HeroPanel(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${s.ct(syllabus.subjectName)} · ${s.syllabusYear(academicYear)}'.toUpperCase(),
            style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.6),
          ),
          const SizedBox(height: 6),
          Text(s.chapterCount(syllabus.examChapters.length), style: AppText.display(24, color: Colors.white)),
          for (final u in syllabus.units) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: 260,
              child: Text('${s.ct(u.name)} · ${s.unitMarks(u.marks)}', style: const TextStyle(color: Colors.white, height: 1.35)),
            ),
          ],
          if (syllabus.examPattern.practicalMarks != null) ...[
            const SizedBox(height: 8),
            Text(
              '${s.chapterMarks(syllabus.examPattern.theoryMarks)} + ${s.chapterMarks(syllabus.examPattern.practicalMarks!)}',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}

class _SourceNote extends StatelessWidget {
  const _SourceNote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.verified_outlined, size: 16, color: LabColors.muted),
          const SizedBox(width: 6),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 12, color: LabColors.muted))),
        ],
      ),
    );
  }
}
