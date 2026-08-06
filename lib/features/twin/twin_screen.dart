import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/core/utils/formats.dart';
import '../../app/core/utils/risk.dart';
import '../../app/core/widgets/app_card.dart';
import '../../app/store/providers.dart';
import '../../app/theme/app_colors.dart';
import '../../shared/models/twin_state.dart';

class TwinScreen extends ConsumerWidget {
  const TwinScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final twin = ref.watch(twinProvider).value;
    return Scaffold(
      appBar: AppBar(title: const Text('Digital Twin')),
      body: SafeArea(
        child: twin == null
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _WeatherBanner(state: twin),
                  const SizedBox(height: 12),
                  AspectRatio(
                    aspectRatio: 4 / 3,
                    child: TwinScene(state: twin),
                  ),
                  const SizedBox(height: 12),
                  _RiskBar(score: twin.methaneScore),
                  const SizedBox(height: 12),
                  _AiPredictionPanel(state: twin),
                  const SizedBox(height: 12),
                  _EquipmentRow(state: twin),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => context.go('/control'),
                      icon: const Icon(Icons.tune_rounded, size: 18),
                      label: const Text('원격 제어로 이동'),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _WeatherBanner extends StatelessWidget {
  const _WeatherBanner({required this.state});

  final TwinState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isRain = state.weather == 'rain';
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(
            isRain ? Icons.water_drop_rounded : Icons.wb_sunny_rounded,
            color: isRain ? AppColors.info : AppColors.riskCaution,
          ),
          const SizedBox(width: 8),
          Text(
            '${state.tempC.round()}°C ${isRain ? '비' : '맑음'}',
            style: theme.textTheme.titleMedium,
          ),
          const Spacer(),
          if (state.rain3h)
            Text(
              '3h 내 강우 80%',
              style: theme.textTheme.labelMedium?.copyWith(color: AppColors.info),
            ),
        ],
      ),
    );
  }
}

class _RiskBar extends StatelessWidget {
  const _RiskBar({required this.score});

  final double score;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = riskColor(score);
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Text('메탄 위험', style: theme.textTheme.labelLarge),
          const SizedBox(width: 12),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: score,
                minHeight: 8,
                color: color,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '${(score * 100).round()}',
            style: theme.textTheme.titleMedium?.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

class _AiPredictionPanel extends StatelessWidget {
  const _AiPredictionPanel({required this.state});

  final TwinState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final predictedRisk = (state.methaneScore +
            (state.predictedOrp3h - state.orp) / 200)
        .clamp(0.0, 1.0);
    final predColor = riskColor(predictedRisk);
    final trend = state.predictedOrp3h > state.orp ? '개선' : '악화';

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome_rounded,
                  size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text('AI 예측 · 3시간 후', style: theme.textTheme.labelLarge),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _PredictStat(
                  label: '수위',
                  now: formatNum(state.waterLevel),
                  predicted: formatNum(state.predictedLevel3h),
                  unit: 'cm',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _PredictStat(
                  label: 'ORP',
                  now: formatNum(state.orp),
                  predicted: formatNum(state.predictedOrp3h),
                  unit: 'mV',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: predColor.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.insights_rounded, size: 20, color: predColor),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '메탄 위험도 ${riskLabel(predictedRisk)}로 $trend 전망입니다. ${state.rain3h ? '비가 오면 수위가 오를 수 있어 수문을 점검하세요.' : '현재 제어를 유지하면 회복될 가능성이 높아요.'}',
                    style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PredictStat extends StatelessWidget {
  const _PredictStat({
    required this.label,
    required this.now,
    required this.predicted,
    required this.unit,
  });

  final String label;
  final String now;
  final String predicted;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.labelSmall),
          const SizedBox(height: 4),
          Text(
            '지금 $now$unit',
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          Text(
            '예상 $predicted$unit',
            style: theme.textTheme.labelMedium
                ?.copyWith(color: theme.colorScheme.primary),
          ),
        ],
      ),
    );
  }
}

class _EquipmentRow extends StatelessWidget {
  const _EquipmentRow({required this.state});

