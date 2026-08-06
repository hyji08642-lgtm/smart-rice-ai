enum RecommendationStatus { pending, approved, rejected }

class Recommendation {
  const Recommendation({
    required this.id,
    required this.title,
    required this.action,
    required this.confidence,
    required this.reason,
    required this.xaiSteps,
    this.status = RecommendationStatus.pending,
  });

  final String id;
  final String title;
  final String action;
  final double confidence;
  final String reason;
  final List<String> xaiSteps;
  final RecommendationStatus status;
}
