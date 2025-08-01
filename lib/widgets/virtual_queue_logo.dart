import 'package:flutter/material.dart';

class VirtualQueueLogo extends StatelessWidget {
  final double size;
  final bool showText;
  final Color? primaryColor;
  final Color? accentColor;

  const VirtualQueueLogo({
    super.key,
    this.size = 100,
    this.showText = true,
    this.primaryColor,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: VirtualQueueLogoPainter(
          primaryColor: primaryColor ?? Theme.of(context).primaryColor,
          accentColor: accentColor ?? Colors.green,
          showText: showText,
        ),
        size: Size(size, size),
      ),
    );
  }
}

class VirtualQueueLogoPainter extends CustomPainter {
  final Color primaryColor;
  final Color accentColor;
  final bool showText;

  VirtualQueueLogoPainter({
    required this.primaryColor,
    required this.accentColor,
    required this.showText,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Create gradient for background
    const gradient = RadialGradient(
      center: Alignment.topLeft,
      radius: 1.2,
      colors: [
        Color(0xFF6366F1), // Indigo
        Color(0xFF8B5CF6), // Purple
        Color(0xFFA855F7), // Purple
      ],
      stops: [0.0, 0.5, 1.0],
    );

    // Paint background circle
    final backgroundPaint =
        Paint()
          ..shader = gradient.createShader(
            Rect.fromCircle(center: center, radius: radius),
          )
          ..style = PaintingStyle.fill;

    canvas.drawCircle(center, radius * 0.95, backgroundPaint);

    // Draw inner circle for depth
    final innerCirclePaint =
        Paint()
          ..color = Colors.white.withOpacity(0.1)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1;

    canvas.drawCircle(center, radius * 0.8, innerCirclePaint);

    // Draw queue people
    _drawQueuePeople(canvas, size);

    // Draw digital elements
    _drawDigitalElements(canvas, size);

    // Draw center position indicator
    _drawCenterPosition(canvas, size);

    // Draw curved text if enabled
    if (showText) {
      _drawCurvedText(canvas, size);
    }

    // Draw decorative dots
    _drawDecorativeDots(canvas, size);
  }

  void _drawQueuePeople(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // Person 1 (Active - Green)
    _drawPerson(
      canvas,
      Offset(center.dx - size.width * 0.15, center.dy - size.height * 0.2),
      size.width * 0.04,
      accentColor,
      isActive: true,
    );

    // Person 2 (Waiting - White)
    _drawPerson(
      canvas,
      Offset(center.dx, center.dy - size.height * 0.15),
      size.width * 0.035,
      Colors.white.withOpacity(0.9),
    );

    // Person 3 (Waiting - White)
    _drawPerson(
      canvas,
      Offset(center.dx + size.width * 0.15, center.dy - size.height * 0.1),
      size.width * 0.03,
      Colors.white.withOpacity(0.7),
    );
  }

  void _drawPerson(
    Canvas canvas,
    Offset position,
    double scale,
    Color color, {
    bool isActive = false,
  }) {
    final paint =
        Paint()
          ..color = color
          ..style = PaintingStyle.fill;

    // Head
    canvas.drawCircle(position, scale * 2, paint);

    // Body
    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: position + Offset(0, scale * 4),
        width: scale * 3,
        height: scale * 5,
      ),
      Radius.circular(scale * 1.5),
    );
    canvas.drawRRect(bodyRect, paint);

