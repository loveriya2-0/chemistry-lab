import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../analytics/progress_report.dart';
import '../content/content_catalog.dart';
import '../content/models/syllabus.dart';
import '../core/theme.dart';
import '../data/focus_session_store.dart';
import '../data/practical_attempt_store.dart';
import '../data/practicals_repository.dart';
import '../l10n/app_strings.dart';
import '../l10n/premium_strings.dart';
import '../models/focus_session.dart';
import '../models/practical.dart';
import '../models/practical_attempt.dart';
import '../state/app_state.dart';
import '../widgets/chapter_style.dart';
import '../widgets/language_toggle.dart';
import '../widgets/premium_gate.dart';
import '../widgets/week_actions_chart.dart';

/// Progress dashboard built only from records saved on this device.
class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key, this.onStartPractising});

  /// Where "Start practising" leads; pops the screen when null.
  final VoidCallback? onStartPractising;

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  late final List<PracticalAttempt> _attempts;
  late final List<FocusSession> _sessions;
  late final LoadedCurriculum _curriculum;
  late int _classLevel;

  @override
  void initState() {
    super.initState();
    _attempts = context.read<PracticalAttemptStore>().all();
    _sessions = context.read<FocusSessionStore>().all();
    final app = context.read<AppState>();
    _curriculum = context.read<ContentCatalog>().curriculum(app.boardId ?? 'cbse')!;
    final levels = _curriculum.classLevels;
    final preferred = app.selectedClass ?? _latestClass();
    _classLevel = levels.contains(preferred) ? preferred! : levels.first;
  }

  /// Class of the most recent saved activity, if any.
  int? _latestClass() {
    final dated = [
      for (final a in _attempts) (a.endedAt, a.classLevel),
      for (final s in _sessions) (s.endedAt, s.classLevel),
    ]..sort((a, b) => b.$1.compareTo(a.$1));
    return dated.isEmpty ? null : dated.first.$2;
  }

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    final now = DateTime.now();
    final report = ProgressReport.build(
      curriculum: _curriculum,
      attempts: _attempts,
      sessions: _sessions,
      classLevel: _classLevel,
      now: now,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(s.myProgress),
        actions: const [LanguageToggle()],
      ),
      body: !report.hasData
          ? _EmptyProgress(onStart: widget.onStartPractising)
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (final c in _curriculum.classLevels)
                      ChoiceChip(
                        label: Text(s.className(c)),
                        selected: c == _classLevel,
                        onSelected: (_) => setState(() => _classLevel = c),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                _OverallCard(report: report),
                const SizedBox(height: 12),
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: _StatTile(
                          icon: Icons.local_fire_department_rounded,
                          iconColor: LabColors.warning,
                          label: s.currentStreak,
                          value: s.streakDays(report.streakDays),
                          hint: report.streakDays == 0 ? s.noStreak : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatTile(
                          icon: Icons.replay_rounded,
                          iconColor: LabColors.secondary,
                          label: s.practicalAttempts,
                          value: '${report.attempts}',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _LearningTimeCard(report: report),
                const SizedBox(height: 12),
                _CompletionCard(report: report),
                const SizedBox(height: 12),
                // Detailed analysis is Premium; the overview above stays free.
                if (!context.isPremium) ...[
                  PremiumLockedCard(body: context.premium.lockedAnalysis),
                  const SizedBox(height: 20),
                ] else ...[
                  _AccuracyCard(report: report),
                  const SizedBox(height: 20),
                  _SectionTitle(s.chapterProgress),
                  if (!report.hasLabs)
                    _Hint(s.noLabsForClass(report.classLevel))
                  else ...[
                    for (final (i, c) in report.chapters.indexed) ...[
                      _ChapterCard(progress: c, accent: chapterAccent(i)),
                      const SizedBox(height: 12),
                    ],
                    if (report.chaptersWithoutLab > 0) _Hint(s.otherChaptersNoLab(report.chaptersWithoutLab)),
                  ],
                ],
                const SizedBox(height: 8),
                _SectionTitle(s.recentActivity),
                _RecentActivity(records: report.recent, curriculum: _curriculum, now: now),
                const SizedBox(height: 16),
                const _LocalDataNote(),
              ],
            ),
    );
  }
}

