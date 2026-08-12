class TwinState {
  const TwinState({
    required this.paddyId,
    required this.waterLevel,
    required this.predictedLevel3h,
    required this.orp,
    required this.predictedOrp3h,
    required this.methaneScore,
    required this.gateOpen,
    required this.pumpOn,
    required this.weather,
    required this.tempC,
    required this.rain3h,
    required this.awdPhase,
  });

  final String paddyId;
  final double waterLevel;
  final double predictedLevel3h;
  final double orp;
  final double predictedOrp3h;
  final double methaneScore;
  final bool gateOpen;
  final bool pumpOn;
  final String weather;
  final double tempC;
  final bool rain3h;

  /// AWD(간단관개) 단계: flooded(담수) / draining(배수) / dry(건조) / reflood(재관수).
  final String awdPhase;
}

String awdPhaseLabel(String phase) => switch (phase) {
      'draining' => 'AWD 배수 중',
      'dry' => 'AWD 건조 중',
      'reflood' => 'AWD 재관수',
      _ => 'AWD 담수',
    };

String awdPhaseShort(String phase) => switch (phase) {
      'draining' => '배수',
      'dry' => '건조',
      'reflood' => '재관수',
      _ => '담수',
    };
