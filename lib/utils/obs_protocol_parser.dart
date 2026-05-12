import 'dart:typed_data';

typedef ObsPayloadParser = Map<String, dynamic> Function(Uint8List payload);

class ObsProtocolRule {
  const ObsProtocolRule({
    required this.dataType,
    required this.parser,
  });

  final int dataType;
  final ObsPayloadParser parser;
}

class ObsFrame {
  const ObsFrame({
    required this.deviceId,
    required this.dataType,
    required this.payload,
  });

  final int deviceId;
  final int dataType;
  final Uint8List payload;
}

class ObsProtocolParser {
  
  static const int frameHead1 = 0xAA;
  static const int frameHead2 = 0x55;
  static const int frameTail1 = 0x55;
  static const int frameTail2 = 0xAA;

  final Map<int, ObsPayloadParser> _ruleMap = {};

  void registerRules(List<ObsProtocolRule> rules) {
    for (final r in rules) {
      _ruleMap[r.dataType] = r.parser;
    }
  }

  Uint8List encodeFrame({
    required int deviceId,
    required int dataType,
    required Uint8List payload,
  }) {
    final length = payload.length;
    final frame = <int>[
      frameHead1,
      frameHead2,
      deviceId & 0xFF,
      dataType & 0xFF,
      (length >> 8) & 0xFF,
      length & 0xFF,
      ...payload,
    ];
    final checksum = _xorChecksum(frame.sublist(2)); 
    frame.add(checksum);
    frame.add(frameTail1);
    frame.add(frameTail2);
    return Uint8List.fromList(frame);
  }

  ObsFrame? tryParse(Uint8List raw) {
    if (raw.length < 9) return null;
    if (raw[0] != frameHead1 || raw[1] != frameHead2) return null;
    if (raw[raw.length - 2] != frameTail1 || raw[raw.length - 1] != frameTail2) return null;

    final deviceId = raw[2];
    final dataType = raw[3];
    final length = (raw[4] << 8) | raw[5];
    final expectedLen = 2 + 1 + 1 + 2 + length + 1 + 2;
    if (expectedLen != raw.length) return null;

    final payload = raw.sublist(6, 6 + length);
    final checksum = raw[6 + length];
    final calc = _xorChecksum(raw.sublist(2, 6 + length));
    if (checksum != calc) return null;

    return ObsFrame(
      deviceId: deviceId,
      dataType: dataType,
      payload: Uint8List.fromList(payload),
    );
  }

  Map<String, dynamic> decodeToMap(Uint8List raw) {
    final frame = tryParse(raw);
    if (frame == null) {
      return {
        'ok': false,
        'error': '协议帧校验失败或格式错误',
      };
    }

    final parser = _ruleMap[frame.dataType];
    if (parser == null) {
      return {
        'ok': true,
        'deviceId': frame.deviceId,
        'dataType': frame.dataType,
        'payload': frame.payload,
        'message': '未注册该数据类型解析规则',
      };
    }

    return {
      'ok': true,
      'deviceId': frame.deviceId,
      'dataType': frame.dataType,
      'data': parser(frame.payload),
    };
  }

  int _xorChecksum(List<int> bytes) {
    var x = 0;
    for (final b in bytes) {
      x ^= (b & 0xFF);
    }
    return x & 0xFF;
  }
}
