import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/core/utils/risk.dart';
import '../../app/core/widgets/app_card.dart';
import '../../app/store/providers.dart';
import '../../app/theme/app_colors.dart';
import '../../shared/models/paddy.dart';

const _stages = ['육묘', '이앙', '담수기', '간단관개기', '중간낙수기'];
const _areas = ['500㎡', '850㎡', '1,000㎡', '1,200㎡', '1,500㎡'];

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
              '논을 누르면 그 논의 홈으로 이동해요.',
              style: Theme.of(context).textTheme.labelMedium,
            ),
            const SizedBox(height: 12),
            for (final paddy in paddies) ...[
              _PaddyCard(
                paddy: paddy,
                selected: paddy.id == selectedId,
                deletable: paddies.length > 1,
                onTap: () {
                  ref.read(selectedPaddyProvider.notifier).select(paddy.id);
                  context.go('/home');
                },
                onDelete: () => _confirmDelete(context, ref, paddy, paddies),
              ),
              const SizedBox(height: 10),
            ],
            const SizedBox(height: 4),
            _AddPaddyCard(
              onTap: () => _showAddSheet(context, ref),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAddSheet(BuildContext context, WidgetRef ref) async {
    final result = await showModalBottomSheet<(String, String, String)>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (_) => const _AddPaddySheet(),
    );
    if (result == null || !context.mounted) return;
    final (name, stage, area) = result;
    final id = ref.read(paddiesProvider.notifier).addPaddy(
          name: name,
          stage: stage,
          area: area,
        );
    ref.read(selectedPaddyProvider.notifier).select(id);
    context.go('/home');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$name ($stage · $area) 추가 완료')),
    );
  }

  void _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Paddy paddy,
    List<Paddy> paddies,
  ) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('논 삭제'),
        content: Text('${paddy.name}을(를) 삭제할까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('취소'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.riskSevere,
            ),
            onPressed: () {
              ref.read(paddiesProvider.notifier).removePaddy(paddy.id);
              if (ref.read(selectedPaddyProvider) == paddy.id &&
                  paddies.length > 1) {
                final next = paddies.firstWhere((p) => p.id != paddy.id);
                ref.read(selectedPaddyProvider.notifier).select(next.id);
              }
              Navigator.of(dialogContext).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('${paddy.name} 삭제 완료')),
              );
            },
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }
}

class _PaddyCard extends StatelessWidget {
  const _PaddyCard({
    required this.paddy,
    required this.selected,
    required this.deletable,
    required this.onTap,
    required this.onDelete,
  });

  final Paddy paddy;
  final bool selected;
  final bool deletable;
  final VoidCallback onTap;
  final VoidCallback onDelete;

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
                Row(
                  children: [
                    Text(
                      paddy.name,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(width: 6),
                    if (selected)
                      const Icon(Icons.check_circle_rounded,
                          color: AppColors.primary, size: 16),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${paddy.stage} · ${paddy.area}',
                  style: theme.textTheme.labelMedium,
                ),
              ],
            ),
          ),
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
          if (deletable)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, size: 20),
              color: theme.colorScheme.onSurfaceVariant,
              tooltip: '삭제',
              onPressed: onDelete,
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

class _AddPaddySheet extends StatefulWidget {
  const _AddPaddySheet();

  @override
  State<_AddPaddySheet> createState() => _AddPaddySheetState();
}

class _AddPaddySheetState extends State<_AddPaddySheet> {
  late final TextEditingController _name;
  String _stage = _stages[0];
  String _area = _areas[2];

  @override
  void initState() {
    super.initState();
    _name = TextEditingController();
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('새 논 추가', style: theme.textTheme.titleLarge),
          const SizedBox(height: 12),
          TextField(
            controller: _name,
            decoration: const InputDecoration(
              labelText: '이름',
              hintText: '예) 뒷동산 논',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          Text('생육 단계', style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final s in _stages)
                ChoiceChip(
                  label: Text(s),
                  selected: _stage == s,
                  onSelected: (_) => setState(() => _stage = s),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text('면적', style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final a in _areas)
                ChoiceChip(
                  label: Text(a),
                  selected: _area == a,
                  onSelected: (_) => setState(() => _area = a),
                ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () {
                final name = _name.text.trim().isEmpty
                    ? '새 논'
                    : _name.text.trim();
                Navigator.of(context).pop((name, _stage, _area));
              },
              icon: const Icon(Icons.check_rounded),
              label: const Text('추가하기'),
            ),
          ),
        ],
      ),
    );
  }
}
