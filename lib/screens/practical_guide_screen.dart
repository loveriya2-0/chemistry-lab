import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../content/content_catalog.dart';
import '../content/models/practical_guide.dart';
import '../content/models/syllabus.dart';
import '../core/theme.dart';
import '../data/practicals_repository.dart';
import '../l10n/app_strings.dart';
import '../l10n/study_strings.dart';
import '../models/practical.dart';
import '../models/practical_path.dart';
import '../state/app_state.dart';
import '../widgets/language_toggle.dart';
import '../widgets/learning_widgets.dart';
import '../widgets/ui_kit.dart';
import 'focus_setup_screen.dart';

/// Opens a lab's details screen, which starts the lab. Every way into a
/// lab (Lab tab, topic, Search) goes through here.
void openPracticalGuide(BuildContext context, {required String labId, required int classLevel, String? topicId, String? listedPracticalId}) {
  Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => PracticalGuideScreen(labId: labId, classLevel: classLevel, topicId: topicId, listedPracticalId: listedPracticalId),
  ));
}

/// A practical's details before the virtual lab: aim, apparatus, chemicals,
/// the real laboratory procedure with expected observations, safety, how
/// the simulation differs from the real lab, and where the experiment sits
/// in the syllabus.
class PracticalGuideScreen extends StatelessWidget {
  const PracticalGuideScreen({super.key, required this.labId, required this.classLevel, this.topicId, this.listedPracticalId});

  final String labId;

  /// The class the student is browsing. Attempts are saved under this
  /// class when the lab belongs to it (a topic placement or a listed
  /// practical in the class).
  final int classLevel;

  /// The topic the lab was opened from, if any.
  final String? topicId;

  /// The listed practical the lab was opened from, if any.
  final String? listedPracticalId;

  /// Where the lab session is saved: the topic or listed practical it was
  /// opened from; else its placement or listed practical in [classLevel];
  /// else its first placement anywhere.
  PracticalPath? startPath(LoadedCurriculum curriculum, Practical lab) {
    final boardId = curriculum.manifest.boardId;
    final placements = curriculum.placementsOf(labId);
    final links = curriculum.practicalsForLab(labId);
    PracticalPath fromTopic(LabPlacement p) => PracticalPath(
          boardId: boardId,
          classLevel: p.location.syllabus.classLevel,
          chapter: p.location.chapter,
          topic: p.location.topic,
          practical: lab,
        );
    PracticalPath fromPractical(({int classLevel, BoardPractical practical, LabPracticalLink link}) l) => PracticalPath(
          boardId: boardId,
          classLevel: l.classLevel,
          chapter: [for (final id in l.practical.chapterIds) ?curriculum.chapter(id)?.$2].firstOrNull,
          listedPractical: l.practical,
          practical: lab,
        );
    if (topicId != null) {
      if (placements.where((p) => p.location.topic.id == topicId).firstOrNull case final p?) return fromTopic(p);
    }
    if (listedPracticalId != null) {
      if (links.where((l) => l.practical.id == listedPracticalId).firstOrNull case final l?) return fromPractical(l);
    }
    if (placements.where((p) => p.location.syllabus.classLevel == classLevel).firstOrNull case final p?) return fromTopic(p);
    if (links.where((l) => l.classLevel == classLevel).firstOrNull case final l?) return fromPractical(l);
    if (placements.firstOrNull case final p?) return fromTopic(p);
    return links.isEmpty ? null : fromPractical(links.first);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    final boardId = context.read<AppState>().boardId!;
    final curriculum = context.read<ContentCatalog>().curriculum(boardId)!;
    final lab = context.read<PracticalsRepository>().byId(labId);
    final guide = curriculum.guideFor(labId)!;
    final placements = curriculum.placementsOf(labId);
    final start = startPath(curriculum, lab);
    final links = curriculum.practicalsForLab(labId);

    return Scaffold(
      appBar: AppBar(title: Text(s.tr(lab.title)), actions: const [LanguageToggle()]),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconTile(icon: lab.icon, color: lab.accent, size: 48),
              const SizedBox(width: 14),
              Expanded(child: Text(s.tr(lab.description), style: const TextStyle(color: LabColors.muted, height: 1.4))),
            ],
          ),
          const SizedBox(height: 14),
          _Notice(text: s.virtualSimulationNotice),
          const SizedBox(height: 12),
          ContentSection(title: s.guideAim, child: BodyText(s.ct(guide.aim))),
          if (guide.equation case final e?) ContentSection(title: s.guideReaction, child: FormulaBox(e)),
          ContentSection(
            title: s.guideApparatus,
            child: BulletList([for (final a in guide.apparatus) s.ct(a.name)]),
          ),
          ContentSection(
            title: s.guideChemicals,
            child: Column(children: [for (final c in guide.chemicals) _ChemicalRow(item: c)]),
          ),
          ContentSection(
            title: s.guideProcedure,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final (i, step) in guide.steps.indexed) _StepTile(number: i + 1, step: step),
                Text(s.guideProcedureNote, style: const TextStyle(fontSize: 12, color: LabColors.muted, height: 1.4)),
              ],
            ),
          ),
          ContentSection(
            title: s.guideSafety,
            color: LabColors.warning,
            child: BulletList([for (final t in guide.safety) s.ct(t)], color: LabColors.warning),
          ),
          ContentSection(title: s.guideResult, color: LabColors.success, child: BodyText(s.ct(guide.result))),
          ContentSection(
            title: s.guideVirtualVsReal,
            color: LabColors.secondary,
            child: BulletList([for (final t in guide.simulationLimits) s.ct(t)], color: LabColors.secondary),
          ),
          if (guide.viva.isNotEmpty)
            ContentSection(
              title: context.study.vivaTitle,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(context.study.vivaHint, style: const TextStyle(fontSize: 12, color: LabColors.muted, height: 1.4)),
                  const SizedBox(height: 8),
                  for (final (i, v) in guide.viva.indexed) VivaTile(number: i + 1, viva: v),
                ],
              ),
            ),
          ContentSection(
            title: s.guideInSyllabus,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final p in placements)
                  _SyllabusLine(title: s.conceptLabAt(p.location.syllabus.classLevel, p.location.topic.number, s.ct(p.location.topic.title))),
                for (final l in links)
                  _SyllabusLine(
                    title: s.practicalLink(l.classLevel, l.practical.number, official: l.link.relation == LabRelation.official),
                    detail: s.ct(l.link.note ?? l.practical.title),
                  ),
                if (links.isEmpty) _SyllabusLine(title: s.notAListedPractical),
              ],
            ),
          ),
          ProvenanceNote(sources: guide.sources, review: guide.review, curriculum: curriculum),
        ],
      ),
      bottomNavigationBar: start == null
          ? null
          : SafeArea(
              minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: lab.accent, minimumSize: const Size.fromHeight(48)),
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => FocusSetupScreen(path: start))),
                icon: const Icon(Icons.play_arrow_rounded),
                label: Text(s.startVirtualLab),
              ),
            ),
    );
  }
}

