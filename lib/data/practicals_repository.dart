import 'package:flutter/material.dart';

import '../l10n/localized_text.dart';
import '../models/chemical.dart';
import '../models/lab_step.dart';
import '../models/practical.dart';

/// Shared chemical catalogue. Each practical puts the chemicals it needs on
/// its shelf plus at least one distractor, so students have to choose.
abstract final class Chemicals {
  static const water = Chemical(
    id: 'h2o',
    name: LocalizedText(en: 'Distilled Water', hi: 'आसुत जल'),
    formula: 'H₂O',
    color: Color(0xFFBFE6FF),
  );
  static const hcl = Chemical(
    id: 'hcl',
    name: LocalizedText(en: 'Hydrochloric Acid', hi: 'हाइड्रोक्लोरिक अम्ल'),
    formula: 'HCl',
    color: Color(0xFFFFF59D),
    hazard: LocalizedText(
      en: 'Corrosive – avoid skin contact.',
      hi: 'संक्षारक – त्वचा के संपर्क से बचें।',
    ),
  );
  static const naoh = Chemical(
    id: 'naoh',
    name: LocalizedText(en: 'Sodium Hydroxide', hi: 'सोडियम हाइड्रॉक्साइड'),
    formula: 'NaOH',
    color: Color(0xFFE1F5FE),
    hazard: LocalizedText(
      en: 'Caustic – causes burns.',
      hi: 'दाहक – त्वचा को जला सकता है।',
    ),
  );
  static const phenolphthalein = Chemical(
    id: 'phph',
    name: LocalizedText(en: 'Phenolphthalein', hi: 'फ़ीनॉल्फ़्थेलिन'),
    formula: 'Phenolphthalein',
    color: Color(0xFFF8F8F8),
  );
  static const h2o2 = Chemical(
    id: 'h2o2',
    name: LocalizedText(en: 'Hydrogen Peroxide', hi: 'हाइड्रोजन परॉक्साइड'),
    formula: 'H₂O₂',
    color: Color(0xFFDDEFFF),
    hazard: LocalizedText(
      en: 'Oxidiser – keep away from flames.',
      hi: 'ऑक्सीकारक – आग की लपटों से दूर रखें।',
    ),
  );
  static const mno2 = Chemical(
    id: 'mno2',
    name: LocalizedText(en: 'Manganese Dioxide', hi: 'मैंगनीज़ डाइऑक्साइड'),
    formula: 'MnO₂',
    color: Color(0xFF3A3A3A),
    state: ChemicalState.solid,
  );

  static const splint = Chemical(
    id: 'splint',
    name: LocalizedText(en: 'Glowing Splinter', hi: 'सुलगती तीली'),
    formula: 'Glowing Splinter',
    color: Color(0xFFB7793F),
    state: ChemicalState.tool,
    hazard: LocalizedText(
      en: 'Handle with care and keep it away from anything that can catch fire.',
      hi: 'सावधानी से पकड़ें और आग पकड़ने वाली हर चीज़ से दूर रखें।',
    ),
  );
  static const oxalicAcid = Chemical(
    id: 'oxalic',
    name: LocalizedText(en: 'Oxalic Acid', hi: 'ऑक्सैलिक अम्ल'),
    formula: 'H₂C₂O₄',
    color: Color(0xFFF4F8FB),
    hazard: LocalizedText(
      en: 'Harmful if swallowed and irritates the skin — never taste it.',
      hi: 'निगलने पर हानिकारक और त्वचा में जलन करता है — कभी न चखें।',
    ),
  );

  static const sodiumCarbonate = Chemical(
    id: 'na2co3',
    name: LocalizedText(en: 'Sodium Carbonate', hi: 'सोडियम कार्बोनेट'),
    formula: 'Na₂CO₃',
    color: Color(0xFFF4F8FB),
    hazard: LocalizedText(
      en: 'Irritates the eyes — wear goggles.',
      hi: 'आँखों में जलन करता है — चश्मा पहनें।',
    ),
  );
  static const methylOrange = Chemical(
    id: 'methyl_orange',
    name: LocalizedText(en: 'Methyl Orange', hi: 'मेथिल ऑरेंज'),
    formula: 'Methyl Orange',
    color: Color(0xFFF59E0B),
    hazard: LocalizedText(
      en: 'Poisonous if swallowed — use only a drop or two.',
      hi: 'निगलने पर विषैला — केवल एक-दो बूँद उपयोग करें।',
    ),
  );
  static const kmno4 = Chemical(
    id: 'kmno4',
    name: LocalizedText(en: 'Potassium Permanganate', hi: 'पोटैशियम परमैंगनेट'),
    formula: 'KMnO₄',
    color: Color(0xFF7B1FA2),
    hazard: LocalizedText(
      en: 'Strong oxidiser that stains skin brown — keep away from other chemicals and wear gloves.',
      hi: 'प्रबल ऑक्सीकारक जो त्वचा पर भूरे दाग छोड़ता है — अन्य रसायनों से दूर रखें और दस्ताने पहनें।',
    ),
  );
  static const dilSulphuricAcid = Chemical(
    id: 'dil_h2so4',
    name: LocalizedText(en: 'Dilute Sulphuric Acid', hi: 'तनु सल्फ़्यूरिक अम्ल'),
    formula: 'H₂SO₄',
    color: Color(0xFFF7FAFC),
    hazard: LocalizedText(
      en: 'Corrosive – avoid skin and eye contact.',
      hi: 'संक्षारक – त्वचा और आँखों के संपर्क से बचें।',
    ),
  );
  static const mohrSalt = Chemical(
    id: 'mohr_salt',
    name: LocalizedText(en: "Mohr's Salt (Ferrous Ammonium Sulphate)", hi: 'मोर लवण (फ़ेरस अमोनियम सल्फ़ेट)'),
    formula: 'FeSO₄·(NH₄)₂SO₄·6H₂O',
    color: Color(0xFFE3F1E0),
    hazard: LocalizedText(
      en: 'Harmful if swallowed — wash your hands after use.',
      hi: 'निगलने पर हानिकारक — उपयोग के बाद हाथ धोएँ।',
    ),
  );
  static const burner = Chemical(
    id: 'burner',
    name: LocalizedText(en: 'Burner', hi: 'बर्नर'),
    formula: 'Burner',
    color: Color(0xFFF97316),
    state: ChemicalState.tool,
    hazard: LocalizedText(
      en: 'Hot flame — keep hair, sleeves and papers away.',
      hi: 'गरम लौ — बाल, आस्तीन और कागज़ दूर रखें।',
    ),
  );

