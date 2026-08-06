import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../utils/risk.dart';

class MethaneGauge extends StatelessWidget {
  const MethaneGauge({super.key, required this.score, this.size = 200});

  final double score;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = riskColor(score);
    final theme = Theme.of(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: score.clamp(0, 1)),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) {
        return SizedBox(
          width: size,
          height: size,
          child: CustomPaint(
            painter: _GaugePainter(
              score: value,
              color: color,
              trackColor: theme.colorScheme.surfaceContainerHighest,
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    (score * 100).round().toString(),
                    style: theme.textTheme.displayMedium?.copyWith(
                      color: color,
                      fontSize: size * 0.28,
                    ),
                  ),
                  Text(
                    riskLabel(score),
                    style: theme.textTheme.titleMedium?.copyWith(color: color),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _GaugePainter extends CustomPainter {
  _GaugePainter({
    required this.score,
    required this.color,
    required this.trackColor,
  });

  final double score;
  final Color color;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 10.0;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - stroke) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = trackColor;
    canvas.drawCircle(center, radius, track);

    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas.drawArc(rect, -math.pi / 2, 2 * math.pi * score, false, arc);
  }

  @override
  bool shouldRepaint(covariant _GaugePainter oldDelegate) =>
      oldDelegate.score != score ||
      oldDelegate.color != color ||
      oldDelegate.trackColor != trackColor;
}
