import '../models/app_notification.dart';
import '../models/telemetry.dart';
import '../models/twin_state.dart';

/// 센서·제어 데이터 소스 공통 계약.
///
/// 실제 운영에서는 [RealApi]가 백엔드(FastAPI)에 연결되고,
/// 데모/개발에서는 [MockApi]가 AWD 사이클을 시뮬레이션한다.
/// 화면 코드는 이 인터페이스만 의존하므로 구현을 갈아끼워도
/// UI·테스트는 그대로 동작한다.
abstract class SensorApi {
  void select(String paddyId);

  Stream<Telemetry> telemetry();

  Stream<TwinState> twin();

  Stream<List<AppNotification>> notifications();

  void setGateOpen(bool open);

  void setPumpOn(bool on);

  void emergencyStop();

  void markNotificationRead(String id);

  void dispose();
}
