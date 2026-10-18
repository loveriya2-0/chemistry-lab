import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../l10n/app_strings.dart';
import '../state/focus_controller.dart';

/// Slim banner above the goal bar while a focus session runs: countdown
/// ring, curriculum breadcrumb, Pause/Resume and Exit.
class FocusBar extends StatelessWidget {
  const FocusBar({super.key, required this.onExit});

  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    final focus = context.watch<FocusController>();
    final s = context.strings;
    final path = focus.path;
    final remaining = focus.remaining;
    final color = remaining.inSeconds <= 60 ? LabColors.warning : Colors.white;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 6),
      padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [LabColors.ink, LabColors.primary],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          SizedBox.square(
            dimension: 40,
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: focus.remainingFraction),
              duration: const Duration(milliseconds: 900),
              builder: (_, value, _) => CircularProgressIndicator(
                value: value,
                strokeWidth: 4,
                color: color,
                backgroundColor: Colors.white24,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      formatClock(remaining),
                      style: TextStyle(
                        color: color,
                        fontSize: 22,
                        height: 1.1,
                        fontWeight: FontWeight.w900,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        focus.isPaused ? s.paused : s.timeLeft,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  switch ((path.topic, path.listedPractical)) {
                    (final t?, _) => s.focusBreadcrumb(path.classLevel, path.chapter?.number, t.number),
                    (null, final p?) => s.practicalBreadcrumb(path.classLevel, p.number),
                    _ => s.className(path.classLevel),
                  },
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: focus.isPaused ? s.resume : s.pause,
            onPressed: focus.togglePause,
            style: IconButton.styleFrom(backgroundColor: Colors.white24),
            color: Colors.white,
            icon: Icon(focus.isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded),
          ),
          IconButton(
            tooltip: s.exitFocus,
            onPressed: onExit,
            color: Colors.white,
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
    );
  }
}