    // Arms
    final leftArm = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: position + Offset(-scale * 2.5, scale * 4.5),
        width: scale,
        height: scale * 3,
      ),
      Radius.circular(scale * 0.5),
    );
    final rightArm = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: position + Offset(scale * 2.5, scale * 4.5),
        width: scale,
        height: scale * 3,
      ),
      Radius.circular(scale * 0.5),
    );
    canvas.drawRRect(leftArm, paint);
    canvas.drawRRect(rightArm, paint);

    // Legs
    final leftLeg = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: position + Offset(-scale * 1, scale * 8),
        width: scale,
        height: scale * 3.5,
      ),
      Radius.circular(scale * 0.5),
    );
    final rightLeg = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: position + Offset(scale * 1, scale * 8),
        width: scale,
        height: scale * 3.5,
      ),
      Radius.circular(scale * 0.5),
    );
    canvas.drawRRect(leftLeg, paint);
    canvas.drawRRect(rightLeg, paint);
  }

  void _drawDigitalElements(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // Clock
    _drawClock(
      canvas,
      Offset(center.dx - size.width * 0.2, center.dy + size.height * 0.2),
      size.width * 0.06,
    );

    // Mobile phone
    _drawMobilePhone(
      canvas,
      Offset(center.dx + size.width * 0.2, center.dy + size.height * 0.2),
      size.width * 0.06,
    );

    // Flow arrow
    _drawFlowArrow(canvas, size);
  }

  void _drawClock(Canvas canvas, Offset position, double radius) {
    final paint =
        Paint()
          ..color = Colors.white.withOpacity(0.2)
          ..style = PaintingStyle.fill;

    final strokePaint =
        Paint()
          ..color = Colors.white.withOpacity(0.6)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2;

    // Clock face
    canvas.drawCircle(position, radius, paint);
    canvas.drawCircle(position, radius, strokePaint);

    // Clock hands
    final handPaint =
        Paint()
          ..color = Colors.white.withOpacity(0.8)
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 2;

    // Hour hand (pointing up)
    canvas.drawLine(position, position - Offset(0, radius * 0.6), handPaint);
    // Minute hand (pointing right)
    canvas.drawLine(
      position,
      position + Offset(radius * 0.4, 0),
      Paint()
        ..color = Colors.white.withOpacity(0.8)
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 1.5,
    );

    // Center dot
    canvas.drawCircle(
      position,
      radius * 0.15,
      Paint()..color = Colors.white.withOpacity(0.8),
    );
  }

  void _drawMobilePhone(Canvas canvas, Offset position, double scale) {
    final paint =
        Paint()
          ..color = Colors.white.withOpacity(0.2)
          ..style = PaintingStyle.fill;

    final strokePaint =
        Paint()
          ..color = Colors.white.withOpacity(0.6)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2;

    // Phone body
    final phoneRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: position, width: scale * 1.2, height: scale * 2),
      Radius.circular(scale * 0.3),
    );
    canvas.drawRRect(phoneRect, paint);
    canvas.drawRRect(phoneRect, strokePaint);

    // Screen
    final screenRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: position - Offset(0, scale * 0.1),
        width: scale * 0.8,
        height: scale * 1.2,
      ),
      Radius.circular(scale * 0.1),
    );
    canvas.drawRRect(
      screenRect,
      Paint()..color = Colors.white.withOpacity(0.4),
    );

    // Home button
    canvas.drawCircle(
      position + Offset(0, scale * 0.7),
      scale * 0.15,
      Paint()..color = Colors.white.withOpacity(0.6),
    );
  }

  void _drawFlowArrow(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint =
        Paint()
          ..color = Colors.white.withOpacity(0.6)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round;

    // Curved path for queue flow
    final path = Path();
    path.moveTo(center.dx - size.width * 0.25, center.dy);
    path.quadraticBezierTo(
      center.dx,
      center.dy - size.height * 0.1,
      center.dx + size.width * 0.25,
      center.dy,
    );

    canvas.drawPath(path, paint);

    // Arrow head
    final arrowPaint =
        Paint()
          ..color = Colors.white.withOpacity(0.6)
          ..style = PaintingStyle.fill;

    final arrowPath = Path();
    final arrowTip = Offset(center.dx + size.width * 0.27, center.dy);
    arrowPath.moveTo(arrowTip.dx, arrowTip.dy);
    arrowPath.lineTo(
      arrowTip.dx - size.width * 0.03,
      arrowTip.dy - size.width * 0.015,
    );
    arrowPath.lineTo(
      arrowTip.dx - size.width * 0.03,
      arrowTip.dy + size.width * 0.015,
    );
    arrowPath.close();

    canvas.drawPath(arrowPath, arrowPaint);
  }

  void _drawCenterPosition(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.1;

    // Background circle
    final bgPaint =
        Paint()
          ..color = Colors.white.withOpacity(0.15)
          ..style = PaintingStyle.fill;

    final strokePaint =
        Paint()
          ..color = Colors.white.withOpacity(0.4)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2;

    canvas.drawCircle(center + Offset(0, size.height * 0.125), radius, bgPaint);
    canvas.drawCircle(
      center + Offset(0, size.height * 0.125),
      radius,
      strokePaint,
    );

    // Position number
    final textPainter = TextPainter(
      text: TextSpan(
        text: '#1',
        style: TextStyle(
          color: Colors.white,
          fontSize: size.width * 0.09,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );

    textPainter.layout();
    textPainter.paint(
      canvas,
      center +
          Offset(0, size.height * 0.125) -
          Offset(textPainter.width / 2, textPainter.height / 2),
    );
  }

  void _drawCurvedText(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // Create text painter for "VIRTUAL QUEUE"
    final textPainter = TextPainter(
      text: TextSpan(
        text: 'VIRTUAL QUEUE',
        style: TextStyle(
          color: Colors.white.withOpacity(0.8),
          fontSize: size.width * 0.06,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.5,
        ),
      ),
      textDirection: TextDirection.ltr,
    );

    textPainter.layout();

    // Paint the text at the top of the circle
    textPainter.paint(
      canvas,
      center - Offset(textPainter.width / 2, size.height * 0.35),
    );
  }

  void _drawDecorativeDots(Canvas canvas, Size size) {
    final dotPaint =
        Paint()
          ..color = Colors.white.withOpacity(0.3)
          ..style = PaintingStyle.fill;

    final dotRadius = size.width * 0.01;

    // Corner dots
    canvas.drawCircle(
      Offset(size.width * 0.15, size.height * 0.25),
      dotRadius,
      dotPaint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.85, size.height * 0.25),
      dotRadius,
      dotPaint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.15, size.height * 0.75),
      dotRadius,
      dotPaint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.85, size.height * 0.75),
      dotRadius,
      dotPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
