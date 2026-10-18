import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:virtual_chemistry_lab/ai/tutor_context.dart';
import 'package:virtual_chemistry_lab/ai/tutor_prompt.dart';
import 'package:virtual_chemistry_lab/ai/tutor_service.dart';
import 'package:virtual_chemistry_lab/content/content_catalog.dart';
import 'package:virtual_chemistry_lab/content/content_repository.dart';
import 'package:virtual_chemistry_lab/l10n/app_language.dart';
import 'package:virtual_chemistry_lab/screens/ai_tutor_screen.dart';
import 'package:virtual_chemistry_lab/screens/chemical_screen.dart';
import 'package:virtual_chemistry_lab/screens/topic_detail_screen.dart';
import 'package:virtual_chemistry_lab/widgets/ask_ai.dart';

import 'test_helpers.dart';

/// Records every request and answers with [answer] (or throws [failure]).
class FakeTutor implements TutorService {
  FakeTutor({this.answer = 'Fake AI answer about pH.', this.failure, this.configured = true});

  final String answer;
  TutorFailure? failure;
  final bool configured;
  final calls = <({TutorContext context, AppLanguage language, List<TutorMessage> conversation})>[];

  @override
  bool get isConfigured => configured;

  @override
  Future<TutorReply> reply({required TutorContext context, required AppLanguage language, required List<TutorMessage> conversation}) async {
    calls.add((context: context, language: language, conversation: List.of(conversation)));
    if (failure case final f?) throw TutorException(f);
    return TutorReply(answer);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late LoadedCurriculum cbse;

  setUpAll(() async {
    cbse = (await ContentCatalog.load(ContentRepository())).curriculum('cbse')!;
  });

  TutorContext phContext() => TutorContext.forTopic(cbse, cbse.topic('cbse-10-ch02-t2.3')!, boardName: 'CBSE');
  const student = [TutorMessage(TutorRole.student, 'What is pH?')];

  group('configuration: no key in the code', () {
    test('without build-time settings the tutor is off, and the default model is Claude Opus 5', () {
      const config = TutorConfig();
      expect(config.isConfigured, isFalse);
      expect(TutorConfig.fromEnvironment().isConfigured, isFalse, reason: 'tests run without --dart-define');
      expect(config.model, 'claude-opus-5');
      expect(const TutorConfig(proxyUrl: 'https://example.org/tutor').isConfigured, isTrue);
      expect(const TutorConfig(apiKey: 'k').isConfigured, isTrue);
    });

    test('no API key or secret is written anywhere in lib/', () {
      final keyLike = RegExp(r'sk-ant-[A-Za-z0-9_-]{8,}');
      for (final f in Directory('lib').listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'))) {
        expect(keyLike.hasMatch(f.readAsStringSync()), isFalse, reason: f.path);
      }
      final service = File('lib/ai/tutor_service.dart').readAsStringSync();
      expect(service, contains("String.fromEnvironment('ANTHROPIC_API_KEY')"));
    });
  });

  group('context and prompt', () {
    test('a topic context carries board, class, chapter, topic and the verified note facts', () {
      final c = phContext();
      expect(c.boardName, 'CBSE');
      expect(c.academicYear, '2026-27');
      expect(c.classLevel, 10);
      expect(c.chapter, contains('Acids, Bases and Salts'));
      expect(c.topic, startsWith('2.3 '));
      expect(c.verifiedFacts, contains('pH < 7 acidic; pH = 7 neutral; pH > 7 basic'));
    });

    test('chapter, chemical and concept contexts', () {
      final (syllabus, chapter) = cbse.chapter('cbse-10-ch02')!;
      final ch = TutorContext.forChapter(cbse, syllabus, chapter, boardName: 'CBSE');
      expect(ch.verifiedFacts.first, startsWith('Topic 2.1'));
      final x = TutorContext.forChemical(cbse, cbse.chemicals['bleaching-powder']!, boardName: 'CBSE');
      expect(x.subject, contains('Ca(ClO)₂'));
      expect(x.classLevel, 10);
      final k = TutorContext.forConcept(cbse, cbse.concepts['neutralisation']!, classLevel: 10, boardName: 'CBSE');
      expect(k.topic, isNotNull);
    });

    test('system prompt: context, notes as reference, rules, reply language', () {
      final en = TutorPrompt.system(phContext(), AppLanguage.en);
      expect(en, contains('Board: CBSE, syllabus 2026-27, Class 10'));
      expect(en, contains('- pH < 7 acidic; pH = 7 neutral; pH > 7 basic'));
      expect(en, contains('follow the notes'));
      expect(en, contains('balanced'));
      expect(en, contains('Never say that a question came in a past board paper'));
      expect(en, contains('Reply in English'));
      final hi = TutorPrompt.system(phContext(), AppLanguage.hi);
      expect(hi, contains('Reply in Hindi (Devanagari script)'));
    });

    test('every quick action names what the student is studying', () {
      for (final a in TutorAction.values) {
        expect(a.instruction('pH scale'), contains('"pH scale"'), reason: a.name);
      }
      expect(TutorAction.quiz.instruction('x'), contains('one question at a time'));
    });
  });

  group('Claude Messages API client (mocked HTTP, no network)', () {
    http.Response ok(Map<String, Object?> body) =>
        http.Response.bytes(utf8.encode(jsonEncode(body)), 200, headers: {'content-type': 'application/json'});
    Map<String, Object?> message(String text, {String stop = 'end_turn'}) => {
          'type': 'message',
          'role': 'assistant',
          'content': [
            {'type': 'text', 'text': text},
          ],
          'stop_reason': stop,
        };

    test('direct mode: Anthropic endpoint, key header from config, full request body', () async {
      late http.Request sent;
      final service = ClaudeTutorService(
        const TutorConfig(apiKey: 'test-key'),
        client: MockClient((r) async {
          sent = r;
          return ok(message('pH तीव्रता बताता है।'));
        }),
      );
      final reply = await service.reply(context: phContext(), language: AppLanguage.hi, conversation: student);
      expect(reply.text, 'pH तीव्रता बताता है।');
      expect(reply.truncated, isFalse);
      expect(sent.url, ClaudeTutorService.apiUrl);
      expect(sent.headers['x-api-key'], 'test-key');
      expect(sent.headers['anthropic-version'], '2023-06-01');
      expect(sent.headers['anthropic-beta'], 'server-side-fallback-2026-07-01');
      final body = jsonDecode(sent.body) as Map<String, Object?>;
      expect(body['model'], 'claude-opus-5');
      expect(body['fallbacks'], 'default');
      expect(body['system'], contains('Reply in Hindi'));
      expect(body['messages'], [
        {'role': 'user', 'content': 'What is pH?'},
      ]);
    });

    test('proxy mode: posts to the proxy and sends no key', () async {
      late http.Request sent;
      final service = ClaudeTutorService(
        const TutorConfig(proxyUrl: 'https://tutor.example.org/v1/messages'),
        client: MockClient((r) async {
          sent = r;
          return ok(message('Answer'));
        }),
      );
      await service.reply(context: phContext(), language: AppLanguage.en, conversation: const [
        TutorMessage(TutorRole.student, 'Q1'),
        TutorMessage(TutorRole.tutor, 'A1'),
        TutorMessage(TutorRole.student, 'Q2'),
      ]);
      expect(sent.url.toString(), 'https://tutor.example.org/v1/messages');
      expect(sent.headers.containsKey('x-api-key'), isFalse);
      expect([for (final m in (jsonDecode(sent.body) as Map)['messages'] as List) m['role']], ['user', 'assistant', 'user']);
    });

    test('not configured: fails without any HTTP call', () async {
      var calls = 0;
      final service = ClaudeTutorService(const TutorConfig(), client: MockClient((_) async {
        calls++;
        return ok(message('x'));
      }));
      await expectLater(
        service.reply(context: phContext(), language: AppLanguage.en, conversation: student),
        throwsA(isA<TutorException>().having((e) => e.failure, 'failure', TutorFailure.notConfigured)),
      );
      expect(calls, 0);
    });

    test('errors, refusals and cut-off answers', () async {
      Future<Object?> run(http.Response r) async {
        final s = ClaudeTutorService(const TutorConfig(apiKey: 'k'), client: MockClient((_) async => r));
        try {
          return await s.reply(context: phContext(), language: AppLanguage.en, conversation: student);
        } on TutorException catch (e) {
          return e.failure;
        }
      }

      expect(await run(http.Response('{}', 401)), TutorFailure.auth);
      expect(await run(http.Response('{}', 429)), TutorFailure.rateLimited);
      expect(await run(http.Response('{}', 529)), TutorFailure.busy);
      expect(await run(http.Response('{}', 400)), TutorFailure.badResponse);
      expect(await run(http.Response('not json', 200)), TutorFailure.badResponse);
      expect(await run(ok({'content': <Object>[], 'stop_reason': 'refusal'})), TutorFailure.refused);
      final cut = await run(ok(message('Part of an answer', stop: 'max_tokens')));
      expect((cut! as TutorReply).truncated, isTrue);

      final offline = ClaudeTutorService(const TutorConfig(apiKey: 'k'), client: MockClient((_) async => throw http.ClientException('offline')));
      await expectLater(
        offline.reply(context: phContext(), language: AppLanguage.en, conversation: student),
        throwsA(isA<TutorException>().having((e) => e.failure, 'failure', TutorFailure.network)),
      );
    });
  });

  group('Ask AI screens', () {
    Future<void> openTopic(WidgetTester tester, {required TutorService tutor, bool hindi = false}) async {
      await launchApp(tester, tutor: tutor, saved: {if (hindi) 'app_language': 'hi'});
      final loc = cbse.topic('cbse-10-ch02-t2.3')!;
      tester.state<NavigatorState>(find.byType(Navigator).first).push(MaterialPageRoute<void>(
        builder: (_) => TopicDetailScreen(syllabus: loc.syllabus, chapter: loc.chapter, topic: loc.topic),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('topic → Ask AI → quick action → labelled AI answer with the topic context', (tester) async {
      final tutor = FakeTutor();
      await openTopic(tester, tutor: tutor);
      expect(find.byTooltip('Ask AI'), findsOneWidget);
      await tester.scrollUntilVisible(find.byType(AskAiCard), 300, scrollable: find.byType(Scrollable).first);
      expect(find.byType(AiAnswerCard), findsNothing, reason: 'AI text never appears among the verified notes');
      await tester.tap(find.byTooltip('Ask AI'));
      await tester.pumpAndSettle();

      expect(find.byType(AiTutorScreen), findsOneWidget);
      expect(find.textContaining('Class 10 › Chapter 2'), findsOneWidget);
      expect(find.text('CBSE · 2026-27'), findsOneWidget);
      await tester.tap(find.text('Step by step'));
      await tester.pumpAndSettle();

      expect(find.text('Fake AI answer about pH.'), findsOneWidget);
      expect(find.text('🤖 AI Explanation'), findsOneWidget);
      expect(find.textContaining('Written by AI, not from the verified notes'), findsOneWidget);
      final call = tutor.calls.single;
      expect(call.context.classLevel, 10);
      expect(call.context.topic, startsWith('2.3'));
      expect(call.language, AppLanguage.en);
      expect(call.conversation.single.text, startsWith('Explain "'));
      expect(call.conversation.single.text, contains('step by step'));
    });

    testWidgets('typed question and a follow-up keep the conversation', (tester) async {
      final tutor = FakeTutor();
      await openTopic(tester, tutor: tutor);
      await tester.tap(find.byTooltip('Ask AI'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Why is soap basic?');
      await tester.tap(find.byTooltip('Send'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Give me one more example');
      await tester.tap(find.byTooltip('Send'));
      await tester.pumpAndSettle();
      expect(find.text('Why is soap basic?'), findsOneWidget);
      expect(find.byType(AiAnswerCard), findsNWidgets(2));
      expect([for (final m in tutor.calls.last.conversation) m.role],
          [TutorRole.student, TutorRole.tutor, TutorRole.student]);
    });

    testWidgets('Hindi: Hindi labels and the Hindi reply language is requested', (tester) async {
      final tutor = FakeTutor(answer: 'pH किसी विलयन की अम्लता बताता है।');
      await openTopic(tester, tutor: tutor, hindi: true);
      await tester.tap(find.byTooltip('AI से पूछें'));
      await tester.pumpAndSettle();
      expect(find.text('🤖 AI ट्यूटर'), findsOneWidget);
      await tester.tap(find.text('सरल भाषा में समझाओ'));
      await tester.pumpAndSettle();
      expect(find.text('🤖 AI व्याख्या'), findsOneWidget);
      expect(find.text('pH किसी विलयन की अम्लता बताता है।'), findsOneWidget);
      expect(tutor.calls.single.language, AppLanguage.hi);
    });

    testWidgets('a failed answer shows the reason and can be retried', (tester) async {
      final tutor = FakeTutor(failure: TutorFailure.network);
      await openTopic(tester, tutor: tutor);
      await tester.tap(find.byTooltip('Ask AI'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Quiz me'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Quiz me'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Could not reach the AI service'), findsOneWidget);
      tutor.failure = null;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.byType(AiAnswerCard), findsOneWidget);
      expect(tutor.calls, hasLength(2));
    });

    testWidgets('without an AI connection the screen says so and offers no input', (tester) async {
      await openTopic(tester, tutor: FakeTutor(configured: false));
      await tester.tap(find.byTooltip('Ask AI'));
      await tester.pumpAndSettle();
      expect(find.text('AI tutor is not set up'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('the default app build (no --dart-define) is not connected', (tester) async {
      await openTopic(tester, tutor: ClaudeTutorService(TutorConfig.fromEnvironment()));
      await tester.tap(find.byTooltip('Ask AI'));
      await tester.pumpAndSettle();
      expect(find.text('AI tutor is not set up'), findsOneWidget);
    });

    testWidgets('small phone 320×568: tutor screen fits in Hindi with an answer', (tester) async {
      final tutor = FakeTutor(answer: 'pH मान 0 से 14 तक होता है। ' * 20);
      await launchApp(tester, tutor: tutor, size: const Size(640, 1136), pixelRatio: 2, saved: {'app_language': 'hi'});
      final loc = cbse.topic('cbse-10-ch02-t2.3')!;
      tester.state<NavigatorState>(find.byType(Navigator).first).push(MaterialPageRoute<void>(
        builder: (_) => TopicDetailScreen(syllabus: loc.syllabus, chapter: loc.chapter, topic: loc.topic),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('AI से पूछें'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('सरल भाषा में समझाओ'));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -4000));
      await tester.pumpAndSettle();
      expect(find.byType(AiAnswerCard), findsOneWidget);
      // Any RenderFlex overflow above fails the test.
    });

    testWidgets('a reaction card has Ask AI with the reaction as context', (tester) async {
      final tutor = FakeTutor();
      await launchApp(tester, tutor: tutor);
      tester.state<NavigatorState>(find.byType(Navigator).first).push(MaterialPageRoute<void>(
        builder: (_) => ChemicalScreen(chemical: cbse.chemicals['bleaching-powder']!),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Ask AI'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Give an example'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Give an example'));
      await tester.pumpAndSettle();
      expect(tutor.calls.single.context.subject, contains('Bleaching powder'));
      expect(tutor.calls.single.context.verifiedFacts, contains('2Ca(OH)₂ + 2Cl₂ → Ca(ClO)₂ + CaCl₂ + 2H₂O'));
    });
  });
}
