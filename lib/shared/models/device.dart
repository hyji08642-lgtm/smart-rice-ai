/// 사용자가 등록한 ESP32 세트(제품).
///
/// ESP32 한 대가 센서(수위·수온·ORP·EC·토양수분 등)와 수문/펌프 제어를
/// 함께 담당하는 "한 세트"다. 큰 논은 구역별로 세트를 여러 대 둔다.
/// paddyId 는 이 세트가 담당하는 논 id.
class Device {
  const Device({
    required this.deviceId,
    required this.name,
    required this.type,
    this.paddyId,
    this.hasGate = false,
    this.hasPump = false,
    this.sensors = const [],
  });

  final String deviceId;
  final String name;

  /// set | sensor | controller 등 제품 역할.
  final String type;

  /// 연결된 논 id (미연결이면 null).
  final String? paddyId;

  /// 이 세트에 포함된 수문 제어.
  final bool hasGate;

  /// 이 세트에 포함된 펌프 제어.
  final bool hasPump;

  /// 이 세트가 측정하는 센서 목록(예: '수위', 'ORP', '토양수분').
  final List<String> sensors;

  factory Device.fromJson(Map<String, dynamic> json) => Device(
        deviceId: json['device_id'] as String,
        name: json['name'] as String,
        type: json['type'] as String? ?? 'set',
        paddyId: json['paddy_id'] as String?,
        hasGate: json['has_gate'] as bool? ?? false,
        hasPump: json['has_pump'] as bool? ?? false,
        sensors:
            (json['sensors'] as List<dynamic>? ?? const []).cast<String>(),
      );

  Device copyWith({String? paddyId}) => Device(
        deviceId: deviceId,
        name: name,
        type: type,
        paddyId: paddyId ?? this.paddyId,
        hasGate: hasGate,
        hasPump: hasPump,
        sensors: sensors,
      );

  Map<String, dynamic> toJson() => {
        'device_id': deviceId,
        'name': name,
        'type': type,
        'paddy_id': paddyId,
        'has_gate': hasGate,
        'has_pump': hasPump,
        'sensors': sensors,
      };
}

/// BLE 스캔으로 발견된 근처 장치(등록 전 후보).
class ScannedDevice {
  const ScannedDevice({
    required this.deviceId,
    required this.name,
    required this.type,
    this.hasGate = false,
    this.hasPump = false,
    this.sensors = const [],
  });

  final String deviceId;
  final String name;
  final String type;
  final bool hasGate;
  final bool hasPump;
  final List<String> sensors;
}
