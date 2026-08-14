import '../models/account.dart';
import '../models/device.dart';
import '../models/paddy.dart';

/// 계정/기기/논 관리 공통 계약.
///
/// [MockAccountApi]는 데모용으로 로컬에서 동작하고,
/// [RealAccountApi]는 백엔드(FastAPI) HTTP 로 동작한다.
abstract class AccountApi {
  Future<AuthSession> signup(String username, String password);

  Future<AuthSession> login(String username, String password);

  Future<void> logout();

  Future<Account> me(String token);

  Future<List<Device>> listDevices();

  Future<Device> registerDevice({
    required String deviceId,
    required String name,
    required String type,
  });

  Future<void> removeDevice(String deviceId);

  Future<List<Paddy>> listPaddies();

  Future<Paddy> addPaddy({
    required String name,
    required String stage,
    required String area,
    required List<String> deviceIds,
  });

  Future<void> removePaddy(String paddyId);

  Future<void> setPaddyDevices(String paddyId, List<String> deviceIds);
}