String _percent(double v) => '${(v * 100).round()}%';

// ─── Building blocks ────────────────────────────────────────────────────────

class _Panel extends StatelessWidget {
  const _Panel({required this.icon, required this.title, required this.child});

  final IconData icon;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: LabColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: LabColors.ink,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
      child: Text(
        text,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: LabColors.ink),
      ),
    );
  }
}

/// Big number + caption.
class _Figure extends StatelessWidget {
  const _Figure({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: LabColors.ink),
          ),
        ),
        Text(label, style: const TextStyle(fontSize: 12, color: LabColors.muted)),
      ],
    );
  }
}

class _Ring extends StatelessWidget {
  const _Ring({
    required this.value,
    required this.label,
    required this.color,
    required this.track,
    required this.textColor,
    this.size = 88,
  });

  final double value;
  final String label;
  final Color color;
  final Color track;
  final Color textColor;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: Stack(
        fit: StackFit.expand,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: value),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutCubic,
            builder: (_, v, _) => CircularProgressIndicator(
              value: v,
              strokeWidth: size / 9,
              strokeCap: StrokeCap.round,
              color: color,
              backgroundColor: track,
            ),
          ),
          Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: size / 4.4,
                fontWeight: FontWeight.w900,
                color: textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.value, required this.color});

  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: value),
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeOutCubic,
        builder: (_, v, _) => LinearProgressIndicator(
          value: v,
          minHeight: 8,
          color: color,
          backgroundColor: color.withValues(alpha: 0.12),
        ),
      ),
    );
  }
}

// ─── Cards ──────────────────────────────────────────────────────────────────

class _OverallCard extends StatelessWidget {
  const _OverallCard({required this.report});

  final ProgressReport report;

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [LabColors.ink, LabColors.primary]),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _Ring(
                value: report.overallProgress,
                label: _percent(report.overallProgress),
                color: Colors.white,
                track: Colors.white24,
                textColor: Colors.white,
                size: 96,
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.overallProgress,
                      style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      s.classProgress(report.classLevel),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _MiniStat(value: '${report.chaptersDone}/${report.chaptersTotal}', label: s.chaptersCompleted),
              _MiniStat(value: '${report.topicsDone}/${report.topicsTotal}', label: s.topicsCompleted),
              _MiniStat(
                value: '${report.practicalsDone}/${report.practicalsTotal}',
                label: s.practicalsCompleted,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            report.hasLabs ? s.progressBasis : s.noLabsForClass(report.classLevel),
            style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.35),
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: Colors.white12,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 11, height: 1.2),
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
    required this.iconColor,
    required this.label,
    required this.value,
    this.hint,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 26),
          const SizedBox(height: 8),
          _Figure(value: value, label: label),
          if (hint != null) ...[
            const SizedBox(height: 4),
            Text(hint!, style: const TextStyle(fontSize: 11, color: LabColors.muted)),
          ],
        ],
      ),
    );
  }
}

class _LearningTimeCard extends StatelessWidget {
  const _LearningTimeCard({required this.report});

  final ProgressReport report;

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    final split = [(10, report.tenMinuteSessions), (15, report.fifteenMinuteSessions)];
    final maxCount = math.max(1, math.max(split[0].$2, split[1].$2));

