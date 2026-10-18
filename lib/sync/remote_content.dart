import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../content/models/syllabus.dart';

/// Where the Lab Console API lives, set at build time:
/// `--dart-define=CONTENT_API_URL=https://api.example.com`. Empty disables
/// remote content and the app uses only what is bundled.
class RemoteContentConfig {
  const RemoteContentConfig(this.baseUrl);

  factory RemoteContentConfig.fromEnvironment() =>
      const RemoteContentConfig(String.fromEnvironment('CONTENT_API_URL'));

  final String baseUrl;
  bool get enabled => baseUrl.isNotEmpty;
  Uri uri(String path) => Uri.parse('${baseUrl.replaceAll(RegExp(r'/+$'), '')}/api/v1/public/$path');
}

/// Content types the console can edit and the app can receive.
const remoteContentTypes = ['note', 'question', 'pyq', 'concept', 'chemical', 'reaction', 'reagent', 'guide'];

/// Last downloaded console content, kept in SharedPreferences so the app
/// works offline and starts without waiting for the network.
class RemoteContentCache {
  RemoteContentCache(this._prefs);

  final SharedPreferences _prefs;

  static String _key(String type) => 'remote_content_$type';

  /// Items of [type] with their Hindi provenance already applied.
  List<Json> items(String type) {
    final raw = _prefs.getString(_key(type));
    if (raw == null) return const [];
    try {
      final body = jsonDecode(raw) as Json;
      final hiSrc = (body['hiSrc'] as Map?)?.cast<String, String>() ?? const {};
      return [
        for (final e in body['items']! as List<Object?>)
          withHiSrc(e, hiSrc[(e! as Json)['id']]) as Json,
      ];
    } catch (_) {
      return const []; // corrupt cache: fall back to bundled content
    }
  }

  Future<void> save(String type, Json body) => _prefs.setString(_key(type), jsonEncode(body));

  /// Fills in [hiSrc] on every `{en, hi}` text that does not set its own.
  static Object? withHiSrc(Object? node, String? hiSrc) {
    if (hiSrc == null) return node;
    return switch (node) {
      final Json m => {
          for (final e in m.entries) e.key: withHiSrc(e.value, hiSrc),
          if (m.containsKey('en') && m.containsKey('hi') && !m.containsKey('hiSrc')) 'hiSrc': hiSrc,
        },
      final List<Object?> l => [for (final e in l) withHiSrc(e, hiSrc)],
      _ => node,
    };
  }
}

/// Downloads reviewed content and config from the Lab Console API.
/// Never throws: the app keeps working with bundled or cached content.
class RemoteContentSync {
  RemoteContentSync({required this.config, required this.cache, http.Client? client}) : _client = client ?? http.Client();

  final RemoteContentConfig config;
  final RemoteContentCache cache;
  final http.Client _client;

  /// Returns how many content types were refreshed. New content is used the
  /// next time the app starts, so a screen never changes under the reader.
  Future<int> refresh() async {
    if (!config.enabled) return 0;
    var updated = 0;
    for (final type in remoteContentTypes) {
      try {
        final res = await _client.get(config.uri('content/$type')).timeout(const Duration(seconds: 15));
        if (res.statusCode != 200) continue;
        final body = jsonDecode(utf8.decode(res.bodyBytes)) as Json;
        if (body['items'] is! List<Object?>) continue;
        await cache.save(type, body);
        updated++;
      } catch (_) {
        // offline or server down: keep what we have
      }
    }
    return updated;
  }

  /// Anonymous install ping used for the console's user counts.
  Future<void> reportInstall({required String installId, String? boardId, int? classLevel, String? language, String? appVersion, bool? premium}) async {
    if (!config.enabled) return;
    try {
      await _client
          .post(
            config.uri('install'),
            headers: {'content-type': 'application/json'},
            body: jsonEncode({
              'installId': installId,
              'boardId': ?boardId,
              'classLevel': ?classLevel,
              'language': ?language,
              'appVersion': ?appVersion,
              'premium': ?premium,
              'platform': 'android',
            }),
          )
          .timeout(const Duration(seconds: 10));
    } catch (_) {}
  }
}
