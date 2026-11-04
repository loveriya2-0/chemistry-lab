import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:virtual_chemistry_lab/ai/gemini_tutor_service.dart';
import 'package:virtual_chemistry_lab/ai/tutor_context.dart';
import 'package:virtual_chemistry_lab/ai/tutor_service.dart';
import 'package:virtual_chemistry_lab/content/content_catalog.dart';
import 'package:virtual_chemistry_lab/content/content_repository.dart';
import 'package:virtual_chemistry_lab/l10n/app_language.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late LoadedCurriculum cbse;

  setUpAll(() async {
    cbse = (await ContentCatalog.load(ContentRepository())).curriculum('cbse')!;
  });

  TutorContext phContext() => TutorContext.forTopic(cbse, cbse.topic('cbse-10-ch02-t2.3')!, boardName: 'CBSE');
  const student = [TutorMessage(TutorRole.student, 'What is pH?')];

  http.Response ok(Map<String, Object?> body) =>
      http.Response.bytes(utf8.encode(jsonEncode(body)), 200, headers: {'content-type': 'application/json'});
  Map<String, Object?> answer(String text, {String finish = 'STOP'}) => {
        'candidates': [
          {
            'content': {
              'role': 'model',
              'parts': [
                {'text': 'thinking…', 'thought': true},
                {'text': text},
              ],
            },
            'finishReason': finish,
          },
        ],
      };

  test('configuration: off without build-time settings; no key in the code', () {
    expect(const GeminiConfig().isConfigured, isFalse);
    expect(GeminiConfig.fromEnvironment().isConfigured, isFalse, reason: 'tests run without --dart-define');
    expect(const GeminiConfig().model, 'gemini-3.8-flash');
    expect(const GeminiConfig(apiKey: 'k').isConfigured, isTrue);
    expect(const GeminiConfig(proxyUrl: 'https://example.org/gemini').isConfigured, isTrue);
    // Without a Gemini setting the app keeps using the Claude tutor.
    expect(tutorFromEnvironment(), isA<ClaudeTutorService>());
    final keyLike = RegExp(r'AIza[0-9A-Za-z_-]{20,}');
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'))) {
      expect(keyLike.hasMatch(f.readAsStringSync()), isFalse, reason: f.path);
    }
  });

  test('direct mode: model endpoint, key header, system prompt and roles', () async {
    late http.Request sent;
    final service = GeminiTutorService(
      const GeminiConfig(apiKey: 'test-key'),
      client: MockClient((r) async {
        sent = r;
        return ok(answer('pH तीव्रता बताता है।'));
      }),
    );
    final reply = await service.reply(context: phContext(), language: AppLanguage.hi, conversation: const [
      TutorMessage(TutorRole.student, 'Q1'),
      TutorMessage(TutorRole.tutor, 'A1'),
      TutorMessage(TutorRole.student, 'Q2'),
    ]);
    expect(reply.text, 'pH तीव्रता बताता है।', reason: 'thought parts are not shown');
    expect(reply.truncated, isFalse);
    expect(sent.url.toString(), 'https://generativelanguage.googleapis.com/v1beta/models/gemini-3.8-flash:generateContent');
    expect(sent.headers['x-goog-api-key'], 'test-key');
    final body = jsonDecode(sent.body) as Map<String, Object?>;
    expect(((body['systemInstruction']! as Map)['parts'] as List).single['text'], contains('Reply in Hindi'));
    expect([for (final c in body['contents']! as List) c['role']], ['user', 'model', 'user']);
    expect(((body['contents']! as List).first['parts'] as List).single, {'text': 'Q1'});
  });

  test('proxy mode: posts to the proxy and sends no key', () async {
    late http.Request sent;
    final service = GeminiTutorService(
      const GeminiConfig(proxyUrl: 'https://tutor.example.org/gemini'),
      client: MockClient((r) async {
        sent = r;
        return ok(answer('Answer'));
      }),
    );
    await service.reply(context: phContext(), language: AppLanguage.en, conversation: student);
    expect(sent.url.toString(), 'https://tutor.example.org/gemini');
    expect(sent.headers.containsKey('x-goog-api-key'), isFalse);
  });

  test('errors, blocks and cut-off answers', () async {
    Future<Object?> run(http.Response r) async {
      final s = GeminiTutorService(const GeminiConfig(apiKey: 'k'), client: MockClient((_) async => r));
      try {
        return await s.reply(context: phContext(), language: AppLanguage.en, conversation: student);
      } on TutorException catch (e) {
        return e.failure;
      }
    }

    expect(await run(http.Response('{"error":{"status":"INVALID_ARGUMENT","details":[{"reason":"API_KEY_INVALID"}]}}', 400)), TutorFailure.auth);
    expect(await run(http.Response('{}', 403)), TutorFailure.auth);
    expect(await run(http.Response('{}', 429)), TutorFailure.rateLimited);
    expect(await run(http.Response('{}', 503)), TutorFailure.busy);
    expect(await run(http.Response('{}', 400)), TutorFailure.badResponse);
    expect(await run(http.Response('not json', 200)), TutorFailure.badResponse);
    expect(await run(ok({'promptFeedback': {'blockReason': 'SAFETY'}})), TutorFailure.refused);
    expect(
        await run(ok({
          'candidates': [
            {'finishReason': 'SAFETY'},
          ],
        })),
        TutorFailure.refused);
    final cut = await run(ok(answer('Part of an answer', finish: 'MAX_TOKENS')));
    expect((cut! as TutorReply).truncated, isTrue);

    final offline = GeminiTutorService(const GeminiConfig(apiKey: 'k'), client: MockClient((_) async => throw http.ClientException('offline')));
    await expectLater(
      offline.reply(context: phContext(), language: AppLanguage.en, conversation: student),
      throwsA(isA<TutorException>().having((e) => e.failure, 'failure', TutorFailure.network)),
    );
  });
}