  static const all = [
    water, hcl, naoh, phenolphthalein, h2o2, mno2, splint, oxalicAcid,
    sodiumCarbonate, methylOrange, kmno4, dilSulphuricAcid, mohrSalt, burner,
  ];
}

/// Interactive virtual labs (chemicals, steps, colours). Where each lab is
/// offered in a syllabus is data: see `labs` in the board manifest; the
/// real-lab guide for each is in `assets/content/library/practical-guides.json`.
/// All text is [LocalizedText], so every lab must carry English and Hindi.
class PracticalsRepository {
  const PracticalsRepository({this.reactionLabs = const []});

  /// Labs built by the reaction engine from verified content data
  /// (see `lib/lab/reaction_labs.dart`).
  final List<Practical> reactionLabs;

  static const _empty = Color(0x00FFFFFF);
  static const _colourless = Color(0xFFEAF6FC);
  static const _pink = Color(0xFFFF4FA3);
  static const _grey = Color(0xFF6B6B6B);

  /// HCl from a burette into a pipetted volume of NaOH. The NaOH is
  /// 0.080 M (unknown to the student), so the end point is at 8.0 mL.
  static const _titration = Practical(
    id: 'acid_base_titration',
    title: LocalizedText(en: 'Acid-Base Titration', hi: 'अम्ल-क्षारक अनुमापन'),
    description: LocalizedText(
      en: 'Find the concentration of a sodium hydroxide solution by titrating '
          'it with 0.1 M HCl, using phenolphthalein to show the end point.',
      hi: '0.1 M HCl से अनुमापन करके सोडियम हाइड्रॉक्साइड विलयन की सांद्रता ज्ञात करें; '
          'अंत्य बिंदु फ़ीनॉल्फ़्थेलिन से पहचानें।',
    ),
    aim: LocalizedText(
      en: 'To find the concentration of a sodium hydroxide solution by titrating it '
          'against 0.1 M hydrochloric acid, using phenolphthalein as the indicator.',
      hi: 'फ़ीनॉल्फ़्थेलिन सूचक का उपयोग करके 0.1 M हाइड्रोक्लोरिक अम्ल के साथ अनुमापन '
          'द्वारा सोडियम हाइड्रॉक्साइड विलयन की सांद्रता ज्ञात करना।',
    ),
    icon: Icons.science_rounded,
    accent: Color(0xFFEC4899),
    chemicals: [Chemicals.naoh, Chemicals.phenolphthalein, Chemicals.hcl, Chemicals.h2o2],
    beakerCapacityMl: 30,
    steps: [
      LabStep(
        instruction: LocalizedText(
          en: 'Pipette 10.0 mL of Sodium Hydroxide (NaOH) solution into the flask',
          hi: 'फ़्लास्क में 10.0 mL सोडियम हाइड्रॉक्साइड (NaOH) विलयन पिपेट से डालें',
        ),
        requiredChemicalId: 'naoh',
        volumeMl: 10,
        amount: StepAmount.fixed,
        resultColor: Color(0xFFE6F4FB),
        observation: LocalizedText(
          en: '10.0 mL of a clear, colourless basic solution is in the flask.',
          hi: 'फ़्लास्क में 10.0 mL स्वच्छ, रंगहीन क्षारकीय विलयन है।',
        ),
      ),
      LabStep(
        instruction: LocalizedText(
          en: 'Add 2 drops of Phenolphthalein indicator',
          hi: 'फ़ीनॉल्फ़्थेलिन सूचक की 2 बूँदें डालें',
        ),
        requiredChemicalId: 'phph',
        volumeMl: 0.1,
        resultColor: _pink,
        observation: LocalizedText(
          en: 'The solution turns pink: phenolphthalein is pink in a basic solution.',
          hi: 'विलयन गुलाबी हो जाता है: फ़ीनॉल्फ़्थेलिन क्षारकीय विलयन में गुलाबी होता है।',
        ),
      ),
      LabStep(
        instruction: LocalizedText(
          en: 'Fill the burette with 0.1 M HCl and run it in until the pink just disappears',
          hi: 'ब्यूरेट में 0.1 M HCl भरें और गुलाबी रंग ठीक गायब होने तक डालें',
        ),
        requiredChemicalId: 'hcl',
        volumeMl: 0,
        amount: StepAmount.titration,
        titration: TitrationSpec(
          endPointMl: 8.0,
          duringObservation: LocalizedText(
            en: 'Where the acid lands the pink disappears for a moment, then comes back on swirling.',
            hi: 'जहाँ अम्ल गिरता है वहाँ गुलाबी रंग क्षण भर गायब होता है, फिर घुमाने पर लौट आता है।',
          ),
          nearObservation: LocalizedText(
            en: 'The pink now takes longer to come back on swirling — the end point is close. Add 0.1 mL at a time.',
            hi: 'अब घुमाने पर गुलाबी रंग लौटने में अधिक समय लेता है — अंत्य बिंदु निकट है। एक बार में 0.1 mL डालें।',
          ),
          overshootColor: _colourless,
        ),
        resultColor: _colourless,
        observation: LocalizedText(
          en: 'The pink colour disappears and stays gone: this is the end point. All the NaOH has been neutralised.',
          hi: 'गुलाबी रंग गायब हो जाता है और लौटता नहीं: यही अंत्य बिंदु है। सारा NaOH उदासीन हो गया है।',
        ),
      ),
    ],
    calculation: TitrationCalculation(
      knownFormula: 'HCl',
      knownMolarity: 0.1,
      unknownFormula: 'NaOH',
      unknownVolumeMl: 10,
    ),
    hints: {
      'h2o2': LocalizedText(
        en: 'Hydrogen peroxide is not used in this titration. Only the base, the indicator and the acid are needed.',
        hi: 'इस अनुमापन में हाइड्रोजन परॉक्साइड का उपयोग नहीं होता। केवल क्षारक, सूचक और अम्ल चाहिए।',
      ),
    },
    conclusion: LocalizedText(
      en: 'NaOH + HCl → NaCl + H₂O. At the end point all the NaOH has reacted. Because the '
          'acid and base react in a 1 : 1 ratio, c(NaOH) = c(HCl) × V(HCl) ÷ V(NaOH).',
      hi: 'NaOH + HCl → NaCl + H₂O. अंत्य बिंदु पर सारा NaOH अभिक्रिया कर चुका होता है। क्योंकि '
          'अम्ल और क्षारक 1 : 1 अनुपात में अभिक्रिया करते हैं, c(NaOH) = c(HCl) × V(HCl) ÷ V(NaOH)।',
    ),
  );

