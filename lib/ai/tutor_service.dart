import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../l10n/app_language.dart';
import 'tutor_context.dart';
import 'tutor_prompt.dart';

enum TutorRole { student, tutor }

@immutable
class TutorMessage {
  const TutorMessage(this.role, this.text);

  final TutorRole role;
  final String text;
}

@immutable
class TutorReply {
  const TutorReply(this.text, {this.truncated = false});

  final String text;

  /// The answer hit the length limit and stops mid-way.
  final bool truncated;
}

enum TutorFailure { notConfigured, network, auth, rateLimited, busy, refused, badResponse }

class TutorException implements Exception {
  const TutorException(this.failure, [this.detail]);

  final TutorFailure failure;
  final String? detail;

  @override
  String toString() => 'TutorException(${failure.name}${detail == null ? '' : ': $detail'})';
}

/// Answers a student's questions about what they are studying.
abstract class TutorService {
  bool get isConfigured;

  /// The tutor's reply to the last student message in [conversation].
  Future<TutorReply> reply({
    required TutorContext context,
    required AppLanguage language,
    required List<TutorMessage> conversation,
  });
}

/// Where the tutor connects, supplied at build time — never in source:
///
///   flutter run --dart-define=AI_TUTOR_PROXY_URL=https://your-server/tutor
///   flutter run --dart-define=ANTHROPIC_API_KEY=...   (local testing only)
///
/// A key passed with --dart-define is compiled into the app, so release
/// builds should use the proxy, which keeps the key on the server.
@immutable
class TutorConfig {
  const TutorConfig({this.apiKey = '', this.proxyUrl = '', this.model = defaultModel, this.effort = defaultEffort});

  factory TutorConfig.fromEnvironment() => const TutorConfig(
        apiKey: String.fromEnvironment('ANTHROPIC_API_KEY'),
        proxyUrl: String.fromEnvironment('AI_TUTOR_PROXY_URL'),
        model: String.fromEnvironment('AI_TUTOR_MODEL', defaultValue: defaultModel),
        effort: String.fromEnvironment('AI_TUTOR_EFFORT', defaultValue: defaultEffort),
      );

  static const defaultModel = 'claude-opus-5';

  /// Medium keeps chat replies quick on a phone; raise it with
  /// AI_TUTOR_EFFORT=high if answers need more depth.
  static const defaultEffort = 'medium';

  final String apiKey;
  final String proxyUrl;
  final String model;
  final String effort;

  bool get usesProxy => proxyUrl.isNotEmpty;
  bool get isConfigured => usesProxy || apiKey.isNotEmpty;
}

/// Claude Messages API over HTTPS (there is no official Dart SDK).
///
/// With a proxy URL the request body is posted there unchanged and the
/// proxy adds the API key; otherwise it goes straight to Anthropic.
class ClaudeTutorService implements TutorService {
  ClaudeTutorService(this.config, {http.Client? client, this.timeout = const Duration(seconds: 90)})
      : _client = client ?? http.Client();

  static final apiUrl = Uri.parse('https://api.anthropic.com/v1/messages');

  final TutorConfig config;
  final Duration timeout;
  final http.Client _client;

  @override
  bool get isConfigured => config.isConfigured;

  /// The Messages API request body for [conversation].
  Map<String, Object?> requestBody(TutorContext context, AppLanguage language, List<TutorMessage> conversation) => {
        'model': config.model,
        'max_tokens': 16000,
        'system': TutorPrompt.system(context, language),
        'output_config': {'effort': config.effort},
        // If a safety classifier declines, let the API retry on the model it
        // recommends instead of failing the student's question.
        'fallbacks': 'default',
        'messages': [
          for (final m in conversation) {'role': m.role == TutorRole.student ? 'user' : 'assistant', 'content': m.text},
        ],
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
            config.usesProxy ? Uri.parse(config.proxyUrl) : apiUrl,
            headers: {
              'content-type': 'application/json',
              'anthropic-version': '2023-06-01',
              'anthropic-beta': 'server-side-fallback-2026-07-01',
              if (!config.usesProxy) 'x-api-key': config.apiKey,
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

  /// Turns an HTTP response into a reply or a [TutorException].
  static TutorReply parse(int status, String body) {
    switch (status) {
      case 200:
        break;
      case 401 || 403:
        throw TutorException(TutorFailure.auth, body);
      case 429:
        throw TutorException(TutorFailure.rateLimited, body);
      case 500 || 502 || 503 || 504 || 529:
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
    // A decline arrives as HTTP 200; check it before reading the content.
    final stop = json['stop_reason'] as String?;
    if (stop == 'refusal') throw const TutorException(TutorFailure.refused);
    final text = [
      for (final block in (json['content'] as List<Object?>? ?? const []))
        if (block case {'type': 'text', 'text': final String t}) t,
    ].join().trim();
    if (text.isEmpty) throw TutorException(TutorFailure.badResponse, 'no text (stop_reason $stop)');
    return TutorReply(text, truncated: stop == 'max_tokens');
  }
}
