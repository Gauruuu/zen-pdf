import 'dart:math' as math;
import 'package:flutter/material.dart';

class FidgetSpinnerLoader extends StatefulWidget {
  final double size;
  final String? message;
  final Color? primaryColor;
  final bool interactive;

  const FidgetSpinnerLoader({
    super.key,
    this.size = 64.0,
    this.message,
    this.primaryColor,
    this.interactive = false,
  });

  @override
  State<FidgetSpinnerLoader> createState() => _FidgetSpinnerLoaderState();
}

class _FidgetSpinnerLoaderState extends State<FidgetSpinnerLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Transform.rotate(
              angle: _controller.value * 2 * math.pi,
              child: CustomPaint(
                size: Size(widget.size, widget.size),
                painter: _FidgetSpinnerPainter(
                  primaryColor: widget.primaryColor ?? const Color(0xFF2563EB),
                ),
              ),
            );
          },
        ),
        if (widget.message != null) ...[
          const SizedBox(height: 14),
          Text(
            widget.message!,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF64748B),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}

class _FidgetSpinnerPainter extends CustomPainter {
  final Color primaryColor;

  _FidgetSpinnerPainter({required this.primaryColor});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final wingDistance = radius * 0.58;
    final wingRadius = radius * 0.38;
    final holeRadius = wingRadius * 0.45;
    final centerCapRadius = radius * 0.36;

    final wingColors = [
      primaryColor,
      const Color(0xFFE11D48), // Crimson
      const Color(0xFF10B981), // Emerald
    ];

    // Draw the 3 Wings
    for (int i = 0; i < 3; i++) {
      final angle = (i * 2 * math.pi / 3) - (math.pi / 2);
      final wingCenter = Offset(
        center.dx + wingDistance * math.cos(angle),
        center.dy + wingDistance * math.sin(angle),
      );

      // Connecting arm from center to wing
      final armPaint = Paint()
        ..color = const Color(0xFF1E293B)
        ..style = PaintingStyle.fill;
      
      final path = Path();
      final perpAngle = angle + math.pi / 2;
      final armWidth = wingRadius * 0.9;
      final p1 = Offset(center.dx + (armWidth / 2) * math.cos(perpAngle), center.dy + (armWidth / 2) * math.sin(perpAngle));
      final p2 = Offset(center.dx - (armWidth / 2) * math.cos(perpAngle), center.dy - (armWidth / 2) * math.sin(perpAngle));
      final p3 = Offset(wingCenter.dx - (armWidth / 2) * math.cos(perpAngle), wingCenter.dy - (armWidth / 2) * math.sin(perpAngle));
      final p4 = Offset(wingCenter.dx + (armWidth / 2) * math.cos(perpAngle), wingCenter.dy + (armWidth / 2) * math.sin(perpAngle));
      
      path.moveTo(p1.dx, p1.dy);
      path.lineTo(p2.dx, p2.dy);
      path.lineTo(p3.dx, p3.dy);
      path.lineTo(p4.dx, p4.dy);
      path.close();
      canvas.drawPath(path, armPaint);

      // Wing Outer Circle
      final wingPaint = Paint()
        ..shader = RadialGradient(
          colors: [
            wingColors[i],
            wingColors[i].withValues(alpha: 0.8),
          ],
        ).createShader(Rect.fromCircle(center: wingCenter, radius: wingRadius))
        ..style = PaintingStyle.fill;

      canvas.drawCircle(wingCenter, wingRadius, wingPaint);

      // Metallic Bearing Ring
      final ringPaint = Paint()
        ..color = const Color(0xFF0F172A)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5;
      canvas.drawCircle(wingCenter, wingRadius, ringPaint);

      // Wing Center Hole / Bearing
      final holePaint = Paint()
        ..color = const Color(0xFFF8FAFC)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(wingCenter, holeRadius, holePaint);

      final innerBearing = Paint()
        ..color = const Color(0xFF94A3B8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      canvas.drawCircle(wingCenter, holeRadius * 0.65, innerBearing);
    }

    // Center Hub Cap (Base)
    final centerBasePaint = Paint()
      ..color = const Color(0xFF0F172A)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, centerCapRadius * 1.15, centerBasePaint);

    // Center Metallic Cap
    final centerCapPaint = Paint()
      ..shader = const RadialGradient(
        colors: [
          Color(0xFFE2E8F0),
          Color(0xFF94A3B8),
          Color(0xFF475569),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: centerCapRadius))
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, centerCapRadius, centerCapPaint);

    // Center Logo Ring
    final centerRing = Paint()
      ..color = const Color(0xFF2563EB)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawCircle(center, centerCapRadius * 0.55, centerRing);

    final centerDot = Paint()
      ..color = const Color(0xFF2563EB)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, centerCapRadius * 0.25, centerDot);
  }

  @override
  bool shouldRepaint(covariant _FidgetSpinnerPainter oldDelegate) => false;
}
