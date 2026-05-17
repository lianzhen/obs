import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:myflutter/utils/bluetooth_transfer_util.dart';
import 'package:myflutter/utils/obs_host_protocol.dart';
import 'package:myflutter/utils/obs_socket_client.dart';

/// 配置管理页
///
/// - 顶部：自定义 AppBar
/// - 中部：配置编辑卡片（可编辑的运行参数表单 + 备份预览区）
/// - 底部：2x2 四个彩色按钮（下载 / 导入 / 上传 / 导出）
///
/// 配置文件格式：JSON（.cfg 后缀），跨平台可读、易备份。
/// 文件 magic：第一行 `# OBS CONFIG v1` 便于辨别。
class ConfigPage extends StatefulWidget {
  const ConfigPage({super.key});

  @override
  State<ConfigPage> createState() => _ConfigPageState();
}

class _ConfigPageState extends State<ConfigPage> {
  static const Color _bgColor = Color(0xFFEFF2F6);
  static const Color _hintTextColor = Color(0xFF9AA0A6);
  static const Color _itemBorder = Color(0xFFE2E6EE);

  /// SharedPreferences 中暂存的"草稿"配置（应用打开时自动恢复）
  static const String _kDraftKey = 'obs_config_draft_v1';

  /// 文件 magic 头，用来快速辨认 .cfg 文件是否是本应用产出
  static const String _kFileMagic = '# OBS CONFIG v1';

  // 通信
  final ObsSocketClient _socket = ObsSocketClient.instance;
  final BluetoothTransferUtil _bt = BluetoothTransferUtil.instance;
  StreamSubscription<Uint8List>? _incomingSub;
  Completer<Uint8List>? _downloadCompleter;

  // 操作状态
  bool _downloading = false;
  bool _uploading = false;
  bool _importing = false;
  bool _exporting = false;

  // 配置项 controllers（可按需扩展）
  late final Map<String, TextEditingController> _controllers;

