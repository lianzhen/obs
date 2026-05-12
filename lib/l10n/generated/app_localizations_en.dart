// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Portable OBS Console';

  @override
  String get tabHome => 'Home';

  @override
  String get tabFeature => 'Features';

  @override
  String get tabForm => 'Forms';

  @override
  String get tabComm => 'Comm';

  @override
  String get tabHelp => 'Help';

  @override
  String pageUnderDevelopment(String tabName) {
    return '$tabName — Page under development';
  }

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonSave => 'Save';

  @override
  String get commonConnect => 'Connect';

  @override
  String get commonImport => 'Import';

  @override
  String get commonYes => 'Yes';

  @override
  String get commonNo => 'No';

  @override
  String get homeWorkbench => 'Workbench';

  @override
  String get homeCollectorStatus => 'Collector status';

  @override
  String get homeSeismometerAttitude => 'Seismometer attitude';

  @override
  String get homeInstrumentAttitude => 'Instrument attitude';

  @override
  String get homeChamberTp => 'Chamber temp & pressure';

  @override
  String get homePowerVoltage => 'Power voltage';

  @override
  String get homeInstrumentClock => 'Instrument clock';

  @override
  String get homeDataTransmission => 'Telemetry';

  @override
  String get homeSwitchOn => 'On';

  @override
  String get homeSwitchOff => 'Off';

  @override
  String get homeActionRealtimeWave => 'Realtime waveform';

  @override
  String get homeActionConfigFile => 'Configuration';

  @override
  String get homeActionCommSettings => 'Communication';

  @override
  String get homeActionCommLink => 'Comm link';

  @override
  String get homeActionGps => 'GPS';

  @override
  String get homeActionLockSwing => 'Lock swing';

  @override
  String get homeActionUnlock => 'Unlock';

  @override
  String get homeTagExternalPower => 'External power';

  @override
  String get homeTagCharging => 'Charging';

  @override
  String get homeTagAcousticRelease => 'Acoustic release';

  @override
  String get homeTagClockInit => 'Clock init';

  @override
  String get homeTagTimedRelease => 'Timed release';

  @override
  String get homeTagDataLinkModule => 'Data link module';

  @override
  String get homeTagGpsLock => 'GPS lock';

  @override
  String get homeTagGpsSync => 'GPS sync';

  @override
  String get homeTagCollectStart => 'Acquisition start';

  @override
  String get homeTagSensorLock => 'Sensor lock';

  @override
  String get homeTagFlashOn => 'Flash on';

  @override
  String get homeTagGpsOn => 'GPS on';

  @override
  String get homePitch => 'Pitch';

  @override
  String get homeRoll => 'Roll';

  @override
  String get homeHeading => 'Heading';

  @override
  String get homeRefresh => 'Refresh';

  @override
  String get homeAdjustAttitude => 'Adjust attitude';

  @override
  String homeStandardPressure(String hpa) {
    return 'Std pressure: $hpa hPa';
  }

  @override
  String get homeChamberPressure => 'Chamber pressure';

  @override
  String get homeChamberTemp => 'Chamber temp';

  @override
  String get homeBatteryMain => 'Main battery';

  @override
  String get homeBatteryBackup => 'Backup battery';

  @override
  String get homeBatteryAcoustic => 'Acoustic battery';

  @override
  String get homeDataLinkPort => 'Telemetry port';

  @override
  String get homePcTime => 'PC';

  @override
  String get homePtcTime => 'PTC time';

  @override
  String get homeEvery => 'Every';

  @override
  String get homeMinutesAutoRefresh => 'min auto refresh';

  @override
  String homeDataTxDetail(String link, String gps, String time) {
    return 'Link: $link\nGPS lock: $gps\nLast refresh: $time';
  }

  @override
  String get configPageTitle => 'Configuration';

  @override
  String get configEditCard => 'Edit configuration';

  @override
  String get configHintEditor => 'Edit or view config (text or HEX)';

  @override
  String get configLinkStatus => 'Link: ';

  @override
  String get configWifiConnected => 'WiFi connected';

  @override
  String get configBtConnected => 'Bluetooth connected';

  @override
  String get configDisconnected => 'Disconnected';

  @override
  String configOpStatus(String status) {
    return 'Status: $status';
  }

  @override
  String get configStatusIdle => 'Idle';

  @override
  String get configBtnDownload => 'Download config';

  @override
  String get configBtnImport => 'Import config';

  @override
  String get configBtnUpload => 'Upload config';

  @override
  String get configBtnExport => 'Export config';

  @override
  String get configDialogImportTitle => 'Import configuration file';

  @override
  String get configDialogImportHint => 'Enter path to .cfg file';

  @override
  String get configErrNoChannel =>
      'No communication link. Connect in Comm first.';

  @override
  String get configErrConnectFirst => 'Connect to device first';

  @override
  String get configErrEmptyContent => 'Configuration is empty';

  @override
  String configErrFileNotFound(String path) {
    return 'File not found: $path';
  }

  @override
  String configStatusDownloadOk(String bytes) {
    return 'Download OK: $bytes bytes';
  }

  @override
  String configStatusUploadOk(String bytes) {
    return 'Upload OK: $bytes bytes';
  }

  @override
  String configStatusImportOk(String path) {
    return 'Import OK: $path';
  }

  @override
  String configStatusExportOk(String path) {
    return 'Export OK: $path';
  }

  @override
  String configStatusFail(String error) {
    return 'Failed: $error';
  }

  @override
  String get commPageTitle => 'Communication';

  @override
  String get commModeTitle => 'Mode';

  @override
  String get commWifi => 'WiFi';

  @override
  String get commBluetooth => 'Bluetooth';

  @override
  String get commPresetTitle => 'Presets';

  @override
  String get commPresetHint => 'Select preset to load';

  @override
  String get commSavePreset => 'Save preset';

  @override
  String get commReconnectTitle => 'Reconnect';

  @override
  String get commAutoReconnect => 'Auto reconnect';

  @override
  String commRetryCount(String n) {
    return 'Retries: $n';
  }

  @override
  String commRetryInterval(String sec) {
    return 'Interval: ${sec}s';
  }

  @override
  String get commLinkDevice => 'Connect device';

  @override
  String get commDisconnectDevice => 'Disconnect';

  @override
  String get commSendStatusQuery => 'Send CMD_GET_STATUS';

  @override
  String get commDeviceCommands => 'Device commands';

  @override
  String get commLogTitle => 'Log';

  @override
  String get commLogEmpty => 'No logs';

  @override
  String get commCmdGpsOn => 'GPS on';

  @override
  String get commCmdGpsOff => 'GPS off';

  @override
  String get commCmdAdOn => 'AD on';

  @override
  String get commCmdAdOff => 'AD off';

  @override
  String get commCmdRdoOn => 'Radio on';

  @override
  String get commCmdRdoOff => 'Radio off';

  @override
  String get commCmdFlashOn => 'Flash on';

  @override
  String get commCmdFlashOff => 'Flash off';

  @override
  String get commDialogWifiTitle => 'WiFi data channel';

  @override
  String get commDeviceIp => 'Device IP';

  @override
  String get commPort => 'Port';

  @override
  String get commDialogSavePresetTitle => 'Save connection preset';

  @override
  String get commPresetName => 'Preset name';

  @override
  String commPresetWifiDefault(String ts) {
    return 'WiFi preset-$ts';
  }

  @override
  String commPresetBtDefault(String ts) {
    return 'BT preset-$ts';
  }

  @override
  String get commSnackPresetSaved => 'Preset saved';

  @override
  String get commSnackReconnectSaved => 'Reconnect settings saved';

  @override
  String commSnackBtReady(String name) {
    return 'Bluetooth ready ($name)';
  }

  @override
  String get commSnackConnectBtFirst =>
      'Tap Connect on a device in the Bluetooth list first';

  @override
  String get commSnackWifiDisconnected => 'WiFi channel disconnected';

  @override
  String get commSnackBtDisconnected => 'Bluetooth disconnected';

  @override
  String commSnackWifiConnected(String host, String port) {
    return 'WiFi connected: $host:$port';
  }

  @override
  String commSnackWifiFailed(String error) {
    return 'WiFi failed: $error';
  }

  @override
  String commSnackPresetLoaded(String name) {
    return 'Loaded preset: $name';
  }

  @override
  String commSnackPresetBtLoaded(String name) {
    return 'Loaded Bluetooth preset: $name';
  }

  @override
  String commSnackSendFailed(String error) {
    return 'Send failed: $error';
  }

  @override
  String commSnackCmdSendFailed(String title, String error) {
    return '$title failed: $error';
  }

  @override
  String get gpsPageTitle => 'GPS';

  @override
  String get gpsNmeaType => 'NMEA sentence type';

  @override
  String get gpsSendCommand => 'Send command';

  @override
  String get gpsInfoCard => 'GPS info';

  @override
  String get gpsMapPlaceholder => 'Map area';

  @override
  String get gpsRowGfsdDate => 'GFSD date';

  @override
  String get gpsRowUtc => 'UTC time';

  @override
  String get gpsRowLon => 'Longitude';

  @override
  String get gpsRowLat => 'Latitude';

  @override
  String get gpsRowSpeed => 'Speed (kn)';

  @override
  String get gpsRowSatsInUse => 'Satellites in use';

  @override
  String get gpsRowSatsVisible => 'Visible satellites';

  @override
  String get netErrGeneric => 'Request failed';

  @override
  String get netErrTimeout => 'Connection timed out';

  @override
  String get netErrSendTimeout => 'Send timed out';

  @override
  String get netErrReceiveTimeout => 'Receive timed out';

  @override
  String netErrServer(String code) {
    return 'Server error $code';
  }

  @override
  String get netErrNetwork => 'Network error';

  @override
  String get wifiChartTitle => 'Waveform';

  @override
  String get wifiSectionTitle => 'WiFi';

  @override
  String get wifiConnectedTitle => 'Connected WiFi';

  @override
  String get wifiTooltipRefresh => 'Refresh';

  @override
  String get wifiCurrentNetwork => 'Current network';

  @override
  String get wifiCurrentConnection => 'Current connection';

  @override
  String get wifiPhoneNotConnected => 'Phone not on WiFi';

  @override
  String get wifiUnknownNetwork => 'Unknown network';

  @override
  String get wifiOpenNetwork => 'Open network';

  @override
  String wifiDialogConnectTitle(String ssid) {
    return 'Connect to $ssid';
  }

  @override
  String get wifiPasswordHint => 'WiFi password';

  @override
  String get wifiSnackEnterPassword => 'Enter WiFi password';

  @override
  String wifiSnackConnectOk(String ssid) {
    return 'Connecting: $ssid';
  }

  @override
  String get wifiSnackConnectTimeout => 'Connection timed out. Check WiFi.';

  @override
  String wifiSnackConnectFail(String error) {
    return 'Connection failed: $error';
  }

  @override
  String wifiSnackConnectError(String error) {
    return 'Connection error: $error';
  }

  @override
  String get wifiNotConnected => 'Not connected';

  @override
  String get wifiErrPermission => 'Enable location and nearby WiFi permission';

  @override
  String wifiErrListFail(String error) {
    return 'Failed to load WiFi list: $error';
  }

  @override
  String get btSectionTitle => 'Bluetooth';

  @override
  String get btPairedListTitle => 'Paired / connected (Classic + BLE)';

  @override
  String get btPairedEmpty => 'No paired devices';

  @override
  String get btUnknownDevice => 'Unknown device';

  @override
  String btClassicSubtitle(String address) {
    return 'Classic / $address';
  }

  @override
  String btBleConnectedLine(String id) {
    return 'BLE connected / $id';
  }

  @override
  String btBlePairedLine(String id) {
    return 'BLE paired / $id';
  }

  @override
  String get btSearchTitle => 'Search devices (Classic + BLE)';

  @override
  String get btScanning => 'Scanning…';

  @override
  String get btScanEmpty => 'No devices found';

  @override
  String get btUnknownClassic => 'Unknown classic device';

  @override
  String get btUnknownBle => 'Unknown BLE device';

  @override
  String get btDialogDisabledTitle => 'Bluetooth is off';

  @override
  String get btDialogDisabledBody => 'Turn on Bluetooth to scan and connect.';

  @override
  String get btGoEnable => 'Open settings';

  @override
  String get btConnected => 'Connected';

  @override
  String get btConnect => 'Connect';

  @override
  String get btNameConnectedDevices => 'Connected devices';

  @override
  String btSnackClassicConnected(String name) {
    return 'Classic Bluetooth connected: $name';
  }

  @override
  String btSnackClassicError(String error) {
    return 'Classic Bluetooth error: $error';
  }

  @override
  String btSnackBleConnected(String name) {
    return 'BLE connected: $name';
  }

  @override
  String get btSnackBleAlready => 'BLE device already connected';

  @override
  String btSnackBleError(String error) {
    return 'BLE error: $error';
  }

  @override
  String get btErrPermission => 'Enable Bluetooth permission';

  @override
  String btErrPairedList(String error) {
    return 'Failed to load paired devices: $error';
  }

  @override
  String btErrScan(String error) {
    return 'Bluetooth scan failed: $error';
  }

  @override
  String get btErrPair => 'Classic pairing failed';

  @override
  String get btErrTimeout => 'Connection timed out';

  @override
  String get btErrConnectFailed => 'Connection failed';

  @override
  String get btErrClassicAddrEmpty => 'Classic address is empty';

  @override
  String get btErrBleIdEmpty => 'BLE id is empty';

  @override
  String btErrReconnectFailed(String error) {
    return 'Bluetooth preset reconnect failed: $error';
  }

  @override
  String commErrReconnectFailed(String error) {
    return 'Reconnect failed: $error';
  }
}
