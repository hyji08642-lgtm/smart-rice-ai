class Paddy {
  const Paddy({
    required this.id,
    required this.name,
    required this.stage,
    required this.area,
    required this.riskScore,
    this.deviceIds = const [],
  });

  final String id;
  final String name;
  final String stage;
  final String area;
  final double riskScore;

  /// 이 논에 연결된 기기 id 목록(수문제어기 1대 + 센서 노드 2대 등).
  final List<String> deviceIds;

  Paddy copyWith({
    String? id,
    String? name,
    String? stage,
    String? area,
    double? riskScore,
    List<String>? deviceIds,
  }) {
    return Paddy(
      id: id ?? this.id,
      name: name ?? this.name,
      stage: stage ?? this.stage,
      area: area ?? this.area,
      riskScore: riskScore ?? this.riskScore,
      deviceIds: deviceIds ?? this.deviceIds,
    );
  }

  factory Paddy.fromJson(Map<String, dynamic> json) => Paddy(
        id: json['id'] as String,
        name: json['name'] as String,
        stage: json['stage'] as String? ?? '담수기',
        area: json['area'] as String? ?? '1,000㎡',
        riskScore: (json['risk_score'] as num?)?.toDouble() ?? 0.3,
        deviceIds: [
          for (final d in json['device_ids'] as List? ?? const []) d as String,
        ],
      );
}
