import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../analytics/progress_report.dart';
import '../core/theme.dart';
import '../l10n/app_strings.dart';

/// Colours for correct vs wrong pours. Indigo/red rather than green/red:
/// green/red is indistinguishable for deuteranopes (ΔE 5); this pair
/// passes the colour-blind separation check (ΔE 30). Icons and the legend
/// carry the meaning too, so colour is never the only cue.
abstract final class ActionColors {
  static const correct = LabColors.primary;
  static const wrong = LabColors.danger;
}

/// Stacked bars of correct (bottom) and wrong (top) pours for the last 7
/// days. Tap/long-press a day for its exact numbers.
class WeekActionsChart extends StatelessWidget {
  const WeekActionsChart({super.key, required this.days});

  final List<DayActivity> days;

  static const _barArea = 96.0;
  static const _barWidth = 18.0;

  // Leave room for the 2px gap so a full stacked bar fits exactly.
  static const _plotHeight = _barArea - 2;

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    final maxTotal = math.max(1, days.map((d) => d.total).fold(0, math.max));
    final labels = [for (final d in days) s.weekdayShort(d.date.weekday)];

    return Semantics(
      label: [
        for (final (i, d) in days.indexed) s.dayActions(labels[i], d.correct, d.wrong),
      ].join('. '),
      excludeSemantics: true,
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final (i, d) in days.indexed)
                Expanded(
                  child: Tooltip(
                    message: s.dayActions(labels[i], d.correct, d.wrong),
                    triggerMode: TooltipTriggerMode.tap,
                    child: Column(
                      children: [
                        SizedBox(
                          height: _barArea,
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: _Bar(
                              correctHeight: _plotHeight * d.correct / maxTotal,
                              wrongHeight: _plotHeight * d.wrong / maxTotal,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          labels[i],
                          maxLines: 1,
                          overflow: TextOverflow.clip,
                          style: TextStyle(
                            fontSize: 11,
                            color: i == days.length - 1 ? LabColors.ink : LabColors.muted,
                            fontWeight: i == days.length - 1 ? FontWeight.w800 : FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 16,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: [
              _LegendItem(color: ActionColors.correct, icon: Icons.check_rounded, label: s.correctActions),
              _LegendItem(color: ActionColors.wrong, icon: Icons.close_rounded, label: s.wrongActions),
            ],
          ),
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.correctHeight, required this.wrongHeight});

  final double correctHeight;
  final double wrongHeight;

  static const _top = BorderRadius.vertical(top: Radius.circular(4));

  @override
  Widget build(BuildContext context) {
    if (correctHeight == 0 && wrongHeight == 0) {
      // Empty day: a faint baseline so the axis still reads.
      return Container(
        width: WeekActionsChart._barWidth,
        height: 2,
        color: LabColors.muted.withValues(alpha: 0.25),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (wrongHeight > 0)
          Container(
            width: WeekActionsChart._barWidth,
            height: wrongHeight,
            decoration: const BoxDecoration(color: ActionColors.wrong, borderRadius: _top),
          ),
        // 2px surface gap between stacked segments.
        if (wrongHeight > 0 && correctHeight > 0) const SizedBox(height: 2),
        if (correctHeight > 0)
          Container(
            width: WeekActionsChart._barWidth,
            height: correctHeight,
            decoration: BoxDecoration(
              color: ActionColors.correct,
              borderRadius: wrongHeight > 0 ? null : _top,
            ),
          ),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.icon, required this.label});

  final Color color;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(1),
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
          child: Icon(icon, size: 12, color: Colors.white),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12, color: LabColors.muted)),
      ],
    );
  }
}
