import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../content/content_catalog.dart';
import '../core/theme.dart';
import '../l10n/app_strings.dart';
import '../l10n/study_strings.dart';
import '../state/app_state.dart';
import '../study/personal_note.dart';
import '../study/personal_notes_store.dart';
import '../widgets/language_toggle.dart';
import '../widgets/ui_kit.dart';
import 'note_editor_screen.dart';

enum _NoteFilter { all, pinned, favourites }

/// Every personal note of the selected board in one place, with search,
/// pinned/favourite filters and a copy-paste backup.
class MyNotesScreen extends StatefulWidget {
  const MyNotesScreen({super.key});

  @override
  State<MyNotesScreen> createState() => _MyNotesScreenState();
}

class _MyNotesScreenState extends State<MyNotesScreen> {
  final _search = TextEditingController();
  _NoteFilter _filter = _NoteFilter.all;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _backup() async {
    final st = context.readStudy;
    final json = context.read<PersonalNotesStore>().exportJson();
    final messenger = ScaffoldMessenger.of(context);
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(st.backupNotes),
        content: SingleChildScrollView(child: Text(st.backupNotesBody)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(ctx.readStrings.cancel)),
          FilledButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: json));
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              messenger.showSnackBar(SnackBar(content: Text(st.backupCopied)));
            },
            icon: const Icon(Icons.copy_rounded),
            label: Text(st.copyBackup),
          ),
        ],
      ),
    );
  }

  Future<void> _restore() async {
    final st = context.readStudy;
    final controller = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(st.restoreNotes),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(st.restoreNotesBody),
              const SizedBox(height: 12),
              TextField(controller: controller, maxLines: 5, minLines: 3, decoration: const InputDecoration(border: OutlineInputBorder())),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(ctx.readStrings.cancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, controller.text), child: Text(st.restore)),
        ],
      ),
    );
    controller.dispose();
    if (text == null || text.trim().isEmpty || !mounted) return;
    String message;
    try {
      message = st.notesRestored(context.read<PersonalNotesStore>().importJson(text));
    } on FormatException {
      message = st.notABackup;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final st = context.study;
    final store = context.watch<PersonalNotesStore>();
    final boardId = context.read<AppState>().boardId!;
    final query = _search.text;
    final notes = [
      for (final n in store.search(query, boardId: boardId))
        if (_filter == _NoteFilter.all || (_filter == _NoteFilter.pinned && n.pinned) || (_filter == _NoteFilter.favourites && n.favourite)) n,
    ];
    final hasAny = store.where(boardId: boardId).isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(st.myNotes),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) => v == 'backup' ? _backup() : _restore(),
            itemBuilder: (_) => [
              PopupMenuItem(value: 'backup', child: Text(st.backupNotes)),
              PopupMenuItem(value: 'restore', child: Text(st.restoreNotes)),
            ],
          ),
          const LanguageToggle(),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          Text(st.myNotesHint, style: const TextStyle(color: LabColors.muted, height: 1.4)),
          if (store.unreadableCount > 0) ...[
            const SizedBox(height: 8),
            Text(st.unreadableNotesKept(store.unreadableCount), style: const TextStyle(fontSize: 12, color: LabColors.warning)),
          ],
          const SizedBox(height: 12),
          if (hasAny) ...[
            TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: st.searchNotes,
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: [
                for (final (f, label) in [(_NoteFilter.all, st.allNotes), (_NoteFilter.pinned, st.pinned), (_NoteFilter.favourites, st.favourites)])
                  ChoiceChip(label: Text(label), selected: _filter == f, onSelected: (_) => setState(() => _filter = f)),
              ],
            ),
            const SizedBox(height: 12),
          ],
          if (!hasAny)
            ComingSoonPanel(icon: Icons.edit_note_rounded, title: st.noNotesYet, body: st.noNotesHint)
          else if (notes.isEmpty)
            ComingSoonPanel(icon: Icons.search_off_rounded, title: query.trim().isEmpty ? st.noNotesYet : st.noNotesMatch(query.trim()), body: st.noNotesHint)
          else ...[
            Text(st.notesCount(notes.length), style: const TextStyle(color: LabColors.muted)),
            const SizedBox(height: 8),
            for (final n in notes) PersonalNoteTile(note: n, showWhere: true),
          ],
        ],
      ),
    );
  }
}

/// One personal note in a list: first line, where it belongs, pin/star.
class PersonalNoteTile extends StatelessWidget {
  const PersonalNoteTile({super.key, required this.note, this.showWhere = false});

  final PersonalNote note;
  final bool showWhere;

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    final st = context.study;
    final curriculum = context.read<ContentCatalog>().curriculum(note.boardId);
    final chapter = curriculum?.chapter(note.chapterId)?.$2;
    final topic = note.topicId == null ? null : curriculum?.topic(note.topicId!)?.topic;
    final d = note.updatedAt.toLocal();
    final date = '${d.day} ${s.monthsShort[d.month - 1]} ${d.year}';
    final where = [
      s.className(note.classLevel),
      if (chapter != null) s.ct(chapter.title),
      if (topic != null) topic.number,
    ].join(' · ');
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: IconTile(icon: note.pinned ? Icons.push_pin_rounded : Icons.sticky_note_2_outlined, color: LabColors.amber, size: 36),
        title: Text(note.headline, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, color: LabColors.ink)),
        subtitle: Text(
          [if (showWhere) where, st.editedOn(date)].join('\n'),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: note.favourite ? const Icon(Icons.star_rounded, color: LabColors.warning) : null,
        onTap: () => openNote(context, note),
      ),
    );
  }
}

/// "My notes" on a chapter or topic page: the student's notes for it and
/// an Add button. Visually separate from the checked notes above it.
class PersonalNotesSection extends StatelessWidget {
  const PersonalNotesSection({super.key, required this.boardId, required this.classLevel, required this.chapterId, this.topicId});

  final String boardId;
  final int classLevel;
  final String chapterId;
  final String? topicId;

  @override
  Widget build(BuildContext context) {
    final st = context.study;
    final notes = context.watch<PersonalNotesStore>().where(
          boardId: boardId,
          chapterId: chapterId,
          // A chapter page lists only the notes on the whole chapter.
        ).where((n) => n.topicId == topicId).toList();
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: LabColors.amber.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: LabColors.amber.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.edit_note_rounded, color: LabColors.amber),
              const SizedBox(width: 6),
              Expanded(child: Text(st.myNotes, style: AppText.display(15, color: LabColors.amber))),
              // Flexible: with a large phone font the label ellipsizes instead
              // of overflowing.
              Flexible(
                child: TextButton.icon(
                  onPressed: () => openNewNote(context, boardId: boardId, classLevel: classLevel, chapterId: chapterId, topicId: topicId),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: Text(st.addNote, maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
              ),
            ],
          ),
          if (notes.isEmpty)
            Text(st.noNotesHint, style: const TextStyle(color: LabColors.muted, height: 1.4))
          else
            for (final n in notes) PersonalNoteTile(note: n),
        ],
      ),
    );
  }
}
