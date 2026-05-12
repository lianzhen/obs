import 'package:flutter/material.dart';
import 'package:myflutter/widgets/common_widgets.dart';

class LockPage extends StatelessWidget {
  const LockPage({super.key, required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return PageShell(
      title: title,
      child: Center(child: Text('$title 页面')),
    );
  }
}
