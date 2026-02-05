import 'package:flutter/material.dart';

class AppColors {
  static const Color background = Color(0xFF0F1723);
  static const Color surface = Color(0xFF1E293B);
  static const Color card = Color(0xFF334155);
  
  static const Color primary = Color(0xFF38BDF8);
  static const Color secondary = Color(0xFF818CF8);
  
  static const Color riskCritical = Color(0xFFF43F5E);
  static const Color riskHigh = Color(0xFFFB923C);
  static const Color riskMedium = Color(0xFFFACC15);
  static const Color riskLow = Color(0xFF4ADE80);
  
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0xFF94A3B8);
}

class AppStyles {
  static const double paddingS = 8.0;
  static const double paddingM = 16.0;
  static const double paddingL = 24.0;
  
  static const double borderRadius = 12.0;

  static final industrialTheme = ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.background,
    cardColor: AppColors.surface,
    primaryColor: AppColors.primary,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.background,
      elevation: 0,
      titleTextStyle: TextStyle(
        color: AppColors.textPrimary,
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
    ),
    textTheme: const TextTheme(
      displayLarge: TextStyle(color: AppColors.textPrimary, fontSize: 32, fontWeight: FontWeight.bold),
      titleLarge: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w600),
      bodyLarge: TextStyle(color: AppColors.textPrimary, fontSize: 16),
      bodyMedium: TextStyle(color: AppColors.textSecondary, fontSize: 14),
    ),
  );
}
