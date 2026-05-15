import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:myflutter/pages/communication_page.dart';
import 'package:myflutter/pages/config_page.dart';
import 'package:myflutter/pages/gps_page.dart';
import 'package:myflutter/pages/lock_page.dart';
import 'package:myflutter/pages/wave_page.dart';
import 'package:myflutter/l10n/generated/app_localizations.dart';
import 'package:myflutter/utils/obs_status_center.dart';

import 'communication_manage_page.dart';

abstract final class _HomePageFonts {
  static const int appBarTitle = 34;
  static const int cardTitle = 26;
  static const int collectorTag = 20;
  static const int workbenchLabel = 26;
  static const int expandChevron = 44;
  static const int sp26 = 26;
  static const int sp30 = 30;
}

const String _kHomeTopBackgroundAsset = 'assets/images/bjt.png';
const double _kHomeTopBackgroundHeight = 710;

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final ObsStatusCenter _statusCenter = ObsStatusCenter.instance;
  final Map<String, bool> _expand = {
    '采集器状态': true,
    '地震计姿态信息': true,
    '仪器姿态信息': true,
    '舱内温压': true,
    '电源电压': true,
    '仪器时钟': true,
    '数传信息': true,
  };

  String _yn(bool value) => value ? '开' : '关';

  String _time(DateTime utc) {
    final local = utc.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} ${two(local.hour)}:${two(local.minute)}:${two(local.second)}';
  }

  String _voltagePercent(double value, {double full = 12.6}) {
    final p = ((value / full) * 100).clamp(0, 100).toStringAsFixed(0);
    return '$p%';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final actions = [
      ActionItem('实时波形', const WavePage(), 'assets/images/boxing.png'),
      ActionItem('配置文件', const ConfigPage(), 'assets/images/peizhi.png'),
      ActionItem('通讯设置', const CommunicationManagePage(), 'assets/images/shezhi.png'),
      ActionItem(
        '通讯链接',
        const CommunicationPage(),
        'assets/images/lianjie.png',
      ),

      ActionItem('GPS信息', const GpsPage(), 'assets/images/gps.png'),
      ActionItem('锁摆', const LockPage(title: '锁摆'), 'assets/images/suobai.png'),
      ActionItem('解锁', const LockPage(title: '解锁'), 'assets/images/jiesuo.png'),
    ];

    final topOverlay = MediaQuery.viewPaddingOf(context).top;

    return Material(
      color: const Color(0xFFEFF2F6),
      child: Stack(
        fit: StackFit.expand,

        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: -topOverlay,
            left: 0,
            right: 0,
            height: _kHomeTopBackgroundHeight.h + topOverlay,
            child: Image.asset(
              _kHomeTopBackgroundAsset,
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
            ),
          ),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(32.w, 15.w, 32.w, 24.w),
                  child: Text(
                    l10n.appTitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: _HomePageFonts.appBarTitle.sp,
                      fontWeight: FontWeight.w700,
                      color: Colors.black,
                    ),
                  ),
                ),
                Expanded(
                  child: ValueListenableBuilder<ObsStatus>(
                    valueListenable: _statusCenter.status,
                    builder: (_, st, _) => ListView(
                      padding: EdgeInsets.fromLTRB(32.w, 60.w, 32.w, 32.w),
                      children: [
                        _WorkbenchCard(actions: actions),
                        SizedBox(height: 47.w),

                        _CollectorStatusCard(
                          expanded: _expand['采集器状态']!,
                          onToggle: () => setState(
                            () => _expand['采集器状态'] = !_expand['采集器状态']!,
                          ),
                          status: st,
                        ),
                        SizedBox(height: 20.w),

                        _SeismometerAttitudeCard(
                          expanded: _expand['地震计姿态信息']!,
                          onToggle: () => setState(
                            () => _expand['地震计姿态信息'] = !_expand['地震计姿态信息']!,
                          ),
                          pitchDeg: st.seisPitchDeg,
                          rollDeg: st.seisRollDeg,
                        ),
                        SizedBox(height: 20.w),
                        _InstrumentAttitudeCard(
                          expanded: _expand['仪器姿态信息']!,
                          onToggle: () => setState(
                            () => _expand['仪器姿态信息'] = !_expand['仪器姿态信息']!,
                          ),
                          pitchDeg: st.pitchDeg,
                          rollDeg: st.rollDeg,
                          headingDeg: st.headingDeg,
                        ),
                        SizedBox(height: 20.w),
                        _ChamberTpCard(
                          expanded: _expand['舱内温压']!,
                          onToggle: () => setState(
                            () => _expand['舱内温压'] = !_expand['舱内温压']!,
                          ),
                          standardPressureHpa: st.standardPressureHpa,
                          chamberTempC: st.chamberTempC,
                          chamberPressureMpa: st.chamberPressureMpa,
                        ),
                        SizedBox(height: 15.w),
                        _PowerVoltageCard(
                          expanded: _expand['电源电压']!,
                          onToggle: () => setState(
                            () => _expand['电源电压'] = !_expand['电源电压']!,
                          ),
                          mainPct: _voltagePercent(st.mainBatteryV),
                          backupPct: _voltagePercent(st.backupBatteryV),
                          acousticPct: _voltagePercent(st.acousticBatteryV),
                        ),
                        SizedBox(height: 15.w),
                        _InstrumentClockCard(
                          expanded: _expand['仪器时钟']!,
                          onToggle: () => setState(
                            () => _expand['仪器时钟'] = !_expand['仪器时钟']!,
                          ),
                          beijingTime: _time(DateTime.now().toUtc()),
                          rtcTime: _time(st.rtcUtc),
                        ),
                        SizedBox(height: 18.w),
                        _DataTransmissionCard(
                          expanded: _expand['数传信息']!,
                          onToggle: () => setState(
                            () => _expand['数传信息'] = !_expand['数传信息']!,
                          ),
                          detailText:
                              '链路状态: ${_yn(st.dataLinkOn)}\nGPS锁定: ${_yn(st.gpsLocked)}\n最后刷新: ${_time(st.updatedAt)}',
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ActionItem {
  ActionItem(this.label, this.page, this.imageAsset);

  final String label;
  final Widget page;
  final String imageAsset;
}

class _CollectorStatusCard extends StatelessWidget {
  const _CollectorStatusCard({
    required this.expanded,
    required this.onToggle,
    required this.status,
  });

  final bool expanded;
  final VoidCallback onToggle;
  final ObsStatus status;

  static const _labels = <String>[
    '外接电源',
    '正在充电',
    '水声释放启动',
    '时钟初始化',
    '时控释放',
    '数传模块',
    'GPS锁定',
    'GPS同步',
    '采集启动',
    '传感器锁定',
    '闪光打开',
    'GPS开启',
  ];

  static bool _activeForIndex(int i, ObsStatus st) {
    switch (i) {
      case 5:
        return st.dataLinkOn;
      case 6:
        return !st.gpsLocked;
      case 8:
        return st.collecting;
      default:
        return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final radius = 8.w;
    final header = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onToggle,
        child: Container(
          height: 80.w,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFFFFFFF), Color(0xFFE8F1F8)],
            ),
            borderRadius: BorderRadius.vertical(top: Radius.circular(radius)),
          ),
          padding: EdgeInsets.only(left: 24.w, right: 26.w),
          child: Row(
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '采集器状态',
                    textAlign: TextAlign.left,
                    style: TextStyle(
                      fontSize: _HomePageFonts.sp30.sp,
                      fontWeight: FontWeight.w700,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
              Icon(
                expanded ? Icons.expand_less : Icons.expand_more,
                color: Colors.black54,
                size: _HomePageFonts.expandChevron.sp,
              ),
            ],
          ),
        ),
      ),
    );
    if (!expanded) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: header,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        header,
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xFFFAFBFD),
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(radius),
              bottomRight: Radius.circular(radius),
            ),
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(22.w, 20.w, 22.w, 34.w),
            child: Wrap(
              spacing: 20.w,
              runSpacing: 30.w,
              alignment: WrapAlignment.start,
              crossAxisAlignment: WrapCrossAlignment.start,
              children: [
                for (var i = 0; i < _labels.length; i++)
                  _CollectorTag(
                    label: _labels[i],
                    active: _activeForIndex(i, status),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CollectorTag extends StatelessWidget {
  const _CollectorTag({required this.label, required this.active});

  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final c = active ? const Color(0xFFFF0000) : const Color(0xFF207D00);
    return Container(
      width: 140.w,
      height: 56.w,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        border: Border.all(color: c, width: 2.w),
        borderRadius: BorderRadius.circular(4.w),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: _HomePageFonts.collectorTag.sp, color: c),
      ),
    );
  }
}

