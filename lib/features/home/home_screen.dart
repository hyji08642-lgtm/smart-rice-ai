import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/core/utils/formats.dart';
import '../../app/core/utils/risk.dart';
import '../../app/core/widgets/app_card.dart';
import '../../app/core/widgets/status_chip.dart';
import '../../app/store/providers.dart';
import '../../app/theme/app_colors.dart';
import '../../shared/models/paddy.dart';
import '../../shared/models/task_item.dart';
import '../../shared/models/telemetry.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final telemetry = ref.watch(telemetryProvider).value;
    final paddyId = ref.watch(selectedPaddyProvider);
    final paddies = ref.watch(paddiesProvider);
    final paddy =
        paddies.cast<Paddy?>().firstWhere((p) => p?.id == paddyId, orElse: () => null);
    final summary = ref.watch(aiSummaryProvider);
    final tasks = ref.watch(todayTasksProvider);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            _Header(
              paddy: paddy,
              onPaddy: () => context.push('/paddy'),
              onFarm: () => context.go('/farms'),
              onSettings: () => context.go('/settings'),
            ),
            const SizedBox(height: 16),
            _SummaryCard(summary: summary, score: telemetry?.methaneScore ?? 0),
            const SizedBox(height: 16),
            _TasksCard(
              tasks: tasks,
              onToggle: (id) => ref.read(todayTasksProvider.notifier).toggle(id),
              onAction: () => context.push('/control'),
            ),
            const SizedBox(height: 16),
            _StatusCard(telemetry: telemetry),
            const SizedBox(height: 8),
            Text('바로가기', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            _Shortcuts(
              onPaddy: () => context.push('/paddy'),
              onControl: () => context.go('/control'),
              onChat: () => context.push('/chat'),
              onJournal: () => context.go('/journal'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.paddy,
    required this.onPaddy,
    required this.onFarm,
    required this.onSettings,
  });

  final Paddy? paddy;
  final VoidCallback onPaddy;
  final VoidCallback onFarm;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final paddy = this.paddy;
    return Row(
      children: [
        InkWell(
          onTap: onPaddy,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.water_drop_rounded, color: AppColors.primary, size: 22),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Smart Rice AI', style: theme.textTheme.labelSmall),
              const SizedBox(height: 2),
              Text(
                paddy?.name ?? '내 논',
                style: theme.textTheme.titleLarge,
              ),
              if (paddy != null)
                Text(
                  '${paddy.stage} · ${formatMonthDay(DateTime.now())}',
                  style: theme.textTheme.labelMedium,
                ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.agriculture_rounded),
          tooltip: '내 농장',
          onPressed: onFarm,
        ),
        IconButton(
          icon: const Icon(Icons.settings_outlined),
          tooltip: '설정',
          onPressed: onSettings,
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.summary, required this.score});

  final String summary;
  final double score;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.auto_awesome_rounded,
                size: 18,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'AI 비서',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            summary,
            style: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _RiskPill(score: score),
              const Spacer(),
              Text('방금 업데이트', style: theme.textTheme.labelSmall),
            ],
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            '메탄 위험도 ${riskLabel(score)}',
            style: Theme.of(context)
                .textTheme
                .labelMedium
                ?.copyWith(color: color, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _TasksCard extends StatelessWidget {
  const _TasksCard({
    required this.tasks,
    required this.onToggle,
    required this.onAction,
  });

  final List<TaskItem> tasks;
  final ValueChanged<String> onToggle;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('오늘 해야 할 일', style: theme.textTheme.titleMedium),
          const SizedBox(height: 2),
          Text(
            'AI가 오늘 가장 필요한 일을 골랐어요',
            style: theme.textTheme.labelMedium,
          ),
          const SizedBox(height: 8),
          for (final task in tasks)
            _TaskRow(
              task: task,
              onToggle: () => onToggle(task.id),
              onAction: onAction,
            ),
        ],
      ),
    );
  }
}

