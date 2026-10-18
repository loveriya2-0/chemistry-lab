import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import 'analytics_screen.dart';
import 'chapter_list_screen.dart';
import 'class_selection_screen.dart';
import 'exam_zone_screen.dart';
import 'lab_list_screen.dart';

enum AppTab { home, learn, lab, exam, progress }

/// The app's home: five tabs with a bottom navigation bar.
///
/// Tabs are rebuilt when selected so Home and Progress always show fresh
/// saved data. Detail screens (chapter, lab, focus…) are pushed on the root
/// navigator and cover the bar, exactly as before.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  /// Switches tab from anywhere inside a tab.
  static void goTo(BuildContext context, AppTab tab) =>
      context.findAncestorStateOfType<_MainShellState>()?._go(tab);

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  AppTab _tab = AppTab.home;

  void _go(AppTab tab) => setState(() => _tab = tab);

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    return Scaffold(
      body: switch (_tab) {
        AppTab.home => const ClassSelectionScreen(),
        AppTab.learn => const ChapterListScreen(),
        AppTab.lab => const LabListScreen(),
        AppTab.exam => const ExamZoneScreen(),
        AppTab.progress => AnalyticsScreen(onStartPractising: () => _go(AppTab.home)),
      },
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab.index,
        onDestinationSelected: (i) => _go(AppTab.values[i]),
        destinations: [
          NavigationDestination(icon: const Icon(Icons.home_outlined), selectedIcon: const Icon(Icons.home_rounded), label: s.navHome),
          NavigationDestination(icon: const Icon(Icons.menu_book_outlined), selectedIcon: const Icon(Icons.menu_book_rounded), label: s.navLearn),
          NavigationDestination(icon: const Icon(Icons.science_outlined), selectedIcon: const Icon(Icons.science_rounded), label: s.navLab),
          NavigationDestination(icon: const Icon(Icons.assignment_outlined), selectedIcon: const Icon(Icons.assignment_rounded), label: s.navExam),
          NavigationDestination(icon: const Icon(Icons.insights_outlined), selectedIcon: const Icon(Icons.insights_rounded), label: s.navProgress),
        ],
      ),
    );
  }
}
