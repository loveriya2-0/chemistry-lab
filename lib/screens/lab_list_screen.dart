import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../content/content_catalog.dart';
import '../content/models/practical_coverage.dart';
import '../content/models/syllabus.dart';
import '../core/theme.dart';
import '../data/bookmark_store.dart';
import '../data/practicals_repository.dart';
import '../l10n/app_strings.dart';
import '../l10n/study_strings.dart';
import '../state/app_state.dart';
import '../widgets/language_toggle.dart';
import '../widgets/ui_kit.dart';
import 'practical_guide_screen.dart';
import 'practical_status_screen.dart';
import 'topic_list_screen.dart';

/// Lab tab: interactive labs placed in the syllabus or linked to the
/// class's listed practicals, then the board's listed practicals (guides
/// not built yet are marked as coming soon).
class LabListScreen extends StatelessWidget {
  const LabListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    final app = context.watch<AppState>();
    final curriculum = context.read<ContentCatalog>().curriculum(app.boardId!)!;
    final labs = context.read<PracticalsRepository>();
    final bookmarks = context.watch<BookmarkStore>();
    final classLevel = curriculum.classes.containsKey(app.selectedClass) ? app.selectedClass! : null;
    final classes = classLevel == null ? curriculum.classLevels : [classLevel];
    final placements = [for (final c in classes) ...curriculum.labsForClass(c)];
    final practicals = [
      for (final c in classes)
        for (final p in curriculum.classes[c]!.practicals.where((p) => p.labId == null)) (classLevel: c, practical: p),
    ];
    // Labs for a class's listed practicals that sit on no topic in that
    // class (Classes 11–12), once per class and lab.
    final linked = <({int classLevel, BoardPractical practical, String labId})>[];
    for (final c in classes) {
      final placed = {for (final p in curriculum.labsForClass(c)) p.labId};
      for (final p in curriculum.classes[c]!.practicals) {
        for (final l in curriculum.labLinksForPractical(p)) {
          if (placed.contains(l.labId) || curriculum.guideFor(l.labId) == null) continue;
          if (linked.any((x) => x.classLevel == c && x.labId == l.labId)) continue;
          linked.add((classLevel: c, practical: p, labId: l.labId));
        }
      }
    }

