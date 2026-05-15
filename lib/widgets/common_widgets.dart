import 'dart:async';
import 'dart:io';

import 'package:app_settings/app_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as fbp;
import 'package:flutter_blue_classic/flutter_blue_classic.dart' as fbc;
import 'package:myflutter/utils/bluetooth_transfer_util.dart';
import 'package:myflutter/utils/connection_preset_store.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:wifi_iot/wifi_iot.dart';

class PageShell extends StatelessWidget {
  const PageShell({super.key, required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title), centerTitle: true),
      body: Padding(padding: EdgeInsets.all(16.r), child: child),
    );
  }
}

class CardContainer extends StatelessWidget {
  const CardContainer({
    super.key,
    required this.title,
    required this.child,
    this.titleBottomSpacing,
    this.childPadding,
  });

  final String title;
  final Widget child;

  final double? titleBottomSpacing;

  final EdgeInsetsGeometry? childPadding;

  @override
  Widget build(BuildContext context) {
    final radius = 8.w;
    final resolved =
        childPadding?.resolve(Directionality.of(context)) ??
        EdgeInsets.fromLTRB(22.w, 20.w, 22.w, 24.w);
    final contentPadding = resolved.copyWith(
      top: resolved.top + (titleBottomSpacing ?? 0),
    );

    Widget body;
    if (title.isEmpty) {
      body = Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFFFAFBFD),
          borderRadius: BorderRadius.circular(radius),
        ),
        child: Padding(padding: contentPadding, child: child),
      );
    } else {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 80.w,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFFFFFFF), Color(0xFFE8F1F8)],
              ),
              borderRadius: BorderRadius.vertical(top: Radius.circular(radius)),
            ),
            padding: EdgeInsets.only(left: 24.w),
            alignment: Alignment.centerLeft,
            child: Text(
              title,
              style: TextStyle(
                fontSize: 30.sp,
                fontWeight: FontWeight.w700,
                color: Colors.black,
              ),
            ),
          ),
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFFFAFBFD),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(radius),
                bottomRight: Radius.circular(radius),
              ),
            ),
            child: Padding(padding: contentPadding, child: child),
          ),
        ],
      );
    }

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 12.w),
      child: body,
    );
  }
}

class CheckTile extends StatelessWidget {
  const CheckTile({
    super.key,
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
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 38.w,
            height: 38.w,
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
                        width: 17.w,
                        height: 17.w,
                        decoration: BoxDecoration(
                          color: _fillSelected,
                          borderRadius: BorderRadius.circular(3.r),
                        ),
                      ),
                    )
                  : null,
            ),
          ),
          SizedBox(width: 8.w),
          Text(label),
        ],
      ),
    );
  }
}

class GradientButton extends StatelessWidget {
  const GradientButton({
    super.key,
    required this.text,
    required this.icon,
    this.onTap,
  });

