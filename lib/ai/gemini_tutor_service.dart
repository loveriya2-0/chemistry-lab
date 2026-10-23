import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../l10n/app_language.dart';
import 'tutor_context.dart';
import 'tutor_prompt.dart';
import 'tutor_service.dart';

/// Where the Gemini tutor connects, supplied at build time — never in source:
///
///   flutter run --dart-define=GEMINI_PROXY_URL=https://your-server/tutor
///   flutter run --dart-define=GEMINI_API_KEY=...   (local testing only)
///
/// A key passed with --dart-define is compiled into the app, so release
/// builds should use the proxy, which keeps the key on the server.
@immutable
class GeminiConfig {
  const GeminiConfig({this.apiKey = '', this.proxyUrl = '', this.model = defaultModel});

  factory GeminiConfig.fromEnvironment() => const GeminiConfig(
        apiKey: String.fromEnvironment('GEMINI_API_KEY'),
        proxyUrl: String.fromEnvironment('GEMINI_PROXY_URL'),
        model: String.fromEnvironment('GEMINI_MODEL', defaultValue: defaultModel),
      );

  static const defaultModel = 'gemini-3.8-flash';

  final String apiKey;
  final String proxyUrl;
  final String model;

  bool get usesProxy => proxyUrl.isNotEmpty;
  bool get isConfigured => usesProxy || apiKey.isNotEmpty;
}

/// Gemini API `generateContent` over HTTPS.
///
/// With a proxy URL the request body is posted there unchanged and the
/// proxy adds the API key and model; otherwise it goes straight to Google.
class GeminiTutorService implements TutorService {
  GeminiTutorService(this.config, {http.Client? client, this.timeout = const Duration(seconds: 90)})
      : _client = client ?? http.Client();

  final GeminiConfig config;
  final Duration timeout;
  final http.Client _client;

  @override
  bool get isConfigured => config.isConfigured;

  Uri get endpoint => config.usesProxy
      ? Uri.parse(config.proxyUrl)
      : Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/${config.model}:generateContent');

  /// The `generateContent` request body for [conversation].
  Map<String, Object?> requestBody(TutorContext context, AppLanguage language, List<TutorMessage> conversation) => {
        'systemInstruction': {
          'parts': [
            {'text': TutorPrompt.system(context, language)},
          ],
        },
        'contents': [
          for (final m in conversation)
            {
              'role': m.role == TutorRole.student ? 'user' : 'model',
              'parts': [
                {'text': m.text},
              ],
            },
        ],
        // Room for the model's thinking as well as a 150–250 word answer.
        'generationConfig': {'maxOutputTokens': 8192},
      };

  @override
  Future<TutorReply> reply({
    required TutorContext context,
    required AppLanguage language,
    required List<TutorMessage> conversation,
  }) async {
    if (!isConfigured) throw const TutorException(TutorFailure.notConfigured);
    final http.Response response;
    try {
      response = await _client
          .post(
            endpoint,
            headers: {
              'content-type': 'application/json',
              if (!config.usesProxy) 'x-goog-api-key': config.apiKey,
            },
            body: jsonEncode(requestBody(context, language, conversation)),
          )
          .timeout(timeout);
    } on TimeoutException {
      throw const TutorException(TutorFailure.network, 'timeout');
    } on http.ClientException catch (e) {
      throw TutorException(TutorFailure.network, e.message);
    }
    return parse(response.statusCode, utf8.decode(response.bodyBytes));
  }

  /// Finish reasons that mean Gemini declined to answer.
  static const _blocked = {'SAFETY', 'RECITATION', 'BLOCKLIST', 'PROHIBITED_CONTENT', 'SPII', 'IMAGE_SAFETY'};

  /// Turns an HTTP response into a reply or a [TutorException].
  static TutorReply parse(int status, String body) {
    switch (status) {
      case 200:
        break;
      // Gemini reports a wrong key as 400 API_KEY_INVALID, not 401.
      case 400 when body.contains('API_KEY_INVALID'):
        throw TutorException(TutorFailure.auth, body);
      case 401 || 403:
        throw TutorException(TutorFailure.auth, body);
      case 429:
        throw TutorException(TutorFailure.rateLimited, body);
      case 500 || 502 || 503 || 504:
        throw TutorException(TutorFailure.busy, body);
      default:
        throw TutorException(TutorFailure.badResponse, 'HTTP $status: $body');
    }
    final Map<String, Object?> json;
    try {
      json = jsonDecode(body) as Map<String, Object?>;
    } on FormatException {
      throw TutorException(TutorFailure.badResponse, body);
    }
    // A blocked prompt arrives as HTTP 200 with no candidates.
    if (json['promptFeedback'] case {'blockReason': final String _}) throw const TutorException(TutorFailure.refused);
    final candidate = switch (json['candidates']) {
      [final Map<String, Object?> c, ...] => c,
      _ => const <String, Object?>{},
    };
    final finish = candidate['finishReason'] as String?;
    final text = [
      if (candidate['content'] case {'parts': final List<Object?> parts})
        for (final p in parts)
          // Skip thought summaries; only the answer is shown.
          if (p case final Map<String, Object?> m when m['text'] is String && m['thought'] != true) m['text']! as String,
    ].join().trim();
    if (text.isEmpty && _blocked.contains(finish)) throw const TutorException(TutorFailure.refused);
    if (text.isEmpty) throw TutorException(TutorFailure.badResponse, 'no text (finishReason $finish)');
    return TutorReply(text, truncated: finish == 'MAX_TOKENS');
  }
}

/// The tutor the app uses: Gemini when it is configured at build time,
/// otherwise Claude (which reports "not set up" if neither is).
TutorService tutorFromEnvironment() {
  final gemini = GeminiConfig.fromEnvironment();
  if (gemini.isConfigured) return GeminiTutorService(gemini);
  return ClaudeTutorService(TutorConfig.fromEnvironment());
}
