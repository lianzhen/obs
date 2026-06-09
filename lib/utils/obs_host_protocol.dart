import 'dart:convert';
import 'dart:typed_data';

/// OBS 设备通讯指令码（与《通讯格式和通讯指令 v1》一致）
///
/// 帧格式：`3A` + `LEN` + `CMD` + `payload…`
/// - LEN = 1（CMD 自身）+ payload 字节数
/// - 整帧长度 = 2 + LEN
class ObsHostCommand {
  ObsHostCommand._();

  static const int frameHead = 0x3A;

  // ---------- 升级 / 配置 ----------
  /// 升级数据流（payload 首字节：0=首包，1=中间包，0xFF=末包）
  static const int cmdUpRdt = 0x20;
  /// 将数据流传递给 OBS 板
  static const int cmdCfgPut = 0x21;
  /// 仪器参数设定
  static const int cmdSetCfg = 0x5A;
  /// 保存 CFG 文件
  static const int cmdSaveCfg = 0x5F;
  /// 获取仪器参数
  static const int cmdGetCfg = 0x69;

  // ---------- 设备开关 ----------
  static const int cmdOpenGps = 0x50;
  static const int cmdCloseGps = 0x51;
  static const int cmdStartAd = 0x52;
  static const int cmdStopAd = 0x53;
  static const int cmdRdoOn = 0x54;
  static const int cmdRdoOff = 0x55;
  static const int cmdTrelOn = 0x56;
  static const int cmdTrelOff = 0x57;
  static const int cmdLgtOn = 0x58;
  static const int cmdLgtOff = 0x59;

  // ---------- 实时数据 / 时钟 / 模式 ----------
  /// 设备推送实时地震数据（SNDRTD）
  static const int cmdSendRtData = 0x5B;
  /// 停止发送实时数据（STPRTD）
  static const int cmdStopRtData = 0x5C;
  /// 兼容旧命名
  static const int cmdSTPrtData = cmdStopRtData;
  /// 初始化 RTC（SET_RTC）
  static const int cmdSetRtc = 0x5D;
  /// 兼容旧命名
  static const int cmdSendRtc = cmdSetRtc;
  /// 转换模式（MOD_CHG）
  static const int cmdModelChange = 0x5E;

  // ---------- 查询类（上位机发 3A 01 XX，下位机回带数据帧） ----------
  /// 舱内温度，回包 2B 小端，单位 0.1℃
  static const int cmdGetT = 0x60;
  /// 舱内气压，回包 2B 小端（原始值，具体单位见设备说明）
  static const int cmdGetP = 0x61;
  /// 电池电压/工作电流/充电电压，回包 6B（各 2B 小端，mV/mA）
  static const int cmdBatVolt = 0x62;
  /// 启动姿态调整
  static const int cmdAdjLevel = 0x63;
  /// 姿态信息，回包 3×3B 小端补码
  static const int cmdGetLevel = 0x64;
  /// 发送仪器状态
  static const int cmdGetStat = 0x65;
  /// 发送 RTC 值
  static const int cmdGetRtc = 0x66;
  /// 读取 RTC 钟差
  static const int cmdRtcErr = 0x67;
  /// 兼容旧命名
  static const int cmdRtcERR = cmdRtcErr;
  /// GPS 初始化时钟
  static const int cmdSynRtc = 0x68;
  /// 读电子罗盘
  static const int cmdReadCmpAS = 0x6A;
  /// 仪器状态
  static const int cmdGetStatus = 0x6B;
  /// 传感器倾角
  static const int cmdSenLvl = 0x6C;
  /// 调整电子罗盘
  static const int cmdCalCmp = 0x6D;

  // ---------- 设备主动上报（INFO） ----------
  static const int cmdGpsPos = 0x70;
  static const int cmdGpsLock = 0x71;
  static const int cmdGpsSyn = 0x72;
  static const int cmdGpsInfo = 0x73;
}

/// 一帧完整协议数据
class ObsHostFrame {
  const ObsHostFrame({
    required this.cmd,
    required this.payload,
    required this.raw,
  });

  final int cmd;
  final Uint8List payload;
  final Uint8List raw;

  String get cmdHex =>
      '0x${cmd.toRadixString(16).padLeft(2, '0').toUpperCase()}';

  String get cmdName => ObsHostProtocol.cmdName(cmd);
}

/// OBS `3A` 协议：组帧、拆帧、按 CMD 解析已知回包
class ObsHostProtocol {
  ObsHostProtocol._();