  static const _oxygen = Practical(
    id: 'oxygen_preparation',
    title: LocalizedText(en: 'Oxygen Gas Preparation', hi: 'ऑक्सीजन गैस का निर्माण'),
    description: LocalizedText(
      en: 'Decompose hydrogen peroxide using a manganese dioxide '
          'catalyst, then test the gas with a glowing splinter.',
      hi: 'मैंगनीज़ डाइऑक्साइड उत्प्रेरक की सहायता से हाइड्रोजन परॉक्साइड का अपघटन करें, '
          'फिर सुलगती तीली से गैस का परीक्षण करें।',
    ),
    aim: LocalizedText(
      en: 'To prepare oxygen by decomposing hydrogen peroxide with manganese dioxide '
          'as a catalyst, and to test the gas.',
      hi: 'मैंगनीज़ डाइऑक्साइड को उत्प्रेरक के रूप में उपयोग करके हाइड्रोजन परॉक्साइड के '
          'अपघटन से ऑक्सीजन बनाना और गैस का परीक्षण करना।',
    ),
    icon: Icons.bubble_chart_rounded,
    accent: Color(0xFF0EA5E9),
    chemicals: [Chemicals.mno2, Chemicals.water, Chemicals.h2o2, Chemicals.splint, Chemicals.hcl],
    beakerCapacityMl: 40,
    steps: [
      LabStep(
        instruction: LocalizedText(
          en: 'Put a spatula-tip of Manganese Dioxide (MnO₂) into the flask',
          hi: 'फ़्लास्क में स्पैचुला की नोक भर मैंगनीज़ डाइऑक्साइड (MnO₂) डालें',
        ),
        requiredChemicalId: 'mno2',
        volumeMl: 0,
        resultColor: _empty,
        observation: LocalizedText(
          en: 'Black manganese dioxide powder is at the bottom of the flask.',
          hi: 'फ़्लास्क की तली में काला मैंगनीज़ डाइऑक्साइड चूर्ण है।',
        ),
      ),
      LabStep(
        instruction: LocalizedText(
          en: 'Add a little Distilled Water (H₂O) to cover the end of the thistle funnel',
          hi: 'थिसल कीप का सिरा डुबाने के लिए थोड़ा आसुत जल (H₂O) डालें',
        ),
        requiredChemicalId: 'h2o',
        volumeMl: 10,
        resultColor: _grey,
        observation: LocalizedText(
          en: 'The black powder does not dissolve in the water.',
          hi: 'काला चूर्ण जल में नहीं घुलता।',
        ),
      ),
      LabStep(
        instruction: LocalizedText(
          en: 'Pour about 20 mL of Hydrogen Peroxide (H₂O₂) slowly through the thistle funnel',
          hi: 'थिसल कीप से लगभग 20 mL हाइड्रोजन परॉक्साइड (H₂O₂) धीरे-धीरे डालें',
        ),
        requiredChemicalId: 'h2o2',
        volumeMl: 20,
        resultColor: _grey,
        observation: LocalizedText(
          en: 'Brisk effervescence: a colourless gas is given off.',
          hi: 'तेज़ बुदबुदाहट: एक रंगहीन गैस निकलती है।',
        ),
        bubbling: true,
        gasLabel: 'O₂ ↑',
      ),
      LabStep(
        instruction: LocalizedText(
          en: 'Test the gas: bring a Glowing Splinter to it',
          hi: 'गैस का परीक्षण करें: उसके पास सुलगती तीली लाएँ',
        ),
        requiredChemicalId: 'splint',
        volumeMl: 0,
        resultColor: _grey,
        observation: LocalizedText(
          en: 'The glowing splinter bursts into flame: the gas is oxygen.',
          hi: 'सुलगती तीली जल उठती है: यह गैस ऑक्सीजन है।',
        ),
        bubbling: true,
        gasLabel: 'O₂ ↑',
      ),
    ],
    hints: {
      'hcl': LocalizedText(
        en: 'Hydrochloric acid is not used here. With manganese dioxide, concentrated HCl gives chlorine — a poisonous gas — not oxygen.',
        hi: 'यहाँ हाइड्रोक्लोरिक अम्ल का उपयोग नहीं होता। मैंगनीज़ डाइऑक्साइड के साथ सांद्र HCl ऑक्सीजन नहीं, बल्कि क्लोरीन — एक विषैली गैस — देता है।',
      ),
    },
    conclusion: LocalizedText(
      en: '2H₂O₂ → 2H₂O + O₂ (MnO₂ catalyst). MnO₂ speeds up the decomposition but is '
          'not used up, so it is a catalyst. The gas relights a glowing splinter, so it is oxygen.',
      hi: '2H₂O₂ → 2H₂O + O₂ (MnO₂ उत्प्रेरक)। MnO₂ अपघटन को तेज़ करता है पर स्वयं खर्च '
          'नहीं होता, इसलिए यह उत्प्रेरक है। गैस सुलगती तीली को जला देती है, इसलिए यह ऑक्सीजन है।',
    ),
  );

