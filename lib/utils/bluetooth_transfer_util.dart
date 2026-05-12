import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_blue_classic/flutter_blue_classic.dart' as fbc;
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as fbp;

enum BtTransport { none, classic, ble }

class BleEndpoint {
  const BleEndpoint({
    required this.serviceUuid,
    required this.characteristicUuid,
    this.notifyCharacteristicUuid,
  });

  final String serviceUuid;
  final String characteristicUuid;
  final String? notifyCharacteristicUuid;
}

class BluetoothTransferUtil {
  BluetoothTransferUtil._();
  static final BluetoothTransferUtil instance = BluetoothTransferUtil._();

  final fbc.FlutterBlueClassic _classic = fbc.FlutterBlueClassic();

  fbc.BluetoothConnection? _classicConnection;
  fbp.BluetoothDevice? _bleDevice;
  fbp.BluetoothCharacteristic? _bleWriteChar;
  fbp.BluetoothCharacteristic? _bleNotifyChar;

  StreamSubscription<Uint8List>? _classicInputSub;
  StreamSubscription<List<int>>? _bleNotifySub;
  StreamSubscription<fbp.BluetoothConnectionState>? _bleStateSub;

  final StreamController<Uint8List> _incomingController = StreamController.broadcast();
  final StreamController<String> _linkEventController = StreamController.broadcast();
  Stream<Uint8List> get incomingDataStream => _incomingController.stream;
  Stream<String> get linkEventStream => _linkEventController.stream;

  BtTransport _currentTransport = BtTransport.none;
  BtTransport get currentTransport => _currentTransport;
  BtTransport _lastTransport = BtTransport.none;
  String? _lastClassicAddress;
  String? _lastBleId;
  BtTransport get lastTransport => _lastTransport;
  String? get lastClassicAddress => _lastClassicAddress;
  String? get lastBleId => _lastBleId;

  bool get isConnected {
    switch (_currentTransport) {
      case BtTransport.classic:
        return _classicConnection?.isConnected == true;
      case BtTransport.ble:
        return _bleDevice?.isConnected == true;
      case BtTransport.none:
        return false;
    }
  }

  Future<void> connectClassic(String address) async {

    await disconnect();
    final conn = await _classic.connect(address);
    if (conn == null) {
      throw Exception('经典蓝牙连接失败: $address');
    }

    _classicConnection = conn;
    _currentTransport = BtTransport.classic;
    _lastTransport = BtTransport.classic;
    _lastClassicAddress = address;
    _classicInputSub = conn.input?.listen((data) {
      _incomingController.add(Uint8List.fromList(data));
    }, onError: (e, s) {
      _incomingController.addError(e, s);
      _linkEventController.add('error:$e');
    }, onDone: () {
      _linkEventController.add('disconnected:classic');
      _classicConnection = null;
      _currentTransport = BtTransport.none;
    });
    _linkEventController.add('connected:classic:$address');
  }

  Future<void> connectBle({
    required fbp.BluetoothDevice device,
    required BleEndpoint endpoint,
  }) async {

    await disconnect();

    await device.connect(
      license: fbp.License.free,
      timeout: const Duration(seconds: 12),
    );
    final services = await device.discoverServices();
    final writeChar = _findChar(services, endpoint.serviceUuid, endpoint.characteristicUuid);
    if (writeChar == null) {
      throw Exception('未找到BLE写特征: ${endpoint.characteristicUuid}');
    }

    final notifyUuid = endpoint.notifyCharacteristicUuid ?? endpoint.characteristicUuid;
    final notifyChar = _findChar(services, endpoint.serviceUuid, notifyUuid);

    if (notifyChar != null && (notifyChar.properties.notify || notifyChar.properties.indicate)) {
      await notifyChar.setNotifyValue(true);
      _bleNotifySub = notifyChar.lastValueStream.listen((data) {
        _incomingController.add(Uint8List.fromList(data));
      });
    }

    _bleDevice = device;
    _bleWriteChar = writeChar;
    _bleNotifyChar = notifyChar;
    _currentTransport = BtTransport.ble;
    _lastTransport = BtTransport.ble;
    _lastBleId = device.remoteId.str;
    _bleStateSub?.cancel();
    _bleStateSub = device.connectionState.listen((state) {
      if (state == fbp.BluetoothConnectionState.disconnected) {
        _linkEventController.add('disconnected:ble:${device.remoteId.str}');
        _bleDevice = null;
        _bleWriteChar = null;
        _bleNotifyChar = null;
        _currentTransport = BtTransport.none;
      }
    });
    _linkEventController.add('connected:ble:${device.remoteId.str}');
  }

