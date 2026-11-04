import 'dart:convert';

import 'package:flutter/services.dart';

import '../sync/remote_content.dart';
import 'models/board.dart';
import 'models/syllabus.dart';

/// Loads board, syllabus and content data from `assets/content/`.
///
/// Fully data-driven: a new board or academic year is a new folder plus an
/// entry in `boards.json` — no code changes.
class ContentRepository {
  ContentRepository({AssetBundle? bundle, this.remote}) : _bundle = bundle ?? rootBundle;

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
    if (decoded is List<Object?>) return _withRemote(relativePath, [for (final e in decoded) e! as Json]);
    final file = decoded as Json;
    final hiSrc = file['hiSrc'] as String?;
    return _withRemote(relativePath, [
      for (final e in file['items']! as List<Object?>) hiSrc == null ? e! as Json : _withHiSrc(e, hiSrc) as Json,
    ]);
  }

  /// Lab Console content downloaded earlier (see `RemoteContentSync`).
  /// Reviewed items replace bundled ones with the same id; items the app
  /// does not ship yet are added once. Items the console un-publishes stay
  /// as bundled until the next app release.
  final RemoteContentCache? remote;
  final _addedRemote = <String>{};

  static String? _remoteType(String path) {
    if (path.contains('/notes/')) return 'note';
    if (path.contains('/questions/')) return 'question';
    if (path.contains('/pyq/')) return 'pyq';
    if (path.startsWith('library/concepts/')) return 'concept';
    return switch (path) {
      'library/chemicals.json' || 'library/chemicals-advanced.json' => 'chemical',
      'library/lab-reactions.json' => 'reaction',
      'library/lab-reagents.json' => 'reagent',
      'library/practical-guides.json' => 'guide',
      _ => null,
    };
  }

  List<Json> _withRemote(String path, List<Json> bundled) {
    final type = _remoteType(path);
    final cache = remote;
    if (type == null || cache == null) return bundled;
    final fromServer = cache.items(type);
    if (fromServer.isEmpty) return bundled;
    final byId = {for (final e in fromServer) e['id']! as String: e};
    final merged = [for (final e in bundled) byId[e['id']] ?? e];
    // Class-specific files (questions, notes, PYQs) only take their own class.
    final fileClass = int.tryParse(RegExp(r'class-(\d+)').firstMatch(path)?.group(1) ?? '');
    final known = {for (final e in bundled) e['id']};
    for (final e in fromServer) {
      final id = e['id']! as String;
      if (known.contains(id) || _addedRemote.contains('$type/$id')) continue;
      final cls = e['classLevel'];
      if (fileClass != null && cls != null && cls != fileClass) continue;
      if (fileClass == null && (type == 'note' || type == 'question' || type == 'pyq')) continue;
      _addedRemote.add('$type/$id');
      merged.add(e);
    }
    return merged;
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
