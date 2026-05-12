import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:myflutter/widgets/common_widgets.dart';

class GpsPage extends StatefulWidget {
  const GpsPage({super.key});

  @override
  State<GpsPage> createState() => _GpsPageState();
}

class _GpsPageState extends State<GpsPage> {
  String type = 'GGA';

  @override
  Widget build(BuildContext context) {
    return PageShell(
      title: 'GPS信息',
      child: ListView(
        children: [
          CardContainer(
            title: 'NMEA语句类型',
            child: Wrap(
              spacing: 16.w,
              runSpacing: 8.h,
              children: ['GGA', 'GLL', 'GSA', 'GSV']
                  .map((e) => CheckTile(label: e, selected: type == e, onTap: () => setState(() => type = e)))
                  .toList(),
            ),
          ),
          SizedBox(height: 12.h),
          const GradientButton(text: '下发指令', icon: Icons.send),
          SizedBox(height: 12.h),
          Container(
            padding: EdgeInsets.all(10.r),
            decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(6.r)),
            child: Text(
              r'$GPRMC,161420.000,.....',
              style: TextStyle(color: Colors.white, fontSize: 12.sp),
            ),
          ),
          SizedBox(height: 12.h),
          const CardContainer(
            title: 'GPS信息',
            child: Column(
              children: [
                InfoRow('GFSD日期', '2025/9/16'),
                InfoRow('UTC时间', '2025/9/16 2:08:03'),
                InfoRow('经度', '117.338793333333'),
                InfoRow('纬度', '39.1041616666667'),
                InfoRow('速度(节)', '0km/h'),
                InfoRow('正在使用的卫星', '8颗'),
                InfoRow('非使用的可见卫星', '9颗'),
              ],
            ),
          ),
          SizedBox(height: 12.h),
          Container(
            height: 220.h,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10.r),
              border: Border.all(color: const Color(0xFFD8DEE8)),
            ),
            child: const Center(child: Text('地图区域')),
          ),
        ],
      ),
    );
  }
}
