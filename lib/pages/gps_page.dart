import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:latlong2/latlong.dart';

import 'package:myflutter/utils/bluetooth_transfer_util.dart';
import 'package:myflutter/utils/obs_host_protocol.dart';
import 'package:myflutter/utils/obs_socket_client.dart';

// ===========================================================
// WGS84 → GCJ-02 坐标转换（高德/腾讯/百度等中国地图都使用 GCJ-02）
// ===========================================================
const double _gcjA = 6378245.0;
const double _gcjEe = 0.00669342162296594323;

bool _outOfChina(double lng, double lat) {
  if (lng < 72.004 || lng > 137.8347) return true;
  if (lat < 0.8293 || lat > 55.8271) return true;
  return false;
}

double _transformLatGcj(double x, double y) {
  var ret = -100.0 +
      2.0 * x +
      3.0 * y +
      0.2 * y * y +
      0.1 * x * y +
      0.2 * math.sqrt(x.abs());
  ret += (20.0 * math.sin(6.0 * x * math.pi) +
          20.0 * math.sin(2.0 * x * math.pi)) *
      2.0 /
      3.0;
  ret += (20.0 * math.sin(y * math.pi) +
          40.0 * math.sin(y / 3.0 * math.pi)) *
      2.0 /
      3.0;
  ret += (160.0 * math.sin(y / 12.0 * math.pi) +
          320.0 * math.sin(y * math.pi / 30.0)) *
      2.0 /
      3.0;
  return ret;
}

double _transformLngGcj(double x, double y) {
  var ret = 300.0 +
      x +
      2.0 * y +
      0.1 * x * x +
      0.1 * x * y +
      0.1 * math.sqrt(x.abs());
  ret += (20.0 * math.sin(6.0 * x * math.pi) +
          20.0 * math.sin(2.0 * x * math.pi)) *
      2.0 /
      3.0;
  ret += (20.0 * math.sin(x * math.pi) +
          40.0 * math.sin(x / 3.0 * math.pi)) *
      2.0 /
      3.0;
  ret += (150.0 * math.sin(x / 12.0 * math.pi) +
          300.0 * math.sin(x / 30.0 * math.pi)) *
      2.0 /
      3.0;
  return ret;
}

/// WGS84 经纬度 → GCJ-02 经纬度（用于高德地图等）
({double lat, double lng}) _wgs84ToGcj02(double lat, double lng) {
  if (_outOfChina(lng, lat)) return (lat: lat, lng: lng);
  var dLat = _transformLatGcj(lng - 105.0, lat - 35.0);
  var dLng = _transformLngGcj(lng - 105.0, lat - 35.0);
  final radLat = lat / 180.0 * math.pi;
  var magic = math.sin(radLat);
  magic = 1 - _gcjEe * magic * magic;
  final sqrtMagic = math.sqrt(magic);
  dLat = (dLat * 180.0) /
      ((_gcjA * (1 - _gcjEe)) / (magic * sqrtMagic) * math.pi);
  dLng = (dLng * 180.0) / (_gcjA / sqrtMagic * math.cos(radLat) * math.pi);
  return (lat: lat + dLat, lng: lng + dLng);
}

/// GPS 信息页
///
/// - 顶部 AppBar
/// - NMEA 语句类型单选（GGA / GLL / GSA / GSV）→ 控制原文区只显示该类型
/// - 黑色终端区：实时显示设备发送过来的 NMEA 报文（过滤后）
/// - "GPS信息"卡片：根据收到的 NMEA 报文聚合显示日期、UTC、经纬度、速度、方位角、卫星数、PDOP / HDOP
/// - 底部地图：根据最新经纬度在 OSM 兼容静态瓦片上展示位置
/// - 底部按钮：下发"开启 GPS"指令 (0x50)
class GpsPage extends StatefulWidget {
  const GpsPage({super.key});

  @override
  State<GpsPage> createState() => _GpsPageState();
}

