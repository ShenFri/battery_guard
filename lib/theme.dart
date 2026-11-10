import 'package:flutter/material.dart';

class AppColors {
  static const bg = Color(0xFF070B14);
  static const card = Color(0xFF111827);
  static const cardBorder = Color(0xFF1F2A3D);
  static const textPrimary = Color(0xFFF1F5F9);
  static const textSecondary = Color(0xFF8A97AD);
  static const green = Color(0xFF22E3A0);
  static const cyan = Color(0xFF3BC9FF);
  static const amber = Color(0xFFFFB84D);
  static const red = Color(0xFFFF5C6C);

  /// 根据电量返回主题色
  static Color forLevel(int level, {bool charging = false}) {
    if (charging) return cyan;
    if (level <= 20) return red;
    if (level <= 40) return amber;
    return green;
  }
}

ThemeData buildTheme() {
  final base = ThemeData.dark(useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: AppColors.bg,
    colorScheme: base.colorScheme.copyWith(
      primary: AppColors.green,
      surface: AppColors.card,
    ),
    textTheme: base.textTheme.apply(
      bodyColor: AppColors.textPrimary,
      displayColor: AppColors.textPrimary,
    ),
    sliderTheme: base.sliderTheme.copyWith(
      activeTrackColor: AppColors.cyan,
      thumbColor: AppColors.cyan,
      inactiveTrackColor: AppColors.cardBorder,
    ),
  );
}