/// Tinted banner that keeps the virtual lab honest about what it is.
class _Notice extends StatelessWidget {
  const _Notice({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: LabColors.secondary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: LabColors.secondary.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.computer_rounded, size: 20, color: LabColors.secondary),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(color: LabColors.ink, height: 1.4))),
        ],
      ),
    );
  }
}

class _ChemicalRow extends StatelessWidget {
  const _ChemicalRow({required this.item});

  final GuideMaterial item;

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            [s.ct(item.name), if (item.formula case final f?) '($f)'].join(' '),
            style: const TextStyle(fontWeight: FontWeight.w700, color: LabColors.ink, height: 1.35),
          ),
          if (item.quantity case final q?) Text(s.ct(q), style: const TextStyle(color: LabColors.muted, height: 1.4)),
          if (item.hazard case final h?)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text('⚠️ ${s.ct(h)}', style: const TextStyle(fontSize: 13, color: LabColors.amber, height: 1.4)),
            ),
        ],
      ),
    );
  }
}

class _StepTile extends StatelessWidget {
  const _StepTile({required this.number, required this.step});

  final int number;
  final GuideStep step;

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: LabColors.primarySoft,
            child: Text('$number', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: LabColors.primary)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BodyText(s.ct(step.instruction)),
                if (step.observation case final o?) _Labelled(label: s.guideExpected, text: s.ct(o), color: LabColors.teal),
                if (step.explanation case final e?) _Labelled(label: s.guideWhy, text: s.ct(e), color: LabColors.muted),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A viva question; the model answer stays hidden until the student taps,
/// so they can try answering aloud first.
class VivaTile extends StatefulWidget {
  const VivaTile({super.key, required this.number, required this.viva});

  final int number;
  final VivaQuestion viva;

  @override
  State<VivaTile> createState() => _VivaTileState();
}

class _VivaTileState extends State<VivaTile> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => setState(() => _open = !_open),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Q${widget.number}. ', style: const TextStyle(fontWeight: FontWeight.w800, color: LabColors.primary)),
                  Expanded(
                    child: Text(s.ct(widget.viva.question),
                        style: const TextStyle(fontWeight: FontWeight.w700, color: LabColors.ink, height: 1.35)),
                  ),
                  Icon(_open ? Icons.expand_less_rounded : Icons.expand_more_rounded, color: LabColors.muted),
                ],
              ),
              if (_open) _Labelled(label: context.study.vivaShowAnswer, text: s.ct(widget.viva.answer), color: LabColors.success),
            ],
          ),
        ),
      ),
    );
  }
}

class _Labelled extends StatelessWidget {
  const _Labelled({required this.label, required this.text, required this.color});

  final String label;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text.rich(
        TextSpan(children: [
          TextSpan(text: '$label: ', style: TextStyle(fontWeight: FontWeight.w800, color: color)),
          TextSpan(text: text),
        ]),
        style: const TextStyle(fontSize: 13, color: LabColors.ink, height: 1.4),
      ),
    );
  }
}

class _SyllabusLine extends StatelessWidget {
  const _SyllabusLine({required this.title, this.detail});

  final String title;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700, color: LabColors.ink, height: 1.35)),
          if (detail case final d?) Text(d, style: const TextStyle(fontSize: 13, color: LabColors.muted, height: 1.4)),
        ],
      ),
    );
  }
}
