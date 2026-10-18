import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../l10n/app_strings.dart';
import '../models/chemical.dart';

/// A reagent bottle on the shelf that can be dragged onto the beaker.
///
/// Uses `affinity: Axis.vertical` so the drag starts when the student pulls
/// the bottle *up* towards the workstation.
class ChemicalBottle extends StatelessWidget {
  const ChemicalBottle({super.key, required this.chemical, this.onTap});

  final Chemical chemical;

  /// Tap (without dragging) – used to show chemical info.
  final VoidCallback? onTap;

  static const double width = 72;
  static const double height = 104;

  @override
  Widget build(BuildContext context) {
    return Draggable<Chemical>(
      data: chemical,
      affinity: Axis.vertical,
      dragAnchorStrategy: pointerDragAnchorStrategy,
      feedback: Transform.translate(
        offset: const Offset(-width / 2, -height * 0.8),
        child: Transform.rotate(
          angle: -0.35, // tilted as if about to pour
          child: Material(
            type: MaterialType.transparency,
            child: _BottleBody(chemical: chemical, lifted: true),
          ),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.25,
        child: _BottleBody(chemical: chemical),
      ),
      child: GestureDetector(
        onTap: onTap,
        child: _BottleBody(chemical: chemical),
      ),
    );
  }
}

class _BottleBody extends StatelessWidget {
  const _BottleBody({required this.chemical, this.lifted = false});

  final Chemical chemical;
  final bool lifted;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: ChemicalBottle.width,
      height: ChemicalBottle.height,
      child: CustomPaint(
        painter: _BottlePainter(chemical.color, lifted: lifted),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 50, 10, 14),
          child: Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: LabColors.ink.withValues(alpha: 0.15)),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                chemical.label(context.strings.language),
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: LabColors.ink,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BottlePainter extends CustomPainter {
  _BottlePainter(this.liquid, {required this.lifted});

  final Color liquid;
  final bool lifted;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final neckW = w * 0.34;

    final bottle = Path()
      ..moveTo(w / 2 - neckW / 2, h * 0.12)
      ..lineTo(w / 2 - neckW / 2, h * 0.28)
      ..quadraticBezierTo(4, h * 0.32, 4, h * 0.45)
      ..lineTo(4, h - 10)
      ..quadraticBezierTo(4, h - 2, 12, h - 2)
      ..lineTo(w - 12, h - 2)
      ..quadraticBezierTo(w - 4, h - 2, w - 4, h - 10)
      ..lineTo(w - 4, h * 0.45)
      ..quadraticBezierTo(w - 4, h * 0.32, w / 2 + neckW / 2, h * 0.28)
      ..lineTo(w / 2 + neckW / 2, h * 0.12)
      ..close();

    if (lifted) {
      canvas.drawShadow(bottle, Colors.black, 8, false);
    }

    // Glass.
    canvas.drawPath(bottle, Paint()..color = const Color(0xFFEFF6FC));

    // Contents fill the lower 60%.
    canvas.save();
    canvas.clipPath(bottle);
    canvas.drawRect(
      Rect.fromLTRB(0, h * 0.4, w, h),
      Paint()..color = liquid,
    );
    canvas.restore();

    canvas.drawPath(
      bottle,
      Paint()
        ..color = const Color(0xFF7FA7C9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );

    // Cap.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w / 2 - neckW / 2 - 3, 0, neckW + 6, h * 0.13),
        const Radius.circular(4),
      ),
      Paint()..color = LabColors.primary,
    );
  }

  @override
  bool shouldRepaint(_BottlePainter old) =>
      old.liquid != liquid || old.lifted != lifted;
}