  final TwinState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: AppCard(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(
                  Icons.door_front_door_rounded,
                  size: 20,
                  color: state.gateOpen
                      ? AppColors.secondary
                      : theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Text(
                  state.gateOpen ? '수문 열림' : '수문 닫힘',
                  style: theme.textTheme.labelLarge,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: AppCard(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(
                  Icons.bolt_rounded,
                  size: 20,
                  color: state.pumpOn
                      ? AppColors.primary
                      : theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Text(
                  state.pumpOn ? '펌프 가동' : '펌프 정지',
                  style: theme.textTheme.labelLarge,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class TwinScene extends StatelessWidget {
  const TwinScene({super.key, required this.state});

  final TwinState state;

  @override
  Widget build(BuildContext context) {
    final color = riskColor(state.methaneScore);
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: state.waterLevel),
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
              predictedLevel: state.predictedLevel3h,
              riskColor: color,
              gateOpen: state.gateOpen,
              pumpOn: state.pumpOn,
            ),
            child: Stack(
              children: [
                Positioned(
                  top: 12,
                  left: 12,
                  child: _SceneTag(
                    text: '물 높이 ${formatNum(water)}cm',
                  ),
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: _SceneTag(
                    text: '예상 3h: ${formatNum(state.predictedLevel3h)}cm',
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
        color: Colors.black.withValues(alpha: 0.4),
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
  });

  final double waterLevel;
  final double predictedLevel;
  final Color riskColor;
  final bool gateOpen;
  final bool pumpOn;

  static const double _maxLevel = 10.0;
  static const double _bottomInset = 16.0;

  @override
  void paint(Canvas canvas, Size size) {
    final field = Paint()
      ..color = Color.lerp(const Color(0xFF0B1412), riskColor, 0.08)!;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(20)),
      field,
    );

    const margin = 28.0;
    final waterHeight =
        (waterLevel / _maxLevel) * (size.height - 40 - _bottomInset);
    final topY = size.height - _bottomInset - waterHeight;
    final water = Paint()
      ..color = AppColors.secondary.withValues(alpha: 0.55);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(
          margin,
          topY,
          size.width - margin,
          size.height - _bottomInset,
        ),
        const Radius.circular(8),
      ),
      water,
    );

    final predictedY = size.height -
        _bottomInset -
        (predictedLevel / _maxLevel) * (size.height - 40 - _bottomInset);
    final dash = Paint()
      ..color = Colors.white.withValues(alpha: 0.75)
      ..strokeWidth = 2;
    _dashedLine(
      canvas,
      Offset(margin, predictedY),
      Offset(size.width - margin, predictedY),
      dash,
    );

    _drawGate(canvas, size);
    _drawPump(canvas, size);
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

  void _drawGate(Canvas canvas, Size size) {
    const w = 22.0;
    final x = size.width - 46;
    final bottom = size.height - _bottomInset;
    final top = gateOpen ? size.height * 0.18 : 30.0;
    final rect = Rect.fromLTRB(x, top, x + w, bottom);
    final gate = Paint()
      ..color = gateOpen ? AppColors.riskSafe : AppColors.textDisabled;
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(4)), gate);
    final slot = Paint()
      ..color = Colors.white.withValues(alpha: 0.2)
      ..strokeWidth = 3;
    canvas.drawLine(
      Offset(x + w / 2, 24),
      Offset(x + w / 2, bottom),
      slot,
    );
  }

  void _drawPump(Canvas canvas, Size size) {
    final center = Offset(52, size.height - 30);
    final body = Paint()
      ..color = pumpOn ? AppColors.primary : AppColors.textDisabled;
    canvas.drawCircle(center, 14, body);
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(center.dx, size.height - 46),
        width: 18,
        height: 20,
      ),
      Paint()
        ..color = pumpOn
            ? AppColors.primary.withValues(alpha: 0.7)
            : AppColors.textDisabled.withValues(alpha: 0.5),
    );
  }

  @override
  bool shouldRepaint(covariant _TwinPainter old) =>
      old.waterLevel != waterLevel ||
      old.predictedLevel != predictedLevel ||
      old.gateOpen != gateOpen ||
      old.pumpOn != pumpOn ||
      old.riskColor != riskColor;
}
