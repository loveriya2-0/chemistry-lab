import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../l10n/app_strings.dart';
import '../models/focus_session.dart';
import '../models/practical_path.dart';
import '../widgets/language_toggle.dart';
import '../widgets/practical_path_card.dart';
import 'focus_setup_screen.dart';

/// Shown when the focus timer reaches zero. The session is already saved.
class FocusCompleteScreen extends StatelessWidget {
  const FocusCompleteScreen({super.key, required this.path, required this.session});

  final PracticalPath path;
  final FocusSession session;

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    final accuracy = session.accuracy;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, 8, 12, 0),
                child: LanguageToggle(),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  children: [
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: 1),
                      duration: const Duration(milliseconds: 900),
                      curve: Curves.elasticOut,
                      builder: (_, v, child) => Transform.scale(scale: v, child: child),
                      child: Container(
                        padding: const EdgeInsets.all(22),
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(colors: [LabColors.ink, LabColors.primary]),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.emoji_events_rounded,
                            color: LabColors.warning, size: 56),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      s.focusComplete,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: LabColors.ink,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      s.focusedFor(session.focusedSeconds ~/ 60),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16, color: LabColors.muted),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: _StatTile(
                            icon: Icons.check_circle_rounded,
                            color: LabColors.success,
                            value: '${session.correctActions}',
                            label: s.correctActions,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _StatTile(
                            icon: Icons.cancel_rounded,
                            color: LabColors.danger,
                            value: '${session.wrongActions}',
                            label: s.wrongActions,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _StatTile(
                            icon: Icons.track_changes_rounded,
                            color: LabColors.primary,
                            value: accuracy == null ? '—' : '${(accuracy * 100).round()}%',
                            label: s.accuracy,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _StatTile(
                            icon: Icons.emoji_events_rounded,
                            color: LabColors.warning,
                            value: '${session.practicalsCompleted}',
                            label: s.practicalsCompleted,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Card(
                      margin: EdgeInsets.zero,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(s.practicalProgress,
                                style: const TextStyle(fontSize: 12, color: LabColors.muted)),
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: LinearProgressIndicator(
                                value: session.stepsCompleted / session.totalSteps,
                                minHeight: 8,
                                color: path.practical.accent,
                                backgroundColor: path.practical.accent.withValues(alpha: 0.12),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              s.stepsDone(session.stepsCompleted, session.totalSteps),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: LabColors.ink,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    PracticalPathCard(path: path),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.save_rounded, size: 16, color: LabColors.muted),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            s.sessionSaved,
                            style: const TextStyle(fontSize: 12, color: LabColors.muted),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (_) => FocusSetupScreen(path: path)),
                      ),
                      icon: const Icon(Icons.replay_rounded),
                      label: Text(s.newSession),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(s.backToPracticals),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final Color color;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: color,
                  ),
                ),
                Text(
                  label,
                  style: const TextStyle(fontSize: 12, color: LabColors.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
