// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => '便携式OBS交互程序';

  @override
  String get tabHome => '首页';

  @override
  String get tabFeature => '功能';

  @override
  String get tabForm => '窗体';

  @override
  String get tabComm => '通讯';

  @override
  String get tabHelp => '帮助';

  @override
  String pageUnderDevelopment(String tabName) {
    return '$tabName 页面开发中';
  }

  @override
  String get commonCancel => '取消';

  @override
  String get commonSave => '保存';

  @override
  String get commonConnect => '连接';

  @override
  String get commonImport => '导入';

  @override
  String get commonYes => '是';

  @override
  String get commonNo => '否';

  @override
  String get homeWorkbench => '工作台';

  @override
  String get homeCollectorStatus => '采集器状态';

  @override
  String get homeSeismometerAttitude => '地震计姿态信息';

  @override
  String get homeInstrumentAttitude => '仪器姿态信息';

  @override
  String get homeChamberTp => '舱内温压';

  @override
  String get homePowerVoltage => '电源电压';

  @override
  String get homeInstrumentClock => '仪器时钟';

  @override
  String get homeDataTransmission => '数传信息';

  @override
  String get homeSwitchOn => '开';

  @override
  String get homeSwitchOff => '关';

  @override
  String get homeActionRealtimeWave => '实时波形';

  @override
  String get homeActionConfigFile => '配置文件';

  @override
  String get homeActionCommSettings => '通讯设置';

  @override
  String get homeActionCommLink => '通讯链接';

  @override
  String get homeActionGps => 'GPS信息';

  @override
  String get homeActionLockSwing => '锁摆';

  @override
  String get homeActionUnlock => '解锁';

  @override
  String get homeTagExternalPower => '外接电源';

  @override
  String get homeTagCharging => '正在充电';

  @override
  String get homeTagAcousticRelease => '水声释放启动';

  @override
  String get homeTagClockInit => '时钟初始化';

  @override
  String get homeTagTimedRelease => '时控释放';

  @override
  String get homeTagDataLinkModule => '数传模块';

  @override
  String get homeTagGpsLock => 'GPS锁定';

  @override
  String get homeTagGpsSync => 'GPS同步';

  @override
  String get homeTagCollectStart => '采集启动';

  @override
  String get homeTagSensorLock => '传感器锁定';

  @override
  String get homeTagFlashOn => '闪光打开';

  @override
  String get homeTagGpsOn => 'GPS开启';

  @override
  String get homePitch => '俯仰角';

  @override
  String get homeRoll => '翻滚角';

  @override
  String get homeHeading => '方位角';

  @override
  String get homeRefresh => '刷新';

  @override
  String get homeAdjustAttitude => '调姿';

  @override
  String homeStandardPressure(String hpa) {
    return '标准气压: ${hpa}hpa';
  }

  @override
  String get homeChamberPressure => '舱压';

  @override
  String get homeChamberTemp => '舱温';

  @override
  String get homeBatteryMain => '主电池';

  @override
  String get homeBatteryBackup => '备份电池';

  @override
  String get homeBatteryAcoustic => '水声电池';

  @override
  String get homeDataLinkPort => '数传端口';

  @override
  String get homePcTime => 'PC';

  @override
  String get homePtcTime => 'PTC时间';

  @override
  String get homeEvery => '每';

  @override
  String get homeMinutesAutoRefresh => '分钟自动刷新';

  @override
  String homeDataTxDetail(String link, String gps, String time) {
    return '链路状态: $link\nGPS锁定: $gps\n最后刷新: $time';
  }

  @override
  String get configPageTitle => '配置管理';

  @override
  String get configEditCard => '配置编辑';

  @override
  String get configHintEditor => '这里编辑/查看配置内容（文本或HEX）';

  @override
  String get configLinkStatus => '链路状态: ';

  @override
  String get configWifiConnected => 'WiFi已连接';

  @override
  String get configBtConnected => '蓝牙已连接';

  @override
  String get configDisconnected => '未连接';

  @override
  String configOpStatus(String status) {
    return '操作状态: $status';
  }

  @override
  String get configStatusIdle => '未操作';

  @override
  String get configBtnDownload => '下载配置文件';

  @override
  String get configBtnImport => '导入配置文件';

  @override
  String get configBtnUpload => '上传配置文件';

  @override
  String get configBtnExport => '导出配置文件';

  @override
  String get configDialogImportTitle => '导入配置文件';

  @override
  String get configDialogImportHint => '请输入 .cfg 文件路径';

  @override
  String get configErrNoChannel => '未检测到可用通信链路，请先在通信管理中连接设备';

  @override
  String get configErrConnectFirst => '请先连接设备';

  @override
  String get configErrEmptyContent => '当前配置内容为空';

  @override
  String configErrFileNotFound(String path) {
    return '文件不存在: $path';
  }

  @override
  String configStatusDownloadOk(String bytes) {
    return '下载成功: $bytes bytes';
  }

  @override
  String configStatusUploadOk(String bytes) {
    return '上传成功: $bytes bytes';
  }

  @override
  String configStatusImportOk(String path) {
    return '导入成功: $path';
  }

  @override
  String configStatusExportOk(String path) {
    return '导出成功: $path';
  }

  @override
  String configStatusFail(String error) {
    return '失败: $error';
  }

  @override
  String get commPageTitle => '通信管理';

  @override
  String get commModeTitle => '通信方式';

  @override
  String get commWifi => 'WiFi';

  @override
  String get commBluetooth => '蓝牙';

  @override
  String get commPresetTitle => '连接预设';

  @override
  String get commPresetHint => '选择并加载预设';

  @override
  String get commSavePreset => '保存预设';

  @override
  String get commReconnectTitle => '重连设置';

  @override
  String get commAutoReconnect => '自动重连';

  @override
  String commRetryCount(String n) {
    return '重试次数: $n';
  }

  @override
  String commRetryInterval(String sec) {
    return '间隔: ${sec}s';
  }

  @override
  String get commLinkDevice => '链接设备';

  @override
  String get commDisconnectDevice => '断开设备';

  @override
  String get commSendStatusQuery => '发送状态查询(CMD_GET_STATUS)';

  @override
  String get commDeviceCommands => '设备控制指令';

  @override
  String get commLogTitle => '通讯日志';

  @override
  String get commLogEmpty => '暂无日志';

  @override
  String get commCmdGpsOn => 'GPS开';

  @override
  String get commCmdGpsOff => 'GPS关';

  @override
  String get commCmdAdOn => 'AD开';

  @override
  String get commCmdAdOff => 'AD关';

  @override
  String get commCmdRdoOn => '数传开';

  @override
  String get commCmdRdoOff => '数传关';

  @override
  String get commCmdFlashOn => '闪光灯开';

  @override
  String get commCmdFlashOff => '闪光灯关';

  @override
  String get commDialogWifiTitle => '连接 WiFi 数据通道';

  @override
  String get commDeviceIp => '设备IP';

  @override
  String get commPort => '端口';

  @override
  String get commDialogSavePresetTitle => '保存连接预设';

  @override
  String get commPresetName => '预设名称';

  @override
  String commPresetWifiDefault(String ts) {
    return 'WiFi预设-$ts';
  }

  @override
  String commPresetBtDefault(String ts) {
    return '蓝牙预设-$ts';
  }

  @override
  String get commSnackPresetSaved => '连接预设已保存';

  @override
  String get commSnackReconnectSaved => '重连设置已保存';

  @override
  String commSnackBtReady(String name) {
    return '蓝牙链路已可用($name)';
  }

  @override
  String get commSnackConnectBtFirst => '请先在蓝牙列表里点击设备“连接”';

  @override
  String get commSnackWifiDisconnected => 'WiFi 通道已断开';

  @override
  String get commSnackBtDisconnected => '蓝牙通道已断开';

  @override
  String commSnackWifiConnected(String host, String port) {
    return 'WiFi 通道已连接: $host:$port';
  }

  @override
  String commSnackWifiFailed(String error) {
    return 'WiFi 通道连接失败: $error';
  }

  @override
  String commSnackPresetLoaded(String name) {
    return '已加载预设并连接: $name';
  }

  @override
  String commSnackPresetBtLoaded(String name) {
    return '已加载蓝牙预设并连接: $name';
  }

  @override
  String commSnackSendFailed(String error) {
    return '发送失败: $error';
  }

  @override
  String commSnackCmdSendFailed(String title, String error) {
    return '$title 发送失败: $error';
  }

  @override
  String get gpsPageTitle => 'GPS信息';

  @override
  String get gpsNmeaType => 'NMEA语句类型';

  @override
  String get gpsSendCommand => '下发指令';

  @override
  String get gpsInfoCard => 'GPS信息';

  @override
  String get gpsMapPlaceholder => '地图区域';

  @override
  String get gpsRowGfsdDate => 'GFSD日期';

  @override
  String get gpsRowUtc => 'UTC时间';

  @override
  String get gpsRowLon => '经度';

  @override
  String get gpsRowLat => '纬度';

  @override
  String get gpsRowSpeed => '速度(节)';

  @override
  String get gpsRowSatsInUse => '正在使用的卫星';

  @override
  String get gpsRowSatsVisible => '非使用的可见卫星';

  @override
  String get netErrGeneric => '请求失败';

  @override
  String get netErrTimeout => '连接超时';

  @override
  String get netErrSendTimeout => '发送超时';

  @override
  String get netErrReceiveTimeout => '接收超时';

  @override
  String netErrServer(String code) {
    return '服务器异常 $code';
  }

  @override
  String get netErrNetwork => '网络异常';

  @override
  String get wifiChartTitle => '波形图';

  @override
  String get wifiSectionTitle => 'WiFi';

  @override
  String get wifiConnectedTitle => '已连接 WiFi';

  @override
  String get wifiTooltipRefresh => '刷新';

  @override
  String get wifiCurrentNetwork => '当前网络';

  @override
  String get wifiCurrentConnection => '当前连接';

  @override
  String get wifiPhoneNotConnected => '手机未连接 WiFi';

  @override
  String get wifiUnknownNetwork => '未知网络';

  @override
  String get wifiOpenNetwork => '开放网络';

  @override
  String wifiDialogConnectTitle(String ssid) {
    return '连接 $ssid';
  }

  @override
  String get wifiPasswordHint => '请输入WiFi密码';

  @override
  String get wifiSnackEnterPassword => '请输入WiFi密码';

  @override
  String wifiSnackConnectOk(String ssid) {
    return '已发起连接: $ssid';
  }

  @override
  String get wifiSnackConnectTimeout => '连接超时，请检查设备WiFi是否正常';

  @override
  String wifiSnackConnectFail(String error) {
    return '连接失败: $error';
  }

  @override
  String wifiSnackConnectError(String error) {
    return '连接异常: $error';
  }

  @override
  String get wifiNotConnected => '未连接';

  @override
  String get wifiErrPermission => '请开启定位与附近WiFi权限';

  @override
  String wifiErrListFail(String error) {
    return '获取WiFi列表失败: $error';
  }

  @override
  String get btSectionTitle => '蓝牙设置';

  @override
  String get btPairedListTitle => '已配对/已连接列表(经典+BLE)';

  @override
  String get btPairedEmpty => '暂无已配对设备';

  @override
  String get btUnknownDevice => '未知设备';

  @override
  String btClassicSubtitle(String address) {
    return '经典蓝牙 / $address';
  }

  @override
  String btBleConnectedLine(String id) {
    return 'BLE 已连接 / $id';
  }

  @override
  String btBlePairedLine(String id) {
    return 'BLE 已配对 / $id';
  }

  @override
  String get btSearchTitle => '搜索蓝牙设备(经典+BLE)';

  @override
  String get btScanning => '正在扫描...';

  @override
  String get btScanEmpty => '未扫描到设备';

  @override
  String get btUnknownClassic => '未知经典设备';

  @override
  String get btUnknownBle => '未知BLE设备';

  @override
  String get btDialogDisabledTitle => '蓝牙未开启';

  @override
  String get btDialogDisabledBody => '请先开启蓝牙，再进行设备扫描与连接。';

  @override
  String get btGoEnable => '去开启';

  @override
  String get btConnected => '已连接';

  @override
  String get btConnect => '连接';

  @override
  String get btNameConnectedDevices => '已连接设备';

  @override
  String btSnackClassicConnected(String name) {
    return '经典蓝牙已连接: $name';
  }

  @override
  String btSnackClassicError(String error) {
    return '经典蓝牙连接异常: $error';
  }

  @override
  String btSnackBleConnected(String name) {
    return 'BLE 已连接: $name';
  }

  @override
  String get btSnackBleAlready => 'BLE 设备已连接';

  @override
  String btSnackBleError(String error) {
    return 'BLE 连接异常: $error';
  }

  @override
  String get btErrPermission => '请开启蓝牙权限';

  @override
  String btErrPairedList(String error) {
    return '获取已配对设备失败: $error';
  }

  @override
  String btErrScan(String error) {
    return '蓝牙扫描失败: $error';
  }

  @override
  String get btErrPair => '经典蓝牙配对失败';

  @override
  String get btErrTimeout => '连接超时';

  @override
  String get btErrConnectFailed => '连接失败';

  @override
  String get btErrClassicAddrEmpty => '经典蓝牙地址为空';

  @override
  String get btErrBleIdEmpty => 'BLE id 为空';

  @override
  String btErrReconnectFailed(String error) {
    return '蓝牙预设重连失败: $error';
  }

  @override
  String commErrReconnectFailed(String error) {
    return '重连失败: $error';
  }
}
