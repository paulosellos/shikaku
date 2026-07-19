import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// The little "puzzle face" mascot: a rounded square split into coloured
/// rectangles with a check-mark eye, echoing the benchmark win screen.
class Mascot extends StatelessWidget {
  final double size;
  final int variant;

  const Mascot({super.key, this.size = 140, this.variant = 0});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _MascotPainter(variant: variant)),
    );
  }
}

class _MascotPainter extends CustomPainter {
  final int variant;

  const _MascotPainter({required this.variant});

  Color _palette(int index, bool isDark) =>
      RectPalette.at(index + variant, isDark);

  @override
  void paint(Canvas canvas, Size size) {
    final r = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(size.width * 0.24),
    );
    canvas.save();
    canvas.clipRRect(r);

    final w = size.width;
    final h = size.height;

    final red = Paint()..color = _palette(7, false);
    final orange = Paint()..color = _palette(9, false);
    final blue = Paint()..color = _palette(1, false);

    // Left column (red), top-right (orange), bottom band (blue).
    canvas.drawRect(Rect.fromLTWH(0, 0, w * 0.42, h * 0.72), red);
    canvas.drawRect(Rect.fromLTWH(w * 0.42, 0, w * 0.58, h * 0.72), orange);
    canvas.drawRect(Rect.fromLTWH(0, h * 0.72, w, h * 0.28), blue);

    final divider = Paint()
      ..color = Colors.black.withValues(alpha: 0.55)
      ..strokeWidth = size.width * 0.02;
    canvas.drawLine(Offset(w * 0.42, 0), Offset(w * 0.42, h * 0.72), divider);
    canvas.drawLine(Offset(0, h * 0.72), Offset(w, h * 0.72), divider);

    _num(canvas, '2', Offset(w * 0.21, h * 0.36), size.width * 0.16);
    _num(canvas, '4', Offset(w * 0.71, h * 0.36), size.width * 0.16);
    _num(canvas, '3', Offset(w * 0.5, h * 0.86), size.width * 0.16);

    canvas.restore();

    // Check-mark "eye".
    final eyeCenter = Offset(w * 0.5, h * 0.4);
    final eyeR = w * 0.16;
    canvas.drawCircle(eyeCenter, eyeR, Paint()..color = const Color(0xFFF3EFEA));
    canvas.drawCircle(
      eyeCenter,
      eyeR,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.02
        ..color = Colors.black87,
    );
    final check = Path()
      ..moveTo(eyeCenter.dx - eyeR * 0.45, eyeCenter.dy)
      ..lineTo(eyeCenter.dx - eyeR * 0.1, eyeCenter.dy + eyeR * 0.4)
      ..lineTo(eyeCenter.dx + eyeR * 0.5, eyeCenter.dy - eyeR * 0.4);
    canvas.drawPath(
      check,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.035
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = Colors.black87,
    );
  }

  void _num(Canvas canvas, String s, Offset center, double fontSize) {
    final tp = TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(
          fontFamily: AppTheme.serif,
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          color: Colors.black87,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant _MascotPainter oldDelegate) =>
      oldDelegate.variant != variant;
}
