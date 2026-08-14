import 'dart:convert';

import 'package:http/http.dart' as http;

import '../api/account_api.dart';
import '../models/account.dart';
import '../models/device.dart';
import '../models/paddy.dart';

/// 백엔드(FastAPI)에 연결하는 실제 계정/기기/논 데이터 소스.
class RealAccountApi implements AccountApi {
  RealAccountApi({
    required this.baseUrl,
    http.Client? client,
  })  : _client = client ?? http.Client(),
        _baseUrl = baseUrl.replaceAll(RegExp(r'/+$'), '');

  final http.Client _client;
  final String baseUrl;
  final String _baseUrl;

  String? _token;

  void setToken(String? token) => _token = token;

  Map<String, String> get _headers => _token == null
      ? {'Content-Type': 'application/json'}
      : {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_token',
        };

  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final uri = Uri.parse('$_baseUrl$path');
    final headers = _headers;
    http.Response res;
    switch (method) {
      case 'POST':
        res = await _client
            .post(uri, headers: headers, body: jsonEncode(body ?? {}))
            .timeout(const Duration(seconds: 8));
      case 'DELETE':
        res = await _client.delete(uri, headers: headers).timeout(const Duration(seconds: 8));
      case 'PATCH':
        res = await _client
            .patch(uri, headers: headers, body: jsonEncode(body ?? {}))
            .timeout(const Duration(seconds: 8));
      default:
        res = await _client.get(uri, headers: headers).timeout(const Duration(seconds: 8));
    }
    final text = utf8.decode(res.bodyBytes);
    if (res.statusCode >= 400) {
      String message = '요청이 실패했어요. (${res.statusCode})';
      try {
        final j = jsonDecode(text) as Map<String, dynamic>;
        message = (j['detail'] as String?) ?? message;
      } catch (_) {}
      throw Exception(message);
    }
    if (text.isEmpty) return {};
    final decoded = jsonDecode(text);
    return decoded is Map<String, dynamic> ? decoded : {'data': decoded};
  }

  @override
  Future<AuthSession> signup(String username, String password) async {
    final json = await _send('POST', '/api/auth/signup',
        body: {'username': username, 'password': password});
    final session = AuthSession.fromJson(json);
    _token = session.token;
    return session;
  }

  @override
  Future<AuthSession> login(String username, String password) async {
    final json = await _send('POST', '/api/auth/login',
        body: {'username': username, 'password': password});
    final session = AuthSession.fromJson(json);
    _token = session.token;
    return session;
  }

  @override
  Future<void> logout() async {
    _token = null;
  }

  @override
  Future<Account> me(String token) async {
    final json = await _send('GET', '/api/auth/me');
    return Account.fromJson(json['user'] as Map<String, dynamic>);
  }

  @override
  Future<List<Device>> listDevices() async {
    final json = await _send('GET', '/api/devices');
    final list = json['data'] as List;
    return [
      for (final d in list) Device.fromJson(d as Map<String, dynamic>),
    ];
  }

  @override
  Future<Device> registerDevice({
    required String deviceId,
    required String name,
    required String type,
  }) async {
    final json = await _send('POST', '/api/devices', body: {
      'device_id': deviceId,
      'name': name,
      'type': type,
    });
    return Device.fromJson(json);
  }

  @override
  Future<void> removeDevice(String deviceId) async {
    await _send('DELETE', '/api/devices/$deviceId');
  }

  @override
  Future<List<Paddy>> listPaddies() async {
    final json = await _send('GET', '/api/paddies');
    final list = json['data'] as List;
    return [
      for (final p in list) Paddy.fromJson(p as Map<String, dynamic>),
    ];
  }

  @override
  Future<Paddy> addPaddy({
    required String name,
    required String stage,
    required String area,
    required List<String> deviceIds,
  }) async {
    final json = await _send('POST', '/api/paddies', body: {
      'name': name,
      'stage': stage,
      'area': area,
      'device_ids': deviceIds,
    });
    return Paddy.fromJson(json);
  }

  @override
  Future<void> removePaddy(String paddyId) async {
    await _send('DELETE', '/api/paddies/$paddyId');
  }

  @override
  Future<void> setPaddyDevices(String paddyId, List<String> deviceIds) async {
    await _send('PATCH', '/api/paddies/$paddyId/devices',
        body: {'device_ids': deviceIds});
  }

  void dispose() => _client.close();
}
