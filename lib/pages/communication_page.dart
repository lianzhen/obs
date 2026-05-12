import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:myflutter/utils/bluetooth_transfer_util.dart';
import 'package:myflutter/utils/connection_preset_store.dart';
import 'package:myflutter/utils/obs_host_protocol.dart';
import 'package:myflutter/utils/obs_protocol_parser.dart';
import 'package:myflutter/utils/obs_socket_client.dart';
import 'package:myflutter/utils/obs_status_center.dart';
import 'package:myflutter/widgets/common_widgets.dart';

class CommunicationPage extends StatefulWidget {
  const CommunicationPage({super.key});

  @override
  State<CommunicationPage> createState() => _CommunicationPageState();
}

class _CommunicationPageState extends State<CommunicationPage> {
  bool wifi = true;
  final ObsSocketClient _socket = ObsSocketClient.instance;
  final BluetoothTransferUtil _bt = BluetoothTransferUtil.instance;
  final ObsStatusCenter _statusCenter = ObsStatusCenter.instance;

  StreamSubscription<Uint8List>? _wifiSub;
  StreamSubscription<Uint8List>? _btSub;
  StreamSubscription<String>? _wifiLinkSub;
  StreamSubscription<String>? _btLinkSub;
  final List<String> _logs = <String>[];
  List<ConnectionPreset> _presets = const [];
  String? _lastWifiHost;
  int? _lastWifiPort;
  CommSettings _commSettings = const CommSettings(
    retryCount: 3,
    retryIntervalMs: 2000,
    autoReconnectEnabled: true,
  );
  bool _autoReconnectEnabled = true;
  bool _manualDisconnect = false;
  bool _reconnecting = false;
  bool _btReconnecting = false;
  Timer? _statusPollTimer;

  @override
  void initState() {
    super.initState();
    _wifiSub = _socket.incomingDataStream.listen((data) => _onRawData('WiFi', data));
    _btSub = _bt.incomingDataStream.listen((data) => _onRawData('蓝牙', data));
    _wifiLinkSub = _socket.linkEventStream.listen(_onWifiLinkEvent);
    _btLinkSub = _bt.linkEventStream.listen(_onBtLinkEvent);
    _loadPresets();
  }

  @override
  void dispose() {
    _wifiSub?.cancel();
    _btSub?.cancel();
    _wifiLinkSub?.cancel();
    _btLinkSub?.cancel();
    _statusPollTimer?.cancel();
    super.dispose();
  }

  void _appendLog(String msg) {
    setState(() {
      _logs.insert(0, msg);
      if (_logs.length > 80) {
        _logs.removeRange(80, _logs.length);
      }
    });
  }

  String _toHex(Uint8List data) {
    if (data.isEmpty) return '';
    return data.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ').toUpperCase();
  }

  void _onRawData(String source, Uint8List data) {
    if (data.isEmpty) {
      _appendLog('[$source][RX] 收到空包，已忽略');
      return;
    }
    final frame = ObsHostProtocol.tryParse(data);
    if (frame == null) {
      _appendLog('[$source][RX] len=${data.length} hex=${_toHex(data)} 非3A协议帧');
      return;
    }
    final decoded = ObsHostProtocol.decodeKnown(frame);
    _applyStatusFromDecoded(frame.cmd, decoded);
    _appendLog('[$source][RX][CMD=0x${frame.cmd.toRadixString(16).padLeft(2, '0').toUpperCase()}] ${decoded.toString()}');
  }

  void _applyStatusFromDecoded(int cmd, Map<String, dynamic> decoded) {
    switch (cmd) {
      case ObsHostCommand.cmdGetT:
        _statusCenter.updateFromMap({'chamberTempC': decoded['tempC']});
        break;
      case ObsHostCommand.cmdGetP:
        final raw = decoded['raw'];
        if (raw is num) {
          _statusCenter.updateFromMap({'chamberPressureMpa': raw / 1000.0});
        }
        break;
      case ObsHostCommand.cmdBatVolt:
        _statusCenter.updateFromMap({
          'mainBatteryV': decoded['voltageV'],
          'backupBatteryV': decoded['chargeVoltageV'],
        });
        break;
      case ObsHostCommand.cmdGetLevel:
        _statusCenter.updateFromMap({
          'pitchDeg': (decoded['ch1'] ?? 0).toDouble(),
          'rollDeg': (decoded['ch2'] ?? 0).toDouble(),
          'headingDeg': (decoded['ch3'] ?? 0).toDouble(),
        });
        break;
      case ObsHostCommand.cmdGetStat:
      case ObsHostCommand.cmdGetStatus:
        _statusCenter.updateFromMap({'dataLinkOn': true});
        break;
      default:
        break;
    }
  }

