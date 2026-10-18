import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../content/content_catalog.dart';
import '../content/models/syllabus.dart';
import '../core/theme.dart';
import '../data/focus_session_store.dart';
import '../l10n/app_strings.dart';
import '../l10n/study_strings.dart';
import '../state/app_state.dart';
import '../state/focus_controller.dart' show formatClock;
import '../study/study_focus.dart';
import '../widgets/language_toggle.dart';
import '../widgets/study_widgets.dart';
import '../widgets/ui_kit.dart';

/// Focus time per day from lab focus sessions and study sessions of one
/// board, so summaries never count a session twice or mix boards.
FocusSummary focusSummary(BuildContext context, {DateTime? now}) {
  final boardId = context.read<AppState>().boardId;
  final lab = context.read<FocusSessionStore>().all().where((s) => s.boardId == boardId);
  final study = context.read<StudySessionStore>().all().where((s) => s.target.boardId == boardId);
  return FocusSummary.build(
    entries: [for (final s in lab) (s.endedAt, s.focusedSeconds), for (final s in study) (s.endedAt, s.focusedSeconds)],
    now: now ?? DateTime.now(),
  );
}

/// The study timer: choose what you are studying and for how long, focus,
/// then take a break. The existing 10- and 15-minute lengths are kept,
/// plus a custom length of 5–180 minutes.
class StudyTimerScreen extends StatefulWidget {
  const StudyTimerScreen({super.key, this.initialTarget});

  /// Pre-selects a class, chapter or topic (e.g. from a topic page).
  final StudyTarget? initialTarget;

  @override
  State<StudyTimerScreen> createState() => _StudyTimerScreenState();
}

class _StudyTimerScreenState extends State<StudyTimerScreen> {
  late final String _boardId = context.read<AppState>().boardId!;
  late final LoadedCurriculum _curriculum = context.read<ContentCatalog>().curriculum(_boardId)!;
  late int _classLevel = widget.initialTarget?.classLevel ??
      (_curriculum.classes.containsKey(context.read<AppState>().selectedClass) ? context.read<AppState>().selectedClass! : _curriculum.classLevels.first);
  late String? _chapterId = widget.initialTarget?.chapterId;
  late String? _topicId = widget.initialTarget?.topicId;
  late String? _practicalId = widget.initialTarget?.practicalId;

  /// null = custom length.
  late int? _preset = const [10, 15].contains(context.read<AppState>().defaultFocusMinutes) ? context.read<AppState>().defaultFocusMinutes : 10;
  late int _custom = context.read<FocusSettings>().customMinutes;

  StudyFocusController? _timer;
  bool _disposed = false;
  late final AppLifecycleListener _lifecycle = AppLifecycleListener(onHide: () => _timer?.pause());

  int get _minutes => _preset ?? _custom;

  @override
  void initState() {
    super.initState();
    _lifecycle; // starts listening
  }

  @override
  void dispose() {
    _disposed = true;
    _lifecycle.dispose();
    // Leaving mid-session saves it as ended early (never lost, never twice).
    final t = _timer;
    if (t != null && t.result == null && t.phase != StudyTimerPhase.ready) t.end();
    t?.dispose();
    super.dispose();
  }

  void _start() {
    final settings = context.read<FocusSettings>();
    if (_preset == null) settings.setCustomMinutes(_custom);
    final t = StudyFocusController(
      store: context.read<StudySessionStore>(),
      target: StudyTarget(
        boardId: _boardId,
        classLevel: _classLevel,
        chapterId: _chapterId,
        topicId: _chapterId == null ? null : _topicId,
        practicalId: _practicalId,
      ),
      duration: Duration(minutes: _minutes),
      breakDuration: Duration(minutes: settings.breakMinutes),
    );
    t.addListener(() {
      if (mounted && !_disposed) setState(() {});
    });
    setState(() => _timer = t);
    t.start();
  }

