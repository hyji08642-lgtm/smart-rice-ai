import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/core/widgets/app_card.dart';
import '../../app/store/providers.dart';
import '../../app/theme/app_colors.dart';
import '../../shared/models/paddy.dart';
import '../../shared/models/recommendation.dart';
import '../../shared/models/telemetry.dart';
import '../../shared/models/twin_state.dart';

class ControlScreen extends ConsumerWidget {
  const ControlScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(telemetryProvider).value;
    final twin = ref.watch(twinProvider).value;
    final settings = ref.watch(settingsProvider);
    final recommendation = ref.watch(recommendationProvider);
    final paddyId = ref.watch(selectedPaddyProvider);
    final paddies = ref.watch(paddiesProvider);
    final name = paddies
            .cast<Paddy?>()
            .firstWhere((p) => p?.id == paddyId, orElse: () => null)
            ?.name ??
        '내 논';

    return Scaffold(
      appBar: AppBar(title: Text('$name · 원격 제어')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _OverviewCard(t: t, awdPhase: twin?.awdPhase),
          const SizedBox(height: 12),
          _AutoControlCard(
            autoControl: settings.autoControl,
            onChanged: ref.read(settingsProvider.notifier).setAutoControl,
          ),
          if (recommendation.status == RecommendationStatus.pending) ...[
            const SizedBox(height: 12),
            _ApplyCard(
              onApply: () => _apply(context, ref),
            ),
          ],
          const SizedBox(height: 12),
          _ControlGrid(
            enabled: !settings.autoControl,
            gateOpen: t?.gateOpen ?? false,
            pumpOn: t?.pumpOn ?? false,
            onGate: (open) => _setGate(context, ref, open),
            onPump: (on) => _setPump(context, ref, on),
          ),
          const SizedBox(height: 16),
          _EmergencyStop(onPressed: () => _emergency(context, ref)),
        ],
      ),
    );
  }

  void _setGate(BuildContext context, WidgetRef ref, bool open) {
    ref.read(sensorApiProvider).setGateOpen(open);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(open ? '수문을 열었습니다' : '수문을 닫았습니다')),
    );
  }

  void _setPump(BuildContext context, WidgetRef ref, bool on) {
    ref.read(sensorApiProvider).setPumpOn(on);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(on ? '펌프를 켰습니다' : '펌프를 껐습니다')),
    );
  }

  void _apply(BuildContext context, WidgetRef ref) {
    ref.read(recommendationProvider.notifier).approve();
    ref.read(sensorApiProvider).setGateOpen(true);
    ref.read(sensorApiProvider).setPumpOn(false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('AI 추천을 적용했습니다. AWD 배수를 시작합니다.')),
    );
  }

  void _emergency(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('긴급 정지'),
        content: const Text('펌프를 끄고 수문을 닫을까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('취소'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.riskSevere),
            onPressed: () {
              Navigator.of(dialogContext).pop();
              ref.read(sensorApiProvider).emergencyStop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('긴급 정지 실행 · 펌프 OFF, 수문 CLOSE'),
                ),
              );
            },
            child: const Text('정지하기'),
          ),
        ],
      ),
    );
  }
}

class _OverviewCard extends StatelessWidget {
  const _OverviewCard({required this.t, required this.awdPhase});

