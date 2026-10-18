import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../analytics/progress_report.dart';
import '../content/content_catalog.dart';
import '../core/theme.dart';
import '../data/focus_session_store.dart';
import '../data/practical_attempt_store.dart';
import '../data/practicals_repository.dart';
import '../l10n/app_strings.dart';
import '../l10n/study_strings.dart';
import '../study/personal_notes_store.dart';
import '../state/app_state.dart';
import '../widgets/language_toggle.dart';
import '../widgets/ui_kit.dart';
import 'board_selection_screen.dart';
import 'bookmarks_screen.dart';
import 'chapter_list_screen.dart';
import 'home_study_dashboard.dart';
import 'main_shell.dart';
import 'my_notes_screen.dart';
import 'revision_screen.dart';
import 'study_timer_screen.dart';
import 'practical_dashboard_screen.dart';
import 'search_screen.dart';
import 'settings_screen.dart';

/// Home dashboard: board, classes, continue learning, quick stats and
/// shortcuts. Every number comes from data saved on this device.
class ClassSelectionScreen extends StatefulWidget {
  const ClassSelectionScreen({super.key});

  @override
  State<ClassSelectionScreen> createState() => _ClassSelectionScreenState();
}

class _ClassSelectionScreenState extends State<ClassSelectionScreen> {
  /// Opens [screen]; on return, rebuilds so "Continue learning" and the
  /// stats reflect anything saved meanwhile.
  Future<void> _push(Widget screen) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    final app = context.watch<AppState>();
    final catalog = context.read<ContentCatalog>();
    final board = catalog.registry.byId(app.boardId!)!;
    final curriculum = catalog.curriculum(app.boardId!)!;
    final report = ProgressReport.build(
      curriculum: curriculum,
      attempts: context.read<PracticalAttemptStore>().all(),
      sessions: context.read<FocusSessionStore>().all(),
      classLevel: app.selectedClass ?? curriculum.classLevels.first,
      now: DateTime.now(),
    );

    final push = _push;
    // The grid cards have fixed heights; grow them with the phone's font size.
    final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
          children: [
            Row(
              children: [
                // The brand mark gives way on very narrow phones.
                if (MediaQuery.sizeOf(context).width >= 360) ...[
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(color: LabColors.night, borderRadius: BorderRadius.circular(13)),
                    child: const Icon(Icons.science_rounded, color: Colors.white),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: Text(s.appName, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.display(16)),
                ),
                IconButton(tooltip: s.search, onPressed: () => push(const SearchScreen()), icon: const Icon(Icons.search_rounded)),
                IconButton(tooltip: s.settings, onPressed: () => push(const SettingsScreen()), icon: const Icon(Icons.settings_outlined)),
                const LanguageToggle(),
              ],
            ),
            const SizedBox(height: 14),
            FadeSlideIn(child: Text(s.homeGreeting, style: AppText.display(26, height: 1.2))),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: ActionChip(
                avatar: const Icon(Icons.account_balance_rounded, size: 18, color: LabColors.primary),
                label: Text('${s.ct(board.name)} · ${s.syllabusYear(curriculum.manifest.academicYear)} · ${s.changeBoard}'),
                onPressed: () => push(const BoardSelectionScreen()),
              ),
            ),
            const SizedBox(height: 10),
            SectionHeader(
              s.chooseYourClass,
              trailing: Text(s.tapForChapters, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: LabColors.muted)),
            ),
            LayoutBuilder(
              // Fixed card height (not an aspect ratio) so narrow phones
              // don't squeeze the card below its content.
              builder: (context, constraints) => GridView(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: constraints.maxWidth >= 560 ? 4 : 2,
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 14,
                  mainAxisExtent: 150 * textScale,
                ),
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  for (final (i, c) in curriculum.classLevels.indexed)
                    FadeSlideIn(
                      index: i,
                      child: _ClassCard(
                        classLevel: c,
                        selected: c == app.selectedClass,
                        chapterCount: curriculum.classes[c]!.examChapters.length,
                        subject: s.ct(curriculum.classes[c]!.subjectName),
                        onTap: () {
                          context.read<AppState>().selectClass(c);
                          push(const ChapterListScreen());
                        },
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            FadeSlideIn(index: 3, child: _ContinueCard(report: report, curriculum: curriculum, push: _push)),
            if (report.hasData) ...[
              const SizedBox(height: 12),
              _StatsStrip(report: report),
            ],
            const SizedBox(height: 18),
            HomeStudyDashboard(curriculum: curriculum, classLevel: app.selectedClass ?? curriculum.classLevels.first, push: _push),
            const SizedBox(height: 18),
            SectionHeader(s.explore),
            LayoutBuilder(
              builder: (context, constraints) => GridView(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: constraints.maxWidth >= 560 ? 4 : 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  mainAxisExtent: 112 * textScale,
                ),
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _ExploreTile(icon: Icons.science_rounded, color: LabColors.primary, title: s.virtualLab, hint: s.labsHint, onTap: () => MainShell.goTo(context, AppTab.lab)),
                  _ExploreTile(icon: Icons.assignment_rounded, color: LabColors.amber, title: s.examZone, hint: s.examZoneHint, onTap: () => MainShell.goTo(context, AppTab.exam)),
                  _ExploreTile(icon: Icons.timer_rounded, color: LabColors.teal, title: s.focusMode, hint: s.focusHint, onTap: () => push(const StudyTimerScreen())),
                  _ExploreTile(icon: Icons.bookmark_rounded, color: LabColors.danger, title: s.bookmarks, hint: s.bookmarksHint, onTap: () => push(const BookmarksScreen())),
                  _ExploreTile(
                    icon: Icons.edit_note_rounded,
                    color: LabColors.amber,
                    title: context.study.myNotes,
                    hint: context.study.notesCount(context.watch<PersonalNotesStore>().where(boardId: app.boardId!).length),
                    onTap: () => push(const MyNotesScreen()),
                  ),
                  _ExploreTile(
                    icon: Icons.replay_circle_filled_rounded,
                    color: LabColors.secondary,
                    title: context.study.revision,
                    hint: context.study.revisionHint,
                    onTap: () => push(const RevisionScreen()),
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

class _ClassCard extends StatelessWidget {
  const _ClassCard({
    required this.classLevel,
    required this.selected,
    required this.chapterCount,
    required this.subject,
    required this.onTap,
  });

  final int classLevel;
  final bool selected;
  final int chapterCount;
  final String subject;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = LabColors.classAccents[classLevel] ?? LabColors.primary;
    final s = context.strings;
    final fg = selected ? Colors.white : LabColors.ink;
    return Material(
      color: selected ? LabColors.night : Colors.white,
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: selected ? LabColors.night : accent.withValues(alpha: 0.5), width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      subject.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.6, color: selected ? Colors.white70 : accent),
                    ),
                  ),
                  if (selected) const Icon(Icons.circle, size: 9, color: Color(0xFF2DD4BF)),
                ],
              ),
              const Spacer(),
              Text('$classLevel', style: AppText.display(40, color: selected ? Colors.white : accent, height: 1)),
              const Spacer(),
              // One line each; shrink rather than wrap on narrow phones.
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(s.className(classLevel), maxLines: 1, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: fg)),
              ),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  s.chapterCount(chapterCount),
                  maxLines: 1,
                  style: TextStyle(color: selected ? Colors.white70 : LabColors.muted),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Resumes the most recent lab visit that still exists in the syllabus,
