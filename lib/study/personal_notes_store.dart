import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'personal_note.dart';

/// The student's own notes, kept on this device only (no account, no
/// cloud). Same layout as the other stores: one JSON string per note in a
/// SharedPreferences string list.
///
/// Notes are the student's work, so this store never throws one away:
/// an entry it cannot read (e.g. written by a newer app version) is kept
/// byte-for-byte and written back on every save. "Reset progress" does not
/// touch notes.
class PersonalNotesStore extends ChangeNotifier {
  PersonalNotesStore(this._prefs, {DateTime Function()? clock}) : _clock = clock ?? DateTime.now {
    for (final raw in _prefs.getStringList(storageKey) ?? const <String>[]) {
      try {
        final n = PersonalNote.fromJson(jsonDecode(raw) as Map<String, Object?>);
        _notes[n.id] = n;
      } catch (e) {
        debugPrint('Keeping unreadable personal note as-is: $e');
        _unreadable.add(raw);
      }
    }
  }

  static const storageKey = 'personal_notes';

  final SharedPreferences _prefs;
  final DateTime Function() _clock;
  final _notes = <String, PersonalNote>{};
  final _unreadable = <String>[];
  int _seq = 0;

  /// Every note, pinned first, then most recently edited.
  List<PersonalNote> get all => _sorted(_notes.values);

  int get unreadableCount => _unreadable.length;

  PersonalNote? byId(String id) => _notes[id];

  /// Notes of one board, optionally narrowed to a class, chapter or topic.
  List<PersonalNote> where({required String boardId, int? classLevel, String? chapterId, String? topicId}) => _sorted(
        _notes.values.where((n) =>
            n.boardId == boardId &&
            (classLevel == null || n.classLevel == classLevel) &&
            (chapterId == null || n.chapterId == chapterId) &&
            (topicId == null || n.topicId == topicId)),
      );

  /// Notes whose text contains [query] (any case, any script).
  List<PersonalNote> search(String query, {required String boardId}) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return where(boardId: boardId);
    return [for (final n in where(boardId: boardId)) if (n.text.toLowerCase().contains(q)) n];
  }

  /// Starts a note. Blank notes are not saved until they get some text.
  PersonalNote create({required String boardId, required int classLevel, required String chapterId, String? topicId, String text = ''}) {
    final now = _clock();
    final note = PersonalNote(
      id: '${now.microsecondsSinceEpoch}-${_seq++}',
      boardId: boardId,
      classLevel: classLevel,
      chapterId: chapterId,
      topicId: topicId,
      text: text,
      createdAt: now,
      updatedAt: now,
    );
    if (!note.isBlank) {
      _notes[note.id] = note;
      _persist();
    }
    return note;
  }

  /// Saves [note] with new [text]. Saving blank text deletes the note
  /// (an emptied note is not kept as clutter).
  PersonalNote save(PersonalNote note, String text) {
    final existing = _notes[note.id];
    if (text.trim().isEmpty) {
      if (existing != null) delete(note.id);
      return note.copyWith(text: text);
    }
    if (existing != null && existing.text == text) return existing;
    final updated = (existing ?? note).copyWith(text: text, updatedAt: _clock());
    _notes[note.id] = updated;
    _persist();
    return updated;
  }

  void togglePinned(String id) => _update(id, (n) => n.copyWith(pinned: !n.pinned));
  void toggleFavourite(String id) => _update(id, (n) => n.copyWith(favourite: !n.favourite));

  void delete(String id) {
    if (_notes.remove(id) == null) return;
    _persist();
  }

  /// A backup of every note (including any this version cannot read) as
  /// JSON text the student can copy somewhere safe.
  String exportJson() => const JsonEncoder.withIndent('  ').convert({
        'app': 'virtual_chemistry_lab',
        'kind': 'personal_notes',
        'version': PersonalNote.schemaVersion,
        'exportedAt': _clock().toIso8601String(),
        'notes': [for (final n in all) n.toJson()],
        if (_unreadable.isNotEmpty) 'unreadable': _unreadable,
      });

  /// Merges a backup made by [exportJson]. Never deletes: a note already
  /// on the device is replaced only by a newer copy of itself. Returns
  /// how many notes were added or updated. Throws [FormatException] for
  /// text that is not such a backup.
  int importJson(String text) {
    final Object? decoded;
    try {
      decoded = jsonDecode(text);
    } on FormatException {
      throw const FormatException('Not a notes backup');
    }
    if (decoded is! Map<String, Object?> || decoded['kind'] != 'personal_notes' || decoded['notes'] is! List) {
      throw const FormatException('Not a notes backup');
    }
    var changed = 0;
    for (final e in decoded['notes']! as List<Object?>) {
      try {
        final n = PersonalNote.fromJson(e! as Map<String, Object?>);
        final mine = _notes[n.id];
        if (n.isBlank || (mine != null && !n.updatedAt.isAfter(mine.updatedAt))) continue;
        _notes[n.id] = n;
        changed++;
      } catch (_) {
        // A damaged entry in the backup is skipped; the rest still import.
      }
    }
    if (changed > 0) _persist();
    return changed;
  }

  void _update(String id, PersonalNote Function(PersonalNote) change) {
    final n = _notes[id];
    if (n == null) return;
    _notes[id] = change(n);
    _persist();
  }

  void _persist() {
    notifyListeners();
    _prefs.setStringList(storageKey, [
      for (final n in _notes.values) jsonEncode(n.toJson()),
      ..._unreadable,
    ]);
  }

  static List<PersonalNote> _sorted(Iterable<PersonalNote> notes) => notes.toList()
    ..sort((a, b) {
      if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
      return b.updatedAt.compareTo(a.updatedAt);
    });
}
