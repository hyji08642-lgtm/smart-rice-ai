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

  factory Telemetry.fromJson(Map<String, dynamic> json) => Telemetry(
        paddyId: json['paddy_id'] as String,
        orp: (json['orp'] as num).toDouble(),
        ec: (json['ec'] as num).toDouble(),
        waterLevel: (json['water_level'] as num).toDouble(),
        soilMoisture: (json['soil_moisture'] as num).toDouble(),
        waterTemp: (json['water_temp'] as num).toDouble(),
        batterySoc: (json['battery_soc'] as num).toDouble(),
        solarV: (json['solar_v'] as num).toDouble(),
        gateOpen: json['gate_open'] as bool,
        pumpOn: json['pump_on'] as bool,
        rssi: (json['rssi'] as num).toDouble(),
        methaneScore: (json['methane_score'] as num).toDouble(),
        orpDelta1h: (json['orp_delta_1h'] as num).toDouble(),
        rain3h: json['rain_3h'] as bool,
      );
}