  @override
  void initState() {
    super.initState();
    _controllers = {
      for (final f in _ConfigField.fields) f.key: TextEditingController(),
    };

    // 监听通信流，用于 "下载" 时捕获回包
    _incomingSub = _bindIncomingStream();

    // 恢复草稿
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadDraft());
  }

  @override
  void dispose() {
    _incomingSub?.cancel();
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  StreamSubscription<Uint8List>? _bindIncomingStream() {
    // 同时订阅 WiFi 和 BT 的数据流
    final ctl = StreamController<Uint8List>.broadcast();
    final subs = <StreamSubscription<Uint8List>>[
      _socket.incomingDataStream.listen(ctl.add),
      _bt.incomingDataStream.listen(ctl.add),
    ];
    return ctl.stream.listen((data) {
      // 尝试解析为 3A 协议帧
      final frame = ObsHostProtocol.tryParse(data);
      if (frame == null) return;
      // GetCfg/SetCfg 返回都按 cmdGetCfg 处理
      if (frame.cmd == ObsHostCommand.cmdGetCfg) {
        _downloadCompleter?.complete(frame.payload);
        _downloadCompleter = null;
      }
    }, onDone: () {
      for (final s in subs) {
        s.cancel();
      }
      ctl.close();
    });
  }

  // ==========================================================
  // 配置数据读写
  // ==========================================================

  Map<String, dynamic> _currentValues() {
    final map = <String, dynamic>{};
    for (final f in _ConfigField.fields) {
      map[f.key] = _controllers[f.key]!.text;
    }
    return map;
  }

  void _applyValues(Map<String, dynamic> values) {
    for (final f in _ConfigField.fields) {
      final v = values[f.key];
      _controllers[f.key]!.text = v == null ? '' : v.toString();
    }
  }

  Future<void> _loadDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kDraftKey);
      if (raw == null || raw.isEmpty) return;
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        if (!mounted) return;
        setState(() => _applyValues(decoded));
      }
    } catch (_) {}
  }

  Future<void> _saveDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kDraftKey, jsonEncode(_currentValues()));
    } catch (_) {}
  }

  // ==========================================================
  // 下载（设备 → APP）
  // ==========================================================
  Future<void> _onDownload() async {
    if (_downloading) return;
    setState(() => _downloading = true);
    try {
      final isWifi = _socket.isConnected;
      final isBt = _bt.isConnected;
      if (!isWifi && !isBt) {
        throw Exception('请先在"通信管理"中连接 WiFi 或蓝牙');
      }
      final frame = ObsHostProtocol.encodeCommand(ObsHostCommand.cmdGetCfg);
      _downloadCompleter = Completer<Uint8List>();
      if (isWifi) {
        await _socket.sendBytes(frame);
      } else {
        await _bt.sendBytes(frame);
      }
      // 等设备回包（最多 6 秒）
      final payload = await _downloadCompleter!.future
          .timeout(const Duration(seconds: 6), onTimeout: () {
        throw Exception('设备未在 6 秒内返回配置');
      });
      _downloadCompleter = null;

      final values = _decodeDevicePayload(payload);
      if (values.isEmpty) {
        throw Exception('解析配置失败：设备返回的数据为空或不可识别');
      }
      if (!mounted) return;
      setState(() => _applyValues(values));
      await _saveDraft();
      _toast('已从设备下载配置（${values.length} 项）');
    } catch (e) {
      if (!mounted) return;
      _toast('下载失败：$e');
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  /// 把设备 payload 还原成键值对。
  /// 设备真实协议未知时，先尝试当作 UTF-8 JSON 解析；不行就退化为 key=value 文本。
  Map<String, dynamic> _decodeDevicePayload(Uint8List payload) {
    if (payload.isEmpty) return {};
    String text;
    try {
      text = utf8.decode(payload, allowMalformed: true).trim();
    } catch (_) {
      return {};
    }
    if (text.isEmpty) return {};
    // JSON
    try {
      final decoded = jsonDecode(text);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {}
    // key=value 一行一个
    final out = <String, dynamic>{};
    for (final line in text.split(RegExp(r'[\r\n]+'))) {
      final s = line.trim();
      if (s.isEmpty || s.startsWith('#')) continue;
      final eq = s.indexOf('=');
      if (eq <= 0) continue;
      out[s.substring(0, eq).trim()] = s.substring(eq + 1).trim();
    }
    return out;
  }

  // ==========================================================
  // 上传（APP → 设备）
  // ==========================================================
  Future<void> _onUpload() async {
    if (_uploading) return;
    setState(() => _uploading = true);
    try {
      final isWifi = _socket.isConnected;
      final isBt = _bt.isConnected;
      if (!isWifi && !isBt) {
        throw Exception('请先在"通信管理"中连接 WiFi 或蓝牙');
      }
      final json = jsonEncode(_currentValues());
      final payload = Uint8List.fromList(utf8.encode(json));
      // CMD_SET_CFG (0x5A) 设置 → CMD_SAVE_CFG (0x5F) 保存
      final setFrame = ObsHostProtocol.encodeCommand(
        ObsHostCommand.cmdSetCfg,
        payload: payload,
      );
      final saveFrame =
          ObsHostProtocol.encodeCommand(ObsHostCommand.cmdSaveCfg);
      if (isWifi) {
        await _socket.sendBytes(setFrame);
        await Future.delayed(const Duration(milliseconds: 200));
        await _socket.sendBytes(saveFrame);
      } else {
        await _bt.sendBytes(setFrame);
        await Future.delayed(const Duration(milliseconds: 200));
        await _bt.sendBytes(saveFrame);
      }
      await _saveDraft();
      if (!mounted) return;
      _toast('已上传配置到设备（${payload.length} 字节）');
    } catch (e) {
      if (!mounted) return;
      _toast('上传失败：$e');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  // ==========================================================
  // 导入（本地文件 → APP）
  // ==========================================================
  Future<void> _onImport() async {
    if (_importing) return;
    setState(() => _importing = true);
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.any,
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final picked = result.files.first;
      final bytes = picked.bytes ??
          (picked.path == null ? null : await File(picked.path!).readAsBytes());
      if (bytes == null) throw Exception('读取文件失败');
      final text = utf8.decode(bytes, allowMalformed: true);

      // 跳过 magic 行
      final body = text
          .split(RegExp(r'\r?\n'))
          .where((l) => !l.trim().startsWith('#'))
          .join('\n')
          .trim();
      final decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic>) {
        throw Exception('文件格式不正确：根节点必须是 JSON 对象');
      }
      if (!mounted) return;
      setState(() => _applyValues(decoded));
      await _saveDraft();
      _toast('已导入配置文件：${picked.name}');
    } catch (e) {
      if (!mounted) return;
      _toast('导入失败：$e');
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  // ==========================================================
  // 导出（APP → 本地文件）
  // ==========================================================
  Future<void> _onExport() async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      final values = _currentValues();
      final body = const JsonEncoder.withIndent('  ').convert(values);
      final content = '$_kFileMagic\n# exported at ${DateTime.now()}\n$body\n';
      final ts = DateTime.now().toIso8601String().replaceAll(':', '-');
      final fileName = 'obs_config_$ts.cfg';

      // 先在 await 前取出 sharePositionOrigin，避免跨 async 使用 context
      final box = context.findRenderObject() as RenderBox?;
      final origin = box == null
          ? null
          : box.localToGlobal(Offset.zero) & box.size;

      Directory dir;
      try {
        dir = await getApplicationDocumentsDirectory();
      } catch (_) {
        dir = Directory.systemTemp;
      }
      final file = File('${dir.path}${Platform.pathSeparator}$fileName');
      await file.writeAsString(content, flush: true);

      // 弹起系统分享面板，让用户保存到任意位置
      try {
        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(file.path)],
            text: 'OBS 配置文件',
            sharePositionOrigin: origin,
          ),
        );
      } catch (_) {
        // 分享失败也无妨，至少文件已经写到沙盒
      }

      if (!mounted) return;
      _toast('已导出到：${file.path}');
    } catch (e) {
      if (!mounted) return;
      _toast('导出失败：$e');
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  // ==========================================================
  // UI
  // ==========================================================
  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
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
                padding: EdgeInsets.fromLTRB(20.w, 8.w, 20.w, 8.w),
                child: _buildEditCard(),
              ),
            ),
            _buildButtonGrid(),
            SizedBox(height: 20.w),
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
            '配置管理',
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

  Widget _buildEditCard() {
    final hasValues =
        _controllers.values.any((c) => c.text.trim().isNotEmpty);
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10.r),
      ),
      clipBehavior: Clip.antiAlias,
      child: hasValues
          ? _buildFieldList()
          : Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 30.w),
                child: Text(
                  '暂无配置数据\n\n请点击下方按钮：\n· 下载配置  从已连接设备获取\n· 导入配置  从本地 .cfg 文件加载',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _hintTextColor,
                    fontSize: 22.sp,
                    height: 1.8,
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildFieldList() {
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(20.w, 14.w, 20.w, 14.w),
      itemCount: _ConfigField.fields.length,
      separatorBuilder: (_, _) =>
          Divider(height: 1, color: _itemBorder.withValues(alpha: 0.6)),
      itemBuilder: (_, i) {
        final f = _ConfigField.fields[i];
        return Padding(
          padding: EdgeInsets.symmetric(vertical: 10.w),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 200.w,
                child: Text(
                  f.label,
                  style: TextStyle(
                    fontSize: 24.sp,
                    color: Colors.black87,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Expanded(
                child: TextField(
                  controller: _controllers[f.key],
                  keyboardType: f.numeric
                      ? const TextInputType.numberWithOptions(
                          decimal: true, signed: false)
                      : TextInputType.text,
                  inputFormatters: f.numeric
                      ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.\-]'))]
                      : null,
                  textAlign: TextAlign.right,
                  style: TextStyle(fontSize: 24.sp, color: Colors.black87),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: f.hint,
                    hintStyle: TextStyle(
                      fontSize: 22.sp,
                      color: _hintTextColor,
                    ),
                    border: InputBorder.none,
                    suffixText: f.unit,
                    suffixStyle: TextStyle(
                      fontSize: 22.sp,
                      color: _hintTextColor,
                    ),
                  ),
                  onChanged: (_) {
                    _saveDraft();
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildButtonGrid() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _ActionButton(
                  text: '下载配置文件',
                  icon: Icons.arrow_downward,
                  colors: const [Color(0xFF7BA7FF), Color(0xFF4778E6)],
                  loading: _downloading,
                  onTap: _onDownload,
                ),
              ),
              SizedBox(width: 16.w),
              Expanded(
                child: _ActionButton(
                  text: '导入配置文件',
                  icon: Icons.file_download_outlined,
                  colors: const [Color(0xFF3CCB7F), Color(0xFF1E9B57)],
                  loading: _importing,
                  onTap: _onImport,
                ),
              ),
            ],
          ),
          SizedBox(height: 14.w),
          Row(
            children: [
              Expanded(
                child: _ActionButton(
                  text: '上传配置文件',
                  icon: Icons.arrow_upward,
                  colors: const [Color(0xFFD3A1FF), Color(0xFFAB59E0)],
                  loading: _uploading,
                  onTap: _onUpload,
                ),
              ),
              SizedBox(width: 16.w),
              Expanded(
                child: _ActionButton(
                  text: '导出配置文件',
                  icon: Icons.file_upload_outlined,
                  colors: const [Color(0xFFFF8A78), Color(0xFFE85F4A)],
                  loading: _exporting,
                  onTap: _onExport,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ===========================================================
// 配置字段定义（可按设备协议扩充）
// ===========================================================
class _ConfigField {
  const _ConfigField({
    required this.key,
    required this.label,
    this.hint = '',
    this.unit = '',
    this.numeric = false,
  });

  final String key;
  final String label;
  final String hint;
  final String unit;
  final bool numeric;

  static const List<_ConfigField> fields = [
    _ConfigField(key: 'deviceId', label: '设备 ID'),
    _ConfigField(key: 'deviceName', label: '设备名称'),
    _ConfigField(
      key: 'sampleRate',
      label: '采样率',
      unit: 'Hz',
      numeric: true,
      hint: '例如 100',
    ),
    _ConfigField(
      key: 'gpsInterval',
      label: 'GPS 更新间隔',
      unit: 's',
      numeric: true,
      hint: '例如 1',
    ),
    _ConfigField(
      key: 'radioFreq',
      label: '数传频率',
      unit: 'MHz',
      numeric: true,
      hint: '例如 433.000',
    ),
    _ConfigField(
      key: 'radioPower',
      label: '数传功率等级',
      numeric: true,
      hint: '1~7',
    ),
    _ConfigField(
      key: 'lightMode',
      label: '闪光灯模式',
      hint: 'off / auto / on',
    ),
    _ConfigField(
      key: 'autoSleepSec',
      label: '自动休眠时长',
      unit: 's',
      numeric: true,
      hint: '0 = 不休眠',
    ),
    _ConfigField(
      key: 'ntpHost',
      label: 'NTP 服务器',
      hint: '例如 ntp.aliyun.com',
    ),
    _ConfigField(
      key: 'wifiSsid',
      label: 'WiFi SSID',
    ),
    _ConfigField(
      key: 'wifiPassword',
      label: 'WiFi 密码',
    ),
    _ConfigField(
      key: 'serverHost',
      label: '上报服务器',
      hint: 'IP 或域名',
    ),
    _ConfigField(
      key: 'serverPort',
      label: '上报端口',
      numeric: true,
      hint: '例如 9000',
    ),
  ];
}

// ===========================================================
// 内部组件
// ===========================================================

class _ActionButton extends StatelessWidget {
  const _ActionButton({
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
    return InkWell(
      onTap: loading ? null : onTap,
      borderRadius: BorderRadius.circular(10.r),
      child: Ink(
        height: 80.w,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: colors),
          borderRadius: BorderRadius.circular(10.r),
        ),
        child: Center(
          child: loading
              ? SizedBox(
                  width: 28.w,
                  height: 28.w,
                  child: const CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2.5,
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, color: Colors.white, size: 28.sp),
                    SizedBox(width: 10.w),
                    Text(
                      text,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24.sp,
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
