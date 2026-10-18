import 'package:flutter/material.dart';

/// Design tokens from the approved mockup. Existing names are kept so every
/// screen picks up the new look without code changes.
abstract final class LabColors {
  static const primary = Color(0xFF4338CA); // indigo
  static const primarySoft = Color(0xFFEEEFFD);
  static const secondary = Color(0xFF0E7490); // deep cyan
  static const teal = Color(0xFF0F766E);
  static const success = Color(0xFF16A34A);
  static const danger = Color(0xFFB4232C);
  static const warning = Color(0xFFD97706);
  static const amber = Color(0xFF9A4A08);
  static const background = Color(0xFFF5F6FA);
  static const surface = Colors.white;
  static const night = Color(0xFF0E1633); // hero panels
  static const bench = Color(0xFF8B5E3C); // wooden bench / shelf
  static const benchDark = Color(0xFF5C3B22);
  static const ink = Color(0xFF0B1230);
  static const muted = Color(0xFF5A6282);
  static const line = Color(0x140B1230);
  static const glass = Color(0xFFB8D8F0);

  /// One accent per class card.
  static const classAccents = <int, Color>{
    9: Color(0xFF0F766E),
    10: Color(0xFF4338CA),
    11: Color(0xFF9A4A08),
    12: Color(0xFFB4232C),
  };
}

/// Headings use Sora (bundled variable font); weight is set through the
/// `wght` axis so it renders the same on every platform. Devanagari falls
/// back to the system Hindi font automatically.
abstract final class AppText {
  static TextStyle display(double size, {FontWeight weight = FontWeight.w700, Color color = LabColors.ink, double? height}) =>
      TextStyle(
        fontFamily: 'Sora',
        fontSize: size,
        fontWeight: weight,
        fontVariations: [FontVariation('wght', weight.value.toDouble())],
        letterSpacing: -0.4,
        height: height,
        color: color,
      );
}

ThemeData buildLabTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: LabColors.primary,
    primary: LabColors.primary,
    surface: LabColors.surface,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: LabColors.background,
    splashFactory: InkSparkle.splashFactory,
    pageTransitionsTheme: const PageTransitionsTheme(builders: {
      TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
    }),
    appBarTheme: AppBarTheme(
      backgroundColor: LabColors.background,
      surfaceTintColor: Colors.transparent,
      foregroundColor: LabColors.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: AppText.display(19),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: LabColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: const BorderSide(color: LabColors.line),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        side: const BorderSide(color: LabColors.line, width: 1.5),
        textStyle: const TextStyle(fontWeight: FontWeight.w800),
      ),
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      side: const BorderSide(color: LabColors.line),
      labelStyle: const TextStyle(fontWeight: FontWeight.w700, color: LabColors.ink),
      selectedColor: LabColors.ink,
      secondaryLabelStyle: const TextStyle(fontWeight: FontWeight.w800, color: Colors.white),
      checkmarkColor: Colors.white,
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 68,
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      indicatorColor: LabColors.primary,
      elevation: 3,
      shadowColor: const Color(0x330B1230),
      labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
            fontSize: 11.5,
            fontWeight: states.contains(WidgetState.selected) ? FontWeight.w800 : FontWeight.w600,
            color: states.contains(WidgetState.selected) ? LabColors.primary : LabColors.muted,
          )),
      iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
            color: states.contains(WidgetState.selected) ? Colors.white : LabColors.muted,
          )),
    ),
    dialogTheme: DialogThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: LabColors.ink,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
  );
}