  final String text;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8.r),
      child: Container(
        height: 46.h,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF6DA1FF), Color(0xFF3F73E8)],
          ),
          borderRadius: BorderRadius.circular(8.r),
          color: onTap == null ? Colors.grey : null,
        ),
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 18.sp),
              SizedBox(width: 8.w),
              Text(
                text,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14.sp,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class WifiSection extends StatefulWidget {
  const WifiSection({super.key});

  @override
  State<WifiSection> createState() => _WifiSectionState();
}

class _WifiSectionState extends State<WifiSection> {
  static const List<String> _obsWifiPrefixes = ['OBS', 'obs', 'GX', 'GeXing'];

  static const Duration _ssidFetchTimeout = Duration(seconds: 8);
  static const Duration _wifiListFetchTimeout = Duration(seconds: 18);

  String _connectedSsid = '';
  List<WifiNetwork> _wifiList = const [];
  bool _loading = true;
  String _error = '';
  String _connectingSsid = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _refreshWifiList();
    });
  }

  Future<bool> _ensureWifiPermissions() async {
    if (!Platform.isAndroid) return true;
    final perms = <Permission>[
      Permission.locationWhenInUse,
      Permission.nearbyWifiDevices,
    ];
    final result = await perms.request();
    final locationOk =
        result[Permission.locationWhenInUse] == PermissionStatus.granted ||
        result[Permission.locationWhenInUse] == PermissionStatus.limited;
    final nearbyOk =
        result[Permission.nearbyWifiDevices] == PermissionStatus.granted ||
        result[Permission.nearbyWifiDevices] == PermissionStatus.limited;
    return locationOk || nearbyOk;
  }

  Future<void> _refreshWifiList() async {
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      final permissionOk = await _ensureWifiPermissions();
      if (!permissionOk) {
        throw Exception('请开启定位与附近WiFi权限');
      }
      final current = await WiFiForIoTPlugin.getSSID().timeout(
        _ssidFetchTimeout,
        onTimeout: () => null,
      );
      final list = await WiFiForIoTPlugin.loadWifiList().timeout(
        _wifiListFetchTimeout,
        onTimeout: () => <WifiNetwork>[],
      );
      final filtered = list.where((e) {
        final ssid = (e.ssid ?? '').trim();
        if (ssid.isEmpty) return false;
        return _obsWifiPrefixes.any((p) => ssid.startsWith(p));
      }).toList();
      if (!mounted) return;
      setState(() {
        _connectedSsid = (current ?? '').replaceAll('"', '');
        _wifiList = filtered;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '获取WiFi列表失败: $e';
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
    }
  }

  List<WifiNetwork> _networksForDisplay() {
    if (_connectedSsid.isEmpty) return [];
    final trimmed = _connectedSsid.trim();
    final matches = _wifiList
        .where((e) => (e.ssid ?? '').trim() == trimmed)
        .toList();
    if (matches.isNotEmpty) return matches;
    return [
      WifiNetwork.fromJson({
        'SSID': trimmed,
        'BSSID': null,
        'capabilities': '[ESS]',
        'frequency': null,
        'level': null,
        'timestamp': null,
      }),
    ];
  }

  NetworkSecurity _inferSecurity(WifiNetwork ap) {
    final caps = (ap.capabilities ?? '').toUpperCase();
    if (caps.contains('WEP')) return NetworkSecurity.WEP;
    if (caps.contains('WPA')) return NetworkSecurity.WPA;
    return NetworkSecurity.NONE;
  }

  Future<void> _onTapWifi(WifiNetwork ap) async {
    final ssid = (ap.ssid ?? '').trim();
    if (ssid.isEmpty) return;
    final security = _inferSecurity(ap);
    String? password;

    if (security != NetworkSecurity.NONE) {
      final cachedPwd = await ConnectionPresetStore.instance.loadWifiCredential(
        ssid,
      );
      final controller = TextEditingController(text: cachedPwd ?? '');
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) {
          return AlertDialog(
            title: Text('连接 $ssid'),
            content: TextField(
              controller: controller,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: '请输入WiFi密码',
                border: OutlineInputBorder(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('取消'),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('连接'),
              ),
            ],
          );
        },
      );
      if (ok != true) return;
      password = controller.text.trim();
      if (password.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('请输入WiFi密码')));
        return;
      }
    }

    setState(() {
      _connectingSsid = ssid;
    });
    try {
      final settings = await ConnectionPresetStore.instance.loadCommSettings();
      var ok = false;
      Object? lastError;
      for (var i = 0; i < settings.retryCount; i++) {
        try {
          ok = await WiFiForIoTPlugin.connect(
            ssid,
            bssid: ap.bssid,
            password: password,
            security: security,
            joinOnce: false,
            timeoutInSeconds: 3,
          );
          if (ok) break;
        } catch (e) {
          lastError = e;
        }
        if (i < settings.retryCount - 1) {
          await Future.delayed(
            Duration(milliseconds: settings.retryIntervalMs),
          );
        }
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ok
                ? '已发起连接: $ssid'
                : (lastError == null
                      ? '连接超时，请检查设备WiFi是否正常'
                      : '连接失败: $lastError'),
          ),
        ),
      );
      if (ok && password != null && password.trim().isNotEmpty) {
        await ConnectionPresetStore.instance.saveWifiCredential(
          ssid: ssid,
          password: password,
        );
      }
      await _refreshWifiList();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('连接异常: $e')));
    } finally {
      if (!mounted) return;
      setState(() {
        _connectingSsid = '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return CardContainer(
      title: 'WiFi',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  '已连接 WiFi',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              IconButton(
                onPressed: _refreshWifiList,
                tooltip: '刷新',
                icon: Icon(Icons.refresh, size: 18.sp),
              ),
            ],
          ),
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(_connectedSsid.isEmpty ? '未连接' : _connectedSsid),
            subtitle: const Text('当前网络'),
            trailing: const Icon(Icons.wifi),
          ),
          SizedBox(height: 8.h),
          Text(
            '当前连接',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14.sp),
          ),
          if (_loading)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 10.h),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else if (_error.isNotEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 8.h),
              child: Text(
                _error,
                style: TextStyle(color: Colors.red, fontSize: 12.sp),
              ),
            )
          else if (_connectedSsid.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 8.h),
              child: Text('手机未连接 WiFi', style: TextStyle(fontSize: 12.sp)),
            )
          else
            ..._networksForDisplay().map(
              (e) => ListTile(
                onTap: () => _onTapWifi(e),
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text((e.ssid ?? '').isEmpty ? '未知网络' : e.ssid!),
                subtitle: Text(
                  '${(e.capabilities ?? '').isEmpty ? '开放网络' : e.capabilities!}  RSSI:${e.level ?? '--'}',
                ),
                trailing: _connectingSsid == (e.ssid ?? '')
                    ? SizedBox(
                        width: 18.w,
                        height: 18.w,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.wifi),
              ),
            ),
        ],
      ),
    );
  }
}

