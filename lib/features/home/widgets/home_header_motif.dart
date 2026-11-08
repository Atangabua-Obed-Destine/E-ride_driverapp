import 'package:flutter/material.dart';

/// The E-Ride route motif from the splash, reduced to a faint trace in the
/// dark home header: a thin red route from an origin ring up to a pin, over a
/// barely-there street grid. Painted to the right of the greeting so it never
/// sits behind text.
class HomeHeaderMotif extends StatelessWidget {
  final Color accent;
  const HomeHeaderMotif({super.key, required this.accent});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(painter: _MotifPainter(accent: accent), size: Size.infinite),
    );
  }
}

class _MotifPainter extends CustomPainter {
  final Color accent;
  _MotifPainter({required this.accent});

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width, h = size.height;

    final grid = Paint()
      ..color = Colors.white.withValues(alpha: 0.035)
      ..strokeWidth = 1;
    for (double x = w * 0.08; x < w; x += 58) {
      canvas.drawLine(Offset(x, 0), Offset(x, h), grid);
    }
    for (double y = 14; y < h; y += 46) {
      canvas.drawLine(Offset(0, y), Offset(w, y), grid);
    }

    // Driver app: the route arrives, so it runs from a pin at the top down
    // to the origin ring near the bottom right.
    final Offset pin = Offset(w * 0.68, h * 0.14);
    final Offset origin = Offset(w * 0.92, h * 0.94);
    final Path route = Path()
      ..moveTo(pin.dx, pin.dy)
      ..cubicTo(w * 0.72, h * 0.55, w * 0.86, h * 0.60, origin.dx, origin.dy);

    // Glow as two soft strokes rather than a MaskFilter blur: a blur inside a
    // scroll view's layer can blank the whole layer on Impeller / OpenGL ES.
    canvas.drawPath(
      route,
      Paint()
        ..color = accent.withValues(alpha: 0.07)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 14
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawPath(
      route,
      Paint()
        ..color = accent.withValues(alpha: 0.12)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawPath(
      route,
      Paint()
        ..color = accent.withValues(alpha: 0.65)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round,
    );

    canvas.drawCircle(
      origin, 5,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    canvas.drawCircle(pin, 10, Paint()..color = accent.withValues(alpha: 0.22));
    canvas.drawCircle(pin, 5.5, Paint()..color = accent);
    canvas.drawCircle(pin, 2, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _MotifPainter old) => old.accent != accent;
}
