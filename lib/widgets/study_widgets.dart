import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../l10n/study_strings.dart';
import '../study/study_progress_store.dart';

/// "− 25 min +" with 48 dp buttons. Long values are clamped by [min]/[max].
class MinutesStepper extends StatelessWidget {
  const MinutesStepper({super.key, required this.value, required this.min, required this.max, required this.onChanged, this.step = 5, this.label});

  final int value;
  final int min;
  final int max;
  final int step;
  final ValueChanged<int> onChanged;

  /// Read by screen readers ("Custom length").
  final String? label;

  @override
  Widget build(BuildContext context) {
    final st = context.study;
    return Semantics(
      label: label,
      value: st.minutes(value),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton.filledTonal(
            tooltip: '−$step',
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            onPressed: value <= min ? null : () => onChanged((value - step).clamp(min, max)),
            icon: const Icon(Icons.remove_rounded),
          ),
          SizedBox(
            width: 84,
            child: Text(st.minutes(value), textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: LabColors.ink)),
          ),
          IconButton.filledTonal(
            tooltip: '+$step',
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            onPressed: value >= max ? null : () => onChanged((value + step).clamp(min, max)),
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
    );
  }
}

Color statusColor(TopicStatus s) => switch (s) {
      TopicStatus.notStarted => LabColors.muted,
      TopicStatus.inProgress => LabColors.primary,
      TopicStatus.completed => LabColors.success,
      TopicStatus.reviseAgain => LabColors.warning,
    };

IconData statusIcon(TopicStatus s) => switch (s) {
      TopicStatus.notStarted => Icons.radio_button_unchecked_rounded,
      TopicStatus.inProgress => Icons.timelapse_rounded,
      TopicStatus.completed => Icons.check_circle_rounded,
      TopicStatus.reviseAgain => Icons.replay_circle_filled_rounded,
    };

/// Small coloured status label.
class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.status});

  final TopicStatus status;

  @override
  Widget build(BuildContext context) {
    final color = statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(statusIcon(status), size: 14, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(context.study.statusName(status),
                maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
          ),
        ],
      ),
    );
  }
}

/// Lets the student set a topic's status. All four states are offered;
/// the current one is highlighted.
class StatusSelector extends StatelessWidget {
  const StatusSelector({super.key, required this.status, required this.onChanged});

  final TopicStatus status;
  final ValueChanged<TopicStatus> onChanged;

  @override
  Widget build(BuildContext context) {
    final st = context.study;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final s in TopicStatus.values)
          ChoiceChip(
            avatar: Icon(statusIcon(s), size: 18, color: s == status ? Colors.white : statusColor(s)),
            label: Text(st.statusName(s)),
            selected: s == status,
            showCheckmark: false,
            selectedColor: statusColor(s),
            labelStyle: TextStyle(color: s == status ? Colors.white : LabColors.ink, fontWeight: FontWeight.w700),
            onSelected: (_) => onChanged(s),
          ),
      ],
    );
  }
}

/// One content kind on a topic: present (tick) or not added yet (greyed).
class AvailabilityChip extends StatelessWidget {
  const AvailabilityChip({super.key, required this.label, required this.available});

  final String label;
  final bool available;

  @override
  Widget build(BuildContext context) {
    final color = available ? LabColors.success : LabColors.muted;
    return Semantics(
      label: available ? label : '$label: ${context.study.notAvailableYet}',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: available ? LabColors.success.withValues(alpha: 0.08) : LabColors.background,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: available ? 0.3 : 0.15)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(available ? Icons.check_rounded : Icons.remove_rounded, size: 14, color: color),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: available ? LabColors.ink : LabColors.muted,
                  decoration: available ? null : TextDecoration.lineThrough,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Thin labelled progress bar.
class ProgressLine extends StatelessWidget {
  const ProgressLine({super.key, required this.value, required this.label, this.color = LabColors.success});

  final double value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: LabColors.muted)),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(value: value.clamp(0, 1), minHeight: 6, color: color, backgroundColor: LabColors.line),
        ),
      ],
    );
  }
}