class BluetoothSection extends StatefulWidget {
  const BluetoothSection({super.key});

  @override
  State<BluetoothSection> createState() => _BluetoothSectionState();
}

class _BluetoothSectionState extends State<BluetoothSection>
    with WidgetsBindingObserver {
  static const List<String> _obsBtPrefixes = [
    'OBS',
    'obs',
    'GX',
    'GeXing',
    'EDIFIER',
    'U-E',
  ];

  final fbc.FlutterBlueClassic _classic = fbc.FlutterBlueClassic();
  final BluetoothTransferUtil _transfer = BluetoothTransferUtil.instance;
  List<fbc.BluetoothDevice> _bondedDevices = const [];
  List<fbp.BluetoothDevice> _bleBondedDevices = const [];
  List<fbp.BluetoothDevice> _bleConnectedDevices = const [];
  List<fbc.BluetoothDevice> _classicScanResults = const [];
  List<fbp.ScanResult> _bleScanResults = const [];
  StreamSubscription<fbc.BluetoothDevice>? _classicScanSub;
  bool _isScanning = false;
  String _error = '';
  final Set<String> _connectingClassic = <String>{};
  final Set<String> _connectingBle = <String>{};
  final Set<String> _connectedClassic = <String>{};
  final Set<String> _connectedBle = <String>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadBondedDevices();
    _startDiscovery();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _classicScanSub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadBondedDevices();
    }
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

  Future<void> _loadBondedDevices() async {
    try {
      final permissionOk = await _ensureBluetoothPermissions();
      if (!permissionOk) {
        throw Exception('请开启蓝牙权限');
      }
      final adapterOn = await _ensureBluetoothEnabled();
      if (!adapterOn) {
        return;
      }
      final devices = (await _classic.bondedDevices ?? <fbc.BluetoothDevice>[])
          .where((d) => _isObsBluetoothName(d.name ?? ''))
          .toList();
      final bleBonded = (await fbp.FlutterBluePlus.bondedDevices)
          .where((d) => _isObsBluetoothName(d.platformName))
          .toList();
      final bleConnected = fbp.FlutterBluePlus.connectedDevices;
      if (!mounted) return;
      setState(() {
        _bondedDevices = devices;
        _bleBondedDevices = bleBonded;
        _bleConnectedDevices = bleConnected;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '获取已配对设备失败: $e';
      });
    }
  }

  Future<void> _startDiscovery() async {
    setState(() {
      _isScanning = true;
      _error = '';
      _classicScanResults = [];
      _bleScanResults = [];
    });
    try {
      final permissionOk = await _ensureBluetoothPermissions();
      if (!permissionOk) {
        throw Exception('请开启蓝牙权限');
      }
      final adapterOn = await _ensureBluetoothEnabled();
      if (!adapterOn) {
        return;
      }

      final classicResults = <fbc.BluetoothDevice>[];
      await _classicScanSub?.cancel();
      _classic.startScan();
      _classicScanSub = _classic.scanResults.listen((r) {
        if (!_isObsBluetoothName(r.name ?? '')) return;
        final exists = classicResults.any((e) => e.address == r.address);
        if (!exists) {
          classicResults.add(r);
          if (mounted) {
            setState(() {
              _classicScanResults = List<fbc.BluetoothDevice>.from(
                classicResults,
              );
            });
          }
        }
      });

      await fbp.FlutterBluePlus.stopScan();
      final bleMap = <String, fbp.ScanResult>{};
      final bleSub = fbp.FlutterBluePlus.scanResults.listen((list) {
        for (final item in list) {
          if (!_isObsBluetoothName(item.device.platformName)) continue;
          bleMap[item.device.remoteId.str] = item;
        }
      });
      await fbp.FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));
      await Future.delayed(const Duration(seconds: 10));
      await bleSub.cancel();
      final bleResults = bleMap.values.toList();
      _classic.stopScan();
      if (mounted) {
        setState(() {
          _bleScanResults = bleResults;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '蓝牙扫描失败: $e';
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _isScanning = false;
      });
    }
  }

  Future<void> _connectClassicDevice(fbc.BluetoothDevice device) async {
    final address = device.address;
    if (_connectingClassic.contains(address)) return;
    setState(() => _connectingClassic.add(address));
    try {
      final permissionOk = await _ensureBluetoothPermissions();
      if (!permissionOk) {
        throw Exception('请开启蓝牙权限');
      }
      final adapterOn = await _ensureBluetoothEnabled();
      if (!adapterOn) return;
      final settings = await ConnectionPresetStore.instance.loadCommSettings();

      if (device.bondState != fbc.BluetoothBondState.bonded) {
        final bondOk = await _classic.bondDevice(address);
        if (!bondOk) {
          throw Exception('经典蓝牙配对失败');
        }
      }

      Object? lastError;
      var connected = false;
      for (var i = 0; i < settings.retryCount; i++) {
        try {
          await Future.any([
            _transfer.connectClassic(address),
            Future<void>.delayed(
              const Duration(seconds: 3),
              () => throw Exception('连接超时'),
            ),
          ]);
          connected = true;
          break;
        } catch (e) {
          lastError = e;
          if (i < settings.retryCount - 1) {
            await Future.delayed(
              Duration(milliseconds: settings.retryIntervalMs),
            );
          }
        }
      }
      if (!connected) {
        throw Exception(lastError ?? '连接失败');
      }
      if (!mounted) return;
      _connectedClassic.add(address);
      await _loadBondedDevices();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('经典蓝牙已连接: ${device.name ?? address}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('经典蓝牙连接异常: $e')));
    } finally {
      if (!mounted) return;
      setState(() => _connectingClassic.remove(address));
    }
  }

  Future<void> _connectBleDevice(fbp.BluetoothDevice device) async {
    final id = device.remoteId.str;
    if (_connectingBle.contains(id)) return;
    setState(() => _connectingBle.add(id));
    try {
      final permissionOk = await _ensureBluetoothPermissions();
      if (!permissionOk) {
        throw Exception('请开启蓝牙权限');
      }
      final adapterOn = await _ensureBluetoothEnabled();
      if (!adapterOn) return;
      final settings = await ConnectionPresetStore.instance.loadCommSettings();

      Object? lastError;
      var connected = false;
      for (var i = 0; i < settings.retryCount; i++) {
        try {
          await Future.any([
            _transfer.connectBleAuto(device: device),
            Future<void>.delayed(
              const Duration(seconds: 3),
              () => throw Exception('连接超时'),
            ),
          ]);
          connected = true;
          break;
        } catch (e) {
          lastError = e;
          if (i < settings.retryCount - 1) {
            await Future.delayed(
              Duration(milliseconds: settings.retryIntervalMs),
            );
          }
        }
      }
      if (!connected) {
        throw Exception(lastError ?? '连接失败');
      }
      if (!mounted) return;
      _connectedBle.add(id);
      await _loadBondedDevices();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'BLE 已连接: ${device.platformName.isEmpty ? id : device.platformName}',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString();
      if (msg.contains('already_connected')) {
        _connectedBle.add(id);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('BLE 设备已连接')));
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('BLE 连接异常: $e')));
      }
    } finally {
      if (!mounted) return;
      setState(() => _connectingBle.remove(id));
    }
  }

  Future<bool> _ensureBluetoothEnabled() async {
    final bleOn =
        (await fbp.FlutterBluePlus.adapterState.first) ==
        fbp.BluetoothAdapterState.on;
    final classicOn = await _classic.isEnabled;
    if (bleOn || classicOn) {
      return true;
    }
    if (!mounted) return false;
    await _showBluetoothOffDialog();
    return false;
  }

  bool _isObsBluetoothName(String name) {
    final n = name.trim();
    if (n.isEmpty) return false;
    return _obsBtPrefixes.any((p) => n.startsWith(p));
  }

  Future<void> _showBluetoothOffDialog() async {
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
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
        );
      },
    );
  }

  Widget _buildDeviceList({
    required int itemCount,
    required Widget Function(int index) itemBuilder,
    required String emptyText,
  }) {
    return Container(
      height: 180.w,
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFD7DCE6)),
      ),
      child: itemCount == 0
          ? Center(child: Text(emptyText))
          : ListView.separated(
              itemCount: itemCount,
              itemBuilder: (_, index) => itemBuilder(index),
              separatorBuilder: (_, _) =>
                  const Divider(height: 1, color: Color(0xFFDDE2EB)),
            ),
    );
  }

  Widget _buildDeviceRow(
    String name, {
    bool highlight = false,
    String? subtitle,
    VoidCallback? onConnect,
    bool connecting = false,
    bool connected = false,
  }) {
    return Container(
      width: double.infinity,
      color: highlight ? const Color(0x195789FC) : null,
      padding: EdgeInsets.symmetric(horizontal: 10.w),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name),
              ],
            ),
          ),
          if (onConnect != null)
            connecting
                ? SizedBox(
                    width: 18.w,
                    height: 18.w,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : TextButton(
                    onPressed: connected ? null : onConnect,
                    child: Text(connected ? '已连接' : '连接'),
                  ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final classicByAddress = <String, fbc.BluetoothDevice>{
      for (final d in _bondedDevices) d.address: d,
    };

    for (final addr in _connectedClassic) {
      classicByAddress.putIfAbsent(
        addr,
        () => fbc.BluetoothDevice.fromMap({
          'name': '已连接设备',
          'address': addr,
          'bondState': 'bonded',
          'deviceType': 'classic',
        }),
      );
    }
    final classicDisplay = classicByAddress.values.toList();

    final bleById = <String, fbp.BluetoothDevice>{
      for (final d in _bleBondedDevices) d.remoteId.str: d,
      for (final d in _bleConnectedDevices) d.remoteId.str: d,
    };
    final bleDisplay = bleById.values.toList();

    Widget buildList(
      String title,
      Widget body, {
      VoidCallback? onRefresh,
      bool scanning = false,
    }) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 20.sp,
                  ),
                ),
              ),
              if (onRefresh != null)
                IconButton(
                  onPressed: onRefresh,
                  tooltip: '刷新',
                  icon: Icon(
                    scanning ? Icons.sync : Icons.refresh,
                    size: 18.sp,
                  ),
                ),
            ],
          ),
          SizedBox(height: 4.h),
          body,
        ],
      );
    }

    return CardContainer(
      title: '蓝牙设置',
      titleBottomSpacing: -20.w,
      child: Column(
        children: [
          buildList(
            '已配对/已连接列表(经典+BLE)',
            _buildDeviceList(
              itemCount: classicDisplay.length + bleDisplay.length,
              emptyText: '暂无已配对设备',
              itemBuilder: (index) {
                if (index < classicDisplay.length) {
                  final d = classicDisplay[index];
                  return _buildDeviceRow(
                    (d.name ?? '').isEmpty ? '未知设备' : d.name!,
                    highlight: index == 0,
                    subtitle: '经典蓝牙 / ${d.address}',
                    onConnect: () => _connectClassicDevice(d),
                    connecting: _connectingClassic.contains(d.address),
                    connected: _connectedClassic.contains(d.address),
                  );
                }
                final ble = bleDisplay[index - classicDisplay.length];
                final id = ble.remoteId.str;
                return _buildDeviceRow(
                  ble.platformName.isEmpty ? '未知BLE设备' : ble.platformName,
                  highlight: index == 0,
                  subtitle:
                      _bleConnectedDevices.any((e) => e.remoteId.str == id)
                      ? 'BLE 已连接 / $id'
                      : 'BLE 已配对 / $id',
                  onConnect: () => _connectBleDevice(ble),
                  connecting: _connectingBle.contains(id),
                  connected: _connectedBle.contains(id),
                );
              },
            ),
            onRefresh: _loadBondedDevices,
          ),
          SizedBox(height: 12.h),
          buildList(
            '搜索蓝牙设备(经典+BLE)',
            _buildDeviceList(
              itemCount: _classicScanResults.length + _bleScanResults.length,
              emptyText: _isScanning ? '正在扫描...' : '未扫描到设备',
              itemBuilder: (index) {
                if (index < _classicScanResults.length) {
                  final d = _classicScanResults[index];
                  return _buildDeviceRow(
                    (d.name ?? '').isEmpty ? '未知经典设备' : d.name!,
                    highlight: index == 0,
                    subtitle: '经典蓝牙 / ${d.address}',
                    onConnect: () => _connectClassicDevice(d),
                    connecting: _connectingClassic.contains(d.address),
                    connected: _connectedClassic.contains(d.address),
                  );
                }
                final ble = _bleScanResults[index - _classicScanResults.length];
                return _buildDeviceRow(
                  ble.device.platformName.isEmpty
                      ? '未知BLE设备'
                      : ble.device.platformName,
                  highlight: index == 0,
                  subtitle: 'BLE RSSI ${ble.rssi} / ${ble.device.remoteId.str}',
                  onConnect: () => _connectBleDevice(ble.device),
                  connecting: _connectingBle.contains(ble.device.remoteId.str),
                  connected: _connectedBle.contains(ble.device.remoteId.str),
                );
              },
            ),
            onRefresh: _startDiscovery,
            scanning: _isScanning,
          ),
          if (_error.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(top: 8.h),
              child: Text(
                _error,
                style: TextStyle(color: Colors.red, fontSize: 12.sp),
              ),
            ),
        ],
      ),
    );
  }
}

