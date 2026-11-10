import 'dart:async';

import 'package:battery_plus/battery_plus.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/battery_service.dart';
import '../services/history_store.dart';
import '../services/notification_service.dart';
import '../theme.dart';
import '../widgets/battery_ring.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final _service = BatteryService();
  final _store = HistoryStore();
  final _notifier = NotificationService();

  BatterySnapshot? _snap;
  List<HistoryPoint> _history = [];
  StreamSubscription<BatteryState>? _stateSub;
  Timer? _timer;

  // 提醒设置
  double _chargeLimit = 80; // 充电到该值提醒拔线
  double _lowLimit = 20; // 低于该值提醒充电
  bool _chargeAlerted = false;
  bool _lowAlerted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _boot();
  }

  Future<void> _boot() async {
    await _notifier.init();
    final sp = await SharedPreferences.getInstance();
    _chargeLimit = sp.getDouble('chargeLimit') ?? 80;
    _lowLimit = sp.getDouble('lowLimit') ?? 20;
    _history = await _store.load();
    await _refresh();
    _stateSub = _service.onStateChanged.listen((_) => _refresh());
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _refresh());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stateSub?.cancel();
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    final s = await _service.read();
    // 记录历史:最多每 60 秒一条
    if (_history.isEmpty ||
        s.time.difference(_history.last.time).inSeconds >= 60 ||
        _history.last.charging != s.charging) {
      _history = await _store
          .add(_history, HistoryPoint(s.time, s.level, s.charging));
    }
    _checkAlerts(s);
    if (mounted) setState(() => _snap = s);
  }

  void _checkAlerts(BatterySnapshot s) {
    if (s.charging && s.level >= _chargeLimit) {
      if (!_chargeAlerted) {
        _chargeAlerted = true;
        _notifier.show(1, '电量已达 ${s.level}%', '建议拔掉充电器,减少电池老化。');
      }
    } else if (!s.charging && !s.full) {
      _chargeAlerted = false;
    }

    if (!s.charging && s.level <= _lowLimit) {
      if (!_lowAlerted) {
        _lowAlerted = true;
        _notifier.show(2, '电量仅剩 ${s.level}%', '请尽快充电,或开启低电量模式。');
      }
    } else if (s.level > _lowLimit + 5) {
      _lowAlerted = false;
    }
  }

  Future<void> _saveSettings() async {
    final sp = await SharedPreferences.getInstance();
    await sp.setDouble('chargeLimit', _chargeLimit);
    await sp.setDouble('lowLimit', _lowLimit);
  }

  // ---------- 文案与建议 ----------

  String _stateText(BatterySnapshot s) {
    if (s.full) return '已充满';
    if (s.charging) return '充电中';
    return '使用电池';
  }

  List<_Tip> _tips(BatterySnapshot s) {
    final tips = <_Tip>[];
    if (s.thermal == ThermalLevel.serious || s.thermal == ThermalLevel.critical) {
      tips.add(const _Tip(Icons.thermostat_rounded, AppColors.red,
          '设备温度过高', '请停止充电、取下保护壳并避免阳光直射,高温会加速电池老化。'));
    } else if (s.thermal == ThermalLevel.fair) {
      tips.add(const _Tip(Icons.thermostat_rounded, AppColors.amber,
          '设备略有发热', '减少游戏、视频录制等高负载操作,让设备降温。'));
    }
    if (!s.lowPowerMode && s.level <= 30 && !s.charging) {
      tips.add(const _Tip(Icons.battery_saver_rounded, AppColors.amber,
          '建议开启低电量模式', '设置 > 电池 > 低电量模式,可明显延长续航。'));
    }
    if (s.charging && s.level >= _chargeLimit) {
      tips.add(const _Tip(Icons.power_off_rounded, AppColors.cyan,
          '可以拔掉充电器了', '长期保持 20%~80% 有助于延缓电池衰减。'));
    }
    if (s.level <= _lowLimit && !s.charging) {
      tips.add(const _Tip(Icons.bolt_rounded, AppColors.red,
          '电量过低', '尽快充电,避免设备自动关机。'));
    }
    tips.addAll(const [
      _Tip(Icons.brightness_6_rounded, AppColors.green, '降低屏幕亮度',
          '开启自动亮度,屏幕是最大的耗电来源之一。'),
      _Tip(Icons.refresh_rounded, AppColors.green, '关闭不必要的后台刷新',
          '设置 > 通用 > 后台 App 刷新,仅保留常用 App。'),
      _Tip(Icons.location_on_rounded, AppColors.green, '收紧定位权限',
          '把非必要 App 的定位改为"使用期间"或"永不"。'),
    ]);
    return tips;
  }

  // ---------- UI ----------

  @override
  Widget build(BuildContext context) {
    final s = _snap;
    return Scaffold(
      body: SafeArea(
        child: s == null
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _refresh,
                color: AppColors.green,
                backgroundColor: AppColors.card,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                  children: [
                    const Text('Battery Guard',
                        style: TextStyle(
                            fontSize: 26, fontWeight: FontWeight.w600)),
                    const Text('电量检测与优化',
                        style: TextStyle(color: AppColors.textSecondary)),
                    const SizedBox(height: 24),
                    Center(
                      child: BatteryRing(
                        level: s.level,
                        charging: s.charging,
                        caption: _stateText(s),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _statusRow(s),
                    const SizedBox(height: 20),
                    _chartCard(),
                    const SizedBox(height: 20),
                    _sectionTitle('省电建议'),
                    ..._tips(s).map(_tipCard),
                    const SizedBox(height: 20),
                    _sectionTitle('提醒设置'),
                    _settingsCard(),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _statusRow(BatterySnapshot s) {
    final thermal = switch (s.thermal) {
      ThermalLevel.nominal => ('正常', AppColors.green),
      ThermalLevel.fair => ('偏热', AppColors.amber),
      ThermalLevel.serious => ('过热', AppColors.red),
      ThermalLevel.critical => ('危急', AppColors.red),
      ThermalLevel.unknown => ('未知', AppColors.textSecondary),
    };
    return Row(
      children: [
        Expanded(
          child: _statusTile(
            Icons.thermostat_rounded,
            '设备温度',
            thermal.$1,
            thermal.$2,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _statusTile(
            Icons.battery_saver_rounded,
            '低电量模式',
            s.lowPowerMode ? '已开启' : '未开启',
            s.lowPowerMode ? AppColors.amber : AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _statusTile(IconData icon, String label, String value, Color color) {
    return _card(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary)),
              const SizedBox(height: 2),
              Text(value,
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600, color: color)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chartCard() {
    final spots = <FlSpot>[];
    final now = DateTime.now();
    for (final p in _history) {
      final hoursAgo = now.difference(p.time).inSeconds / 3600.0;
      spots.add(FlSpot(-hoursAgo, p.level.toDouble()));
    }
    return _card(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('近 24 小时电量',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          SizedBox(
            height: 170,
            child: spots.length < 2
                ? const Center(
                    child: Text('数据收集中,请保持 App 打开一段时间…',
                        style: TextStyle(color: AppColors.textSecondary)),
                  )
                : LineChart(
                    LineChartData(
                      minX: -24,
                      maxX: 0,
                      minY: 0,
                      maxY: 100,
                      gridData: FlGridData(
                        drawVerticalLine: false,
                        horizontalInterval: 25,
                        getDrawingHorizontalLine: (_) => const FlLine(
                            color: AppColors.cardBorder, strokeWidth: 1),
                      ),
                      borderData: FlBorderData(show: false),
                      titlesData: FlTitlesData(
                        topTitles: const AxisTitles(),
                        rightTitles: const AxisTitles(),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            interval: 25,
                            reservedSize: 34,
                            getTitlesWidget: (v, _) => Text('${v.toInt()}%',
                                style: const TextStyle(
                                    fontSize: 10,
                                    color: AppColors.textSecondary)),
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            interval: 8,
                            getTitlesWidget: (v, _) => Text(
                                v == 0 ? '现在' : '${v.toInt().abs()}h前',
                                style: const TextStyle(
                                    fontSize: 10,
                                    color: AppColors.textSecondary)),
                          ),
                        ),
                      ),
                      lineTouchData: LineTouchData(
                        touchTooltipData: LineTouchTooltipData(
                          getTooltipItems: (items) => items
                              .map((i) => LineTooltipItem(
                                  '${i.y.toInt()}%',
                                  const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600)))
                              .toList(),
                        ),
                      ),
                      lineBarsData: [
                        LineChartBarData(
                          spots: spots,
                          isCurved: true,
                          curveSmoothness: 0.2,
                          barWidth: 3,
                          dotData: const FlDotData(show: false),
                          gradient: const LinearGradient(
                              colors: [AppColors.cyan, AppColors.green]),
                          belowBarData: BarAreaData(
                            show: true,
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                AppColors.green.withOpacity(0.28),
                                AppColors.green.withOpacity(0.0),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _tipCard(_Tip t) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: _card(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: t.color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(t.icon, color: t.color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t.title,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 3),
                  Text(t.body,
                      style: const TextStyle(
                          fontSize: 13,
                          height: 1.4,
                          color: AppColors.textSecondary)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _settingsCard() {
    return _card(
      child: Column(
        children: [
          _sliderRow('充电提醒上限', _chargeLimit, 50, 100, (v) {
            setState(() => _chargeLimit = v.roundToDouble());
          }),
          _sliderRow('低电量提醒', _lowLimit, 5, 50, (v) {
            setState(() => _lowLimit = v.roundToDouble());
          }),
          const SizedBox(height: 4),
          const Text(
            '提示:iOS 会挂起后台 App,提醒仅在 App 运行期间可靠触发。',
            style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _sliderRow(String label, double value, double min, double max,
      ValueChanged<double> onChanged) {
    return Row(
      children: [
        SizedBox(
            width: 96,
            child: Text(label, style: const TextStyle(fontSize: 13))),
        Expanded(
          child: Slider(
            value: value,
            min: min,
            max: max,
            onChanged: onChanged,
            onChangeEnd: (_) {
              _chargeAlerted = false;
              _lowAlerted = false;
              _saveSettings();
            },
          ),
        ),
        SizedBox(
          width: 40,
          child: Text('${value.toInt()}%',
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }

  Widget _sectionTitle(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 10, left: 2),
        child: Text(t,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
      );

  Widget _card({required Widget child, EdgeInsets? padding}) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: child,
    );
  }
}

class _Tip {
  final IconData icon;
  final Color color;
  final String title;
  final String body;
  const _Tip(this.icon, this.color, this.title, this.body);
}
