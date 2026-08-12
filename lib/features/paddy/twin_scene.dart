import 'package:flutter/material.dart';

import '../../app/core/utils/formats.dart';
import '../../app/theme/app_colors.dart';

class TwinScene extends StatelessWidget {
  const TwinScene({
    super.key,
    required this.waterLevel,
    required this.predictedLevel,
    required this.gateOpen,
    required this.pumpOn,
    required this.weather,
    required this.stage,
    required this.riskColor,
  });

  final double waterLevel;
  final double predictedLevel;
  final bool gateOpen;
  final bool pumpOn;
  final String weather;
  final String stage;
  final Color riskColor;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: waterLevel),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      builder: (context, water, _) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: AppColors.surfaceAlt,
          ),
          clipBehavior: Clip.antiAlias,
          child: CustomPaint(
            painter: _TwinPainter(
              waterLevel: water,
              predictedLevel: predictedLevel,
              riskColor: riskColor,
              gateOpen: gateOpen,
              pumpOn: pumpOn,
              weather: weather,
              stage: stage,
            ),
            child: Stack(
              children: [
                Positioned(
                  top: 12,
                  left: 12,
                  child: _SceneTag(text: '물 높이 ${formatNum(water)}cm'),
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: _SceneTag(
                    text: '예상 3h: ${formatNum(predictedLevel)}cm',
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SceneTag extends StatelessWidget {
  const _SceneTag({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _TwinPainter extends CustomPainter {
  _TwinPainter({
    required this.waterLevel,
    required this.predictedLevel,
    required this.riskColor,
    required this.gateOpen,
    required this.pumpOn,
    required this.weather,
    required this.stage,
  });

  final double waterLevel;
  final double predictedLevel;
  final Color riskColor;
  final bool gateOpen;
  final bool pumpOn;
  final String weather;
  final String stage;

  static const double _maxLevel = 10.0;

  double _horizonY(Size s) => s.height * 0.30;

  bool get _isRain => weather == 'rain';

  @override
  void paint(Canvas canvas, Size size) {
    _paintSky(canvas, size);
    _paintWeather(canvas, size);
    _paintField(canvas, size);
    _paintSoil(canvas, size);
    _paintPlants(canvas, size);
    _paintWater(canvas, size);
    _paintRipples(canvas, size);
    _paintPredictedLine(canvas, size);
    _paintGate(canvas, size);
    _paintPump(canvas, size);
  }

  void _paintSky(Canvas canvas, Size size) {
    final skyRect = Rect.fromLTRB(0, 0, size.width, _horizonY(size));
    final sky = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF0B1E33), Color(0xFF17413A)],
      ).createShader(skyRect);
    canvas.drawRect(skyRect, sky);
  }

  void _paintWeather(Canvas canvas, Size size) {
    if (_isRain) {
      final cx = size.width * 0.20;
      final cy = size.height * 0.14;
      final cloud = Paint()..color = const Color(0xFF3A4A52);
      const puffs = [(0.0, 0.0, 16.0), (-16.0, 4.0, 12.0), (16.0, 4.0, 12.0)];
      for (final (dx, dy, r) in puffs) {
        canvas.drawCircle(Offset(cx + dx, cy + dy), r, cloud);
      }
      final drop = Paint()
        ..color = AppColors.info.withValues(alpha: 0.8)
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round;
      for (var i = 0; i < 4; i++) {
        final x = cx - 22 + i * 14.0;
        canvas.drawLine(
          Offset(x, cy + 34),
          Offset(x + 3, cy + 42),
          drop,
        );
      }
    } else {
      final center = Offset(size.width * 0.80, size.height * 0.14);
      canvas.drawCircle(
        center,
        24,
        Paint()..color = AppColors.riskCaution.withValues(alpha: 0.16),
      );
      canvas.drawCircle(
        center,
        15,
        Paint()..color = AppColors.riskCaution.withValues(alpha: 0.65),
      );
    }
  }

  void _paintField(Canvas canvas, Size size) {
    final rect = Rect.fromLTRB(0, _horizonY(size), size.width, size.height);
    final field = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF24422F), Color(0xFF16271E)],
      ).createShader(rect);
    canvas.drawRect(rect, field);

    final ridge = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..strokeWidth = 1;
    for (var i = 1; i <= 3; i++) {
      final y = _horizonY(size) + (size.height - _horizonY(size)) * (i / 4);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), ridge);
    }
  }

  void _paintSoil(Canvas canvas, Size size) {
    final soilRect = Rect.fromLTRB(0, size.height - 16, size.width, size.height);
    canvas.drawRect(soilRect, Paint()..color = const Color(0xFF22190F));
    final speck = Paint()..color = const Color(0xFF3A2B1B);
    for (var i = 0; i < 6; i++) {
      canvas.drawCircle(
        Offset(24 + i * (size.width - 48) / 5,
            size.height - 8 + (i.isEven ? -3.0 : 3.0)),
        2,
        speck,
      );
    }
  }

  double get _plantHeight => switch (stage) {
        '육묘' => 0.12,
        '이앙' => 0.16,
        '담수기' => 0.22,
        '간단관개기' => 0.28,
        '중간낙수기' => 0.34,
        _ => 0.22,
      };

  void _paintPlants(Canvas canvas, Size size) {
    final tall = _plantHeight * size.height;
    final young = stage == '육묘' || stage == '이앙';
    final stem = Paint()
      ..color = young ? const Color(0xFF7CC45C) : const Color(0xFF4C8A3A)
      ..strokeWidth = 2;
    final leaf = Paint()
      ..color = young ? const Color(0xFF9ADB62) : const Color(0xFF5DA043)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final rows = [
      (y: size.height - 8, s: 1.0, gap: 46.0),
      (y: size.height - 48, s: 0.75, gap: 42.0),
      (y: size.height - 84, s: 0.5, gap: 38.0),
    ];
    for (final r in rows) {
      var x = 30.0;
      final span = size.width - 76;
      while (x < span) {
        _drawPlant(canvas, Offset(x, r.y), tall * r.s, stem, leaf);
        x += r.gap;
      }
    }
  }

  void _drawPlant(
    Canvas canvas,
    Offset base,
    double h,
    Paint stem,
    Paint leaf,
  ) {
    final top = Offset(base.dx, base.dy - h);
    canvas.drawLine(base, top, stem);
    const blades = [(-0.55, -0.82), (-0.2, -1.0), (0.25, -1.02), (0.55, -0.78)];
    for (final (dx, dy) in blades) {
      final ctrl = Offset(base.dx + dx * h * 0.30, base.dy - h * 0.84);
      final end = Offset(base.dx + dx * h * 0.62, base.dy + dy * h);
      final path = Path()
        ..moveTo(top.dx, top.dy)
        ..quadraticBezierTo(ctrl.dx, ctrl.dy, end.dx, end.dy);
      canvas.drawPath(path, leaf);
    }
  }

  void _paintWater(Canvas canvas, Size size) {
    final maxH = size.height - _horizonY(size);
    final topY = size.height - (waterLevel / _maxLevel) * maxH;
    final rect = Rect.fromLTRB(20, topY, size.width - 20, size.height);
    final water = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color.lerp(AppColors.secondary, riskColor, 0.20)!
              .withValues(alpha: 0.62),
          AppColors.secondary.withValues(alpha: 0.30),
        ],
      ).createShader(rect);
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        rect,
        topLeft: const Radius.circular(14),
        topRight: const Radius.circular(14),
      ),
      water,
    );
    final surface = Paint()
      ..color = Colors.white.withValues(alpha: 0.55)
      ..strokeWidth = 2;
    canvas.drawLine(Offset(20, topY), Offset(size.width - 20, topY), surface);
  }

  void _paintRipples(Canvas canvas, Size size) {
    final maxH = size.height - _horizonY(size);
    final topY = size.height - (waterLevel / _maxLevel) * maxH;
    final ripple = Paint()
      ..color = Colors.white.withValues(alpha: 0.18)
      ..strokeWidth = 1.5;
    for (var i = 0; i < 3; i++) {
      final y = topY + 16 + i * 18;
      if (y >= size.height - 4) continue;
      final inset = i * 16.0 + 12;
      canvas.drawLine(
        Offset(20 + inset, y),
        Offset(20 + inset + 60, y),
        ripple,
      );
    }
  }

  void _paintPredictedLine(Canvas canvas, Size size) {
    final maxH = size.height - _horizonY(size);
    final y = size.height - (predictedLevel / _maxLevel) * maxH;
    final dash = Paint()
      ..color = Colors.white.withValues(alpha: 0.8)
      ..strokeWidth = 2;
    _dashedLine(canvas, Offset(20, y), Offset(size.width - 20, y), dash);
  }

  void _dashedLine(Canvas canvas, Offset a, Offset b, Paint paint) {
    const dash = 8.0;
    const gap = 6.0;
    final total = (b - a).distance;
    var t = 0.0;
    while (t < total) {
      final p1 = Offset.lerp(a, b, t / total)!;
      final p2 = Offset.lerp(a, b, (t + dash) / total)!;
      canvas.drawLine(p1, p2, paint);
      t += dash + gap;
    }
  }

  void _paintGate(Canvas canvas, Size size) {
    final wall = size.width - 36;
    final wallTop = _horizonY(size) + 8;
    final wallRect = Rect.fromLTRB(wall, wallTop, wall + 28, size.height - 10);
    canvas.drawRRect(
      RRect.fromRectAndRadius(wallRect, const Radius.circular(6)),
      Paint()..color = const Color(0xFF2C3D33),
    );

    final doorTop = gateOpen ? wallTop + 6 : size.height * 0.40;
    final doorRect = Rect.fromLTRB(wall + 4, doorTop, wall + 24, size.height - 12);
    canvas.drawRRect(
      RRect.fromRectAndRadius(doorRect, const Radius.circular(4)),
      Paint()..color = gateOpen ? AppColors.riskSafe : AppColors.textDisabled,
    );

    final slot = Paint()
      ..color = Colors.white.withValues(alpha: 0.25)
      ..strokeWidth = 3;
    canvas.drawLine(
      Offset(wall + 14, wallTop + 6),
      Offset(wall + 14, size.height - 14),
      slot,
    );
  }

  void _paintPump(Canvas canvas, Size size) {
    final px = 48.0;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(px - 22, size.height - 12, px + 22, size.height - 2),
        const Radius.circular(5),
      ),
      Paint()..color = const Color(0xFF37382E),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(px, size.height - 30),
          width: 28,
          height: 22,
        ),
        const Radius.circular(7),
      ),
      Paint()..color = pumpOn ? AppColors.primary : AppColors.textDisabled,
    );
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(px + 34, size.height - 32),
        width: 40,
        height: 8,
      ),
      Paint()
        ..color = pumpOn
            ? AppColors.primary.withValues(alpha: 0.7)
            : AppColors.textDisabled.withValues(alpha: 0.5),
    );
    if (pumpOn) {
      final jet = Paint()
        ..color = AppColors.info.withValues(alpha: 0.85)
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round;
      final start = Offset(px + 52, size.height - 32);
      final end = Offset(size.width * 0.60, size.height - 38);
      _dashedLine(canvas, start, end, jet);
    }
  }

  @override
  bool shouldRepaint(covariant _TwinPainter old) =>
      old.waterLevel != waterLevel ||
      old.predictedLevel != predictedLevel ||
      old.gateOpen != gateOpen ||
      old.pumpOn != pumpOn ||
      old.weather != weather ||
      old.stage != stage ||
      old.riskColor != riskColor;
}