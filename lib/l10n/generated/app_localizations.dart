import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In zh, this message translates to:
  /// **'便携式OBS交互程序'**
  String get appTitle;

  /// No description provided for @tabHome.
  ///
  /// In zh, this message translates to:
  /// **'首页'**
  String get tabHome;

  /// No description provided for @tabFeature.
  ///
  /// In zh, this message translates to:
  /// **'功能'**
  String get tabFeature;

  /// No description provided for @tabForm.
  ///
  /// In zh, this message translates to:
  /// **'窗体'**
  String get tabForm;

  /// No description provided for @tabComm.
  ///
  /// In zh, this message translates to:
  /// **'通讯'**
  String get tabComm;

  /// No description provided for @tabHelp.
  ///
  /// In zh, this message translates to:
  /// **'帮助'**
  String get tabHelp;

  /// No description provided for @pageUnderDevelopment.
  ///
  /// In zh, this message translates to:
  /// **'{tabName} 页面开发中'**
  String pageUnderDevelopment(String tabName);

  /// No description provided for @commonCancel.
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get commonCancel;

  /// No description provided for @commonSave.
  ///
  /// In zh, this message translates to:
  /// **'保存'**
  String get commonSave;

  /// No description provided for @commonConnect.
  ///
  /// In zh, this message translates to:
  /// **'连接'**
  String get commonConnect;

  /// No description provided for @commonImport.
  ///
  /// In zh, this message translates to:
  /// **'导入'**
  String get commonImport;

  /// No description provided for @commonYes.
  ///
  /// In zh, this message translates to:
  /// **'是'**
  String get commonYes;

  /// No description provided for @commonNo.
  ///
  /// In zh, this message translates to:
  /// **'否'**
  String get commonNo;

  /// No description provided for @homeWorkbench.
  ///
  /// In zh, this message translates to:
  /// **'工作台'**
  String get homeWorkbench;

  /// No description provided for @homeCollectorStatus.
  ///
  /// In zh, this message translates to:
  /// **'采集器状态'**
  String get homeCollectorStatus;

  /// No description provided for @homeSeismometerAttitude.
  ///
  /// In zh, this message translates to:
  /// **'地震计姿态信息'**
  String get homeSeismometerAttitude;

  /// No description provided for @homeInstrumentAttitude.
  ///
  /// In zh, this message translates to:
  /// **'仪器姿态信息'**
  String get homeInstrumentAttitude;

  /// No description provided for @homeChamberTp.
  ///
  /// In zh, this message translates to:
  /// **'舱内温压'**
  String get homeChamberTp;

  /// No description provided for @homePowerVoltage.
  ///
  /// In zh, this message translates to:
  /// **'电源电压'**
  String get homePowerVoltage;

  /// No description provided for @homeInstrumentClock.
  ///
  /// In zh, this message translates to:
  /// **'仪器时钟'**
  String get homeInstrumentClock;

  /// No description provided for @homeDataTransmission.
  ///
  /// In zh, this message translates to:
  /// **'数传信息'**
  String get homeDataTransmission;

  /// No description provided for @homeSwitchOn.
  ///
  /// In zh, this message translates to:
  /// **'开'**
  String get homeSwitchOn;

  /// No description provided for @homeSwitchOff.
  ///
  /// In zh, this message translates to:
  /// **'关'**
  String get homeSwitchOff;

  /// No description provided for @homeActionRealtimeWave.
  ///
  /// In zh, this message translates to:
  /// **'实时波形'**
  String get homeActionRealtimeWave;

  /// No description provided for @homeActionConfigFile.
  ///
  /// In zh, this message translates to:
  /// **'配置文件'**
  String get homeActionConfigFile;

  /// No description provided for @homeActionCommSettings.
  ///
  /// In zh, this message translates to:
  /// **'通讯设置'**
  String get homeActionCommSettings;

  /// No description provided for @homeActionCommLink.
  ///
  /// In zh, this message translates to:
  /// **'通讯链接'**
  String get homeActionCommLink;

  /// No description provided for @homeActionGps.
  ///
  /// In zh, this message translates to:
  /// **'GPS信息'**
  String get homeActionGps;

  /// No description provided for @homeActionLockSwing.
  ///
  /// In zh, this message translates to:
  /// **'锁摆'**
  String get homeActionLockSwing;

  /// No description provided for @homeActionUnlock.
  ///
  /// In zh, this message translates to:
  /// **'解锁'**
  String get homeActionUnlock;

  /// No description provided for @homeTagExternalPower.
  ///
  /// In zh, this message translates to:
  /// **'外接电源'**
  String get homeTagExternalPower;

  /// No description provided for @homeTagCharging.
  ///
  /// In zh, this message translates to:
  /// **'正在充电'**
  String get homeTagCharging;

  /// No description provided for @homeTagAcousticRelease.
  ///
  /// In zh, this message translates to:
  /// **'水声释放启动'**
  String get homeTagAcousticRelease;

  /// No description provided for @homeTagClockInit.
  ///
  /// In zh, this message translates to:
  /// **'时钟初始化'**
  String get homeTagClockInit;

  /// No description provided for @homeTagTimedRelease.
  ///
  /// In zh, this message translates to:
  /// **'时控释放'**
  String get homeTagTimedRelease;

  /// No description provided for @homeTagDataLinkModule.
  ///
  /// In zh, this message translates to:
  /// **'数传模块'**
  String get homeTagDataLinkModule;

  /// No description provided for @homeTagGpsLock.
  ///
  /// In zh, this message translates to:
  /// **'GPS锁定'**
  String get homeTagGpsLock;

  /// No description provided for @homeTagGpsSync.
  ///
  /// In zh, this message translates to:
  /// **'GPS同步'**
  String get homeTagGpsSync;

  /// No description provided for @homeTagCollectStart.
  ///
  /// In zh, this message translates to:
  /// **'采集启动'**
  String get homeTagCollectStart;

  /// No description provided for @homeTagSensorLock.
  ///
  /// In zh, this message translates to:
  /// **'传感器锁定'**
  String get homeTagSensorLock;

  /// No description provided for @homeTagFlashOn.
  ///
  /// In zh, this message translates to:
  /// **'闪光打开'**
  String get homeTagFlashOn;

  /// No description provided for @homeTagGpsOn.
  ///
  /// In zh, this message translates to:
  /// **'GPS开启'**
  String get homeTagGpsOn;

  /// No description provided for @homePitch.
  ///
  /// In zh, this message translates to:
  /// **'俯仰角'**
  String get homePitch;

  /// No description provided for @homeRoll.
  ///
  /// In zh, this message translates to:
  /// **'翻滚角'**
  String get homeRoll;

  /// No description provided for @homeHeading.
  ///
  /// In zh, this message translates to:
  /// **'方位角'**
  String get homeHeading;

  /// No description provided for @homeRefresh.
  ///
  /// In zh, this message translates to:
  /// **'刷新'**
  String get homeRefresh;

  /// No description provided for @homeAdjustAttitude.
  ///
  /// In zh, this message translates to:
  /// **'调姿'**
  String get homeAdjustAttitude;

  /// No description provided for @homeStandardPressure.
  ///
  /// In zh, this message translates to:
  /// **'标准气压: {hpa}hpa'**
  String homeStandardPressure(String hpa);

  /// No description provided for @homeChamberPressure.
  ///
  /// In zh, this message translates to:
  /// **'舱压'**
  String get homeChamberPressure;

  /// No description provided for @homeChamberTemp.
  ///
  /// In zh, this message translates to:
  /// **'舱温'**
  String get homeChamberTemp;

  /// No description provided for @homeBatteryMain.
  ///
  /// In zh, this message translates to:
  /// **'主电池'**
  String get homeBatteryMain;

  /// No description provided for @homeBatteryBackup.
  ///
  /// In zh, this message translates to:
  /// **'备份电池'**
  String get homeBatteryBackup;

  /// No description provided for @homeBatteryAcoustic.
  ///
  /// In zh, this message translates to:
  /// **'水声电池'**
  String get homeBatteryAcoustic;

  /// No description provided for @homeDataLinkPort.
  ///
  /// In zh, this message translates to:
  /// **'数传端口'**
  String get homeDataLinkPort;

  /// No description provided for @homePcTime.
  ///
  /// In zh, this message translates to:
  /// **'PC'**
  String get homePcTime;

  /// No description provided for @homePtcTime.
  ///
  /// In zh, this message translates to:
  /// **'PTC时间'**
  String get homePtcTime;

  /// No description provided for @homeEvery.
  ///
  /// In zh, this message translates to:
  /// **'每'**
  String get homeEvery;

  /// No description provided for @homeMinutesAutoRefresh.
  ///
  /// In zh, this message translates to:
  /// **'分钟自动刷新'**
  String get homeMinutesAutoRefresh;

  /// No description provided for @homeDataTxDetail.
  ///
  /// In zh, this message translates to:
  /// **'链路状态: {link}\nGPS锁定: {gps}\n最后刷新: {time}'**
  String homeDataTxDetail(String link, String gps, String time);

  /// No description provided for @configPageTitle.
  ///
  /// In zh, this message translates to:
  /// **'配置管理'**
  String get configPageTitle;

  /// No description provided for @configEditCard.
  ///
  /// In zh, this message translates to:
  /// **'配置编辑'**
  String get configEditCard;

  /// No description provided for @configHintEditor.
  ///
  /// In zh, this message translates to:
  /// **'这里编辑/查看配置内容（文本或HEX）'**
  String get configHintEditor;

  /// No description provided for @configLinkStatus.
  ///
  /// In zh, this message translates to:
  /// **'链路状态: '**
  String get configLinkStatus;

  /// No description provided for @configWifiConnected.
  ///
  /// In zh, this message translates to:
  /// **'WiFi已连接'**
  String get configWifiConnected;

  /// No description provided for @configBtConnected.
  ///
  /// In zh, this message translates to:
  /// **'蓝牙已连接'**
  String get configBtConnected;

  /// No description provided for @configDisconnected.
  ///
  /// In zh, this message translates to:
  /// **'未连接'**
  String get configDisconnected;

  /// No description provided for @configOpStatus.
  ///
  /// In zh, this message translates to:
  /// **'操作状态: {status}'**
  String configOpStatus(String status);

  /// No description provided for @configStatusIdle.
  ///
  /// In zh, this message translates to:
  /// **'未操作'**
  String get configStatusIdle;

  /// No description provided for @configBtnDownload.
  ///
  /// In zh, this message translates to:
  /// **'下载配置文件'**
  String get configBtnDownload;

  /// No description provided for @configBtnImport.
  ///
  /// In zh, this message translates to:
  /// **'导入配置文件'**
  String get configBtnImport;

  /// No description provided for @configBtnUpload.
  ///
  /// In zh, this message translates to:
  /// **'上传配置文件'**
  String get configBtnUpload;

  /// No description provided for @configBtnExport.
  ///
  /// In zh, this message translates to:
  /// **'导出配置文件'**
  String get configBtnExport;

  /// No description provided for @configDialogImportTitle.
  ///
  /// In zh, this message translates to:
  /// **'导入配置文件'**
  String get configDialogImportTitle;

  /// No description provided for @configDialogImportHint.
  ///
  /// In zh, this message translates to:
  /// **'请输入 .cfg 文件路径'**
  String get configDialogImportHint;

  /// No description provided for @configErrNoChannel.
  ///
  /// In zh, this message translates to:
  /// **'未检测到可用通信链路，请先在通信管理中连接设备'**
  String get configErrNoChannel;

  /// No description provided for @configErrConnectFirst.
  ///
  /// In zh, this message translates to:
  /// **'请先连接设备'**
  String get configErrConnectFirst;

  /// No description provided for @configErrEmptyContent.
  ///
  /// In zh, this message translates to:
  /// **'当前配置内容为空'**
  String get configErrEmptyContent;

  /// No description provided for @configErrFileNotFound.
  ///
  /// In zh, this message translates to:
  /// **'文件不存在: {path}'**
  String configErrFileNotFound(String path);

  /// No description provided for @configStatusDownloadOk.
  ///
  /// In zh, this message translates to:
  /// **'下载成功: {bytes} bytes'**
  String configStatusDownloadOk(String bytes);

  /// No description provided for @configStatusUploadOk.
  ///
  /// In zh, this message translates to:
  /// **'上传成功: {bytes} bytes'**
  String configStatusUploadOk(String bytes);

  /// No description provided for @configStatusImportOk.
  ///
  /// In zh, this message translates to:
  /// **'导入成功: {path}'**
  String configStatusImportOk(String path);

  /// No description provided for @configStatusExportOk.
  ///
  /// In zh, this message translates to:
  /// **'导出成功: {path}'**
  String configStatusExportOk(String path);

  /// No description provided for @configStatusFail.
  ///
  /// In zh, this message translates to:
  /// **'失败: {error}'**
  String configStatusFail(String error);

  /// No description provided for @commPageTitle.
  ///
  /// In zh, this message translates to:
  /// **'通信管理'**
  String get commPageTitle;

  /// No description provided for @commModeTitle.
  ///
  /// In zh, this message translates to:
  /// **'通信方式'**
  String get commModeTitle;

  /// No description provided for @commWifi.
  ///
  /// In zh, this message translates to:
  /// **'WiFi'**
  String get commWifi;

  /// No description provided for @commBluetooth.
  ///
  /// In zh, this message translates to:
  /// **'蓝牙'**
  String get commBluetooth;

  /// No description provided for @commPresetTitle.
  ///
  /// In zh, this message translates to:
  /// **'连接预设'**
  String get commPresetTitle;

  /// No description provided for @commPresetHint.
  ///
  /// In zh, this message translates to:
  /// **'选择并加载预设'**
  String get commPresetHint;

  /// No description provided for @commSavePreset.
  ///
  /// In zh, this message translates to:
  /// **'保存预设'**
  String get commSavePreset;

  /// No description provided for @commReconnectTitle.
  ///
  /// In zh, this message translates to:
  /// **'重连设置'**
  String get commReconnectTitle;

  /// No description provided for @commAutoReconnect.
  ///
  /// In zh, this message translates to:
  /// **'自动重连'**
  String get commAutoReconnect;

  /// No description provided for @commRetryCount.
  ///
  /// In zh, this message translates to:
  /// **'重试次数: {n}'**
  String commRetryCount(String n);

  /// No description provided for @commRetryInterval.
  ///
  /// In zh, this message translates to:
  /// **'间隔: {sec}s'**
  String commRetryInterval(String sec);

  /// No description provided for @commLinkDevice.
  ///
  /// In zh, this message translates to:
  /// **'链接设备'**
  String get commLinkDevice;

  /// No description provided for @commDisconnectDevice.
  ///
  /// In zh, this message translates to:
  /// **'断开设备'**
  String get commDisconnectDevice;

  /// No description provided for @commSendStatusQuery.
  ///
  /// In zh, this message translates to:
  /// **'发送状态查询(CMD_GET_STATUS)'**
  String get commSendStatusQuery;

  /// No description provided for @commDeviceCommands.
  ///
  /// In zh, this message translates to:
  /// **'设备控制指令'**
  String get commDeviceCommands;

  /// No description provided for @commLogTitle.
  ///
  /// In zh, this message translates to:
  /// **'通讯日志'**
  String get commLogTitle;

  /// No description provided for @commLogEmpty.
  ///
  /// In zh, this message translates to:
  /// **'暂无日志'**
  String get commLogEmpty;

  /// No description provided for @commCmdGpsOn.
  ///
  /// In zh, this message translates to:
  /// **'GPS开'**
  String get commCmdGpsOn;

  /// No description provided for @commCmdGpsOff.
  ///
  /// In zh, this message translates to:
  /// **'GPS关'**
  String get commCmdGpsOff;

  /// No description provided for @commCmdAdOn.
  ///
  /// In zh, this message translates to:
  /// **'AD开'**
  String get commCmdAdOn;

  /// No description provided for @commCmdAdOff.
  ///
  /// In zh, this message translates to:
  /// **'AD关'**
  String get commCmdAdOff;

  /// No description provided for @commCmdRdoOn.
  ///
  /// In zh, this message translates to:
  /// **'数传开'**
  String get commCmdRdoOn;

  /// No description provided for @commCmdRdoOff.
  ///
  /// In zh, this message translates to:
  /// **'数传关'**
  String get commCmdRdoOff;

  /// No description provided for @commCmdFlashOn.
  ///
  /// In zh, this message translates to:
  /// **'闪光灯开'**
  String get commCmdFlashOn;

  /// No description provided for @commCmdFlashOff.
  ///
  /// In zh, this message translates to:
  /// **'闪光灯关'**
  String get commCmdFlashOff;

  /// No description provided for @commDialogWifiTitle.
  ///
  /// In zh, this message translates to:
  /// **'连接 WiFi 数据通道'**
  String get commDialogWifiTitle;

  /// No description provided for @commDeviceIp.
  ///
  /// In zh, this message translates to:
  /// **'设备IP'**
  String get commDeviceIp;

  /// No description provided for @commPort.
  ///
  /// In zh, this message translates to:
  /// **'端口'**
  String get commPort;

  /// No description provided for @commDialogSavePresetTitle.
  ///
  /// In zh, this message translates to:
  /// **'保存连接预设'**
  String get commDialogSavePresetTitle;

  /// No description provided for @commPresetName.
  ///
  /// In zh, this message translates to:
  /// **'预设名称'**
  String get commPresetName;

  /// No description provided for @commPresetWifiDefault.
  ///
  /// In zh, this message translates to:
  /// **'WiFi预设-{ts}'**
  String commPresetWifiDefault(String ts);

  /// No description provided for @commPresetBtDefault.
  ///
  /// In zh, this message translates to:
  /// **'蓝牙预设-{ts}'**
  String commPresetBtDefault(String ts);

  /// No description provided for @commSnackPresetSaved.
  ///
  /// In zh, this message translates to:
  /// **'连接预设已保存'**
  String get commSnackPresetSaved;

  /// No description provided for @commSnackReconnectSaved.
  ///
  /// In zh, this message translates to:
  /// **'重连设置已保存'**
  String get commSnackReconnectSaved;

  /// No description provided for @commSnackBtReady.
  ///
  /// In zh, this message translates to:
  /// **'蓝牙链路已可用({name})'**
  String commSnackBtReady(String name);

  /// No description provided for @commSnackConnectBtFirst.
  ///
  /// In zh, this message translates to:
  /// **'请先在蓝牙列表里点击设备“连接”'**
  String get commSnackConnectBtFirst;

  /// No description provided for @commSnackWifiDisconnected.
  ///
  /// In zh, this message translates to:
  /// **'WiFi 通道已断开'**
  String get commSnackWifiDisconnected;

  /// No description provided for @commSnackBtDisconnected.
  ///
  /// In zh, this message translates to:
  /// **'蓝牙通道已断开'**
  String get commSnackBtDisconnected;

  /// No description provided for @commSnackWifiConnected.
  ///
  /// In zh, this message translates to:
  /// **'WiFi 通道已连接: {host}:{port}'**
  String commSnackWifiConnected(String host, String port);

  /// No description provided for @commSnackWifiFailed.
  ///
  /// In zh, this message translates to:
  /// **'WiFi 通道连接失败: {error}'**
  String commSnackWifiFailed(String error);

  /// No description provided for @commSnackPresetLoaded.
  ///
  /// In zh, this message translates to:
  /// **'已加载预设并连接: {name}'**
  String commSnackPresetLoaded(String name);

  /// No description provided for @commSnackPresetBtLoaded.
  ///
  /// In zh, this message translates to:
  /// **'已加载蓝牙预设并连接: {name}'**
  String commSnackPresetBtLoaded(String name);

  /// No description provided for @commSnackSendFailed.
  ///
  /// In zh, this message translates to:
  /// **'发送失败: {error}'**
  String commSnackSendFailed(String error);

  /// No description provided for @commSnackCmdSendFailed.
  ///
  /// In zh, this message translates to:
  /// **'{title} 发送失败: {error}'**
  String commSnackCmdSendFailed(String title, String error);

  /// No description provided for @gpsPageTitle.
  ///
  /// In zh, this message translates to:
  /// **'GPS信息'**
  String get gpsPageTitle;

  /// No description provided for @gpsNmeaType.
  ///
  /// In zh, this message translates to:
  /// **'NMEA语句类型'**
  String get gpsNmeaType;

  /// No description provided for @gpsSendCommand.
  ///
  /// In zh, this message translates to:
  /// **'下发指令'**
  String get gpsSendCommand;

  /// No description provided for @gpsInfoCard.
  ///
  /// In zh, this message translates to:
  /// **'GPS信息'**
  String get gpsInfoCard;

  /// No description provided for @gpsMapPlaceholder.
  ///
  /// In zh, this message translates to:
  /// **'地图区域'**
  String get gpsMapPlaceholder;

  /// No description provided for @gpsRowGfsdDate.
  ///
  /// In zh, this message translates to:
  /// **'GFSD日期'**
  String get gpsRowGfsdDate;

  /// No description provided for @gpsRowUtc.
  ///
  /// In zh, this message translates to:
  /// **'UTC时间'**
  String get gpsRowUtc;

  /// No description provided for @gpsRowLon.
  ///
  /// In zh, this message translates to:
  /// **'经度'**
  String get gpsRowLon;

  /// No description provided for @gpsRowLat.
  ///
  /// In zh, this message translates to:
  /// **'纬度'**
  String get gpsRowLat;

  /// No description provided for @gpsRowSpeed.
  ///
  /// In zh, this message translates to:
  /// **'速度(节)'**
  String get gpsRowSpeed;

  /// No description provided for @gpsRowSatsInUse.
  ///
  /// In zh, this message translates to:
  /// **'正在使用的卫星'**
  String get gpsRowSatsInUse;

  /// No description provided for @gpsRowSatsVisible.
  ///
  /// In zh, this message translates to:
  /// **'非使用的可见卫星'**
  String get gpsRowSatsVisible;

  /// No description provided for @netErrGeneric.
  ///
  /// In zh, this message translates to:
  /// **'请求失败'**
  String get netErrGeneric;

  /// No description provided for @netErrTimeout.
  ///
  /// In zh, this message translates to:
  /// **'连接超时'**
  String get netErrTimeout;

  /// No description provided for @netErrSendTimeout.
  ///
  /// In zh, this message translates to:
  /// **'发送超时'**
  String get netErrSendTimeout;

  /// No description provided for @netErrReceiveTimeout.
  ///
  /// In zh, this message translates to:
  /// **'接收超时'**
  String get netErrReceiveTimeout;

  /// No description provided for @netErrServer.
  ///
  /// In zh, this message translates to:
  /// **'服务器异常 {code}'**
  String netErrServer(String code);

  /// No description provided for @netErrNetwork.
  ///
  /// In zh, this message translates to:
  /// **'网络异常'**
  String get netErrNetwork;

  /// No description provided for @wifiChartTitle.
  ///
  /// In zh, this message translates to:
  /// **'波形图'**
  String get wifiChartTitle;

  /// No description provided for @wifiSectionTitle.
  ///
  /// In zh, this message translates to:
  /// **'WiFi'**
  String get wifiSectionTitle;

  /// No description provided for @wifiConnectedTitle.
  ///
  /// In zh, this message translates to:
  /// **'已连接 WiFi'**
  String get wifiConnectedTitle;

  /// No description provided for @wifiTooltipRefresh.
  ///
  /// In zh, this message translates to:
  /// **'刷新'**
  String get wifiTooltipRefresh;

  /// No description provided for @wifiCurrentNetwork.
  ///
  /// In zh, this message translates to:
  /// **'当前网络'**
  String get wifiCurrentNetwork;

  /// No description provided for @wifiCurrentConnection.
  ///
  /// In zh, this message translates to:
  /// **'当前连接'**
  String get wifiCurrentConnection;

  /// No description provided for @wifiPhoneNotConnected.
  ///
  /// In zh, this message translates to:
  /// **'手机未连接 WiFi'**
  String get wifiPhoneNotConnected;

  /// No description provided for @wifiUnknownNetwork.
  ///
  /// In zh, this message translates to:
  /// **'未知网络'**
  String get wifiUnknownNetwork;

  /// No description provided for @wifiOpenNetwork.
  ///
  /// In zh, this message translates to:
  /// **'开放网络'**
  String get wifiOpenNetwork;

  /// No description provided for @wifiDialogConnectTitle.
  ///
  /// In zh, this message translates to:
  /// **'连接 {ssid}'**
  String wifiDialogConnectTitle(String ssid);

  /// No description provided for @wifiPasswordHint.
  ///
  /// In zh, this message translates to:
  /// **'请输入WiFi密码'**
  String get wifiPasswordHint;

  /// No description provided for @wifiSnackEnterPassword.
  ///
  /// In zh, this message translates to:
  /// **'请输入WiFi密码'**
  String get wifiSnackEnterPassword;

  /// No description provided for @wifiSnackConnectOk.
  ///
  /// In zh, this message translates to:
  /// **'已发起连接: {ssid}'**
  String wifiSnackConnectOk(String ssid);

  /// No description provided for @wifiSnackConnectTimeout.
  ///
  /// In zh, this message translates to:
  /// **'连接超时，请检查设备WiFi是否正常'**
  String get wifiSnackConnectTimeout;

  /// No description provided for @wifiSnackConnectFail.
  ///
  /// In zh, this message translates to:
  /// **'连接失败: {error}'**
  String wifiSnackConnectFail(String error);

  /// No description provided for @wifiSnackConnectError.
  ///
  /// In zh, this message translates to:
  /// **'连接异常: {error}'**
  String wifiSnackConnectError(String error);

  /// No description provided for @wifiNotConnected.
  ///
  /// In zh, this message translates to:
  /// **'未连接'**
  String get wifiNotConnected;

  /// No description provided for @wifiErrPermission.
  ///
  /// In zh, this message translates to:
  /// **'请开启定位与附近WiFi权限'**
  String get wifiErrPermission;

  /// No description provided for @wifiErrListFail.
  ///
  /// In zh, this message translates to:
  /// **'获取WiFi列表失败: {error}'**
  String wifiErrListFail(String error);

  /// No description provided for @btSectionTitle.
  ///
  /// In zh, this message translates to:
  /// **'蓝牙设置'**
  String get btSectionTitle;

  /// No description provided for @btPairedListTitle.
  ///
  /// In zh, this message translates to:
  /// **'已配对/已连接列表(经典+BLE)'**
  String get btPairedListTitle;

  /// No description provided for @btPairedEmpty.
  ///
  /// In zh, this message translates to:
  /// **'暂无已配对设备'**
  String get btPairedEmpty;

  /// No description provided for @btUnknownDevice.
  ///
  /// In zh, this message translates to:
  /// **'未知设备'**
  String get btUnknownDevice;

  /// No description provided for @btClassicSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'经典蓝牙 / {address}'**
  String btClassicSubtitle(String address);

  /// No description provided for @btBleConnectedLine.
  ///
  /// In zh, this message translates to:
  /// **'BLE 已连接 / {id}'**
  String btBleConnectedLine(String id);

  /// No description provided for @btBlePairedLine.
  ///
  /// In zh, this message translates to:
  /// **'BLE 已配对 / {id}'**
  String btBlePairedLine(String id);

  /// No description provided for @btSearchTitle.
  ///
  /// In zh, this message translates to:
  /// **'搜索蓝牙设备(经典+BLE)'**
  String get btSearchTitle;

  /// No description provided for @btScanning.
  ///
  /// In zh, this message translates to:
  /// **'正在扫描...'**
  String get btScanning;

  /// No description provided for @btScanEmpty.
  ///
  /// In zh, this message translates to:
  /// **'未扫描到设备'**
  String get btScanEmpty;

  /// No description provided for @btUnknownClassic.
  ///
  /// In zh, this message translates to:
  /// **'未知经典设备'**
  String get btUnknownClassic;

  /// No description provided for @btUnknownBle.
  ///
  /// In zh, this message translates to:
  /// **'未知BLE设备'**
  String get btUnknownBle;

  /// No description provided for @btDialogDisabledTitle.
  ///
  /// In zh, this message translates to:
  /// **'蓝牙未开启'**
  String get btDialogDisabledTitle;

  /// No description provided for @btDialogDisabledBody.
  ///
  /// In zh, this message translates to:
  /// **'请先开启蓝牙，再进行设备扫描与连接。'**
  String get btDialogDisabledBody;

  /// No description provided for @btGoEnable.
  ///
  /// In zh, this message translates to:
  /// **'去开启'**
  String get btGoEnable;

  /// No description provided for @btConnected.
  ///
  /// In zh, this message translates to:
  /// **'已连接'**
  String get btConnected;

  /// No description provided for @btConnect.
  ///
  /// In zh, this message translates to:
  /// **'连接'**
  String get btConnect;

  /// No description provided for @btNameConnectedDevices.
  ///
  /// In zh, this message translates to:
  /// **'已连接设备'**
  String get btNameConnectedDevices;

  /// No description provided for @btSnackClassicConnected.
  ///
  /// In zh, this message translates to:
  /// **'经典蓝牙已连接: {name}'**
  String btSnackClassicConnected(String name);

  /// No description provided for @btSnackClassicError.
  ///
  /// In zh, this message translates to:
  /// **'经典蓝牙连接异常: {error}'**
  String btSnackClassicError(String error);

  /// No description provided for @btSnackBleConnected.
  ///
  /// In zh, this message translates to:
  /// **'BLE 已连接: {name}'**
  String btSnackBleConnected(String name);

  /// No description provided for @btSnackBleAlready.
  ///
  /// In zh, this message translates to:
  /// **'BLE 设备已连接'**
  String get btSnackBleAlready;

  /// No description provided for @btSnackBleError.
  ///
  /// In zh, this message translates to:
  /// **'BLE 连接异常: {error}'**
  String btSnackBleError(String error);

  /// No description provided for @btErrPermission.
  ///
  /// In zh, this message translates to:
  /// **'请开启蓝牙权限'**
  String get btErrPermission;

  /// No description provided for @btErrPairedList.
  ///
  /// In zh, this message translates to:
  /// **'获取已配对设备失败: {error}'**
  String btErrPairedList(String error);

  /// No description provided for @btErrScan.
  ///
  /// In zh, this message translates to:
  /// **'蓝牙扫描失败: {error}'**
  String btErrScan(String error);

  /// No description provided for @btErrPair.
  ///
  /// In zh, this message translates to:
  /// **'经典蓝牙配对失败'**
  String get btErrPair;

  /// No description provided for @btErrTimeout.
  ///
  /// In zh, this message translates to:
  /// **'连接超时'**
  String get btErrTimeout;

  /// No description provided for @btErrConnectFailed.
  ///
  /// In zh, this message translates to:
  /// **'连接失败'**
  String get btErrConnectFailed;

  /// No description provided for @btErrClassicAddrEmpty.
  ///
  /// In zh, this message translates to:
  /// **'经典蓝牙地址为空'**
  String get btErrClassicAddrEmpty;

  /// No description provided for @btErrBleIdEmpty.
  ///
  /// In zh, this message translates to:
  /// **'BLE id 为空'**
  String get btErrBleIdEmpty;

  /// No description provided for @btErrReconnectFailed.
  ///
  /// In zh, this message translates to:
  /// **'蓝牙预设重连失败: {error}'**
  String btErrReconnectFailed(String error);

  /// No description provided for @commErrReconnectFailed.
  ///
  /// In zh, this message translates to:
  /// **'重连失败: {error}'**
  String commErrReconnectFailed(String error);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
