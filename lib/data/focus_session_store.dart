import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/focus_session.dart';

/// On-device history of focus sessions (no network, no account).
///
/// Each session is one JSON string in a SharedPreferences string list, oldest
/// first. Unreadable entries are skipped rather than crashing the app.
class FocusSessionStore {
  FocusSessionStore(this._prefs);

  static const storageKey = 'focus_sessions';

  final SharedPreferences _prefs;

  List<FocusSession> all() {
    final sessions = <FocusSession>[];
    for (final raw in _prefs.getStringList(storageKey) ?? const <String>[]) {
      try {
        sessions.add(FocusSession.fromJson(jsonDecode(raw) as Map<String, Object?>));
      } catch (e) {
        debugPrint('Skipping unreadable focus session: $e');
      }
    }
    return sessions;
  }

  Future<void> add(FocusSession session) => _prefs.setStringList(storageKey, [
        ...?_prefs.getStringList(storageKey),
        jsonEncode(session.toJson()),
      ]);
}