  // ============================================================
  // 组帧
  // ============================================================

  /// 组一帧「仅 CMD、无 payload」的控制/查询指令，如查仓温 `3A 01 60`
  static Uint8List encodeCommand(int cmd, {List<int> payload = const []}) {
    final len = 1 + payload.length;
    return Uint8List.fromList([
      ObsHostCommand.frameHead,
      len & 0xFF,
      cmd & 0xFF,
      ...payload,
    ]);
  }

  /// 升级数据流分包：subCmd 0=首包，1=中间，0xFF=末包
  static Uint8List encodeUpgradeChunk(
    List<int> data, {
    required int subCmd,
  }) {
    return encodeCommand(ObsHostCommand.cmdUpRdt, payload: [subCmd, ...data]);
  }

  /// CFG 数据流写入 OBS 板
  static Uint8List encodeCfgPut(List<int> data) {
    return encodeCommand(ObsHostCommand.cmdCfgPut, payload: data);
  }

  // ============================================================
  // 拆帧
  // ============================================================

  /// 从**完整一帧**字节解析；半包/粘包请用 [ObsHostFrameBuffer]
  static ObsHostFrame? tryParse(Uint8List raw) {
    if (raw.length < 3) return null;
    if (raw[0] != ObsHostCommand.frameHead) return null;
    final len = raw[1];
    final fullLen = 2 + len;
    if (len < 1 || fullLen > raw.length) return null;
    final cmd = raw[2];
    final payload = raw.sublist(3, fullLen);
    return ObsHostFrame(
      cmd: cmd,
      payload: Uint8List.fromList(payload),
      raw: Uint8List.fromList(raw.sublist(0, fullLen)),
    );
  }

  /// 解析并解码为 Map（含 cmd/cmdName/type 等）
  static Map<String, dynamic> decode(ObsHostFrame frame) {
    final base = {
      'cmd': frame.cmd,
      'cmdHex': frame.cmdHex,
      'cmdName': frame.cmdName,
      'payloadLen': frame.payload.length,
      'rawHex': _bytesToHex(frame.raw),
    };
    final body = decodeKnown(frame);
    return {...base, ...body};
  }

  /// 按 CMD 解析 payload；未知 CMD 返回 type=unknown
  static Map<String, dynamic> decodeKnown(ObsHostFrame f) {
    switch (f.cmd) {
      // ----- 文档明确格式的回包 -----
      case ObsHostCommand.cmdGetT:
        return _decodeTemp(f.payload);
      case ObsHostCommand.cmdGetP:
        return _decodePressure(f.payload);
      case ObsHostCommand.cmdBatVolt:
        return _decodeBattery(f.payload);
      case ObsHostCommand.cmdGetLevel:
        return _decodeTriChannel(f.payload, type: 'attitude', offset: 0);
      case ObsHostCommand.cmdSendRtData:
        return _decodeRtSeismic(f.payload);
      case ObsHostCommand.cmdSenLvl:
        return _decodeTriChannel(f.payload, type: 'sensor_tilt', offset: 0);

      // ----- 升级 / 配置流 -----
      case ObsHostCommand.cmdUpRdt:
        return _decodeUpgradeAck(f.payload);
      case ObsHostCommand.cmdCfgPut:
      case ObsHostCommand.cmdSetCfg:
      case ObsHostCommand.cmdGetCfg:
        return _decodeConfigPayload(f.payload, f.cmd);

      // ----- RTC / 钟差 -----
      case ObsHostCommand.cmdGetRtc:
        return _decodeRtc(f.payload);
      case ObsHostCommand.cmdRtcErr:
        return _decodeRtcErr(f.payload);
      case ObsHostCommand.cmdSetRtc:
      case ObsHostCommand.cmdSynRtc:
        return _decodeAck(f.payload, type: 'rtc_control');

      // ----- 罗盘 / 姿态调整 -----
      case ObsHostCommand.cmdReadCmpAS:
        return _decodeCompass(f.payload);
      case ObsHostCommand.cmdAdjLevel:
      case ObsHostCommand.cmdCalCmp:
        return _decodeAck(f.payload, type: 'calibration');

      // ----- 状态类 -----
      case ObsHostCommand.cmdGetStat:
      case ObsHostCommand.cmdGetStatus:
        return _decodeStatus(f.payload, f.cmd);

      // ----- GPS 主动上报 -----
      case ObsHostCommand.cmdGpsPos:
      case ObsHostCommand.cmdGpsLock:
      case ObsHostCommand.cmdGpsSyn:
      case ObsHostCommand.cmdGpsInfo:
        return _decodeGpsInfo(f.payload, f.cmd);

      // ----- 纯控制 / 应答（无固定载荷格式） -----
      case ObsHostCommand.cmdOpenGps:
      case ObsHostCommand.cmdCloseGps:
      case ObsHostCommand.cmdStartAd:
      case ObsHostCommand.cmdStopAd:
      case ObsHostCommand.cmdRdoOn:
      case ObsHostCommand.cmdRdoOff:
      case ObsHostCommand.cmdTrelOn:
      case ObsHostCommand.cmdTrelOff:
      case ObsHostCommand.cmdLgtOn:
      case ObsHostCommand.cmdLgtOff:
      case ObsHostCommand.cmdStopRtData:
      case ObsHostCommand.cmdModelChange:
      case ObsHostCommand.cmdSaveCfg:
        return _decodeAck(f.payload, type: 'control_ack');
    }

    return {
      'type': 'unknown',
      'payloadHex': _bytesToHex(f.payload),
    };
  }

