import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:virtual_chemistry_lab/screens/lab_tutorial_screen.dart';

import 'test_helpers.dart';

/// Scrolls the first scrollable on screen to its end.
Future<void> _scrollToEnd(WidgetTester tester) async {
  for (var i = 0; i < 30; i++) {
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -400), warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  // Many Android phones run with a larger system font; any RenderFlex
  // overflow below fails the test.
  for (final (name, size, scale) in [('320×568 at 1.5× font', const Size(960, 1704), 1.5), ('360×640 at 1.3× font', const Size(1080, 1920), 1.3)]) {
    testWidgets('tabs, chapter, lab and tutorial fit a $name', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await launchApp(tester, size: size, pixelRatio: 3);
      await tester.pumpAndSettle();

      final tabs = find.byType(NavigationDestination);
      for (var t = 0; t < 5; t++) {
        await tester.tap(tabs.at(t));
        await tester.pumpAndSettle();
        await _scrollToEnd(tester);
      }
      await tester.tap(tabs.at(0));
      await tester.pumpAndSettle();

      await scrollAndTap(tester, find.text('Class 10'));
      await scrollAndTap(tester, find.text('Acids, Bases and Salts'));
      await _scrollToEnd(tester);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await scrollAndTap(tester, find.text('Acids, Bases and Salts'));
      await scrollAndTap(tester, openLabOn('2.1.4'));
      await scrollAndTap(tester, find.text('View practical'));
      await tester.tap(find.text('Start virtual lab'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Start without Focus Mode'), 200, scrollable: find.byType(Scrollable).first);
      await tester.tap(find.text('Start without Focus Mode'));
      await pumpRoute(tester);
      await completeTitration(tester);
      await pumpRoute(tester);

      // Every page of the first-time lab tutorial.
      tester.state<NavigatorState>(find.byType(Navigator).first).push(MaterialPageRoute<void>(builder: (_) => const LabTutorialScreen()));
      await pumpRoute(tester);
      for (var page = 0; page < 7; page++) {
        await tester.tap(find.byType(FilledButton).last);
        await pumpRoute(tester);
      }
    });
  }
}
