import 'dart:async';

import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/services.dart';

/// 设备热状态,对应 iOS ProcessInfo.ThermalState
enum ThermalLevel { nominal, fair, serious, critical, unknown }

class BatterySnapshot {
  final int level;
  final BatteryState state;
  final bool lowPowerMode;
  final ThermalLevel thermal;
  final DateTime time;

  const BatterySnapshot({
    required this.level,
    required this.state,
    required this.lowPowerMode,
    required this.thermal,
    required this.time,
  });

  bool get charging => state == BatteryState.charging;
  bool get full => state == BatteryState.full;
}

/// 封装电量、充电状态、低电量模式、热状态的读取。
class BatteryService {
  final Battery _battery = Battery();
  static const MethodChannel _channel = MethodChannel('battery_guard/thermal');

  Stream<BatteryState> get onStateChanged => _battery.onBatteryStateChanged;

  Future<ThermalLevel> _thermal() async {
    try {
      final int? v = await _channel.invokeMethod<int>('getThermalState');
      switch (v) {
        case 0:
          return ThermalLevel.nominal;
        case 1:
          return ThermalLevel.fair;
        case 2:
          return ThermalLevel.serious;
        case 3:
          return ThermalLevel.critical;
      }
    } catch (_) {
      // 非 iOS 或未注册原生通道时降级
    }
    return ThermalLevel.unknown;
  }

  Future<BatterySnapshot> read() async {
    final level = await _battery.batteryLevel;
    final state = await _battery.batteryState;
    bool lpm = false;
    try {
      lpm = await _battery.isInBatterySaveMode;
    } catch (_) {}
    final thermal = await _thermal();
    return BatterySnapshot(
      level: level,
      state: state,
      lowPowerMode: lpm,
      thermal: thermal,
      time: DateTime.now(),
    );
  }
}
