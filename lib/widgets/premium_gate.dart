import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../l10n/premium_strings.dart';
import '../premium/premium_controller.dart';
import '../screens/premium_screen.dart';
import 'language_toggle.dart';
import 'ui_kit.dart';

/// Whether Premium is unlocked; rebuilds the caller when that changes.
extension PremiumContext on BuildContext {
  bool get isPremium => watch<PremiumController>().isPremium;
}

void openPremium(BuildContext context) =>
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const PremiumScreen()));

/// Shown in place of a Premium feature: what it is and how to unlock it.
class PremiumLockedCard extends StatelessWidget {
  const PremiumLockedCard({super.key, required this.body});

  final String body;

  @override
  Widget build(BuildContext context) {
    final p = context.premium;
    final price = context.watch<PremiumController>().price;
    return Card(
      key: const Key('premium-locked'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const IconTile(icon: Icons.lock_rounded, color: LabColors.primary, size: 36),
                const SizedBox(width: 10),
                Expanded(child: Text(p.lockedTitle, style: AppText.display(16, color: LabColors.ink))),
              ],
            ),
            const SizedBox(height: 10),
            Text(body, style: const TextStyle(color: LabColors.muted, height: 1.4)),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => openPremium(context),
              icon: const Icon(Icons.workspace_premium_rounded),
              label: Text(p.unlockFor(price)),
            ),
          ],
        ),
      ),
    );
  }
}

/// A whole screen that needs Premium: [child] when unlocked, otherwise a
/// screen with [title] and the locked card.
class PremiumGate extends StatelessWidget {
  const PremiumGate({super.key, required this.title, required this.body, required this.child, this.locked = true});

  final String title;
  final String body;
  final Widget child;

  /// False when there is nothing to sell yet (e.g. no PYQs for a board).
  final bool locked;

  @override
  Widget build(BuildContext context) {
    if (!locked || context.isPremium) return child;
    return Scaffold(
      appBar: AppBar(title: Text(title), actions: const [LanguageToggle()]),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [PremiumLockedCard(body: body)],
      ),
    );
  }
}
