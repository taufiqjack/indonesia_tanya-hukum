import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The four-colour Google "G", drawn instead of shipping an image asset.
class GoogleLogo extends StatelessWidget {
  const GoogleLogo({super.key, this.size = 20});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _GoogleLogoPainter()),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  static const _blue = Color(0xFF4285F4);
  static const _green = Color(0xFF34A853);
  static const _yellow = Color(0xFFFBBC05);
  static const _red = Color(0xFFEA4335);

  /// Ring segments as (colour, start, sweep) in degrees, 0° pointing right and
  /// growing clockwise. The gap on the right is where the bar comes out.
  static const _segments = <({Color color, double start, double sweep})>[
    (color: _blue, start: -35, sweep: 45),
    (color: _green, start: 25, sweep: 105),
    (color: _yellow, start: 130, sweep: 60),
    (color: _red, start: 192, sweep: 138),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final side = math.min(size.width, size.height);
    final stroke = side * 0.26;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (side - stroke) / 2;
    final box = Rect.fromCircle(center: center, radius: radius);

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.butt;

    for (final segment in _segments) {
      canvas.drawArc(
        box,
        _radians(segment.start),
        _radians(segment.sweep),
        false,
        paint..color = segment.color,
      );
    }

    // The crossbar, sitting just below the middle and running out to the edge.
    canvas.drawRect(
      Rect.fromLTRB(
        center.dx - stroke * 0.05,
        center.dy - stroke * 0.12,
        center.dx + radius + stroke / 2,
        center.dy + stroke * 0.88,
      ),
      Paint()..color = _blue,
    );
  }

  double _radians(double degrees) => degrees * math.pi / 180;

  @override
  bool shouldRepaint(covariant _GoogleLogoPainter oldDelegate) => false;
}