  /// Class 11 practical E, the NaOH–oxalic acid part: NaOH from a burette
  /// into a pipetted volume of 0.05 M oxalic acid. The NaOH is 0.080 M
  /// (unknown to the student), so the end point is at 12.5 mL.
  static const _oxalic = Practical(
    id: 'oxalic_acid_titration',
    title: LocalizedText(en: 'Titration: NaOH against Oxalic Acid', hi: 'अनुमापन: ऑक्सैलिक अम्ल के विरुद्ध NaOH'),
    description: LocalizedText(
      en: 'Find the concentration of a sodium hydroxide solution by titrating it '
          'against a standard 0.05 M oxalic acid solution, with phenolphthalein.',
      hi: 'मानक 0.05 M ऑक्सैलिक अम्ल विलयन के विरुद्ध अनुमापन करके सोडियम हाइड्रॉक्साइड '
          'विलयन की सांद्रता ज्ञात करें; सूचक फ़ीनॉल्फ़्थेलिन।',
    ),
    aim: LocalizedText(
      en: 'To find the concentration of a sodium hydroxide solution by titrating it '
          'against a standard solution of oxalic acid.',
      hi: 'ऑक्सैलिक अम्ल के मानक विलयन के विरुद्ध अनुमापन द्वारा सोडियम हाइड्रॉक्साइड '
          'विलयन की सांद्रता ज्ञात करना।',
    ),
    icon: Icons.science_outlined,
    accent: Color(0xFF7C3AED),
    chemicals: [Chemicals.oxalicAcid, Chemicals.phenolphthalein, Chemicals.naoh, Chemicals.hcl],
    beakerCapacityMl: 40,
    steps: [
      LabStep(
        instruction: LocalizedText(
          en: 'Pipette 10.0 mL of 0.05 M Oxalic Acid (H₂C₂O₄) solution into the flask',
          hi: 'फ़्लास्क में 0.05 M ऑक्सैलिक अम्ल (H₂C₂O₄) विलयन का 10.0 mL पिपेट से डालें',
        ),
        requiredChemicalId: 'oxalic',
        volumeMl: 10,
        amount: StepAmount.fixed,
        resultColor: Color(0xFFF4F8FB),
        observation: LocalizedText(
          en: '10.0 mL of the colourless standard oxalic acid solution is in the flask.',
          hi: 'फ़्लास्क में मानक ऑक्सैलिक अम्ल का 10.0 mL रंगहीन विलयन है।',
        ),
      ),
      LabStep(
        instruction: LocalizedText(
          en: 'Add 2 drops of Phenolphthalein indicator',
          hi: 'फ़ीनॉल्फ़्थेलिन सूचक की 2 बूँदें डालें',
        ),
        requiredChemicalId: 'phph',
        volumeMl: 0.1,
        resultColor: Color(0xFFF1F7FA),
        observation: LocalizedText(
          en: 'The solution stays colourless: phenolphthalein is colourless in an acidic solution.',
          hi: 'विलयन रंगहीन रहता है: फ़ीनॉल्फ़्थेलिन अम्लीय विलयन में रंगहीन होता है।',
        ),
      ),
      LabStep(
        instruction: LocalizedText(
          en: 'Fill the burette with the NaOH solution and run it in until a light pink just stays',
          hi: 'ब्यूरेट में NaOH विलयन भरें और हल्का गुलाबी रंग ठीक स्थायी होने तक डालें',
        ),
        requiredChemicalId: 'naoh',
        volumeMl: 0,
        amount: StepAmount.titration,
        titration: TitrationSpec(
          endPointMl: 12.5,
          duringObservation: LocalizedText(
            en: 'Where the NaOH lands a pink colour appears for a moment, then disappears on swirling.',
            hi: 'जहाँ NaOH गिरता है वहाँ क्षण भर गुलाबी रंग दिखता है, फिर घुमाने पर गायब हो जाता है।',
          ),
          nearObservation: LocalizedText(
            en: 'The pink now takes longer to disappear on swirling — the end point is close. Add 0.1 mL at a time.',
            hi: 'अब घुमाने पर गुलाबी रंग गायब होने में अधिक समय लेता है — अंत्य बिंदु निकट है। एक बार में 0.1 mL डालें।',
          ),
          overshootColor: _pink,
        ),
        resultColor: Color(0xFFF8BBD9),
        observation: LocalizedText(
          en: 'A light pink colour appears and stays on swirling: this is the end point.',
          hi: 'हल्का गुलाबी रंग आता है और घुमाने पर भी बना रहता है: यही अंत्य बिंदु है।',
        ),
      ),
    ],
    calculation: TitrationCalculation(
      knownFormula: 'H₂C₂O₄',
      knownMolarity: 0.05,
      knownVolumeMl: 10,
      unknownFormula: 'NaOH',
      unknownCoefficient: 2,
    ),
    hints: {
      'hcl': LocalizedText(
        en: 'Hydrochloric acid is not used in this titration: the acid here is the standard oxalic acid solution.',
        hi: 'इस अनुमापन में हाइड्रोक्लोरिक अम्ल का उपयोग नहीं होता: यहाँ अम्ल मानक ऑक्सैलिक अम्ल विलयन है।',
      ),
    },
    conclusion: LocalizedText(
      en: 'H₂C₂O₄ + 2NaOH → Na₂C₂O₄ + 2H₂O. One mole of oxalic acid reacts with two moles of '
          'NaOH, so c(NaOH) = 2 × c(H₂C₂O₄) × V(H₂C₂O₄) ÷ V(NaOH).',
      hi: 'H₂C₂O₄ + 2NaOH → Na₂C₂O₄ + 2H₂O. ऑक्सैलिक अम्ल का एक मोल NaOH के दो मोल से '
          'अभिक्रिया करता है, इसलिए c(NaOH) = 2 × c(H₂C₂O₄) × V(H₂C₂O₄) ÷ V(NaOH)।',
    ),
  );

