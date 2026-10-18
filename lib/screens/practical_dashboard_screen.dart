import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../content/content_catalog.dart';
import '../content/models/syllabus.dart';
import '../core/theme.dart';
import '../l10n/app_strings.dart';
import '../models/practical.dart';
import '../models/practical_path.dart';
import '../widgets/empty_state.dart';
import '../widgets/info_pill.dart';
import '../widgets/language_toggle.dart';
import 'focus_setup_screen.dart';
import 'practical_guide_screen.dart';

/// Screen 4 – interactive labs offered on the selected topic.
class PracticalDashboardScreen extends StatelessWidget {
  const PracticalDashboardScreen({
    super.key,
    required this.boardId,
    required this.classLevel,
    required this.chapter,
    required this.topic,
    required this.labs,
  });

  final String boardId;
  final int classLevel;
  final Chapter chapter;
  final Topic topic;
  final List<Practical> labs;

  @override
  Widget build(BuildContext context) {
    final practicals = labs;
    final s = context.strings;

    return Scaffold(
      appBar: AppBar(
        title: Text('${topic.number} ${s.ct(topic.title)}'),
        actions: const [LanguageToggle()],
      ),
      body: practicals.isEmpty
          ? EmptyState(message: s.noPracticals)
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: practicals.length,
              separatorBuilder: (_, _) => const SizedBox(height: 14),
              itemBuilder: (context, i) => _PracticalCard(
                practical: practicals[i],
                hasGuide: context.read<ContentCatalog>().curriculum(boardId)?.guideFor(practicals[i].id) != null,
                onStart: () => _openLab(context, practicals[i]),
              ),
            ),
    );
  }

  /// A lab with a written guide opens it first; the guide starts Focus
  /// Mode setup, which can also skip straight to the plain lab.
  void _openLab(BuildContext context, Practical practical) {
    final curriculum = context.read<ContentCatalog>().curriculum(boardId);
    if (curriculum?.guideFor(practical.id) != null) {
      openPracticalGuide(context, labId: practical.id, classLevel: classLevel, topicId: topic.id);
      return;
    }
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => FocusSetupScreen(
        path: PracticalPath(
          boardId: boardId,
          classLevel: classLevel,
          chapter: chapter,
          topic: topic,
          practical: practical,
        ),
      ),
    ));
  }
}

class _PracticalCard extends StatelessWidget {
  const _PracticalCard({required this.practical, required this.hasGuide, required this.onStart});

  final Practical practical;
  final bool hasGuide;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final accent = practical.accent;
    final s = context.strings;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onStart,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(practical.icon, color: accent, size: 30),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      s.tr(practical.title),
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: LabColors.ink,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                s.tr(practical.description),
                style: const TextStyle(color: LabColors.muted, height: 1.4),
              ),
              const SizedBox(height: 14),
              // Pills left, button right; the button wraps to its own line
              // when a longer translation doesn't fit beside the pills.
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 10,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      InfoPill(icon: Icons.format_list_numbered_rounded,
                          label: s.stepCount(practical.steps.length)),
                      InfoPill(icon: Icons.local_drink_rounded,
                          label: s.chemicalCount(practical.chemicals.length)),
                    ],
                  ),
                  FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: accent),
                    onPressed: onStart,
                    child: Text(hasGuide ? s.viewPractical : s.start),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

