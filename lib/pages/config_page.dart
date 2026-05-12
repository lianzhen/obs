import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:myflutter/utils/bluetooth_transfer_util.dart';
import 'package:myflutter/utils/obs_host_protocol.dart';
import 'package:myflutter/utils/obs_socket_client.dart';
import 'package:myflutter/widgets/common_widgets.dart';
import 'package:path_provider/path_provider.dart';

class ConfigPage extends StatefulWidget {
  const ConfigPage({super.key});

  @override
  State<ConfigPage> createState() => _ConfigPageState();
}

class _ConfigPageState extends State<ConfigPage> {
  final ObsSocketClient _socket = ObsSocketClient.instance;
  final BluetoothTransferUtil _bt = BluetoothTransferUtil.instance;
  final TextEditingController _contentController = TextEditingController();
  String _lastFilePath = '';
  String _status = '未操作';
  bool _loading = false;

  bool get _wifiConnected => _socket.isConnected;
  bool get _btConnected => _bt.isConnected;
  bool get _hasChannel => _wifiConnected || _btConnected;

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  void _setStatus(String text) {
    if (!mounted) return;
    setState(() => _status = text);
  }

  Future<void> _withLoading(Future<void> Function() action) async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _sendBytes(Uint8List bytes) async {
    if (_wifiConnected) {
      await _socket.sendBytes(bytes);
      return;
    }
    if (_btConnected) {
      await _bt.sendBytes(bytes);
      return;
    }
    throw Exception('未检测到可用通信链路，请先在通信管理中连接设备');
  }

  Stream<Uint8List> get _rxStream => _wifiConnected ? _socket.incomingDataStream : _bt.incomingDataStream;

  Future<ObsHostFrame> _waitCmdFrame(int cmd, {Duration timeout = const Duration(seconds: 3)}) async {
    final completer = Completer<ObsHostFrame>();
    late final StreamSubscription<Uint8List> sub;
    sub = _rxStream.listen((raw) {
      final f = ObsHostProtocol.tryParse(raw);
      if (f != null && f.cmd == cmd && !completer.isCompleted) {
        completer.complete(f);
      }
    });
    try {
      return await completer.future.timeout(timeout);
    } finally {
      await sub.cancel();
    }
  }

  Future<void> _downloadConfig() async {
    await _withLoading(() async {
      if (!_hasChannel) throw Exception('请先连接设备');
      await _sendBytes(ObsHostProtocol.encodeCommand(ObsHostCommand.cmdGetCfg));
      final frame = await _waitCmdFrame(ObsHostCommand.cmdGetCfg, timeout: const Duration(seconds: 5));
      final text = utf8.decode(frame.payload, allowMalformed: true);
      _contentController.text = text.isEmpty ? _hex(frame.payload) : text;
      _setStatus('下载成功: ${frame.payload.length} bytes');
    });
  }

  Future<void> _uploadConfig() async {
    await _withLoading(() async {
      if (!_hasChannel) throw Exception('请先连接设备');
      final bytes = Uint8List.fromList(utf8.encode(_contentController.text));
      if (bytes.isEmpty) throw Exception('当前配置内容为空');

      const chunkSize = 180;
      for (var i = 0; i < bytes.length; i += chunkSize) {
        final end = (i + chunkSize > bytes.length) ? bytes.length : (i + chunkSize);
        final chunk = bytes.sublist(i, end);
        await _sendBytes(ObsHostProtocol.encodeCommand(ObsHostCommand.cmdCfgPut, payload: chunk));
      }
      await _sendBytes(ObsHostProtocol.encodeCommand(ObsHostCommand.cmdSaveCfg));
      _setStatus('上传成功: ${bytes.length} bytes');
    });
  }

  Future<void> _importConfig() async {
    await _withLoading(() async {
      final defaultDir = await getApplicationDocumentsDirectory();
      final pathCtrl = TextEditingController(text: _lastFilePath.isEmpty ? '${defaultDir.path}\\obs_config.cfg' : _lastFilePath);
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('导入配置文件'),
          content: TextField(
            controller: pathCtrl,
            decoration: const InputDecoration(
              labelText: '请输入 .cfg 文件路径',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('取消')),
            TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('导入')),
          ],
        ),
      );
      if (ok != true) return;
      final path = pathCtrl.text.trim();
      final file = File(path);
      if (!await file.exists()) throw Exception('文件不存在: $path');
      final content = await file.readAsString();
      _contentController.text = content;
      _lastFilePath = path;
      _setStatus('导入成功: $path');
    });
  }

  Future<void> _exportConfig() async {
    await _withLoading(() async {
      final content = _contentController.text;
      if (content.trim().isEmpty) throw Exception('当前配置内容为空');
      final dir = await getApplicationDocumentsDirectory();
      final ts = DateTime.now().millisecondsSinceEpoch;
      final path = '${dir.path}${Platform.pathSeparator}obs_config_$ts.cfg';
      final file = File(path);
      await file.writeAsString(content, flush: true);
      _lastFilePath = path;
      _setStatus('导出成功: $path');
    });
  }

  String _hex(Uint8List data) => data.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ').toUpperCase();

  @override
  Widget build(BuildContext context) {
    return PageShell(
      title: '配置管理',
      child: ListView(
        children: [
          CardContainer(
            title: '配置编辑',
            child: Column(
              children: [
                TextField(
                  controller: _contentController,
                  minLines: 8,
                  maxLines: 12,
                  decoration: const InputDecoration(
                    hintText: '这里编辑/查看配置内容（文本或HEX）',
                    border: OutlineInputBorder(),
                  ),
                ),
                SizedBox(height: 8.h),
                Row(
                  children: [
                    const Text('链路状态: '),
                    Text(_wifiConnected ? 'WiFi已连接' : (_btConnected ? '蓝牙已连接' : '未连接')),
                  ],
                ),
                SizedBox(height: 4.h),
                Text(
                  '操作状态: $_status',
                  style: TextStyle(fontSize: 12.sp, color: const Color(0xFF5A6375)),
                ),
              ],
            ),
          ),
          SizedBox(height: 12.h),
          Wrap(
            spacing: 12.w,
            runSpacing: 12.h,
            children: [
              ColorButton(
                text: '下载配置文件',
                color: const Color(0xFF4E86FF),
                icon: Icons.download,
                onTap: _loading ? null : () async => _safeAction(_downloadConfig),
              ),
              ColorButton(
                text: '导入配置文件',
                color: const Color(0xFF10B359),
                icon: Icons.upload_file,
                onTap: _loading ? null : () async => _safeAction(_importConfig),
              ),
              ColorButton(
                text: '上传配置文件',
                color: const Color(0xFFD17AF4),
                icon: Icons.upload,
                onTap: _loading ? null : () async => _safeAction(_uploadConfig),
              ),
              ColorButton(
                text: '导出配置文件',
                color: const Color(0xFFFF6B63),
                icon: Icons.file_download_done,
                onTap: _loading ? null : () async => _safeAction(_exportConfig),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _safeAction(Future<void> Function() fn) async {
    try {
      await fn();
    } catch (e) {
      _setStatus('失败: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }
}