    return _Panel(
      icon: Icons.timer_rounded,
      title: s.learningTime,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _Figure(value: s.duration(report.totalFocusSeconds), label: s.totalFocusTime)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Figure(value: '${report.focusSessions}', label: s.focusSessions),
                    Text(
                      s.sessionsFinished(report.focusSessionsFinished),
                      style: const TextStyle(fontSize: 11, color: LabColors.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          for (final (minutes, count) in split)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 110,
                    child: Text(
                      s.minuteSessions(minutes),
                      style: const TextStyle(fontSize: 13, color: LabColors.ink),
                    ),
                  ),
                  Expanded(child: _Bar(value: count / maxCount, color: LabColors.primary)),
                  SizedBox(
                    width: 32,
                    child: Text(
                      '$count',
                      textAlign: TextAlign.end,
                      style: const TextStyle(fontWeight: FontWeight.w800, color: LabColors.ink),
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

class _CompletionCard extends StatelessWidget {
  const _CompletionCard({required this.report});

  final ProgressReport report;

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    final total = report.practicalsTotal;
    return _Panel(
      icon: Icons.science_rounded,
      title: s.practicalCompletion,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Figure(
            value: '${report.practicalsDone}/$total',
            label: '${s.practicalsCompleted} · ${s.className(report.classLevel)}',
          ),
          const SizedBox(height: 10),
          _Bar(value: total == 0 ? 0 : report.practicalsDone / total, color: LabColors.success),
          const SizedBox(height: 8),
          Text(
            s.completionRuns(report.completionRuns, report.attempts),
            style: const TextStyle(fontSize: 13, color: LabColors.muted),
          ),
        ],
      ),
    );
  }
}

class _AccuracyCard extends StatelessWidget {
  const _AccuracyCard({required this.report});

  final ProgressReport report;

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    final accuracy = report.accuracy;
    return _Panel(
      icon: Icons.track_changes_rounded,
      title: s.accuracy,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _Ring(
                value: accuracy ?? 0,
                label: accuracy == null ? '—' : _percent(accuracy),
                color: ActionColors.correct,
                track: ActionColors.correct.withValues(alpha: 0.12),
                textColor: LabColors.ink,
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  children: [
                    _CountRow(
                      icon: Icons.check_circle_rounded,
                      color: ActionColors.correct,
                      label: s.correctActions,
                      count: report.correctActions,
                    ),
                    const SizedBox(height: 10),
                    _CountRow(
                      icon: Icons.cancel_rounded,
                      color: ActionColors.wrong,
                      label: s.wrongActions,
                      count: report.wrongActions,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (report.totalActions == 0)
            Text(s.noActionsYet, style: const TextStyle(color: LabColors.muted))
          else ...[
            Text(
              s.lastSevenDays,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: LabColors.ink),
            ),
            const SizedBox(height: 12),
            WeekActionsChart(days: report.lastSevenDays),
          ],
        ],
      ),
    );
  }
}

class _CountRow extends StatelessWidget {
  const _CountRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.count,
  });

  final IconData icon;
  final Color color;
  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(width: 8),
        Expanded(child: Text(label, style: const TextStyle(color: LabColors.muted))),
        Text(
          '$count',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: LabColors.ink),
        ),
      ],
    );
  }
}

class _ChapterCard extends StatelessWidget {
  const _ChapterCard({required this.progress, required this.accent});

  final ChapterProgress progress;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    final chapter = progress.chapter;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.menu_book_rounded, color: accent),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        chapter.number == null ? s.alsoInSyllabus : s.chapterOverline(chapter.number!),
                        style: TextStyle(
                          color: accent,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                        ),
                      ),
                      Text(
                        s.ct(chapter.title),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: LabColors.ink,
                        ),
                      ),
                    ],
                  ),
                ),
                if (progress.isComplete)
                  const Icon(Icons.verified_rounded, color: LabColors.success),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _Bar(value: progress.progress, color: accent)),
                const SizedBox(width: 10),
                Text(
                  _percent(progress.progress),
                  style: const TextStyle(fontWeight: FontWeight.w800, color: LabColors.ink),
                ),
              ],
            ),
            const SizedBox(height: 6),
            for (final t in progress.topics)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      t.isComplete ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                      size: 20,
                      color: t.isComplete ? LabColors.success : LabColors.muted,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${t.topic.number} ${s.ct(t.topic.title)}',
                            style: const TextStyle(fontWeight: FontWeight.w700, color: LabColors.ink),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${s.practicalsOf(t.practicalsDone, t.practicalsTotal)} · '
                            '${s.attemptsCount(t.attempts)}',
                            style: const TextStyle(fontSize: 12, color: LabColors.muted),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      _percent(t.progress),
                      style: const TextStyle(fontSize: 13, color: LabColors.muted),
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

class _RecentActivity extends StatelessWidget {
  const _RecentActivity({required this.records, required this.curriculum, required this.now});