    return Scaffold(
      appBar: AppBar(title: Text(s.virtualLab), actions: const [LanguageToggle()]),
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
          const SizedBox(height: 8),
          // Every listed practical with its honest status.
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => PracticalStatusScreen(classLevel: classLevel ?? curriculum.classLevels.first),
            )),
            icon: const Icon(Icons.checklist_rounded),
            label: Text(context.study.practicalStatusTitle),
          ),
          const SizedBox(height: 8),
          SectionHeader(s.interactiveLab),
          if (placements.isEmpty && linked.isEmpty)
            ComingSoonPanel(icon: Icons.science_rounded, title: s.interactiveLab, body: s.noLabsForClass(classLevel ?? curriculum.classLevels.first)),
          for (final (i, p) in placements.indexed)
            FadeSlideIn(
              index: i,
              child: _LabCard(
                title: s.tr(labs.byId(p.labId).title),
                description: s.tr(labs.byId(p.labId).description),
                icon: labs.byId(p.labId).icon,
                accent: labs.byId(p.labId).accent,
                where: s.focusBreadcrumb(p.location.syllabus.classLevel, p.location.chapter.number, p.location.topic.number),
                saved: bookmarks.contains(BookmarkStore.labKey(p.location.topic.id, p.labId)),
                onBookmark: () => bookmarks.toggle(BookmarkStore.labKey(p.location.topic.id, p.labId)),
                openLabel: curriculum.guideFor(p.labId) == null ? s.openLab : s.viewPractical,
                onOpen: curriculum.guideFor(p.labId) == null
                    ? () => openLabsForTopic(context, syllabus: p.location.syllabus, chapter: p.location.chapter, topic: p.location.topic)
                    : () => openPracticalGuide(context, labId: p.labId, classLevel: p.location.syllabus.classLevel, topicId: p.location.topic.id),
              ),
            ),
          for (final (i, l) in linked.indexed)
            FadeSlideIn(
              index: placements.length + i,
              child: _LabCard(
                title: s.tr(labs.byId(l.labId).title),
                description: s.tr(labs.byId(l.labId).description),
                icon: labs.byId(l.labId).icon,
                accent: labs.byId(l.labId).accent,
                where: s.practicalBreadcrumb(l.classLevel, l.practical.number),
                openLabel: s.viewPractical,
                onOpen: () => openPracticalGuide(context, labId: l.labId, classLevel: l.classLevel, listedPracticalId: l.practical.id),
              ),
            ),
          if (practicals.isNotEmpty) ...[
            const SizedBox(height: 12),
            SectionHeader(s.boardPracticals),
            Card(
              margin: EdgeInsets.zero,
              child: Column(
                children: [
                  for (final (i, (:classLevel, :practical)) in practicals.indexed) ...[
                    if (i > 0) const Divider(height: 1, indent: 16, endIndent: 16),
                    _PracticalTile(
                      title: s.ct(practical.title),
                      level: curriculum.practicalStatus(practical).level,
                      // A related lab is offered only when its guide explains how it differs.
                      relatedLabs: [
                        for (final l in curriculum.labLinksForPractical(practical))
                          if (curriculum.guideFor(l.labId) != null) l.labId,
                      ],
                      onOpenLab: (labId) => openPracticalGuide(context, labId: labId, classLevel: classLevel, listedPracticalId: practical.id),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// One practical from the board's list: links to its related virtual
/// labs, or "guide coming soon".
class _PracticalTile extends StatelessWidget {
  const _PracticalTile({required this.title, required this.level, required this.relatedLabs, required this.onOpenLab});

  final String title;

  /// Shown when part or all of the practical can be done in a lab.
  final PracticalLevel level;
  final List<String> relatedLabs;
  final ValueChanged<String> onOpenLab;

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    final repo = context.read<PracticalsRepository>();
    final labs = [for (final id in relatedLabs) repo.byId(id)];
    return ListTile(
      leading: IconTile(icon: labs.firstOrNull?.icon ?? Icons.science_outlined, color: labs.firstOrNull?.accent ?? LabColors.muted, size: 34),
      title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: LabColors.ink, height: 1.35)),
      subtitle: labs.isEmpty
          ? Text(s.guideComingSoon, style: const TextStyle(fontSize: 12))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (level == PracticalLevel.fullyInteractive || level == PracticalLevel.partiallyInteractive)
                  Padding(padding: const EdgeInsets.only(top: 4, bottom: 2), child: PracticalLevelChip(level: level)),
                for (final lab in labs)
                  InkWell(
                    onTap: () => onOpenLab(lab.id),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(
                              s.relatedVirtualLab(s.tr(lab.title)),
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: lab.accent),
                            ),
                          ),
                          Icon(Icons.chevron_right_rounded, size: 18, color: lab.accent),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _LabCard extends StatelessWidget {
  const _LabCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.accent,
    required this.where,
    this.saved = false,
    this.onBookmark,
    required this.openLabel,
    required this.onOpen,
  });

  final String title;
  final String description;
  final IconData icon;
  final Color accent;
  final String where;
  final bool saved;

  /// Null hides the bookmark button (bookmarks belong to topics).
  final VoidCallback? onBookmark;
  final String openLabel;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconTile(icon: icon, color: accent, size: 48),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(where, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: accent)),
                    const SizedBox(height: 2),
                    Text(title, style: AppText.display(16, height: 1.25)),
                    const SizedBox(height: 4),
                    Text(description, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: LabColors.muted, height: 1.35)),
                    const SizedBox(height: 10),
                    FilledButton.tonalIcon(
                      onPressed: onOpen,
                      icon: const Icon(Icons.play_arrow_rounded, size: 18),
                      label: Text(openLabel),
                    ),
                  ],
                ),
              ),
              if (onBookmark != null)
                IconButton(
                  tooltip: saved ? s.bookmarked : s.bookmark,
                  onPressed: onBookmark,
                  icon: Icon(saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded, color: LabColors.primary),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