  Future<void> _confirmEnd() async {
    final t = _timer!;
    final st = context.readStudy;
    final wasRunning = t.isRunning;
    t.pause();
    final end = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(st.endSessionTitle),
        content: Text(st.endSessionBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, true), style: TextButton.styleFrom(foregroundColor: LabColors.danger), child: Text(st.endSession)),
          FilledButton(onPressed: () => Navigator.pop(ctx, false), child: Text(st.keepGoing)),
        ],
      ),
    );
    if (!mounted) return;
    if (end ?? false) {
      await t.end();
    } else if (wasRunning) {
      t.resume();
    }
  }

  void _newSession() {
    _timer?.dispose();
    setState(() => _timer = null);
  }

  @override
  Widget build(BuildContext context) {
    final st = context.study;
    final t = _timer;
    return PopScope(
      canPop: t == null || !(t.isRunning || t.isPaused),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmEnd();
      },
      child: Scaffold(
        appBar: AppBar(title: Text(st.studyTimer), actions: const [LanguageToggle()]),
        body: t == null ? _setup(context) : _running(context, t),
      ),
    );
  }

  Widget _setup(BuildContext context) {
    final s = context.strings;
    final st = context.study;
    final syllabus = _curriculum.classes[_classLevel]!;
    final chapter = _chapterId == null ? null : syllabus.chapters.where((c) => c.id == _chapterId).firstOrNull;
    final topics = chapter == null ? const <Topic>[] : [for (final t in chapter.topics) ...t.selfAndDescendants];
    final summary = focusSummary(context);
    final goal = context.watch<FocusSettings>().dailyGoalMinutes;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        FocusTodayCard(summary: summary, goalMinutes: goal),
        const SizedBox(height: 16),
        SectionHeader(st.whatAreYouStudying),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final c in _curriculum.classLevels)
              ChoiceChip(
                label: Text(s.className(c)),
                selected: c == _classLevel,
                onSelected: (_) => setState(() {
                  _classLevel = c;
                  _chapterId = null;
                  _topicId = null;
                  _practicalId = null;
                }),
              ),
          ],
        ),
        const SizedBox(height: 10),
        _Dropdown<String?>(
          label: st.chooseChapter,
          value: chapter?.id,
          items: [
            (null, st.wholeClass),
            for (final c in syllabus.chapters) (c.id, c.number == null ? s.ct(c.title) : '${c.number}. ${s.ct(c.title)}'),
          ],
          onChanged: (v) => setState(() {
            _chapterId = v;
            _topicId = null;
          }),
        ),
        if (chapter != null && topics.isNotEmpty) ...[
          const SizedBox(height: 10),
          _Dropdown<String?>(
            label: st.chooseTopic,
            value: topics.any((t) => t.id == _topicId) ? _topicId : null,
            items: [(null, st.anyTopic), for (final t in topics) (t.id, '${t.number} ${s.ct(t.title)}')],
            onChanged: (v) => setState(() => _topicId = v),
          ),
        ],
        if (syllabus.practicals.isNotEmpty) ...[
          const SizedBox(height: 10),
          _Dropdown<String?>(
            label: st.choosePractical,
            value: syllabus.practicals.any((p) => p.id == _practicalId) ? _practicalId : null,
            items: [(null, st.noPractical), for (final p in syllabus.practicals) (p.id, '${p.number}. ${s.ct(p.title)}')],
            onChanged: (v) => setState(() => _practicalId = v),
          ),
        ],
        const SizedBox(height: 18),
        SectionHeader(st.lengthLabel),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final m in const [10, 15])
              ChoiceChip(label: Text(s.minutesShort(m)), selected: _preset == m, onSelected: (_) => setState(() => _preset = m)),
            ChoiceChip(label: Text(st.custom), selected: _preset == null, onSelected: (_) => setState(() => _preset = null)),
          ],
        ),
        if (_preset == null) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: Text(st.lengthRange, style: const TextStyle(color: LabColors.muted))),
              MinutesStepper(
                value: _custom,
                min: FocusSettings.minMinutes,
                max: FocusSettings.maxMinutes,
                label: st.customLength,
                onChanged: (v) => setState(() => _custom = v),
              ),
            ],
          ),
        ],
        const SizedBox(height: 8),
        Text('${st.breakLabel}: ${st.minutes(context.watch<FocusSettings>().breakMinutes)}', style: const TextStyle(color: LabColors.muted)),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _start,
          icon: const Icon(Icons.play_arrow_rounded),
          label: Text('${st.startSession} · ${st.minutes(_minutes)}'),
        ),
        const SizedBox(height: 8),
        Text(st.backgroundNote, style: const TextStyle(fontSize: 12, color: LabColors.muted, height: 1.4)),
        const SizedBox(height: 20),
        _History(curriculum: _curriculum, boardId: _boardId),
      ],
    );
  }

  Widget _running(BuildContext context, StudyFocusController t) {
    final s = context.strings;
    final st = context.study;
    final onBreak = t.phase == StudyTimerPhase.onBreak;
    final finished = t.phase == StudyTimerPhase.finished;
    final breakOver = t.phase == StudyTimerPhase.breakOver;
    final clock = onBreak ? t.breakRemaining : t.remaining;
    final target = t.target;
    final chapter = target.chapterId == null ? null : _curriculum.chapter(target.chapterId!)?.$2;
    final topic = target.topicId == null ? null : _curriculum.topic(target.topicId!)?.topic;
    final what = [
      s.className(target.classLevel ?? _classLevel),
      if (chapter != null) s.ct(chapter.title),
      if (topic != null) '${topic.number} ${s.ct(topic.title)}',
    ].join(' › ');

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      children: [
        Text(what, textAlign: TextAlign.center, style: const TextStyle(color: LabColors.muted, fontWeight: FontWeight.w600)),
        const SizedBox(height: 20),
        Center(
          child: SizedBox.square(
            dimension: 220,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CircularProgressIndicator(
                  value: onBreak ? (t.breakDuration.inSeconds == 0 ? 0 : clock.inSeconds / t.breakDuration.inSeconds) : 1 - t.progress,
                  strokeWidth: 10,
                  color: onBreak ? LabColors.teal : LabColors.primary,
                  backgroundColor: LabColors.line,
                ),
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        finished || breakOver ? formatClock(t.focused) : formatClock(clock),
                        style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w900, color: LabColors.ink, fontFeatures: [FontFeature.tabularFigures()]),
                      ),
                      Text(
                        switch (t.phase) {
                          StudyTimerPhase.paused => st.pause,
                          StudyTimerPhase.onBreak => st.onBreak,
                          StudyTimerPhase.finished || StudyTimerPhase.breakOver => st.studyStatus(t.result?.status ?? StudySessionStatus.completed),
                          _ => s.timeLeft,
                        },
                        style: const TextStyle(color: LabColors.muted, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        if (t.isRunning || t.isPaused) ...[
          FilledButton.icon(
            onPressed: t.isRunning ? t.pause : t.resume,
            icon: Icon(t.isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded),
            label: Text(t.isRunning ? st.pause : st.resume),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(onPressed: _confirmEnd, icon: const Icon(Icons.stop_rounded), label: Text(st.endSession)),
          const SizedBox(height: 12),
          Text(st.backgroundNote, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: LabColors.muted, height: 1.4)),
        ],
        if (finished) ...[
          Icon(
            t.result?.status == StudySessionStatus.completed ? Icons.emoji_events_rounded : Icons.check_circle_outline_rounded,
            size: 48,
            color: t.result?.status == StudySessionStatus.completed ? LabColors.warning : LabColors.muted,
          ),
          const SizedBox(height: 8),
          if (t.result?.status == StudySessionStatus.completed)
            Text(st.sessionDone, textAlign: TextAlign.center, style: AppText.display(20)),
          Text(st.focusedFor(s.duration(t.focused.inSeconds)), textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)),
          const SizedBox(height: 16),
          if (t.breakDuration > Duration.zero && t.result?.status == StudySessionStatus.completed)
            FilledButton.icon(onPressed: t.startBreak, icon: const Icon(Icons.free_breakfast_rounded), label: Text(st.takeBreak(t.breakDuration.inMinutes))),
          const SizedBox(height: 8),
          OutlinedButton(onPressed: _newSession, child: Text(st.backToStudy)),
        ],
        if (onBreak) ...[
          FilledButton(onPressed: t.skipBreak, child: Text(st.skipBreak)),
        ],
        if (breakOver) ...[
          Text(st.breakOver, textAlign: TextAlign.center, style: AppText.display(17)),
          const SizedBox(height: 12),
          FilledButton(onPressed: _newSession, child: Text(st.backToStudy)),
        ],
      ],
    );
  }
}

