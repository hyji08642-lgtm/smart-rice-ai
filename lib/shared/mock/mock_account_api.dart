import '../api/account_api.dart';
import '../models/account.dart';
import '../models/device.dart';
import '../models/paddy.dart';
import 'mock_data.dart';

/// 데모용 계정/기기/논 저장소. 로컬 메모리에서만 동작한다.
///
/// 데모 계정: `demo` / `demo1234` — 이 아이디로 로그인하면
/// 3개 논(A/B/C)과 기기들이 미리 연결된 상태로 시작할 수 있다.
class MockAccountApi implements AccountApi {
  MockAccountApi();

  final Map<String, String> _users = {'demo': 'demo1234'};
  AuthSession? _session;

  List<Device> _devices = [
    const Device(
      deviceId: 'esp-gate-01',
      name: '논 A 수문 제어기',
      type: 'controller',
      paddyId: 'paddy_a',
    ),
    const Device(
      deviceId: 'esp-sense-01',
      name: '논 A 수위·수온 센서',
      type: 'sensor',
      paddyId: 'paddy_a',
    ),
    const Device(
      deviceId: 'esp-sense-02',
      name: '논 A 토양·ORP 센서',
      type: 'sensor',
      paddyId: 'paddy_a',
    ),
    const Device(
      deviceId: 'esp-gate-02',
      name: '논 B 수문 제어기',
      type: 'controller',
      paddyId: 'paddy_b',
    ),
    const Device(
      deviceId: 'esp-sense-03',
      name: '논 B 센서 노드',
      type: 'sensor',
      paddyId: 'paddy_b',
    ),
  ];

  List<Paddy> _paddies = _seedPaddies();

  static List<Paddy> _seedPaddies() {
    return [
      for (final p in MockData.paddies())
        Paddy(
          id: p.id,
          name: p.name,
          stage: p.stage,
          area: p.area,
          riskScore: p.riskScore,
          deviceIds: switch (p.id) {
            'paddy_a' => ['esp-gate-01', 'esp-sense-01', 'esp-sense-02'],
            'paddy_b' => ['esp-gate-02', 'esp-sense-03'],
            _ => const <String>[],
          },
        ),
    ];
  }

  @override
  Future<AuthSession> signup(String username, String password) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final name = username.trim();
    if (name.isEmpty || _users.containsKey(name)) {
      throw Exception('이미 사용 중인 아이디예요.');
    }
    _users[name] = password;
    final user = Account(id: _users.length, username: name);
    _session = AuthSession(token: 'mock_token_$name', user: user);
    return _session!;
  }

  @override
  Future<AuthSession> login(String username, String password) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final name = username.trim();
    if (_users[name] != password) {
      throw Exception('아이디 또는 비밀번호가 달라요.');
    }
    final user = Account(id: _users.keys.toList().indexOf(name) + 1, username: name);
    _session = AuthSession(token: 'mock_token_$name', user: user);
    return _session!;
  }

  @override
  Future<void> logout() async {
    _session = null;
  }

  @override
  Future<Account> me(String token) async {
    if (_session == null) throw Exception('로그인이 필요해요.');
    return _session!.user;
  }

  @override
  Future<List<Device>> listDevices() async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    return List.unmodifiable(_devices);
  }

  @override
  Future<Device> registerDevice({
    required String deviceId,
    required String name,
    required String type,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    if (_devices.any((d) => d.deviceId == deviceId)) {
      throw Exception('이미 등록된 기기예요.');
    }
    final device = Device(deviceId: deviceId, name: name, type: type);
    _devices = [..._devices, device];
    return device;
  }

  @override
  Future<void> removeDevice(String deviceId) async {
    _devices = _devices.where((d) => d.deviceId != deviceId).toList();
    _paddies = [
      for (final p in _paddies)
        p.copyWith(deviceIds: p.deviceIds.where((id) => id != deviceId).toList()),
    ];
  }

  @override
  Future<List<Paddy>> listPaddies() async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    return List.unmodifiable(_paddies);
  }

  @override
  Future<Paddy> addPaddy({
    required String name,
    required String stage,
    required String area,
    required List<String> deviceIds,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    final paddy = Paddy(
      id: 'paddy_m${_paddies.length + 1}',
      name: name,
      stage: stage,
      area: area,
      riskScore: 0.3,
      deviceIds: deviceIds,
    );
    _paddies = [..._paddies, paddy];
    return paddy;
  }

  @override
  Future<void> removePaddy(String paddyId) async {
    _paddies = _paddies.where((p) => p.id != paddyId).toList();
  }

  @override
  Future<void> setPaddyDevices(String paddyId, List<String> deviceIds) async {
    _paddies = [
      for (final p in _paddies)
        p.id == paddyId ? p.copyWith(deviceIds: deviceIds) : p,
    ];
  }
}
