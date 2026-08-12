import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../api/sensor_api.dart';
import '../models/app_notification.dart';
import '../models/telemetry.dart';
import '../models/twin_state.dart';

/// 백엔드(FastAPI)에 연결하는 실제 센서 데이터 소스.
///
/// JSON 계약:
///   GET  {base}/api/state/{paddyId}       -> {"telemetry": {...}, "twin": {...}}
///   GET  {base}/api/notifications         -> [ AppNotification JSON ... ]
///   POST {base}/api/control/{paddyId}     -> {"gate_open"?: bool, "pump_on"?: bool, "emergency"?: bool}
///   POST {base}/api/notifications/{id}/read
class RealApi implements SensorApi {
  RealApi({
    required this.baseUrl,
    this.pollInterval = const Duration(seconds: 3),
    http.Client? client,
  })  : _client = client ?? http.Client(),
        _baseUrl = baseUrl.replaceAll(RegExp(r'/+$'), '');

  final http.Client _client;
  final String baseUrl;
  final String _baseUrl;
  final Duration pollInterval;

  String _current = 'paddy_a';
  Timer? _pollTimer;
  bool _refreshing = false;

  final StreamController<Telemetry> _telemetryController =
      StreamController<Telemetry>.broadcast();
  final StreamController<TwinState> _twinController =
      StreamController<TwinState>.broadcast();
  final StreamController<List<AppNotification>> _notificationController =
      StreamController<List<AppNotification>>.broadcast();

  @override
  void select(String paddyId) {
    if (paddyId == _current) return;
    _current = paddyId;
    _ensurePolling();
  }

  @override
  Stream<Telemetry> telemetry() {
    _telemetryController.onListen = _ensurePolling;
    return _telemetryController.stream;
  }

  @override
  Stream<TwinState> twin() {
    _twinController.onListen = _ensurePolling;
    return _twinController.stream;
  }

  @override
  Stream<List<AppNotification>> notifications() {
    _notificationController.onListen = _ensurePolling;
    return _notificationController.stream;
  }

  void _ensurePolling() {
    if (_pollTimer != null) return;
    _pollTimer = Timer.periodic(pollInterval, (_) => _refresh());
    _refresh();
  }

  Future<void> _refresh() async {
    if (_refreshing) return;
    _refreshing = true;
    try {
      final state = await _client
          .get(Uri.parse('$_baseUrl/api/state/$_current'))
          .timeout(const Duration(seconds: 5));
      if (state.statusCode == 200) {
        final json =
            jsonDecode(utf8.decode(state.bodyBytes)) as Map<String, dynamic>;
        final telemetry =
            Telemetry.fromJson(json['telemetry'] as Map<String, dynamic>);
        final twin = TwinState.fromJson(json['twin'] as Map<String, dynamic>);
        _telemetryController.add(telemetry);
        _twinController.add(twin);
      }

      final notif = await _client
          .get(Uri.parse('$_baseUrl/api/notifications'))
          .timeout(const Duration(seconds: 5));
      if (notif.statusCode == 200) {
        final list = (jsonDecode(utf8.decode(notif.bodyBytes)) as List)
            .cast<Map<String, dynamic>>();
        _notificationController.add(
          [for (final j in list) AppNotification.fromJson(j)],
        );
      }
    } catch (_) {
      // 네트워크 오류 시 이전 상태 유지(다음 폴링에서 재시도).
    } finally {
      _refreshing = false;
    }
  }

  Future<void> _postControl(Map<String, dynamic> body) async {
    try {
      await _client
          .post(
            Uri.parse('$_baseUrl/api/control/$_current'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 5));
    } catch (_) {}
    await _refresh();
  }

  @override
  void setGateOpen(bool open) => _postControl({'gate_open': open});

  @override
  void setPumpOn(bool on) => _postControl({'pump_on': on});

  @override
  void emergencyStop() => _postControl({'emergency': true});

  @override
  void markNotificationRead(String id) {
    try {
      _client.post(
        Uri.parse('$_baseUrl/api/notifications/$id/read'),
        headers: {'Content-Type': 'application/json'},
        body: '{}',
      );
    } catch (_) {}
    _refresh();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _telemetryController.close();
    _twinController.close();
    _notificationController.close();
    _client.close();
  }
}
