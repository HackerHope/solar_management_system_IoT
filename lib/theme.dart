
import "package:flutter/material.dart";

// Shared color palette matching the web application's App.css.
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

  // Additional presentation colors.
  static const elevatedPanel = Color(0xFF17243A);
  static const subtleSurface = Color(0xFF0B1424);
  static const onlineSurface = Color(0x1F22C55E);
  static const indigoSurface = Color(0x1F4F46E5);
}

ThemeData buildAppTheme() {
  const borderRadius = 14.0;

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.background,
    primaryColor: AppColors.accentIndigo,
    fontFamily: "Roboto",

    colorScheme: const ColorScheme.dark(
      primary: AppColors.accentIndigo,
      secondary: AppColors.online,
      surface: AppColors.panel,
      error: AppColors.offline,
      onPrimary: Colors.white,
      onSecondary: Color(0xFF07111F),
      onSurface: Colors.white,
      onError: Colors.white,
    ),

    cardColor: AppColors.panel,

    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.background,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
      scrolledUnderElevation: 0,
    ),

    dividerTheme: const DividerThemeData(
      color: AppColors.panelBorder,
      thickness: 1,
      space: 1,
    ),

    bottomNavigationBarTheme:
        const BottomNavigationBarThemeData(
      backgroundColor: AppColors.sidebarBg,
      selectedItemColor: AppColors.accentIndigoHover,
      unselectedItemColor: AppColors.textMuted,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
    ),

    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.sidebarBg,
      indicatorColor: AppColors.indigoSurface,
      elevation: 0,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontSize: 12,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w600
              : FontWeight.w400,
          color: states.contains(WidgetState.selected)
              ? AppColors.accentIndigoHover
              : AppColors.textMuted,
        ),
      ),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.subtleSurface,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 15,
        vertical: 14,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(borderRadius),
        borderSide: const BorderSide(
          color: AppColors.panelBorder,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(borderRadius),
        borderSide: const BorderSide(
          color: AppColors.panelBorder,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(borderRadius),
        borderSide: const BorderSide(
          color: AppColors.accentIndigoHover,
          width: 1.5,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(borderRadius),
        borderSide: const BorderSide(
          color: AppColors.offline,
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(borderRadius),
        borderSide: const BorderSide(
          color: AppColors.offline,
          width: 1.5,
        ),
      ),
      hintStyle: const TextStyle(
        color: AppColors.textMuted,
        fontSize: 13,
      ),
      labelStyle: const TextStyle(
        color: AppColors.textMuted,
        fontSize: 13,
      ),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.accentIndigo,
        foregroundColor: Colors.white,
        disabledBackgroundColor: AppColors.panelBorder,
        disabledForegroundColor: AppColors.textMuted,
        elevation: 0,
        padding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 14,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        textStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side: const BorderSide(
          color: AppColors.panelBorder,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 13,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    ),

    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return AppColors.online;
        }
        return AppColors.textMuted;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return AppColors.onlineSurface;
        }
        return AppColors.panelBorder;
      }),
      trackOutlineColor: WidgetStateProperty.all(
        Colors.transparent,
      ),
    ),

    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.accentIndigoHover,
      linearTrackColor: AppColors.panelBorder,
    ),

    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.elevatedPanel,
      contentTextStyle: const TextStyle(
        color: Colors.white,
        fontSize: 13,
      ),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    ),

    textTheme: const TextTheme(
      headlineSmall: TextStyle(
        color: Colors.white,
        fontSize: 24,
        fontWeight: FontWeight.bold,
      ),
      titleLarge: TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
      titleMedium: TextStyle(
        color: Colors.white,
        fontSize: 15,
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: TextStyle(
        color: AppColors.textBody,
        fontSize: 14,
      ),
      bodyMedium: TextStyle(
        color: Colors.white,
        fontSize: 13,
      ),
      bodySmall: TextStyle(
        color: AppColors.textMuted,
        fontSize: 12,
      ),
      labelLarge: TextStyle(
        color: Colors.white,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

// Shared card decoration used across dashboard panels.
BoxDecoration panelDecoration() {
  return BoxDecoration(
    color: AppColors.panel,
    border: Border.all(
      color: AppColors.panelBorder,
    ),
    borderRadius: BorderRadius.circular(20),
  );
}
