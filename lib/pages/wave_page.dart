import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:myflutter/utils/bluetooth_transfer_util.dart';
import 'package:myflutter/utils/obs_host_protocol.dart';
import 'package:myflutter/utils/obs_rt_wave_parser.dart';
import 'package:myflutter/utils/obs_socket_client.dart';

/// 实时波形页（2.5）
///
/// - 左侧：X / Y / Z / HY 四路折线（[fl_chart]），自右向左滚动
/// - 右侧：清屏 / 绘图(暂停滚动) / 保存(txt) / 开始(启停 AD)
/// - 参数：垂直缩放、水平伸展、各通道零位（AppBar 设置入口）
class WavePage extends StatefulWidget {
  const WavePage({super.key});

  @override
  State<WavePage> createState() => _WavePageState();
}

class _WavePageState extends State<WavePage> {
  static const Color _bgColor = Color(0xFFEFF2F6);
  static const Color _hintTextColor = Color(0xFF9AA0A6);
  static const String _kPrefsKey = 'obs_wave_params_v1';

  static const List<String> _channelLabels = ['X向', 'Y向', 'Z向', 'HY'];
  static const List<Color> _channelColors = [
    Color(0xFF34C759),
    Color(0xFFE53935),
    Color(0xFFFFA726),
    Color(0xFF9C27B0),
  ];

  /// 可见窗口基准采样点数（越大波形越密）；实际窗口 = base / stretch
  static const int _baseWindowPoints = 480;

  /// 与设计图一致的 Y 轴刻度范围
  static const double _axisY = 150;

  final ObsSocketClient _socket = ObsSocketClient.instance;
  final BluetoothTransferUtil _bt = BluetoothTransferUtil.instance;
  final ObsRtWaveParser _parser = ObsRtWaveParser();

  StreamSubscription<Uint8List>? _wifiSub;
  StreamSubscription<Uint8List>? _btSub;
  Timer? _demoTimer;

  final List<_WaveBuffer> _buffers =
      List.generate(4, (_) => _WaveBuffer());

  /// 原始采样行，供导出 txt
  final List<String> _rawLines = [];

  bool _acquiring = false;
  bool _scrollPaused = false;
  bool _demoMode = false;
  bool _saving = false;

  double _scaleVertical = 1.0;
  double _stretchHorizontal = 1.0;
  int _zeroX = 0;
  int _zeroY = 0;
  int _zeroZ = 0;
  int _zeroHy = 0;
  int _zeroHx = 0;

  int _demoTick = 0;

  @override
  void initState() {
    super.initState();
    _wifiSub = _socket.incomingDataStream.listen(_onIncoming);
    _btSub = _bt.incomingDataStream.listen(_onIncoming);
    _loadParams();
  }

  @override
  void dispose() {
    _wifiSub?.cancel();
    _btSub?.cancel();
    _demoTimer?.cancel();
    super.dispose();
  }

  int get _windowPoints =>
      (_baseWindowPoints / _stretchHorizontal).clamp(60, 1200).round();

  List<int> get _zeros => [_zeroX, _zeroY, _zeroZ, _zeroHy];

  double _toDisplay(int channel, int raw) {
    final z = _zeros[channel];
    final v = (raw - z) * _scaleVertical / 32768.0 * _axisY;
    return v.clamp(-_axisY, _axisY);
  }

