import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Animated "drivers near you" radar for the set-location screen.
///
/// Painted rather than an asset for two reasons. The old illustration
/// (map_location_icon.png) is teal, which is off-brand, and it is also used as
/// the Google Maps marker bitmap in three other places, so recolouring the file
/// would have changed the markers on every map in the app. This draws its own
/// artwork from the theme's brand colour instead and leaves that asset alone.
class LocationRadar extends StatefulWidget {
  final double size;
  const LocationRadar({super.key, this.size = 236});

  @override
  State<LocationRadar> createState() => _LocationRadarState();
}

class _LocationRadarState extends State<LocationRadar> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Honour the OS "remove animations" setting: hold a static frame instead.
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      _pulse.stop();
      _pulse.value = 0.45;
    } else if (!_pulse.isAnimating) {
      _pulse.repeat();
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: CustomPaint(
        painter: _RadarPainter(
          animation: _pulse,
          accent: theme.primaryColor,
          marker: theme.textTheme.bodyMedium?.color ?? const Color(0xFF1D2D2B),
          ring: theme.hintColor,
        ),
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  final Animation<double> animation;
  final Color accent;
  final Color marker;
  final Color ring;

  _RadarPainter({
    required this.animation,
    required this.accent,
    required this.marker,
    required this.ring,
  }) : super(repaint: animation);

  double get t => animation.value;

  void _dashedCircle(Canvas canvas, Offset c, double r, Paint paint, {int dashes = 60}) {
    final sweep = 2 * math.pi / dashes;
    final rect = Rect.fromCircle(center: c, radius: r);
    for (int i = 0; i < dashes; i++) {
      canvas.drawArc(rect, i * sweep, sweep * 0.45, false, paint);
    }
  }

  /// Small car, the same silhouette used in the onboarding artwork.
  void _car(Canvas canvas, Offset at, double s, Color body) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: at, width: s * 2.5, height: s * 1.35),
        Radius.circular(s * 0.5),
      ),
      Paint()..color = body,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: at.translate(0, -s * 0.74), width: s * 1.55, height: s * 0.86),
        Radius.circular(s * 0.32),
      ),
      Paint()..color = body,
    );
    final tyre = Paint()..color = Colors.white.withValues(alpha: 0.85);
    canvas.drawCircle(at.translate(-s * 0.68, s * 0.62), s * 0.22, tyre);
    canvas.drawCircle(at.translate(s * 0.68, s * 0.62), s * 0.22, tyre);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;

    // Soft discs, so the centre reads as "here"
    canvas.drawCircle(c, r * 0.76, Paint()..color = accent.withValues(alpha: 0.045));
    canvas.drawCircle(c, r * 0.50, Paint()..color = accent.withValues(alpha: 0.075));

    // Outer boundary, a nod to the original dashed ring
    _dashedCircle(
      canvas,
      c,
      r * 0.95,
      Paint()
        ..color = ring.withValues(alpha: 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..strokeCap = StrokeCap.round,
    );

    // Three pulses, staggered so one is always mid-flight
    for (int i = 0; i < 3; i++) {
      final p = (t + i / 3) % 1.0;
      final eased = Curves.easeOutCubic.transform(p);
      canvas.drawCircle(
        c,
        r * (0.22 + 0.72 * eased),
        Paint()
          ..color = accent.withValues(alpha: (1 - p) * 0.40)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0,
      );
    }

    // Nearby drivers, drifting gently so the scene feels live
    const angles = [-0.62, 2.35, 3.95];
    const radii = [0.74, 0.62, 0.80];
    for (int i = 0; i < angles.length; i++) {
      final bob = math.sin((t * 2 * math.pi) + i * 2.1) * r * 0.022;
      final at = Offset(
        c.dx + math.cos(angles[i]) * r * radii[i],
        c.dy + math.sin(angles[i]) * r * radii[i] + bob,
      );
      _car(canvas, at, r * 0.072, i == 0 ? accent : marker.withValues(alpha: 0.38));
    }

    // The pin, tip resting on the exact centre
    final s = r * 0.20;
    final tip = c.translate(0, s * 0.9);
    canvas.drawOval(
      Rect.fromCenter(center: tip.translate(0, s * 0.18), width: s * 1.5, height: s * 0.42),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.13)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.18),
    );
    final pin = Path()
      ..moveTo(tip.dx, tip.dy)
      ..cubicTo(tip.dx - s * 1.02, tip.dy - s * 0.95, tip.dx - s * 0.84, tip.dy - s * 2.25, tip.dx, tip.dy - s * 2.25)
      ..cubicTo(tip.dx + s * 0.84, tip.dy - s * 2.25, tip.dx + s * 1.02, tip.dy - s * 0.95, tip.dx, tip.dy);
    canvas.drawPath(pin, Paint()..color = accent);
    canvas.drawCircle(Offset(tip.dx, tip.dy - s * 1.48), s * 0.40, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _RadarPainter old) =>
      old.accent != accent || old.marker != marker || old.ring != ring || old.animation != animation;
}