class InfoRow extends StatelessWidget {
  const InfoRow(this.label, this.value, {super.key});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 3.h),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: TextStyle(fontSize: 13.sp)),
          ),
          Text(value, style: TextStyle(fontSize: 13.sp)),
        ],
      ),
    );
  }
}

class SelectField extends StatelessWidget {
  const SelectField({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42.h,
      margin: EdgeInsets.only(bottom: 10.h),
      padding: EdgeInsets.symmetric(horizontal: 12.w),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFD7DCE6)),
        borderRadius: BorderRadius.circular(6.r),
      ),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          const Icon(Icons.arrow_drop_down),
        ],
      ),
    );
  }
}

class ChartPlaceholder extends StatelessWidget {
  const ChartPlaceholder({super.key, required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60.h,
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFD7DCE6)),
        borderRadius: BorderRadius.circular(4.r),
      ),
      child: Center(
        child: Text(
          '波形图',
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w600,
            fontSize: 13.sp,
          ),
        ),
      ),
    );
  }
}

class ColorButton extends StatelessWidget {
  const ColorButton({
    super.key,
    required this.text,
    required this.color,
    required this.icon,
    this.onTap,
  });

  final String text;
  final Color color;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: (1.sw - 44.w) / 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8.r),
        child: Container(
          height: 48.h,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(8.r),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 18.sp),
              SizedBox(width: 8.w),
              Text(
                text,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14.sp,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
