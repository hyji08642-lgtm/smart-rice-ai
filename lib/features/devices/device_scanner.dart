import '../../shared/models/device.dart';

/// 주변 ESP32 장치를 발견하는 스캐너 공통 계약.
///
/// 실제 운영에서는 BLE(블루투스)로 주변 ESP32를 찾고,
/// 데모/개발에서는 [MockDeviceScanner]가 가짜 ESP 장치를 돌려준다.
abstract class DeviceScanner {
  Stream<ScannedDevice> scan({required Duration timeout});
}

/// 데모용 스캐너: 하드웨어 없이 가짜 ESP32 세트를 발견한다.
class MockDeviceScanner implements DeviceScanner {
  static const nearby = [
    ScannedDevice(
      deviceId: 'esp-new-01',
      name: 'ESP32 관개 세트',
      type: 'set',
      hasGate: true,
      hasPump: true,
      sensors: ['수위', '수온', 'ORP', 'EC', '토양수분'],
    ),
    ScannedDevice(
      deviceId: 'esp-new-02',
      name: 'ESP32 토양 세트',
      type: 'set',
      hasGate: true,
      hasPump: false,
      sensors: ['수위', '토양수분'],
    ),
  ];

  @override
  Stream<ScannedDevice> scan({required Duration timeout}) async* {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    for (final d in nearby) {
      yield d;
    }
  }
}
