import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../content/content_catalog.dart';
import '../core/theme.dart';
import '../data/bookmark_store.dart';
import '../data/focus_session_store.dart';
import '../data/practical_attempt_store.dart';
import '../l10n/app_language.dart';
import '../l10n/app_strings.dart';
import '../state/app_state.dart';
import '../state/language_controller.dart';
import '../l10n/premium_strings.dart';
import '../premium/premium_controller.dart';
import '../widgets/premium_gate.dart';
import '../widgets/study_widgets.dart';
import '../widgets/ui_kit.dart';
import '../l10n/study_strings.dart';
import '../study/study_focus.dart';
import '../study/study_progress_store.dart';
import 'board_selection_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _confirmReset(BuildContext context) async {
    final s = context.readStrings;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.resetConfirmTitle),
        content: Text(s.resetConfirmBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(s.cancel)),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: LabColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(s.reset),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final prefs = context.read<SharedPreferences>();
    await prefs.remove(FocusSessionStore.storageKey);
    await prefs.remove(PracticalAttemptStore.storageKey);
    await prefs.remove(StudySessionStore.storageKey);
    await prefs.remove(StudySessionStore.activeKey);
    if (!context.mounted) return;
    context.read<BookmarkStore>().clear();
    // Topic status, answers and revision ticks are progress too. Personal
    // notes are the student's own writing and are never reset here.
    context.read<StudyProgressStore>().clear();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.progressReset)));
  }

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    final app = context.watch<AppState>();
    final language = context.watch<LanguageController>();
    final catalog = context.read<ContentCatalog>();
    final board = catalog.registry.byId(app.boardId!)!;
    final curriculum = catalog.curriculum(app.boardId!)!;

    Widget group(String title, List<Widget> children) => Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionHeader(title),
              Card(margin: EdgeInsets.zero, child: Column(children: children)),
            ],
          ),
        );

    return Scaffold(
      appBar: AppBar(title: Text(s.settings)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          group(s.boardAndClass, [
            ListTile(
              leading: const IconTile(icon: Icons.account_balance_rounded, color: LabColors.primary, size: 36),
              title: Text(s.ct(board.name), style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(s.syllabusYear(curriculum.manifest.academicYear)),
              trailing: Text(s.changeBoard, style: const TextStyle(color: LabColors.primary, fontWeight: FontWeight.w700)),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BoardSelectionScreen())),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final c in curriculum.classLevels)
                    ChoiceChip(
                      label: Text(s.className(c)),
                      selected: c == app.selectedClass,
                      onSelected: (_) => context.read<AppState>().selectClass(c),
                    ),
                ],
              ),
            ),
          ]),
          Builder(builder: (context) {
            final p = context.premium;
            final premium = context.watch<PremiumController>();
            return group(p.premium, [
              ListTile(
                key: const Key('settings-premium'),
                leading: const IconTile(icon: Icons.workspace_premium_rounded, color: LabColors.amber, size: 36),
                title: Text(
                  switch (premium.status) {
                    PremiumStatus.active => p.active,
                    PremiumStatus.pending => p.pendingTitle,
                    PremiumStatus.free => p.buyFor(premium.price),
                  },
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: premium.status == PremiumStatus.free ? Text(p.oneTime) : null,
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => openPremium(context),
              ),
            ]);
          }),
          group(s.languageLabel, [
            Padding(
              padding: const EdgeInsets.all(14),
              child: SizedBox(
                width: double.infinity,
                child: SegmentedButton<AppLanguage>(
                  segments: [
                    for (final l in AppLanguage.values) ButtonSegment(value: l, label: Text(l.nativeName)),
                  ],
                  selected: {language.language},
                  onSelectionChanged: (v) => context.read<LanguageController>().setLanguage(v.first),
                ),
              ),
            ),
          ]),
          group(s.defaultFocus, [
            Padding(
              padding: const EdgeInsets.all(14),
              child: SizedBox(
                width: double.infinity,
                child: SegmentedButton<int>(
                  segments: [for (final m in const [10, 15]) ButtonSegment(value: m, label: Text(s.minutesShort(m)))],
                  selected: {app.defaultFocusMinutes},
                  onSelectionChanged: (v) => context.read<AppState>().setDefaultFocusMinutes(v.first),
                ),
              ),
            ),
          ]),
          Builder(builder: (context) {
            final st = context.study;
            final focus = context.watch<FocusSettings>();
            Widget row(String title, String? subtitle, int value, int min, int max, ValueChanged<int> set, {int step = 5}) => Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    runSpacing: 4,
                    children: [
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: const TextStyle(fontWeight: FontWeight.w700, color: LabColors.ink)),
                          if (subtitle != null) Text(subtitle, style: const TextStyle(fontSize: 12, color: LabColors.muted)),
                        ],
                      ),
                      MinutesStepper(value: value, min: min, max: max, step: step, label: title, onChanged: set),
                    ],
                  ),
                );
            return group(st.focusSettings, [
              row(st.customLength, st.lengthRange, focus.customMinutes, FocusSettings.minMinutes, FocusSettings.maxMinutes, focus.setCustomMinutes),
              row(st.breakLabel, null, focus.breakMinutes, FocusSettings.minBreak, FocusSettings.maxBreak, focus.setBreakMinutes, step: 1),
              row(st.dailyGoal, null, focus.dailyGoalMinutes, FocusSettings.minGoal, FocusSettings.maxGoal, focus.setDailyGoalMinutes, step: 10),
            ]);
          }),
          group(s.yourData, [
            ListTile(
              leading: const IconTile(icon: Icons.lock_outline_rounded, color: LabColors.teal, size: 36),
              title: Text(s.dataOnDevice),
            ),
            ListTile(
              leading: const IconTile(icon: Icons.restart_alt_rounded, color: LabColors.danger, size: 36),
              title: Text(s.resetProgress, style: const TextStyle(color: LabColors.danger, fontWeight: FontWeight.w700)),
              onTap: () => _confirmReset(context),
            ),
          ]),
          group(s.aboutContent, [
            ListTile(
              leading: const IconTile(icon: Icons.verified_outlined, color: LabColors.success, size: 36),
              title: Text(s.contentVersion(curriculum.manifest.academicYear)),
            ),
            ExpansionTile(
              leading: const IconTile(icon: Icons.link_rounded, color: LabColors.muted, size: 36),
              title: Text(s.sourcesTitle),
              shape: const Border(),
              children: [
                for (final src in curriculum.manifest.sources)
                  ListTile(
                    dense: true,
                    title: Text(src.title),
                    subtitle: SelectableText(src.url, style: const TextStyle(fontSize: 11)),
                  ),
              ],
            ),
          ]),
        ],
      ),
    );
  }
}