  Future<void> _loadParams() async {
    final p = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _scaleVertical = p.getDouble('${_kPrefsKey}_scaleV') ?? 1.0;
      _stretchHorizontal = p.getDouble('${_kPrefsKey}_stretchH') ?? 1.0;
      _zeroX = p.getInt('${_kPrefsKey}_zeroX') ?? 0;
      _zeroY = p.getInt('${_kPrefsKey}_zeroY') ?? 0;
      _zeroZ = p.getInt('${_kPrefsKey}_zeroZ') ?? 0;
      _zeroHy = p.getInt('${_kPrefsKey}_zeroHy') ?? 0;
      _zeroHx = p.getInt('${_kPrefsKey}_zeroHx') ?? 0;
    });
  }

  Future<void> _saveParams() async {
    final p = await SharedPreferences.getInstance();
    await p.setDouble('${_kPrefsKey}_scaleV', _scaleVertical);
    await p.setDouble('${_kPrefsKey}_stretchH', _stretchHorizontal);
    await p.setInt('${_kPrefsKey}_zeroX', _zeroX);
    await p.setInt('${_kPrefsKey}_zeroY', _zeroY);
    await p.setInt('${_kPrefsKey}_zeroZ', _zeroZ);
    await p.setInt('${_kPrefsKey}_zeroHy', _zeroHy);
    await p.setInt('${_kPrefsKey}_zeroHx', _zeroHx);
  }

  void _onIncoming(Uint8List data) {
    if (!_acquiring) return;
    final samples = _parser.push(data);
    if (samples.isEmpty) return;
    for (final s in samples) {
      _ingestSample(s, recordRaw: true);
    }
    if (mounted) setState(() {});
  }

  void _ingestSample(ObsRtSample s, {required bool recordRaw}) {
    if (recordRaw) {
      _rawLines.add(formatRtSampleLine(s));
      if (_rawLines.length > 50000) {
        _rawLines.removeRange(0, _rawLines.length - 50000);
      }
    }
    if (_scrollPaused) return;
    final vals = [
      _toDisplay(0, s.x),
      _toDisplay(1, s.y),
      _toDisplay(2, s.z),
      _toDisplay(3, s.hy != 0 ? s.hy : s.hydro),
    ];
    for (var i = 0; i < 4; i++) {
      _buffers[i].add(vals[i]);
    }
  }

  bool get _linkReady => _socket.isConnected || _bt.isConnected;

  Future<void> _sendCmd(int cmd) async {
    final frame = ObsHostProtocol.encodeCommand(cmd);
    if (_socket.isConnected) {
      await _socket.sendBytes(frame);
      return;
    }
    if (_bt.isConnected) {
      await _bt.sendBytes(frame);
      return;
    }
    throw StateError('未连接设备');
  }

  Future<void> _toggleAcquire() async {
    if (_acquiring) {
      _demoTimer?.cancel();
      _demoTimer = null;
      _demoMode = false;
      if (_linkReady) {
        try {
          await _sendCmd(ObsHostCommand.cmdStopAd);
        } catch (_) {}
      }
      setState(() => _acquiring = false);
      _toast('已停止采集');
      return;
    }

    if (_linkReady) {
      try {
        await _sendCmd(ObsHostCommand.cmdStartAd);
        setState(() => _acquiring = true);
        _toast('已下发开始采集 (CMD=0x52)');
      } catch (e) {
        _toast('开始失败：$e');
      }
      return;
    }

    setState(() {
      _acquiring = true;
      _demoMode = true;
    });
    _demoTimer?.cancel();
    _demoTimer = Timer.periodic(const Duration(milliseconds: 40), (_) {
      if (!mounted || !_acquiring || !_demoMode) return;
      _demoTick++;
      final t = _demoTick * 0.08;
      // 幅度约 12000 raw → 换算显示值 ≈ ±55（在 ±150 轴上约占 1/3，贴近真实地震数据）
      final sample = ObsRtSample(
        flag: 0,
        x: (12000 * math.sin(t * 0.7)).round() +
            (4000 * math.sin(t * 2.3 + 0.5)).round(),
        y: (10000 * math.sin(t * 0.5 + 1.2)).round() +
            (3000 * math.sin(t * 3.1 + 0.8)).round(),
        z: (9000 * math.sin(t * 0.9 + 2.4)).round() +
            (5000 * math.sin(t * 1.7 + 1.1)).round(),
        hy: (11000 * math.sin(t * 0.6 + 0.6)).round() +
            (3500 * math.sin(t * 2.8 + 0.3)).round(),
        timestampMs: DateTime.now().millisecondsSinceEpoch,
      );
      _ingestSample(sample, recordRaw: true);
      setState(() {});
    });
    _toast('未连接设备，已进入模拟波形');
  }

  void _clearScreen() {
    _parser.clear();
    for (final b in _buffers) {
      b.clear();
    }
    _rawLines.clear();
    _demoTick = 0;
    setState(() {});
    _toast('已清屏');
  }

  void _toggleScrollPause() {
    setState(() => _scrollPaused = !_scrollPaused);
    _toast(_scrollPaused ? '已暂停滚动' : '继续滚动');
  }

  Future<void> _saveTxt() async {
    if (_saving) return;
    if (_rawLines.isEmpty) {
      _toast('暂无数据可保存');
      return;
    }
    setState(() => _saving = true);
    try {
      final dir = await getApplicationDocumentsDirectory();
      final name =
          'wave_${DateTime.now().toIso8601String().replaceAll(':', '-')}.txt';
      final file = File('${dir.path}/$name');
      final header =
          '# OBS RT WAVE\nts_ms,flag,x,y,z,hy,hydro\n';
      await file.writeAsString(header + _rawLines.join('\n'));
      if (!mounted) return;
      _toast('已保存：${file.path}');
    } catch (e) {
      if (mounted) _toast('保存失败：$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _onPointerSignal(PointerSignalEvent e) {
    if (e is! PointerScrollEvent) return;
    final delta = e.scrollDelta.dy;
    if (delta == 0) return;
    setState(() {
      if (e.kind == PointerDeviceKind.mouse && e.buttons == 0) {
        // 滚轮：垂直缩放
        _scaleVertical = (_scaleVertical * (delta > 0 ? 0.92 : 1.08))
            .clamp(0.25, 4.0);
      } else {
        _stretchHorizontal =
            (_stretchHorizontal * (delta > 0 ? 0.95 : 1.05)).clamp(0.5, 4.0);
      }
    });
    _saveParams();
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _openParamsSheet() async {
    var scale = _scaleVertical;
    var stretch = _stretchHorizontal;
    var zx = _zeroX.toDouble();
    var zy = _zeroY.toDouble();
    var zz = _zeroZ.toDouble();
    var zhy = _zeroHy.toDouble();
    var zhx = _zeroHx.toDouble();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheet) {
            return Padding(
              padding: EdgeInsets.fromLTRB(20.w, 16.w, 20.w, 24.w),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '曲线参数',
                      style: TextStyle(
                        fontSize: 30.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 12.w),
                    _paramSlider(
                      '垂直缩放',
                      scale,
                      0.25,
                      4.0,
                      (v) => setSheet(() => scale = v),
                    ),
                    _paramSlider(
                      '水平伸展',
                      stretch,
                      0.5,
                      4.0,
                      (v) => setSheet(() => stretch = v),
                    ),
                    _paramSlider('X 零位', zx, -500000, 500000,
                        (v) => setSheet(() => zx = v),
                        divisions: 200),
                    _paramSlider('Y 零位', zy, -500000, 500000,
                        (v) => setSheet(() => zy = v),
                        divisions: 200),
                    _paramSlider('Z 零位', zz, -500000, 500000,
                        (v) => setSheet(() => zz = v),
                        divisions: 200),
                    _paramSlider('HY 零位', zhy, -500000, 500000,
                        (v) => setSheet(() => zhy = v),
                        divisions: 200),
                    _paramSlider('水听零位', zhx, -500000, 500000,
                        (v) => setSheet(() => zhx = v),
                        divisions: 200),
                    SizedBox(height: 16.w),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () {
                          setState(() {
                            _scaleVertical = scale;
                            _stretchHorizontal = stretch;
                            _zeroX = zx.round();
                            _zeroY = zy.round();
                            _zeroZ = zz.round();
                            _zeroHy = zhy.round();
                            _zeroHx = zhx.round();
                          });
                          _saveParams();
                          Navigator.pop(ctx);
                        },
                        child: const Text('应用'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _paramSlider(
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged, {
    int? divisions,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label：${value.toStringAsFixed(divisions == null ? 2 : 0)}',
          style: TextStyle(fontSize: 22.sp, color: Colors.black87),
        ),
        Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          divisions: divisions,
          onChanged: onChanged,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(),
            Expanded(
              child: Padding(
                padding: EdgeInsets.fromLTRB(10.w, 0, 10.w, 8.w),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: _buildChartPanel()),
                    SizedBox(width: 8.w),
                    _buildSideActions(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      height: 52.h,
      padding: EdgeInsets.symmetric(horizontal: 8.w),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              padding: EdgeInsets.zero,
              splashRadius: 22,
              onPressed: () {
                if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                }
              },
              icon: Icon(
                Icons.arrow_back_ios_new,
                size: 32.sp,
                color: Colors.black87,
              ),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '实时波形',
                style: TextStyle(
                  fontSize: 28.sp,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
              if (_demoMode)
                Text(
                  '模拟数据',
                  style: TextStyle(fontSize: 16.sp, color: _hintTextColor),
                ),
            ],
          ),
          Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              tooltip: '曲线参数',
              onPressed: _openParamsSheet,
              icon: Icon(Icons.tune, size: 30.sp, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartPanel() {
    final window = _windowPoints;
    final maxX = window.toDouble();

    return Listener(
      onPointerSignal: _onPointerSignal,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8.r),
          border: Border.all(color: const Color(0xFF333333), width: 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Column(
                children: [
                  for (var i = 0; i < 4; i++)
                    Expanded(
                      child: _buildChartCell(
                        index: i,
                        window: window,
                        maxX: maxX,
                        showBottomAxis: true,
                        showTopBorder: i == 0,
                      ),
                    ),
                ],
              ),
            ),
            _buildLegendColumn(window),
          ],
        ),
      ),
    );
  }

  Widget _buildChartCell({
    required int index,
    required int window,
    required double maxX,
    required bool showBottomAxis,
    required bool showTopBorder,
  }) {
    final buf = _buffers[index];
    final spots = buf.spotsForWindow(window);
    final color = _channelColors[index];

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          top: showTopBorder
              ? BorderSide.none
              : const BorderSide(color: Color(0xFF444444), width: 0.8),
        ),
      ),
      child: LineChart(
        _lineChartData(
          spots: spots,
          color: color,
          maxX: maxX,
          showBottomAxis: showBottomAxis,
        ),
        duration: Duration.zero,
      ),
    );
  }

  LineChartData _lineChartData({
    required List<FlSpot> spots,
    required Color color,
    required double maxX,
    required bool showBottomAxis,
  }) {
    const gridColor = Color(0xFF888888);
    final xMax = maxX > 0 ? maxX : 1.0;

    return LineChartData(
      minX: 0,
      maxX: xMax,
      minY: -_axisY,
      maxY: _axisY,
      clipData: const FlClipData.all(),
      gridData: FlGridData(
        show: true,
        drawVerticalLine: true,
        // 水平每 50 一格（-150,-100,-50,0,50,100,150 共 6 格）
        horizontalInterval: 50,
        verticalInterval: xMax / 6,
        getDrawingHorizontalLine: (_) => const FlLine(
          color: gridColor,
          strokeWidth: 0.5,
        ),
        getDrawingVerticalLine: (_) => const FlLine(
          color: gridColor,
          strokeWidth: 0.5,
        ),
      ),
      borderData: FlBorderData(
        show: true,
        border: Border.all(color: const Color(0xFF444444), width: 0.8),
      ),
      titlesData: FlTitlesData(
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 30,
            interval: 50,
            getTitlesWidget: (v, meta) {
              // 只在 -100, 0, 100 三处显示，避免太密
              if (v != -100 && v != 0 && v != 100) {
                return const SizedBox.shrink();
              }
              return SideTitleWidget(
                meta: meta,
                child: Text(
                  v.toInt().toString(),
                  style: TextStyle(
                    fontSize: 8.sp,
                    color: Colors.black54,
                    height: 1,
                  ),
                ),
              );
            },
          ),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 12,
            interval: xMax / 6,
            getTitlesWidget: (v, meta) {
              if (v == meta.min || v == meta.max) {
                return const SizedBox.shrink();
              }
              return SideTitleWidget(
                meta: meta,
                child: Text(
                  v.toInt().toString(),
                  style: TextStyle(
                    fontSize: 8.sp,
                    color: Colors.black54,
                    height: 1,
                  ),
                ),
              );
            },
          ),
        ),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      lineTouchData: const LineTouchData(enabled: false),
      lineBarsData: [
        LineChartBarData(
          spots: spots.isEmpty
              ? [const FlSpot(0, 0), FlSpot(xMax, 0)]
              : spots,
          isCurved: false,
          color: color,
          barWidth: 1,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(show: false),
        ),
      ],
    );
  }

  /// 右侧统计列：与四格图表等高对齐，紧凑排版
  Widget _buildLegendColumn(int window) {
    return Container(
      width: 76.w,
      decoration: const BoxDecoration(
        border: Border(
          left: BorderSide(color: Color(0xFF333333), width: 1),
        ),
      ),
      child: Column(
        children: [
          for (var i = 0; i < 4; i++)
            Expanded(
              child: _buildLegendCell(
                i,
                _buffers[i].statsForWindow(window),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLegendCell(
    int index,
    ({double max, double min, double range}) stats,
  ) {
    final color = _channelColors[index];
    String fmt(double v) => v.isFinite ? v.toStringAsFixed(0) : '--';

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          bottom: index < 3
              ? const BorderSide(color: Color(0xFF555555), width: 0.6)
              : BorderSide.none,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(width: 14.w, height: 2, color: color),
                SizedBox(width: 3.w),
                Text(
                  _channelLabels[index],
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                    height: 1.1,
                  ),
                ),
              ],
            ),
            Text(
              'MAX ${fmt(stats.max)}',
              style: TextStyle(fontSize: 11.sp, height: 1.15),
            ),
            Text(
              'RAN ${fmt(stats.range)}',
              style: TextStyle(fontSize: 11.sp, height: 1.15),
            ),
            Text(
              'MIN ${fmt(stats.min)}',
              style: TextStyle(fontSize: 11.sp, height: 1.15),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSideActions() {
    return SizedBox(
      width: 100.w,
      child: Column(
        children: [
          Expanded(
            child: _SideButton(
              text: '清屏',
              icon: Icons.cleaning_services_outlined,
              colors: const [Color(0xFF5B9BD5), Color(0xFF3A7BC8)],
              onTap: _clearScreen,
            ),
          ),
          SizedBox(height: 6.w),
          Expanded(
            child: _SideButton(
              text: _scrollPaused ? '继续' : '绘图',
              icon: _scrollPaused ? Icons.play_arrow : Icons.show_chart,
              colors: const [Color(0xFF34C759), Color(0xFF28A745)],
              onTap: _toggleScrollPause,
            ),
          ),
          SizedBox(height: 6.w),
          Expanded(
            child: _SideButton(
              text: '保存',
              icon: Icons.save_outlined,
              loading: _saving,
              colors: const [Color(0xFFB39DDB), Color(0xFF9575CD)],
              onTap: _saveTxt,
            ),
          ),
          SizedBox(height: 6.w),
          Expanded(
            child: _SideButton(
              text: _acquiring ? '停止' : '开始',
              icon: _acquiring ? Icons.stop : Icons.play_arrow,
              colors: const [Color(0xFFFF8A80), Color(0xFFE57373)],
              onTap: _toggleAcquire,
            ),
          ),
        ],
      ),
    );
  }
}

class _WaveBuffer {
  final List<double> _ys = [];

  void add(double y) {
    _ys.add(y);
    if (_ys.length > 6000) {
      _ys.removeRange(0, _ys.length - 6000);
    }
  }

  void clear() => _ys.clear();

  List<FlSpot> spotsForWindow(int window) {
    if (_ys.isEmpty) return const [];
    final start = math.max(0, _ys.length - window);
    final spots = <FlSpot>[];
    for (var i = start; i < _ys.length; i++) {
      spots.add(FlSpot((i - start).toDouble(), _ys[i]));
    }
    return spots;
  }

  ({double max, double min, double range}) statsForWindow(int window) {
    if (_ys.isEmpty) {
      return (max: 0, min: 0, range: 0);
    }
    final start = math.max(0, _ys.length - window);
    var maxV = -double.infinity;
    var minV = double.infinity;
    for (var i = start; i < _ys.length; i++) {
      final y = _ys[i];
      if (y > maxV) maxV = y;
      if (y < minV) minV = y;
    }
    return (max: maxV, min: minV, range: maxV - minV);
  }
}

class _SideButton extends StatelessWidget {
  const _SideButton({
    required this.text,
    required this.icon,
    required this.colors,
    required this.onTap,
    this.loading = false,
  });

  final String text;
  final IconData icon;
  final List<Color> colors;
  final VoidCallback onTap;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: loading ? null : onTap,
        borderRadius: BorderRadius.circular(10.r),
        child: Ink(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: colors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(10.r),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (loading)
                SizedBox(
                  width: 28.w,
                  height: 28.w,
                  child: const CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2.5,
                  ),
                )
              else
                Icon(icon, color: Colors.white, size: 28.sp),
              SizedBox(height: 4.w),
              Text(
                text,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
