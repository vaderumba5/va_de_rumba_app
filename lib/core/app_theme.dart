import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

abstract final class AppColors {
  static const appBackground = Color(0xFFF7F7F7),
      contentSurface = Color(0xFFFFFFFF),
      topBarBackground = Color(0xFFF1F1F1),
      sidebarBackground = Color(0xFFE8E8E8),
      navigationBackground = Color(0xFFE8E8E8),
      menuItemBackground = Colors.transparent,
      menuItemHover = Color(0xFFDDDDDD),
      menuItemSelected = Color(0xFFD2D2D2),
      cardBackground = Color(0xFFFFFFFF),
      panelBackground = Color(0xFFFCFCFC),
      textPrimary = Color(0xFF151515),
      textSecondary = Color(0xFF5F5F5F),
      textMuted = Color(0xFF858585),
      iconPrimary = Color(0xFF202020),
      iconSecondary = Color(0xFF555555),
      iconDisabled = Color(0xFFAAAAAA),
      navigationText = Color(0xFF303030),
      border = Color(0xFFDADADA),
      divider = Color(0xFFD5D5D5),
      primaryButton = Color(0xFF151515),
      primaryButtonForeground = Color(0xFFFFFFFF),
      background = appBackground,
      surface = contentSurface,
      surfaceSoft = Color(0xFFF4F4F4),
      surfaceSelected = menuItemSelected,
      borderStrong = Color(0xFFD4D4D4),
      primary = primaryButton,
      primaryForeground = primaryButtonForeground;
  static const successBackground = Color(0xFFEAF5ED),
      successText = Color(0xFF267A42),
      warningBackground = Color(0xFFFFF1DF),
      warningText = Color(0xFFA85300),
      infoBackground = Color(0xFFE9F2FF),
      infoText = Color(0xFF185FAD),
      dangerBackground = Color(0xFFFBEAEA),
      dangerText = Color(0xFFAD2D24);
}

// Alias local al tema para mantener las declaraciones de ThemeData legibles.
// ignore: camel_case_types
abstract final class c {
  static const background = AppColors.background,
      surface = AppColors.surface,
      surfaceSoft = AppColors.surfaceSoft,
      textPrimary = AppColors.textPrimary,
      textSecondary = AppColors.textSecondary,
      textMuted = AppColors.textMuted,
      border = AppColors.border,
      primary = AppColors.primary,
      primaryForeground = AppColors.primaryForeground,
      dangerText = AppColors.dangerText;
}

abstract final class AppTheme {
  static ThemeData light() {
    const scheme = ColorScheme.light(
        primary: c.primary,
        onPrimary: c.primaryForeground,
        secondary: c.primary,
        onSecondary: c.primaryForeground,
        surface: c.surface,
        onSurface: c.textPrimary,
        error: c.dangerText,
        onError: c.primaryForeground);
    final outline = OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: c.border));
    return ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: scheme,
        primaryColor: c.primary,
        scaffoldBackgroundColor: c.background,
        canvasColor: c.surface,
        shadowColor: Colors.transparent,
        dividerColor: AppColors.divider,
        appBarTheme: const AppBarTheme(
            backgroundColor: AppColors.topBarBackground,
            foregroundColor: AppColors.textPrimary,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            iconTheme: IconThemeData(color: AppColors.iconPrimary, size: 22)),
        iconTheme: const IconThemeData(color: AppColors.iconPrimary, size: 21),
        textTheme: GoogleFonts.interTextTheme()
            .apply(bodyColor: c.textPrimary, displayColor: c.textPrimary),
        cardTheme: CardThemeData(
            color: c.surface,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            margin: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(color: c.border))),
        dialogTheme: DialogThemeData(
            backgroundColor: c.surface,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14))),
        drawerTheme: const DrawerThemeData(
            backgroundColor: c.surface, surfaceTintColor: Colors.transparent),
        dividerTheme: const DividerThemeData(
            color: AppColors.divider, thickness: 1, space: 1),
        inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: c.surface,
            hintStyle: const TextStyle(color: c.textMuted),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
            border: outline,
            enabledBorder: outline,
            focusedBorder: outline.copyWith(
                borderSide: const BorderSide(color: c.primary, width: 1.4))),
        filledButtonTheme: FilledButtonThemeData(
            style: FilledButton.styleFrom(
                backgroundColor: c.primary,
                foregroundColor: c.primaryForeground,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)))),
        outlinedButtonTheme: OutlinedButtonThemeData(
            style: OutlinedButton.styleFrom(
                foregroundColor: c.primary,
                side: const BorderSide(color: c.border),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)))),
        textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(foregroundColor: c.primary)),
        snackBarTheme: const SnackBarThemeData(
            backgroundColor: c.textPrimary,
            contentTextStyle: TextStyle(color: c.primaryForeground)),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
            backgroundColor: c.primary, foregroundColor: c.primaryForeground),
        tabBarTheme: const TabBarThemeData(
            labelColor: c.textPrimary,
            unselectedLabelColor: c.textSecondary,
            indicatorColor: c.primary,
            dividerColor: c.border),
        popupMenuTheme: const PopupMenuThemeData(
            color: c.surface, surfaceTintColor: Colors.transparent),
        datePickerTheme: const DatePickerThemeData(
            backgroundColor: c.surface,
            surfaceTintColor: Colors.transparent,
            headerForegroundColor: c.textPrimary),
        timePickerTheme: const TimePickerThemeData(
            backgroundColor: c.surface,
            hourMinuteColor: c.surfaceSoft,
            hourMinuteTextColor: c.textPrimary));
  }
}