/// or invites the student to start one.
class _ContinueCard extends StatelessWidget {
  const _ContinueCard({required this.report, required this.curriculum, required this.push});

  final ProgressReport report;
  final LoadedCurriculum curriculum;
  final Future<void> Function(Widget) push;

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    final labs = context.read<PracticalsRepository>();
    final last = report.recent
        // Only topic labs can be continued from here (they reopen their topic).
        .where((r) => r.topicId != null && curriculum.topic(r.topicId!) != null && curriculum.labsForTopic(r.topicId!).contains(r.practicalId))
        .firstOrNull;

    if (last == null) {
      return HeroPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.continueLearning.toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: Colors.white70)),
            const SizedBox(height: 8),
            SizedBox(width: 220, child: Text(s.startFirstLab, style: AppText.display(20, color: Colors.white))),
            const SizedBox(height: 6),
            SizedBox(width: 240, child: Text(s.startFirstLabHint, style: const TextStyle(color: Colors.white70, height: 1.4))),
          ],
        ),
      );
    }

    final loc = curriculum.topic(last.topicId!)!;
    final lab = labs.byId(last.practicalId);
    return HeroPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(s.continueLearning.toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: Colors.white70)),
          const SizedBox(height: 8),
          SizedBox(width: 230, child: Text(s.tr(lab.title), style: AppText.display(20, color: Colors.white))),
          const SizedBox(height: 4),
          Text(
            s.focusBreadcrumb(loc.syllabus.classLevel, loc.chapter.number, loc.topic.number),
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(value: last.progress, minHeight: 8, color: Colors.white, backgroundColor: Colors.white24),
                ),
              ),
              const SizedBox(width: 10),
              Text('${(last.progress * 100).round()}%', style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.white)),
            ],
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: LabColors.ink),
            onPressed: () => push(PracticalDashboardScreen(
              boardId: curriculum.manifest.boardId,
              classLevel: loc.syllabus.classLevel,
              chapter: loc.chapter,
              topic: loc.topic,
              labs: [for (final id in curriculum.labsForTopic(loc.topic.id)) labs.byId(id)],
            )),
            icon: const Icon(Icons.play_arrow_rounded),
            label: Text(s.resume),
          ),
        ],
      ),
    );
  }
}

class _StatsStrip extends StatelessWidget {
  const _StatsStrip({required this.report});

  final ProgressReport report;

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    final acc = report.accuracy;
    Widget stat(IconData icon, Color color, String value, String label) => Expanded(
          child: Row(
            children: [
              IconTile(icon: icon, color: color, size: 34),
              const SizedBox(width: 8),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FittedBox(fit: BoxFit.scaleDown, child: Text(value, style: const TextStyle(fontWeight: FontWeight.w800, color: LabColors.ink))),
                    Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: LabColors.muted)),
                  ],
                ),
              ),
            ],
          ),
        );
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          children: [
            stat(Icons.local_fire_department_rounded, LabColors.warning, s.streakDays(report.streakDays), s.streakShort),
            stat(Icons.timer_rounded, LabColors.primary, s.duration(report.totalFocusSeconds), s.focusShort),
            stat(Icons.track_changes_rounded, LabColors.teal, acc == null ? '—' : '${(acc * 100).round()}%', s.accuracy),
          ],
        ),
      ),
    );
  }
}

class _ExploreTile extends StatelessWidget {
  const _ExploreTile({required this.icon, required this.color, required this.title, required this.hint, required this.onTap});

  final IconData icon;
  final Color color;
  final String title;
  final String hint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconTile(icon: icon, color: color, size: 36),
              const Spacer(),
              Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, color: LabColors.ink)),
              Text(hint, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: LabColors.muted)),
            ],
          ),
        ),
      ),
    );
  }
}
