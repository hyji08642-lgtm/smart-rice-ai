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
}
