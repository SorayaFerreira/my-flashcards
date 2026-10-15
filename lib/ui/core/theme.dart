import 'package:flutter/material.dart';

abstract final class AppColors {
  static const magenta = Color(0xFFC52DC3);
  static const pink = Color(0xFFF05BD3);
}

ThemeData buildLightTheme() => ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: AppColors.magenta)
          .copyWith(primary: AppColors.magenta, onPrimary: Colors.white),
    );

ThemeData buildDarkTheme() => ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.magenta,
        brightness: Brightness.dark,
      ).copyWith(primary: AppColors.pink, onPrimary: Colors.black),
    );
