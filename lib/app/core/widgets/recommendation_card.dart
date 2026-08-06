import 'package:flutter/material.dart';

import '../../../shared/models/recommendation.dart';
import 'app_card.dart';

class RecommendationCard extends StatelessWidget {
  const RecommendationCard({
    super.key,
    required this.recommendation,
    required this.onApprove,
    required this.onReject,
    this.onDetails,
  });

  final Recommendation recommendation;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback? onDetails;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.primary;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.auto_awesome_rounded, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  recommendation.title,
                  style: theme.textTheme.titleMedium,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '신뢰도 ${(recommendation.confidence * 100).round()}',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(recommendation.reason, style: theme.textTheme.bodyMedium),
          if (recommendation.xaiSteps.isNotEmpty) ...[
            const SizedBox(height: 4),
            TextButton.icon(
              onPressed: onDetails,
              icon: const Icon(Icons.account_tree_outlined, size: 18),
              label: const Text('근거 보기'),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: onApprove,
                  child: const Text('승인'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: onReject,
                  child: const Text('거절'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
