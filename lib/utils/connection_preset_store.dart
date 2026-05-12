import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

String _obfuscate(String? plain) {
  if (plain == null || plain.isEmpty) return '';
  const key = 'OBS_APP_FIXED_KEY';
  final src = plain.codeUnits;
  final out = <int>[];
  for (var i = 0; i < src.length; i++) {
    out.add(src[i] ^ key.codeUnitAt(i % key.length));
  }
  return out.map((e) => e.toRadixString(16).padLeft(2, '0')).join();
}

String _deobfuscate(String? enc) {
  if (enc == null || enc.isEmpty) return '';
  const key = 'OBS_APP_FIXED_KEY';
  final bytes = <int>[];
  for (var i = 0; i < enc.length; i += 2) {
    bytes.add(int.parse(enc.substring(i, i + 2), radix: 16));
  }
  final out = <int>[];
  for (var i = 0; i < bytes.length; i++) {
    out.add(bytes[i] ^ key.codeUnitAt(i % key.length));
  }
  return String.fromCharCodes(out);
}

class ConnectionPreset {
  const ConnectionPreset({
    this.id,
    required this.name,
    required this.type,
    this.host,
    this.port,
    this.wifiSsid,
    this.btAddress,
    this.wifiPassword,
    this.btPin,
    required this.createdAt,
  });

  final int? id;
  final String name; 
  final String type; 
  final String? host;
  final int? port;
  final String? wifiSsid;
  final String? btAddress;
  final String? wifiPassword;
  final String? btPin;
  final int createdAt;

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'host': host,
      'port': port,
      'wifi_ssid': wifiSsid,
      'bt_address': btAddress,
      'wifi_password_enc': _obfuscate(wifiPassword),
      'bt_pin_enc': _obfuscate(btPin),
      'created_at': createdAt,
    };
  }

  factory ConnectionPreset.fromMap(Map<String, Object?> map) {
    return ConnectionPreset(
      id: map['id'] as int?,
      name: map['name'] as String,
      type: map['type'] as String,
      host: map['host'] as String?,
      port: map['port'] as int?,
      wifiSsid: map['wifi_ssid'] as String?,
      btAddress: map['bt_address'] as String?,
      wifiPassword: _deobfuscate(map['wifi_password_enc'] as String?),
      btPin: _deobfuscate(map['bt_pin_enc'] as String?),
      createdAt: map['created_at'] as int,
    );
  }
}

class CommSettings {
  const CommSettings({
    required this.retryCount,
    required this.retryIntervalMs,
    required this.autoReconnectEnabled,
  });

  final int retryCount;
  final int retryIntervalMs;
  final bool autoReconnectEnabled;
}

class ConnectionPresetStore {
  ConnectionPresetStore._();
  static final ConnectionPresetStore instance = ConnectionPresetStore._();

  Database? _db;

  Future<Database> _open() async {
    if (_db != null) return _db!;
    final dir = await getApplicationDocumentsDirectory();
    final dbPath = p.join(dir.path, 'obs_app.db');
    _db = await openDatabase(
      dbPath,
      version: 3,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE connection_preset (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL UNIQUE,
            type TEXT NOT NULL,
            host TEXT,
            port INTEGER,
            wifi_ssid TEXT,
            bt_address TEXT,
            wifi_password_enc TEXT,
            bt_pin_enc TEXT,
            created_at INTEGER NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE comm_settings (
            id INTEGER PRIMARY KEY CHECK (id = 1),
            retry_count INTEGER NOT NULL,
            retry_interval_ms INTEGER NOT NULL,
            auto_reconnect_enabled INTEGER NOT NULL DEFAULT 1
          )
        ''');
        await db.insert('comm_settings', {
          'id': 1,
          'retry_count': 3,
          'retry_interval_ms': 2000,
          'auto_reconnect_enabled': 1,
        });
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE connection_preset ADD COLUMN wifi_password_enc TEXT');
          await db.execute('ALTER TABLE connection_preset ADD COLUMN bt_pin_enc TEXT');
          await db.execute('''
            CREATE TABLE IF NOT EXISTS comm_settings (
              id INTEGER PRIMARY KEY CHECK (id = 1),
              retry_count INTEGER NOT NULL,
              retry_interval_ms INTEGER NOT NULL,
              auto_reconnect_enabled INTEGER NOT NULL DEFAULT 1
            )
          ''');
          final rows = await db.query('comm_settings', where: 'id = 1');
          if (rows.isEmpty) {
            await db.insert('comm_settings', {
              'id': 1,
              'retry_count': 3,
              'retry_interval_ms': 2000,
              'auto_reconnect_enabled': 1,
            });
          }
        }
        if (oldVersion < 3) {
          await db.execute('ALTER TABLE comm_settings ADD COLUMN auto_reconnect_enabled INTEGER NOT NULL DEFAULT 1');
        }
      },
    );
    return _db!;
  }

  Future<void> upsert(ConnectionPreset preset) async {
    final db = await _open();
    await db.insert(
      'connection_preset',
      preset.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<ConnectionPreset>> all() async {
    final db = await _open();
    final rows = await db.query(
      'connection_preset',
      where: 'type IN (?, ?)',
      whereArgs: const ['wifi', 'bluetooth'],
      orderBy: 'created_at DESC',
    );
    return rows.map(ConnectionPreset.fromMap).toList();
  }

  Future<void> saveWifiCredential({
    required String ssid,
    required String password,
  }) async {
    if (ssid.trim().isEmpty || password.trim().isEmpty) return;
    await upsert(
      ConnectionPreset(
        name: 'wifi_credential::$ssid',
        type: 'wifi_credential',
        wifiSsid: ssid,
        wifiPassword: password,
        createdAt: DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  Future<String?> loadWifiCredential(String ssid) async {
    if (ssid.trim().isEmpty) return null;
    final db = await _open();
    final rows = await db.query(
      'connection_preset',
      where: 'type = ? AND wifi_ssid = ?',
      whereArgs: ['wifi_credential', ssid],
      orderBy: 'created_at DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final preset = ConnectionPreset.fromMap(rows.first);
    final pwd = (preset.wifiPassword ?? '').trim();
    return pwd.isEmpty ? null : pwd;
  }

  Future<CommSettings> loadCommSettings() async {
    final db = await _open();
    final rows = await db.query('comm_settings', where: 'id = 1');
    if (rows.isEmpty) {
      return const CommSettings(
        retryCount: 3,
        retryIntervalMs: 2000,
        autoReconnectEnabled: true,
      );
    }
    final row = rows.first;
    return CommSettings(
      retryCount: (row['retry_count'] as int?) ?? 3,
      retryIntervalMs: (row['retry_interval_ms'] as int?) ?? 2000,
      autoReconnectEnabled: ((row['auto_reconnect_enabled'] as int?) ?? 1) == 1,
    );
  }

  Future<void> saveCommSettings(CommSettings settings) async {
    final db = await _open();
    await db.insert(
      'comm_settings',
      {
        'id': 1,
        'retry_count': settings.retryCount,
        'retry_interval_ms': settings.retryIntervalMs,
        'auto_reconnect_enabled': settings.autoReconnectEnabled ? 1 : 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