  final Telemetry? t;
  final String? awdPhase;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = this.t;
    final gateOpen = t?.gateOpen ?? false;
    final pumpOn = t?.pumpOn ?? false;
    final awdColor = switch (awdPhase) {
      'draining' => AppColors.info,
      'dry' => AppColors.riskCaution,
      'reflood' => AppColors.primary,
      _ => AppColors.secondary,
    };
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('현재 상태', style: theme.textTheme.titleMedium),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _StatusLine(
                  icon: Icons.door_front_door_rounded,
                  color: gateOpen ? AppColors.secondary : theme.colorScheme.onSurfaceVariant,
                  text: gateOpen ? '수문 열림' : '수문 닫힘',
                ),
              ),
              Expanded(
                child: _StatusLine(
                  icon: Icons.bolt_rounded,
                  color: pumpOn ? AppColors.primary : theme.colorScheme.onSurfaceVariant,
                  text: pumpOn ? '펌프 가동' : '펌프 정지',
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _StatusLine(
                  icon: switch (awdPhase) {
                    'draining' => Icons.arrow_downward_rounded,
                    'dry' => Icons.grass_rounded,
                    'reflood' => Icons.water_drop_rounded,
                    _ => Icons.opacity_rounded,
                  },
                  color: awdColor,
                  text: awdPhase == null ? 'AWD —' : 'AWD ${awdPhaseShort(awdPhase!)}',
                ),
              ),
              Expanded(
                child: _StatusLine(
                  icon: Icons.battery_alert_rounded,
                  color: (t != null && t.batterySoc < 30)
                      ? AppColors.riskHigh
                      : AppColors.riskSafe,
                  text: t == null ? '—' : '배터리 ${t.batterySoc.round()}%',
                ),
              ),
              Expanded(
                child: _StatusLine(
                  icon: Icons.connected_tv_rounded,
                  color: AppColors.riskSafe,
                  text: '연결됨',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.icon, required this.color, required this.text});

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            text,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(fontWeight: FontWeight.w600),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _AutoControlCard extends StatelessWidget {
  const _AutoControlCard({required this.autoControl, required this.onChanged});

  final bool autoControl;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      child: Row(
        children: [
          Icon(
            Icons.auto_awesome_rounded,
            size: 20,
            color: autoControl
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('AI 자동 제어', style: theme.textTheme.labelLarge),
                Text(
                  autoControl
                      ? '켜짐 · 신뢰도 0.6 이상만 자동 실행'
                      : '꺼짐 · 모든 제어는 수동으로',
                  style: theme.textTheme.labelMedium,
                ),
              ],
            ),
          ),
          Switch(value: autoControl, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _ApplyCard extends StatelessWidget {
  const _ApplyCard({required this.onApply});

  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('AI 추천 대기 중', style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            'AWD 배수 시작 · 신뢰도 87%',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onApply,
              icon: const Icon(Icons.auto_awesome_rounded, size: 18),
              label: const Text('AI 추천 적용하기'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ControlGrid extends StatelessWidget {
  const _ControlGrid({
    required this.enabled,
    required this.gateOpen,
    required this.pumpOn,
    required this.onGate,
    required this.onPump,
  });

  final bool enabled;
  final bool gateOpen;
  final bool pumpOn;
  final ValueChanged<bool> onGate;
  final ValueChanged<bool> onPump;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('수문 · 펌프 제어', style: theme.textTheme.titleMedium),
              const Spacer(),
              if (!enabled)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary
                        .withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.lock_outline_rounded,
                          size: 13, color: AppColors.primary),
                      const SizedBox(width: 4),
                      Text(
                        'AI 제어 중',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          if (!enabled) ...[
            const SizedBox(height: 4),
            Text(
              'AI 자동 제어가 켜져 있어 수동 조작이 잠겼어요.',
              style: theme.textTheme.labelMedium,
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _ControlButton(
                  icon: Icons.door_front_door_rounded,
                  label: '수문 열기',
                  filled: gateOpen,
                  color: AppColors.secondary,
                  enabled: enabled,
                  onTap: () => onGate(true),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ControlButton(
                  icon: Icons.door_front_door_rounded,
                  label: '수문 닫기',
                  filled: !gateOpen,
                  enabled: enabled,
                  onTap: () => onGate(false),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _ControlButton(
                  icon: Icons.bolt_rounded,
                  label: '펌프 켜기',
                  filled: pumpOn,
                  enabled: enabled,
                  onTap: () => onPump(true),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ControlButton(
                  icon: Icons.power_settings_new_rounded,
                  label: '펌프 끄기',
                  filled: !pumpOn,
                  enabled: enabled,
                  onTap: () => onPump(false),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  const _ControlButton({
    required this.icon,
    required this.label,
    required this.filled,
    required this.onTap,
    this.color,
    this.enabled = true,
  });

  final IconData icon;
  final String label;
  final bool filled;
  final VoidCallback onTap;
  final Color? color;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    if (filled) {
      return FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: color ?? Theme.of(context).colorScheme.primary,
        ),
        onPressed: enabled ? onTap : null,
        icon: Icon(icon, size: 20),
        label: Text(label),
      );
    }
    return OutlinedButton.icon(
      onPressed: enabled ? onTap : null,
      icon: Icon(icon, size: 20),
      label: Text(label),
    );
  }
}

class _EmergencyStop extends StatelessWidget {
  const _EmergencyStop({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.riskSevere,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        onPressed: onPressed,
        icon: const Icon(Icons.stop_circle_rounded, size: 22),
        label: const Text(
          '긴급 정지',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
