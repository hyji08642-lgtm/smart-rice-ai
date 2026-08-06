class Telemetry {
  const Telemetry({
    required this.paddyId,
    required this.orp,
    required this.ec,
    required this.waterLevel,
    required this.soilMoisture,
    required this.waterTemp,
    required this.batterySoc,
    required this.solarV,
    required this.gateOpen,
    required this.pumpOn,
    required this.rssi,
    required this.methaneScore,
    required this.orpDelta1h,
    required this.rain3h,
  });

  final String paddyId;
  final double orp;
  final double ec;
  final double waterLevel;
  final double soilMoisture;
  final double waterTemp;
  final double batterySoc;
  final double solarV;
  final bool gateOpen;
  final bool pumpOn;
  final double rssi;
  final double methaneScore;
  final double orpDelta1h;
  final bool rain3h;
}