class _Dropdown<T> extends StatelessWidget {
  const _Dropdown({required this.label, required this.value, required this.items, required this.onChanged});

  final String label;
  final T value;
  final List<(T, String)> items;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label, filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(14))),
      items: [
        for (final (v, text) in items) DropdownMenuItem(value: v, child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis)),
      ],
      onChanged: (v) => onChanged(v as T),
    );
  }
}

/// Today's focus against the daily goal, and the last seven days.
class FocusTodayCard extends StatelessWidget {
  const FocusTodayCard({super.key, required this.summary, required this.goalMinutes});

  final FocusSummary summary;
  final int goalMinutes;

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    final st = context.study;
    final today = summary.todaySeconds ~/ 60;
    final maxDay = summary.week.fold(1, (m, e) => e.$2 > m ? e.$2 : m);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(st.today, style: AppText.display(15))),
                if (today >= goalMinutes) Text(st.goalReached, style: const TextStyle(color: LabColors.success, fontWeight: FontWeight.w800)),
              ],
            ),
            const SizedBox(height: 6),
            ProgressLine(value: goalMinutes == 0 ? 0 : today / goalMinutes, label: '${st.dailyGoal}: ${st.goalProgress(today, goalMinutes)}', color: LabColors.primary),
            const SizedBox(height: 14),
            Text('${st.thisWeek} · ${s.duration(summary.weekSeconds)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: LabColors.muted)),
            const SizedBox(height: 8),
            SizedBox(
              height: 64,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final (day, secs) in summary.week)
                    Expanded(
                      child: Semantics(
                        label: '${s.weekdayShort(day.weekday)} ${s.duration(secs)}',
                        excludeSemantics: true,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Container(
                              height: 40 * secs / maxDay,
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              decoration: BoxDecoration(color: LabColors.primary.withValues(alpha: 0.7), borderRadius: BorderRadius.circular(4)),
                            ),
                            const SizedBox(height: 4),
                            Text(s.weekdayShort(day.weekday), maxLines: 1, style: const TextStyle(fontSize: 10, color: LabColors.muted)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text(st.totalFocus(s.duration(summary.allTimeSeconds)), style: const TextStyle(fontSize: 12, color: LabColors.muted)),
          ],
        ),
      ),
    );
  }
}

