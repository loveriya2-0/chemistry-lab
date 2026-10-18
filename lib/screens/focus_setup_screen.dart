import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/theme.dart';
import '../lab/lab_tutorial.dart';
import '../l10n/app_strings.dart';
import '../l10n/study_strings.dart';
import '../models/practical_path.dart';
import '../state/app_state.dart';
import '../state/focus_controller.dart';
import '../study/study_focus.dart';
import '../widgets/language_toggle.dart';
import '../widgets/practical_path_card.dart';
import '../widgets/study_widgets.dart';
import 'lab_tutorial_screen.dart';
import 'virtual_lab_screen.dart';

/// Shown before a practical: pick a focus length (10 / 15 min, or a custom
/// 5–180 min) or skip straight to the lab as before.
class FocusSetupScreen extends StatefulWidget {
  const FocusSetupScreen({super.key, required this.path});

  final PracticalPath path;

  @override
  State<FocusSetupScreen> createState() => _FocusSetupScreenState();
}

class _FocusSetupScreenState extends State<FocusSetupScreen> {
  // Pre-selects the length chosen in Settings (falls back to the first option).
  late Duration _duration = FocusController.options.firstWhere(
    (o) => o.inMinutes == context.read<AppState>().defaultFocusMinutes,
    orElse: () => FocusController.options.first,
  );

  /// True when the student chose their own length instead of 10 / 15.
  bool _custom = false;
  late int _customMinutes = context.read<FocusSettings>().customMinutes;

  Duration get _chosen => _custom ? Duration(minutes: _customMinutes) : _duration;

  void _startFocus() {
    if (_custom) context.read<FocusSettings>().setCustomMinutes(_customMinutes);
    _open(focus: _chosen);
  }

  // Replace this screen so leaving the lab returns to the practical list.
  // The first time any lab is opened the tutorial runs first, before the
  // lab (and any focus timer) starts.
  Future<void> _open({Duration? focus}) async {
    if (!LabTutorial.isSeen(context.read<SharedPreferences>())) {
      await openLabTutorial(context);
      if (!mounted) return;
    }
    Navigator.of(context).pushReplacement(labRoute(widget.path, focusDuration: focus));
  }

  @override
  Widget build(BuildContext context) {
    final s = context.strings;

    return Scaffold(
      appBar: AppBar(
        title: Text(s.focusMode),
        actions: const [LanguageToggle()],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Hero(title: s.focusSetupTitle, subtitle: s.focusSetupSubtitle),
                    const SizedBox(height: 16),
                    PracticalPathCard(path: widget.path),
                    const SizedBox(height: 20),
                    Text(
                      s.sessionLength,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: LabColors.ink,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        for (final (i, option) in FocusController.options.indexed) ...[
                          if (i > 0) const SizedBox(width: 12),
                          Expanded(
                            child: _DurationOption(
                              duration: option,
                              selected: !_custom && option == _duration,
                              onTap: () => setState(() {
                                _duration = option;
                                _custom = false;
                              }),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 10),
                    // A custom length of 5–180 minutes, kept for next time.
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        ChoiceChip(
                          label: Text(context.study.custom),
                          selected: _custom,
                          onSelected: (_) => setState(() => _custom = true),
                        ),
                        if (_custom)
                          MinutesStepper(
                            value: _customMinutes,
                            min: FocusSettings.minMinutes,
                            max: FocusSettings.maxMinutes,
                            label: context.study.customLength,
                            onChanged: (v) => setState(() => _customMinutes = v),
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    for (final rule in s.focusRules)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.check_circle_rounded,
                                size: 18, color: LabColors.success),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                rule,
                                style: const TextStyle(color: LabColors.muted, height: 1.35),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _startFocus,
                      icon: const Icon(Icons.timer_rounded),
                      label: Text('${s.startFocus} · ${s.minutesShort(_chosen.inMinutes)}'),
                    ),
                  ),
                  TextButton(
                    onPressed: _open,
                    child: Text(s.startWithoutFocus),
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

class _Hero extends StatelessWidget {
  const _Hero({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [LabColors.ink, LabColors.primary]),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(color: Colors.white24, shape: BoxShape.circle),
            child: const Icon(Icons.center_focus_strong_rounded, color: Colors.white, size: 30),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(color: Colors.white70, height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DurationOption extends StatelessWidget {
  const _DurationOption({
    required this.duration,
    required this.selected,
    required this.onTap,
  });

  final Duration duration;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    final minutes = duration.inMinutes;

    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? LabColors.primary : Colors.white,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: selected ? LabColors.primary : LabColors.muted.withValues(alpha: 0.2),
                width: 2,
              ),
            ),
            child: Column(
              children: [
                Icon(
                  selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                  color: selected ? Colors.white : LabColors.muted,
                ),
                const SizedBox(height: 6),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    s.minutesShort(minutes),
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: selected ? Colors.white : LabColors.ink,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  s.durationHint(minutes),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: selected ? Colors.white70 : LabColors.muted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