  Future<void> connectBleAuto({
    required fbp.BluetoothDevice device,
  }) async {

    await disconnect();
    await device.connect(
      license: fbp.License.free,
      timeout: const Duration(seconds: 12),
    );

    final services = await device.discoverServices();
    fbp.BluetoothCharacteristic? writeChar;
    fbp.BluetoothCharacteristic? notifyChar;

    for (final s in services) {
      for (final c in s.characteristics) {
        if (writeChar == null && (c.properties.write || c.properties.writeWithoutResponse)) {
          writeChar = c;
        }
        if (notifyChar == null && (c.properties.notify || c.properties.indicate)) {
          notifyChar = c;
        }
      }
    }

    if (writeChar == null) {
      throw Exception('未找到可写BLE特征');
    }

    if (notifyChar != null) {
      await notifyChar.setNotifyValue(true);
      _bleNotifySub = notifyChar.lastValueStream.listen((data) {
        _incomingController.add(Uint8List.fromList(data));
      });
    }

    _bleDevice = device;
    _bleWriteChar = writeChar;
    _bleNotifyChar = notifyChar;
    _currentTransport = BtTransport.ble;
    _lastTransport = BtTransport.ble;
    _lastBleId = device.remoteId.str;
    _bleStateSub?.cancel();
    _bleStateSub = device.connectionState.listen((state) {
      if (state == fbp.BluetoothConnectionState.disconnected) {
        _linkEventController.add('disconnected:ble:${device.remoteId.str}');
        _bleDevice = null;
        _bleWriteChar = null;
        _bleNotifyChar = null;
        _currentTransport = BtTransport.none;
      }
    });
    _linkEventController.add('connected:ble:${device.remoteId.str}');
  }

  Future<void> sendBytes(List<int> bytes) async {
    if (!isConnected) throw Exception('蓝牙未连接');

    switch (_currentTransport) {
      case BtTransport.classic:
        final conn = _classicConnection;
        if (conn == null) throw Exception('经典蓝牙连接不存在');

        conn.output.add(Uint8List.fromList(bytes));
        break;
      case BtTransport.ble:
        final c = _bleWriteChar;
        if (c == null) throw Exception('BLE写特征不存在');

        await c.write(bytes, withoutResponse: false);
        break;
      case BtTransport.none:
        throw Exception('未选择传输通道');
    }
  }

  Future<void> sendText(String text, {Encoding encoding = utf8}) async {
    
    await sendBytes(encoding.encode(text));
  }

  Future<void> reconnectLast() async {
    switch (_lastTransport) {
      case BtTransport.classic:
        final address = _lastClassicAddress;
        if (address == null || address.isEmpty) {
          throw Exception('无上次经典蓝牙连接信息');
        }
        await connectClassic(address);
        return;
      case BtTransport.ble:
        final id = _lastBleId;
        if (id == null || id.isEmpty) {
          throw Exception('无上次BLE连接信息');
        }
        final device = await _findBleDeviceById(id);
        if (device == null) {
          throw Exception('未找到上次BLE设备: $id');
        }
        await connectBleAuto(device: device);
        return;
      case BtTransport.none:
        throw Exception('无上次蓝牙连接记录');
    }
  }

  Future<void> connectBleById(String id) async {
    final device = await _findBleDeviceById(id);
    if (device == null) {
      throw Exception('未找到BLE设备: $id');
    }
    await connectBleAuto(device: device);
  }

  Future<fbp.BluetoothDevice?> _findBleDeviceById(String id) async {
    final connected = fbp.FlutterBluePlus.connectedDevices;
    for (final d in connected) {
      if (d.remoteId.str == id) return d;
    }

    final bonded = await fbp.FlutterBluePlus.bondedDevices;
    for (final d in bonded) {
      if (d.remoteId.str == id) return d;
    }

    final completer = Completer<fbp.BluetoothDevice?>();
    late final StreamSubscription<List<fbp.ScanResult>> sub;
    sub = fbp.FlutterBluePlus.scanResults.listen((list) {
      for (final r in list) {
        if (r.device.remoteId.str == id && !completer.isCompleted) {
          completer.complete(r.device);
          break;
        }
      }
    });

    try {
      await fbp.FlutterBluePlus.startScan(timeout: const Duration(seconds: 6));
      final device = await completer.future.timeout(const Duration(seconds: 7), onTimeout: () => null);
      return device;
    } finally {
      await sub.cancel();
      await fbp.FlutterBluePlus.stopScan();
    }
  }

  Future<void> disconnect() async {
    await _classicInputSub?.cancel();
    _classicInputSub = null;
    await _bleNotifySub?.cancel();
    _bleNotifySub = null;
    await _bleStateSub?.cancel();
    _bleStateSub = null;

    if (_bleNotifyChar != null && _bleNotifyChar!.isNotifying) {
      await _bleNotifyChar!.setNotifyValue(false);
    }

    if (_bleDevice?.isConnected == true) {
      await _bleDevice!.disconnect();
    }
    _bleDevice = null;
    _bleWriteChar = null;
    _bleNotifyChar = null;

    if (_classicConnection != null) {
      await _classicConnection!.finish();
    }
    _classicConnection = null;

    _currentTransport = BtTransport.none;
    _linkEventController.add('disconnected');
  }

  Future<void> dispose() async {
    await disconnect();
    await _incomingController.close();
    await _linkEventController.close();
  }

  fbp.BluetoothCharacteristic? _findChar(
    List<fbp.BluetoothService> services,
    String serviceUuid,
    String charUuid,
  ) {
    final s = services.where((e) => e.uuid.str128.toLowerCase() == serviceUuid.toLowerCase()).toList();
    if (s.isEmpty) return null;
    for (final service in s) {
      for (final c in service.characteristics) {
        if (c.uuid.str128.toLowerCase() == charUuid.toLowerCase()) {
          return c;
        }
      }
    }
    return null;
  }
}
