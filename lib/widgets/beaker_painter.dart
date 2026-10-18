import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Draws a glass beaker with an animated liquid surface, gas bubbles, solid
/// pieces, a settling precipitate, rising fumes and an optional pouring
/// stream (or falling granules for a solid). All motion is driven from outside via [wavePhase]
/// and [pourProgress] so the painter itself stays stateless.
class BeakerPainter extends CustomPainter {
  BeakerPainter({
    required this.liquidColor,
    required this.fillLevel,
    required this.wavePhase,
    required this.capacityMl,
    this.bubbling = false,
    this.pourColor,
    this.pourProgress = 0,
    this.highlighted = false,
    this.solidColor,
    this.precipitateColor,
    this.fumesColor,
    this.pourSolid = false,
  });

  /// Colour of the beaker contents.
  final Color liquidColor;

  /// 0..1 – how full the beaker is.
  final double fillLevel;

  /// 0..1 looping phase for the wave and bubbles.
  final double wavePhase;

  /// Used to label the graduation marks.
  final double capacityMl;

  final bool bubbling;

  /// Colour of the stream being poured in (null when not pouring).
  final Color? pourColor;

  /// 0..1 progress of the pour animation.
  final double pourProgress;

  /// Glow when a chemical is hovering over the beaker.
  final bool highlighted;

  /// Colour of solid pieces (granules, nails, lumps) lying in the beaker.
  final Color? solidColor;

  /// Colour of an insoluble precipitate settling at the bottom.
  final Color? precipitateColor;

  /// Colour of fumes rising from the beaker.
  final Color? fumesColor;

  /// The item being added is a solid: granules fall instead of a stream.
  final bool pourSolid;

  static const _maxFillRatio = 0.85;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Beaker geometry.
    final body = Rect.fromLTRB(w * 0.18, h * 0.12, w * 0.82, h * 0.96);
    final bodyPath = _bodyPath(body);

