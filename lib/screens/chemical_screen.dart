import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../ai/tutor_context.dart';
import '../content/content_catalog.dart';
import '../content/models/chemical_entry.dart';
import '../core/theme.dart';
import '../l10n/app_strings.dart';
import '../state/app_state.dart';
import '../widgets/ask_ai.dart';
import '../widgets/language_toggle.dart';
import '../widgets/learning_widgets.dart';
import '../widgets/ui_kit.dart';
import 'topic_detail_screen.dart';

/// One chemical or named reaction: formula, properties, uses, balanced
/// equations, explanation, lab connection and the topics that use it.
class ChemicalScreen extends StatelessWidget {
  const ChemicalScreen({super.key, required this.chemical});

  final ChemicalEntry chemical;

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    final curriculum = context.read<ContentCatalog>().curriculum(context.read<AppState>().boardId!)!;
    final x = chemical;
    final topics = curriculum.topicsForChemical(x.id);
    TutorContext tutorContext() => TutorContext.forChemical(curriculum, x, boardName: currentBoardName(context));

    return Scaffold(
      appBar: AppBar(title: Text(s.chemicalsAndReactions), actions: [AskAiAction(tutorContext: tutorContext), const LanguageToggle()]),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          HeroPanel(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.chemicalKindName(x.kind).toUpperCase(),
                  style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.6),
                ),
                const SizedBox(height: 6),
                Text(s.ct(x.name), style: AppText.display(22, color: Colors.white, height: 1.25)),
                if (x.formula != null) ...[
                  const SizedBox(height: 8),
                  Text('${s.formulaLabel}: ${x.formula}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          ContentSection(title: s.explanationTitle, child: BodyText(s.ct(x.explanation))),
          if (x.equations.isNotEmpty)
            ContentSection(title: s.equationsTitle, child: Column(children: [for (final e in x.equations) FormulaBox(e)])),
          ContentSection(title: s.propertiesTitle, child: BulletList([for (final p in x.properties) s.ct(p)])),
          ContentSection(title: s.usesTitle, color: LabColors.teal, child: BulletList([for (final u in x.uses) s.ct(u)], color: LabColors.teal)),
          if (x.practicalNote != null)
            ContentSection(title: s.practicalConnection, color: LabColors.amber, child: BodyText(s.ct(x.practicalNote!))),
          AskAiCard(tutorContext: tutorContext),
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
          ProvenanceNote(sources: x.sources, review: x.review, curriculum: curriculum),
        ],
      ),
    );
  }
}
