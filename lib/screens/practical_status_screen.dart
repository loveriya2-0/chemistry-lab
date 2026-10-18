import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../content/content_catalog.dart';
import '../content/models/practical_coverage.dart';
import '../core/theme.dart';
import '../data/practicals_repository.dart';
import '../l10n/app_strings.dart';
import '../l10n/study_strings.dart';
import '../state/app_state.dart';
import '../widgets/language_toggle.dart';
import '../widgets/ui_kit.dart';
import 'practical_guide_screen.dart';

Color practicalLevelColor(PracticalLevel l) => switch (l) {
      PracticalLevel.fullyInteractive => LabColors.success,
      PracticalLevel.partiallyInteractive => LabColors.primary,
      PracticalLevel.guideOnly => LabColors.amber,
      PracticalLevel.notImplemented => LabColors.muted,
    };

/// Small label with a practical's status.
class PracticalLevelChip extends StatelessWidget {
  const PracticalLevelChip({super.key, required this.level});

  final PracticalLevel level;

  @override
  Widget build(BuildContext context) {
    final color = practicalLevelColor(level);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
      child: Text(context.study.practicalLevel(level), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
    );
  }
}

/// Every practical in the board's list for one class with its honest
/// status: what can be done in a virtual lab and what is not simulated.
class PracticalStatusScreen extends StatefulWidget {
  const PracticalStatusScreen({super.key, this.classLevel});

  final int? classLevel;

  @override
  State<PracticalStatusScreen> createState() => _PracticalStatusScreenState();
}

class _PracticalStatusScreenState extends State<PracticalStatusScreen> {
  late int _classLevel = widget.classLevel ?? context.read<AppState>().selectedClass ?? 10;

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    final st = context.study;
    final curriculum = context.read<ContentCatalog>().curriculum(context.read<AppState>().boardId!)!;
    final labs = context.read<PracticalsRepository>();
    if (!curriculum.classes.containsKey(_classLevel)) _classLevel = curriculum.classLevels.first;
    final practicals = curriculum.classes[_classLevel]!.practicals;
    final statuses = [for (final p in practicals) (p, curriculum.practicalStatus(p))];
    int count(PracticalLevel l) => statuses.where((e) => e.$2.level == l).length;

    return Scaffold(
      appBar: AppBar(title: Text(st.practicalStatusTitle), actions: const [LanguageToggle()]),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final c in curriculum.classLevels)
                ChoiceChip(label: Text(s.className(c)), selected: c == _classLevel, onSelected: (_) => setState(() => _classLevel = c)),
            ],
          ),
          const SizedBox(height: 10),
          Text(st.practicalStatusHint, style: const TextStyle(color: LabColors.muted, height: 1.4)),
          const SizedBox(height: 6),
          Text(
            st.practicalCountLine(
              count(PracticalLevel.fullyInteractive),
              count(PracticalLevel.partiallyInteractive),
              count(PracticalLevel.guideOnly),
              count(PracticalLevel.notImplemented),
            ),
            style: const TextStyle(fontWeight: FontWeight.w700, color: LabColors.ink),
          ),
          const SizedBox(height: 12),
          for (final (p, status) in statuses)
            Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ElementTile(number: p.number, color: practicalLevelColor(status.level), size: 40),
                        const SizedBox(width: 12),
                        Expanded(child: Text(s.ct(p.title), style: const TextStyle(fontWeight: FontWeight.w700, color: LabColors.ink, height: 1.35))),
                      ],
                    ),
                    const SizedBox(height: 8),
                    PracticalLevelChip(level: status.level),
                    const SizedBox(height: 4),
                    Text(st.practicalLevelHint(status.level), style: const TextStyle(fontSize: 12, color: LabColors.muted)),
                    if (status.coverage case final c?) ...[
                      const SizedBox(height: 8),
                      Text('✓ ${s.ct(c.covered)}', style: const TextStyle(color: LabColors.success, height: 1.4)),
                      if (c.notCovered case final n?) ...[
                        const SizedBox(height: 4),
                        Text('${st.notCovered}: ${s.ct(n)}', style: const TextStyle(color: LabColors.muted, height: 1.4)),
                      ],
                    ],
                    if (status.labIds.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(st.coveredBy, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: LabColors.muted)),
                      for (final id in status.labIds)
                        InkWell(
                          onTap: () => openPracticalGuide(context, labId: id, classLevel: _classLevel, listedPracticalId: p.id),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(minHeight: 44),
                            child: Row(
                              children: [
                                Icon(labs.byId(id).icon, size: 18, color: labs.byId(id).accent),
                                const SizedBox(width: 8),
                                Expanded(child: Text(s.tr(labs.byId(id).title), style: TextStyle(fontWeight: FontWeight.w700, color: labs.byId(id).accent))),
                                Icon(Icons.chevron_right_rounded, color: labs.byId(id).accent),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
