import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme.dart';

/// Rotating compass rose: degree ticks every 5°, labels every 30°, Arabic cardinal letters
/// (ش north, ق east, ج south, غ west). Painted with north at the top; the caller rotates it by -heading.
class CompassDialPainter extends CustomPainter {
  CompassDialPainter({required this.p, required this.qibla, required this.aligned});
  final NoorPalette p;
  final double qibla;
  final bool aligned;

  static const _cardinals = {0: 'ش', 90: 'ق', 180: 'ج', 270: 'غ'};

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    final tickPaint = Paint()..strokeCap = StrokeCap.round;

    // Qibla arc highlight on the rim.
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.035
      ..strokeCap = StrokeCap.round
      ..color = p.gold.withValues(alpha: aligned ? 0.95 : 0.55);
    canvas.drawArc(Rect.fromCircle(center: c, radius: r * 0.93), _rad(qibla - 90 - 12), _rad(24), false, arc);

    for (var d = 0; d < 360; d += 5) {
      final major = d % 30 == 0;
      final card = d % 90 == 0;
      final len = card ? r * 0.085 : (major ? r * 0.065 : r * 0.035);
      final a = _rad(d - 90);
      final o = c + Offset(math.cos(a), math.sin(a)) * (r * 0.88);
      final i = c + Offset(math.cos(a), math.sin(a)) * (r * 0.88 - len);
      tickPaint
        ..strokeWidth = card ? 2.4 : (major ? 1.6 : 1)
        ..color = d == 0 ? p.danger : (major ? p.text.withValues(alpha: 0.85) : p.textFaint.withValues(alpha: 0.7));
      canvas.drawLine(i, o, tickPaint);

      if (major && !card) {
        _text(canvas, '$d', c + Offset(math.cos(a), math.sin(a)) * (r * 0.68), r * 0.06, p.textSoft, FontWeight.w500, d.toDouble());
      }
    }
    _cardinals.forEach((deg, label) {
      final a = _rad(deg - 90);
      _text(canvas, label, c + Offset(math.cos(a), math.sin(a)) * (r * 0.66), r * 0.11, deg == 0 ? p.danger : p.text, FontWeight.w700, deg.toDouble());
    });

    // Inner rings.
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = p.hairline;
    canvas.drawCircle(c, r * 0.52, ring);
    canvas.drawCircle(c, r * 0.30, ring..color = p.hairline.withValues(alpha: 0.6));
  }

  /// Draws [s] centred at [at], rotated so it stays upright relative to the dial direction.
  void _text(Canvas canvas, String s, Offset at, double size, Color color, FontWeight w, double deg) {
    final tp = TextPainter(
      text: TextSpan(text: s, style: TextStyle(fontFamily: NoorFonts.ui, fontSize: size, color: color, fontWeight: w)),
      textDirection: TextDirection.ltr,
    )..layout();
    canvas.save();
    canvas.translate(at.dx, at.dy);
    canvas.rotate(_rad(deg));
    tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
    canvas.restore();
  }

  static double _rad(num d) => d * math.pi / 180;

  @override
  bool shouldRepaint(covariant CompassDialPainter old) => old.p != p || old.qibla != qibla || old.aligned != aligned;
}

/// Fixed lubber line at 12 o'clock showing where the top of the phone points.
class LubberPainter extends CustomPainter {
  LubberPainter(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width / 2, 0)
      ..lineTo(size.width / 2 - 9, 16)
      ..lineTo(size.width / 2 + 9, 16)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant LubberPainter old) => old.color != color;
}

/// Qibla needle from the centre towards the Kaaba (drawn pointing up; the caller rotates it).
class NeedlePainter extends CustomPainter {
  NeedlePainter({required this.color, required this.tail});
  final Color color;
  final Color tail;
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    final head = Path()
      ..moveTo(c.dx, c.dy - r * 0.50)
      ..lineTo(c.dx - r * 0.055, c.dy)
      ..lineTo(c.dx + r * 0.055, c.dy)
      ..close();
    canvas.drawPath(head, Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [color, color.withValues(alpha: 0.55)]).createShader(Rect.fromLTWH(c.dx - r * 0.06, c.dy - r * 0.5, r * 0.12, r * 0.5)));
    final back = Path()
      ..moveTo(c.dx, c.dy + r * 0.30)
      ..lineTo(c.dx - r * 0.04, c.dy)
      ..lineTo(c.dx + r * 0.04, c.dy)
      ..close();
    canvas.drawPath(back, Paint()..color = tail);
  }

  @override
  bool shouldRepaint(covariant NeedlePainter old) => old.color != color || old.tail != tail;
}
