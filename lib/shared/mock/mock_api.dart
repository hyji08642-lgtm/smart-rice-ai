import 'dart:async';

import '../api/sensor_api.dart';
import '../models/app_notification.dart';
import '../models/telemetry.dart';
import '../models/twin_state.dart';

enum AwdPhase { flooded, draining, dry, reflood }

class _PaddySim {
  _PaddySim({
    required this.awd,
    required this.orp,
    required this.ec,
    required this.waterLevel,
    required this.soilMoisture,
    required this.waterTemp,
    required this.batterySoc,
    required this.solarV,
    required this.rssi,
    required this.gateOpen,
    required this.pumpOn,
    required this.rain3h,
    required this.sky,
    this.phaseTick = 0,
  });

  AwdPhase awd;
  int phaseTick;
  double orp;
  double ec;
  double waterLevel;
  double soilMoisture;
  double waterTemp;
  double batterySoc;
  double solarV;
  double rssi;
  bool gateOpen;
  bool pumpOn;
  bool rain3h;
  String sky;
}

class MockApi implements SensorApi {
  MockApi() {
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => _emit());
    _telemetryController.onListen = _emit;
    _twinController.onListen = _emit;
    _notificationController.onListen = _seedNotifications;
  }

  static const Map<String, String> _names = {
    'paddy_a': '논 A',
    'paddy_b': '논 B',
    'paddy_c': '논 C',
  };

  String _paddyName(String id) => _names[id] ?? '내 논';

  final Map<String, _PaddySim> _sims = {
    'paddy_a': _PaddySim(
      awd: AwdPhase.flooded,
      phaseTick: 34,
      orp: 310.2,
      ec: 1.28,
      waterLevel: 5.8,
      soilMoisture: 40.2,
      waterTemp: 26.0,
      batterySoc: 78.5,
      solarV: 18.2,
      rssi: -62,
      gateOpen: false,
      pumpOn: false,
      rain3h: false,
      sky: 'sunny',
    ),
    'paddy_b': _PaddySim(
      awd: AwdPhase.flooded,
      orp: 385.0,
      ec: 0.9,
      waterLevel: 4.2,
      soilMoisture: 48.0,
      waterTemp: 25.0,
      batterySoc: 92.0,
      solarV: 19.0,
      rssi: -58,
      gateOpen: false,
      pumpOn: false,
      rain3h: false,
      sky: 'cloudy',
    ),
    'paddy_c': _PaddySim(
      awd: AwdPhase.dry,
      phaseTick: 6,
      orp: 352.0,
      ec: 1.6,
      waterLevel: 0.1,
      soilMoisture: 24.0,
      waterTemp: 27.0,
      batterySoc: 41.0,
      solarV: 17.0,
      rssi: -70,
      gateOpen: false,
      pumpOn: false,
      rain3h: false,
      sky: 'rain',
    ),
  };

  String _current = 'paddy_a';
  int _tick = 0;

  final StreamController<Telemetry> _telemetryController =
      StreamController<Telemetry>.broadcast();
  final StreamController<TwinState> _twinController =
      StreamController<TwinState>.broadcast();
  final StreamController<List<AppNotification>> _notificationController =
      StreamController<List<AppNotification>>.broadcast();
  late final Timer _timer;

  final List<AppNotification> _notifications = [];
  int _notifSeq = 0;

  _PaddySim get _sim => _sims[_current]!;

  @override
  void select(String paddyId) {
    if (paddyId == _current) return;
    if (!_sims.containsKey(paddyId)) {
      _sims[paddyId] = _PaddySim(
        awd: AwdPhase.flooded,
        orp: 330.0,
        ec: 1.1,
        waterLevel: 5.0,
        soilMoisture: 42.0,
        waterTemp: 26.0,
        batterySoc: 70.0,
        solarV: 18.0,
        rssi: -65,
        gateOpen: false,
        pumpOn: false,
        rain3h: false,
        sky: 'sunny',
      );
    }
    _current = paddyId;
    _emit();
  }

  void _setPhase(_PaddySim s, AwdPhase phase) {
    s.awd = phase;
    s.phaseTick = 0;
    _addNotification(_phaseNotification(phase, s));
  }

  AppNotification _phaseNotification(AwdPhase phase, _PaddySim s) {
    _notifSeq++;
    final name = _paddyName(_current);
    final orp = s.orp.round();
    final wl = s.waterLevel.toStringAsFixed(1);
    return switch (phase) {
      AwdPhase.draining => AppNotification(
          id: 'awd_${_notifSeq}_drain',
          time: DateTime.now(),
          type: NotificationType.awdDrain,
          title: '$name · AWD 배수 시작',
          body: 'ORP $orp mV로 메탄 위험이 커져 수문을 열고 배수를 시작했어요.',
        ),
      AwdPhase.dry => AppNotification(
          id: 'awd_${_notifSeq}_dry',
          time: DateTime.now(),
          type: NotificationType.awdDry,
          title: '$name · 건조 단계',
          body: '수위 $wl cm로 토양이 드러났어요. ORP가 회복되고 있어요.',
        ),
      AwdPhase.reflood => AppNotification(
          id: 'awd_${_notifSeq}_reflood',
          time: DateTime.now(),
          type: NotificationType.awdReflood,
          title: '$name · 재관수 시작',
          body: '건조가 끝났어요. 펌프로 물을 채워 목표 수위 5~7cm를 맞춰요.',
        ),
      AwdPhase.flooded => AppNotification(
          id: 'awd_${_notifSeq}_flood',
          time: DateTime.now(),
          type: NotificationType.awdFlood,
          title: '$name · 담수 완료',
          body: '수위 $wl cm에 도달했어요. 다음 AWD 주기를 준비해요.',
        ),
    };
  }

  void _addNotification(AppNotification n) {
    _notifications.insert(0, n);
    if (_notifications.length > 40) _notifications.removeLast();
    _notificationController.add(List.unmodifiable(_notifications));
  }

  void _seedNotifications() {
    if (_notifications.isNotEmpty) return;
    final s = _sim;
    final name = _paddyName(_current);
    _addNotification(AppNotification(
      id: 'awd_seed_phase',
      time: DateTime.now().subtract(const Duration(minutes: 4)),
      type: switch (s.awd) {
        AwdPhase.draining => NotificationType.awdDrain,
        AwdPhase.dry => NotificationType.awdDry,
        AwdPhase.reflood => NotificationType.awdReflood,
        AwdPhase.flooded => NotificationType.awdFlood,
      },
      title: '$name · AWD ${awdPhaseShort(_phaseName(s.awd))} 중',
      body: '현재 간단관개 사이클은 "${awdPhaseShort(_phaseName(s.awd))}" 단계예요. ORP ${s.orp.round()}mV.',
    ));
    final methane = ((360.0 - s.orp) / 60.0).clamp(0.15, 0.95).toDouble();
    if (methane >= 0.6) {
      _addNotification(AppNotification(
        id: 'awd_seed_methane',
        time: DateTime.now().subtract(const Duration(minutes: 2)),
        type: NotificationType.methaneRisk,
        title: '$name · 메탄 위험',
        body: '메탄 위험도 ${methane.toStringAsFixed(2)}로 높아 AWD 배수를 판단 중이에요. ORP ${s.orp.round()}mV.',
      ));
    }
  }

  String _phaseName(AwdPhase p) => switch (p) {
        AwdPhase.flooded => 'flooded',
        AwdPhase.draining => 'draining',
        AwdPhase.dry => 'dry',
        AwdPhase.reflood => 'reflood',
      };

  @override
  void markNotificationRead(String id) {
    for (var i = 0; i < _notifications.length; i++) {
      final n = _notifications[i];
      if (n.id == id && !n.read) {
        _notifications[i] = AppNotification(
          id: n.id,
          time: n.time,
          type: n.type,
          title: n.title,
          body: n.body,
          read: true,
        );
        _notificationController.add(List.unmodifiable(_notifications));
        return;
      }
    }
  }

  @override
  void setGateOpen(bool open) {
    final s = _sim;
    s.gateOpen = open;
    if (open && s.awd != AwdPhase.draining) {
      _setPhase(s, AwdPhase.draining);
    } else if (!open && s.awd == AwdPhase.draining) {
      _setPhase(s, s.waterLevel < 0.5 ? AwdPhase.dry : AwdPhase.flooded);
    }
    _emit();
  }

  @override
  void setPumpOn(bool on) {
    final s = _sim;
    s.pumpOn = on;
    if (on && s.awd != AwdPhase.reflood) {
      _setPhase(s, AwdPhase.reflood);
    } else if (!on && s.awd == AwdPhase.reflood) {
      _setPhase(s, s.waterLevel >= 4.0 ? AwdPhase.flooded : AwdPhase.dry);
    }
    _emit();
  }

  @override
  void emergencyStop() {
    final s = _sim;
    s.pumpOn = false;
    s.gateOpen = false;
    _setPhase(s, s.waterLevel < 0.5 ? AwdPhase.dry : AwdPhase.flooded);
    _emit();
  }

  /// AWD 주기: 담수 → 배수 → 건조 → 재관수. ORP·수위가 단계별로 움직인다.
  void _advanceAwd(_PaddySim s) {
    s.phaseTick++;
    switch (s.awd) {
      case AwdPhase.flooded:
        s.gateOpen = false;
        s.pumpOn = false;
        s.orp = (s.orp - 1.2).clamp(120.0, 420.0).toDouble();
        s.waterLevel = (s.waterLevel + 0.01).clamp(4.5, 7.0).toDouble();
        if (s.orp <= 300 || s.phaseTick >= 40) _setPhase(s, AwdPhase.draining);
      case AwdPhase.draining:
        s.gateOpen = true;
        s.pumpOn = false;
        s.orp = (s.orp + 2.5).clamp(120.0, 420.0).toDouble();
        s.waterLevel = (s.waterLevel - 0.12).clamp(0.0, 9.0).toDouble();
        if (s.waterLevel <= 0.3) _setPhase(s, AwdPhase.dry);
      case AwdPhase.dry:
        s.gateOpen = false;
        s.pumpOn = false;
        s.orp = (s.orp + 0.5).clamp(120.0, 420.0).toDouble();
        s.waterLevel = 0.1;
        if (s.phaseTick >= 20) _setPhase(s, AwdPhase.reflood);
      case AwdPhase.reflood:
        s.gateOpen = false;
        s.pumpOn = true;
        s.orp = (s.orp - 0.6).clamp(120.0, 420.0).toDouble();
        s.waterLevel = (s.waterLevel + 0.10).clamp(0.0, 7.0).toDouble();
        if (s.waterLevel >= 5.5) _setPhase(s, AwdPhase.flooded);
    }
  }

  void _emit() {
    _tick++;
    final s = _sim;
    _advanceAwd(s);
    s.ec += 0.02;
    s.soilMoisture -= 0.15;
    s.waterTemp += 0.02;
    s.solarV = 18.0 + 0.5 * ((_tick * 37) % 10 - 5);
    s.rssi = -62 + (_tick % 5);
    s.batterySoc = (s.batterySoc - 0.05).clamp(20.0, 100.0).toDouble();

    final methane = ((360.0 - s.orp) / 60.0).clamp(0.15, 0.95).toDouble();
    final awdPhase = _phaseName(s.awd);
    final predictedLevel = switch (s.awd) {
      AwdPhase.draining => (s.waterLevel - 2.0).clamp(0.0, 9.0).toDouble(),
      AwdPhase.dry => s.waterLevel,
      AwdPhase.reflood => (s.waterLevel + 2.0).clamp(0.0, 9.0).toDouble(),
      AwdPhase.flooded => (s.waterLevel + 0.5).clamp(0.0, 9.0).toDouble(),
    };
    final predictedOrp = switch (s.awd) {
      AwdPhase.draining => s.orp + 20,
      AwdPhase.dry => s.orp + 10,
      AwdPhase.reflood => s.orp + 3,
      AwdPhase.flooded => s.orp - 5,
    };

    _telemetryController.add(
      Telemetry(
        paddyId: _current,
        orp: s.orp,
        ec: s.ec,
        waterLevel: s.waterLevel,
        soilMoisture: s.soilMoisture,
        waterTemp: s.waterTemp,
        batterySoc: s.batterySoc,
        solarV: s.solarV,
        gateOpen: s.gateOpen,
        pumpOn: s.pumpOn,
        rssi: s.rssi,
        methaneScore: methane,
        orpDelta1h: -10.3 + _tick * 0.2,
        rain3h: s.rain3h,
      ),
    );

    _twinController.add(
      TwinState(
        paddyId: _current,
        waterLevel: s.waterLevel,
        predictedLevel3h: predictedLevel,
        orp: s.orp,
        predictedOrp3h: predictedOrp,
        methaneScore: methane,
        gateOpen: s.gateOpen,
        pumpOn: s.pumpOn,
        weather: s.sky,
        tempC: 28.0,
        rain3h: s.rain3h,
        awdPhase: awdPhase,
      ),
    );
  }

  @override
  Stream<Telemetry> telemetry() => _telemetryController.stream;

  @override
  Stream<TwinState> twin() => _twinController.stream;

  @override
  Stream<List<AppNotification>> notifications() => _notificationController.stream;

  @override
  void dispose() {
    _timer.cancel();
    _telemetryController.close();
    _twinController.close();
    _notificationController.close();
  }
}
