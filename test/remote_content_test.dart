import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:virtual_chemistry_lab/content/content_repository.dart';
import 'package:virtual_chemistry_lab/sync/remote_content.dart';

Map<String, Object?> _q(String id, int cls, String text) => {
      'id': id,
      'classLevel': cls,
      'question': {'en': text, 'hi': 'हिन्दी'},
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<RemoteContentCache> cacheWith(Map<String, Object?> stored) async {
    SharedPreferences.setMockInitialValues(stored.map((k, v) => MapEntry(k, v is String ? v : jsonEncode(v))));
    return RemoteContentCache(await SharedPreferences.getInstance());
  }

  test('without a cache the bundled content is untouched', () async {
    final bundled = await ContentRepository().jsonList('boards/cbse/2026-27/questions/class-10.json');
    final cache = await cacheWith({});
    final same = await ContentRepository(remote: cache).jsonList('boards/cbse/2026-27/questions/class-10.json');
    expect(same.length, bundled.length);
  });

  test('console edits replace bundled items and new ones are added once, to the right class', () async {
    const path = 'boards/cbse/2026-27/questions/class-10.json';
    final bundled = await ContentRepository().jsonList(path);
    final firstId = bundled.first['id']! as String;
    final cache = await cacheWith({
      'remote_content_question': {
        'items': [_q(firstId, 10, 'Edited in console'), _q('q-new-10', 10, 'New class 10'), _q('q-new-12', 12, 'New class 12')],
        'hiSrc': {'q-new-10': 'translated'},
      },
    });
    final repo = ContentRepository(remote: cache);
    final merged = await repo.jsonList(path);

    expect(merged.length, bundled.length + 1);
    expect((merged.first['question']! as Map)['en'], 'Edited in console');
    final added = merged.last;
    expect(added['id'], 'q-new-10');
    expect((added['question']! as Map)['hiSrc'], 'translated');
    expect(merged.any((e) => e['id'] == 'q-new-12'), isFalse);

    // Loading another file must not add the same item again.
    final class12 = await repo.jsonList('boards/cbse/2026-27/questions/class-12.json');
    expect(class12.where((e) => e['id'] == 'q-new-10'), isEmpty);
    expect(class12.where((e) => e['id'] == 'q-new-12'), hasLength(1));
  });

  test('a corrupt cache falls back to bundled content', () async {
    final bundled = await ContentRepository().jsonList('library/lab-reagents.json');
    final cache = await cacheWith({'remote_content_reagent': '{not json'});
    final merged = await ContentRepository(remote: cache).jsonList('library/lab-reagents.json');
    expect(merged.length, bundled.length);
  });

  test('refresh stores content, tolerates failures, and is off without a URL', () async {
    final cache = await cacheWith({});
    final calls = <String>[];
    final client = MockClient((req) async {
      calls.add(req.url.path);
      if (req.url.path.endsWith('/content/note')) {
        return http.Response(jsonEncode({'items': [_q('n1', 10, 'x')], 'hiSrc': {}}), 200,
            headers: {'content-type': 'application/json; charset=utf-8'});
      }
      if (req.url.path.endsWith('/content/pyq')) throw http.ClientException('offline');
      return http.Response('boom', 500);
    });

    final off = RemoteContentSync(config: const RemoteContentConfig(''), cache: cache, client: client);
    expect(await off.refresh(), 0);
    expect(calls, isEmpty);

    final sync = RemoteContentSync(config: const RemoteContentConfig('https://api.test/'), cache: cache, client: client);
    expect(await sync.refresh(), 1);
    expect(calls, contains('/api/v1/public/content/note'));
    expect(cache.items('note').single['id'], 'n1');
    expect(cache.items('pyq'), isEmpty);
  });
}
