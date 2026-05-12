import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

abstract final class AppTheme {
  AppTheme._();

  static const Color scaffoldBackground = Color(0xFFEFF2F6);

  static const SystemUiOverlayStyle systemUiOverlay = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
    systemNavigationBarColor: scaffoldBackground,
    systemNavigationBarIconBrightness: Brightness.dark,
    systemNavigationBarContrastEnforced: false,
  );

  static ThemeData get obsLight => ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF4C89FF)),
        scaffoldBackgroundColor: scaffoldBackground,
        appBarTheme: AppBarTheme(
          backgroundColor: scaffoldBackground,
          foregroundColor: Colors.black,
          elevation: 0,
          centerTitle: true,
          systemOverlayStyle: systemUiOverlay,
          titleTextStyle: const TextStyle(
            color: Colors.black,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
}