  /// 指令中文名（日志 / UI 展示）
  static String cmdName(int cmd) {
    switch (cmd) {
      case ObsHostCommand.cmdUpRdt:
        return '升级数据流';
      case ObsHostCommand.cmdCfgPut:
        return 'CFG数据写入';
      case ObsHostCommand.cmdOpenGps:
        return 'GPS开';
      case ObsHostCommand.cmdCloseGps:
        return 'GPS关';
      case ObsHostCommand.cmdStartAd:
        return 'AD开';
      case ObsHostCommand.cmdStopAd:
        return 'AD关';
      case ObsHostCommand.cmdRdoOn:
        return '数传开';
      case ObsHostCommand.cmdRdoOff:
        return '数传关';
      case ObsHostCommand.cmdTrelOn:
        return '时控释放开';
      case ObsHostCommand.cmdTrelOff:
        return '时控释放关';
      case ObsHostCommand.cmdLgtOn:
        return '闪光灯开';
      case ObsHostCommand.cmdLgtOff:
        return '闪光灯关';
      case ObsHostCommand.cmdSetCfg:
        return '参数设定';
      case ObsHostCommand.cmdSendRtData:
        return '实时地震数据';
      case ObsHostCommand.cmdStopRtData:
        return '停止实时数据';
      case ObsHostCommand.cmdSetRtc:
        return '初始化RTC';
      case ObsHostCommand.cmdModelChange:
        return '转换模式';
      case ObsHostCommand.cmdSaveCfg:
        return '保存CFG';
      case ObsHostCommand.cmdGetT:
        return '舱内温度';
      case ObsHostCommand.cmdGetP:
        return '舱内气压';
      case ObsHostCommand.cmdBatVolt:
        return '电池电压';
      case ObsHostCommand.cmdAdjLevel:
        return '姿态调整';
      case ObsHostCommand.cmdGetLevel:
        return '姿态信息';
      case ObsHostCommand.cmdGetStat:
        return '仪器状态';
      case ObsHostCommand.cmdGetRtc:
        return 'RTC值';
      case ObsHostCommand.cmdRtcErr:
        return 'RTC钟差';
      case ObsHostCommand.cmdSynRtc:
        return 'GPS同步时钟';
      case ObsHostCommand.cmdGetCfg:
        return '获取参数';
      case ObsHostCommand.cmdReadCmpAS:
        return '电子罗盘';
      case ObsHostCommand.cmdGetStatus:
        return '仪器状态';
      case ObsHostCommand.cmdSenLvl:
        return '传感器倾角';
      case ObsHostCommand.cmdCalCmp:
        return '校准罗盘';
      case ObsHostCommand.cmdGpsPos:
        return 'GPS位置';
      case ObsHostCommand.cmdGpsLock:
        return 'GPS锁定';
      case ObsHostCommand.cmdGpsSyn:
        return 'GPS同步';
      case ObsHostCommand.cmdGpsInfo:
        return 'GPS信息';
      default:
        return '未知(0x${cmd.toRadixString(16).toUpperCase()})';
    }
  }

  /// 是否为设备主动推送（无需先发查询）
  static bool isDevicePushCmd(int cmd) {
    return cmd == ObsHostCommand.cmdSendRtData ||
        (cmd >= ObsHostCommand.cmdGpsPos && cmd <= ObsHostCommand.cmdGpsInfo);
  }

