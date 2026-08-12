import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/core/utils/formats.dart';
import '../../app/theme/app_colors.dart';

enum _SkyPhase { day, dusk, night }

_SkyPhase _currentSkyPhase() {
  final h = DateTime.now().hour;
  if (h >= 6 && h < 17) return _SkyPhase.day;
  if (h >= 17 && h < 20) return _SkyPhase.dusk;
  return _SkyPhase.night;
}

String _phaseLabel(_SkyPhase p) => switch (p) {
      _SkyPhase.day => '낮',
      _SkyPhase.dusk => '저녁',
      _SkyPhase.night => '밤',
    };

String weatherLabel(String weather) => switch (weather) {
      'rain' => '비',
      'cloudy' => '구름',
      _ => '맑음',
    };

IconData weatherIcon(String weather) => switch (weather) {
      'rain' => Icons.water_drop_rounded,
      'cloudy' => Icons.cloud_rounded,
      _ => Icons.wb_sunny_rounded,
    };

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
    required this.awdPhase,
  });

  final double waterLevel;
  final double predictedLevel;
  final bool gateOpen;
  final bool pumpOn;
  final String weather;
  final String stage;
  final Color riskColor;
  final String awdPhase;

  @override
  Widget build(BuildContext context) {
    final phase = _currentSkyPhase();
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
                  child: _SceneTag(
                    icon: Icons.water_drop_rounded,
                    text: '물 높이 ${formatNum(water)}cm',
                  ),
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: _SceneTag(
                    icon: weatherIcon(weather),
                    text: '${weatherLabel(weather)} · ${_phaseLabel(phase)}',
                  ),
                ),
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 10,
                  child: Center(child: _AwdChip(phase: awdPhase)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _AwdChip extends StatelessWidget {
  const _AwdChip({required this.phase});

  final String phase;

  @override
  Widget build(BuildContext context) {
    final (color, icon, text) = switch (phase) {
      'draining' => (
          AppColors.info,
          Icons.arrow_downward_rounded,
          'AWD 배수 중',
        ),
      'dry' => (
          AppColors.riskCaution,
          Icons.grass_rounded,
          'AWD 건조 중',
        ),
      'reflood' => (
          AppColors.primary,
          Icons.water_drop_rounded,
          'AWD 재관수',
        ),
      _ => (
          AppColors.secondary,
          Icons.opacity_rounded,
          'AWD 담수',
        ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color, width: 1.4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _SceneTag extends StatelessWidget {
  const _SceneTag({required this.text, this.icon});

  final String text;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: Colors.white.withValues(alpha: 0.9)),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
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
  static const double _bankL = 46;
  static const double _bankR = 50;

  double _horizonY(Size s) => s.height * 0.30;

  @override
  void paint(Canvas canvas, Size size) {
    final phase = _currentSkyPhase();
    _paintSky(canvas, size, phase);
    _paintCelestial(canvas, size, phase);
    _paintHills(canvas, size, phase);
    _paintLevees(canvas, size);
    _paintPlants(canvas, size);
    _paintWater(canvas, size);
    _paintPredicted(canvas, size);
    _paintPump(canvas, size);
    _paintGate(canvas, size);
  }

  void _paintSky(Canvas c, Size s, _SkyPhase phase) {
    final rect = Rect.fromLTRB(0, 0, s.width, _horizonY(s));
    final base = switch (phase) {
      _SkyPhase.day => const [
          Color(0xFF4A90D9),
          Color(0xFF8FCBE8),
          Color(0xFFE6F1EE),
        ],
      _SkyPhase.dusk => const [
          Color(0xFF1F2244),
          Color(0xFF9A4E8E),
          Color(0xFFF2A65A),
        ],
      _SkyPhase.night => const [
          Color(0xFF070B1E),
          Color(0xFF101B38),
          Color(0xFF1B2C4A),
        ],
    };
    final cloudFactor =
        weather == 'rain' ? 0.72 : (weather == 'cloudy' ? 0.5 : 0.0);
    const grey = Color(0xFF55606B);
    final colors = [for (final col in base) Color.lerp(col, grey, cloudFactor)!];
    c.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: colors,
        ).createShader(rect),
    );
  }

  void _paintCelestial(Canvas c, Size s, _SkyPhase phase) {
    final horizon = _horizonY(s);
    switch (phase) {
      case _SkyPhase.night:
        _paintStars(c, s);
        final moon = Offset(s.width * 0.80, s.height * 0.14);
        c.drawCircle(moon, 14, Paint()..color = const Color(0xFFEDE9D4));
        c.drawCircle(
          moon - const Offset(4.5, -3),
          12,
          Paint()..color = const Color(0xFF0B1026),
        );
        break;
      case _SkyPhase.dusk:
        final sun = Offset(s.width * 0.78, horizon - 4);
        c.drawCircle(
          sun,
          22,
          Paint()..color = const Color(0xFFFFB04D).withValues(alpha: 0.25),
        );
        c.drawCircle(sun, 12, Paint()..color = const Color(0xFFF9A03F));
        break;
      case _SkyPhase.day:
        final sun = Offset(s.width * 0.80, s.height * 0.13);
        if (weather != 'rain') {
          final alpha = weather == 'cloudy' ? 0.5 : 1.0;
          c.drawCircle(
            sun,
            26,
            Paint()..color = AppColors.riskCaution.withValues(alpha: 0.22),
          );
          c.drawCircle(
            sun,
            15,
            Paint()..color = AppColors.riskCaution.withValues(alpha: alpha),
          );
        }
        break;
    }
    if (weather == 'rain' || weather == 'cloudy') {
      _paintClouds(c, s, rain: weather == 'rain');
    }
  }

  void _paintStars(Canvas c, Size s) {
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.8);
    final rand = math.Random(7);
    for (var i = 0; i < 24; i++) {
      final x = rand.nextDouble() * s.width;
      final y = rand.nextDouble() * (_horizonY(s) * 0.7);
      c.drawCircle(Offset(x, y), 0.6 + rand.nextDouble(), paint);
    }
  }

  void _paintClouds(Canvas c, Size s, {required bool rain}) {
    final color =
        rain ? const Color(0xFF3A4A52) : const Color(0xFF8A939C).withValues(alpha: 0.85);
    final cloud = Paint()..color = color;
    final clouds = rain
        ? [(0.20, 0.13, 1.0), (0.62, 0.10, 0.8)]
        : [(0.22, 0.12, 0.9), (0.68, 0.16, 0.7)];
    for (final (fx, fy, sc) in clouds) {
      final cx = s.width * fx;
      final cy = s.height * fy;
      for (final (dx, dy, r) in [
        (0.0, 0.0, 15.0 * sc),
        (-15.0 * sc, 4.0 * sc, 11.0 * sc),
        (15.0 * sc, 4.0 * sc, 11.0 * sc),
        (0.0, 6.0 * sc, 12.0 * sc),
      ]) {
        c.drawCircle(Offset(cx + dx, cy + dy), r, cloud);
      }
    }
    if (rain) {
      final drop = Paint()
        ..color = AppColors.info.withValues(alpha: 0.75)
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round;
      final cx = s.width * 0.20;
      final cy = s.height * 0.13;
      for (var i = 0; i < 4; i++) {
        final x = cx - 24 + i * 14.0;
        c.drawLine(Offset(x, cy + 34), Offset(x + 3, cy + 42), drop);
      }
    }
  }

  void _paintHills(Canvas c, Size s, _SkyPhase phase) {
    final horizon = _horizonY(s);
    final color = switch (phase) {
      _SkyPhase.day => const Color(0xFF3F6B4F).withValues(alpha: 0.55),
      _SkyPhase.dusk => const Color(0xFF2C2A4A).withValues(alpha: 0.8),
      _SkyPhase.night => const Color(0xFF0A1420),
    };
    final hills = Path()
      ..moveTo(0, horizon)
      ..quadraticBezierTo(
          s.width * 0.22, horizon - s.height * 0.045, s.width * 0.46,
          horizon - 2)
      ..quadraticBezierTo(
          s.width * 0.70, horizon - s.height * 0.04, s.width, horizon)
      ..close();
    c.drawPath(hills, Paint()..color = color);
  }

  void _paintLevees(Canvas c, Size s) {
    final horizon = _horizonY(s);
    final bottom = s.height;
    final dirtRect = Rect.fromLTRB(0, horizon, s.width, bottom);
    final dirt = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF7A5A38), Color(0xFF4A3720)],
      ).createShader(dirtRect);
    c.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTRB(0, horizon + 6, _bankL, bottom),
        topRight: const Radius.circular(16),
        bottomRight: const Radius.circular(10),
      ),
      dirt,
    );
    c.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTRB(s.width - _bankR, horizon + 6, s.width, bottom),
        topLeft: const Radius.circular(16),
        bottomLeft: const Radius.circular(10),
      ),
      dirt,
    );
    final basinRect = Rect.fromLTRB(_bankL, horizon, s.width - _bankR, bottom);
    c.drawRect(
      basinRect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF3F5F38), Color(0xFF263A22)],
        ).createShader(basinRect),
    );
    _paintBankGrass(c, s);
  }

  void _paintBankGrass(Canvas c, Size s) {
    final horizon = _horizonY(s);
    final grass = Paint()
      ..color = const Color(0xFF6FA34F)
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    void tuft(double x, double y) {
      for (var i = -1; i <= 1; i++) {
        c.drawLine(
          Offset(x + i * 1.5, y),
          Offset(x + i * 3.0, y - 5.0 - (i.isNegative ? 2.0 : 0.0)),
          grass,
        );
      }
    }

    for (var x = 8.0; x < _bankL - 6; x += 12) {
      tuft(x, horizon + 10);
    }
    for (var x = s.width - _bankR + 8; x < s.width - 8; x += 12) {
      tuft(x, horizon + 10);
    }
  }

  (Color, Color, int, double) get _plantStyle => switch (stage) {
        '육묘' => (const Color(0xFF9CCC65), const Color(0xFF7CB342), 3, 0.12),
        '이앙' => (const Color(0xFF8BC34A), const Color(0xFF689F38), 4, 0.16),
        '담수기' => (const Color(0xFF7CB342), const Color(0xFF558B2F), 4, 0.22),
        '간단관개기' =>
          (const Color(0xFF689F38), const Color(0xFF4E7A2E), 5, 0.28),
        '중간낙수기' =>
          (const Color(0xFF6B8E23), const Color(0xFF4E7A2E), 5, 0.34),
        _ => (const Color(0xFF7CB342), const Color(0xFF558B2F), 4, 0.22),
      };

  void _paintPlants(Canvas c, Size s) {
    final (leaf, vein, blades, h) = _plantStyle;
    final rows = [
      (baseY: s.height - 10, scale: 1.0, gap: 42.0),
      (baseY: s.height - 40, scale: 0.74, gap: 38.0),
      (baseY: s.height - 66, scale: 0.52, gap: 34.0),
    ];
    for (final r in rows) {
      var x = _bankL + 18.0;
      final end = s.width - _bankR - 10;
      var i = 0;
      while (x < end) {
        _drawPlant(
          c,
          Offset(x, r.baseY),
          h * s.height * r.scale,
          leaf,
          vein,
          blades,
        );
        x += r.gap * (0.9 + 0.2 * ((i % 3) / 3));
        i++;
      }
    }
  }

  void _drawPlant(
    Canvas c,
    Offset base,
    double h,
    Color leaf,
    Color vein,
    int blades,
  ) {
    final stem = Paint()..color = vein..strokeWidth = 1.4;
    for (var i = -1; i <= 1; i++) {
      c.drawLine(
        Offset(base.dx + i * 2.0, base.dy),
        Offset(base.dx + i * 2.5, base.dy - h * 0.5),
        stem,
      );
    }
    for (var i = 0; i < blades; i++) {
      final t = blades == 1 ? 0.5 : i / (blades - 1);
      _drawLeaf(c, base, h, -0.8 + t * 1.6, leaf, vein);
    }
  }

  void _drawLeaf(
      Canvas c, Offset base, double h, double angle, Color leaf, Color vein) {
    final sin = math.sin(angle);
    final tip = Offset(
        base.dx + sin * h * 0.9, base.dy - h * (0.95 - 0.3 * sin.abs()));
    final ctrl = Offset(base.dx + sin * h * 0.30, base.dy - h * 0.80);
    final back = Offset(base.dx + sin * h * 0.34 + 2.6, base.dy - h * 0.85);
    final path = Path()
      ..moveTo(base.dx, base.dy)
      ..quadraticBezierTo(ctrl.dx, ctrl.dy, tip.dx, tip.dy)
      ..quadraticBezierTo(back.dx, back.dy, base.dx + 2.0, base.dy)
      ..close();
    c.drawPath(path, Paint()..color = leaf);
    c.drawLine(
      Offset(base.dx, base.dy),
      Offset(tip.dx, tip.dy - 1),
      Paint()..color = vein..strokeWidth = 1,
    );
  }

  void _paintWater(Canvas c, Size s) {
    final maxH = s.height - _horizonY(s);
    final topY = s.height - (waterLevel / _maxLevel) * maxH;

    if (waterLevel < 0.5) {
      _paintDrySoil(c, s);
      return;
    }

    final rect = Rect.fromLTRB(_bankL, topY, s.width - _bankR, s.height);
    c.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFFBFE7F2).withValues(alpha: 0.55),
            Color.lerp(AppColors.secondary, riskColor, 0.18)!
                .withValues(alpha: 0.48),
            AppColors.secondary.withValues(alpha: 0.34),
          ],
        ).createShader(rect),
    );
    final surf = Paint()
      ..color = Colors.white.withValues(alpha: 0.6)
      ..strokeWidth = 2;
    c.drawLine(Offset(_bankL, topY), Offset(s.width - _bankR, topY), surf);

    final ripple = Paint()
      ..color = Colors.white.withValues(alpha: 0.16)
      ..strokeWidth = 1.5;
    for (var i = 0; i < 3; i++) {
      final y = topY + 18 + i * 20;
      if (y >= s.height - 6) continue;
      c.drawLine(
        Offset(_bankL + 14 + i * 18, y),
        Offset(_bankL + 74 + i * 18, y),
        ripple,
      );
    }

    final tick = Paint()
      ..color = Colors.white.withValues(alpha: 0.35)
      ..strokeWidth = 1.2;
    for (var v = 1; v <= 9; v += 2) {
      final y = s.height - (v / _maxLevel) * maxH;
      if (y < topY - 6) continue;
      c.drawLine(Offset(_bankL + 2, y), Offset(_bankL + 9, y), tick);
    }
  }

  void _paintDrySoil(Canvas c, Size s) {
    final horizon = _horizonY(s);
    final basinRect = Rect.fromLTRB(_bankL, horizon, s.width - _bankR, s.height);
    c.drawRect(
      basinRect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF3F5F38), Color(0xFF2C3A26)],
        ).createShader(basinRect),
    );
    final crack = Paint()
      ..color = const Color(0xFF4A3720).withValues(alpha: 0.75)
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round;
    var x = _bankL + 16.0;
    while (x < s.width - _bankR - 10) {
      final top = horizon + 14 + (x * 31 % 16);
      c.drawLine(Offset(x, top), Offset(x + 9, top + 18), crack);
      c.drawLine(Offset(x + 9, top + 18), Offset(x + 15, top + 12), crack);
      c.drawLine(Offset(x + 9, top + 18), Offset(x + 5, top + 26), crack);
      x += 28;
    }
    final mud = Paint()
      ..color = const Color(0xFF2E4A2A).withValues(alpha: 0.85);
    c.drawRect(
      Rect.fromLTRB(_bankL, s.height - 10, s.width - _bankR, s.height),
      mud,
    );
  }

  void _paintPredicted(Canvas c, Size s) {
    final maxH = s.height - _horizonY(s);
    final y = s.height - (predictedLevel / _maxLevel) * maxH;
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.85)
      ..strokeWidth = 2;
    _dashedLine(c, Offset(_bankL, y), Offset(s.width - _bankR - 12, y), paint);
    _label(
      c,
      '예상 수위 ${formatNum(predictedLevel)}cm',
      Offset(s.width - _bankR - 40, y - 12),
    );
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

  void _paintPump(Canvas c, Size s) {
    final x = 30.0;
    final y = s.height - 16;
    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(x - 18, y - 8, x + 18, y + 6),
        const Radius.circular(6),
      ),
      Paint()..color = const Color(0xFF3D3D43),
    );
    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(x - 9, y - 26, x + 9, y - 8),
        const Radius.circular(5),
      ),
      Paint()..color = pumpOn ? AppColors.primary : const Color(0xFF5A5A62),
    );
    final pipe = Paint()
      ..color = pumpOn
          ? AppColors.primary.withValues(alpha: 0.8)
          : const Color(0xFF5A5A62).withValues(alpha: 0.8);
    c.drawRect(Rect.fromLTRB(x + 8, y - 22, x + 66, y - 15), pipe);
    if (pumpOn) {
      final jet = Paint()
        ..color = AppColors.info.withValues(alpha: 0.85)
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round;
      _dashedLine(c, Offset(x + 64, y - 18), Offset(s.width * 0.62, y - 26), jet);
    }
    _label(c, '펌프', Offset(x, y - 38));
  }

  void _paintGate(Canvas c, Size s) {
    final horizon = _horizonY(s);
    final fx = s.width - _bankR + 4;
    final top = horizon + 10;
    final bottom = s.height - 12;
    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(fx, top, fx + 42, bottom),
        const Radius.circular(6),
      ),
      Paint()..color = const Color(0xFF6E6E76),
    );
    c.drawRect(
      Rect.fromLTRB(fx + 4, top, fx + 38, bottom),
      Paint()..color = const Color(0xFF33333A),
    );
    final doorH = (bottom - top) * 0.42;
    final doorY = gateOpen ? top + 2 : bottom - doorH - 2;
    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(fx + 5, doorY, fx + 37, doorY + doorH),
        const Radius.circular(4),
      ),
      Paint()..color = gateOpen ? AppColors.riskSafe : AppColors.textDisabled,
    );
    _label(c, '수문', Offset(fx + 21, top - 12));
  }

  void _label(Canvas c, String text, Offset center) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final rect = Rect.fromCenter(
      center: center,
      width: tp.width + 14,
      height: tp.height + 7,
    );
    c.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(6)),
      Paint()..color = Colors.black.withValues(alpha: 0.5),
    );
    tp.paint(c, Offset(rect.left + 7, rect.top + 3.5));
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