import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

import '../content/content_catalog.dart';
import '../core/theme.dart';
import '../l10n/app_strings.dart';
import '../models/practical_path.dart';

/// Card listing Class, Chapter, Topic and Practical for a [PracticalPath].
class PracticalPathCard extends StatelessWidget {
  const PracticalPathCard({super.key, required this.path});

  final PracticalPath path;

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    final accent = path.practical.accent;
    final chapter = path.chapter;
    final topic = path.topic;
    final listed = path.listedPractical;
    final board = context.read<ContentCatalog>().registry.byId(path.boardId);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
        child: Column(
          children: [
            _Row(
              icon: Icons.school_rounded,
              color: LabColors.classAccents[path.classLevel] ?? LabColors.primary,
              label: s.classLabel,
              value: board == null
                  ? s.className(path.classLevel)
                  : '${s.ct(board.name)} · ${s.className(path.classLevel)}',
            ),
            if (chapter != null)
              _Row(
                icon: Icons.menu_book_rounded,
                color: LabColors.primary,
                label: s.chapterLabel,
                value: chapter.number == null ? s.ct(chapter.title) : '${chapter.number}. ${s.ct(chapter.title)}',
              ),
            if (topic != null)
              _Row(
                icon: Icons.lightbulb_rounded,
                color: LabColors.primary,
                label: s.topicLabel,
                value: '${topic.number} ${s.ct(topic.title)}',
              )
            else if (listed != null)
              _Row(
                icon: Icons.assignment_rounded,
                color: LabColors.primary,
                label: s.listedPracticalLabel,
                value: '${listed.number}. ${s.ct(listed.title)}',
              ),
            _Row(
              icon: path.practical.icon,
              color: accent,
              label: s.practicalLabel,
              value: s.tr(path.practical.title),
            ),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 12, color: LabColors.muted)),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: LabColors.ink,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
