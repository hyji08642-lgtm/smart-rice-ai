import 'dart:async';

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

class MockApi {
  MockApi() {
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => _emit());
    _telemetryController.onListen = _emit;
    _twinController.onListen = _emit;
  }

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
  late final Timer _timer;

  _PaddySim get _sim => _sims[_current]!;

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
  }

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
    final awdPhase = switch (s.awd) {
      AwdPhase.flooded => 'flooded',
      AwdPhase.draining => 'draining',
      AwdPhase.dry => 'dry',
      AwdPhase.reflood => 'reflood',
    };
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

  Stream<Telemetry> telemetry() => _telemetryController.stream;

  Stream<TwinState> twin() => _twinController.stream;

  void dispose() {
    _timer.cancel();
    _telemetryController.close();
    _twinController.close();
  }
}