  /// 将解析结果映射到 [ObsStatusCenter] 可用的字段（能映射的才写入）
  static Map<String, dynamic> toStatusPatch(Map<String, dynamic> decoded) {
    final patch = <String, dynamic>{};
    switch (decoded['type']) {
      case 'temperature':
        patch['chamberTempC'] = decoded['tempC'];
        break;
      case 'pressure':
        if (decoded['pressureHpa'] != null) {
          patch['chamberPressureMpa'] = (decoded['pressureHpa'] as num) / 10000.0;
          patch['standardPressureHpa'] = decoded['pressureHpa'];
        }
        break;
      case 'battery':
        patch['mainBatteryV'] = decoded['voltageV'];
        break;
      case 'attitude':
        patch['pitchDeg'] = decoded['ch1'];
        patch['rollDeg'] = decoded['ch2'];
        patch['headingDeg'] = decoded['ch3'];
        break;
      case 'sensor_tilt':
        patch['seisPitchDeg'] = decoded['ch1'];
        patch['seisRollDeg'] = decoded['ch2'];
        break;
      case 'compass':
        if (decoded['headingDeg'] != null) {
          patch['headingDeg'] = decoded['headingDeg'];
        }
        break;
      case 'status':
        if (decoded['collecting'] != null) {
          patch['collecting'] = decoded['collecting'];
        }
        if (decoded['gpsLocked'] != null) {
          patch['gpsLocked'] = decoded['gpsLocked'];
        }
        if (decoded['dataLinkOn'] != null) {
          patch['dataLinkOn'] = decoded['dataLinkOn'];
        }
        break;
      case 'gps_info':
        if (decoded['gpsLocked'] != null) {
          patch['gpsLocked'] = decoded['gpsLocked'];
        }
        break;
      case 'rtc':
        if (decoded['rtcUtc'] != null) {
          patch['rtcUtc'] = decoded['rtcUtc'];
        }
        break;
    }
    return patch;
  }

  // ============================================================
  // 各 CMD payload 解析（私有）
  // ============================================================

  /// 0x60：2B 小端，单位 0.1℃（例 8401 → 388 → 38.8℃）
  static Map<String, dynamic> _decodeTemp(Uint8List p) {
    if (p.length < 2) {
      return {'type': 'temperature', 'error': 'payload太短'};
    }
    final raw = _u16le(p, 0);
    return {
      'type': 'temperature',
      'raw': raw,
      'tempC': raw / 10.0,
    };
  }

  /// 0x61：2B 小端（文档未给单位，暂按 0.1 hPa 解析，联调时可再改）
  static Map<String, dynamic> _decodePressure(Uint8List p) {
    if (p.length < 2) {
      return {'type': 'pressure', 'error': 'payload太短'};
    }
    final raw = _u16le(p, 0);
    return {
      'type': 'pressure',
      'raw': raw,
      'pressureHpa': raw / 10.0,
    };
  }

  /// 0x62：电压/电流/充电电压各 2B 小端（mV、mA）
  static Map<String, dynamic> _decodeBattery(Uint8List p) {
    if (p.length < 6) {
      return {'type': 'battery', 'error': 'payload太短', 'payloadLen': p.length};
    }
    final v = _u16le(p, 0);
    final i = _u16le(p, 2);
    final cv = _u16le(p, 4);
    return {
      'type': 'battery',
      'voltageRaw': v,
      'currentRaw': i,
      'chargeRaw': cv,
      'voltageV': v / 1000.0,
      'currentA': i / 1000.0,
      'chargeVoltageV': cv / 1000.0,
    };
  }

  /// 0x64 / 0x6C：3 通道 × 3B 小端补码
  static Map<String, dynamic> _decodeTriChannel(
    Uint8List p, {
    required String type,
    required int offset,
  }) {
    if (p.length < offset + 9) {
      return {
        'type': type,
        'error': 'payload太短',
        'payloadLen': p.length,
      };
    }
    return {
      'type': type,
      'ch1': _i24le(p, offset),
      'ch2': _i24le(p, offset + 3),
      'ch3': _i24le(p, offset + 6),
    };
  }

