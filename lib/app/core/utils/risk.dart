import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

enum RiskLevel { safe, caution, high, severe }

RiskLevel riskLevel(double score) {
  if (score < 0.4) return RiskLevel.safe;
  if (score < 0.6) return RiskLevel.caution;
  if (score < 0.8) return RiskLevel.high;
  return RiskLevel.severe;
}

String riskLabel(double score) => switch (riskLevel(score)) {
      RiskLevel.safe => '안전',
      RiskLevel.caution => '주의',
      RiskLevel.high => '위험',
      RiskLevel.severe => '심각',
    };

Color riskColor(double score) => switch (riskLevel(score)) {
      RiskLevel.safe => AppColors.riskSafe,
      RiskLevel.caution => AppColors.riskCaution,
      RiskLevel.high => AppColors.riskHigh,
      RiskLevel.severe => AppColors.riskSevere,
    };
