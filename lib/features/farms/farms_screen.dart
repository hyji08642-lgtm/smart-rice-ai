import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/core/utils/risk.dart';
import '../../app/core/widgets/app_card.dart';
import '../../app/store/providers.dart';
import '../../app/theme/app_colors.dart';
import '../../shared/models/paddy.dart';

class FarmsScreen extends ConsumerWidget {
  const FarmsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paddies = ref.watch(paddiesProvider);
    final selectedId = ref.watch(selectedPaddyProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('내 농장')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              '내 논',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              '논을 선택하면 홈·원격 제어·일지가 그 논 기준으로 바뀌어요.',
              style: Theme.of(context).textTheme.labelMedium,
            ),
            const SizedBox(height: 12),
            for (final paddy in paddies) ...[
              _PaddyCard(
                paddy: paddy,
                selected: paddy.id == selectedId,
                onTap: () =>
                    ref.read(selectedPaddyProvider.notifier).select(paddy.id),
              ),
              const SizedBox(height: 10),
            ],
            const SizedBox(height: 4),
            _AddPaddyCard(onTap: () => ref.read(paddiesProvider.notifier).addPaddy()),
          ],
        ),
      ),
    );
  }
}

class _PaddyCard extends StatelessWidget {
  const _PaddyCard({
    required this.paddy,
    required this.selected,
    required this.onTap,
  });

  final Paddy paddy;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = riskColor(paddy.riskScore);
    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.grain_rounded, color: color, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  paddy.name,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  '${paddy.stage} · ${paddy.area}',
                  style: theme.textTheme.labelMedium,
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  riskLabel(paddy.riskScore),
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: color, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 6),
              if (selected)
                const Icon(Icons.check_circle_rounded,
                    color: AppColors.primary, size: 18),
            ],
          ),
        ],
      ),
    );
  }
}

class _AddPaddyCard extends StatelessWidget {
  const _AddPaddyCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      onTap: onTap,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.add_circle_outline_rounded,
              color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Text('새 논 추가', style: theme.textTheme.labelLarge),
        ],
      ),
    );
  }
}