class _TaskRow extends StatelessWidget {
  const _TaskRow({
    required this.task,
    required this.onToggle,
    required this.onAction,
  });

  final TaskItem task;
  final VoidCallback onToggle;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Widget leading = switch (task.kind) {
      TaskKind.check => InkWell(
          onTap: onToggle,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Icon(
              task.done
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked,
              size: 22,
              color: task.done
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      TaskKind.action => const Padding(
          padding: EdgeInsets.all(4),
          child: Icon(Icons.auto_awesome_rounded, size: 20, color: AppColors.primary),
        ),
      TaskKind.alert => const Padding(
          padding: EdgeInsets.all(4),
          child: Icon(
            Icons.warning_amber_rounded,
            size: 20,
            color: AppColors.riskHigh,
          ),
        ),
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          leading,
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              task.text,
              style: theme.textTheme.bodyMedium?.copyWith(
                decoration: task.done ? TextDecoration.lineThrough : null,
                color: task.done
                    ? theme.colorScheme.onSurfaceVariant
                    : theme.colorScheme.onSurface,
              ),
            ),
          ),
          if (task.action != null && !task.done)
            TextButton(onPressed: onAction, child: Text(task.action!)),
        ],
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.telemetry});

  final Telemetry? telemetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = telemetry;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('내 논 상태', style: theme.textTheme.titleMedium),
              const Spacer(),
              Text(
                t == null ? '연결 확인 중' : '방금 업데이트',
                style: theme.textTheme.labelSmall,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _Stat(
                  icon: Icons.water_drop_rounded,
                  value: t == null ? '—' : '${formatNum(t.waterLevel)}cm',
                  label: '물',
                  color: AppColors.secondary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _Stat(
                  icon: Icons.thermostat_rounded,
                  value: t == null ? '—' : '${formatNum(t.waterTemp)}°C',
                  label: '수온',
                  color: AppColors.info,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _Stat(
                  icon: Icons.battery_alert_rounded,
                  value: t == null ? '—' : '${t.batterySoc.round()}%',
                  label: '배터리',
                  color: (t != null && t.batterySoc < 30)
                      ? AppColors.riskHigh
                      : AppColors.riskSafe,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: StatusChip(
                  icon: Icons.door_front_door_rounded,
                  label: (t?.gateOpen ?? false) ? '수문 열림' : '수문 닫힘',
                  active: t?.gateOpen ?? false,
                  activeColor: AppColors.secondary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: StatusChip(
                  icon: Icons.bolt_rounded,
                  label: (t?.pumpOn ?? false) ? '펌프 가동' : '펌프 정지',
                  active: t?.pumpOn ?? false,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 6),
          Text(
            value,
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          Text(label, style: theme.textTheme.labelSmall),
        ],
      ),
    );
  }
}

class _Shortcuts extends StatelessWidget {
  const _Shortcuts({
    required this.onPaddy,
    required this.onControl,
    required this.onChat,
    required this.onJournal,
  });

  final VoidCallback onPaddy;
  final VoidCallback onControl;
  final VoidCallback onChat;
  final VoidCallback onJournal;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _Shortcut(
            icon: Icons.grain_rounded,
            label: '논 보기',
            onTap: onPaddy,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _Shortcut(
            icon: Icons.tune_rounded,
            label: '원격 제어',
            onTap: onControl,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _Shortcut(
            icon: Icons.chat_rounded,
            label: 'AI 상담',
            onTap: onChat,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _Shortcut(
            icon: Icons.history_rounded,
            label: '운영일지',
            onTap: onJournal,
          ),
        ),
      ],
    );
  }
}

class _Shortcut extends StatelessWidget {
  const _Shortcut({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: 16),
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, size: 26, color: theme.colorScheme.primary),
          const SizedBox(height: 8),
          Text(
            label,
            style: theme.textTheme.labelLarge,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
