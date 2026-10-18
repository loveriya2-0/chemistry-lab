import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/practicals_repository.dart';
import '../l10n/localized_text.dart';
import '../models/lab_step.dart';
import '../models/practical.dart';

/// Pages of the first-time lab tutorial, in order.
enum TutorialStep { welcome, shelf, beaker, progress, demo, wrongChoice, reset, completion, tryIt, wellDone }

/// The first-time lab tutorial: whether it has been seen, and the tiny
/// practice experiment it runs.
///
/// The practice experiment is a [Practical] like any other, so the real
/// shelf, beaker and validation ([LabController]) are used — but on its own
/// controller, never the real lab's, and nothing about it is saved except
/// the "seen" flag.
abstract final class LabTutorial {
  static const seenKey = 'lab_tutorial_seen';

  static bool isSeen(SharedPreferences prefs) => prefs.getBool(seenKey) ?? false;

  static Future<void> markSeen(SharedPreferences prefs) => prefs.setBool(seenKey, true);

  /// The guided drag: put distilled water in the beaker. Hydrochloric acid
  /// is on the shelf as the wrong choice, and comes first so the student
  /// has to read the labels.
  static const practical = Practical(
    id: 'lab_tutorial',
    title: LocalizedText(en: 'Practice: add water', hi: 'अभ्यास: जल डालें'),
    description: LocalizedText(
      en: 'A one-step practice run to learn how the lab works. Nothing is saved.',
      hi: 'लैब कैसे काम करती है, यह सीखने के लिए एक चरण का अभ्यास। कुछ भी सहेजा नहीं जाता।',
    ),
    aim: LocalizedText(
      en: 'To learn how to drag a chemical from the shelf into the beaker.',
      hi: 'शेल्फ़ से रसायन को खींचकर बीकर में डालना सीखना।',
    ),
    icon: Icons.school_rounded,
    accent: Color(0xFF4338CA),
    chemicals: [Chemicals.hcl, Chemicals.water],
    beakerCapacityMl: 40,
    steps: [
      LabStep(
        instruction: LocalizedText(en: 'Pour Distilled Water (H₂O) into the beaker', hi: 'बीकर में आसुत जल (H₂O) डालें'),
        requiredChemicalId: 'h2o',
        volumeMl: 20,
        resultColor: Color(0xFFBFE6FF),
        observation: LocalizedText(en: 'The water is in the beaker.', hi: 'जल बीकर में आ गया।'),
      ),
    ],
    hints: {
      'hcl': LocalizedText(
        en: 'Hydrochloric acid is not needed for this step — here you only need distilled water.',
        hi: 'इस चरण में हाइड्रोक्लोरिक अम्ल की आवश्यकता नहीं है — यहाँ केवल आसुत जल चाहिए।',
      ),
    },
    conclusion: LocalizedText(
      en: 'You poured the right chemical. Every lab works this way.',
      hi: 'आपने सही रसायन डाला। हर लैब इसी तरह काम करती है।',
    ),
  );
}
