import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Topics and labs the student saved for revision, kept on this device.
///
/// Keys: `topic:<topicId>` and `lab:<topicId>:<labId>` (a lab is saved where
/// it is offered, so it can be reopened with its syllabus context),
/// `pyq:<id>`, `question:<practiceQuestionId>` and
/// `formula:<noteId>|<formula>` (a formula is saved with the note it is in).
class BookmarkStore extends ChangeNotifier {
  BookmarkStore(this._prefs) : _keys = {...?_prefs.getStringList(storageKey)};

  static const storageKey = 'bookmarks';

  final SharedPreferences _prefs;
  final Set<String> _keys;

  static String topicKey(String topicId) => 'topic:$topicId';
  static String labKey(String topicId, String labId) => 'lab:$topicId:$labId';
  static String questionKey(String questionId) => 'question:$questionId';
  static String formulaKey(String noteId, String formula) => 'formula:$noteId|$formula';

  bool contains(String key) => _keys.contains(key);

  void toggle(String key) {
    _keys.contains(key) ? _keys.remove(key) : _keys.add(key);
    notifyListeners();
    _prefs.setStringList(storageKey, _keys.toList());
  }

  /// Saved topic ids, most recent last.
  List<String> get topicIds => [for (final k in _keys) if (k.startsWith('topic:')) k.substring(6)];

  /// Saved (topicId, labId) pairs.
  List<(String, String)> get labs => [
        for (final k in _keys)
          if (k.startsWith('lab:')) (k.split(':')[1], k.split(':')[2]),
      ];

  /// Saved practice-question ids.
  List<String> get questionIds => [for (final k in _keys) if (k.startsWith('question:')) k.substring(9)];

  /// Saved (noteId, formula) pairs.
  List<(String, String)> get formulas => [
        for (final k in _keys)
          if (k.startsWith('formula:') && k.contains('|')) (k.substring(8, k.indexOf('|')), k.substring(k.indexOf('|') + 1)),
      ];

  void clear() {
    _keys.clear();
    notifyListeners();
    _prefs.remove(storageKey);
  }
}