    // Glass back + glow.
    if (highlighted) {
      canvas.drawPath(
        bodyPath,
        Paint()
          ..color = LabColors.secondary.withValues(alpha: 0.45)
          ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 18),
      );
    }
    canvas.drawPath(
      bodyPath,
      Paint()..color = LabColors.glass.withValues(alpha: 0.18),
    );

    // Liquid (clipped to the beaker body).
    final liquidHeight = body.height * _maxFillRatio * fillLevel;
    final surfaceY = body.bottom - liquidHeight;
    final hasLiquid = fillLevel > 0.001;
    canvas.save();
    canvas.clipPath(bodyPath);
    if (hasLiquid) _paintLiquid(canvas, body, surfaceY);
    if (precipitateColor != null && hasLiquid) _paintPrecipitate(canvas, body, surfaceY, precipitateColor!);
    if (solidColor != null) _paintSolids(canvas, body, solidColor!);
    if (bubbling && hasLiquid) _paintBubbles(canvas, body, surfaceY);
    canvas.restore();

    if (fumesColor != null) _paintFumes(canvas, body, fumesColor!);

    // Pour stream (or falling granules) from above the rim to the surface.
    if (pourColor != null && pourProgress > 0 && pourProgress < 1) {
      if (pourSolid) {
        _paintFallingSolid(canvas, body, hasLiquid ? surfaceY : body.bottom - 8);
      } else {
        _paintPour(canvas, size, body, surfaceY);
      }
    }

    _paintGraduations(canvas, body);
    _paintGlass(canvas, body, bodyPath);
  }

  Path _bodyPath(Rect body) {
    const r = Radius.circular(18);
    return Path()
      ..moveTo(body.left, body.top)
      ..lineTo(body.left, body.bottom - r.y)
      ..arcToPoint(Offset(body.left + r.x, body.bottom), radius: r, clockwise: false)
      ..lineTo(body.right - r.x, body.bottom)
      ..arcToPoint(Offset(body.right, body.bottom - r.y), radius: r, clockwise: false)
      ..lineTo(body.right, body.top)
      ..close();
  }

  void _paintLiquid(Canvas canvas, Rect body, double surfaceY) {
    // Calmer wave when the beaker is nearly empty; choppy while bubbling.
    final amplitude = bubbling ? 5.0 : 3.0;
    final phase = wavePhase * 2 * math.pi;

    final path = Path()..moveTo(body.left, body.bottom);
    path.lineTo(body.left, surfaceY);
    for (double x = body.left; x <= body.right; x += 4) {
      final t = (x - body.left) / body.width;
      final y = surfaceY + math.sin(t * 2 * math.pi * 1.5 + phase) * amplitude;
      path.lineTo(x, y);
    }
    path
      ..lineTo(body.right, body.bottom)
      ..close();

    final top = Color.lerp(liquidColor, Colors.white, 0.25)!;
    final bottom = Color.lerp(liquidColor, Colors.black, 0.12)!;
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [top, bottom],
        ).createShader(Rect.fromLTRB(body.left, surfaceY, body.right, body.bottom)),
    );

    // Thin meniscus line so even colourless liquids are visible.
    canvas.drawPath(
      Path()
        ..moveTo(body.left, surfaceY)
        ..relativeLineTo(body.width, 0),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.7)
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke,
    );
  }

  void _paintBubbles(Canvas canvas, Rect body, double surfaceY) {
    final liquidHeight = body.bottom - surfaceY;
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.75)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    final rnd = math.Random(7); // fixed seed → stable bubble layout
    for (var i = 0; i < 22; i++) {
      final x = body.left + 10 + rnd.nextDouble() * (body.width - 20);
      final offset = rnd.nextDouble();
      final speed = 1 + rnd.nextInt(2); // integer so the loop is seamless
      final radius = 2.0 + rnd.nextDouble() * 4;
      final t = (wavePhase * speed + offset) % 1.0;
      final y = body.bottom - 6 - t * (liquidHeight - 6);
      final wobble = math.sin((t + offset) * 4 * math.pi) * 3;
      canvas.drawCircle(Offset(x + wobble, y), radius, paint);
    }
  }

  /// A settled layer at the bottom with particles still drifting down.
  void _paintPrecipitate(Canvas canvas, Rect body, double surfaceY, Color color) {
    final layer = math.min(body.height * 0.1, (body.bottom - surfaceY) * 0.5);
    canvas.drawRect(
      Rect.fromLTRB(body.left, body.bottom - layer, body.right, body.bottom),
      Paint()..color = color,
    );
    final paint = Paint()..color = color.withValues(alpha: 0.85);
    final rnd = math.Random(11);
    final depth = body.bottom - layer - surfaceY;
    for (var i = 0; i < 26; i++) {
      final x = body.left + 8 + rnd.nextDouble() * (body.width - 16);
      final t = (wavePhase * 0.5 + rnd.nextDouble()) % 1.0;
      canvas.drawCircle(Offset(x, surfaceY + 6 + t * (depth - 6)), 1.5 + rnd.nextDouble() * 2, paint);
    }
  }

  /// Pieces of solid (granules, lumps, nails) lying on the bottom.
  void _paintSolids(Canvas canvas, Rect body, Color color) {
    final rnd = math.Random(3);
    final fill = Paint()..color = color;
    final edge = Paint()
      ..color = Color.lerp(color, Colors.black, 0.35)!
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    for (var i = 0; i < 9; i++) {
      final w = 12 + rnd.nextDouble() * 12;
      final h = 7 + rnd.nextDouble() * 6;
      final x = body.left + 14 + rnd.nextDouble() * (body.width - 28 - w);
      final y = body.bottom - 4 - h - rnd.nextDouble() * 6;
      final piece = RRect.fromRectAndRadius(Rect.fromLTWH(x, y, w, h), const Radius.circular(4));
      canvas.drawRRect(piece, fill);
      canvas.drawRRect(piece, edge);
    }
  }

  /// Puffs rising above the rim and fading out.
  void _paintFumes(Canvas canvas, Rect body, Color color) {
    for (var i = 0; i < 5; i++) {
      final t = (wavePhase + i / 5) % 1.0;
      final x = body.center.dx + math.sin((t + i) * math.pi * 2) * body.width * 0.18;
      final y = body.top + 10 - t * body.top * 0.9;
      canvas.drawCircle(
        Offset(x, y),
        8 + t * 14,
        Paint()
          ..color = color.withValues(alpha: 0.45 * (1 - t))
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
    }
  }

  void _paintFallingSolid(Canvas canvas, Rect body, double landingY) {
    final paint = Paint()..color = pourColor!;
    final x = body.center.dx + body.width * 0.12;
    for (var i = 0; i < 6; i++) {
      final t = (pourProgress * 1.4 - i * 0.08).clamp(0.0, 1.0);
      if (t <= 0 || t >= 1) continue;
      canvas.drawCircle(Offset(x + (i.isEven ? -6 : 6), t * landingY), 4, paint);
    }
  }

  void _paintPour(Canvas canvas, Size size, Rect body, double surfaceY) {
    // Stream grows down in the first half, thins out in the second half.
    final grow = (pourProgress * 2).clamp(0.0, 1.0);
    final fade = pourProgress < 0.5 ? 1.0 : 1 - (pourProgress - 0.5) * 2;
    final startY = 0.0;
    final endY = startY + (surfaceY - startY) * grow;
    final x = body.center.dx + body.width * 0.12;
    canvas.drawLine(
      Offset(x, startY),
      Offset(x, endY),
      Paint()
        ..color = Color.lerp(pourColor, Colors.blueGrey, 0.15)!
            .withValues(alpha: 0.9 * fade)
        ..strokeWidth = 7 * fade + 1
        ..strokeCap = StrokeCap.round,
    );
    if (grow >= 1) {
      // Splash ring where the stream hits the surface.
      canvas.drawOval(
        Rect.fromCenter(center: Offset(x, surfaceY), width: 30 * fade + 6, height: 8),
        Paint()
          ..color = Colors.white.withValues(alpha: 0.6 * fade)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }

  void _paintGraduations(Canvas canvas, Rect body) {
    final markPaint = Paint()
      ..color = LabColors.ink.withValues(alpha: 0.45)
      ..strokeWidth = 1.5;
    const steps = 4;
    for (var i = 1; i <= steps; i++) {
      final y = body.bottom - body.height * _maxFillRatio * (i / steps);
      canvas.drawLine(Offset(body.right - 22, y), Offset(body.right - 4, y), markPaint);
      final label = TextPainter(
        text: TextSpan(
          text: '${(capacityMl * i / steps).round()}',
          style: TextStyle(
            color: LabColors.ink.withValues(alpha: 0.55),
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      label.paint(canvas, Offset(body.right - 26 - label.width, y - label.height / 2));
    }
    final ml = TextPainter(
      text: TextSpan(
        text: 'ml',
        style: TextStyle(color: LabColors.ink.withValues(alpha: 0.5), fontSize: 10),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    ml.paint(canvas, Offset(body.right - 20, body.top + 6));
  }

  void _paintGlass(Canvas canvas, Rect body, Path bodyPath) {
    // Outline.
    canvas.drawPath(
      bodyPath,
      Paint()
        ..color = const Color(0xFF7FA7C9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5
        ..strokeJoin = StrokeJoin.round,
    );
    // Rim with spout on the left.
    final rim = Path()
      ..moveTo(body.left - 12, body.top - 8)
      ..quadraticBezierTo(body.left - 2, body.top - 4, body.left, body.top + 8)
      ..moveTo(body.right, body.top)
      ..lineTo(body.right + 6, body.top - 4);
    canvas.drawPath(
      rim,
      Paint()
        ..color = const Color(0xFF7FA7C9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round,
    );
    // Reflection highlight.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(body.left + 10, body.top + 16, 8, body.height * 0.6),
        const Radius.circular(4),
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.55),
    );
  }

  @override
  bool shouldRepaint(BeakerPainter old) =>
      old.liquidColor != liquidColor ||
      old.fillLevel != fillLevel ||
      old.wavePhase != wavePhase ||
      old.bubbling != bubbling ||
      old.pourColor != pourColor ||
      old.pourProgress != pourProgress ||
      old.highlighted != highlighted ||
      old.capacityMl != capacityMl ||
      old.solidColor != solidColor ||
      old.precipitateColor != precipitateColor ||
      old.fumesColor != fumesColor ||
      old.pourSolid != pourSolid;
}
