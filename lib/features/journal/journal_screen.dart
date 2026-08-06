import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/core/utils/formats.dart';
import '../../app/store/providers.dart';
import '../../app/theme/app_colors.dart';
import '../../shared/models/journal_entry.dart';

class JournalScreen extends ConsumerWidget {
  const JournalScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final journal = ref.watch(journalProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('AI 운영일지')),
      body: journal.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('불러오기 실패: $e')),
        data: (entries) => ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          itemCount: entries.length,
          itemBuilder: (context, index) {
            final entry = entries[index];
            final prev = index > 0 ? entries[index - 1] : null;
            final isNewDay = prev == null || prev.time.day != entry.time.day;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (isNewDay) _DayDivider(date: entry.time),
                TimelineItem(entry: entry, isLast: index == entries.length - 1),
              ],
            );
          },
        ),
      ),
    );
  }
}

class TimelineItem extends StatelessWidget {
  const TimelineItem({super.key, required this.entry, required this.isLast});

  final JournalEntry entry;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 28,
            child: Column(
              children: [
                const SizedBox(height: 4),
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _typeColor(entry.type),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(width: 2, color: theme.colorScheme.outline),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(formatTime(entry.time), style: theme.textTheme.labelMedium),
                      const Spacer(),
                      _TypeLabel(type: entry.type),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    entry.title,
                    style: theme.textTheme.bodyLarge
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  if (entry.detail != null) ...[
                    const SizedBox(height: 2),
                    Text(entry.detail!, style: theme.textTheme.bodyMedium),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DayDivider extends StatelessWidget {
  const _DayDivider({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Expanded(child: Container(height: 1, color: theme.colorScheme.outline)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(formatMonthDay(date), style: theme.textTheme.labelMedium),
          ),
          Expanded(child: Container(height: 1, color: theme.colorScheme.outline)),
        ],
      ),
    );
  }
}

class _TypeLabel extends StatelessWidget {
  const _TypeLabel({required this.type});

  final JournalEventType type;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _typeColor(type);
    final label = switch (type) {
      JournalEventType.decision => '판단',
      JournalEventType.execution => '실행',
      JournalEventType.expected => '예상',
      JournalEventType.actual => '실제',
      JournalEventType.notice => '정보',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(color: color),
      ),
    );
  }
}

Color _typeColor(JournalEventType type) => switch (type) {
      JournalEventType.decision => AppColors.primary,
      JournalEventType.execution => AppColors.secondary,
      JournalEventType.expected => AppColors.info,
      JournalEventType.actual => AppColors.riskSafe,
      JournalEventType.notice => AppColors.riskCaution,
    };
