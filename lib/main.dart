import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:myflutter/core/app_theme.dart';
import 'package:myflutter/l10n/generated/app_localizations.dart';
import 'package:myflutter/pages/main_tab_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(AppTheme.systemUiOverlay);
  
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  runApp(const ObsApp());
}

class ObsApp extends StatelessWidget {
  const ObsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(750, 812),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (_, __) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.obsLight,
          builder: (context, child) {
            return AnnotatedRegion<SystemUiOverlayStyle>(
              value: AppTheme.systemUiOverlay,
              child: child ?? const SizedBox.shrink(),
            );
          },
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          localeListResolutionCallback: (locales, supported) {
            const fallback = Locale('zh');
            if (locales == null || locales.isEmpty) return fallback;
            for (final device in locales) {
              for (final s in supported) {
                if (s.languageCode == device.languageCode) return s;
              }
            }
            return fallback;
          },
          onGenerateTitle: (context) =>
              AppLocalizations.of(context)!.appTitle,
          home: const MainTabPage(),
        );
      },
    );
  }
}
