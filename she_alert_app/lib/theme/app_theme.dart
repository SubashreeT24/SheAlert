import 'package:flutter/material.dart';

class AppColors {
  static const bg = Color(0xFF0A0E0D);
  static const cardBg = Color(0xFF11211C);
  static const cardBorder = Color(0xFF1E3A33);
  static const teal = Color(0xFF2DD4BF);
  static const tealDark = Color(0xFF14B8A6);
  static const red = Color(0xFFEF4444);
  static const redDark = Color(0xFFB91C1C);
  static const textPrimary = Colors.white;
  static const textSecondary = Color(0xFF8A9A96);
}

class AppTheme {
  static ThemeData get dark {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.bg,
      fontFamily: 'Roboto',
      colorScheme: const ColorScheme.dark(
        primary: AppColors.teal,
        error: AppColors.red,
        surface: AppColors.cardBg,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.bg,
        selectedItemColor: AppColors.teal,
        unselectedItemColor: AppColors.textSecondary,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }

  static BoxDecoration card({Color? glow}) => BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: glow != null
            ? [BoxShadow(
                color: glow.withOpacity(0.15),
                blurRadius: 20,
                spreadRadius: 1,
              )]
            : null,
      );
}