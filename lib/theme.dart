import "package:flutter/material.dart";

// Colors pulled straight from the web app's App.css so both apps feel the same.
class AppColors {
  static const background = Color(0xFF07111F);
  static const panel = Color(0xFF111C30);
  static const panelBorder = Color(0xFF243047);
  static const sidebarBg = Color(0xFF101B31);
  static const accentIndigo = Color(0xFF4F46E5);
  static const accentIndigoHover = Color(0xFF6366F1);
  static const online = Color(0xFF22C55E);
  static const offline = Color(0xFFEF4444);
  static const textMuted = Color(0xFF9CA3AF);
  static const textBody = Color(0xFFD1D5DB);
  static const voltageLine = Color(0xFF4F7CFF);
  static const currentLine = Color(0xFF4ADE80);
  static const powerFill = Color(0xFFA855F7);
  static const warning = Color(0xFFF59E0B);
}

ThemeData buildAppTheme() {
  return ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.background,
    primaryColor: AppColors.accentIndigo,
    colorScheme: ColorScheme.dark(
      primary: AppColors.accentIndigo,
      secondary: AppColors.online,
      surface: AppColors.panel,
      error: AppColors.offline,
    ),
    fontFamily: "Roboto",
    cardColor: AppColors.panel,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.background,
      foregroundColor: Colors.white,
      elevation: 0,
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.sidebarBg,
      selectedItemColor: AppColors.accentIndigo,
      unselectedItemColor: AppColors.textMuted,
      type: BottomNavigationBarType.fixed,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF0B1424),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.panelBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.panelBorder),
      ),
      contentPadding: const EdgeInsets.all(14),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.accentIndigo,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    textTheme: const TextTheme(
      bodyMedium: TextStyle(color: Colors.white),
    ),
  );
}

// Shared card decoration used across panels, matching .panel in App.css
BoxDecoration panelDecoration() {
  return BoxDecoration(
    color: AppColors.panel,
    border: Border.all(color: AppColors.panelBorder),
    borderRadius: BorderRadius.circular(20),
  );
}
