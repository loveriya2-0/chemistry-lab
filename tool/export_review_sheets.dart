// Exports every bilingual text of the CBSE learning content into CSV sheets
// a subject teacher can review in Excel or Google Sheets.
//
//   dart run tool/export_review_sheets.dart
//
// Writes research/cbse-2026-27/review/<kind>-class-<n>.csv (UTF-8 with BOM).
// Reviewers fill the last three columns; nothing is changed in the app.
import 'dart:convert';
import 'dart:io';

const _root = 'assets/content';
const _out = 'research/cbse-2026-27/review';

void main() {
  final manifest = _read('boards/cbse/2026-27/manifest.json') as Map<String, Object?>;
  final sheets = <String, List<List<String>>>{};

  void collect(String kind, String file) {
    final data = _read(file);
    final items = data is Map ? data['items']! as List : data as List;
    final fileHiSrc = data is Map ? data['hiSrc'] as String? : null;
    for (final raw in items) {
      final item = raw as Map<String, Object?>;
      final id = item['id']! as String;
      final level = item['classLevel'] ?? _classOf(item['targetId'] as String? ?? item['chapterId'] as String? ?? '');
      final sheet = sheets.putIfAbsent('$kind-${level == null ? 'library' : 'class-$level'}', () => []);
      final sources = [
        for (final s in (item['sources'] as List? ?? const []))
          [(s as Map)['sourceId'], if (s['section'] != null) '§${s['section']}'].join(' '),
        if ((item['source'] as Map?)?['paperUrl'] case final String url) url,
      ].join('; ');
      final status = ((item['review'] as Map?)?['status'] as String?) ?? 'draft';
      void walk(Object? node, String path) {
        if (node is Map) {
          if (node.containsKey('en')) {
            sheet.add([file, id, path, '${node['en']}', '${node['hi'] ?? ''}', '${node['hiSrc'] ?? fileHiSrc ?? ''}', sources, status, '', '', '']);
            return;
          }
          for (final e in node.entries) {
            if (e.key != 'review' && e.key != 'source') walk(e.value, path.isEmpty ? '${e.key}' : '$path.${e.key}');
          }
        } else if (node is List) {
          for (final (i, e) in node.indexed) {
            walk(e, '$path[${i + 1}]');
          }
        }
      }

      walk(item, '');
    }
  }

  for (final f in (manifest['notes'] as List? ?? const [])) {
    collect('notes', f as String);
  }
  for (final f in (manifest['questions'] as List? ?? const [])) {
    collect('questions', f as String);
  }
  for (final f in ((manifest['pyq'] as Map?)?['files'] as List? ?? const [])) {
    collect('pyqs', f as String);
  }
  for (final f in (manifest['concepts'] as List? ?? const [])) {
    collect('concepts', f as String);
  }
  for (final f in (manifest['chemicals'] as List? ?? const [])) {
    collect('chemicals', f as String);
  }

  Directory(_out).createSync(recursive: true);
  const header = ['file', 'id', 'field', 'english', 'hindi', 'hindi_source', 'sources', 'status', 'reviewer_ok (yes/no)', 'corrected_text', 'reviewer_comment'];
  for (final e in sheets.entries) {
    final csv = [header, ...e.value].map((r) => r.map(_cell).join(',')).join('\r\n');
    File('$_out/${e.key}.csv').writeAsStringSync('﻿$csv\r\n', encoding: utf8);
    stdout.writeln('${e.key}.csv  ${e.value.length} rows');
  }
}

Object? _read(String relative) => jsonDecode(File('$_root/$relative').readAsStringSync());

int? _classOf(String id) => int.tryParse(RegExp(r'^cbse-(\d+)-').firstMatch(id)?.group(1) ?? '');

String _cell(String v) => '"${v.replaceAll('"', '""')}"';
