import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../l10n/premium_strings.dart';
import '../premium/premium_controller.dart';
import '../widgets/language_toggle.dart';
import '../widgets/ui_kit.dart';

/// Price, benefits, Buy and Restore. Every state of the purchase (pending,
/// cancelled, failed, refunded…) is reported here.
class PremiumScreen extends StatelessWidget {
  const PremiumScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.premium;
    final premium = context.watch<PremiumController>();
    final unavailable = premium.unavailable;

    return Scaffold(
      appBar: AppBar(title: Text(p.premium), actions: const [LanguageToggle()]),
      // Buy stays in reach however far the benefits scroll.
      bottomNavigationBar: premium.isPremium
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (unavailable != null) ...[
                      Text(p.unavailable(unavailable), textAlign: TextAlign.center, style: const TextStyle(color: LabColors.muted, fontSize: 13)),
                      const SizedBox(height: 8),
                    ],
                    FilledButton.icon(
                      key: const Key('buy-premium'),
                      onPressed: premium.canBuy ? () => context.read<PremiumController>().buy() : null,
                      icon: premium.busy
                          ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.workspace_premium_rounded),
                      label: Text(p.buyFor(premium.price)),
                      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                    ),
                  ],
                ),
              ),
            ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          HeroPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.workspace_premium_rounded, color: Color(0xFFFBBF24)),
                    const SizedBox(width: 8),
                    Text(p.premium.toUpperCase(), style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.8)),
                  ],
                ),
                const SizedBox(height: 10),
                Text(premium.price, key: const Key('premium-price'), style: AppText.display(34, color: Colors.white)),
                const SizedBox(height: 2),
                Text(p.oneTime, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                SizedBox(width: 260, child: Text(p.premiumTagline, style: const TextStyle(color: Colors.white, height: 1.4))),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (premium.status == PremiumStatus.active)
            _StatusCard(icon: Icons.verified_rounded, color: LabColors.success, title: p.active, body: p.activeBody)
          else if (premium.status == PremiumStatus.pending)
            _StatusCard(icon: Icons.hourglass_top_rounded, color: LabColors.warning, title: p.pendingTitle, body: p.pendingBody),
          if (premium.notice case final n? when !(n == PremiumNotice.purchased && premium.isPremium)) ...[
            const SizedBox(height: 8),
            _NoticeBanner(text: p.notice(n), good: n == PremiumNotice.purchased || n == PremiumNotice.restored),
          ],
          const SizedBox(height: 8),
          SectionHeader(p.whatYouGet),
          _Benefit(icon: Icons.history_edu_rounded, title: p.benefitPyqs, body: p.benefitPyqsBody),
          _Benefit(icon: Icons.insights_rounded, title: p.benefitAnalysis, body: p.benefitAnalysisBody),
          _Benefit(icon: Icons.layers_rounded, title: p.benefitRevisionSets, body: p.comingSoonIncluded, soon: true),
          _Benefit(icon: Icons.fact_check_rounded, title: p.benefitMockTests, body: p.comingSoonIncluded, soon: true),
          const SizedBox(height: 8),
          _Benefit(icon: Icons.lock_open_rounded, title: p.alwaysFree, body: p.alwaysFreeBody, color: LabColors.teal),
          const SizedBox(height: 16),
          TextButton.icon(
            key: const Key('restore-premium'),
            onPressed: premium.busy ? null : () => context.read<PremiumController>().restore(),
            icon: const Icon(Icons.restore_rounded),
            label: Text(p.restore),
          ),
          const SizedBox(height: 8),
          for (final note in [p.linkedToPlay, p.priceNote])
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline_rounded, size: 16, color: LabColors.muted),
                  const SizedBox(width: 6),
                  Expanded(child: Text(note, style: const TextStyle(fontSize: 12, color: LabColors.muted, height: 1.4))),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Benefit extends StatelessWidget {
  const _Benefit({required this.icon, required this.title, required this.body, this.soon = false, this.color = LabColors.primary});

  final IconData icon;
  final String title;
  final String body;
  final bool soon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: IconTile(icon: icon, color: soon ? LabColors.muted : color, size: 36),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(body, style: TextStyle(color: soon ? LabColors.warning : LabColors.muted, height: 1.35)),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.icon, required this.color, required this.title, required this.body});

  final IconData icon;
  final Color color;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: Icon(icon, color: color, size: 32),
        title: Text(title, style: TextStyle(fontWeight: FontWeight.w800, color: color)),
        subtitle: Text(body),
      ),
    );
  }
}

class _NoticeBanner extends StatelessWidget {
  const _NoticeBanner({required this.text, required this.good});

  final String text;
  final bool good;

  @override
  Widget build(BuildContext context) {
    final color = good ? LabColors.success : LabColors.amber;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(good ? Icons.check_circle_rounded : Icons.info_rounded, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w600, height: 1.35))),
        ],
      ),
    );
  }
}
