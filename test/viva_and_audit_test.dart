import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:virtual_chemistry_lab/content/content_catalog.dart';
import 'package:virtual_chemistry_lab/content/content_repository.dart';
import 'package:virtual_chemistry_lab/content/content_text.dart';
import 'package:virtual_chemistry_lab/content/content_validator.dart';
import 'package:virtual_chemistry_lab/content/models/practical_guide.dart';
import 'package:virtual_chemistry_lab/content/models/practice_question.dart';
import 'package:virtual_chemistry_lab/content/models/pyq.dart' show QuestionType;
import 'package:virtual_chemistry_lab/screens/practical_guide_screen.dart';
import 'package:virtual_chemistry_lab/widgets/language_toggle.dart';

import 'test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late LoadedCurriculum cbse;

  setUpAll(() async {
    cbse = (await ContentCatalog.load(ContentRepository())).curriculum('cbse')!;
  });

  group('practical viva', () {
    test('every practical guide has at least 4 viva questions with answers, in English and Hindi', () {
      expect(cbse.guides, hasLength(24));
      var total = 0;
      for (final g in cbse.guides.values) {
        expect(g.viva.length, greaterThanOrEqualTo(ContentValidator.minVivaQuestions), reason: g.id);
        for (final v in g.viva) {
          for (final text in [v.question, v.answer]) {
            expect(text.en.trim(), isNotEmpty, reason: g.id);
            expect(text.hi, isNotNull, reason: g.id);
            expect(RegExp(r'[ऀ-ॿ]').hasMatch(text.hi!), isTrue, reason: '${g.id}: Hindi is Devanagari');
          }
        }
        total += g.viva.length;
      }
      expect(total, 100);
    });

    test('viva answers agree with the lab they belong to', () {
      String answers(String id) => [for (final v in cbse.guideFor(id)!.viva) v.answer.en].join(' ');
      expect(answers('kmno4_oxalic_titration'), contains('self-indicator'));
      expect(answers('kmno4_mohr_salt_titration'), contains('+7 to +2'));
      expect(answers('hcl_sodium_carbonate_titration'), contains('1 : 2'));
      expect(answers('oxygen_preparation'), contains('catalyst'));
      expect(answers('rx-tollens-test'), contains('silver mirror'));
    });

    test('the validator requires viva questions and rejects a repeated one', () {
      final g = cbse.guideFor('acid_base_titration')!;
      PracticalGuide withViva(List<VivaQuestion> viva) => PracticalGuide(
            id: g.id, aim: g.aim, equation: g.equation, apparatus: g.apparatus, chemicals: g.chemicals, steps: g.steps,
            result: g.result, safety: g.safety, simulationLimits: g.simulationLimits, sources: g.sources, review: g.review, viva: viva,
          );
      List<String> issues(PracticalGuide guide) => ContentValidator.learningContent(
            LoadedCurriculum(cbse.manifest, cbse.classes.values.toList(),
                concepts: cbse.concepts, chemicals: cbse.chemicals, reagents: cbse.reagents, reactions: cbse.reactions,
                guides: {...cbse.guides, guide.id: guide}),
            notesForClasses: const {},
          );
      expect(issues(g).where((i) => i.contains('viva')), isEmpty);
      expect(issues(withViva(const [])), contains('Practical guide acid_base_titration: has 0 viva questions, needs at least 4'));
      final repeated = [...g.viva, g.viva.first];
      expect(issues(withViva(repeated)).any((i) => i.contains('viva question repeated')), isTrue);
    });

    test('old guide data without a viva list still loads (empty viva)', () {
      final raw = jsonDecode(File('assets/content/library/practical-guides.json').readAsStringSync()) as Map<String, Object?>;
      final first = Map<String, Object?>.of((raw['items']! as List).first as Map<String, Object?>)..remove('viva');
      final guide = PracticalGuide.fromJson(first);
      expect(guide.viva, isEmpty);
      expect(guide.steps, isNotEmpty);
    });

    testWidgets('guide screen shows the viva section; answers stay hidden until tapped; Hindi works', (tester) async {
      await launchApp(tester, size: const Size(1080, 20000));
      tester.state<NavigatorState>(find.byType(Navigator).first).push(MaterialPageRoute<void>(
        builder: (_) => const PracticalGuideScreen(labId: 'kmno4_oxalic_titration', classLevel: 12),
      ));
      await tester.pumpAndSettle();
      final v = cbse.guideFor('kmno4_oxalic_titration')!.viva.first;
      // Existing sections are still there.
      expect(find.text('📋 Steps in a real lab'), findsOneWidget);
      expect(find.text('⚠️ Safety'), findsOneWidget);
      expect(find.text('🎤 Viva questions'), findsOneWidget);
      expect(find.byType(VivaTile), findsNWidgets(5));
      expect(find.text(v.question.en), findsOneWidget);
      expect(find.textContaining(v.answer.en, findRichText: true), findsNothing);
      await tester.tap(find.text(v.question.en));
      await tester.pumpAndSettle();
      expect(find.textContaining('Answer: ${v.answer.en}', findRichText: true), findsOneWidget);

      await tester.tap(find.byType(LanguageToggle).first);
      await tester.pumpAndSettle();
      expect(find.text('🎤 मौखिकी (वाइवा) प्रश्न'), findsOneWidget);
      expect(find.text(v.question.hi!), findsOneWidget);
      // Existing sections in Hindi too.
      expect(find.text('🔬 उपकरण'), findsOneWidget);
      expect(find.text('📋 वास्तविक लैब में चरण'), findsOneWidget);
      expect(find.text('⚠️ सुरक्षा'), findsOneWidget);
      // The first answer is still open, now in Hindi; a second one opens on tap.
      expect(find.textContaining('उत्तर: ${v.answer.hi!}', findRichText: true), findsOneWidget);
      final v2 = cbse.guideFor('kmno4_oxalic_titration')!.viva[1];
      expect(find.textContaining(v2.answer.hi!, findRichText: true), findsNothing);
      await tester.tap(find.text(v2.question.hi!));
      await tester.pumpAndSettle();
      expect(find.textContaining('उत्तर: ${v2.answer.hi!}', findRichText: true), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('question audit', () {
    PracticeQuestion q(String id) => cbse.questions.firstWhere((x) => x.id == id);
    ContentText answerOf(PracticeQuestion x) => x.answer;

    test('boiling-point order uses correct data (ethoxyethane does not boil above n-pentane)', () {
      final x = q('qt-cbse-12-ch08-t8.3-1');
      expect(answerOf(x).en, 'n-butane < methoxyethane < propanal < propan-1-ol');
      expect(x.options[x.correctOption!].en, answerOf(x).en);
      expect(x.question.en, isNot(contains('pentane')));
    });

    test('formula P₂O₅ is not called a molecule; radioactivity is not claimed as "first"', () {
      expect(q('qt-cbse-9-ch09-t9.5.1-3').question.en, isNot(contains('one molecule')));
      expect(q('qt-cbse-9-ch09-t9.5.1-3').explanation.en, contains('P₄O₁₀'));
      expect(q('qt-cbse-9-ch08-t8.2-1').question.en, isNot(contains('first')));
    });

    test('alloy question sits on 3.5.1; 3.5 keeps a corrosion question', () {
      expect(q('qt-cbse-10-ch03-t3.5.1-4').question.en, '22-carat gold contains —');
      expect(q('qt-cbse-10-ch03-t3.5.1-4').topicId, 'cbse-10-ch03-t3.5.1');
      expect(answerOf(q('qt-cbse-10-ch03-t3.5-1')).en, contains('silver sulphide'));
    });

    test('Sandmeyer equation writes Cu₂Cl₂ as the reagent, not a reactant', () {
      expect(answerOf(q('qt-cbse-12-ch06-t6.5-2')).en, contains('→(Cu₂Cl₂)'));
      expect(answerOf(q('qt-cbse-12-ch06-t6.5-2')).en, isNot(contains('+ Cu₂Cl₂')));
    });

    test('the 12 original numericals stay numerical: they are calculations with working in the answer', () {
      const ids = [
        'q-cbse-9-ch09-01', 'q-cbse-11-ch01-09', 'q-cbse-11-ch02-08', 'q-cbse-11-ch05-07', 'q-cbse-11-ch05-08', 'q-cbse-11-ch06-07',
        'q-cbse-11-ch08-08', 'q-cbse-12-ch01-08', 'q-cbse-12-ch02-07', 'q-cbse-12-ch02-08', 'q-cbse-12-ch03-07', 'q-cbse-12-ch03-08',
      ];
      for (final id in ids) {
        final x = q(id);
        expect(x.type, QuestionType.numerical, reason: id);
        expect(x.answer.en, anyOf(contains('='), contains('×')), reason: '$id shows its calculation');
      }
    });

    test('protein molar mass matches its own working: 1.26 × 0.083 × 300 ÷ (2.57 × 10⁻³ × 0.200)', () {
      final m = 1.26 * 0.083 * 300 / (2.57e-3 * 0.200);
      expect(m.round(), 61039);
      final x = q('q-cbse-12-ch01-08');
      expect(x.answer.en, contains('≈ 61,039 g mol⁻¹'));
      expect(x.answer.hi, contains('≈ 61,039 g mol⁻¹'));
      expect(x.answer.en, isNot(contains('61,022')));
    });

    test('no two choice questions share both their text and their options', () {
      final seen = <String, String>{};
      for (final x in cbse.questions.where((x) => x.options.isNotEmpty)) {
        final key = '${x.question.en.trim().toLowerCase()}|${[for (final o in x.options) o.en.toLowerCase()].join('|')}';
        expect(seen[key], isNull, reason: '${x.id} repeats ${seen[key]}');
        seen[key] = x.id;
      }
    });
  });
}
