import 'dart:async';

import '../models/telemetry.dart';
import '../models/twin_state.dart';

class _PaddySim {
  _PaddySim({
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
  });

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
}

class MockApi {
  MockApi() {
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => _emit());
    _telemetryController.onListen = _emit;
    _twinController.onListen = _emit;
  }

  final Map<String, _PaddySim> _sims = {
    'paddy_a': _PaddySim(
      orp: 310.2,
      ec: 1.28,
      waterLevel: 5.8,
      soilMoisture: 40.2,
      waterTemp: 26.0,
      batterySoc: 78.5,
      solarV: 18.2,
      rssi: -62,
      gateOpen: true,
      pumpOn: true,
      rain3h: false,
    ),
    'paddy_b': _PaddySim(
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
    ),
    'paddy_c': _PaddySim(
      orp: 300.5,
      ec: 1.6,
      waterLevel: 7.1,
      soilMoisture: 35.0,
      waterTemp: 27.0,
      batterySoc: 41.0,
      solarV: 17.0,
      rssi: -70,
      gateOpen: true,
      pumpOn: false,
      rain3h: true,
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
      );
    }
    _current = paddyId;
    _emit();
  }

  void setGateOpen(bool open) {
    _sim.gateOpen = open;
    _emit();
  }

  void setPumpOn(bool on) {
    _sim.pumpOn = on;
    _emit();
  }

  void emergencyStop() {
    _sim.pumpOn = false;
    _sim.gateOpen = false;
    _emit();
  }

  void _emit() {
    _tick++;
    final s = _sim;
    s.orp += (_tick % 3 == 0) ? 0.3 : -0.4;
    s.ec += 0.02;
    s.waterLevel = (s.waterLevel + 0.1).clamp(2.0, 9.0).toDouble();
    s.soilMoisture -= 0.15;
    s.waterTemp += 0.02;
    s.solarV = 18.0 + 0.5 * ((_tick * 37) % 10 - 5);
    s.rssi = -62 + (_tick % 5);
    s.batterySoc = (s.batterySoc - 0.05).clamp(20.0, 100.0).toDouble();

    final methane = ((360.0 - s.orp) / 60.0).clamp(0.15, 0.95).toDouble();

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
        predictedLevel3h: (s.waterLevel - 1.8).clamp(1.5, 9.0).toDouble(),
        orp: s.orp,
        predictedOrp3h: s.orp + 15,
        methaneScore: methane,
        gateOpen: s.gateOpen,
        pumpOn: s.pumpOn,
        weather: s.rain3h ? 'rain' : 'sunny',
        tempC: 28.0,
        rain3h: s.rain3h,
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
