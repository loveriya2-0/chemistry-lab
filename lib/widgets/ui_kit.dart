import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Dark "night" panel with a faint dot grid and an optional ball-and-stick
/// molecule — the hero surface used across the app.
class HeroPanel extends StatelessWidget {
  const HeroPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.molecule = true,
    this.radius = 26,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool molecule;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: CustomPaint(
        painter: const _DotGridPainter(),
        child: Stack(
          children: [
            if (molecule)
              // Faint, so titles that run underneath stay readable.
              const Positioned(
                right: -22,
                top: -10,
                child: ExcludeSemantics(child: Opacity(opacity: 0.4, child: MoleculeMotif(size: 130))),
              ),
            Padding(
              padding: padding,
              child: DefaultTextStyle.merge(
                style: const TextStyle(color: Colors.white),
                child: child,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DotGridPainter extends CustomPainter {
  const _DotGridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = LabColors.night);
    final dot = Paint()..color = Colors.white.withValues(alpha: 0.07);
    for (var y = 8.0; y < size.height; y += 16) {
      for (var x = 8.0; x < size.width; x += 16) {
        canvas.drawCircle(Offset(x, y), 1, dot);
      }
    }
  }

  @override
  bool shouldRepaint(_DotGridPainter oldDelegate) => false;
}

/// Decorative ball-and-stick molecule (static, so it costs nothing).
class MoleculeMotif extends StatelessWidget {
  const MoleculeMotif({super.key, this.size = 150});

  final double size;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: const _MoleculePainter());
}

class _MoleculePainter extends CustomPainter {
  const _MoleculePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 170;
    Offset p(double x, double y) => Offset(x * s, y * s);
    final bond = Paint()
      ..color = Colors.white.withValues(alpha: 0.24)
      ..strokeWidth = 3 * s
      ..strokeCap = StrokeCap.round;
    for (final (a, b) in [
      (p(86, 62), p(52, 40)),
      (p(86, 62), p(124, 44)),
      (p(86, 62), p(92, 104)),
      (p(92, 104), p(62, 124)),
      (p(92, 104), p(132, 116)),
    ]) {
      canvas.drawLine(a, b, bond);
    }
    void atom(Offset c, double r, Color color) {
      canvas.drawCircle(c, r * s, Paint()..color = color);
      canvas.drawCircle(c - Offset(r * s * 0.35, r * s * 0.35), r * s * 0.3, Paint()..color = Colors.white.withValues(alpha: 0.4));
    }

    atom(p(86, 62), 14, const Color(0xFF6E66F0));
    atom(p(52, 40), 9, Colors.white.withValues(alpha: 0.85));
    atom(p(124, 44), 9, Colors.white.withValues(alpha: 0.85));
    atom(p(92, 104), 12, const Color(0xFF2DD4BF));
    atom(p(62, 124), 8, Colors.white.withValues(alpha: 0.7));
    atom(p(132, 116), 8, Colors.white.withValues(alpha: 0.7));
  }

  @override
  bool shouldRepaint(_MoleculePainter oldDelegate) => false;
}

/// Periodic-table style tile: small label on top, big number below.
class ElementTile extends StatelessWidget {
  const ElementTile({super.key, required this.number, required this.color, this.label = 'CH', this.size = 56});

  final String number;
  final String label;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.symmetric(horizontal: size * 0.13, vertical: size * 0.1),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(size * 0.25),
        border: Border.all(color: color, width: 1.6),
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.18), blurRadius: 12, offset: const Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        // A fixed-size badge: its text ignores the phone's font size.
        children: [
          Text(label, textScaler: TextScaler.noScaling, style: TextStyle(fontSize: size * 0.17, fontWeight: FontWeight.w800, color: color, letterSpacing: 0.6)),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(number, textScaler: TextScaler.noScaling, style: AppText.display(size * 0.38, weight: FontWeight.w700, color: color, height: 1)),
          ),
        ],
      ),
    );
  }
}

/// Fades and slides its child in, staggered by [index].
class FadeSlideIn extends StatelessWidget {
  const FadeSlideIn({super.key, required this.child, this.index = 0});

  final Widget child;
  final int index;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 380 + 50 * index.clamp(0, 8)),
      curve: Curves.easeOutCubic,
      builder: (_, v, child) => Opacity(
        opacity: v,
        child: Transform.translate(offset: Offset(0, 14 * (1 - v)), child: child),
      ),
      child: child,
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 6, 2, 10),
      child: Row(
        children: [
          Expanded(child: Text(title, style: AppText.display(17))),
          if (trailing != null) ...[const SizedBox(width: 8), Flexible(child: trailing!)],
        ],
      ),
    );
  }
}

/// Honest empty state for features whose data is not available yet.
class ComingSoonPanel extends StatelessWidget {
  const ComingSoonPanel({super.key, required this.icon, required this.title, required this.body, this.action});

  final IconData icon;
  final String title;
  final String body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: LabColors.line),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: const BoxDecoration(color: LabColors.primarySoft, shape: BoxShape.circle),
            child: Icon(icon, color: LabColors.primary, size: 28),
          ),
          const SizedBox(height: 12),
          Text(title, textAlign: TextAlign.center, style: AppText.display(16)),
          const SizedBox(height: 6),
          Text(body, textAlign: TextAlign.center, style: const TextStyle(color: LabColors.muted, height: 1.45)),
          if (action != null) ...[const SizedBox(height: 14), action!],
        ],
      ),
    );
  }
}

/// Small tinted icon square used on list rows and cards.
class IconTile extends StatelessWidget {
  const IconTile({super.key, required this.icon, required this.color, this.size = 40});

  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(size * 0.3)),
      child: Icon(icon, color: color, size: size * 0.5),
    );
  }
}
