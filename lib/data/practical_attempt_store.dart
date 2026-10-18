import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/practical_attempt.dart';

/// On-device history of practical attempts (no network, no account).
///
/// Same layout as [FocusSessionStore]: one JSON string per attempt in a
/// SharedPreferences string list, oldest first; unreadable entries skipped.
class PracticalAttemptStore {
  PracticalAttemptStore(this._prefs);

  static const storageKey = 'practical_attempts';

  final SharedPreferences _prefs;

  List<PracticalAttempt> all() {
    final attempts = <PracticalAttempt>[];
    for (final raw in _prefs.getStringList(storageKey) ?? const <String>[]) {
      try {
        attempts.add(PracticalAttempt.fromJson(jsonDecode(raw) as Map<String, Object?>));
      } catch (e) {
        debugPrint('Skipping unreadable practical attempt: $e');
      }
    }
    return attempts;
  }

  Future<void> add(PracticalAttempt attempt) => _prefs.setStringList(storageKey, [
        ...?_prefs.getStringList(storageKey),
        jsonEncode(attempt.toJson()),
      ]);
}
