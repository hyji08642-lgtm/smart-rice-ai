import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/core/utils/formats.dart';
import '../../app/store/providers.dart';
import '../../app/theme/app_colors.dart';
import '../../shared/models/app_notification.dart';

enum _Filter { all, methaneRisk, awdDrain, awdDry, awdReflood }

class NotificationScreen extends ConsumerStatefulWidget {
  const NotificationScreen({super.key});

  @override
  ConsumerState<NotificationScreen> createState() =>
      _NotificationScreenState();
}

class _NotificationScreenState extends ConsumerState<NotificationScreen> {
  _Filter _filter = _Filter.all;

  @override
  Widget build(BuildContext context) {
    final notifications =
        ref.watch(notificationsProvider).value ?? const <AppNotification>[];
    final filtered = notifications.where((n) {
      return switch (_filter) {
        _Filter.all => true,
        _Filter.methaneRisk => n.type == NotificationType.methaneRisk,
        _Filter.awdDrain => n.type == NotificationType.awdDrain,
        _Filter.awdDry => n.type == NotificationType.awdDry,
        _Filter.awdReflood =>
          n.type == NotificationType.awdReflood ||
              n.type == NotificationType.awdFlood,
      };
    }).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('알림')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Row(
              children: [
                for (final f in _Filter.values) ...[
                  ChoiceChip(
                    label: Text(_filterLabel(f)),
                    selected: _filter == f,
                    onSelected: (_) => setState(() => _filter = f),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? const Center(child: Text('알림이 없습니다'))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final n = filtered[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _NotificationTile(
                          item: n,
                          onTap: () => ref
                              .read(mockApiProvider)
                              .markNotificationRead(n.id),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  String _filterLabel(_Filter f) => switch (f) {
        _Filter.all => '전체',
        _Filter.methaneRisk => '메탄',
        _Filter.awdDrain => '배수',
        _Filter.awdDry => '건조',
        _Filter.awdReflood => '재관수',
      };
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.item, required this.onTap});

  final AppNotification item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (icon, color) = switch (item.type) {
      NotificationType.methaneRisk =>
        (Icons.auto_awesome_rounded, AppColors.riskHigh),
      NotificationType.awdDrain =>
        (Icons.arrow_downward_rounded, AppColors.info),
      NotificationType.awdDry => (Icons.grass_rounded, AppColors.riskCaution),
      NotificationType.awdReflood =>
        (Icons.water_drop_rounded, AppColors.primary),
      NotificationType.awdFlood => (Icons.opacity_rounded, AppColors.secondary),
    };
    return Material(
      color: item.read
          ? theme.colorScheme.surface
          : theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            style: theme.textTheme.labelLarge,
                          ),
                        ),
                        Text(formatTime(item.time), style: theme.textTheme.labelSmall),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(item.body, style: theme.textTheme.bodyMedium),
                  ],
                ),
              ),
              if (!item.read)
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
