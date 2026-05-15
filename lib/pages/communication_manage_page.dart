import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:app_settings/app_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as fbp;
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wifi_iot/wifi_iot.dart';

import 'package:myflutter/utils/bluetooth_transfer_util.dart';

/// 通信管理页（独立实现，不复用现有 widgets，避免影响其他页面）
///
/// - 顶部：自定义 AppBar（返回 + 标题）
/// - 通信方式：WiFi / 蓝牙 互斥单选
/// - WiFi：已连接 WiFi + 可用 WiFi 列表
/// - 蓝牙：已配对蓝牙 + 搜索蓝牙设备 列表
/// - 底部：链接设备
class CommunicationManagePage extends StatefulWidget {
  const CommunicationManagePage({super.key});

  @override
  State<CommunicationManagePage> createState() =>
      _CommunicationManagePageState();
}

class _CommunicationManagePageState extends State<CommunicationManagePage>
    with WidgetsBindingObserver {
  static const Color _bgColor = Color(0xFFEFF2F6);
  static const Color _cardColor = Colors.white;
  static const Color _headerStripStart = Color(0xFFFFFFFF);
  static const Color _headerStripEnd = Color(0xFFE8F1F8);
  static const Color _hintTextColor = Color(0xFF9AA0A6);
  static const Color _primaryBlue = Color(0xFF3F73E8);
  static const Color _selectedBg = Color(0x195789FC);
  static const Color _itemBorder = Color(0xFFE2E6EE);

  // 通信方式：true = WiFi，false = 蓝牙
  bool _useWifi = true;

  // ===== WiFi 状态 =====
  String _connectedSsid = '';
  bool _connectedSecure = true;
  List<WifiNetwork> _wifiList = const [];
  WifiNetwork? _selectedWifi;
  bool _wifiLoading = false;
  String _wifiError = '';
  String _wifiConnecting = '';

  // ===== 蓝牙状态 =====
  final BluetoothTransferUtil _btTransfer = BluetoothTransferUtil.instance;

  /// 已配对设备（仅 BLE，已过滤未知设备）
  List<_BtItem> _bondedBtItems = const [];

  /// 扫描到的可用设备（仅 BLE，已过滤未知设备）
  List<_BtItem> _scanBtItems = const [];
  StreamSubscription<List<fbp.ScanResult>>? _bleScanSub;
  bool _btScanning = false;
  String _btError = '';

  /// 当前选中的蓝牙设备 key（_BtItem.key）
  String? _selectedBtKey;

  /// 正在连接的蓝牙 key
  String? _btConnectingKey;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _bootstrap();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // 用户从系统设置回来时刷新
      if (_useWifi) {
        _refreshWifi();
      } else {
        _loadBondedBtDevices();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _bleScanSub?.cancel();
    fbp.FlutterBluePlus.stopScan();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    if (_useWifi) {
      await _refreshWifi();
    } else {
      await _loadBondedBtDevices();
      await _startBtScan();
    }
  }

  // ============================================================
  // WiFi 相关
  // ============================================================

  Future<bool> _ensureWifiPermissions() async {
    if (!Platform.isAndroid) return true;
    final result = await <Permission>[
      Permission.locationWhenInUse,
      Permission.nearbyWifiDevices,
    ].request();
    final locationOk =
        result[Permission.locationWhenInUse] == PermissionStatus.granted ||
        result[Permission.locationWhenInUse] == PermissionStatus.limited;
    final nearbyOk =
        result[Permission.nearbyWifiDevices] == PermissionStatus.granted ||
        result[Permission.nearbyWifiDevices] == PermissionStatus.limited;
    return locationOk || nearbyOk;
  }

  Future<void> _refreshWifi() async {
    if (!mounted) return;
    setState(() {
      _wifiLoading = true;
      _wifiError = '';
    });
    try {
      final ok = await _ensureWifiPermissions();
      if (!ok) {
        throw Exception('请开启定位与附近WiFi权限');
      }
      final current = await WiFiForIoTPlugin.getSSID()
          .timeout(const Duration(seconds: 8), onTimeout: () => null);
      final list = await WiFiForIoTPlugin.loadWifiList()
          .timeout(const Duration(seconds: 18), onTimeout: () => <WifiNetwork>[]);

      // 去重 + 过滤无 SSID
      final seen = <String>{};
      final cleaned = <WifiNetwork>[];
      for (final ap in list) {
        final ssid = (ap.ssid ?? '').trim();
        if (ssid.isEmpty) continue;
        if (!seen.add(ssid)) continue;
        cleaned.add(ap);
      }

      // 按信号强度排序（level 越大越好）
      cleaned.sort((a, b) => (b.level ?? -200).compareTo(a.level ?? -200));

      final connected = (current ?? '').replaceAll('"', '').trim();
      final connectedAp = connected.isEmpty
          ? null
          : cleaned.firstWhere(
              (e) => (e.ssid ?? '').trim() == connected,
              orElse: () => WifiNetwork.fromJson({
                'SSID': connected,
                'BSSID': null,
                'capabilities': '[ESS]',
                'frequency': null,
                'level': null,
                'timestamp': null,
              }),
            );

      // 可用列表去掉已连接的
      final available = cleaned
          .where((e) => (e.ssid ?? '').trim() != connected)
          .toList();

      if (!mounted) return;
      setState(() {
        _connectedSsid = connected;
        _connectedSecure = connectedAp == null
            ? true
            : _isWifiEncrypted(connectedAp);
        _wifiList = available;
        if (_selectedWifi != null) {
          final ssid = _selectedWifi!.ssid;
          if (!available.any((e) => e.ssid == ssid)) {
            _selectedWifi = null;
          }
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _wifiError = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _wifiLoading = false;
        });
      }
    }
  }

  bool _isWifiEncrypted(WifiNetwork ap) {
    final caps = (ap.capabilities ?? '').toUpperCase();
    return caps.contains('WPA') || caps.contains('WEP') || caps.contains('PSK');
  }

  NetworkSecurity _wifiSecurity(WifiNetwork ap) {
    final caps = (ap.capabilities ?? '').toUpperCase();
    if (caps.contains('WEP')) return NetworkSecurity.WEP;
    if (caps.contains('WPA')) return NetworkSecurity.WPA;
    return NetworkSecurity.NONE;
  }

  Future<void> _connectSelectedWifi() async {
    final ap = _selectedWifi;
    if (ap == null) {
      _toast('请先在可用 WiFi 中选择一项');
      return;
    }
    final ssid = (ap.ssid ?? '').trim();
    if (ssid.isEmpty) {
      _toast('SSID 不可用');
      return;
    }
    final security = _wifiSecurity(ap);
    String? password;
    if (security != NetworkSecurity.NONE) {
      password = await _askWifiPassword(ssid);
      if (password == null) return; // 取消
      if (password.isEmpty) {
        _toast('请输入WiFi密码');
        return;
      }
    }

    setState(() => _wifiConnecting = ssid);
    try {
      final ok = await WiFiForIoTPlugin.connect(
        ssid,
        bssid: ap.bssid,
        password: password,
        security: security,
        joinOnce: false,
        timeoutInSeconds: 15,
      );
      if (!mounted) return;
      _toast(ok ? '已发起连接：$ssid' : '连接失败：$ssid');
      if (ok) {
        await Future.delayed(const Duration(seconds: 1));
        await _refreshWifi();
      }
    } catch (e) {
      if (!mounted) return;
      _toast('WiFi 连接异常：$e');
    } finally {
      if (mounted) {
        setState(() => _wifiConnecting = '');
      }
    }
  }

  Future<String?> _askWifiPassword(String ssid) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text('连接 $ssid'),
          content: TextField(
            controller: controller,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: '请输入 WiFi 密码',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.of(ctx).pop(controller.text.trim()),
              child: const Text('连接'),
            ),
          ],
        );
      },
    );
    return result;
  }

  // ============================================================
  // 蓝牙相关
  // ============================================================

  /// SharedPreferences key：本地记住的 BLE 设备
  /// 存储格式：JSON `{"<remoteId>": "<name>"}`
  static const String _kRememberedBleKey = 'remembered_ble_devices_v1';

  /// 加载本地记住的 BLE 设备（id -> name）
  Future<Map<String, String>> _loadRememberedBleDevices() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kRememberedBleKey);
      if (raw == null || raw.isEmpty) return {};
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return {};
      return decoded.map((k, v) => MapEntry(k.toString(), v.toString()));
    } catch (_) {
      return {};
    }
  }

  /// 保存一台 BLE 设备到本地"记住"列表
  Future<void> _rememberBleDevice(String id, String name) async {
    final current = await _loadRememberedBleDevices();
    current[id] = name;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kRememberedBleKey, jsonEncode(current));
  }

  /// 清理蓝牙名字：去除控制字符 / 零宽字符，再 trim。
  /// 防止某些设备返回 `\x00` 之类的"看不见"字符导致空名设备进入列表。
  String _sanitizeBtName(String? raw) {
    if (raw == null) return '';
    // 移除 ASCII 控制字符 + Unicode 零宽空格 / BOM 等
    final cleaned = raw.replaceAll(
      RegExp(r'[\u0000-\u001F\u007F\u200B-\u200F\uFEFF]'),
      '',
    );
    return cleaned.trim();
  }

  Future<bool> _ensureBluetoothPermissions() async {
    if (Platform.isAndroid) {
      final result = await <Permission>[
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.locationWhenInUse,
      ].request();
      return result.values.every(
        (s) => s == PermissionStatus.granted || s == PermissionStatus.limited,
      );
    }
    if (Platform.isIOS) {
      final result = await <Permission>[Permission.bluetooth].request();
      return result.values.every(
        (s) => s == PermissionStatus.granted || s == PermissionStatus.limited,
      );
    }
    return true;
  }

  Future<bool> _ensureBluetoothEnabled() async {
    final bleOn = (await fbp.FlutterBluePlus.adapterState.first) ==
        fbp.BluetoothAdapterState.on;
    if (bleOn) return true;
    if (!mounted) return false;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('蓝牙未开启'),
        content: const Text('请先开启蓝牙，再进行设备扫描与连接。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              AppSettings.openAppSettings(type: AppSettingsType.bluetooth);
            },
            child: const Text('去开启'),
          ),
        ],
      ),
    );
    return false;
  }

  Future<void> _loadBondedBtDevices() async {
    try {
      final ok = await _ensureBluetoothPermissions();
      if (!ok) {
        throw Exception('请开启蓝牙权限');
      }
      final on = await _ensureBluetoothEnabled();
      if (!on) return;

      // 已配对列表 = 系统 bonded ∪ 当前已连接 ∪ 本地记住的曾经连过的 BLE
      final bleBonded = await fbp.FlutterBluePlus.bondedDevices;
      final bleConnected = fbp.FlutterBluePlus.connectedDevices;
      final remembered = await _loadRememberedBleDevices();

      // id -> (device, name)
      final byId = <String, _BtItem>{};

      for (final d in [...bleBonded, ...bleConnected]) {
        final name = _sanitizeBtName(d.platformName);
        if (name.isEmpty) continue;
        byId[d.remoteId.str] = _BtItem.ble(
          name: name,
          id: d.remoteId.str,
          device: d,
        );
      }

      // 用本地"记住"的设备补齐：若系统层没拿到，则用持久化里的 name + 重建 device
      remembered.forEach((id, name) {
        if (id.isEmpty) return;
        final cleanName = _sanitizeBtName(name);
        if (cleanName.isEmpty) return;
        if (byId.containsKey(id)) return;
        byId[id] = _BtItem.ble(
          name: cleanName,
          id: id,
          device: fbp.BluetoothDevice.fromId(id),
        );
      });

      final items = byId.values.toList()
        ..sort((a, b) => a.name.compareTo(b.name));

      if (!mounted) return;
      setState(() {
        _bondedBtItems = items;
        _btError = '';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _btError = e.toString());
    }
  }

  Future<void> _startBtScan() async {
    if (!mounted) return;
    setState(() {
      _btScanning = true;
      _scanBtItems = const [];
      _btError = '';
    });
    try {
      final ok = await _ensureBluetoothPermissions();
      if (!ok) throw Exception('请开启蓝牙权限');
      final on = await _ensureBluetoothEnabled();
      if (!on) {
        setState(() => _btScanning = false);
        return;
      }

      final found = <String, _BtItem>{};

      void publish() {
        if (!mounted) return;
        final list = found.values.toList()
          ..sort((a, b) => a.displayName.compareTo(b.displayName));
        setState(() => _scanBtItems = list);
      }

      // 只扫 BLE，且只展示有名字的设备（过滤经典蓝牙 & 未知设备）
      await _bleScanSub?.cancel();
      await fbp.FlutterBluePlus.stopScan();
      _bleScanSub = fbp.FlutterBluePlus.scanResults.listen((list) {
        var changed = false;
        for (final r in list) {
          // 优先用缓存名 platformName，其次用扫描包里的 advName
          var name = _sanitizeBtName(r.device.platformName);
          if (name.isEmpty) {
            name = _sanitizeBtName(r.advertisementData.advName);
          }
          if (name.isEmpty) continue; // 过滤未知设备

          final id = r.device.remoteId.str;
          final key = 'ble:$id';
          final exist = found[key];
          if (exist == null) {
            found[key] = _BtItem.ble(
              name: name,
              id: id,
              device: r.device,
            );
            changed = true;
          } else if (exist.name != name) {
            found[key] = _BtItem.ble(
              name: name,
              id: id,
              device: exist.bleDevice ?? r.device,
            );
            changed = true;
          }
        }
        if (changed) publish();
      });

      await fbp.FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 10),
      );
      await Future.delayed(const Duration(seconds: 10));
    } catch (e) {
      if (!mounted) return;
      setState(() => _btError = e.toString());
    } finally {
      try {
        await fbp.FlutterBluePlus.stopScan();
      } catch (_) {}
      await _bleScanSub?.cancel();
      _bleScanSub = null;
      if (mounted) {
        setState(() => _btScanning = false);
      }
    }
  }

  Future<void> _connectSelectedBluetooth() async {
    final key = _selectedBtKey;
    if (key == null) {
      _toast('请先选择一个蓝牙设备');
      return;
    }
    final item = [..._bondedBtItems, ..._scanBtItems]
        .firstWhere((e) => e.key == key, orElse: () => _BtItem.empty());
    if (item.isEmpty) {
      _toast('选中的蓝牙设备已失效，请重新选择');
      return;
    }
    setState(() => _btConnectingKey = key);
    try {
      final ok = await _ensureBluetoothPermissions();
      if (!ok) throw Exception('请开启蓝牙权限');
      final on = await _ensureBluetoothEnabled();
      if (!on) return;

      final device = item.bleDevice;
      if (device == null) throw Exception('BLE 设备引用为空');
      await _btTransfer.connectBleAuto(device: device);

      // 1) 持久化"记住"该设备，确保下次进入页面已配对列表能看到
      await _rememberBleDevice(item.id, item.name);

      // 2) 尝试触发 OS 层 bond（不是所有 BLE 设备都支持，失败不影响主流程）
      if (Platform.isAndroid) {
        try {
          await device.createBond(timeout: 15);
        } catch (_) {
          // 设备不支持 bond / 用户拒绝配对 / 已经是 bonded 状态，都安静吞掉
        }
      }

      if (!mounted) return;
      _toast('已连接：${item.displayName}');
      await _loadBondedBtDevices();
    } catch (e) {
      if (!mounted) return;
      _toast('蓝牙连接失败：$e');
    } finally {
      if (mounted) {
        setState(() => _btConnectingKey = null);
      }
    }
  }

  // ============================================================
  // UI
  // ============================================================

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _switchMode(bool toWifi) {
    if (_useWifi == toWifi) return;
    setState(() {
      _useWifi = toWifi;
    });
    if (toWifi) {
      _refreshWifi();
    } else {
      _loadBondedBtDevices();
      _startBtScan();
    }
  }

  bool get _canLink {
    if (_useWifi) return _selectedWifi != null;
    return _selectedBtKey != null;
  }

  Future<void> _onLinkPressed() async {
    if (!_canLink) {
      _toast(_useWifi ? '请先选择一个 WiFi' : '请先选择一个蓝牙设备');
      return;
    }
    if (_useWifi) {
      await _connectSelectedWifi();
    } else {
      await _connectSelectedBluetooth();
    }
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
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(20.w, 8.w, 20.w, 24.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildModeCard(),
                    SizedBox(height: 22.w),
                    if (_useWifi) _buildWifiCard() else _buildBluetoothCard(),
                    SizedBox(height: 28.w),
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
            '通信管理',
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

  // ---- 通信方式 ----
  Widget _buildModeCard() {
    return _SectionCard(
      title: '通信方式',
      child: Padding(
        padding: EdgeInsets.fromLTRB(28.w, 20.w, 28.w, 24.w),
        child: Row(
          children: [
            Expanded(
              child: _CheckOption(
                label: 'WiFi',
                selected: _useWifi,
                onTap: () => _switchMode(true),
              ),
            ),
            Expanded(
              child: _CheckOption(
                label: '蓝牙',
                selected: !_useWifi,
                onTap: () => _switchMode(false),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---- WiFi 卡片 ----
  Widget _buildWifiCard() {
    return _SectionCard(
      title: 'WiFi',
      trailing: IconButton(
        onPressed: _wifiLoading ? null : _refreshWifi,
        icon: Icon(
          _wifiLoading ? Icons.sync : Icons.refresh,
          size: 32.sp,
          color: Colors.black54,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(24.w, 20.w, 24.w, 24.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildSubLabel('已连接 WiFi'),
            SizedBox(height: 12.w),
            _buildConnectedWifiTile(),
            SizedBox(height: 22.w),
            _buildSubLabel('可用 WiFi'),
            SizedBox(height: 12.w),
            _buildAvailableWifiList(),
            if (_wifiError.isNotEmpty)
              Padding(
                padding: EdgeInsets.only(top: 12.w),
                child: Text(
                  _wifiError,
                  style: TextStyle(color: Colors.red, fontSize: 22.sp),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 26.sp,
        color: _hintTextColor,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  Widget _buildConnectedWifiTile() {
    final hasConn = _connectedSsid.isNotEmpty;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: _itemBorder),
      ),
      padding: EdgeInsets.symmetric(horizontal: 22.w, vertical: 18.w),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasConn ? _connectedSsid : '未连接',
                  style: TextStyle(
                    fontSize: 28.sp,
                    fontWeight: FontWeight.w600,
                    color: hasConn ? _primaryBlue : Colors.black54,
                  ),
                ),
                SizedBox(height: 6.w),
                Text(
                  hasConn
                      ? '已连接，${_connectedSecure ? '安全' : '开放'}'
                      : '请连接 WiFi 后使用',
                  style: TextStyle(
                    fontSize: 22.sp,
                    color: _hintTextColor,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.wifi,
            size: 38.sp,
            color: hasConn ? Colors.black87 : Colors.black26,
          ),
        ],
      ),
    );
  }

  Widget _buildAvailableWifiList() {
    if (_wifiLoading && _wifiList.isEmpty) {
      return _placeholderBox('正在扫描 WiFi…');
    }
    if (_wifiList.isEmpty) {
      return _placeholderBox(_wifiError.isEmpty ? '暂无可用 WiFi' : '加载失败');
    }
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: _itemBorder),
      ),
      child: Column(
        children: List.generate(_wifiList.length, (index) {
          final ap = _wifiList[index];
          final ssid = (ap.ssid ?? '').trim();
          final isSelected = _selectedWifi?.ssid == ap.ssid;
          final isConnecting = _wifiConnecting == ssid;
          final encrypted = _isWifiEncrypted(ap);
          return InkWell(
            onTap: () => setState(() => _selectedWifi = ap),
            borderRadius: BorderRadius.circular(8.r),
            child: Container(
              decoration: BoxDecoration(
                color: isSelected ? _selectedBg : Colors.transparent,
                border: Border(
                  bottom: BorderSide(
                    color: index == _wifiList.length - 1
                        ? Colors.transparent
                        : _itemBorder,
                  ),
                ),
              ),
              padding:
                  EdgeInsets.symmetric(horizontal: 22.w, vertical: 16.w),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ssid.isEmpty ? '未知网络' : ssid,
                          style: TextStyle(
                            fontSize: 28.sp,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        SizedBox(height: 4.w),
                        Text(
                          encrypted ? '加密（可上网）' : '开放网络',
                          style: TextStyle(
                            fontSize: 22.sp,
                            color: _hintTextColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isConnecting)
                    SizedBox(
                      width: 28.w,
                      height: 28.w,
                      child: const CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    Icon(Icons.wifi, size: 38.sp, color: Colors.black87),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _placeholderBox(String text) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: _itemBorder),
      ),
      padding: EdgeInsets.symmetric(vertical: 28.w),
      alignment: Alignment.center,
      child: Text(
        text,
        style: TextStyle(fontSize: 24.sp, color: _hintTextColor),
      ),
    );
  }

  // ---- 蓝牙卡片 ----
  Widget _buildBluetoothCard() {
    return _SectionCard(
      title: '蓝牙设置',
      trailing: IconButton(
        onPressed: _btScanning ? null : _startBtScan,
        icon: Icon(
          _btScanning ? Icons.sync : Icons.refresh,
          size: 32.sp,
          color: Colors.black54,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(24.w, 20.w, 24.w, 24.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildBtSubLabel('已配对列表'),
            SizedBox(height: 10.w),
            _buildBluetoothListBox(_bondedBtItems, emptyText: '暂无已配对设备'),
            SizedBox(height: 22.w),
            _buildBtSubLabel('搜索蓝牙设备'),
            SizedBox(height: 10.w),
            _buildBluetoothListBox(
              _scanBtItems,
              emptyText: _btScanning ? '正在扫描…' : '未扫描到设备',
            ),
            if (_btError.isNotEmpty)
              Padding(
                padding: EdgeInsets.only(top: 12.w),
                child: Text(
                  _btError,
                  style: TextStyle(color: Colors.red, fontSize: 22.sp),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBtSubLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 24.sp,
        color: Colors.black87,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildBluetoothListBox(
    List<_BtItem> rawItems, {
    required String emptyText,
  }) {
    // 渲染兜底：如果意外有空名设备漏过，UI 层再过滤一次
    final items = rawItems
        .where((e) => _sanitizeBtName(e.name).isNotEmpty)
        .toList();
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6.r),
        border: Border.all(color: _itemBorder),
      ),
      constraints: BoxConstraints(minHeight: 150.w, maxHeight: 300.w),
      child: items.isEmpty
          ? Padding(
              padding: EdgeInsets.symmetric(vertical: 36.w),
              child: Center(
                child: Text(
                  emptyText,
                  style:
                      TextStyle(fontSize: 24.sp, color: _hintTextColor),
                ),
              ),
            )
          : ListView.separated(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: items.length,
              separatorBuilder: (_, _) => Divider(
                height: 1,
                thickness: 1,
                color: _itemBorder.withValues(alpha: 0.6),
              ),
              itemBuilder: (_, i) {
                final item = items[i];
                final selected = item.key == _selectedBtKey;
                final connecting = item.key == _btConnectingKey;
                final title = item.name.trim();
                final subtitle = 'BLE · ${item.id}';
                return InkWell(
                  onTap: () => setState(() => _selectedBtKey = item.key),
                  child: Container(
                    color: selected ? _selectedBg : Colors.transparent,
                    padding: EdgeInsets.symmetric(
                      horizontal: 22.w,
                      vertical: 18.w,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.bluetooth,
                          size: 32.sp,
                          color: selected ? _primaryBlue : Colors.black54,
                        ),
                        SizedBox(width: 14.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                title,
                                style: TextStyle(
                                  fontSize: 26.sp,
                                  fontWeight: FontWeight.w600,
                                  color: selected
                                      ? _primaryBlue
                                      : Colors.black87,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              SizedBox(height: 4.w),
                              Text(
                                subtitle,
                                style: TextStyle(
                                  fontSize: 20.sp,
                                  color: _hintTextColor,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        if (connecting) ...[
                          SizedBox(width: 12.w),
                          SizedBox(
                            width: 28.w,
                            height: 28.w,
                            child: const CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  // ---- 底部按钮 ----
  Widget _buildBottomBar() {
    final enabled = _canLink;
    final btnConnecting =
        (_useWifi && _wifiConnecting.isNotEmpty) || _btConnectingKey != null;
    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 8.w, 20.w, 20.w),
      child: SizedBox(
        height: 96.w,
        child: InkWell(
          borderRadius: BorderRadius.circular(12.r),
          onTap: btnConnecting
              ? null
              : enabled
                  ? _onLinkPressed
                  : null,
          child: Ink(
            decoration: BoxDecoration(
              gradient: enabled
                  ? const LinearGradient(
                      colors: [Color(0xFF6DA1FF), Color(0xFF3F73E8)],
                    )
                  : LinearGradient(
                      colors: [
                        const Color(0xFF6DA1FF).withValues(alpha: 0.5),
                        const Color(0xFF3F73E8).withValues(alpha: 0.5),
                      ],
                    ),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Center(
              child: btnConnecting
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
                        Icon(Icons.link, color: Colors.white, size: 36.sp),
                        SizedBox(width: 14.w),
                        Text(
                          '链接设备',
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

// ============================================================
// 内部小部件 / 数据结构（不外暴露，避免影响其他页面）
// ============================================================

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.child,
    this.trailing,
  });

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(10.r);
    return Container(
      decoration: BoxDecoration(
        color: _CommunicationManagePageState._cardColor,
        borderRadius: radius,
      ),
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
                  _CommunicationManagePageState._headerStripStart,
                  _CommunicationManagePageState._headerStripEnd,
                ],
              ),
            ),
            padding: EdgeInsets.symmetric(horizontal: 24.w),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 30.sp,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                ),
                ?trailing,
              ],
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
            SizedBox(width: 14.w),
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

/// 蓝牙列表项的统一封装（仅 BLE）
class _BtItem {
  _BtItem._({
    required this.name,
    required this.id,
    this.bleDevice,
  });

  factory _BtItem.ble({
    required String name,
    required String id,
    required fbp.BluetoothDevice device,
  }) {
    return _BtItem._(name: name, id: id, bleDevice: device);
  }

  factory _BtItem.empty() => _BtItem._(name: '', id: '');

  final String name;
  final String id;
  final fbp.BluetoothDevice? bleDevice;

  bool get isEmpty => id.isEmpty && name.isEmpty;

  String get key => 'ble:$id';

  String get displayName {
    final n = name.trim();
    if (n.isNotEmpty) return n;
    return id.isEmpty ? '未知设备' : id;
  }
}
