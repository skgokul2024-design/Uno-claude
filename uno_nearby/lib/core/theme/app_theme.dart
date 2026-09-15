import 'package:flutter/material.dart';
import '../../models/card_model.dart';

class AppColors {
  AppColors._();
  static const red = Color(0xFFE53935);
  static const blue = Color(0xFF1E88E5);
  static const green = Color(0xFF43A047);
  static const yellow = Color(0xFFFDD835);
  static const wildDark = Color(0xFF212121);

  static Color forCardColor(CardColor c) {
    switch (c) {
      case CardColor.red:
        return red;
      case CardColor.blue:
        return blue;
      case CardColor.green:
        return green;
      case CardColor.yellow:
        return yellow;
      case CardColor.wild:
        return wildDark;
    }
  }
}

class AppTheme {
  AppTheme._();

  static ThemeData light() => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorSchemeSeed: AppColors.red,
        scaffoldBackgroundColor: const Color(0xFFF7F3EE),
        textTheme: const TextTheme().apply(fontFamilyFallback: const ['Roboto']),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 24),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 3,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
      );

  static ThemeData dark() => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: AppColors.red,
        scaffoldBackgroundColor: const Color(0xFF14171A),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 24),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 3,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
      );
}