  /// 0x5B：标志位(1B) + 通道1~3(各3B)，可选第4通道
  static Map<String, dynamic> _decodeRtSeismic(Uint8List p) {
    if (p.isEmpty) {
      return {'type': 'seismic', 'error': 'payload为空'};
    }
    final flag = p[0];
    final out = <String, dynamic>{
      'type': 'seismic',
      'flag': flag,
    };
    if (p.length >= 10) {
      out['x'] = _i24le(p, 1);
      out['y'] = _i24le(p, 4);
      out['z'] = _i24le(p, 7);
      // 兼容旧字段名
      out['ch1'] = out['x'];
      out['ch2'] = out['y'];
      out['ch3'] = out['z'];
    }
    if (p.length >= 13) {
      out['hy'] = _i24le(p, 10);
    }
    if (p.length >= 16) {
      out['hydro'] = _i24le(p, 13);
    }
    return out;
  }

  static Map<String, dynamic> _decodeUpgradeAck(Uint8List p) {
    return {
      'type': 'upgrade',
      'subCmd': p.isNotEmpty ? p[0] : null,
      'dataLen': p.length > 1 ? p.length - 1 : 0,
      'payloadHex': _bytesToHex(p),
    };
  }

  static Map<String, dynamic> _decodeConfigPayload(Uint8List p, int cmd) {
    final text = _tryUtf8(p);
    Map<String, dynamic>? json;
    if (text != null) {
      try {
        final v = jsonDecode(text);
        if (v is Map<String, dynamic>) json = v;
      } catch (_) {}
    }
    return {
      'type': cmd == ObsHostCommand.cmdGetCfg ? 'config_get' : 'config_put',
      'text': text,
      'json': json,
      'payloadHex': _bytesToHex(p),
    };
  }

  /// 0x66：尝试多种 RTC 格式（4B Unix / 6B 日期时间）
  static Map<String, dynamic> _decodeRtc(Uint8List p) {
    final out = <String, dynamic>{
      'type': 'rtc',
      'payloadHex': _bytesToHex(p),
    };
    if (p.length >= 4) {
      final unix = _u32le(p, 0);
      out['unixSeconds'] = unix;
      out['rtcUtc'] = DateTime.fromMillisecondsSinceEpoch(unix * 1000, isUtc: true)
          .toIso8601String();
    }
    if (p.length >= 6) {
      final year = 2000 + p[0];
      final month = p[1];
      final day = p[2];
      final hour = p[3];
      final minute = p[4];
      final second = p[5];
      out['bcdDateTime'] =
          '$year-${_two(month)}-${_two(day)} ${_two(hour)}:${_two(minute)}:${_two(second)}';
      try {
        out['rtcUtc'] = DateTime.utc(year, month, day, hour, minute, second)
            .toIso8601String();
      } catch (_) {}
    }
    return out;
  }

  /// 0x67：钟差，优先按 2B/4B 有符号小端（秒或 0.1 秒，联调时可微调）
  static Map<String, dynamic> _decodeRtcErr(Uint8List p) {
    final out = <String, dynamic>{
      'type': 'rtc_err',
      'payloadHex': _bytesToHex(p),
    };
    if (p.length >= 2) {
      out['driftRaw16'] = _i16le(p, 0);
      out['driftSec'] = _i16le(p, 0);
    }
    if (p.length >= 4) {
      out['driftRaw32'] = _i32le(p, 0);
      out['driftSec'] = _i32le(p, 0);
    }
    return out;
  }

  /// 0x6A：电子罗盘，2B 小端按 0.1° 解析航向（设备若不同可再改）
  static Map<String, dynamic> _decodeCompass(Uint8List p) {
    final out = <String, dynamic>{
      'type': 'compass',
      'payloadHex': _bytesToHex(p),
    };
    if (p.length >= 2) {
      final raw = _u16le(p, 0);
      out['headingRaw'] = raw;
      out['headingDeg'] = raw / 10.0;
    }
    if (p.length >= 6) {
      out['ch1'] = _i24le(p, 0);
      out['ch2'] = _i24le(p, 3);
    }
    return out;
  }

  /// 0x65 / 0x6B：状态字节（文档未给位定义，先解析原始 hex + 常见 bit0~2 猜测）
  static Map<String, dynamic> _decodeStatus(Uint8List p, int cmd) {
    final out = <String, dynamic>{
      'type': 'status',
      'statusCmd': cmd,
      'payloadHex': _bytesToHex(p),
      'payloadLen': p.length,
    };
    if (p.isNotEmpty) {
      final b0 = p[0];
      // 以下为占位映射，待设备位表确认后可替换
      out['collecting'] = (b0 & 0x01) != 0;
      out['gpsLocked'] = (b0 & 0x02) != 0;
      out['dataLinkOn'] = (b0 & 0x04) != 0;
      out['statusByte0'] = b0;
    }
    final text = _tryUtf8(p);
    if (text != null && text.contains('{')) {
      try {
        final v = jsonDecode(text);
        if (v is Map<String, dynamic>) out['json'] = v;
      } catch (_) {}
    }
    return out;
  }