class _GpsPageState extends State<GpsPage> {
  static const Color _bgColor = Color(0xFFEFF2F6);
  static const Color _headerStripStart = Color(0xFFFFFFFF);
  static const Color _headerStripEnd = Color(0xFFE8F1F8);
  static const Color _hintTextColor = Color(0xFF9AA0A6);
  static const Color _itemBorder = Color(0xFFE2E6EE);

  /// 支持的 NMEA 语句类型 (3 字母后缀)
  static const List<String> _types = ['GGA', 'GLL', 'GSA', 'GSV'];

  String _selectedType = 'GGA';

  /// 终端展示用：最近 80 行 NMEA 原文（过滤后）
  final List<String> _rawLines = <String>[];

  /// 用于按字节流拼装 NMEA 行
  final StringBuffer _byteBuffer = StringBuffer();

  // 解析快照（聚合所有 NMEA 报文 → 用于"GPS信息"区域展示）
  // 默认坐标为北京天安门，便于地图初次加载时可见
  _GpsAgg _agg = const _GpsAgg(
    latDeg: 39.9042,
    lngDeg: 116.4074,
  );

  // 通信订阅
  final ObsSocketClient _socket = ObsSocketClient.instance;
  final BluetoothTransferUtil _bt = BluetoothTransferUtil.instance;
  StreamSubscription<Uint8List>? _wifiSub;
  StreamSubscription<Uint8List>? _btSub;
  bool _sendingCmd = false;

  // 地图控制器：定位变化时跟随移动
  final MapController _mapController = MapController();
  final double _mapZoom = 15.0;

  @override
  void initState() {
    super.initState();
    _wifiSub = _socket.incomingDataStream.listen(_onIncoming);
    _btSub = _bt.incomingDataStream.listen(_onIncoming);
  }

  @override
  void dispose() {
    _wifiSub?.cancel();
    _btSub?.cancel();
    super.dispose();
  }

  // ===========================================================
  // 数据接收 / NMEA 解析
  // ===========================================================

