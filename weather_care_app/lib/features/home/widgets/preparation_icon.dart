import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../models/recommendation.dart';

/// 앱과 홈 위젯이 공유하는 준비물 아이콘의 Flutter 구현입니다.
class PreparationIcon extends StatelessWidget {
  final RecommendationType type;
  final double size;
  final Color color;
  final bool circularBackground;
  final Color backgroundColor;

  const PreparationIcon({
    super.key,
    required this.type,
    this.size = 24,
    this.color = const Color(0xFF3E5F7C),
    this.circularBackground = false,
    this.backgroundColor = const Color(0xFFE2EFF8),
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: type.label,
      child: CustomPaint(
        size: Size.square(size),
        painter: _PreparationIconPainter(
          type: type,
          color: color,
          circularBackground: circularBackground,
          backgroundColor: backgroundColor,
        ),
      ),
    );
  }
}

class _PreparationIconPainter extends CustomPainter {
  final RecommendationType type;
  final Color color;
  final bool circularBackground;
  final Color backgroundColor;

  const _PreparationIconPainter({
    required this.type,
    required this.color,
    required this.circularBackground,
    required this.backgroundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final scale = math.min(size.width, size.height) / 100;
    canvas.save();
    canvas.translate(
      (size.width - 100 * scale) / 2,
      (size.height - 100 * scale) / 2,
    );
    canvas.scale(scale);

    if (circularBackground) {
      canvas.drawCircle(
        const Offset(50, 50),
        48,
        Paint()..color = backgroundColor,
      );
      canvas.translate(17, 17);
      canvas.scale(0.66);
    }

    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = 7.5;

    switch (type) {
      case RecommendationType.umbrella:
        _drawUmbrella(canvas, stroke, parasol: false);
      case RecommendationType.parasol:
        _drawUmbrella(canvas, stroke, parasol: true);
      case RecommendationType.heavySnowCaution:
        _drawSnowflake(canvas, const Offset(50, 50), 34, stroke);
      case RecommendationType.outerwear:
        _drawOuterwear(canvas, stroke);
      case RecommendationType.mask:
        _drawMask(canvas, stroke);
      case RecommendationType.water:
        _drawBottle(canvas, stroke, sunscreen: false);
      case RecommendationType.sunscreen:
        _drawBottle(canvas, stroke, sunscreen: true);
    }
    canvas.restore();
  }

  void _drawUmbrella(Canvas canvas, Paint paint, {required bool parasol}) {
    canvas.drawArc(
      const Rect.fromLTWH(13, 20, 74, 54),
      190 * math.pi / 180,
      160 * math.pi / 180,
      false,
      paint,
    );
    canvas.drawLine(const Offset(50, 47), const Offset(50, 82), paint);
    canvas.drawArc(
      const Rect.fromLTWH(50, 70, 23, 22),
      math.pi / 2,
      math.pi,
      false,
      paint,
    );
    if (parasol) {
      canvas.drawCircle(const Offset(77, 19), 7, paint);
      for (var index = 0; index < 4; index++) {
        final angle = math.pi * index / 2;
        final direction = Offset(math.cos(angle), math.sin(angle));
        canvas.drawLine(
          const Offset(77, 19) + direction * 10,
          const Offset(77, 19) + direction * 14,
          paint,
        );
      }
    }
  }

  void _drawSnowflake(
    Canvas canvas,
    Offset center,
    double radius,
    Paint paint,
  ) {
    for (var index = 0; index < 3; index++) {
      final angle = math.pi * index / 3;
      final direction = Offset(math.cos(angle), math.sin(angle)) * radius;
      canvas.drawLine(center - direction, center + direction, paint);
    }
  }

  void _drawOuterwear(Canvas canvas, Paint paint) {
    final path = Path()
      ..moveTo(38, 20)
      ..lineTo(20, 36)
      ..lineTo(27, 55)
      ..lineTo(36, 50)
      ..lineTo(33, 86)
      ..lineTo(67, 86)
      ..lineTo(64, 50)
      ..lineTo(73, 55)
      ..lineTo(80, 36)
      ..lineTo(62, 20)
      ..lineTo(50, 34)
      ..close();
    canvas.drawPath(path, paint);
    canvas.drawLine(const Offset(50, 34), const Offset(50, 85), paint);
  }

  void _drawMask(Canvas canvas, Paint paint) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(20, 30, 60, 42),
        const Radius.circular(11),
      ),
      paint,
    );
    canvas.drawArc(
      const Rect.fromLTWH(5, 32, 24, 41),
      math.pi / 2,
      math.pi,
      false,
      paint,
    );
    canvas.drawArc(
      const Rect.fromLTWH(71, 32, 24, 41),
      -math.pi / 2,
      math.pi,
      false,
      paint,
    );
    canvas.drawLine(const Offset(30, 46), const Offset(70, 46), paint);
    canvas.drawLine(const Offset(30, 58), const Offset(70, 58), paint);
  }

  void _drawBottle(Canvas canvas, Paint paint, {required bool sunscreen}) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(31, 31, 38, 57),
        const Radius.circular(8),
      ),
      paint,
    );
    canvas.drawRect(const Rect.fromLTWH(40, 17, 20, 14), paint);
    canvas.drawLine(const Offset(40, 17), const Offset(60, 17), paint);
    if (sunscreen) {
      canvas.drawCircle(const Offset(50, 58), 9, paint);
      for (var index = 0; index < 4; index++) {
        final angle = math.pi * index / 2;
        final direction = Offset(math.cos(angle), math.sin(angle));
        canvas.drawLine(
          const Offset(50, 58) + direction * 11.5,
          const Offset(50, 58) + direction * 14,
          paint,
        );
      }
    } else {
      final drop = Path()
        ..moveTo(50, 46)
        ..quadraticBezierTo(38, 63, 50, 70)
        ..quadraticBezierTo(62, 63, 50, 46);
      canvas.drawPath(drop, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _PreparationIconPainter oldDelegate) {
    return type != oldDelegate.type ||
        color != oldDelegate.color ||
        circularBackground != oldDelegate.circularBackground ||
        backgroundColor != oldDelegate.backgroundColor;
  }
}
