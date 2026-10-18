import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../content/content_catalog.dart';
import '../core/theme.dart';
import '../l10n/app_strings.dart';
import '../models/practical_path.dart';
import '../state/lab_controller.dart';
import 'learning_widgets.dart' show FormulaBox;
import 'reaction_summary.dart';

enum CompletionAction { repeat, exit }

/// Celebration dialog with a star rating and the practical's conclusion;
/// for a reaction lab, the full verified reaction ([ReactionSummary]).
class CompletionDialog extends StatelessWidget {
  const CompletionDialog({super.key, required this.lab, this.location});

  final LabController lab;

  /// Where the lab was opened, for the topic's exam importance.
  final ({LoadedCurriculum curriculum, TopicLocation topic})? location;

  static Future<CompletionAction?> show(BuildContext context, LabController lab) {
    // The dialog's route sits outside the lab's providers, so read them here.
    final path = context.read<PracticalPath?>();
    final curriculum = path == null ? null : context.read<ContentCatalog>().curriculum(path.boardId);
    final topic = switch (path?.topic) {
      final t? => curriculum?.topic(t.id),
      null => null,
    };
    return showDialog<CompletionAction>(
      context: context,
      barrierDismissible: false,
      builder: (_) => CompletionDialog(
        lab: lab,
        location: curriculum == null || topic == null ? null : (curriculum: curriculum, topic: topic),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    return AlertDialog(
      // A reaction card is long; give it the phone's width.
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      title: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < 3; i++)
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: Duration(milliseconds: 400 + i * 200),
                  curve: Curves.elasticOut,
                  builder: (_, v, child) => Transform.scale(scale: v, child: child),
                  child: Icon(
                    Icons.star_rounded,
                    size: 48,
                    color: i < lab.stars ? LabColors.warning : Colors.grey.shade300,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            s.practicalComplete,
            style: const TextStyle(fontWeight: FontWeight.w900, color: LabColors.ink),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              lab.mistakes == 0
                  ? s.perfectRun
                  : s.finishedWithMistakes(lab.mistakes),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            if (lab.practical.reaction case final reaction?)
              ReactionSummary(
                reaction: reaction,
                curriculum: location?.curriculum,
                topic: location?.topic.topic,
                showImportance: location != null &&
                    location!.topic.syllabus.examPattern.boardExam &&
                    location!.topic.chapter.inYearEndExam &&
                    location!.curriculum.manifest.pyqPapers.isNotEmpty,
              )
            else ...[
              Text(s.conclusion, style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(s.tr(lab.practical.conclusion), style: const TextStyle(height: 1.4)),
            ],
            if (lab.practical.calculation case final calc?) ...[
              const SizedBox(height: 12),
              Text(
                s.endPointReading(lab.titrantMl.toStringAsFixed(1)),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              FormulaBox(calc.working(lab.titrantMl)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(CompletionAction.exit),
          child: Text(s.backToPracticals),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(CompletionAction.repeat),
          child: Text(s.repeat),
        ),
      ],
    );
  }
}
