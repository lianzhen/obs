import 'dart:convert';

import 'package:flutter/foundation.dart';

class ObsStatus {
  const ObsStatus({
    required this.collecting,
    required this.gpsLocked,
    required this.dataLinkOn,
    required this.chamberTempC,
    required this.chamberPressureMpa,
    required this.standardPressureHpa,
    required this.pitchDeg,
    required this.rollDeg,
    required this.headingDeg,
    required this.seisPitchDeg,
    required this.seisRollDeg,
    required this.mainBatteryV,
    required this.backupBatteryV,
    required this.acousticBatteryV,
    required this.rtcUtc,
    required this.updatedAt,
  });

  final bool collecting;
  final bool gpsLocked;
  final bool dataLinkOn;
  final double chamberTempC;
  final double chamberPressureMpa;
  final double standardPressureHpa;
  final double pitchDeg;
  final double rollDeg;
  final double headingDeg;
  final double seisPitchDeg;
  final double seisRollDeg;
  final double mainBatteryV;
  final double backupBatteryV;
  final double acousticBatteryV;
  final DateTime rtcUtc;
  final DateTime updatedAt;

  factory ObsStatus.initial() {
    final now = DateTime.now().toUtc();
    return ObsStatus(
      collecting: false,
      gpsLocked: false,
      dataLinkOn: false,
      chamberTempC: 0,
      chamberPressureMpa: 0,
      standardPressureHpa: 1013.25,
      pitchDeg: 0,
      rollDeg: 0,
      headingDeg: 0,
      seisPitchDeg: 0,
      seisRollDeg: 0,
      mainBatteryV: 11.8,
      backupBatteryV: 11.6,
      acousticBatteryV: 11.4,
      rtcUtc: now,
      updatedAt: now,
    );
  }

  ObsStatus copyWith({
    bool? collecting,
    bool? gpsLocked,
    bool? dataLinkOn,
    double? chamberTempC,
    double? chamberPressureMpa,
    double? standardPressureHpa,
    double? pitchDeg,
    double? rollDeg,
    double? headingDeg,
    double? seisPitchDeg,
    double? seisRollDeg,
    double? mainBatteryV,
    double? backupBatteryV,
    double? acousticBatteryV,
    DateTime? rtcUtc,
    DateTime? updatedAt,
  }) {
    return ObsStatus(
      collecting: collecting ?? this.collecting,
      gpsLocked: gpsLocked ?? this.gpsLocked,
      dataLinkOn: dataLinkOn ?? this.dataLinkOn,
      chamberTempC: chamberTempC ?? this.chamberTempC,
      chamberPressureMpa: chamberPressureMpa ?? this.chamberPressureMpa,
      standardPressureHpa: standardPressureHpa ?? this.standardPressureHpa,
      pitchDeg: pitchDeg ?? this.pitchDeg,
      rollDeg: rollDeg ?? this.rollDeg,
      headingDeg: headingDeg ?? this.headingDeg,
      seisPitchDeg: seisPitchDeg ?? this.seisPitchDeg,
      seisRollDeg: seisRollDeg ?? this.seisRollDeg,
      mainBatteryV: mainBatteryV ?? this.mainBatteryV,
      backupBatteryV: backupBatteryV ?? this.backupBatteryV,
      acousticBatteryV: acousticBatteryV ?? this.acousticBatteryV,
      rtcUtc: rtcUtc ?? this.rtcUtc,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class ObsStatusCenter {
  ObsStatusCenter._();
  static final ObsStatusCenter instance = ObsStatusCenter._();

  final ValueNotifier<ObsStatus> status = ValueNotifier<ObsStatus>(ObsStatus.initial());

  void updateFromMap(Map<String, dynamic> data) {
    final old = status.value;
    status.value = old.copyWith(
      collecting: _boolValue(data['collecting'], old.collecting),
      gpsLocked: _boolValue(data['gpsLocked'], old.gpsLocked),
      dataLinkOn: _boolValue(data['dataLinkOn'], old.dataLinkOn),
      chamberTempC: _doubleValue(data['chamberTempC'], old.chamberTempC),
      chamberPressureMpa: _doubleValue(data['chamberPressureMpa'], old.chamberPressureMpa),
      standardPressureHpa: _doubleValue(data['standardPressureHpa'], old.standardPressureHpa),
      pitchDeg: _doubleValue(data['pitchDeg'], old.pitchDeg),
      rollDeg: _doubleValue(data['rollDeg'], old.rollDeg),
      headingDeg: _doubleValue(data['headingDeg'], old.headingDeg),
      seisPitchDeg: _doubleValue(data['seisPitchDeg'], old.seisPitchDeg),
      seisRollDeg: _doubleValue(data['seisRollDeg'], old.seisRollDeg),
      mainBatteryV: _doubleValue(data['mainBatteryV'], old.mainBatteryV),
      backupBatteryV: _doubleValue(data['backupBatteryV'], old.backupBatteryV),
      acousticBatteryV: _doubleValue(data['acousticBatteryV'], old.acousticBatteryV),
      rtcUtc: _dateValue(data['rtcUtc'], old.rtcUtc),
      updatedAt: DateTime.now().toUtc(),
    );
  }

  Map<String, dynamic> tryParseJsonPayload(dynamic raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is String) {
      try {
        final v = jsonDecode(raw);
        if (v is Map<String, dynamic>) return v;
      } catch (_) {}
    }
    return const {};
  }

  static bool _boolValue(dynamic v, bool fallback) {
    if (v is bool) return v;
    if (v is num) return v != 0;
    if (v is String) {
      final s = v.toLowerCase();
      if (s == '1' || s == 'true' || s == 'on') return true;
      if (s == '0' || s == 'false' || s == 'off') return false;
    }
    return fallback;
  }

  static double _doubleValue(dynamic v, double fallback) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? fallback;
    return fallback;
  }

  static DateTime _dateValue(dynamic v, DateTime fallback) {
    if (v is String) return DateTime.tryParse(v)?.toUtc() ?? fallback;
    return fallback;
  }
}
