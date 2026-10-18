import 'package:flutter_test/flutter_test.dart';
import 'package:virtual_chemistry_lab/screens/practical_guide_screen.dart';
import 'package:virtual_chemistry_lab/screens/virtual_lab_screen.dart';
import 'package:virtual_chemistry_lab/widgets/focus_bar.dart';
import 'package:virtual_chemistry_lab/widgets/language_toggle.dart';

import 'test_helpers.dart';

void main() {
  testWidgets('class → chapter → topic → practical → lab, wrong drop warns',
      (tester) async {
    await launchApp(tester);
    expect(find.text('Class 10'), findsOneWidget);

    await tester.tap(find.text('Class 10'));
    await tester.pumpAndSettle();
    expect(find.text('Class 10 Chapters'), findsOneWidget);
    expect(find.text('Chemical Reactions and Equations'), findsOneWidget);
    expect(find.text('Acids, Bases and Salts'), findsOneWidget);

    await scrollAndTap(tester, find.text('Acids, Bases and Salts'));
    expect(find.text('Chapter 2 Topics'), findsOneWidget);
    expect(find.text('TOPIC 2.1'), findsOneWidget);

    // The titration lab is offered on verified sub-topic 2.1.4.
    await scrollAndTap(tester, openLabOn('2.1.4'));
    expect(find.text('2.1.4 How do Acids and Bases React with each other?'), findsOneWidget);
    expect(find.text('Acid-Base Titration'), findsOneWidget);
    expect(find.text('Oxygen Gas Preparation'), findsNothing);

    // View practical → its guide → Start virtual lab → Focus Mode setup →
    // skip straight to the plain lab.
    await tester.tap(find.text('View practical'));
    await tester.pumpAndSettle();
    expect(find.byType(PracticalGuideScreen), findsOneWidget);
    await tester.tap(find.text('Start virtual lab'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start without Focus Mode'));
    await pumpRoute(tester);
    expect(find.byType(VirtualLabScreen), findsOneWidget);
    expect(find.byType(FocusBar), findsNothing);
    expect(find.textContaining('Sodium Hydroxide (NaOH) solution into the flask'), findsOneWidget);
    expect(find.text('Measured with a pipette: exactly 10.0 mL.'), findsOneWidget);

    // HCl is wrong – NaOH is expected first.
    await pour(tester, 'HCl');

    expect(find.text('Smart Warning'), findsOneWidget);
    expect(
      find.textContaining('You were supposed to add Sodium Hydroxide (NaOH), '
          'but you added Hydrochloric Acid (HCl)'),
      findsOneWidget,
    );
  });

  testWidgets('Hindi: full flow translated, switching mid-lab keeps progress',
      (tester) async {
    final prefs = await launchApp(tester);

    await tester.tap(find.byType(LanguageToggle));
    await tester.pumpAndSettle();
    expect(find.text('कक्षा 10'), findsOneWidget);
    expect(prefs.getString('app_language'), 'hi');

    await tester.tap(find.text('कक्षा 10'));
    await tester.pumpAndSettle();
    expect(find.text('कक्षा 10 के अध्याय'), findsOneWidget);
    expect(find.text('रासायनिक अभिक्रियाएँ एवं समीकरण'), findsOneWidget);

    await scrollAndTap(tester, find.text('अम्ल, क्षारक एवं लवण'));
    expect(find.text('विषय 2.1'), findsOneWidget);

    await scrollAndTap(tester, openLabOn('2.1.4', openLab: 'लैब खोलें'));
    expect(find.text('अम्ल-क्षारक अनुमापन'), findsOneWidget);
    expect(find.text('3 चरण'), findsOneWidget);

    await tester.tap(find.text('प्रयोग देखें'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('वर्चुअल लैब शुरू करें'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('फ़ोकस मोड के बिना प्रारंभ करें'));
    await pumpRoute(tester);
    expect(find.text('फ़्लास्क में 10.0 mL सोडियम हाइड्रॉक्साइड (NaOH) विलयन पिपेट से डालें'), findsOneWidget);
    expect(find.text('चरण 1 / 3'), findsOneWidget);

    // Correct pour, then switch to English: still on step 2, now in English.
    await pour(tester, 'NaOH');
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('फ़्लास्क में 10.0 mL स्वच्छ, रंगहीन क्षारकीय विलयन है।'), findsOneWidget);

    await tester.tap(find.byType(LanguageToggle));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('STEP 2 OF 3'), findsOneWidget);
    expect(find.text('10.0 mL of a clear, colourless basic solution is in the flask.'), findsOneWidget);

    await tester.tap(find.byType(LanguageToggle));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('चरण 2 / 3'), findsOneWidget);

    // Wrong pour shows the Hindi Smart Warning with a Hindi safety note.
    await pour(tester, 'HCl');
    expect(find.text('स्मार्ट चेतावनी'), findsOneWidget);
    expect(
      find.textContaining('आपको फ़ीनॉल्फ़्थेलिन डालना था, '
          'लेकिन आपने हाइड्रोक्लोरिक अम्ल (HCl) डाल दिया'),
      findsOneWidget,
    );
    expect(find.text('सुरक्षा: HCl – संक्षारक – त्वचा के संपर्क से बचें।'), findsOneWidget);
    expect(find.text('पुनः प्रयास करें'), findsOneWidget);
  });
}
