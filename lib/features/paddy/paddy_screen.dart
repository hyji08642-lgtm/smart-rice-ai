import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/core/utils/formats.dart';
import '../../app/core/utils/risk.dart';
import '../../app/core/widgets/app_card.dart';
import '../../app/core/widgets/metric_tile.dart';
import '../../app/store/providers.dart';
import '../../app/theme/app_colors.dart';
import '../../shared/models/device.dart';
import '../../shared/models/paddy.dart';
import '../../shared/models/telemetry.dart';
import '../../shared/models/twin_state.dart';
import 'twin_scene.dart';

class PaddyScreen extends ConsumerWidget {
  const PaddyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final twin = ref.watch(twinProvider).value;
    final telemetry = ref.watch(telemetryProvider).value;
    final paddyId = ref.watch(selectedPaddyProvider);
    final paddies = ref.watch(paddiesProvider);
    final devices = ref.watch(devicesProvider);
    final paddy = paddies
        .cast<Paddy?>()
        .firstWhere((p) => p?.id == paddyId, orElse: () => null);
    final paddyDevices = [
      for (final d in devices)
        if (paddy?.deviceIds.contains(d.deviceId) ?? false) d,
    ];

    return Scaffold(
      appBar: AppBar(title: Text(paddy?.name ?? '논 보기')),
      body: SafeArea(
        child: (twin == null || telemetry == null)
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _PaddyHeader(paddy: paddy, state: twin),
                  const SizedBox(height: 16),
                  Text('Digital Twin · 실시간',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  AspectRatio(
                    aspectRatio: 4 / 3,
                    child: TwinScene(
                      waterLevel: twin.waterLevel,
                      predictedLevel: twin.predictedLevel3h,
                      gateOpen: twin.gateOpen,
                      pumpOn: twin.pumpOn,
                      weather: twin.weather,
                      stage: paddy?.stage ?? '담수기',
                      riskColor: riskColor(twin.methaneScore),
                      awdPhase: twin.awdPhase,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _SceneLegend(),
                  const SizedBox(height: 16),
                  Text('센서 상태',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  _SensorGrid(telemetry: telemetry),
                  if (paddyDevices.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text('연결된 기기 (${paddyDevices.length})',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(
                      '이 논에 등록된 제품 각각의 센서 상태예요.',
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                    const SizedBox(height: 12),
                    for (final d in paddyDevices) ...[
                      _DeviceStateCard(device: d, telemetry: telemetry),
                      const SizedBox(height: 8),
                    ],
                  ],
                  const SizedBox(height: 16),
                  _AiPredictionPanel(state: twin),
                  const SizedBox(height: 16),
                  _EquipmentRow(state: twin),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => context.push('/control'),
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

class _PaddyHeader extends StatelessWidget {
  const _PaddyHeader({required this.paddy, required this.state});

  final Paddy? paddy;
  final TwinState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final paddy = this.paddy;
    final score = paddy?.riskScore ?? state.methaneScore;
    final color = riskColor(score);
    final wLabel = switch (state.weather) {
      'rain' => '비',
      'cloudy' => '구름',
      _ => '맑음',
    };
    final wIcon = switch (state.weather) {
      'rain' => Icons.water_drop_rounded,
      'cloudy' => Icons.cloud_rounded,
      _ => Icons.wb_sunny_rounded,
    };
    final wColor = state.weather == 'rain'
        ? AppColors.info
        : (state.weather == 'cloudy'
            ? theme.colorScheme.onSurfaceVariant
            : AppColors.riskCaution);
    return AppCard(
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.grain_rounded, color: color, size: 28),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  paddy?.name ?? '내 논',
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  '${paddy?.stage ?? '담수기'} · ${paddy?.area ?? '1,000㎡'}',
                  style: theme.textTheme.labelMedium,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _InfoChip(
                      icon: wIcon,
                      label: '${state.tempC.round()}°C $wLabel',
                      color: wColor,
                    ),
                    _InfoChip(
                      icon: switch (state.awdPhase) {
                        'draining' => Icons.arrow_downward_rounded,
                        'dry' => Icons.grass_rounded,
                        'reflood' => Icons.water_drop_rounded,
                        _ => Icons.opacity_rounded,
                      },
                      label: awdPhaseLabel(state.awdPhase),
                      color: switch (state.awdPhase) {
                        'draining' => AppColors.info,
                        'dry' => AppColors.riskCaution,
                        'reflood' => AppColors.primary,
                        _ => AppColors.secondary,
                      },
                    ),
                    _RiskPill(score: score),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: color, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _RiskPill extends StatelessWidget {
  const _RiskPill({required this.score});

  final double score;

  @override
  Widget build(BuildContext context) {
    final color = riskColor(score);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            '메탄 ${riskLabel(score)}',
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: color, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

Color _orpColor(double v) {
  if (v < 300) return AppColors.riskSevere;
  if (v < 340) return AppColors.riskHigh;
  if (v < 360) return AppColors.riskCaution;
  return AppColors.riskSafe;
}

Color _rssiColor(double v) {
  if (v >= -60) return AppColors.riskSafe;
  if (v >= -70) return AppColors.riskCaution;
  return AppColors.riskHigh;
}

/// 논에 연결된 개별 제품(ESP32)의 역할별 센서 상태.
class _DeviceStateCard extends StatelessWidget {
  const _DeviceStateCard({
    required this.device,
    required this.telemetry,
  });

  final Device device;
  final Telemetry telemetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = telemetry;
    final widget = device.type == 'controller'
        ? _controllerTile(t)
        : _sensorTile(t);
    return AppCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                device.type == 'controller'
                    ? Icons.settings_remote_rounded
                    : Icons.sensors_rounded,
                size: 18,
                color: AppColors.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  device.name,
                  style: theme.textTheme.labelLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                device.type == 'controller' ? '수문/펌프 제어기' : '센서 노드',
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 10),
          widget,
        ],
      ),
    );
  }

  Widget _controllerTile(Telemetry t) {
    return Row(
      children: [
        Expanded(
          child: _MiniStatus(
            icon: Icons.door_front_door_rounded,
            label: '수문',
            value: t.gateOpen ? '열림' : '닫힘',
            color: t.gateOpen ? AppColors.secondary : AppColors.textSecondary,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _MiniStatus(
            icon: Icons.bolt_rounded,
            label: '펌프',
            value: t.pumpOn ? '가동' : '정지',
            color: t.pumpOn ? AppColors.primary : AppColors.textSecondary,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _MiniStatus(
            icon: Icons.battery_charging_full_rounded,
            label: '배터리',
            value: '${t.batterySoc.round()}%',
            color: t.batterySoc < 30
                ? AppColors.riskSevere
                : AppColors.riskSafe,
          ),
        ),
      ],
    );
  }

  Widget _sensorTile(Telemetry t) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _MiniStatus(
          icon: Icons.opacity_rounded,
          label: '수위',
          value: '${formatNum(t.waterLevel)}cm',
          color: AppColors.secondary,
        ),
        _MiniStatus(
          icon: Icons.science_rounded,
          label: 'ORP',
          value: '${formatNum(t.orp)}mV',
          color: _orpColor(t.orp),
        ),
        _MiniStatus(
          icon: Icons.spa_rounded,
          label: '토양수분',
          value: '${formatNum(t.soilMoisture)}%',
          color: AppColors.info,
        ),
        _MiniStatus(
          icon: Icons.thermostat_rounded,
          label: '수온',
          value: '${formatNum(t.waterTemp)}°C',
          color: AppColors.info,
        ),
      ],
    );
  }
}

class _MiniStatus extends StatelessWidget {
  const _MiniStatus({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.bodyMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          Text(label, style: theme.textTheme.labelSmall),
        ],
      ),
    );
  }
}

class _SceneLegend extends StatelessWidget {
  const _SceneLegend();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _LegendItem(color: AppColors.secondary, label: '물'),
        _LegendItem(color: const Color(0xFF689F38), label: '벼'),
        _LegendItem(color: AppColors.riskSafe, label: '수문'),
        _LegendItem(color: AppColors.primary, label: '펌프'),
        _LegendItem(
          color: Colors.white70,
          label: '예상 수위',
          dash: true,
        ),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({
    required this.color,
    required this.label,
    this.dash = false,
  });

  final Color color;
  final String label;
  final bool dash;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (dash)
          Container(
            width: 14,
            height: 2,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(1),
            ),
          )
        else
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
        const SizedBox(width: 5),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}

class _SensorGrid extends StatelessWidget {
  const _SensorGrid({required this.telemetry});

  final Telemetry telemetry;

  @override
  Widget build(BuildContext context) {
    final t = telemetry;
    final tiles = <MetricTile>[
      MetricTile(
        value: formatNum(t.waterLevel),
        unit: 'cm',
        label: '수위',
        valueColor: AppColors.secondary,
      ),
      MetricTile(
        value: formatNum(t.orp),
        unit: 'mV',
        label: 'ORP',
        valueColor: _orpColor(t.orp),
      ),
      MetricTile(
        value: formatNum(t.soilMoisture),
        unit: '%',
        label: '토양수분',
        valueColor: AppColors.info,
      ),
      MetricTile(
        value: formatNum(t.ec),
        unit: 'dS/m',
        label: 'EC',
        valueColor: t.ec > 1.5 ? AppColors.riskCaution : AppColors.riskSafe,
      ),
      MetricTile(
        value: formatNum(t.waterTemp),
        unit: '°C',
        label: '수온',
        valueColor: AppColors.info,
      ),
      MetricTile(
        value: t.batterySoc.round().toString(),
        unit: '%',
        label: '배터리',
        valueColor:
            t.batterySoc < 30 ? AppColors.riskSevere : AppColors.riskSafe,
      ),
      MetricTile(
        value: formatNum(t.solarV),
        unit: 'V',
        label: '태양광',
        valueColor: AppColors.riskCaution,
      ),
      MetricTile(
        value: t.rssi.round().toString(),
        unit: 'dBm',
        label: '신호',
        valueColor: _rssiColor(t.rssi),
      ),
    ];
    return Column(
      children: [
        for (var i = 0; i < tiles.length; i += 2)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Expanded(child: tiles[i]),
                const SizedBox(width: 10),
                Expanded(child: tiles[i + 1]),
              ],
            ),
          ),
      ],
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
    final delta = predictedRisk - state.methaneScore;
    final outlook = delta < -0.01 ? '개선' : (delta > 0.01 ? '악화' : '유지');

    final insight = switch (state.awdPhase) {
      'draining' =>
        '배수 진행 중이에요. 수문이 열려 물이 빠지면서 ORP가 회복되고 있어요. 수위가 토양면 근처까지 내려가면 건조 단계로 넘어가요.',
      'dry' =>
        '건조 단계예요. 토양에 산소가 공급돼 메탄 생성이 억제되고 있어요. 건조 상태를 유지하면 ORP가 더 안정돼요.',
      'reflood' =>
        '물을 채우는 중이에요. 목표 수위(5~7cm)에 도달하면 담수 단계로 돌아가고, 다음 AWD 주기가 다시 시작돼요.',
      _ => state.rain3h
          ? '3시간 내 비가 와요. 수위가 올라 ORP가 낮아질 수 있으니 강우 전 배수를 마치세요.'
          : switch (outlook) {
              '개선' =>
                '배수 효과가 나타나 메탄 위험이 줄어들 전망이에요. 지금 수위를 유지해 주세요.',
              '악화' =>
                '메탄 위험이 올라갈 수 있어요. 수문을 열어 물을 조금 빼고 수위를 확인하세요.',
              _ => '현재 제어대로 유지하면 안정적으로 이어질 전망이에요.',
            },
    };
    final awdColor = switch (state.awdPhase) {
      'draining' => AppColors.info,
      'dry' => AppColors.riskCaution,
      'reflood' => AppColors.primary,
      _ => AppColors.secondary,
    };

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
                  Text(
                    'AWD 사이클 · ${awdPhaseShort(state.awdPhase)}',
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: awdColor, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _AwdSteps(current: state.awdPhase),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _PredictStat(
                      label: '수위',
                      now: formatNum(state.waterLevel),
                      predicted: formatNum(state.predictedLevel3h),
                      unit: 'cm',
                      delta: state.predictedLevel3h - state.waterLevel,
                      upIsGood: false,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _PredictStat(
                      label: 'ORP',
                      now: formatNum(state.orp),
                      predicted: formatNum(state.predictedOrp3h),
                      unit: 'mV',
                      delta: state.predictedOrp3h - state.orp,
                      upIsGood: true,
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.insights_rounded, size: 20, color: predColor),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '메탄 위험도 ${riskLabel(state.methaneScore)} → '
                        '${riskLabel(predictedRisk)} 전망 · $outlook',
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  insight,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.4,
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

class _AwdSteps extends StatelessWidget {
  const _AwdSteps({required this.current});

  final String current;

  @override
  Widget build(BuildContext context) {
    const steps = ['flooded', 'draining', 'dry', 'reflood'];
    const labels = ['담수', '배수', '건조', '재관수'];
    final idx = steps.indexOf(current);
    final theme = Theme.of(context);
    final doneColor = theme.colorScheme.primary;
    final pendingColor = theme.colorScheme.outlineVariant;
    return Row(
      children: [
        for (var i = 0; i < steps.length; i++) ...[
          if (i > 0)
            Expanded(
              child: Container(
                height: 2,
                margin: const EdgeInsets.only(bottom: 16),
                color: i <= idx ? doneColor : pendingColor,
              ),
            ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 15,
                height: 15,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i <= idx ? doneColor : pendingColor,
                ),
                child: i < idx
                    ? Icon(Icons.check,
                        size: 10, color: theme.colorScheme.onPrimary)
                    : (i == idx
                        ? Container(
                            width: 5,
                            height: 5,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                            ),
                          )
                        : null),
              ),
              const SizedBox(height: 4),
              Text(
                labels[i],
                style: theme.textTheme.labelSmall?.copyWith(
                  color: i == idx
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                  fontWeight: i == idx ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _PredictStat extends StatelessWidget {
  const _PredictStat({
    required this.label,
    required this.now,
    required this.predicted,
    required this.unit,
    required this.delta,
    required this.upIsGood,
  });

  final String label;
  final String now;
  final String predicted;
  final String unit;
  final double delta;
  final bool upIsGood;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rising = delta >= 0;
    final trendColor = rising
        ? (upIsGood ? AppColors.riskSafe : AppColors.riskHigh)
        : (upIsGood ? AppColors.riskHigh : AppColors.riskSafe);
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
          Row(
            children: [
              Icon(
                rising ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                size: 15,
                color: trendColor,
              ),
              const SizedBox(width: 2),
              Text(
                '예상 $predicted$unit (${formatSigned(delta)})',
                style: theme.textTheme.labelMedium
                    ?.copyWith(color: theme.colorScheme.primary),
              ),
            ],
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