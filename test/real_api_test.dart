import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:smart_rice_ai/shared/models/app_notification.dart';
import 'package:smart_rice_ai/shared/remote/real_api.dart';

const _state = {
  'telemetry': {
    'paddy_id': 'paddy_a',
    'orp': 310.2,
    'ec': 1.28,
    'water_level': 5.8,
    'soil_moisture': 40.2,
    'water_temp': 26.0,
    'battery_soc': 78.5,
    'solar_v': 18.2,
    'gate_open': true,
    'pump_on': false,
    'rssi': -62,
    'methane_score': 0.78,
    'orp_delta_1h': -10.3,
    'rain_3h': false,
  },
  'twin': {
    'paddy_id': 'paddy_a',
    'water_level': 5.8,
    'predicted_level_3h': 4.0,
    'orp': 310.2,
    'predicted_orp_3h': 325.0,
    'methane_score': 0.78,
    'gate_open': true,
    'pump_on': false,
    'weather': 'sunny',
    'temp_c': 28.0,
    'rain_3h': false,
    'awd_phase': 'draining',
  },
};

const _notifications = [
  {
    'id': 'paddy_a_1_awdDrain',
    'time': '2026-08-12T07:17:49+00:00',
    'type': 'awdDrain',
    'title': '논 A · AWD 배수 시작',
    'body': '배수 시작',
    'read': false,
  },
];

http.Response _json(Object body) => http.Response(
      jsonEncode(body),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

RealApi _api() {
  final client = MockClient((request) async {
    if (request.url.path.endsWith('/api/state/paddy_a')) {
      return _json(_state);
    }
    if (request.url.path.endsWith('/api/notifications')) {
      return _json(_notifications);
    }
    if (request.url.path.contains('/api/control/paddy_a') &&
        request.method == 'POST') {
      return _json({'ok': true, ..._state});
    }
    if (request.url.path.endsWith('/read') && request.method == 'POST') {
      return _json({'ok': true});
    }
    return http.Response('{}', 404);
  });
  return RealApi(baseUrl: 'http://test.local', client: client);
}

void main() {
  test('RealApi twin/telemetry parses backend contract', () async {
    final api = _api();
    addTearDown(api.dispose);

    final twin = await api.twin().first;
    expect(twin.awdPhase, 'draining');
    expect(twin.predictedLevel3h, 4.0);
    expect(twin.gateOpen, isTrue);

    final t = await api.telemetry().first;
    expect(t.orp, 310.2);
    expect(t.waterLevel, 5.8);
    expect(t.pumpOn, isFalse);
  });

  test('RealApi notifications parse types', () async {
    final api = _api();
    addTearDown(api.dispose);

    final list = await api.notifications().first;
    expect(list, hasLength(1));
    expect(list.single.type, NotificationType.awdDrain);
    expect(list.single.read, isFalse);
  });

  test('RealApi select switches paddy and control POST returns state', () async {
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/api/state/paddy_b')) {
        final state = jsonDecode(jsonEncode(_state)) as Map<String, dynamic>;
        (state['twin'] as Map<String, dynamic>)['awd_phase'] = 'dry';
        return _json(state);
      }
      if (request.url.path.contains('/api/control/paddy_b')) {
        return _json({'ok': true, 'twin': {'awd_phase': 'draining'}});
      }
      return http.Response('{}', 404);
    });
    final api = RealApi(baseUrl: 'http://test.local', client: client);
    addTearDown(api.dispose);

    api.select('paddy_b');
    final twin = await api.twin().first;
    expect(twin.awdPhase, 'dry');
  });
}