  /// Class 11 practical E, the HCl–sodium carbonate part: HCl from a
  /// burette into a pipetted volume of 0.05 M Na₂CO₃ with methyl orange.
  /// The HCl is 0.100 M (unknown to the student), so the end point is at
  /// 10.0 mL (2 mol HCl per mol Na₂CO₃).
  static const _carbonate = Practical(
    id: 'hcl_sodium_carbonate_titration',
    title: LocalizedText(en: 'Titration: HCl against Sodium Carbonate', hi: 'अनुमापन: सोडियम कार्बोनेट के विरुद्ध HCl'),
    description: LocalizedText(
      en: 'Find the concentration of hydrochloric acid by titrating it against a standard '
          '0.05 M sodium carbonate solution, with methyl orange.',
      hi: 'मानक 0.05 M सोडियम कार्बोनेट विलयन के विरुद्ध अनुमापन करके हाइड्रोक्लोरिक अम्ल की '
          'सांद्रता ज्ञात करें; सूचक मेथिल ऑरेंज।',
    ),
    aim: LocalizedText(
      en: 'To find the concentration of hydrochloric acid by titrating it against a standard '
          'solution of sodium carbonate, using methyl orange as the indicator.',
      hi: 'मेथिल ऑरेंज सूचक का उपयोग करके, सोडियम कार्बोनेट के मानक विलयन के विरुद्ध अनुमापन '
          'द्वारा हाइड्रोक्लोरिक अम्ल की सांद्रता ज्ञात करना।',
    ),
    icon: Icons.science_outlined,
    accent: Color(0xFFD97706),
    chemicals: [Chemicals.sodiumCarbonate, Chemicals.phenolphthalein, Chemicals.methylOrange, Chemicals.hcl, Chemicals.naoh],
    beakerCapacityMl: 40,
    steps: [
      LabStep(
        instruction: LocalizedText(
          en: 'Pipette 10.0 mL of 0.05 M Sodium Carbonate (Na₂CO₃) solution into the flask',
          hi: 'फ़्लास्क में 0.05 M सोडियम कार्बोनेट (Na₂CO₃) विलयन का 10.0 mL पिपेट से डालें',
        ),
        requiredChemicalId: 'na2co3',
        volumeMl: 10,
        amount: StepAmount.fixed,
        resultColor: Color(0xFFF4F8FB),
        observation: LocalizedText(
          en: '10.0 mL of the colourless standard sodium carbonate solution is in the flask.',
          hi: 'फ़्लास्क में मानक सोडियम कार्बोनेट का 10.0 mL रंगहीन विलयन है।',
        ),
      ),
      LabStep(
        instruction: LocalizedText(
          en: 'Add 1–2 drops of Methyl Orange indicator',
          hi: 'मेथिल ऑरेंज सूचक की 1–2 बूँदें डालें',
        ),
        requiredChemicalId: 'methyl_orange',
        volumeMl: 0.1,
        resultColor: Color(0xFFF2C94C),
        observation: LocalizedText(
          en: 'The solution turns yellow: methyl orange is yellow in a basic solution.',
          hi: 'विलयन पीला हो जाता है: मेथिल ऑरेंज क्षारकीय विलयन में पीला होता है।',
        ),
      ),
      LabStep(
        instruction: LocalizedText(
          en: 'Fill the burette with the HCl and run it in until the yellow just turns orange-red',
          hi: 'ब्यूरेट में HCl भरें और पीला रंग ठीक नारंगी-लाल होने तक डालें',
        ),
        requiredChemicalId: 'hcl',
        volumeMl: 0,
        amount: StepAmount.titration,
        titration: TitrationSpec(
          endPointMl: 10.0,
          duringObservation: LocalizedText(
            en: 'Where the acid lands the colour turns orange-red for a moment, then yellow again on swirling.',
            hi: 'जहाँ अम्ल गिरता है वहाँ रंग क्षण भर नारंगी-लाल होता है, फिर घुमाने पर पीला हो जाता है।',
          ),
          nearObservation: LocalizedText(
            en: 'The orange-red now takes longer to turn back to yellow — the end point is close. Add 0.1 mL at a time.',
            hi: 'अब नारंगी-लाल रंग को पीला होने में अधिक समय लगता है — अंत्य बिंदु निकट है। एक बार में 0.1 mL डालें।',
          ),
          overshootColor: Color(0xFFE8505B),
        ),
        resultColor: Color(0xFFF08A4B),
        observation: LocalizedText(
          en: 'The yellow changes to orange-red and stays on swirling: this is the end point.',
          hi: 'पीला रंग नारंगी-लाल हो जाता है और घुमाने पर भी बना रहता है: यही अंत्य बिंदु है।',
        ),
      ),
    ],
    calculation: TitrationCalculation(
      knownFormula: 'Na₂CO₃',
      knownMolarity: 0.05,
      knownVolumeMl: 10,
      unknownFormula: 'HCl',
      unknownCoefficient: 2,
    ),
    hints: {
      'phph': LocalizedText(
        en: 'Phenolphthalein is not used here: it changes colour when only half the carbonate has reacted (to NaHCO₃). Methyl orange changes at the true end point.',
        hi: 'यहाँ फ़ीनॉल्फ़्थेलिन का उपयोग नहीं होता: इसका रंग तब बदलता है जब केवल आधा कार्बोनेट (NaHCO₃ तक) अभिक्रिया करता है। मेथिल ऑरेंज सही अंत्य बिंदु पर रंग बदलता है।',
      ),
      'naoh': LocalizedText(
        en: 'Sodium hydroxide is not used here: the base being titrated is the standard sodium carbonate solution.',
        hi: 'यहाँ सोडियम हाइड्रॉक्साइड का उपयोग नहीं होता: अनुमापित क्षारक मानक सोडियम कार्बोनेट विलयन है।',
      ),
    },
    conclusion: LocalizedText(
      en: 'Na₂CO₃ + 2HCl → 2NaCl + H₂O + CO₂. One mole of sodium carbonate reacts with two moles of HCl, '
          'so c(HCl) = 2 × c(Na₂CO₃) × V(Na₂CO₃) ÷ V(HCl).',
      hi: 'Na₂CO₃ + 2HCl → 2NaCl + H₂O + CO₂. सोडियम कार्बोनेट का एक मोल HCl के दो मोल से अभिक्रिया '
          'करता है, इसलिए c(HCl) = 2 × c(Na₂CO₃) × V(Na₂CO₃) ÷ V(HCl)।',
    ),
  );