class _HomePanelChrome extends StatelessWidget {
  const _HomePanelChrome({
    required this.title,
    this.headerSubtitle,
    required this.expanded,
    required this.onToggle,
    required this.child,
  });

  final String title;
  final String? headerSubtitle;
  final bool expanded;
  final VoidCallback onToggle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final radius = 8.w;
    final header = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onToggle,
        child: Container(
          height: 80.w,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFFFFFFF), Color(0xFFE8F1F8)],
            ),
            borderRadius: BorderRadius.vertical(top: Radius.circular(radius)),
          ),
          padding: EdgeInsets.only(left: 24.w, right: 8.w),
          child: Row(
            children: [
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: _HomePageFonts.sp30.sp,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                      ),
                    ),
                    if (headerSubtitle != null &&
                        headerSubtitle!.isNotEmpty) ...[
                      SizedBox(width: 16.w),
                      Expanded(
                        child: Text(
                          headerSubtitle!,
                          style: TextStyle(
                            fontSize: _HomePageFonts.collectorTag.sp,
                            color: Colors.black54,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                expanded ? Icons.expand_less : Icons.expand_more,
                color: Colors.black54,
                size: _HomePageFonts.expandChevron.sp,
              ),
            ],
          ),
        ),
      ),
    );
    if (!expanded) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: header,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        header,
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xFFFAFBFD),
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(radius),
              bottomRight: Radius.circular(radius),
            ),
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(22.w, 20.w, 22.w, 34.w),
            child: child,
          ),
        ),
      ],
    );
  }
}

