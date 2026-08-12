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

  factory TwinState.fromJson(Map<String, dynamic> json) => TwinState(
        paddyId: json['paddy_id'] as String,
        waterLevel: (json['water_level'] as num).toDouble(),
        predictedLevel3h: (json['predicted_level_3h'] as num).toDouble(),
        orp: (json['orp'] as num).toDouble(),
        predictedOrp3h: (json['predicted_orp_3h'] as num).toDouble(),
        methaneScore: (json['methane_score'] as num).toDouble(),
        gateOpen: json['gate_open'] as bool,
        pumpOn: json['pump_on'] as bool,
        weather: json['weather'] as String,
        tempC: (json['temp_c'] as num).toDouble(),
        rain3h: json['rain_3h'] as bool,
        awdPhase: json['awd_phase'] as String,
      );
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
