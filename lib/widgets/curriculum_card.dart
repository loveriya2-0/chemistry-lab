import 'package:flutter/material.dart';

import '../core/theme.dart';
import 'info_pill.dart';

/// Tappable card for a chapter or topic: icon tile, overline, title,
/// description and a row of [InfoPill]s.
class CurriculumCard extends StatelessWidget {
  const CurriculumCard({
    super.key,
    required this.icon,
    required this.accent,
    required this.overline,
    required this.title,
    required this.description,
    required this.pills,
    required this.onTap,
    this.descriptionMaxLines,
  });

  final IconData icon;
  final Color accent;

  /// Small caps label above the title, e.g. "CHAPTER 2".
  final String overline;
  final String title;
  final String description;
  final List<InfoPill> pills;
  final VoidCallback onTap;

  /// Clamp long descriptions on list screens; null shows everything.
  final int? descriptionMaxLines;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
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
                    child: Icon(icon, color: accent, size: 30),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          overline,
                          style: TextStyle(
                            color: accent,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                            letterSpacing: 0.6,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            color: LabColors.ink,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: accent),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                description,
                maxLines: descriptionMaxLines,
                overflow: descriptionMaxLines == null ? null : TextOverflow.ellipsis,
                style: const TextStyle(color: LabColors.muted, height: 1.4),
              ),
              const SizedBox(height: 14),
              Wrap(spacing: 8, runSpacing: 6, children: pills),
            ],
          ),
        ),
      ),
    );
  }
}
