import 'dart:math' as math;
import 'package:flutter/material.dart';

/// The splash canvas colours.
///
/// These are duplicated in three other places that have to match exactly, or
/// the user sees a colour flash during hand-off:
///   * android/app/src/main/res/values/colors.xml          (splash_ink)
///   * android/app/src/main/res/drawable/splash_gradient.xml
///   * ios/Runner/Assets.xcassets/LaunchBackground.imageset/background.png
/// Change one, change all four.
const Color kSplashInk = Color(0xFF0E0E12);
const Color kSplashInkLow = Color(0xFF16161C);

/// Dark canvas with a soft brand-coloured glow in the upper left.
///
/// Deliberately the same treatment as the web landing page hero and the admin
/// sign-in screen, so the product reads as one brand across web and mobile.
class SplashBackdrop extends StatelessWidget {
  final Color accent;
  const SplashBackdrop({super.key, required this.accent});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [kSplashInkLow, kSplashInk],
        ),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(-0.65, -0.75),
            radius: 1.1,
            colors: [accent.withValues(alpha: 0.30), Colors.transparent],
          ),
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

/// A city map with a route drawing itself across it.
///
/// [progress] runs 0 to 1: the street grid fades in first, the route draws from
/// the pickup dot, a vehicle rides the head of the line, and the destination pin
/// drops in at the end.
///
/// Set [reversed] for the driver app, where the story is a job arriving rather
/// than a trip departing, so the route draws the other way down the screen.
class RouteMapPainter extends CustomPainter {
  final Animation<double> animation;
  final Color accent;
  final bool reversed;

  RouteMapPainter({
    required this.animation,
    required this.accent,
    this.reversed = false,
  }) : super(repaint: animation);

  /// Read live from the controller rather than captured at construction, so the
  /// painter repaints off `repaint:` alone and the screen needs no
  /// AnimatedBuilder rebuilding the widget tree every frame.
  double get progress => animation.value;

  // Eased sub-timeline helper: maps [progress] inside [start]..[end] to 0..1.
  double _phase(double start, double end, {Curve curve = Curves.easeOutCubic}) {
    if (end <= start) return progress >= end ? 1 : 0;
    final t = ((progress - start) / (end - start)).clamp(0.0, 1.0);
    return curve.transform(t);
  }

  Path _routePath(Size size) {
    final w = size.width;
    final h = size.height;
    final path = Path();
    if (reversed) {
      path
        ..moveTo(w * 0.88, h * 0.14)
        ..cubicTo(w * 0.88, h * 0.32, w * 0.52, h * 0.30, w * 0.52, h * 0.50)
        ..cubicTo(w * 0.52, h * 0.70, w * 0.14, h * 0.68, w * 0.14, h * 0.88);
    } else {
      path
        ..moveTo(w * 0.12, h * 0.88)
        ..cubicTo(w * 0.12, h * 0.70, w * 0.48, h * 0.72, w * 0.48, h * 0.52)
        ..cubicTo(w * 0.48, h * 0.32, w * 0.88, h * 0.34, w * 0.88, h * 0.14);
    }
    return path;
  }