  /// Class 12 practical J, the oxalic acid part: KMnO₄ from a burette into
  /// warm, acidified 0.05 M oxalic acid. The KMnO₄ is 0.020 M (unknown to
  /// the student), so the end point is at 10.0 mL (2 MnO₄⁻ per 5 C₂O₄²⁻).
  static const _kmno4Oxalic = Practical(
    id: 'kmno4_oxalic_titration',
    title: LocalizedText(en: 'Titration: KMnO₄ against Oxalic Acid', hi: 'अनुमापन: ऑक्सैलिक अम्ल के विरुद्ध KMnO₄'),
    description: LocalizedText(
      en: 'Find the molarity of a potassium permanganate solution by titrating it against warm, '
          'acidified 0.05 M oxalic acid. KMnO₄ is its own indicator.',
      hi: 'गरम, अम्लीकृत 0.05 M ऑक्सैलिक अम्ल के विरुद्ध अनुमापन करके पोटैशियम परमैंगनेट विलयन की '
          'मोलरता ज्ञात करें। KMnO₄ स्वयं सूचक है।',
    ),
    aim: LocalizedText(
      en: 'To find the molarity of a potassium permanganate solution by titrating it against a '
          'standard solution of oxalic acid.',
      hi: 'ऑक्सैलिक अम्ल के मानक विलयन के विरुद्ध अनुमापन द्वारा पोटैशियम परमैंगनेट विलयन की '
          'मोलरता ज्ञात करना।',
    ),
    icon: Icons.science_rounded,
    accent: Color(0xFF7B1FA2),
    chemicals: [Chemicals.oxalicAcid, Chemicals.hcl, Chemicals.dilSulphuricAcid, Chemicals.burner, Chemicals.phenolphthalein, Chemicals.kmno4],
    beakerCapacityMl: 40,
    steps: [
      LabStep(
        instruction: LocalizedText(
          en: 'Pipette 10.0 mL of 0.05 M Oxalic Acid (H₂C₂O₄) solution into the flask',
          hi: 'फ़्लास्क में 0.05 M ऑक्सैलिक अम्ल (H₂C₂O₄) विलयन का 10.0 mL पिपेट से डालें',
        ),
        requiredChemicalId: 'oxalic',
        volumeMl: 10,
        amount: StepAmount.fixed,
        resultColor: Color(0xFFF4F8FB),
        observation: LocalizedText(
          en: '10.0 mL of the colourless standard oxalic acid solution is in the flask.',
          hi: 'फ़्लास्क में मानक ऑक्सैलिक अम्ल का 10.0 mL रंगहीन विलयन है।',
        ),
      ),
      LabStep(
        instruction: LocalizedText(
          en: 'Add about 10 mL (a test tube full) of Dilute Sulphuric Acid (H₂SO₄)',
          hi: 'लगभग 10 mL (एक परखनली भर) तनु सल्फ़्यूरिक अम्ल (H₂SO₄) डालें',
        ),
        requiredChemicalId: 'dil_h2so4',
        volumeMl: 10,
        resultColor: Color(0xFFF4F8FB),
        observation: LocalizedText(
          en: 'The solution is now acidic. Permanganate needs H⁺ ions to be reduced to colourless Mn²⁺.',
          hi: 'विलयन अब अम्लीय है। परमैंगनेट को रंगहीन Mn²⁺ में अपचयित होने के लिए H⁺ आयन चाहिए।',
        ),
      ),
      LabStep(
        instruction: LocalizedText(
          en: 'Warm the flask on the Burner to about 60–70 °C',
          hi: 'फ़्लास्क को बर्नर पर लगभग 60–70 °C तक गरम करें',
        ),
        requiredChemicalId: 'burner',
        volumeMl: 0,
        heating: true,
        resultColor: Color(0xFFF4F8FB),
        observation: LocalizedText(
          en: 'The acidified oxalic acid is warm. Cold oxalic acid reacts with KMnO₄ only slowly.',
          hi: 'अम्लीकृत ऑक्सैलिक अम्ल गरम है। ठंडा ऑक्सैलिक अम्ल KMnO₄ से बहुत धीरे अभिक्रिया करता है।',
        ),
      ),
      LabStep(
        instruction: LocalizedText(
          en: 'Fill the burette with KMnO₄ and run it in until a light pink colour just stays',
          hi: 'ब्यूरेट में KMnO₄ भरें और हल्का गुलाबी रंग ठीक स्थायी होने तक डालें',
        ),
        requiredChemicalId: 'kmno4',
        volumeMl: 0,
        amount: StepAmount.titration,
        titration: TitrationSpec(
          endPointMl: 10.0,
          duringObservation: LocalizedText(
            en: 'The purple KMnO₄ is decolourised as it mixes in.',
            hi: 'बैंगनी KMnO₄ मिलते ही रंगहीन हो जाता है।',
          ),
          nearObservation: LocalizedText(
            en: 'The pink colour now takes longer to disappear — the end point is close. Add 0.1 mL at a time.',
            hi: 'अब गुलाबी रंग गायब होने में अधिक समय लेता है — अंत्य बिंदु निकट है। एक बार में 0.1 mL डालें।',
          ),
          overshootColor: Color(0xFFD946A8),
        ),
        resultColor: Color(0xFFF9C9E3),
        observation: LocalizedText(
          en: 'One more drop gives a light pink colour that stays: this is the end point. KMnO₄ is its own indicator.',
          hi: 'एक और बूँद से हल्का गुलाबी रंग आता है जो बना रहता है: यही अंत्य बिंदु है। KMnO₄ स्वयं सूचक है।',
        ),
      ),
    ],
    calculation: TitrationCalculation(
      knownFormula: 'H₂C₂O₄',
      knownMolarity: 0.05,
      knownVolumeMl: 10,
      unknownFormula: 'KMnO₄',
      knownCoefficient: 5,
      unknownCoefficient: 2,
    ),
    hints: {
      'hcl': LocalizedText(
        en: 'Hydrochloric acid is not used to acidify: permanganate would oxidise chloride ions to chlorine, using up extra KMnO₄. Dilute sulphuric acid is used.',
        hi: 'अम्लीकरण के लिए हाइड्रोक्लोरिक अम्ल का उपयोग नहीं होता: परमैंगनेट क्लोराइड आयनों को क्लोरीन में ऑक्सीकृत करके अतिरिक्त KMnO₄ खर्च कर देगा। तनु सल्फ़्यूरिक अम्ल का उपयोग होता है।',
      ),
      'phph': LocalizedText(
        en: 'No indicator is needed: KMnO₄ itself shows the end point with its pink colour.',
        hi: 'किसी सूचक की आवश्यकता नहीं है: KMnO₄ स्वयं अपने गुलाबी रंग से अंत्य बिंदु दिखाता है।',
      ),
    },
    conclusion: LocalizedText(
      en: '5C₂O₄²⁻ + 2MnO₄⁻ + 16H⁺ → 2Mn²⁺ + 8H₂O + 10CO₂. Five moles of oxalate react with two moles '
          'of permanganate, so c(KMnO₄) = (2/5) × c(oxalic acid) × V(oxalic acid) ÷ V(KMnO₄).',
      hi: '5C₂O₄²⁻ + 2MnO₄⁻ + 16H⁺ → 2Mn²⁺ + 8H₂O + 10CO₂. ऑक्सैलेट के पाँच मोल परमैंगनेट के दो मोल से '
          'अभिक्रिया करते हैं, इसलिए c(KMnO₄) = (2/5) × c(ऑक्सैलिक अम्ल) × V(ऑक्सैलिक अम्ल) ÷ V(KMnO₄)।',
    ),
  );

