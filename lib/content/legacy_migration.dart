import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/focus_session_store.dart';
import '../data/practical_attempt_store.dart';

/// Rewrites chapter/topic ids in saved progress from the draft curriculum to
/// the verified one, once. Nothing is deleted: records whose old id has no
/// equivalent keep it and still count towards time, accuracy and activity.
abstract final class LegacyProgressMigration {
  static const doneKey = 'content_ids_migrated_v1';
  static const _fields = ['chapterId', 'topicId'];

  /// Returns how many saved records were changed.
  static Future<int> run(SharedPreferences prefs, Map<String, String?> idMap) async {
    if (prefs.getBool(doneKey) ?? false) return 0;
    var changed = 0;
    for (final key in [PracticalAttemptStore.storageKey, FocusSessionStore.storageKey]) {
      final raw = prefs.getStringList(key);
      if (raw == null) continue;
      final rewritten = <String>[];
      for (final entry in raw) {
        final updated = _rewrite(entry, idMap);
        if (updated != entry) changed++;
        rewritten.add(updated);
      }
      await prefs.setStringList(key, rewritten);
    }
    await prefs.setBool(doneKey, true);
    return changed;
  }

  static String _rewrite(String entry, Map<String, String?> idMap) {
    try {
      final json = jsonDecode(entry) as Map<String, Object?>;
      var touched = false;
      for (final field in _fields) {
        final old = json[field];
        if (old is String && idMap[old] != null) {
          json[field] = idMap[old];
          touched = true;
        }
      }
      return touched ? jsonEncode(json) : entry;
    } catch (e) {
      debugPrint('Legacy migration skipped an unreadable record: $e');
      return entry; // keep unreadable records exactly as they were
    }
  }
}
