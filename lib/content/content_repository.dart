import 'dart:convert';

import 'package:flutter/services.dart';

import 'models/board.dart';
import 'models/syllabus.dart';

/// Loads board, syllabus and content data from `assets/content/`.
///
/// Fully data-driven: a new board or academic year is a new folder plus an
/// entry in `boards.json` — no code changes.
class ContentRepository {
  ContentRepository({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  static const root = 'assets/content';

  final AssetBundle _bundle;
  BoardRegistry? _registry;
  final _manifests = <String, CurriculumManifest>{};
  final _classes = <String, ClassSyllabus>{};

  Future<Json> _json(String relativePath) async =>
      jsonDecode(await _bundle.loadString('$root/$relativePath')) as Json;

  /// A content file holding a list of objects (notes, concepts, PYQs…).
  ///
  /// Either a bare JSON list, or `{"hiSrc": …, "items": […]}` where `hiSrc`
  /// is the default provenance for every bilingual text in the file.
  Future<List<Json>> jsonList(String relativePath) async {
    final decoded = jsonDecode(await _bundle.loadString('$root/$relativePath'));
    if (decoded is List<Object?>) return [for (final e in decoded) e! as Json];
    final file = decoded as Json;
    final hiSrc = file['hiSrc'] as String?;
    return [
      for (final e in file['items']! as List<Object?>) hiSrc == null ? e! as Json : _withHiSrc(e, hiSrc) as Json,
    ];
  }

  /// Fills in [hiSrc] on every `{en, hi}` text that does not set its own.
  static Object? _withHiSrc(Object? node, String hiSrc) => switch (node) {
        final Json m => {
            for (final e in m.entries) e.key: _withHiSrc(e.value, hiSrc),
            if (m.containsKey('en') && m.containsKey('hi') && !m.containsKey('hiSrc')) 'hiSrc': hiSrc,
          },
        final List<Object?> l => [for (final e in l) _withHiSrc(e, hiSrc)],
        _ => node,
      };

  Future<BoardRegistry> boards() async =>
      _registry ??= BoardRegistry.fromJson(await _json('boards.json'));

  /// Syllabus index for [boardId] in [academicYear] (latest if omitted).
  /// Throws [StateError] for a board that has no syllabus yet.
  Future<CurriculumManifest> curriculum(String boardId, {String? academicYear}) async {
    final board = (await boards()).byId(boardId);
    if (board == null) throw StateError('Unknown board "$boardId"');
    final ref = academicYear == null
        ? board.latestCurriculum
        : board.curricula.where((c) => c.academicYear == academicYear).firstOrNull;
    if (ref == null) {
      throw StateError('No syllabus for board "$boardId"${academicYear == null ? '' : ' in $academicYear'}');
    }
    return _manifests[ref.manifestPath] ??= CurriculumManifest.fromJson(await _json(ref.manifestPath));
  }

  Future<ClassSyllabus> classSyllabus(String boardId, int classLevel, {String? academicYear}) async {
    final manifest = await curriculum(boardId, academicYear: academicYear);
    final ref = manifest.classes.where((c) => c.classLevel == classLevel).firstOrNull;
    if (ref == null) {
      throw StateError('Board "$boardId" ${manifest.academicYear} has no Class $classLevel');
    }
    return _classes[ref.path] ??= ClassSyllabus.fromJson(await _json(ref.path));
  }

  /// Every class of one curriculum, in class order.
  Future<List<ClassSyllabus>> allClasses(String boardId, {String? academicYear}) async {
    final manifest = await curriculum(boardId, academicYear: academicYear);
    return [
      for (final c in manifest.classLevels..sort())
        await classSyllabus(boardId, c, academicYear: manifest.academicYear),
    ];
  }
}
