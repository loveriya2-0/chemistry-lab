import 'package:flutter/material.dart';

import '../content/content_catalog.dart';
import '../content/models/syllabus.dart';
import '../core/theme.dart';
import '../l10n/app_strings.dart';
import '../models/reaction_info.dart';
import '../screens/concept_screen.dart' show ImportanceBadge;
import 'learning_widgets.dart';

/// The verified reaction behind a completed reaction lab: type, balanced
/// equation, reactants and products, what happened and why, a real-life
/// use and what to write in the exam.
///
/// With a [curriculum] and [topic] it also shows the topic's exam
/// importance, computed from the entered PYQs (never stored in the lab).
class ReactionSummary extends StatelessWidget {
  const ReactionSummary({super.key, required this.reaction, this.curriculum, this.topic, this.showImportance = false});

  final ReactionInfo reaction;
  final LoadedCurriculum? curriculum;
  final Topic? topic;

  /// The topic is in a board exam with entered papers.
  final bool showImportance;

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    final r = reaction;
    final importance = showImportance && curriculum != null && topic != null ? curriculum!.topicImportance(topic!) : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(color: LabColors.teal.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
          child: Text(s.tr(r.kind), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: LabColors.teal)),
        ),
        _heading(s.balancedEquation),
        FormulaBox(r.equation),
        _heading(s.reactantsTitle),
        BulletList([for (final x in r.reactants) s.tr(x)]),
        _heading(s.productsTitle),
        BulletList([for (final x in r.products) s.tr(x)], color: LabColors.success),
        _heading(s.whatHappenedTitle),
        BodyText(s.tr(r.whatHappened)),
        _heading(s.whyItHappensTitle),
        BodyText(s.tr(r.why)),
        _heading(s.realLifeTitle),
        BodyText(s.tr(r.realLife)),
        _heading(s.examFocusTitle),
        BodyText(s.tr(r.examPoint)),
        if (importance != null) ...[
          const SizedBox(height: 8),
          ImportancePanel(
            importance: importance,
            curriculum: curriculum!,
            classLevel: curriculum!.topic(topic!.id)!.syllabus.classLevel,
            badge: ImportanceBadge(importance: importance),
          ),
        ],
        if (curriculum != null) ...[
          const SizedBox(height: 8),
          ProvenanceNote(sources: r.sources, review: r.review, curriculum: curriculum!),
        ],
      ],
    );
  }

  Widget _heading(String text) => Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 4),
        child: Text(text, style: const TextStyle(fontWeight: FontWeight.w800, color: LabColors.ink)),
      );
}