class _History extends StatelessWidget {
  const _History({required this.curriculum, required this.boardId});

  final LoadedCurriculum curriculum;
  final String boardId;

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    final st = context.study;
    final study = [for (final x in context.read<StudySessionStore>().all()) if (x.target.boardId == boardId) x]
      ..sort((a, b) => b.endedAt.compareTo(a.endedAt));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(st.history),
        if (study.isEmpty)
          Text(st.noSessionsYet, style: const TextStyle(color: LabColors.muted))
        else
          for (final x in study.take(20))
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: IconTile(
                  icon: switch (x.status) {
                    StudySessionStatus.completed => Icons.check_circle_rounded,
                    StudySessionStatus.ended => Icons.stop_circle_outlined,
                    StudySessionStatus.interrupted => Icons.warning_amber_rounded,
                  },
                  color: switch (x.status) {
                    StudySessionStatus.completed => LabColors.success,
                    StudySessionStatus.ended => LabColors.muted,
                    StudySessionStatus.interrupted => LabColors.warning,
                  },
                  size: 36,
                ),
                title: Text('${s.duration(x.focusedSeconds)} / ${st.minutes(x.plannedSeconds ~/ 60)} · ${st.studyStatus(x.status)}',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(
                  [
                    if (x.target.classLevel case final c?) s.className(c),
                    if (x.target.chapterId case final id?) ?curriculum.chapter(id)?.$2.title.of(s.language),
                    if (x.target.topicId case final id?) ?curriculum.topic(id)?.topic.number,
                    '${x.endedAt.toLocal().day} ${s.monthsShort[x.endedAt.toLocal().month - 1]}',
                  ].join(' · '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
      ],
    );
  }
}
