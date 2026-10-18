import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../ai/tutor_context.dart';
import '../content/content_catalog.dart';
import '../content/content_text.dart';
import '../content/models/concept.dart';
import '../content/models/pyq.dart';
import '../core/theme.dart';
import '../l10n/app_strings.dart';
import '../state/app_state.dart';
import '../widgets/ask_ai.dart';
import '../widgets/language_toggle.dart';
import '../widgets/learning_widgets.dart';
import '../widgets/ui_kit.dart';
import 'pyq_screens.dart';
import 'topic_detail_screen.dart';

/// A reviewed concept note in the approved order: what, how, why, uses,
/// observations, exam importance, formulas/reactions, related PYQs.
///
/// Sections without text are left out; exam importance is computed from
/// PYQ data, never typed in.
class ConceptScreen extends StatelessWidget {
  const ConceptScreen({super.key, required this.concept, required this.classLevel});

  final Concept concept;
  final int classLevel;

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    final curriculum = context.read<ContentCatalog>().curriculum(context.read<AppState>().boardId!)!;
    final related = [
      for (final q in curriculum.pyqs)
        if (q.conceptIds.contains(concept.id) && q.isPublishable) q,
    ];
    final importance = ExamImportance.fromQuestions(related, examYears: curriculum.enteredExamYears);
    final topics = curriculum.topicsForConcept(concept.id);
    final relatedConcepts = [for (final id in concept.relatedConceptIds) ?curriculum.concepts[id]];

    Widget section(String title, ContentText? text) => text == null
        ? const SizedBox.shrink()
        : _Section(title: title, child: Text(s.ct(text), style: const TextStyle(height: 1.5, color: LabColors.ink)));

    final sec = concept.sections;
    return Scaffold(
      appBar: AppBar(
        title: Text(s.conceptNotes),
        actions: [
          AskAiAction(
            tutorContext: () => TutorContext.forConcept(curriculum, concept, classLevel: classLevel, boardName: currentBoardName(context)),
          ),
          const LanguageToggle(),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          HeroPanel(
            padding: const EdgeInsets.all(18),
            child: Text(s.ct(concept.title), style: AppText.display(24, color: Colors.white)),
          ),
          const SizedBox(height: 14),
          section(s.sectionWhat, sec[ConceptSection.whatIsIt]),
          section(s.sectionHow, sec[ConceptSection.howItWorks]),
          section(s.sectionWhy, sec[ConceptSection.whyImportant]),
          section(s.sectionUses, sec[ConceptSection.realLifeUses]),
          section(s.sectionObservations, sec[ConceptSection.keyObservations]),
          if (importance.level != ImportanceLevel.none)
            _Section(title: s.sectionExam, child: ImportanceBadge(importance: importance)),
          section(s.sectionRemember, sec[ConceptSection.rememberForExam]),
          section(s.sectionMistakes, sec[ConceptSection.commonMistakes]),
          if (concept.equations.isNotEmpty)
            _Section(
              title: s.sectionFormulas,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final e in concept.equations)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: LabColors.primarySoft, borderRadius: BorderRadius.circular(12)),
                      child: Text(e, style: const TextStyle(fontWeight: FontWeight.w700, color: LabColors.ink)),
                    ),
                ],
              ),
            ),
          if (related.isNotEmpty)
            _Section(
              title: s.sectionPyqs,
              child: Column(children: [for (final q in related) PyqTile(question: q)]),
            ),
          if (topics.isNotEmpty) ...[
            SectionHeader(s.relatedTopics),
            for (final loc in topics)
              LinkTile(
                icon: Icons.menu_book_rounded,
                title: '${loc.topic.number} ${s.ct(loc.topic.title)}',
                subtitle: '${s.className(loc.syllabus.classLevel)} · ${s.ct(loc.chapter.title)}',
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => TopicDetailScreen(syllabus: loc.syllabus, chapter: loc.chapter, topic: loc.topic),
                )),
              ),
          ],
          if (relatedConcepts.isNotEmpty) ...[
            SectionHeader(s.relatedConcepts),
            for (final c in relatedConcepts)
              LinkTile(
                icon: Icons.lightbulb_outline_rounded,
                color: LabColors.teal,
                title: s.ct(c.title),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => ConceptScreen(concept: c, classLevel: classLevel),
                )),
              ),
          ],
          if (concept.sources.isNotEmpty) ProvenanceNote(sources: concept.sources, review: concept.review, curriculum: curriculum),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: AppText.display(15, color: LabColors.primary)),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
}

/// High / medium / low label with the years it was asked in.
class ImportanceBadge extends StatelessWidget {
  const ImportanceBadge({super.key, required this.importance});

  final ExamImportance importance;

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    final (label, color) = switch (importance.level) {
      ImportanceLevel.high => (s.importanceHigh, LabColors.danger),
      ImportanceLevel.medium => (s.importanceMedium, LabColors.warning),
      _ => (s.importanceLow, LabColors.teal),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
          child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w800)),
        ),
        const SizedBox(height: 6),
        Text('${s.askedInYears}: ${importance.askedInYears.join(', ')}', style: const TextStyle(color: LabColors.muted)),
      ],
    );
  }
}
