import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../content/content_catalog.dart';
import '../content/models/syllabus.dart';
import '../core/theme.dart';
import '../data/practicals_repository.dart';
import '../l10n/app_strings.dart';
import '../l10n/study_strings.dart';
import '../study/personal_notes_store.dart';
import '../state/app_state.dart';
import '../widgets/ui_kit.dart';
import 'note_editor_screen.dart';
import 'practical_guide_screen.dart';
import 'question_bank_screen.dart';
import 'topic_detail_screen.dart';
import 'topic_list_screen.dart';

enum _Kind { chapter, topic, lab, question, formula, note }

class _Hit {
  const _Hit(this.kind, this.title, this.where, this.open);

  final _Kind kind;
  final String title;
  final String where;
  final void Function(BuildContext) open;
}

/// Searches the verified syllabus (chapters, topics, sub-topics), the
/// interactive labs, practice questions, formulas in the notes and the
/// student's own notes, matching English and Hindi alike.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  static const recentKey = 'recent_searches';

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  String _query = '';
  _Kind? _filter;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<String> get _recent => context.read<SharedPreferences>().getStringList(SearchScreen.recentKey) ?? const [];

  void _remember(String q) {
    final q2 = q.trim();
    if (q2.isEmpty) return;
    final list = [q2, ..._recent.where((r) => r != q2)].take(6).toList();
    context.read<SharedPreferences>().setStringList(SearchScreen.recentKey, list);
  }

  List<_Hit> _search(String raw) {
    final q = raw.trim().toLowerCase();
    if (q.isEmpty) return const [];
    final s = context.readStrings;
    final curriculum = context.read<ContentCatalog>().curriculum(context.read<AppState>().boardId!)!;
    final labs = context.read<PracticalsRepository>();
    bool match(String en, String? hi) => en.toLowerCase().contains(q) || (hi?.toLowerCase().contains(q) ?? false);

    final hits = <_Hit>[];
    for (final c in curriculum.classLevels) {
      final syllabus = curriculum.classes[c]!;
      for (final ch in syllabus.chapters) {
        final chWhere = s.className(c);
        if (match(ch.title.en, ch.title.hi)) {
          hits.add(_Hit(_Kind.chapter, s.ct(ch.title), chWhere, _push((_) => TopicListScreen(syllabus: syllabus, chapter: ch))));
        }
        for (final t in ch.topics) {
          for (final x in t.selfAndDescendants) {
            if (match(x.title.en, x.title.hi)) {
              hits.add(_Hit(
                _Kind.topic,
                s.ct(x.title),
                '$chWhere · ${s.ct(ch.title)} · ${x.number}',
                _push((_) => TopicDetailScreen(syllabus: syllabus, chapter: ch, topic: _topLevel(ch, x))),
              ));
            }
          }
        }
      }
      for (final p in curriculum.labsForClass(c)) {
        final lab = labs.byId(p.labId);
        if (match(lab.title.en, lab.title.hi)) {
          hits.add(_Hit(_Kind.lab, s.tr(lab.title), s.focusBreadcrumb(c, p.location.chapter.number, p.location.topic.number),
              (ctx) => curriculum.guideFor(p.labId) == null
                  ? openLabsForTopic(ctx, syllabus: p.location.syllabus, chapter: p.location.chapter, topic: p.location.topic)
                  : openPracticalGuide(ctx, labId: p.labId, classLevel: c, topicId: p.location.topic.id)));
        }
      }
      // Labs that sit on no topic at all, only on a listed practical
      // (labs with a topic are found through it above).
      for (final p in curriculum.classes[c]!.practicals) {
        for (final l in curriculum.labLinksForPractical(p)) {
          if (curriculum.placementsOf(l.labId).isNotEmpty || curriculum.guideFor(l.labId) == null) continue;
          final lab = labs.byId(l.labId);
          if (match(lab.title.en, lab.title.hi)) {
            hits.add(_Hit(_Kind.lab, s.tr(lab.title), s.practicalBreadcrumb(c, p.number),
                (ctx) => openPracticalGuide(ctx, labId: l.labId, classLevel: c, listedPracticalId: p.id)));
          }
        }
      }

    }
    final st = context.readStudy;
    String where(String targetId) => switch (curriculum.topic(targetId)) {
          final loc? => s.focusBreadcrumb(loc.syllabus.classLevel, loc.chapter.number, loc.topic.number),
          null => switch (curriculum.chapter(targetId)) {
              final c? => '${s.className(c.$1.classLevel)} · ${s.ct(c.$2.title)}',
              null => '',
            },
        };
    for (final question in curriculum.questions) {
      if (!question.review.isPublishable) continue;
      if (match(question.question.en, question.question.hi)) {
        hits.add(_Hit(_Kind.question, s.ct(question.question), where(question.topicId),
            _push((_) => QuestionBankScreen(classLevel: question.classLevel, title: st.questionsGroup, questions: [question]))));
      }
    }
    final seenFormulas = <String>{};
    for (final n in curriculum.notes) {
      if (!n.review.isPublishable) continue;
      for (final f in n.formulas) {
        if (f.toLowerCase().contains(q) && seenFormulas.add('${n.targetId}|$f')) {
          final loc = curriculum.topic(n.targetId);
          hits.add(_Hit(_Kind.formula, f, where(n.targetId), loc == null
              ? _push((_) => TopicListScreen(syllabus: curriculum.chapter(n.targetId)!.$1, chapter: curriculum.chapter(n.targetId)!.$2))
              : _push((_) => TopicDetailScreen(syllabus: loc.syllabus, chapter: loc.chapter, topic: loc.topic))));
        }
      }
    }
    final board = context.read<AppState>().boardId!;
    for (final n in context.read<PersonalNotesStore>().search(q, boardId: board)) {
      hits.add(_Hit(_Kind.note, n.headline, '${st.personalNoteLabel} · ${where(n.topicId ?? n.chapterId)}', (ctx) => openNote(ctx, n)));
    }
    return hits;
  }

  static Topic _topLevel(Chapter ch, Topic t) => ch.topics.firstWhere((top) => top.selfAndDescendants.contains(t));

  static void Function(BuildContext) _push(WidgetBuilder builder) =>
      (ctx) => Navigator.of(ctx).push(MaterialPageRoute(builder: builder));

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    final all = _search(_query);
    final hits = _filter == null ? all : all.where((h) => h.kind == _filter).toList();
    final recent = _recent;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: TextField(
          controller: _controller,
          autofocus: true,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: s.searchHint,
            border: InputBorder.none,
            suffixIcon: _query.isEmpty
                ? null
                : IconButton(
                    tooltip: s.clear,
                    onPressed: () => setState(() {
                      _controller.clear();
                      _query = '';
                    }),
                    icon: const Icon(Icons.close_rounded),
                  ),
          ),
          onChanged: (v) => setState(() => _query = v),
          onSubmitted: _remember,
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          if (_query.trim().isEmpty) ...[
            if (recent.isNotEmpty) ...[
              SectionHeader(
                s.recentSearches,
                trailing: TextButton(
                  onPressed: () => setState(() => context.read<SharedPreferences>().remove(SearchScreen.recentKey)),
                  child: Text(s.clear),
                ),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  for (final r in recent)
                    ActionChip(
                      avatar: const Icon(Icons.history_rounded, size: 16),
                      label: Text(r),
                      onPressed: () => setState(() {
                        _controller.text = r;
                        _query = r;
                      }),
                    ),
                ],
              ),
              const SizedBox(height: 16),
            ],
            Text(s.searchBothLanguages, style: const TextStyle(color: LabColors.muted)),
          ] else ...[
            Wrap(
              spacing: 8,
              children: [
                for (final (k, label) in [
                  (null, s.allFilter),
                  (_Kind.chapter, s.chaptersGroup),
                  (_Kind.topic, s.topicsGroup),
                  (_Kind.lab, s.labsTab),
                  (_Kind.question, context.study.questionsGroup),
                  (_Kind.formula, context.study.formulasGroup),
                  (_Kind.note, context.study.notesGroup),
                ])
                  ChoiceChip(label: Text(label), selected: _filter == k, onSelected: (_) => setState(() => _filter = k)),
              ],
            ),
            const SizedBox(height: 12),
            if (hits.isEmpty)
              ComingSoonPanel(icon: Icons.search_off_rounded, title: s.noResults(_query.trim()), body: s.searchBothLanguages)
            else
              for (final h in hits.take(60))
                Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: IconTile(
                      icon: switch (h.kind) {
                        _Kind.chapter => Icons.menu_book_rounded,
                        _Kind.topic => Icons.topic_rounded,
                        _Kind.lab => Icons.science_rounded,
                        _Kind.question => Icons.quiz_rounded,
                        _Kind.formula => Icons.functions_rounded,
                        _Kind.note => Icons.edit_note_rounded,
                      },
                      color: switch (h.kind) {
                        _Kind.chapter => LabColors.primary,
                        _Kind.topic => LabColors.teal,
                        _Kind.lab => LabColors.amber,
                        _Kind.question => LabColors.secondary,
                        _Kind.formula => LabColors.primary,
                        _Kind.note => LabColors.amber,
                      },
                      size: 36,
                    ),
                    title: Text(h.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text(h.where, maxLines: 1, overflow: TextOverflow.ellipsis),
                    onTap: () {
                      _remember(_query);
                      h.open(context);
                    },
                  ),
                ),
          ],
        ],
      ),
    );
  }
}
