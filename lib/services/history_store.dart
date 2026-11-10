import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class HistoryPoint {
  final DateTime time;
  final int level;
  final bool charging;

  HistoryPoint(this.time, this.level, this.charging);

  Map<String, dynamic> toJson() => {
        't': time.millisecondsSinceEpoch,
        'l': level,
        'c': charging ? 1 : 0,
      };

  factory HistoryPoint.fromJson(Map<String, dynamic> j) => HistoryPoint(
        DateTime.fromMillisecondsSinceEpoch(j['t'] as int),
        j['l'] as int,
        (j['c'] as int) == 1,
      );
}

/// 本地保存最近 24 小时的电量记录。
class HistoryStore {
  static const _key = 'battery_history_v1';
  static const _maxPoints = 1500;

  Future<List<HistoryPoint>> load() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_key);
    if (raw == null) return [];
    try {
      final list = (jsonDecode(raw) as List)
          .map((e) => HistoryPoint.fromJson(e as Map<String, dynamic>))
          .toList();
      return _prune(list);
    } catch (_) {
      return [];
    }
  }

  Future<List<HistoryPoint>> add(List<HistoryPoint> current, HistoryPoint p) async {
    final list = _prune([...current, p]);
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_key, jsonEncode(list.map((e) => e.toJson()).toList()));
    return list;
  }

  List<HistoryPoint> _prune(List<HistoryPoint> list) {
    final cutoff = DateTime.now().subtract(const Duration(hours: 24));
    var out = list.where((e) => e.time.isAfter(cutoff)).toList();
    if (out.length > _maxPoints) out = out.sublist(out.length - _maxPoints);
    return out;
  }
}
