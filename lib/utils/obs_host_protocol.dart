import 'dart:typed_data';

class ObsHostCommand {
  static const int frameHead = 0x3A;

  static const int cmdGetT = 0x60;
  static const int cmdGetP = 0x61;
  static const int cmdBatVolt = 0x62;
  static const int cmdOpenGps = 0x50;
  static const int cmdCloseGps = 0x51;
  static const int cmdStartAd = 0x52;
  static const int cmdStopAd = 0x53;
  static const int cmdRdoOn = 0x54;
  static const int cmdRdoOff = 0x55;
  static const int cmdLgtOn = 0x58;
  static const int cmdLgtOff = 0x59;
  static const int cmdCfgPut = 0x21;
  static const int cmdSetCfg = 0x5A;
  static const int cmdSaveCfg = 0x5F;
  static const int cmdGetLevel = 0x64;
  static const int cmdGetStat = 0x65;
  static const int cmdGetRtc = 0x66;
  static const int cmdGetCfg = 0x69;
  static const int cmdGetStatus = 0x6B;
  static const int cmdSendRtData = 0x5B;
}

class ObsHostFrame {
  const ObsHostFrame({
    required this.cmd,
    required this.payload,
    required this.raw,
  });

  final int cmd;
  final Uint8List payload;
  final Uint8List raw;
}

class ObsHostProtocol {
  static Uint8List encodeCommand(int cmd, {List<int> payload = const []}) {
    final len = 1 + payload.length;
    return Uint8List.fromList([ObsHostCommand.frameHead, len & 0xFF, cmd & 0xFF, ...payload]);
  }

  static ObsHostFrame? tryParse(Uint8List raw) {
    if (raw.length < 3) return null;
    if (raw[0] != ObsHostCommand.frameHead) return null;
    final len = raw[1];
    final fullLen = 2 + len;
    if (fullLen > raw.length || len < 1) return null;
    final cmd = raw[2];
    final payload = raw.sublist(3, fullLen);
    return ObsHostFrame(
      cmd: cmd,
      payload: Uint8List.fromList(payload),
      raw: Uint8List.fromList(raw.sublist(0, fullLen)),
    );
  }

  static Map<String, dynamic> decodeKnown(ObsHostFrame f) {
    switch (f.cmd) {
      case ObsHostCommand.cmdGetT:
        if (f.payload.length >= 2) {
          final raw = _u16le(f.payload, 0);
          return {'type': 'temperature', 'raw': raw, 'tempC': raw / 10.0};
        }
        break;
      case ObsHostCommand.cmdGetP:
        if (f.payload.length >= 2) {
          final raw = _u16le(f.payload, 0);
          return {'type': 'pressure', 'raw': raw};
        }
        break;
      case ObsHostCommand.cmdBatVolt:
        if (f.payload.length >= 6) {
          final v = _u16le(f.payload, 0);
          final i = _u16le(f.payload, 2);
          final cv = _u16le(f.payload, 4);
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
        break;
      case ObsHostCommand.cmdGetLevel:
      case ObsHostCommand.cmdSendRtData:
        if (f.payload.length >= 9) {
          final c1 = _i24le(f.payload, 0);
          final c2 = _i24le(f.payload, 3);
          final c3 = _i24le(f.payload, 6);
          return {
            'type': f.cmd == ObsHostCommand.cmdGetLevel ? 'attitude' : 'seismic',
            'ch1': c1,
            'ch2': c2,
            'ch3': c3,
          };
        }
        break;
      case ObsHostCommand.cmdGetStat:
      case ObsHostCommand.cmdGetStatus:
        return {'type': 'status', 'rawHexLen': f.payload.length};
      case ObsHostCommand.cmdGetRtc:
        return {'type': 'rtc', 'rawHexLen': f.payload.length};
    }
    return {'type': 'unknown', 'payloadLen': f.payload.length};
  }

  static int _u16le(Uint8List b, int i) => b[i] | (b[i + 1] << 8);

  static int _i24le(Uint8List b, int i) {
    var v = b[i] | (b[i + 1] << 8) | (b[i + 2] << 16);
    if ((v & 0x800000) != 0) {
      v -= 0x1000000;
    }
    return v;
  }
}
