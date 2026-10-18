import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../data/focus_session_store.dart';
import '../l10n/app_strings.dart';
import '../models/focus_session.dart';
import '../screens/focus_complete_screen.dart';
import '../state/focus_controller.dart';
import '../state/lab_controller.dart';

/// Wraps the lab screen during a focus session and owns its lifecycle:
/// starts the timer, pauses when the app is backgrounded, guards Back with
/// the Exit Focus dialog, and saves the session exactly once however it ends.
///
/// Expects [FocusController], [LabController] and [FocusSessionStore] above.
class FocusSessionHost extends StatefulWidget {
  const FocusSessionHost({super.key, required this.child});

  final Widget child;

  /// Shows the Exit Focus confirmation for the session around [context].
  static Future<void> requestExit(BuildContext context) =>
      context.findAncestorStateOfType<_FocusSessionHostState>()!._confirmExit();

  @override
  State<FocusSessionHost> createState() => _FocusSessionHostState();
}

class _FocusSessionHostState extends State<FocusSessionHost> {
  late final FocusController _focus;
  late final LabController _lab;
  late final FocusSessionStore _store;
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _focus = context.read<FocusController>();
    _lab = context.read<LabController>();
    _store = context.read<FocusSessionStore>();
    _lifecycle = AppLifecycleListener(onHide: _focus.pause);
    _focus.addListener(_onFocusChanged);
    // start() notifies listeners, which isn't allowed mid-build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.start();
    });
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocusChanged);
    _lifecycle.dispose();
    // Left by any other route (e.g. "Back to Practicals"): still record it.
    if (!_focus.hasEnded) _end(FocusStatus.exited);
    super.dispose();
  }

  FocusSession _end(FocusStatus status) {
    final session = _focus.finish(
      status,
      stepsCompleted: _lab.stepIndex,
      totalSteps: _lab.totalSteps,
    );
    _store.add(session);
    return session;
  }

  void _onFocusChanged() {
    if (!_focus.isTimeUp || _focus.hasEnded) return;
    final session = _end(FocusStatus.completed);
    final navigator = Navigator.of(context);
    final labRoute = ModalRoute.of(context);
    // Close any open dialog or sheet first, then swap the lab for the summary.
    navigator.popUntil((route) => route == labRoute);
    navigator.pushReplacement(MaterialPageRoute(
      builder: (_) => FocusCompleteScreen(path: _focus.path, session: session),
    ));
  }

  Future<void> _confirmExit() async {
    if (_focus.hasEnded) return;
    final wasPaused = _focus.isPaused;
    _focus.pause();
    final exit = await showDialog<bool>(
      context: context,
      builder: (_) => const _ExitFocusDialog(),
    );
    if (!mounted || _focus.hasEnded) return;
    if (exit ?? false) {
      _end(FocusStatus.exited);
      Navigator.of(context).pop();
    } else if (!wasPaused) {
      _focus.resume();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmExit();
      },
      child: Stack(
        children: [
          widget.child,
          Positioned.fill(child: _PausedOverlay(onExit: _confirmExit)),
        ],
      ),
    );
  }
}

/// Full-screen "Session paused" card; also blocks the bench while paused.
class _PausedOverlay extends StatelessWidget {
  const _PausedOverlay({required this.onExit});

  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    final focus = context.watch<FocusController>();
    final visible = focus.isPaused && !focus.hasEnded;

    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: const Duration(milliseconds: 250),
        child: visible ? _content(context, focus) : const SizedBox.shrink(),
      ),
    );
  }

  Widget _content(BuildContext context, FocusController focus) {
    final s = context.strings;
    final lab = context.watch<LabController>();

    return Material(
      color: LabColors.ink.withValues(alpha: 0.92),
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: const BoxDecoration(
                      color: Colors.white12,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.pause_rounded, color: Colors.white, size: 44),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    s.paused,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    formatClock(focus.remaining),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 56,
                      fontWeight: FontWeight.w900,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                  Text(
                    s.pausedHint,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70, height: 1.4),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.practicalProgress,
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: lab.progress,
                            minHeight: 8,
                            color: LabColors.secondary,
                            backgroundColor: Colors.white12,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          s.stepsDone(lab.stepIndex, lab.totalSteps),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: LabColors.ink,
                      ),
                      onPressed: focus.resume,
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: Text(s.resume),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    style: TextButton.styleFrom(foregroundColor: Colors.white70),
                    onPressed: onExit,
                    icon: const Icon(Icons.logout_rounded),
                    label: Text(s.exitFocus),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ExitFocusDialog extends StatelessWidget {
  const _ExitFocusDialog();

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    return AlertDialog(
      icon: const Icon(Icons.timer_off_rounded, color: LabColors.warning, size: 40),
      title: Text(
        s.exitFocusTitle,
        textAlign: TextAlign.center,
        style: const TextStyle(fontWeight: FontWeight.w900, color: LabColors.ink),
      ),
      content: Text(s.exitFocusBody, textAlign: TextAlign.center),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: TextButton.styleFrom(foregroundColor: LabColors.danger),
          child: Text(s.exit),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(s.keepFocusing),
        ),
      ],
    );
  }
}
