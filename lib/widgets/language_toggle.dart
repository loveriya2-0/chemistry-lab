import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../l10n/app_language.dart';
import '../l10n/app_strings.dart';
import '../state/language_controller.dart';

/// Compact EN / हिं switch for app bars. Switching keeps all screen and lab
/// state; only the text changes.
class LanguageToggle extends StatelessWidget {
  const LanguageToggle({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<LanguageController>();
    final current = controller.language;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Tooltip(
        message: context.strings.changeLanguage,
        child: Material(
          color: LabColors.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: controller.toggle,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.translate_rounded, size: 16, color: LabColors.primary),
                  const SizedBox(width: 6),
                  // Unscaled: a big phone font would push the header's other
                  // buttons off screen.
                  for (final l in AppLanguage.values) ...[
                    if (l.index > 0)
                      const Text(' / ', textScaler: TextScaler.noScaling, style: TextStyle(color: LabColors.muted)),
                    Text(
                      l.shortName,
                      textScaler: TextScaler.noScaling,
                      style: TextStyle(
                        fontWeight: l == current ? FontWeight.w900 : FontWeight.w500,
                        color: l == current ? LabColors.primary : LabColors.muted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
