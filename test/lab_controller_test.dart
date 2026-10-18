import 'package:flutter_test/flutter_test.dart';
import 'package:virtual_chemistry_lab/data/practicals_repository.dart';
import 'package:virtual_chemistry_lab/l10n/app_language.dart';
import 'package:virtual_chemistry_lab/l10n/app_strings.dart';
import 'package:virtual_chemistry_lab/l10n/localized_text.dart';
import 'package:virtual_chemistry_lab/models/lab_step.dart';
import 'package:virtual_chemistry_lab/state/lab_controller.dart';

void main() {
  const repo = PracticalsRepository();

  /// Fills the burette on [lab]'s titration step and runs [portions] in.
  List<DropResult> titrate(LabController lab, List<double> portions) {
    final titrant = lab.expectedChemical!;
    expect(lab.attemptAdd(titrant), isA<TitrantReady>());
    return [for (final p in portions) lab.attemptAdd(titrant, portionMl: p)];
  }

  group('LabController', () {
    test('correct sequence and burette reading complete the titration', () {
      final lab = LabController(repo.byId('acid_base_titration'));
      expect(lab.attemptAdd(Chemicals.naoh), isA<CorrectDrop>());
      expect(lab.volumeMl, 10, reason: 'a pipette delivers exactly 10.0 mL');
      expect(lab.attemptAdd(Chemicals.phenolphthalein), isA<CorrectDrop>());
      expect(lab.stepIndex, 2);
      expect(lab.titrantReady, isFalse);

      final results = titrate(lab, [1, 1, 1, 1, 1, 1, 1, 1]);
      expect(results.take(7), everyElement(isA<TitrantAdded>()));
      expect(results.last, isA<PracticalCompleted>());
      expect(lab.titrantMl, 8.0);
      expect(lab.isComplete, isTrue);
      expect(lab.mistakes, 0);
      expect(lab.stars, 3);
      expect(lab.beakerColor, lab.practical.steps.last.resultColor);
      expect(lab.practical.calculation!.working(lab.titrantMl), 'c(NaOH) = 0.1 × 8.0 ÷ 10.0 = 0.080 M');
      expect(lab.attemptAdd(Chemicals.naoh), isA<IgnoredDrop>());
    });

    test('burette portions add exactly and the colour holds until the end point', () {
      final lab = LabController(repo.byId('acid_base_titration'))
        ..attemptAdd(Chemicals.naoh)
        ..attemptAdd(Chemicals.phenolphthalein);
      final pink = lab.beakerColor;
      final step = lab.currentStep!;
      titrate(lab, [1, 1, 1, 1, 1, 1, 1]);
      expect(lab.titrantMl, 7.0);
      expect(lab.beakerColor, pink);
      expect(lab.lastObservation, step.titration!.duringObservation);
      // Ten 0.1 mL portions reach 8.0 mL exactly (no floating-point drift).
      for (var i = 0; i < 9; i++) {
        expect(lab.attemptAdd(Chemicals.hcl, portionMl: 0.1), isA<TitrantAdded>());
      }
      expect(lab.titrantMl, 7.9);
      expect(lab.lastObservation, step.titration!.nearObservation, reason: 'within 0.5 mL: the real cue that the end point is close');
      expect(lab.attemptAdd(Chemicals.hcl, portionMl: 0.1), isA<PracticalCompleted>());
      expect(lab.titrantMl, 8.0);
    });

    test('a portion that is not one of the burette portions is rejected', () {
      final lab = LabController(repo.byId('acid_base_titration'))
        ..attemptAdd(Chemicals.naoh)
        ..attemptAdd(Chemicals.phenolphthalein)
        ..attemptAdd(Chemicals.hcl);
      expect(() => lab.attemptAdd(Chemicals.hcl, portionMl: 2.5), throwsArgumentError);
      expect(lab.titrantMl, 0);
    });

    test('passing the end point gives a rough reading: no mistake, but reset is needed', () {
      final lab = LabController(repo.byId('oxalic_acid_titration'))
        ..attemptAdd(Chemicals.oxalicAcid)
        ..attemptAdd(Chemicals.phenolphthalein);
      final results = titrate(lab, List.filled(13, 1.0));
      expect(results.last, isA<Overshot>());
      final over = results.last as Overshot;
      expect(over.readingMl, 13.0);
      expect(over.portionMl, 1.0);
      expect(lab.isSpoiled, isTrue);
      expect(lab.mistakes, 0, reason: 'a rough titration is not a wrong action');
      expect(lab.isComplete, isFalse);
      expect(lab.beakerColor, lab.currentStep!.titration!.overshootColor);
      // Nothing more can be added, and nothing changes, until reset.
      expect(lab.attemptAdd(Chemicals.naoh, portionMl: 0.1), isA<NeedsReset>());
      expect(lab.attemptAdd(Chemicals.hcl), isA<NeedsReset>());
      expect(lab.titrantMl, 13.0);
      expect(lab.mistakes, 0);

      lab.reset();
      expect(lab.isSpoiled, isFalse);
      expect(lab.titrantMl, 0);
      expect(lab.titrantReady, isFalse);
      expect(lab.stepIndex, 0);
    });

    test('oxalic acid titration: 1 : 2 ratio in the result', () {
      final lab = LabController(repo.byId('oxalic_acid_titration'))
        ..attemptAdd(Chemicals.oxalicAcid)
        ..attemptAdd(Chemicals.phenolphthalein);
      final results = titrate(lab, [...List.filled(12, 1.0), ...List.filled(5, 0.1)]);
      expect(results.last, isA<PracticalCompleted>());
      expect(lab.titrantMl, 12.5);
      final calc = lab.practical.calculation!;
      expect(calc.unknownMolarity(12.5), closeTo(0.08, 1e-9));
      expect(calc.working(12.5), 'c(NaOH) = 2 × 0.05 × 10.0 ÷ 12.5 = 0.080 M');
    });

    test('wrong chemical warns, names both chemicals and does not advance', () {
      final lab = LabController(repo.byId('acid_base_titration'));
      final result = lab.attemptAdd(Chemicals.hcl);

      expect(result, isA<WrongDrop>());
      final wrong = result as WrongDrop;
      expect(wrong.expected, Chemicals.naoh);
      expect(wrong.actual, Chemicals.hcl);
      expect(wrong.outOfOrder, isTrue, reason: 'HCl is used later, in the burette');
      expect(lab.stepIndex, 0);
      expect(lab.volumeMl, 0);
      expect(lab.mistakes, 1);

      final distractor = lab.attemptAdd(Chemicals.h2o2) as WrongDrop;
      expect(distractor.outOfOrder, isFalse);
      expect(distractor.hint, isNotNull, reason: 'the lab explains why H₂O₂ is not used');
      expect(lab.mistakes, 2);
    });

    test('a wrong chemical on the titration step is still a mistake', () {
      final lab = LabController(repo.byId('acid_base_titration'))
        ..attemptAdd(Chemicals.naoh)
        ..attemptAdd(Chemicals.phenolphthalein);
      expect(lab.attemptAdd(Chemicals.naoh), isA<WrongDrop>());
      expect(lab.titrantReady, isFalse);
      expect(lab.mistakes, 1);
    });

    test('oxygen preparation: MnO₂, water, H₂O₂, glowing splinter; reset clears state', () {
      final lab = LabController(repo.byId('oxygen_preparation'));
      expect(lab.attemptAdd(Chemicals.h2o2), isA<WrongDrop>()); // MnO₂ goes in first
      lab
        ..attemptAdd(Chemicals.mno2)
        ..attemptAdd(Chemicals.water);
      expect(lab.solidColor, Chemicals.mno2.color, reason: 'MnO₂ is a solid that stays in the flask');
      expect(lab.attemptAdd(Chemicals.splint), isA<WrongDrop>(), reason: 'no gas to test yet');
      lab.attemptAdd(Chemicals.h2o2);
      expect(lab.isBubbling, isTrue);
      expect(lab.gasLabel, 'O₂ ↑');
      expect(lab.attemptAdd(Chemicals.splint), isA<PracticalCompleted>());
      expect(lab.lastObservation!.en, contains('bursts into flame'));
      expect(lab.mistakes, 2);

      lab.reset();
      expect(lab.stepIndex, 0);
      expect(lab.isBubbling, isFalse);
      expect(lab.solidColor, isNull);
      expect(lab.fillLevel, 0);
      expect(lab.mistakes, 0);
    });

    test('hydrochloric acid with MnO₂ is refused with a safety reason', () {
      final lab = LabController(repo.byId('oxygen_preparation'));
      final wrong = lab.attemptAdd(Chemicals.hcl) as WrongDrop;
      expect(wrong.hint!.en, contains('chlorine'));
    });
  });

  group('lab definitions', () {
    // Where labs appear in a syllabus is data (see practical_guide_test.dart);
    // the repository only defines the interactive labs themselves.
    test('the hand-built labs are defined with unique ids', () {
      expect(repo.all.map((p) => p.id), [
        'acid_base_titration',
        'oxygen_preparation',
        'oxalic_acid_titration',
        'hcl_sodium_carbonate_titration',
        'kmno4_oxalic_titration',
        'kmno4_mohr_salt_titration',
      ]);
      expect(repo.byId('oxygen_preparation').steps, hasLength(4));
    });

    test('every step says honestly how its amount is handled', () {
      for (final p in repo.all) {
        for (final (i, step) in p.steps.indexed) {
          final where = '${p.id} step ${i + 1}';
          // Exactly the titration steps have a burette, and only they.
          expect(step.titration != null, step.amount == StepAmount.titration, reason: where);
          if (step.amount == StepAmount.fixed) expect(step.volumeMl, greaterThan(0), reason: where);
        }
        // Each shelf has something wrong to learn from.
        final used = {for (final s in p.steps) s.requiredChemicalId};
        expect(p.chemicals.any((c) => !used.contains(c.id)), isTrue, reason: p.id);
        // Steps only use chemicals on this lab's shelf.
        for (final id in used) {
          expect(p.chemicals.map((c) => c.id), contains(id), reason: '${p.id}: $id');
        }
      }
      expect(repo.byId('acid_base_titration').calculation, isNotNull);
      expect(repo.byId('oxalic_acid_titration').calculation, isNotNull);
    });
  });

  group('localisation', () {
    const en = EnStrings();
    const hi = HiStrings();

    test('English Smart Warning keeps the exact spec wording', () {
      expect(
        en.wrongDropMessage(en.chemical(Chemicals.naoh), en.chemical(Chemicals.hcl)),
        'Warning: Wrong Action! You were supposed to add Sodium Hydroxide (NaOH), '
        'but you added Hydrochloric Acid (HCl). Please try again.',
      );
    });

    test('Hindi translates names but keeps formulae', () {
      expect(hi.chemical(Chemicals.hcl), 'हाइड्रोक्लोरिक अम्ल (HCl)');
      expect(
        hi.wrongDropMessage(hi.chemical(Chemicals.naoh), hi.chemical(Chemicals.hcl)),
        'चेतावनी: गलत क्रिया! आपको सोडियम हाइड्रॉक्साइड (NaOH) डालना था, '
        'लेकिन आपने हाइड्रोक्लोरिक अम्ल (HCl) डाल दिया। कृपया पुनः प्रयास करें।',
      );
      // A chemical with no real formula is translated on the bottle too.
      expect(Chemicals.phenolphthalein.label(AppLanguage.en), 'Phenolphthalein');
      expect(Chemicals.phenolphthalein.label(AppLanguage.hi), 'फ़ीनॉल्फ़्थेलिन');
      expect(Chemicals.hcl.label(AppLanguage.hi), 'HCl');
    });

    test('every lab and chemical has a real Hindi translation', () {
      final devanagari = RegExp('[ऀ-ॿ]');
      void check(LocalizedText t, String where) {
        expect(t.en.trim(), isNotEmpty, reason: '$where: English missing');
        expect(t.hi, matches(devanagari), reason: '$where: Hindi missing ("${t.hi}")');
      }

      for (final c in Chemicals.all) {
        check(c.name, 'chemical ${c.id}');
        if (c.hazard != null) check(c.hazard!, 'hazard ${c.id}');
      }
      for (final p in repo.all) {
        check(p.title, '${p.id} title');
        check(p.description, '${p.id} description');
        check(p.aim, '${p.id} aim');
        check(p.conclusion, '${p.id} conclusion');
        for (final e in p.hints.entries) {
          check(e.value, '${p.id} hint for ${e.key}');
        }
        for (final (i, step) in p.steps.indexed) {
          check(step.instruction, '${p.id} step ${i + 1} instruction');
          check(step.observation, '${p.id} step ${i + 1} observation');
          if (step.titration case final x?) {
            check(x.duringObservation, '${p.id} step ${i + 1} burette');
            check(x.nearObservation, '${p.id} step ${i + 1} near end point');
          }
        }
      }
    });
  });
}