class _SeismometerAttitudeCard extends StatelessWidget {
  const _SeismometerAttitudeCard({
    required this.expanded,
    required this.onToggle,
    required this.pitchDeg,
    required this.rollDeg,
  });

  final bool expanded;
  final VoidCallback onToggle;
  final double pitchDeg;
  final double rollDeg;

  @override
  Widget build(BuildContext context) {
    return _HomePanelChrome(
      title: '地震计姿态信息',
      expanded: expanded,
      onToggle: onToggle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SeismoDataRow(label: '俯仰角', value: '$pitchDeg°'),
          SizedBox(height: 20.w),
          _SeismoDataRow(label: '翻滚角', value: '$rollDeg°'),
          SizedBox(height: 20.w),
          Row(
            children: [
              Expanded(
                child: _SeismoOutlineButton(
                  icon: 'assets/images/shuaxin.png',
                  label: '刷新',
                  onTap: () {},
                ),
              ),
              SizedBox(width: 37.w),
              Expanded(
                child: _SeismoOutlineButton(
                  icon: 'assets/images/tiaozi.png',
                  label: '调姿',
                  onTap: () {},
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InstrumentAttitudeCard extends StatelessWidget {
  const _InstrumentAttitudeCard({
    required this.expanded,
    required this.onToggle,
    required this.pitchDeg,
    required this.rollDeg,
    required this.headingDeg,
  });

  final bool expanded;
  final VoidCallback onToggle;
  final double pitchDeg;
  final double rollDeg;
  final double headingDeg;

  @override
  Widget build(BuildContext context) {
    return _HomePanelChrome(
      title: '仪器姿态信息',
      expanded: expanded,
      onToggle: onToggle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SeismoDataRow(
            label: '俯仰角',
            value: '${pitchDeg.toStringAsFixed(1)}°',
          ),
          SizedBox(height: 10.w),
          _SeismoDataRow(label: '翻滚角', value: '${rollDeg.toStringAsFixed(1)}°'),
          SizedBox(height: 10.w),
          _SeismoDataRow(
            label: '方位角',
            value: '${headingDeg.toStringAsFixed(1)}°',
          ),
          SizedBox(height: 12.w),
          Row(
            children: [
              Expanded(
                child: _SeismoOutlineButton(
                  icon: 'assets/images/shuaxin.png',
                  label: '刷新',
                  onTap: () {},
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: _SeismoOutlineButton(
                  icon: 'assets/images/tiaozi.png',
                  label: '调姿',
                  onTap: () {},
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ChamberTpCard extends StatelessWidget {
  const _ChamberTpCard({
    required this.expanded,
    required this.onToggle,
    required this.standardPressureHpa,
    required this.chamberTempC,
    required this.chamberPressureMpa,
  });

  final bool expanded;
  final VoidCallback onToggle;
  final double standardPressureHpa;
  final double chamberTempC;
  final double chamberPressureMpa;

  @override
  Widget build(BuildContext context) {
    return _HomePanelChrome(
      title: '舱内温压',
      headerSubtitle: '标准气压: ${standardPressureHpa.toStringAsFixed(2)}hpa',
      expanded: expanded,
      onToggle: onToggle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SeismoDataRow(
            label: '舱压',
            value: '${chamberPressureMpa.toStringAsFixed(3)}MPa',
          ),
          SizedBox(height: 20.w),
          _SeismoDataRow(
            label: '舱温',
            value: '${chamberTempC.toStringAsFixed(1)}℃',
          ),
          SizedBox(height: 32.w),
          SizedBox(
            width: double.infinity,
            child: _SeismoOutlineButton(
              icon: 'assets/images/shuaxin.png',
              label: '刷新',
              onTap: () {},
            ),
          ),
        ],
      ),
    );
  }
}

class _PowerVoltageCard extends StatelessWidget {
  const _PowerVoltageCard({
    required this.expanded,
    required this.onToggle,
    required this.mainPct,
    required this.backupPct,
    required this.acousticPct,
  });

  final bool expanded;
  final VoidCallback onToggle;
  final String mainPct;
  final String backupPct;
  final String acousticPct;

  @override
  Widget build(BuildContext context) {
    return _HomePanelChrome(
      title: '电源电压',
      expanded: expanded,
      onToggle: onToggle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SeismoDataRow(label: '主电池', value: mainPct),
          SizedBox(height: 10.w),
          _SeismoDataRow(label: '备份电池', value: backupPct),
          SizedBox(height: 10.w),
          _SeismoDataRow(label: '水声电池', value: acousticPct),
          SizedBox(height: 12.w),
          SizedBox(
            width: double.infinity,
            child: _SeismoOutlineButton(
              icon: 'assets/images/shuaxin.png',
              label: '刷新',
              onTap: () {},
            ),
          ),
        ],
      ),
    );
  }
}

class _DataTransmissionCard extends StatelessWidget {
  const _DataTransmissionCard({
    required this.expanded,
    required this.onToggle,
    required this.detailText,
  });

  final bool expanded;
  final VoidCallback onToggle;
  final String detailText;

  @override
  Widget build(BuildContext context) {
    final labelStyle = TextStyle(
      fontSize: _HomePageFonts.cardTitle.sp,
      color: const Color(0xFF323232),
    );
    final bodyStyle = TextStyle(
      fontSize: _HomePageFonts.cardTitle.sp,
      color: const Color(0xFF323232),
      height: 1.45,
    );
    return _HomePanelChrome(
      title: '数传信息',
      expanded: expanded,
      onToggle: onToggle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {},
              borderRadius: BorderRadius.circular(4.w),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 24.w),
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFD7D7D7), width: 1.w),
                  borderRadius: BorderRadius.circular(4.w),
                ),
                child: Row(
                  children: [
                    Text('数传端口', style: labelStyle),
                    const Spacer(),
                    Icon(Icons.swap_vert, color: Colors.black54, size: 28.w),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(height: 12.w),
          Container(
            constraints: BoxConstraints(minHeight: 400.w),
            padding: EdgeInsets.all(20.w),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFD7D7D7), width: 1.w),
              borderRadius: BorderRadius.circular(4.w),
            ),
            alignment: Alignment.topLeft,
            child: Text(detailText, style: bodyStyle),
          ),
        ],
      ),
    );
  }
}

class _InstrumentClockCard extends StatefulWidget {
  const _InstrumentClockCard({
    required this.expanded,
    required this.onToggle,
    required this.beijingTime,
    required this.rtcTime,
  });

  final bool expanded;
  final VoidCallback onToggle;
  final String beijingTime;
  final String rtcTime;

  @override
  State<_InstrumentClockCard> createState() => _InstrumentClockCardState();
}

class _InstrumentClockCardState extends State<_InstrumentClockCard> {
  int _autoRefreshMinutes = 3;
  static const int _minMinutes = 1;
  static const int _maxMinutes = 99;

  @override
  Widget build(BuildContext context) {
    final labelStyle = TextStyle(
      fontSize: _HomePageFonts.cardTitle.sp,
      color: const Color(0xFF323232),
    );
    return _HomePanelChrome(
      title: '仪器时钟',
      expanded: widget.expanded,
      onToggle: widget.onToggle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _InstrumentDateRow(
            label: 'PC',
            value: widget.beijingTime,
            icon: 'assets/images/shijian.png',
          ),
          SizedBox(height: 10.w),
          _InstrumentDateRow(
            label: 'PTC时间',
            value: widget.rtcTime,
            icon: 'assets/images/shijian.png',
          ),
          SizedBox(height: 29.w),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text('每', style: labelStyle),
              SizedBox(width: 24.w),
              _ClockMinuteStepper(
                value: _autoRefreshMinutes,
                onChanged: (v) => setState(
                  () => _autoRefreshMinutes = v.clamp(_minMinutes, _maxMinutes),
                ),
              ),
              SizedBox(width: 24.w),
              Expanded(
                child: Text(
                  '分钟自动刷新',
                  style: labelStyle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          SizedBox(height: 12.w),
        ],
      ),
    );
  }
}

class _ClockMinuteStepper extends StatelessWidget {
  const _ClockMinuteStepper({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final h = 64.w;
    final side = 100.w;
    final midW = 160.w;
    final gap = 15.w;
    final cellDeco = BoxDecoration(
      border: Border.all(color: const Color(0xFFD7D7D7), width: 1.w),
      borderRadius: BorderRadius.circular(4.w),
    );
    final textStyle = TextStyle(
      fontSize: _HomePageFonts.cardTitle.sp,
      color: const Color(0xFF323232),
      fontWeight: FontWeight.w600,
    );

    void step(int delta) {
      onChanged(value + delta);
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => step(-1),
            borderRadius: BorderRadius.circular(4.w),
            child: Container(
              width: side,
              height: h,
              alignment: Alignment.center,
              decoration: cellDeco,
              child: Text('-', style: textStyle),
            ),
          ),
        ),
        SizedBox(width: gap),
        Container(
          width: midW,
          height: h,
          alignment: Alignment.center,
          decoration: cellDeco,
          child: Text('$value', style: textStyle),
        ),
        SizedBox(width: gap),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => step(1),
            borderRadius: BorderRadius.circular(4.w),
            child: Container(
              width: side,
              height: h,
              alignment: Alignment.center,
              decoration: cellDeco,
              child: Text('+', style: textStyle),
            ),
          ),
        ),
      ],
    );
  }
}