  /// 0x70~0x73：GPS 主动上报，短包按标志位，长包尝试 UTF-8/NMEA
  static Map<String, dynamic> _decodeGpsInfo(Uint8List p, int cmd) {
    final out = <String, dynamic>{
      'type': 'gps_info',
      'gpsCmd': cmd,
      'gpsCmdName': cmdName(cmd),
      'payloadHex': _bytesToHex(p),
    };
    if (p.length == 1) {
      out['flag'] = p[0];
      if (cmd == ObsHostCommand.cmdGpsLock) {
        out['gpsLocked'] = p[0] != 0;
      }
    }
    final text = _tryUtf8(p);
    if (text != null) {
      out['text'] = text;
      if (text.contains('\$G')) out['nmea'] = text.trim();
    }
    return out;
  }

  static Map<String, dynamic> _decodeAck(Uint8List p, {required String type}) {
    return {
      'type': type,
      'ok': p.isEmpty || p[0] == 0,
      'payloadHex': _bytesToHex(p),
      'payloadLen': p.length,
    };
  }

  // ============================================================
  // 字节工具
  // ============================================================

  static int _u16le(Uint8List b, int i) => b[i] | (b[i + 1] << 8);

  static int _u32le(Uint8List b, int i) =>
      b[i] | (b[i + 1] << 8) | (b[i + 2] << 16) | (b[i + 3] << 24);

  static int _i16le(Uint8List b, int i) {
    final v = _u16le(b, i);
    return v >= 0x8000 ? v - 0x10000 : v;
  }

  static int _i32le(Uint8List b, int i) {
    final v = _u32le(b, i);
    return v >= 0x80000000 ? v - 0x100000000 : v;
  }

  static int _i24le(Uint8List b, int i) {
    var v = b[i] | (b[i + 1] << 8) | (b[i + 2] << 16);
    if ((v & 0x800000) != 0) v -= 0x1000000;
    return v;
  }

  static String? _tryUtf8(Uint8List p) {
    if (p.isEmpty) return null;
    try {
      final s = utf8.decode(p, allowMalformed: true).trim();
      if (s.isEmpty) return null;
      // 过滤明显二进制
      final printable = s.codeUnits.where((c) => c >= 32 && c < 127).length;
      if (printable < s.length * 0.6 && !s.contains('\$G')) return null;
      return s;
    } catch (_) {
      return null;
    }
  }

  static String _bytesToHex(Uint8List b) {
    if (b.isEmpty) return '';
    return b.map((e) => e.toRadixString(16).padLeft(2, '0')).join(' ');
  }

  static String _two(int v) => v.toString().padLeft(2, '0');
}

/// 从 TCP/蓝牙 **字节流** 中连续拆出多帧 `3A` 协议包
class ObsHostFrameBuffer {
  final List<int> _buf = [];

  /// 喂入任意长度字节，返回本批解析出的完整帧
  List<ObsHostFrame> push(Uint8List chunk) {
    _buf.addAll(chunk);
    final out = <ObsHostFrame>[];
    while (true) {
      final frame = _takeOne();
      if (frame == null) break;
      out.add(frame);
    }
    return out;
  }

  void clear() => _buf.clear();

  ObsHostFrame? _takeOne() {
    var start = -1;
    for (var i = 0; i < _buf.length; i++) {
      if (_buf[i] == ObsHostCommand.frameHead) {
        start = i;
        break;
      }
    }
    if (start < 0) {
      _buf.clear();
      return null;
    }
    if (start > 0) _buf.removeRange(0, start);
    if (_buf.length < 3) return null;

    final len = _buf[1];
    final total = 2 + len;
    if (len < 1 || total > 256) {
      _buf.removeAt(0);
      return null;
    }
    if (_buf.length < total) return null;

    final raw = Uint8List.fromList(_buf.sublist(0, total));
    _buf.removeRange(0, total);
    return ObsHostProtocol.tryParse(raw);
  }
}
