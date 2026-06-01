import 'dart:typed_data';

import 'package:myflutter/utils/obs_host_protocol.dart';

/// 单帧实时地震采样（CMD 0x5B / 实时数据流）
class ObsRtSample {
  const ObsRtSample({
    required this.flag,
    required this.x,
    required this.y,
    required this.z,
    this.hy = 0,
    this.hydro = 0,
    required this.timestampMs,
  });

  final int flag;
  final int x;
  final int y;
  final int z;
  final int hy;
  final int hydro;
  final int timestampMs;

  List<int> get channels => [x, y, z, hy];
}

/// 从 TCP/蓝牙 字节流中拆出 0x5B 实时波形帧并解析。
///
/// 协议（与《通讯格式和通讯指令》一致）：
/// `3A` + `长度` + `5B` + `标志位(1)` + `通道1(3B)` + `通道2(3B)` + `通道3(3B)` [+ `通道4(3B)`…]
/// 每通道 3 字节小端有符号补码（与 [ObsHostProtocol._i24le] 相同）。
class ObsRtWaveParser {
  final List<int> _buf = [];

  /// 喂入任意长度字节，返回本批解析出的采样点。
  List<ObsRtSample> push(Uint8List chunk) {
    _buf.addAll(chunk);
    final out = <ObsRtSample>[];
    while (true) {
      final frame = _takeOneFrame();
      if (frame == null) break;
      if (frame.cmd != ObsHostCommand.cmdSendRtData) continue;
      final sample = _parsePayload(frame.payload);
      if (sample != null) out.add(sample);
    }
    return out;
  }

  void clear() => _buf.clear();

  ObsHostFrame? _takeOneFrame() {
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

  ObsRtSample? _parsePayload(Uint8List payload) {
    if (payload.isEmpty) return null;
    final flag = payload[0];
    return ObsRtSample(
      flag: flag,
      x: _readCh(payload, 1),
      y: _readCh(payload, 4),
      z: _readCh(payload, 7),
      hy: payload.length >= 13 ? _readCh(payload, 10) : 0,
      hydro: payload.length >= 16 ? _readCh(payload, 13) : 0,
      timestampMs: DateTime.now().millisecondsSinceEpoch,
    );
  }

  static int _readCh(Uint8List payload, int off) {
    if (off + 3 > payload.length) return 0;
    return _i24le(payload, off);
  }

  static int _i24le(Uint8List b, int i) {
    var v = b[i] | (b[i + 1] << 8) | (b[i + 2] << 16);
    if ((v & 0x800000) != 0) v -= 0x1000000;
    return v;
  }
}

/// 原始行文本，供保存 txt
String formatRtSampleLine(ObsRtSample s) {
  return '${s.timestampMs},${s.flag},${s.x},${s.y},${s.z},${s.hy},${s.hydro}';
}