  void _onIncoming(Uint8List data) {
    if (data.isEmpty) return;

    // 如果是 3A 自定义协议帧，先尝试解析 → NMEA 多半混在 payload 里
    final hostFrame = ObsHostProtocol.tryParse(data);
    if (hostFrame != null) {
      // 把 payload 当成 ASCII 拼到行缓冲
      _byteBuffer.write(_safeAscii(hostFrame.payload));
    } else {
      _byteBuffer.write(_safeAscii(data));
    }

    // 按 \r 或 \n 切行
    final raw = _byteBuffer.toString();
    final parts = raw.split(RegExp(r'[\r\n]+'));
    if (parts.isEmpty) return;

    // 最后一段可能是不完整的行，保留到下一次
    _byteBuffer
      ..clear()
      ..write(parts.removeLast());

    if (parts.isEmpty) return;

    for (final line in parts) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      _ingestLine(trimmed);
    }
    if (mounted) setState(() {});
  }

  /// 处理一行可能的 NMEA 报文
  void _ingestLine(String line) {
    // 找出 NMEA 主体（去掉首部杂字节，到换行结束）
    // 关键字：GGA, GLL, GSA, GSV, RMC, VTG, ZDA
    final type = _detectNmeaType(line);
    if (type == null) return;

    // 终端显示：按当前选择类型过滤
    if (type == _selectedType ||
        (_selectedType == 'GGA' && type == 'GGA') ||
        _selectedType == type) {
      _rawLines.insert(0, line);
      while (_rawLines.length > 80) {
        _rawLines.removeLast();
      }
    }

    // 解析（无论选中哪个类型，所有 NMEA 都用来更新 GPS 聚合信息）
    _parseAndApply(type, line);
  }

  /// 检测一行里包含的 NMEA 类型（取后 3 个字母作为标识）
  String? _detectNmeaType(String line) {
    final m = RegExp(r'([A-Z]{2})(GGA|GLL|GSA|GSV|RMC|VTG|ZDA)\b')
        .firstMatch(line.toUpperCase());
    return m?.group(2);
  }

  void _parseAndApply(String type, String line) {
    final upper = line.toUpperCase();
    // 截到 * 校验位前
    final star = upper.indexOf('*');
    final body = star >= 0 ? upper.substring(0, star) : upper;
    final parts = body.split(',');
    if (parts.length < 2) return;

    switch (type) {
      case 'GGA':
        _parseGga(parts);
        break;
      case 'GLL':
        _parseGll(parts);
        break;
      case 'GSA':
        _parseGsa(parts);
        break;
      case 'GSV':
        _parseGsv(parts);
        break;
      case 'RMC':
        _parseRmc(parts);
        break;
      case 'VTG':
        _parseVtg(parts);
        break;
      case 'ZDA':
        _parseZda(parts);
        break;
    }
  }

  /// $..GGA,time,lat,N/S,lng,E/W,fixQuality,satsUsed,HDOP,alt,M,...
  void _parseGga(List<String> p) {
    if (p.length < 10) return;
    final time = _parseUtcTime(p[1]);
    final lat = _parseLatLng(p[2], p[3]);
    final lng = _parseLatLng(p[4], p[5]);
    final satsUsed = int.tryParse(p[7]);
    final hdop = double.tryParse(p[8]);
    _agg = _agg.copyWith(
      utcTime: time,
      latDeg: lat,
      lngDeg: lng,
      satsUsed: satsUsed,
      hdop: hdop,
      hasFix: lat != null && lng != null,
    );
  }

  /// $..GLL,lat,N/S,lng,E/W,time,status,modeIndicator
  void _parseGll(List<String> p) {
    if (p.length < 6) return;
    final lat = _parseLatLng(p[1], p[2]);
    final lng = _parseLatLng(p[3], p[4]);
    final time = _parseUtcTime(p[5]);
    _agg = _agg.copyWith(
      utcTime: time,
      latDeg: lat,
      lngDeg: lng,
      hasFix: lat != null && lng != null,
    );
  }

  /// $..GSA,mode,fixType,sat1..sat12,PDOP,HDOP,VDOP
  void _parseGsa(List<String> p) {
    if (p.length < 18) return;
    final pdop = double.tryParse(p[15]);
    final hdop = double.tryParse(p[16]);
    // sat ID 字段：3..14
    var satCount = 0;
    for (var i = 3; i <= 14 && i < p.length; i++) {
      if (p[i].isNotEmpty) satCount++;
    }
    _agg = _agg.copyWith(
      pdop: pdop,
      hdop: hdop,
      satsUsed: satCount > 0 ? satCount : _agg.satsUsed,
    );
  }

  /// $..GSV,totalMsgs,msgNum,satsInView,sat1info..*
  void _parseGsv(List<String> p) {
    if (p.length < 4) return;
    final totalInView = int.tryParse(p[3]);
    if (totalInView != null) {
      _agg = _agg.copyWith(satsInView: totalInView);
    }
  }

  /// $..RMC,time,status,lat,N/S,lng,E/W,speedKnots,courseDeg,date,...
  void _parseRmc(List<String> p) {
    if (p.length < 10) return;
    final time = _parseUtcDateTime(timeRaw: p[1], dateRaw: p[9]);
    final lat = _parseLatLng(p[3], p[4]);
    final lng = _parseLatLng(p[5], p[6]);
    final speedKnots = double.tryParse(p[7]);
    final course = double.tryParse(p[8]);
    _agg = _agg.copyWith(
      utcTime: time,
      latDeg: lat,
      lngDeg: lng,
      speedKnots: speedKnots,
      courseDeg: course,
      hasFix: lat != null && lng != null,
    );
  }

  /// $..VTG,courseTrue,T,courseMag,M,speedKnots,N,speedKph,K,modeIndicator
  void _parseVtg(List<String> p) {
    if (p.length < 8) return;
    final course = double.tryParse(p[1]);
    final knots = double.tryParse(p[5]);
    final kph = double.tryParse(p[7]);
    _agg = _agg.copyWith(
      courseDeg: course,
      speedKnots: knots,
      speedKph: kph,
    );
  }

  /// $..ZDA,time,day,month,year,...
  void _parseZda(List<String> p) {
    if (p.length < 5) return;
    final h = int.tryParse(_safeSub(p[1], 0, 2));
    final m = int.tryParse(_safeSub(p[1], 2, 4));
    final s = int.tryParse(_safeSub(p[1], 4, 6));
    final d = int.tryParse(p[2]);
    final mo = int.tryParse(p[3]);
    final y = int.tryParse(p[4]);
    if (y == null || mo == null || d == null) return;
    final dt = DateTime.utc(y, mo, d, h ?? 0, m ?? 0, s ?? 0);
    _agg = _agg.copyWith(utcTime: dt);
  }

  /// 把 ddmm.mmmm / dddmm.mmmm + 方向字符 → 十进制度
  double? _parseLatLng(String raw, String dir) {
    if (raw.isEmpty) return null;
    final dot = raw.indexOf('.');
    if (dot < 2) return null;
    final deg = double.tryParse(raw.substring(0, dot - 2));
    final min = double.tryParse(raw.substring(dot - 2));
    if (deg == null || min == null) return null;
    var v = deg + min / 60.0;
    final u = dir.toUpperCase();
    if (u == 'S' || u == 'W') v = -v;
    return v;
  }

  /// "HHMMSS.sss" → 当天 UTC DateTime（保留毫秒）
  DateTime? _parseUtcTime(String raw) {
    if (raw.length < 6) return null;
    final h = int.tryParse(raw.substring(0, 2));
    final m = int.tryParse(raw.substring(2, 4));
    final s = int.tryParse(raw.substring(4, 6));
    if (h == null || m == null || s == null) return null;
    final now = DateTime.now().toUtc();
    return DateTime.utc(now.year, now.month, now.day, h, m, s);
  }

  /// RMC 时间+日期合成 UTC
  DateTime? _parseUtcDateTime({
    required String timeRaw,
    required String dateRaw,
  }) {
    if (dateRaw.length < 6) return _parseUtcTime(timeRaw);
    final d = int.tryParse(dateRaw.substring(0, 2));
    final mo = int.tryParse(dateRaw.substring(2, 4));
    final yy = int.tryParse(dateRaw.substring(4, 6));
    if (d == null || mo == null || yy == null) return _parseUtcTime(timeRaw);
    final year = yy + (yy >= 70 ? 1900 : 2000);
    final h = int.tryParse(_safeSub(timeRaw, 0, 2)) ?? 0;
    final m = int.tryParse(_safeSub(timeRaw, 2, 4)) ?? 0;
    final s = int.tryParse(_safeSub(timeRaw, 4, 6)) ?? 0;
    return DateTime.utc(year, mo, d, h, m, s);
  }

  String _safeSub(String s, int a, int b) {
    if (a < 0 || b > s.length || a > b) return '';
    return s.substring(a, b);
  }

  /// 把字节当 ASCII 解释，非可打印字符替换为占位，避免影响 UTF-8 分行
  String _safeAscii(List<int> bytes) {
    final sb = StringBuffer();
    for (final b in bytes) {
      if (b == 10 || b == 13) {
        sb.writeCharCode(b);
      } else if (b >= 32 && b < 127) {
        sb.writeCharCode(b);
      } else {
        // 其它字节用空格代替，仍能保持行结构
        sb.write(' ');
      }
    }
    return sb.toString();
  }

  // ===========================================================
  // 下发指令
  // ===========================================================

  Future<void> _sendCommand() async {
    if (_sendingCmd) return;
    setState(() => _sendingCmd = true);
    try {
      final frame = ObsHostProtocol.encodeCommand(ObsHostCommand.cmdOpenGps);
      var sent = false;
      if (_socket.isConnected) {
        await _socket.sendBytes(frame);
        sent = true;
      } else if (_bt.isConnected) {
        await _bt.sendBytes(frame);
        sent = true;
      }
      if (!mounted) return;
      if (!sent) {
        _toast('请先在"通信管理"中连接 WiFi 或蓝牙');
        return;
      }
      _toast('已下发"开启 GPS"指令 (CMD=0x50)');
    } catch (e) {
      if (!mounted) return;
      _toast('指令下发失败：$e');
    } finally {
      if (mounted) {
        setState(() => _sendingCmd = false);
      }
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ===========================================================
  // UI
  // ===========================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(20.w, 8.w, 20.w, 24.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildTypeCard(),
                    SizedBox(height: 20.w),
                    _buildRawTerminal(),
                    SizedBox(height: 20.w),
                    _buildGpsInfoCard(),
                    SizedBox(height: 20.w),
                    _buildMap(),
                    SizedBox(height: 16.w),
                  ],
                ),
              ),
            ),
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      height: 88.w,
      padding: EdgeInsets.symmetric(horizontal: 16.w),
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
          Text(
            'GPS信息',
            style: TextStyle(
              fontSize: 34.sp,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeCard() {
    return _SectionCard(
      title: 'NMEA语句类型',
      child: Padding(
        padding: EdgeInsets.fromLTRB(22.w, 22.w, 22.w, 24.w),
        child: Row(
          children: _types
              .map(
                (t) => Expanded(
                  child: _CheckOption(
                    label: t,
                    selected: _selectedType == t,
                    onTap: () {
                      if (_selectedType == t) return;
                      setState(() {
                        _selectedType = t;
                        // 切换类型时清空终端，避免新旧混杂
                        _rawLines.clear();
                      });
                    },
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  Widget _buildRawTerminal() {
    return Container(
      height: 230.w,
      decoration: BoxDecoration(
        color: const Color(0xFF111319),
        borderRadius: BorderRadius.circular(8.r),
      ),
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.w),
      child: _rawLines.isEmpty
          ? Center(
              child: Text(
                '等待 $_selectedType 报文…\n请先在"通信管理"中连接设备并点击下方"下发指令"开启 GPS',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 20.sp,
                  height: 1.5,
                ),
              ),
            )
          : ListView.builder(
              padding: EdgeInsets.zero,
              reverse: false,
              itemCount: _rawLines.length,
              itemBuilder: (_, i) {
                return Padding(
                  padding: EdgeInsets.only(bottom: 4.w),
                  child: Text(
                    _rawLines[i],
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18.sp,
                      height: 1.4,
                      fontFamilyFallback: const [
                        'Menlo',
                        'Consolas',
                        'Courier New',
                        'monospace',
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildGpsInfoCard() {
    final a = _agg;
    String date = '--';
    String utcStr = '--';
    if (a.utcTime != null) {
      final t = a.utcTime!;
      date = '${t.year}/${t.month}/${t.day}';
      utcStr = '$date ${t.hour.toString().padLeft(2, '0')}:'
          '${t.minute.toString().padLeft(2, '0')}:'
          '${t.second.toString().padLeft(2, '0')}';
    }
    final lat = a.latDeg == null ? '--' : a.latDeg!.toStringAsFixed(13);
    final lng = a.lngDeg == null ? '--' : a.lngDeg!.toStringAsFixed(13);
    final speedKnots = a.speedKnots;
    final speedKph = a.speedKph ??
        (speedKnots == null ? null : speedKnots * 1.852);
    final speedLabel = (speedKnots == null && speedKph == null)
        ? '--'
        : '${(speedKnots ?? 0).toStringAsFixed(2)} 节 / '
            '${(speedKph ?? 0).toStringAsFixed(2)} km/h';
    final course = a.courseDeg == null
        ? '--'
        : '${a.courseDeg!.toStringAsFixed(2)}°';
    final satsUsed = a.satsUsed == null ? '--' : '${a.satsUsed} 颗';
    final notUsed = (a.satsInView == null || a.satsUsed == null)
        ? '--'
        : '${math.max(0, a.satsInView! - a.satsUsed!)} 颗';
    final pdop = a.pdop?.toStringAsFixed(2) ?? '--';
    final hdop = a.hdop?.toStringAsFixed(2) ?? '--';

    return _SectionCard(
      title: 'GPS信息',
      child: Padding(
        padding: EdgeInsets.fromLTRB(22.w, 16.w, 22.w, 16.w),
        child: Column(
          children: [
            _InfoRow(label: 'GFS日期:', value: date),
            _InfoRow(label: 'UTC时间:', value: utcStr),
            _InfoRow(label: '经度:', value: lng),
            _InfoRow(label: '纬度:', value: lat),
            _InfoRow(label: '速度(节):', value: speedLabel),
            _InfoRow(label: '方位角:', value: course),
            _InfoRow(label: '正在使用的卫星:', value: satsUsed),
            _InfoRow(label: '非使用的可见卫星:', value: notUsed),
            _InfoRow(label: '位置精度因子:', value: pdop),
            _InfoRow(label: '水平精度因子:', value: hdop, last: true),
          ],
        ),
      ),
    );
  }

  Widget _buildMap() {
    final lat = _agg.latDeg;
    final lng = _agg.lngDeg;
    if (lat == null || lng == null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8.r),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Container(
            color: const Color(0xFFEAEEF4),
            alignment: Alignment.center,
            child: Text(
              '暂无定位数据\n收到 GPS 数据后将在地图上显示',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _hintTextColor,
                fontSize: 22.sp,
                height: 1.5,
              ),
            ),
          ),
        ),
      );
    }
    // 设备给的是 WGS84，高德瓦片是 GCJ-02，必须转换否则会偏移 100~700m
    final gcj = _wgs84ToGcj02(lat, lng);
    final center = LatLng(gcj.lat, gcj.lng);
    return ClipRRect(
      borderRadius: BorderRadius.circular(8.r),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Stack(
          children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: center,
                initialZoom: _mapZoom,
                minZoom: 3,
                maxZoom: 20,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.pinchZoom |
                      InteractiveFlag.drag |
                      InteractiveFlag.doubleTapZoom |
                      InteractiveFlag.scrollWheelZoom,
                ),
              ),
              children: [
                // 高德矢量地图（中文标注，无需 key）
                // 用标准 256px 瓦片，配合 retinaMode 自动按设备 DPR 渲染高清
                TileLayer(
                  urlTemplate:
                      'https://wprd0{s}.is.autonavi.com/appmaptile?lang=zh_cn&size=1&scale=1&style=8&x={x}&y={y}&z={z}',
                  subdomains: const ['1', '2', '3', '4'],
                  userAgentPackageName: 'com.myflutter.gps',
                  retinaMode: RetinaMode.isHighDensity(context),
                  maxNativeZoom: 20,
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: center,
                      width: 44.w,
                      height: 44.w,
                      alignment: Alignment.topCenter,
                      child: Icon(
                        Icons.location_on,
                        color: Colors.redAccent,
                        size: 40.sp,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            // 右上角坐标徽标
            Positioned(
              right: 10.w,
              top: 10.w,
              child: Container(
                padding:
                    EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(6.r),
                ),
                child: Text(
                  '${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}',
                  style: TextStyle(color: Colors.white, fontSize: 18.sp),
                ),
              ),
            ),
            // 右下角"回到设备"按钮
            Positioned(
              right: 10.w,
              bottom: 10.w,
              child: Material(
                color: Colors.white,
                shape: const CircleBorder(),
                elevation: 2,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () =>
                      _mapController.move(center, _mapController.camera.zoom),
                  child: Padding(
                    padding: EdgeInsets.all(8.w),
                    child: Icon(
                      Icons.my_location,
                      size: 32.sp,
                      color: const Color(0xFF3F73E8),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 8.w, 20.w, 20.w),
      child: SizedBox(
        height: 96.w,
        child: InkWell(
          borderRadius: BorderRadius.circular(12.r),
          onTap: _sendingCmd ? null : _sendCommand,
          child: Ink(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6DA1FF), Color(0xFF3F73E8)],
              ),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Center(
              child: _sendingCmd
                  ? SizedBox(
                      width: 36.w,
                      height: 36.w,
                      child: const CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.navigation_outlined,
                          color: Colors.white,
                          size: 36.sp,
                        ),
                        SizedBox(width: 14.w),
                        Text(
                          '下发指令',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 30.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

// ===========================================================
// 内部聚合数据
// ===========================================================

class _GpsAgg {
  const _GpsAgg({
    this.utcTime,
    this.latDeg,
    this.lngDeg,
    this.speedKnots,
    this.speedKph,
    this.courseDeg,
    this.satsUsed,
    this.satsInView,
    this.pdop,
    this.hdop,
    this.hasFix = false,
  });

  final DateTime? utcTime;
  final double? latDeg;
  final double? lngDeg;
  final double? speedKnots;
  final double? speedKph;
  final double? courseDeg;
  final int? satsUsed;
  final int? satsInView;
  final double? pdop;
  final double? hdop;
  final bool hasFix;

  _GpsAgg copyWith({
    DateTime? utcTime,
    double? latDeg,
    double? lngDeg,
    double? speedKnots,
    double? speedKph,
    double? courseDeg,
    int? satsUsed,
    int? satsInView,
    double? pdop,
    double? hdop,
    bool? hasFix,
  }) {
    return _GpsAgg(
      utcTime: utcTime ?? this.utcTime,
      latDeg: latDeg ?? this.latDeg,
      lngDeg: lngDeg ?? this.lngDeg,
      speedKnots: speedKnots ?? this.speedKnots,
      speedKph: speedKph ?? this.speedKph,
      courseDeg: courseDeg ?? this.courseDeg,
      satsUsed: satsUsed ?? this.satsUsed,
      satsInView: satsInView ?? this.satsInView,
      pdop: pdop ?? this.pdop,
      hdop: hdop ?? this.hdop,
      hasFix: hasFix ?? this.hasFix,
    );
  }
}

// ===========================================================
// 通用 UI 内部组件
// ===========================================================

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(10.r);
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: radius),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 84.w,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  _GpsPageState._headerStripStart,
                  _GpsPageState._headerStripEnd,
                ],
              ),
            ),
            padding: EdgeInsets.symmetric(horizontal: 24.w),
            alignment: Alignment.centerLeft,
            child: Text(
              title,
              style: TextStyle(
                fontSize: 30.sp,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _CheckOption extends StatelessWidget {
  const _CheckOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  static const Color _borderUnselected = Color(0xFFB9B9B9);
  static const Color _borderSelected = Color(0xFF006DC4);
  static const Color _fillSelected = Color(0xFF006DC4);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4.r),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 6.w),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 36.w,
              height: 36.w,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4.r),
                  border: Border.all(
                    color: selected ? _borderSelected : _borderUnselected,
                    width: selected ? 1.5 : 1,
                  ),
                ),
                child: selected
                    ? Center(
                        child: Container(
                          width: 18.w,
                          height: 18.w,
                          decoration: BoxDecoration(
                            color: _fillSelected,
                            borderRadius: BorderRadius.circular(3.r),
                          ),
                        ),
                      )
                    : null,
              ),
            ),
            SizedBox(width: 10.w),
            Text(
              label,
              style: TextStyle(
                fontSize: 26.sp,
                color: Colors.black87,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    this.last = false,
  });

  final String label;
  final String value;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 14.w),
      decoration: BoxDecoration(
        border: last
            ? null
            : const Border(
                bottom: BorderSide(color: _GpsPageState._itemBorder),
              ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 24.sp,
                color: Colors.black87,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 24.sp,
              color: Colors.black54,
            ),
          ),
        ],
      ),
    );
  }
}
