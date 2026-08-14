/// 사용자가 등록한 ESP32 장치(제품).
///
/// BLE(블루투스)로 근처 ESP32를 발견해 등록하고, 등록 후에는 WiFi로
/// 백엔드에 데이터를 쏜다. paddyId 는 이 장치가 담당하는 논 id.
class Device {
  const Device({
    required this.deviceId,
    required this.name,
    required this.type,
    this.paddyId,
  });

  final String deviceId;
  final String name;

  /// sensor | controller 등 제품 역할.
  final String type;

  /// 연결된 논 id (미연결이면 null).
  final String? paddyId;

  factory Device.fromJson(Map<String, dynamic> json) => Device(
        deviceId: json['device_id'] as String,
        name: json['name'] as String,
        type: json['type'] as String? ?? 'sensor',
        paddyId: json['paddy_id'] as String?,
      );

  Device copyWith({String? paddyId}) => Device(
        deviceId: deviceId,
        name: name,
        type: type,
        paddyId: paddyId ?? this.paddyId,
      );
}

/// BLE 스캔으로 발견된 근처 장치(등록 전 후보).
class ScannedDevice {
  const ScannedDevice({
    required this.deviceId,
    required this.name,
    required this.type,
  });

  final String deviceId;
  final String name;
  final String type;
}
