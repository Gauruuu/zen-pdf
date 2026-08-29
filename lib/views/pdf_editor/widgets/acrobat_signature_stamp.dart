import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AcrobatSignatureStamp extends StatelessWidget {
  final String signerName;
  final DateTime signingDate;
  final bool isVerified;
  final VoidCallback? onTap;
  final VoidCallback? onSecondaryTap;

  const AcrobatSignatureStamp({
    super.key,
    required this.signerName,
    required this.signingDate,
    required this.isVerified,
    this.onTap,
    this.onSecondaryTap,
  });

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('yyyy.MM.dd HH:mm:ss').format(signingDate);

    return InkWell(
      onTap: onTap,
      onSecondaryTap: onSecondaryTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(3),
          border: Border.all(
            color: isVerified ? Colors.transparent : Colors.blueAccent.withValues(alpha: 0.3),
            width: 0.8,
          ),
        ),
        child: SizedBox(
          width: 145,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Main Text Content
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isVerified ? 'Signature valid' : 'Signature Not Verified',
                    style: const TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Digitally signed by ${signerName.replaceAll("\n", " ")}',
                    style: const TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 7.5,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                      height: 1.2,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 1),
                  Text(
                    'Date: $dateStr\nIST',
                    style: const TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 7.0,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                      height: 1.15,
                    ),
                  ),
                ],
              ),

              // 3D Yellow Question Mark (Unverified) or 3D Green Tick Mark (Verified)
              Positioned(
                left: 20,
                top: 4,
                child: isVerified
                    ? CustomPaint(
                        size: const Size(28, 28),
                        painter: AcrobatGreenTickPainter(),
                      )
                    : CustomPaint(
                        size: const Size(22, 28),
                        painter: AcrobatYellowQuestionPainter(),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AcrobatGreenTickPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // 3D Shadow Path (Dark Shadow offset)
    final shadowPaint = Paint()
      ..color = const Color(0xFF000000)
      ..style = PaintingStyle.fill;

    final shadowPath = Path()
      ..moveTo(size.width * 0.05 + 1.2, size.height * 0.55 + 1.2)
      ..lineTo(size.width * 0.38 + 1.2, size.height * 0.95 + 1.2)
      ..lineTo(size.width * 0.95 + 1.2, size.height * 0.05 + 1.2)
      ..lineTo(size.width * 0.80 + 1.2, size.height * 0.00 + 1.2)
      ..lineTo(size.width * 0.35 + 1.2, size.height * 0.70 + 1.2)
      ..lineTo(size.width * 0.16 + 1.2, size.height * 0.45 + 1.2)
      ..close();

    canvas.drawPath(shadowPath, shadowPaint);

    // Front Bright Green Tick
    final greenPaint = Paint()
      ..color = const Color(0xFF009933) // Vivid Acrobat Green
      ..style = PaintingStyle.fill;

    final greenPath = Path()
      ..moveTo(size.width * 0.05, size.height * 0.55)
      ..lineTo(size.width * 0.38, size.height * 0.95)
      ..lineTo(size.width * 0.95, size.height * 0.05)
      ..lineTo(size.width * 0.80, size.height * 0.00)
      ..lineTo(size.width * 0.35, size.height * 0.70)
      ..lineTo(size.width * 0.16, size.height * 0.45)
      ..close();

    canvas.drawPath(greenPath, greenPaint);

    // Fine black border around the green tick
    final borderPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    canvas.drawPath(greenPath, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class AcrobatYellowQuestionPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const text = '?';
    const textStyle = TextStyle(
      fontSize: 26,
      fontWeight: FontWeight.bold,
      fontFamily: 'Arial',
    );

    // Draw shadow
    final textSpanShadow = TextSpan(
      text: text,
      style: textStyle.copyWith(color: Colors.black),
    );
    final textPainterShadow = TextPainter(
      text: textSpanShadow,
      textDirection: ui.TextDirection.ltr,
    )..layout();
    textPainterShadow.paint(canvas, const Offset(1.5, 1.5));

    // Draw yellow fill
    final textSpanFill = TextSpan(
      text: text,
      style: textStyle.copyWith(
        color: const Color(0xFFFDE047), // Acrobat Bright Yellow
      ),
    );
    final textPainterFill = TextPainter(
      text: textSpanFill,
      textDirection: ui.TextDirection.ltr,
    )..layout();
    textPainterFill.paint(canvas, Offset.zero);

    // Draw thin black stroke
    final textSpanStroke = TextSpan(
      text: text,
      style: textStyle.copyWith(
        foreground: Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8
          ..color = Colors.black,
      ),
    );
    final textPainterStroke = TextPainter(
      text: textSpanStroke,
      textDirection: ui.TextDirection.ltr,
    )..layout();
    textPainterStroke.paint(canvas, Offset.zero);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
