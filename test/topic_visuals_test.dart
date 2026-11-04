import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:virtual_chemistry_lab/content/content_catalog.dart';
import 'package:virtual_chemistry_lab/content/content_repository.dart';
import 'package:virtual_chemistry_lab/content/models/topic_note.dart';
import 'package:virtual_chemistry_lab/screens/topic_detail_screen.dart';
import 'package:virtual_chemistry_lab/widgets/reaction_picture.dart';
import 'package:virtual_chemistry_lab/widgets/topic_diagrams.dart';

import 'test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late LoadedCurriculum cbse;

  setUpAll(() async {
    cbse = (await ContentCatalog.load(ContentRepository())).curriculum('cbse')!;
  });

  group('equation parsing', () {
    test('coefficients, state symbols and conditions', () {
      final e = ReactionEquation.tryParse('3Fe(s) + 4H₂O(g) → Fe₃O₄(s) + 4H₂(g)')!;
      expect([for (final t in e.reactants) (t.coefficient, t.formula, t.state)], [(3, 'Fe', 's'), (4, 'H₂O', 'g')]);
      expect([for (final t in e.products) (t.coefficient, t.formula, t.state)], [(null, 'Fe₃O₄', 's'), (4, 'H₂', 'g')]);

      final heat = ReactionEquation.tryParse('2H₂O(l) →(electricity) 2H₂(g) + O₂(g)')!;
      expect(heat.condition, 'electricity');
      expect(heat.products.first.coefficient, 2);

      final after = ReactionEquation.tryParse('C₆H₆ + Cl₂ → C₆H₅Cl + HCl (Fe, dark)')!;
      expect(after.condition, 'Fe, dark');
      expect(after.products.last.formula, 'HCl');

      final eq = ReactionEquation.tryParse('N₂(g) + 3H₂(g) ⇌ 2NH₃(g); ΔH < 0')!;
      expect(eq.reversible, isTrue);
      expect(eq.note, 'ΔH < 0');

      final cathode = ReactionEquation.tryParse('Cathode: O₂ + 2H₂O + 4e⁻ → 4OH⁻')!;
      expect(cathode.label, 'Cathode');
      expect(ReactionEquation.tryParse('CaO(s) + H₂O(l) → Ca(OH)₂(aq) + Heat')!.products.last.isEnergy, isTrue);
      expect(ReactionEquation.tryParse('C₆H₅OH + 3Br₂ (aq) → 2,4,6-tribromophenol + 3HBr')!.reactants.last.state, 'aq');
    });

    test('formulas that are not one-arrow equations stay as text', () {
      for (final f in ['K = °C + 273.15', 'rate = k[A]ˣ[B]ʸ', 'sp 180°, sp² 120°, sp³ 109.5°', 'CaCO₃', 'H–H']) {
        expect(ReactionEquation.tryParse(f), isNull, reason: f);
      }
    });

    test('most equations in the notes become pictures', () {
      final equations = [
        for (final n in cbse.notes)
          for (final f in n.formulas)
            if (f.contains('→') || f.contains('⇌')) f,
      ];
      final parsed = equations.where((f) => ReactionEquation.tryParse(f) != null).length;
      expect(parsed / equations.length, greaterThan(0.9), reason: '$parsed of ${equations.length}');
    });
  });

  group('topic diagrams', () {
    test('every listed diagram is drawn, and every note uses a known one', () {
      for (final id in topicDiagramIds) {
        expect(TopicDiagramCard.exists(id), isTrue, reason: id);
      }
      final used = {for (final n in cbse.notes) ...n.diagrams};
      expect(used, topicDiagramIds, reason: 'each drawing is shown on at least one topic');
    });

    for (final hindi in [false, true]) {
      testWidgets('all diagrams paint without errors (${hindi ? 'Hindi' : 'English'})', (tester) async {
        await launchApp(tester, saved: {if (hindi) 'app_language': 'hi'});
        for (final id in topicDiagramIds) {
          tester.state<NavigatorState>(find.byType(Navigator).first).push(MaterialPageRoute<void>(
            builder: (_) => Scaffold(body: SingleChildScrollView(child: TopicDiagramCard(id: id))),
          ));
          await tester.pumpAndSettle();
          expect(find.byType(TopicDiagramCard), findsOneWidget, reason: id);
          tester.state<NavigatorState>(find.byType(Navigator).first).pop();
          await tester.pumpAndSettle();
        }
      });
    }

    testWidgets('pH topic shows its picture and the reaction pictures; tapping zooms', (tester) async {
      await launchApp(tester);
      final loc = cbse.topic('cbse-10-ch02-t2.3')!;
      tester.state<NavigatorState>(find.byType(Navigator).first).push(MaterialPageRoute<void>(
        builder: (_) => TopicDetailScreen(syllabus: loc.syllabus, chapter: loc.chapter, topic: loc.topic),
      ));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.byType(TopicDiagramCard), 300, scrollable: find.byType(Scrollable).first);
      expect(find.text('The pH scale (0 to 14)'), findsOneWidget);
      final drawing = find.descendant(of: find.byType(TopicDiagramCard), matching: find.byType(InkWell));
      await tester.ensureVisible(drawing);
      await tester.pumpAndSettle();
      await tester.tap(drawing);
      await tester.pumpAndSettle();
      expect(find.byType(InteractiveViewer), findsOneWidget);
    });

    testWidgets('small phone: a topic with a long equation fits', (tester) async {
      await launchApp(tester, size: const Size(640, 1136), pixelRatio: 2, saved: {'app_language': 'hi'});
      final loc = cbse.topic('cbse-10-ch03-t3.2.2')!;
      tester.state<NavigatorState>(find.byType(Navigator).first).push(MaterialPageRoute<void>(
        builder: (_) => TopicDetailScreen(syllabus: loc.syllabus, chapter: loc.chapter, topic: loc.topic),
      ));
      await tester.pumpAndSettle();
      for (var i = 0; i < 40 && find.byType(ReactionPicture).evaluate().isEmpty; i++) {
        await tester.drag(find.byType(Scrollable).first, const Offset(0, -300));
        await tester.pumpAndSettle();
      }
      expect(find.byType(ReactionPicture), findsWidgets);
      // Any RenderFlex overflow fails the test.
    });
  });
}