  /// Class 12 practical J, the Mohr's salt part: KMnO₄ from a burette into
  /// acidified 0.1 M Mohr's salt at room temperature. The KMnO₄ is 0.020 M
  /// (unknown to the student), so the end point is at 10.0 mL
  /// (1 MnO₄⁻ per 5 Fe²⁺).
  static const _kmno4Mohr = Practical(
    id: 'kmno4_mohr_salt_titration',
    title: LocalizedText(en: "Titration: KMnO₄ against Mohr's Salt", hi: 'अनुमापन: मोर लवण के विरुद्ध KMnO₄'),
    description: LocalizedText(
      en: "Find the molarity of a potassium permanganate solution by titrating it against acidified "
          "0.1 M Mohr's salt at room temperature. KMnO₄ is its own indicator.",
      hi: 'कमरे के ताप पर अम्लीकृत 0.1 M मोर लवण के विरुद्ध अनुमापन करके पोटैशियम परमैंगनेट विलयन की '
          'मोलरता ज्ञात करें। KMnO₄ स्वयं सूचक है।',
    ),
    aim: LocalizedText(
      en: "To find the molarity of a potassium permanganate solution by titrating it against a "
          "standard solution of ferrous ammonium sulphate (Mohr's salt).",
      hi: 'फ़ेरस अमोनियम सल्फ़ेट (मोर लवण) के मानक विलयन के विरुद्ध अनुमापन द्वारा पोटैशियम '
          'परमैंगनेट विलयन की मोलरता ज्ञात करना।',
    ),
    icon: Icons.science_outlined,
    accent: Color(0xFF15803D),
    chemicals: [Chemicals.mohrSalt, Chemicals.hcl, Chemicals.dilSulphuricAcid, Chemicals.burner, Chemicals.kmno4],
    beakerCapacityMl: 40,
    steps: [
      LabStep(
        instruction: LocalizedText(
          en: "Pipette 10.0 mL of 0.1 M Mohr's Salt solution into the flask",
          hi: 'फ़्लास्क में 0.1 M मोर लवण विलयन का 10.0 mL पिपेट से डालें',
        ),
        requiredChemicalId: 'mohr_salt',
        volumeMl: 10,
        amount: StepAmount.fixed,
        resultColor: Color(0xFFE3F1E0),
        observation: LocalizedText(
          en: "10.0 mL of the pale green standard Mohr's salt solution is in the flask.",
          hi: 'फ़्लास्क में मानक मोर लवण का 10.0 mL हल्का हरा विलयन है।',
        ),
      ),
      LabStep(
        instruction: LocalizedText(
          en: 'Add about 10 mL (a test tube full) of Dilute Sulphuric Acid (H₂SO₄)',
          hi: 'लगभग 10 mL (एक परखनली भर) तनु सल्फ़्यूरिक अम्ल (H₂SO₄) डालें',
        ),
        requiredChemicalId: 'dil_h2so4',
        volumeMl: 10,
        resultColor: Color(0xFFE8F4E6),
        observation: LocalizedText(
          en: 'The solution is now acidic. Permanganate needs H⁺ ions to be reduced to colourless Mn²⁺.',
          hi: 'विलयन अब अम्लीय है। परमैंगनेट को रंगहीन Mn²⁺ में अपचयित होने के लिए H⁺ आयन चाहिए।',
        ),
      ),
      LabStep(
        instruction: LocalizedText(
          en: 'Fill the burette with KMnO₄ and run it in, without heating, until a light pink colour just stays',
          hi: 'ब्यूरेट में KMnO₄ भरें और बिना गरम किए, हल्का गुलाबी रंग ठीक स्थायी होने तक डालें',
        ),
        requiredChemicalId: 'kmno4',
        volumeMl: 0,
        amount: StepAmount.titration,
        titration: TitrationSpec(
          endPointMl: 10.0,
          duringObservation: LocalizedText(
            en: 'The purple KMnO₄ is decolourised as soon as it mixes in.',
            hi: 'बैंगनी KMnO₄ मिलते ही तुरंत रंगहीन हो जाता है।',
          ),
          nearObservation: LocalizedText(
            en: 'The pink colour now takes longer to disappear — the end point is close. Add 0.1 mL at a time.',
            hi: 'अब गुलाबी रंग गायब होने में अधिक समय लेता है — अंत्य बिंदु निकट है। एक बार में 0.1 mL डालें।',
          ),
          overshootColor: Color(0xFFD946A8),
        ),
        resultColor: Color(0xFFF9C9E3),
        observation: LocalizedText(
          en: 'One more drop gives a light pink colour that stays: this is the end point. KMnO₄ is its own indicator.',
          hi: 'एक और बूँद से हल्का गुलाबी रंग आता है जो बना रहता है: यही अंत्य बिंदु है। KMnO₄ स्वयं सूचक है।',
        ),
      ),
    ],
    calculation: TitrationCalculation(
      knownFormula: 'Fe²⁺',
      knownMolarity: 0.1,
      knownVolumeMl: 10,
      unknownFormula: 'KMnO₄',
      knownCoefficient: 5,
      unknownCoefficient: 1,
    ),
    hints: {
      'hcl': LocalizedText(
        en: 'Hydrochloric acid is not used to acidify: permanganate would oxidise chloride ions to chlorine, using up extra KMnO₄. Dilute sulphuric acid is used.',
        hi: 'अम्लीकरण के लिए हाइड्रोक्लोरिक अम्ल का उपयोग नहीं होता: परमैंगनेट क्लोराइड आयनों को क्लोरीन में ऑक्सीकृत करके अतिरिक्त KMnO₄ खर्च कर देगा। तनु सल्फ़्यूरिक अम्ल का उपयोग होता है।',
      ),
      'burner': LocalizedText(
        en: 'Do not heat: this titration is done at room temperature, because when hot, air can oxidise some Fe²⁺ ions to Fe³⁺.',
        hi: 'गरम न करें: यह अनुमापन कमरे के ताप पर किया जाता है, क्योंकि गरम होने पर वायु कुछ Fe²⁺ आयनों को Fe³⁺ में ऑक्सीकृत कर सकती है।',
      ),
    },
    conclusion: LocalizedText(
      en: 'MnO₄⁻ + 5Fe²⁺ + 8H⁺ → Mn²⁺ + 5Fe³⁺ + 4H₂O. Five moles of Fe²⁺ react with one mole of '
          'permanganate, so c(KMnO₄) = (1/5) × c(Mohr\'s salt) × V(Mohr\'s salt) ÷ V(KMnO₄).',
      hi: 'MnO₄⁻ + 5Fe²⁺ + 8H⁺ → Mn²⁺ + 5Fe³⁺ + 4H₂O. Fe²⁺ के पाँच मोल परमैंगनेट के एक मोल से '
          'अभिक्रिया करते हैं, इसलिए c(KMnO₄) = (1/5) × c(मोर लवण) × V(मोर लवण) ÷ V(KMnO₄)।',
    ),
  );

  static const List<Practical> _all = [_titration, _oxygen, _oxalic, _carbonate, _kmno4Oxalic, _kmno4Mohr];

  /// Every interactive lab, in display order.
  List<Practical> get all => [..._all, ...reactionLabs];

  Practical byId(String id) => all.firstWhere((p) => p.id == id);
}
