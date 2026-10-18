import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../content/content_catalog.dart';
import '../core/theme.dart';
import '../l10n/app_strings.dart';
import '../l10n/study_strings.dart';
import '../study/personal_note.dart';
import '../study/personal_notes_store.dart';
import '../widgets/language_toggle.dart';

/// Writes one personal note. Text is saved automatically a moment after
/// typing stops, and again whenever the screen is left (Back, app closed
/// to the background), so nothing typed is lost.
class NoteEditorScreen extends StatefulWidget {
  const NoteEditorScreen({super.key, required this.note});

  /// A new note from [PersonalNotesStore.create], or an existing one.
  final PersonalNote note;

  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen> with WidgetsBindingObserver {
  static const _saveDelay = Duration(milliseconds: 700);

  late final PersonalNotesStore _store = context.read<PersonalNotesStore>();
  late final TextEditingController _text = TextEditingController(text: widget.note.text);
  late PersonalNote _note = widget.note;
  Timer? _debounce;
  bool _dirty = false;
  bool _disposing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) _saveNow();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _disposing = true;
    _saveNow();
    _text.dispose();
    super.dispose();
  }

  void _onChanged(String _) {
    setState(() => _dirty = true);
    _debounce?.cancel();
    _debounce = Timer(_saveDelay, _saveNow);
  }

  void _saveNow() {
    _debounce?.cancel();
    if (!_dirty) return;
    _note = _store.save(_note, _text.text);
    _dirty = false;
    if (mounted && !_disposing) setState(() {});
  }

  Future<void> _delete() async {
    final st = context.readStudy;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(st.deleteNoteTitle),
        content: Text(st.deleteNoteBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(ctx.readStrings.cancel)),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: LabColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(st.delete),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    _debounce?.cancel();
    _dirty = false;
    _store.delete(_note.id);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    final st = context.study;
    final stored = context.watch<PersonalNotesStore>().byId(_note.id);
    final curriculum = context.read<ContentCatalog>().curriculum(_note.boardId);
    final chapter = curriculum?.chapter(_note.chapterId)?.$2;
    final topic = _note.topicId == null ? null : curriculum?.topic(_note.topicId!)?.topic;
    final where = [
      s.className(_note.classLevel),
      if (chapter != null) s.ct(chapter.title),
      if (topic != null) '${topic.number} ${s.ct(topic.title)}' else st.wholeChapter,
    ].join(' › ');

    return PopScope(
      onPopInvokedWithResult: (_, _) => _saveNow(),
      child: Scaffold(
        appBar: AppBar(
          title: Text(stored == null ? st.newNote : st.editNote),
          actions: [
            if (stored != null) ...[
              IconButton(
                tooltip: stored.pinned ? st.unpin : st.pin,
                onPressed: () => _store.togglePinned(stored.id),
                icon: Icon(stored.pinned ? Icons.push_pin_rounded : Icons.push_pin_outlined),
              ),
              IconButton(
                tooltip: stored.favourite ? st.unfavourite : st.favourite,
                onPressed: () => _store.toggleFavourite(stored.id),
                icon: Icon(stored.favourite ? Icons.star_rounded : Icons.star_outline_rounded, color: stored.favourite ? LabColors.warning : null),
              ),
              IconButton(tooltip: st.deleteNote, onPressed: _delete, icon: const Icon(Icons.delete_outline_rounded)),
            ],
            const LanguageToggle(),
          ],
        ),
        body: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(where, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: LabColors.muted, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.edit_note_rounded, size: 16, color: LabColors.muted),
                    const SizedBox(width: 4),
                    Expanded(child: Text(st.personalNoteLabel, style: const TextStyle(fontSize: 12, color: LabColors.muted))),
                    Text(
                      _dirty ? st.noteSaving : (stored == null ? '' : st.noteSaved),
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _dirty ? LabColors.muted : LabColors.success),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: TextField(
                    key: const ValueKey('note-field'),
                    controller: _text,
                    autofocus: widget.note.isBlank,
                    onChanged: _onChanged,
                    maxLines: null,
                    expands: true,
                    textAlignVertical: TextAlignVertical.top,
                    keyboardType: TextInputType.multiline,
                    textCapitalization: TextCapitalization.sentences,
                    style: const TextStyle(fontSize: 16, height: 1.5, color: LabColors.ink),
                    decoration: InputDecoration(
                      hintText: st.noteFieldHint,
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: LabColors.line)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: LabColors.line)),
                    ),
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

/// Opens the editor for a new note on a chapter or topic.
Future<void> openNewNote(BuildContext context, {required String boardId, required int classLevel, required String chapterId, String? topicId}) {
  final note = context.read<PersonalNotesStore>().create(boardId: boardId, classLevel: classLevel, chapterId: chapterId, topicId: topicId);
  return Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => NoteEditorScreen(note: note)));
}

Future<void> openNote(BuildContext context, PersonalNote note) =>
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => NoteEditorScreen(note: note)));