class _SeismoDataRow extends StatelessWidget {
  const _SeismoDataRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 24.w),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFD7D7D7), width: 1.w),
        borderRadius: BorderRadius.circular(4.w),
      ),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: _HomePageFonts.cardTitle.sp,
              color: Colors.black87,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: _HomePageFonts.cardTitle.sp,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}

class _SeismoOutlineButton extends StatelessWidget {
  const _SeismoOutlineButton({this.icon, this.label, required this.onTap});

  final String? icon;
  final String? label;
  final VoidCallback onTap;

  static const Color _blue = Color(0xFF4E86FF);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(4.w),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4.w),
        child: Container(
          height: 56.w,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8.w),
            border: Border.all(color: _blue, width: 1.w),
            color: Colors.white,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Image.asset(
                  icon!,
                  fit: BoxFit.contain,
                  width: 30.w,
                  height: 30.w,
                ),
              ],
              if (icon != null && label != null && label!.isNotEmpty) ...[
                SizedBox(width: 16.w),
              ],
              if (label != null && label!.isNotEmpty)
                Text(
                  label!,
                  style: TextStyle(
                    fontSize: _HomePageFonts.workbenchLabel.sp,
                    color: _blue,
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InstrumentDateRow extends StatelessWidget {
  const _InstrumentDateRow({
    required this.label,
    required this.value,
    this.icon,
  });

  final String label;
  final String value;
  final String? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 24.w),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFD7D7D7), width: 1.w),
        borderRadius: BorderRadius.circular(4.w),
      ),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: _HomePageFonts.cardTitle.sp,
              color: const Color(0xFF323232),
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: _HomePageFonts.cardTitle.sp,
              color: const Color(0xFF323232),
            ),
          ),
          if (icon != null) ...[
            Padding(
              padding: EdgeInsets.only(left: 35.w),
              child: Image.asset(
                icon!,
                fit: BoxFit.contain,
                width: 28.w,
                height: 28.w,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _WorkbenchCard extends StatelessWidget {
  const _WorkbenchCard({required this.actions});

  final List<ActionItem> actions;

  @override
  Widget build(BuildContext context) {
    final radius = 8.w;
    return Column(
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
            '工作台',
            textAlign: TextAlign.left,
            style: TextStyle(
              fontSize: _HomePageFonts.sp30.sp,
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
          child: Padding(
            padding: EdgeInsets.fromLTRB(36.w, 32.w, 36.w, 46.w),
            child: Wrap(
              alignment: WrapAlignment.start,
              crossAxisAlignment: WrapCrossAlignment.start,
              spacing: 60.w,
              runSpacing: 54.w,
              children: actions
                  .map(
                    (item) => SizedBox(
                      width: 106.w,
                      child: ActionButton(
                        item: item,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => item.page),
                          );
                        },
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
      ],
    );
  }
}

class ActionButton extends StatelessWidget {
  const ActionButton({super.key, required this.item, required this.onTap});

  final ActionItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        width: double.infinity,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 80.w,
              height: 80.w,
              child: Image.asset(item.imageAsset, fit: BoxFit.contain),
            ),
            SizedBox(height: 18.w),
            Text(
              item.label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: _HomePageFonts.workbenchLabel.sp,
                color: const Color(0xFF323232),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
