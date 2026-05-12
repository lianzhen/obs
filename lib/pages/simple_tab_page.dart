import 'package:flutter/material.dart';
import 'package:myflutter/l10n/generated/app_localizations.dart';

class SimpleTabPage extends StatelessWidget {
  const SimpleTabPage({super.key, required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    return SafeArea(
      child: Center(child: Text(l10n.pageUnderDevelopment(title))),
    );
  }
}