  Future<void> _loadPresets() async {
    final store = ConnectionPresetStore.instance;
    final list = await store.all();
    final settings = await store.loadCommSettings();
    if (!mounted) return;
    setState(() {
      _presets = list;
      _commSettings = settings;
      _autoReconnectEnabled = settings.autoReconnectEnabled;
    });
  }

  Future<void> _onLinkDevice() async {
    _manualDisconnect = false;
    if (wifi) {
      await _connectWifiChannel();
      _startStatusPolling();
      return;
    }
    if (_bt.isConnected) {
      _startStatusPolling();
      _appendLog('[蓝牙] 链路已可用: ${_bt.currentTransport.name}');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('蓝牙链路已可用(${_bt.currentTransport.name})')),
      );
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先在蓝牙列表里点击设备“连接”')),
      );
    }
  }

  Future<void> _onDisconnectDevice() async {
    _manualDisconnect = true;
    _stopStatusPolling();
    try {
      if (wifi) {
        await _socket.disconnect();
        _appendLog('[WiFi] 手动断开');
      } else {
        await _bt.disconnect();
        _appendLog('[蓝牙] 手动断开');
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(wifi ? 'WiFi 通道已断开' : '蓝牙通道已断开')),
      );
    } catch (e) {
      _appendLog('[DISCONNECT][ERROR] $e');
    }
  }

  void _onWifiLinkEvent(String event) {
    _appendLog('[WiFi][LINK] $event');
    if (event.startsWith('connected')) {
      _startStatusPolling();
    }
    if (event.startsWith('disconnected')) {
      _stopStatusPolling();
    }
    if (!_autoReconnectEnabled || _manualDisconnect || !event.startsWith('disconnected')) {
      return;
    }
    _tryAutoReconnectWifi();
  }

  void _onBtLinkEvent(String event) {
    _appendLog('[蓝牙][LINK] $event');
    if (event.startsWith('connected')) {
      _startStatusPolling();
    }
    if (event.startsWith('disconnected')) {
      _stopStatusPolling();
    }
    if (!_autoReconnectEnabled || _manualDisconnect || !event.startsWith('disconnected')) {
      return;
    }
    _tryAutoReconnectBluetooth();
  }

  Future<void> _tryAutoReconnectWifi() async {
    if (_reconnecting) return;
    if (_lastWifiHost == null || _lastWifiPort == null) return;
    _reconnecting = true;
    try {
      _appendLog('[WiFi] 检测到断线，开始自动重连');
      await _connectWifiWithRetry(host: _lastWifiHost!, port: _lastWifiPort!);
      _appendLog('[WiFi] 自动重连成功: ${_lastWifiHost!}:${_lastWifiPort!}');
    } catch (e) {
      _appendLog('[WiFi] 自动重连失败: $e');
    } finally {
      _reconnecting = false;
    }
  }

  Future<void> _tryAutoReconnectBluetooth() async {
    if (_btReconnecting) return;
    _btReconnecting = true;
    Object? lastError;
    try {
      _appendLog('[蓝牙] 检测到断线，开始自动重连');
      for (var i = 0; i < _commSettings.retryCount; i++) {
        try {
          await _bt.reconnectLast();
          _appendLog('[蓝牙] 自动重连成功');
          return;
        } catch (e) {
          lastError = e;
          _appendLog('[蓝牙] 第${i + 1}/${_commSettings.retryCount}次重连失败: $e');
          if (i < _commSettings.retryCount - 1) {
            await Future.delayed(Duration(milliseconds: _commSettings.retryIntervalMs));
          }
        }
      }
      _appendLog('[蓝牙] 自动重连失败: $lastError');
    } finally {
      _btReconnecting = false;
    }
  }

  Future<void> _connectWifiChannel() async {
    final ipController = TextEditingController(text: _lastWifiHost ?? '192.168.4.1');
    final portController = TextEditingController(text: (_lastWifiPort ?? 9000).toString());
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('连接 WiFi 数据通道'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: ipController, decoration: const InputDecoration(labelText: '设备IP')),
            TextField(controller: portController, decoration: const InputDecoration(labelText: '端口')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('连接')),
        ],
      ),
    );
    if (ok != true) return;
    final host = ipController.text.trim();
    final port = int.tryParse(portController.text.trim());
    if (host.isEmpty || port == null) {
      _appendLog('[WiFi] IP 或端口无效');
      return;
    }
    try {
      await _connectWifiWithRetry(host: host, port: port);
      _lastWifiHost = host;
      _lastWifiPort = port;
      _appendLog('[WiFi] 连接成功 $host:$port');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('WiFi 通道已连接: $host:$port')),
      );
    } catch (e) {
      _appendLog('[WiFi] 连接失败: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('WiFi 通道连接失败: $e')),
      );
    }
  }

  Future<void> _connectWifiWithRetry({
    required String host,
    required int port,
  }) async {
    Object? lastError;
    for (var i = 0; i < _commSettings.retryCount; i++) {
      try {
        await _socket.connect(host: host, port: port, timeout: const Duration(seconds: 3));
        return;
      } catch (e) {
        lastError = e;
        _appendLog('[WiFi] 第${i + 1}/${_commSettings.retryCount}次连接失败: $e');
        if (i < _commSettings.retryCount - 1) {
          await Future.delayed(Duration(milliseconds: _commSettings.retryIntervalMs));
        }
      }
    }
    throw Exception('重连失败: $lastError');
  }

  Future<void> _saveCurrentPreset() async {
    final nameController = TextEditingController(
      text: wifi ? 'WiFi预设-${DateTime.now().millisecondsSinceEpoch}' : '蓝牙预设-${DateTime.now().millisecondsSinceEpoch}',
    );
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('保存连接预设'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(labelText: '预设名称'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('保存')),
        ],
      ),
    );
    if (ok != true) return;
    final name = nameController.text.trim();
    if (name.isEmpty) return;
    final preset = ConnectionPreset(
      name: name,
      type: wifi ? 'wifi' : 'bluetooth',
      host: _lastWifiHost,
      port: _lastWifiPort,
      wifiSsid: null,
      btAddress: wifi
          ? null
          : (_bt.lastTransport == BtTransport.classic
                ? (_bt.lastClassicAddress == null ? null : 'classic:${_bt.lastClassicAddress}')
                : (_bt.lastBleId == null ? null : 'ble:${_bt.lastBleId}')),
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
    await ConnectionPresetStore.instance.upsert(preset);
    await _loadPresets();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('连接预设已保存')));
  }

  Future<void> _saveCommSettings() async {
    await ConnectionPresetStore.instance.saveCommSettings(
      CommSettings(
        retryCount: _commSettings.retryCount,
        retryIntervalMs: _commSettings.retryIntervalMs,
        autoReconnectEnabled: _autoReconnectEnabled,
      ),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('重连设置已保存')));
  }

  Future<void> _applyPreset(ConnectionPreset preset) async {
    if (preset.type == 'wifi') {
      if (preset.host == null || preset.port == null) {
        _appendLog('[Preset] WiFi 预设缺少 host/port');
        return;
      }
      try {
        await _connectWifiWithRetry(host: preset.host!, port: preset.port!);
        _lastWifiHost = preset.host;
        _lastWifiPort = preset.port;
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('已加载预设并连接: ${preset.name}')));
      } catch (e) {
        _appendLog('[Preset] 连接失败: $e');
      }
      return;
    }
    if (preset.type == 'bluetooth') {
      final target = (preset.btAddress ?? '').trim();
      if (target.isEmpty) {
        _appendLog('[Preset] 蓝牙预设缺少地址信息');
        return;
      }
      try {
        await _connectBluetoothPresetWithRetry(target);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('已加载蓝牙预设并连接: ${preset.name}')));
      } catch (e) {
        _appendLog('[Preset] 蓝牙连接失败: $e');
      }
    }
  }

  Future<void> _connectBluetoothPresetWithRetry(String target) async {
    Object? lastError;
    for (var i = 0; i < _commSettings.retryCount; i++) {
      try {
        if (target.startsWith('classic:')) {
          final address = target.substring('classic:'.length);
          if (address.isEmpty) throw Exception('经典蓝牙地址为空');
          await _bt.connectClassic(address);
        } else if (target.startsWith('ble:')) {
          final id = target.substring('ble:'.length);
          if (id.isEmpty) throw Exception('BLE id 为空');
          await _bt.connectBleById(id);
        } else {
          
          await _bt.connectClassic(target);
        }
        return;
      } catch (e) {
        lastError = e;
        _appendLog('[蓝牙Preset] 第${i + 1}/${_commSettings.retryCount}次连接失败: $e');
        if (i < _commSettings.retryCount - 1) {
          await Future.delayed(Duration(milliseconds: _commSettings.retryIntervalMs));
        }
      }
    }
    throw Exception('蓝牙预设重连失败: $lastError');
  }

  Future<void> _sendTestFrame() async {
    final frame = ObsHostProtocol.encodeCommand(ObsHostCommand.cmdGetStatus);
    try {
      if (wifi) {
        await _socket.sendBytes(frame);
        _appendLog('[WiFi][TX] 3A协议 CMD=0x6B ${_toHex(frame)}');
      } else {
        await _bt.sendBytes(frame);
        _appendLog('[蓝牙][TX] 3A协议 CMD=0x6B ${_toHex(frame)}');
      }
    } catch (e) {
      _appendLog('[TX][ERROR] $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('发送失败: $e')));
    }
  }

  Future<void> _sendObsCommand(int cmd, String title) async {
    final frame = ObsHostProtocol.encodeCommand(cmd);
    try {
      if (wifi) {
        await _socket.sendBytes(frame);
        _appendLog('[WiFi][TX][$title] ${_toHex(frame)}');
      } else {
        await _bt.sendBytes(frame);
        _appendLog('[蓝牙][TX][$title] ${_toHex(frame)}');
      }
    } catch (e) {
      _appendLog('[TX][$title][ERROR] $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$title 发送失败: $e')));
    }
  }

  void _startStatusPolling() {
    _statusPollTimer?.cancel();
    _statusPollTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (wifi && !_socket.isConnected) return;
      if (!wifi && !_bt.isConnected) return;
      await _sendObsCommand(ObsHostCommand.cmdGetT, '测试舱温(0x60)');
      await _sendObsCommand(ObsHostCommand.cmdGetP, '测试舱压(0x61)');
      await _sendObsCommand(ObsHostCommand.cmdBatVolt, '测试电压(0x62)');
      await _sendObsCommand(ObsHostCommand.cmdGetLevel, '测试姿态(0x64)');
      await _sendObsCommand(ObsHostCommand.cmdGetStatus, '仪器状态(0x6B)');
    });
    _appendLog('[轮询] 已启动 1s 周期状态查询');
  }

  void _stopStatusPolling() {
    _statusPollTimer?.cancel();
    _statusPollTimer = null;
    _appendLog('[轮询] 已停止');
  }

  @override
  Widget build(BuildContext context) {
    return PageShell(
      title: '通信管理',
      child: ListView(
        padding: EdgeInsets.only(bottom: 8.h),
        children: [
          CardContainer(
            title: '通信方式',
            child: Row(
              children: [
                Expanded(child: CheckTile(label: 'WiFi', selected: wifi, onTap: () => setState(() => wifi = true))),
                SizedBox(width: 12.w),
                Expanded(child: CheckTile(label: '蓝牙', selected: !wifi, onTap: () => setState(() => wifi = false))),
              ],
            ),
          ),
          SizedBox(height: 18.h),
          wifi ? const WifiSection() : const BluetoothSection(),
          SizedBox(height: 16.h),
          CardContainer(
            title: '连接预设',
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: DropdownButton<ConnectionPreset>(
                        isExpanded: true,
                        hint: const Text('选择并加载预设'),
                        value: null,
                        items: _presets
                            .map((e) => DropdownMenuItem<ConnectionPreset>(
                                  value: e,
                                  child: Text('${e.name} (${e.type})'),
                                ))
                            .toList(),
                        onChanged: (preset) {
                          if (preset != null) {
                            _applyPreset(preset);
                          }
                        },
                      ),
                    ),
                    SizedBox(width: 8.w),
                    OutlinedButton(
                      onPressed: _saveCurrentPreset,
                      child: const Text('保存预设'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(height: 16.h),
          CardContainer(
            title: '重连设置',
            child: Column(
              children: [
                Row(
                  children: [
                    const Text('自动重连'),
                    SizedBox(width: 8.w),
                    Switch(
                      value: _autoReconnectEnabled,
                      onChanged: (v) => setState(() => _autoReconnectEnabled = v),
                    ),
                  ],
                ),
                SizedBox(height: 12.h),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButton<int>(
                        isExpanded: true,
                        value: _commSettings.retryCount,
                        items: const [1, 2, 3, 5]
                            .map((e) => DropdownMenuItem(value: e, child: Text('重试次数: $e')))
                            .toList(),
                        onChanged: (v) {
                          if (v == null) return;
                          setState(() {
                            _commSettings = CommSettings(
                              retryCount: v,
                              retryIntervalMs: _commSettings.retryIntervalMs,
                              autoReconnectEnabled: _autoReconnectEnabled,
                            );
                          });
                        },
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: DropdownButton<int>(
                        isExpanded: true,
                        value: _commSettings.retryIntervalMs,
                        items: const [1000, 2000, 3000, 5000]
                            .map((e) => DropdownMenuItem(value: e, child: Text('间隔: ${e ~/ 1000}s')))
                            .toList(),
                        onChanged: (v) {
                          if (v == null) return;
                          setState(() {
                            _commSettings = CommSettings(
                              retryCount: _commSettings.retryCount,
                              retryIntervalMs: v,
                              autoReconnectEnabled: _autoReconnectEnabled,
                            );
                          });
                        },
                      ),
                    ),
                    SizedBox(width: 8.w),
                    OutlinedButton(onPressed: _saveCommSettings, child: const Text('保存')),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(height: 22.h),
          Row(
            children: [
              Expanded(child: GradientButton(text: '链接设备', icon: Icons.link, onTap: _onLinkDevice)),
              SizedBox(width: 10.w),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _onDisconnectDevice,
                  icon: const Icon(Icons.link_off),
                  label: const Text('断开设备'),
                ),
              ),
            ],
          ),
          SizedBox(height: 14.h),
          OutlinedButton.icon(
            onPressed: _sendTestFrame,
            icon: const Icon(Icons.send),
            label: const Text('发送状态查询(CMD_GET_STATUS)'),
          ),
          SizedBox(height: 14.h),
          CardContainer(
            title: '设备控制指令',
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton(
                  onPressed: () => _sendObsCommand(ObsHostCommand.cmdOpenGps, 'GPS开(0x50)'),
                  child: const Text('GPS开'),
                ),
                OutlinedButton(
                  onPressed: () => _sendObsCommand(ObsHostCommand.cmdCloseGps, 'GPS关(0x51)'),
                  child: const Text('GPS关'),
                ),
                OutlinedButton(
                  onPressed: () => _sendObsCommand(ObsHostCommand.cmdStartAd, 'AD开(0x52)'),
                  child: const Text('AD开'),
                ),
                OutlinedButton(
                  onPressed: () => _sendObsCommand(ObsHostCommand.cmdStopAd, 'AD关(0x53)'),
                  child: const Text('AD关'),
                ),
                OutlinedButton(
                  onPressed: () => _sendObsCommand(ObsHostCommand.cmdRdoOn, '数传开(0x54)'),
                  child: const Text('数传开'),
                ),
                OutlinedButton(
                  onPressed: () => _sendObsCommand(ObsHostCommand.cmdRdoOff, '数传关(0x55)'),
                  child: const Text('数传关'),
                ),
                OutlinedButton(
                  onPressed: () => _sendObsCommand(ObsHostCommand.cmdLgtOn, '闪光灯开(0x58)'),
                  child: const Text('闪光灯开'),
                ),
                OutlinedButton(
                  onPressed: () => _sendObsCommand(ObsHostCommand.cmdLgtOff, '闪光灯关(0x59)'),
                  child: const Text('闪光灯关'),
                ),
              ],
            ),
          ),
          SizedBox(height: 16.h),
          CardContainer(
            title: '通讯日志',
            child: Container(
              height: 140.h,
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFD7DCE6)),
                borderRadius: BorderRadius.circular(6.r),
              ),
              padding: EdgeInsets.all(8.r),
              child: _logs.isEmpty
                  ? const Text('暂无日志')
                  : ListView.builder(
                      itemCount: _logs.length,
                      itemBuilder: (_, i) => Padding(
                        padding: EdgeInsets.only(bottom: 8.h),
                        child: Text(
                          _logs[i],
                          style: TextStyle(fontSize: 11.sp, height: 1.35),
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
