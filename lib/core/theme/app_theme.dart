import 'package:flutter/material.dart';

class AppColors {
  const AppColors._();

  static const Color gold = Color(0xFFD4AF37);
  static const Color goldDark = Color(0xFF9C7A12);
  static const Color ink = Color(0xFF0B0B0F);
  static const Color surfaceDark = Color(0xFF16161D);
  static const Color paper = Color(0xFFFAF7EF);
}

ThemeData buildTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final scheme = ColorScheme(
    brightness: brightness,
    primary: dark ? AppColors.gold : AppColors.goldDark,
    onPrimary: dark ? Colors.black : Colors.white,
    secondary: AppColors.gold,
    onSecondary: Colors.black,
    error: dark ? const Color(0xFFCF6679) : const Color(0xFFB3261E),
    onError: dark ? Colors.black : Colors.white,
    surface: dark ? AppColors.surfaceDark : Colors.white,
    onSurface: dark ? const Color(0xFFF2EBD9) : const Color(0xFF1B1B1F),
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: dark ? AppColors.ink : AppColors.paper,
    // يعود إلى خط النظام إن لم تُضمَّن ملفات Cairo بعد.
    fontFamily: 'Cairo',
    appBarTheme: AppBarTheme(
      centerTitle: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      foregroundColor: scheme.onSurface,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
  );
}
