import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App-wide selections that outlive a single screen, remembered on the
/// device: the board and the class.
class AppState extends ChangeNotifier {
  AppState(this._prefs)
      : _boardId = _prefs.getString(boardKey),
        _selectedClass = _prefs.getInt(classKey);

  static const boardKey = 'selected_board';
  static const classKey = 'selected_class';
  static const focusKey = 'default_focus_minutes';

  final SharedPreferences _prefs;
  String? _boardId;
  int? _selectedClass;

  /// Null until the student picks a board.
  String? get boardId => _boardId;
  int? get selectedClass => _selectedClass;

  void selectBoard(String boardId) {
    if (_boardId == boardId) return;
    _boardId = boardId;
    // Class numbering and syllabus belong to a board; start fresh.
    _selectedClass = null;
    notifyListeners();
    _prefs
      ..setString(boardKey, boardId)
      ..remove(classKey);
  }

  /// Session length pre-selected in Focus Mode (10 or 15).
  int get defaultFocusMinutes => _prefs.getInt(focusKey) ?? 10;

  void setDefaultFocusMinutes(int minutes) {
    if (minutes == defaultFocusMinutes) return;
    _prefs.setInt(focusKey, minutes);
    notifyListeners();
  }

  void selectClass(int classLevel) {
    if (_selectedClass == classLevel) return;
    _selectedClass = classLevel;
    notifyListeners();
    _prefs.setInt(classKey, classLevel);
  }
}