  final List<PracticeRecord> records;
  final LoadedCurriculum curriculum;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final repo = context.read<PracticalsRepository>();
    final tiles = <Widget>[];
    for (final r in records) {
      // Skip records whose content was removed from the app since.
      final Practical practical;
      try {
        practical = repo.byId(r.practicalId);
      } on StateError {
        continue;
      }
      // Records whose chapter has no verified equivalent show the class only.
      final chapter = r.chapterId == null ? null : curriculum.chapter(r.chapterId!)?.$2;
      tiles.add(_ActivityTile(record: r, practical: practical, chapter: chapter, now: now));
    }

    return Card(
      margin: EdgeInsets.zero,
      child: Column(
        children: [
          for (final (i, tile) in tiles.indexed) ...[
            if (i > 0) const Divider(height: 1, indent: 16, endIndent: 16),
            tile,
          ],
        ],
      ),
    );
  }
}

class _ActivityTile extends StatelessWidget {
  const _ActivityTile({
    required this.record,
    required this.practical,
    required this.chapter,
    required this.now,
  });

  final PracticeRecord record;
  final Practical practical;
  final Chapter? chapter;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    final r = record;
    final focus = r.focus;
    final number = chapter?.number;
    final where = number == null ? s.className(r.classLevel) : s.classChapterShort(r.classLevel, number);

    return Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: practical.accent.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(practical.icon, color: practical.accent, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.tr(practical.title),
                  style: const TextStyle(fontWeight: FontWeight.w800, color: LabColors.ink),
                ),
                const SizedBox(height: 2),
                Text(
                  '${s.when(r.endedAt, now)} · $where',
                  style: const TextStyle(fontSize: 12, color: LabColors.muted),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    if (r.correct + r.wrong > 0) ...[
                      _Tag(icon: Icons.check_rounded, color: ActionColors.correct, label: '${r.correct}'),
                      _Tag(icon: Icons.close_rounded, color: ActionColors.wrong, label: '${r.wrong}'),
                    ],
                    if (r.completions > 0)
                      _Tag(
                        icon: Icons.emoji_events_rounded,
                        color: LabColors.warning,
                        label: s.activityCompleted,
                      )
                    else if (r.totalSteps > 0)
                      _Tag(
                        icon: Icons.format_list_numbered_rounded,
                        color: LabColors.muted,
                        label: s.stepsDone(r.bestSteps, r.totalSteps),
                      ),
                    if (focus != null)
                      _Tag(
                        icon: Icons.timer_rounded,
                        color: LabColors.primary,
                        label: s.focusBadge(
                          focus.plannedSeconds ~/ 60,
                          focus.status == FocusStatus.completed,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Small pill: coloured icon carries identity, text stays in ink.
class _Tag extends StatelessWidget {
  const _Tag({required this.icon, required this.color, required this.label});

  final IconData icon;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: LabColors.background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: LabColors.ink, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _LocalDataNote extends StatelessWidget {
  const _LocalDataNote();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.lock_rounded, size: 14, color: LabColors.muted),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            context.strings.localDataNote,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: LabColors.muted),
          ),
        ),
      ],
    );
  }
}

class _EmptyProgress extends StatelessWidget {
  const _EmptyProgress({this.onStart});

  final VoidCallback? onStart;

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: LabColors.primary.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.insights_rounded, size: 56, color: LabColors.primary),
            ),
            const SizedBox(height: 20),
            Text(
              s.noProgressTitle,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: LabColors.ink),
            ),
            const SizedBox(height: 8),
            Text(
              s.noProgressBody,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, color: LabColors.muted, height: 1.4),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onStart ?? () => Navigator.of(context).pop(),
              icon: const Icon(Icons.science_rounded),
              label: Text(s.startPractising),
            ),
            const SizedBox(height: 20),
            const _LocalDataNote(),
          ],
        ),
      ),
    );
  }
}

/// Muted one-line explanation under a section.
class _Hint extends StatelessWidget {
  const _Hint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
      child: Text(text, style: const TextStyle(fontSize: 13, color: LabColors.muted, height: 1.4)),
    );
  }
}
