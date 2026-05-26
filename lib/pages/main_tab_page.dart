import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:myflutter/pages/communication_manage_page.dart';
import 'package:myflutter/pages/home_page.dart';
import 'package:myflutter/pages/simple_tab_page.dart';

abstract final class _BottomNavIconAssets {
  
  static const String bottomBarBackground = 'assets/images/dibu.png';

  static const String homeNormal = 'assets/images/tab_home_normal.png';
  static const String homeSelected = 'assets/images/tab_home_selected.png';
  static const String funcNormal = 'assets/images/tab_func_normal.png';
  static const String funcSelected = 'assets/images/tab_func_selected.png';
  static const String formNormal = 'assets/images/tab_form_normal.png';
  static const String formSelected = 'assets/images/tab_form_selected.png';
  static const String commNormal = 'assets/images/tab_comm_normal.png';
  static const String commSelected = 'assets/images/tab_comm_selected.png';
  static const String helpNormal = 'assets/images/tab_help_normal.png';
  static const String helpSelected = 'assets/images/tab_help_selected.png';
}

class MainTabPage extends StatefulWidget {
  const MainTabPage({super.key});

  @override
  State<MainTabPage> createState() => _MainTabPageState();
}

class _MainTabPageState extends State<MainTabPage> {
  int _currentIndex = 0;

  final List<Widget> _tabs = const [
    HomePage(),
    SimpleTabPage(title: '功能'),
    SimpleTabPage(title: '窗体'),
    CommunicationManagePage(),
    SimpleTabPage(title: '帮助'),
  ];

  Widget _navImage(String asset, double size) {
    return Image.asset(
      asset,
      width: size,
      height: size,
      gaplessPlayback: true,
      fit: BoxFit.contain,
    );
  }

  BottomNavigationBarItem _navItem({
    required String normal,
    required String selected,
    required String label,
  }) {
    final size = 28.w;
    return BottomNavigationBarItem(
      icon: _navImage(normal, size),
      activeIcon: _navImage(selected, size),
      label: label,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      
      body: SafeArea(
        top: false,
        bottom: false,
        child: IndexedStack(
          index: _currentIndex,
          sizing: StackFit.expand,
          clipBehavior: Clip.none,
          children: _tabs,
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage(_BottomNavIconAssets.bottomBarBackground),
            fit: BoxFit.cover,
            alignment: Alignment.center,
          ),
        ),
        child: BottomNavigationBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          currentIndex: _currentIndex,
          type: BottomNavigationBarType.fixed,
          selectedFontSize: 20.sp,
          unselectedFontSize: 20.sp,
          selectedItemColor: const Color(0xFF4E86FF),
          unselectedItemColor: const Color(0xFF9FA7B5),
          onTap: (index) => setState(() => _currentIndex = index),
          items: [
            _navItem(
              normal: _BottomNavIconAssets.homeNormal,
              selected: _BottomNavIconAssets.homeSelected,
              label: '首页',
            ),
            _navItem(
              normal: _BottomNavIconAssets.funcNormal,
              selected: _BottomNavIconAssets.funcSelected,
              label: '功能',
            ),
            _navItem(
              normal: _BottomNavIconAssets.formNormal,
              selected: _BottomNavIconAssets.formSelected,
              label: '窗体',
            ),
            _navItem(
              normal: _BottomNavIconAssets.commNormal,
              selected: _BottomNavIconAssets.commSelected,
              label: '通讯',
            ),
            _navItem(
              normal: _BottomNavIconAssets.helpNormal,
              selected: _BottomNavIconAssets.helpSelected,
              label: '帮助',
            ),
          ],
        ),
      ),
    );
  }
}