  void _paintCity(Canvas canvas, Size size, double fade) {
    if (fade <= 0) return;
    final w = size.width;
    final h = size.height;

    final major = Paint()
      ..color = Colors.white.withValues(alpha: 0.030 * fade)
      ..strokeWidth = w * 0.045
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final minor = Paint()
      ..color = Colors.white.withValues(alpha: 0.016 * fade)
      ..strokeWidth = w * 0.016
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // Fractions rather than fixed pixels, so the grid keeps its proportions on
    // every screen size instead of getting denser on tablets.
    for (final f in [0.17, 0.46, 0.78]) {
      canvas.drawLine(Offset(-w * 0.1, h * f), Offset(w * 1.1, h * f), major);
    }
    for (final f in [0.30, 0.62, 0.92]) {
      canvas.drawLine(Offset(-w * 0.1, h * f), Offset(w * 1.1, h * f), minor);
    }
    for (final f in [0.22, 0.68]) {
      canvas.drawLine(Offset(w * f, -h * 0.1), Offset(w * f, h * 1.1), major);
    }
    for (final f in [0.44, 0.88]) {
      canvas.drawLine(Offset(w * f, -h * 0.1), Offset(w * f, h * 1.1), minor);
    }

    // City blocks, for a little texture between the streets
    final block = Paint()..color = Colors.white.withValues(alpha: 0.010 * fade);
    const blocks = <List<double>>[
      [0.04, 0.04, 0.13, 0.09],
      [0.30, 0.05, 0.11, 0.08],
      [0.74, 0.22, 0.14, 0.08],
      [0.05, 0.54, 0.12, 0.06],
      [0.76, 0.82, 0.15, 0.09],
      [0.28, 0.84, 0.12, 0.06],
    ];
    for (final b in blocks) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(w * b[0], h * b[1], w * b[2], h * b[3]),
          Radius.circular(w * 0.02),
        ),
        block,
      );
    }
  }

  void _paintPin(Canvas canvas, Offset at, double t, double scale) {
    if (t <= 0) return;
    final drop = (1 - t) * 48 * scale;
    final c = at.translate(0, -drop);
    final r = 9.0 * scale * t;

    final body = Path()
      ..moveTo(c.dx, c.dy)
      ..cubicTo(c.dx - 16 * scale, c.dy - 14 * scale, c.dx - 13 * scale,
          c.dy - 34 * scale, c.dx, c.dy - 34 * scale)
      ..cubicTo(c.dx + 13 * scale, c.dy - 34 * scale, c.dx + 16 * scale,
          c.dy - 14 * scale, c.dx, c.dy);

    canvas.drawPath(body, Paint()..color = accent.withValues(alpha: t));
    canvas.drawCircle(
      Offset(c.dx, c.dy - 23 * scale),
      r * 0.55,
      Paint()..color = Colors.white.withValues(alpha: t),
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final scale = (size.width / 390).clamp(0.75, 1.6);

    _paintCity(canvas, size, _phase(0.00, 0.35));

    final draw = _phase(0.12, 0.78);
    if (draw <= 0) return;

    final path = _routePath(size);
    final metrics = path.computeMetrics().toList();
    if (metrics.isEmpty) return;
    final metric = metrics.first;
    final drawn = metric.extractPath(0, metric.length * draw);

    // Glow under the route, so it reads as lit rather than painted on
    canvas.drawPath(
      drawn,
      Paint()
        ..color = accent.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 14 * scale
        ..strokeCap = StrokeCap.round
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 10 * scale),
    );

    canvas.drawPath(
      drawn,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.bottomLeft,
          end: Alignment.topRight,
          colors: [Color.lerp(accent, Colors.white, 0.45)!, accent],
        ).createShader(Offset.zero & size)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5 * scale
        ..strokeCap = StrokeCap.round,
    );

    // Pickup marker at the start of the line
    final start = metric.getTangentForOffset(0)!.position;
    canvas.drawCircle(start, 9 * scale, Paint()..color = kSplashInk);
    canvas.drawCircle(
      start,
      9 * scale,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5 * scale,
    );

    // The vehicle riding the head of the line
    if (draw < 1) {
      final head = metric.getTangentForOffset(metric.length * draw)!.position;
      canvas.drawCircle(
        head,
        13 * scale,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.22)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 8 * scale),
      );
      canvas.drawCircle(head, 5.5 * scale, Paint()..color = Colors.white);
    }

    _paintPin(
      canvas,
      metric.getTangentForOffset(metric.length)!.position,
      _phase(0.70, 0.95, curve: Curves.easeOutBack),
      scale,
    );
  }

  @override
  bool shouldRepaint(covariant RouteMapPainter old) =>
      old.animation != animation || old.accent != accent || old.reversed != reversed;
}

/// Ink wash centred on the lockup.
///
/// Sits between the route and the logo. Without it the route runs straight
/// through the wordmark and fights the red speed streak inside the mark, which
/// made the logo look broken; this lets the line dissolve as it approaches the
/// lockup so the brand always reads cleanly.
class SplashLogoScrim extends StatelessWidget {
  /// Vertical centre of the wash, in Alignment units, matched to where the
  /// Column actually places the logo.
  final double centerY;
  const SplashLogoScrim({super.key, this.centerY = -0.08});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, centerY),
            radius: 0.62,
            colors: [
              kSplashInk,
              kSplashInk.withValues(alpha: 0.92),
              kSplashInk.withValues(alpha: 0.0),
            ],
            stops: const [0.0, 0.42, 1.0],
          ),
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

/// Thin indeterminate loading bar.
///
/// The splash has no idea how long configuration will take (it waits on the
/// /configuration call and on connectivity), so this is deliberately
/// indeterminate rather than a fake percentage.
class SplashLoadingBar extends StatelessWidget {
  final Animation<double> animation;
  final Color accent;
  final bool animate;
  const SplashLoadingBar({
    super.key,
    required this.animation,
    required this.accent,
    this.animate = true,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 132,
      height: 3,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: Stack(children: [
          Container(color: Colors.white.withValues(alpha: 0.10)),
          if (animate)
            AnimatedBuilder(
              animation: animation,
              builder: (_, __) => Align(
                // -1..1 sweep, so the highlight runs the full width and loops
                alignment: Alignment(
                  math.sin(animation.value * 2 * math.pi) * 1.0,
                  0,
                ),
                child: FractionallySizedBox(
                  widthFactor: 0.42,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(3),
                      gradient: LinearGradient(colors: [
                        accent.withValues(alpha: 0.0),
                        accent,
                        accent.withValues(alpha: 0.0),
                      ]),
                    ),
                  ),
                ),
              ),
            )
          else
            Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: 0.42,
                child: ColoredBox(color: accent),
              ),
            ),
        ]),
      ),
    );
  }
}
