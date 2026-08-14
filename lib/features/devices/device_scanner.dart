import 'dart:math';

import '../../shared/models/device.dart';

/// 주변 ESP32 장치를 발견하는 스캐너 공통 계약.
///
/// 실제 운영에서는 BLE(블루투스)로 주변 ESP32를 찾고,
/// 데모/개발에서는 [MockDeviceScanner]가 가짜 ESP 장치를 돌려준다.
abstract class DeviceScanner {
  Stream<ScannedDevice> scan({required Duration timeout});
}

/// 데모용 스캐너: 하드웨어 없이 가짜 ESP32 세트를 발견한다.
///
/// 매 스캔마다 고유한 device_id 를 부여해 등록 테스트를 반복할 수 있게 한다.
/// (실기기는 MAC 기반 고유 ID를 가진다.)
class MockDeviceScanner implements DeviceScanner {
  final _rng = Random();

  List<ScannedDevice> _nearby() {
    final n = _rng.nextInt(10000);
    return [
      ScannedDevice(
        deviceId: 'esp-demo-$n-01',
        name: 'ESP32 1구역 세트',
        type: 'set',
        hasGate: true,
        hasPump: true,
        sensors: ['수위', '수온', 'ORP', 'EC', '토양수분'],
      ),
      ScannedDevice(
        deviceId: 'esp-demo-$n-02',
        name: 'ESP32 2구역 세트',
        type: 'set',
        hasGate: true,
        hasPump: true,
        sensors: ['수위', '수온', 'ORP', 'EC', '토양수분'],
      ),
    ];
  }

  @override
  Stream<ScannedDevice> scan({required Duration timeout}) async* {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    for (final d in _nearby()) {
      yield d;
    }
  }
}
