import 'package:flutter/material.dart';

/// Noor palette — midnight teal, emerald glass and warm gold.
class AppColors {
  static const midnight = Color(0xFF031517);
  static const deepTeal = Color(0xFF062A2C);
  static const emerald = Color(0xFF0E6B5C);
  static const aqua = Color(0xFF4FE3CF);
  static const gold = Color(0xFFE6BE72);
  static const goldDeep = Color(0xFFB8893E);
  static const ivory = Color(0xFFF7F1E3);
  static const textSoft = Color(0xB3F7F1E3);
  static const textFaint = Color(0x73F7F1E3);
  static const danger = Color(0xFFFF7A7A);

  static const goldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFFE3A3), gold, goldDeep],
  );

  static const auroraGradient = LinearGradient(
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
    colors: [Color(0xFF4FE3CF), Color(0xFF0E6B5C), Color(0xFF062A2C)],
  );
}

class AppFonts {
  static const ui = 'Tajawal';
  static const arabic = 'Amiri';
  static const quran = 'AmiriQuran';
}

class AppTheme {
  static ThemeData get dark {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: AppFonts.ui,
      scaffoldBackgroundColor: AppColors.midnight,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.gold,
        secondary: AppColors.aqua,
        surface: AppColors.deepTeal,
        onPrimary: AppColors.midnight,
        onSurface: AppColors.ivory,
      ),
      splashFactory: InkSparkle.splashFactory,
    );
    return base.copyWith(
      textTheme: base.textTheme.apply(
        bodyColor: AppColors.ivory,
        displayColor: AppColors.ivory,
        fontFamily: AppFonts.ui,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        foregroundColor: AppColors.ivory,
        titleTextStyle: TextStyle(
          fontFamily: AppFonts.ui,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppColors.ivory,
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? AppColors.midnight : AppColors.ivory,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? AppColors.gold : Colors.white24,
        ),
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: AppColors.gold,
        thumbColor: AppColors.gold,
        inactiveTrackColor: Colors.white24,
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.deepTeal,
        contentTextStyle: TextStyle(fontFamily: AppFonts.ui, color: AppColors.ivory),
      ),
    );
  }
}
