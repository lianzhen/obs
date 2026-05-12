import 'package:flutter/material.dart';
import 'package:myflutter/widgets/common_widgets.dart';

class WavePage extends StatelessWidget {
  const WavePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const PageShell(
      title: '实时波形',
      child: Center(child: Text('实时波形页面（待接入数据源）')),
    );
  }
}
