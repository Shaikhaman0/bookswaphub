import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:bookswaphub/core/constants/app_colors.dart';
// import 'app_dimensions.dart';
import 'package:bookswaphub/core/constants/app_dimensions.dart';
class AppTheme {
  static TextTheme _buildTextTheme(TextTheme base, Color primaryColor, Color secondaryColor) {
    return base.copyWith(
      displayLarge: GoogleFonts.poppins(textStyle: base.displayLarge, color: primaryColor, fontWeight: FontWeight.bold),
      headlineLarge: GoogleFonts.poppins(textStyle: base.headlineLarge, color: primaryColor, fontWeight: FontWeight.w700),
      headlineMedium: GoogleFonts.poppins(textStyle: base.headlineMedium, color: primaryColor, fontWeight: FontWeight.w600),
      headlineSmall: GoogleFonts.poppins(textStyle: base.headlineSmall, color: primaryColor, fontWeight: FontWeight.w600),
      titleLarge: GoogleFonts.poppins(textStyle: base.titleLarge, color: primaryColor, fontWeight: FontWeight.w600),
      titleMedium: GoogleFonts.poppins(textStyle: base.titleMedium, color: primaryColor, fontWeight: FontWeight.w500),
      titleSmall: GoogleFonts.poppins(textStyle: base.titleSmall, color: primaryColor, fontWeight: FontWeight.w500),
      bodyLarge: GoogleFonts.inter(textStyle: base.bodyLarge, color: secondaryColor, fontSize: 16),
      bodyMedium: GoogleFonts.inter(textStyle: base.bodyMedium, color: secondaryColor, fontSize: 14),
      bodySmall: GoogleFonts.inter(textStyle: base.bodySmall, color: secondaryColor, fontSize: 12),
      labelLarge: GoogleFonts.inter(textStyle: base.labelLarge, color: primaryColor, fontWeight: FontWeight.w600),
      labelMedium: GoogleFonts.inter(textStyle: base.labelMedium, color: primaryColor, fontWeight: FontWeight.w500),
      labelSmall: GoogleFonts.inter(textStyle: base.labelSmall, color: primaryColor, fontWeight: FontWeight.w500),
    );
  }

  static ThemeData get lightTheme {
    final base = ThemeData.light(useMaterial3: true);
    
    return base.copyWith(
      primaryColor: AppColors.primary,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: const ColorScheme.light(
        primary: AppColors.primary,
        onPrimary: AppColors.surface,
        primaryContainer: AppColors.primaryLight,
        onPrimaryContainer: AppColors.surface,
        secondary: AppColors.secondary,
        onSecondary: AppColors.surface,
        tertiary: AppColors.accent,
        onTertiary: AppColors.textPrimary,
        error: AppColors.error,
        onError: AppColors.surface,
        surface: AppColors.surface,
        onSurface: AppColors.textPrimary,
      ),
      textTheme: _buildTextTheme(base.textTheme, AppColors.textPrimary, AppColors.textSecondary),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: AppDimensions.elevationNone,
        centerTitle: true,
      ),
      cardTheme: CardThemeData(
        color: AppColors.card,
        elevation: AppDimensions.elevationSm,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimensions.radiusMd)),
        margin: const EdgeInsets.all(AppDimensions.sm),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.surface,
          elevation: AppDimensions.elevationSm,
          padding: const EdgeInsets.symmetric(horizontal: AppDimensions.lg, vertical: AppDimensions.md),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimensions.radiusSm)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary),
          padding: const EdgeInsets.symmetric(horizontal: AppDimensions.lg, vertical: AppDimensions.md),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimensions.radiusSm)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.background,
        contentPadding: const EdgeInsets.all(AppDimensions.md),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
          borderSide: const BorderSide(color: AppColors.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
          borderSide: const BorderSide(color: AppColors.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
          borderSide: const BorderSide(color: AppColors.primary),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
          borderSide: const BorderSide(color: AppColors.error),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.background,
        labelStyle: const TextStyle(color: AppColors.textPrimary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimensions.radiusSm)),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.surface,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textHint,
        elevation: AppDimensions.elevationLg,
      ),
      navigationRailTheme: const NavigationRailThemeData(
        backgroundColor: AppColors.surface,
        selectedIconTheme: IconThemeData(color: AppColors.primary),
        unselectedIconTheme: IconThemeData(color: AppColors.textHint),
        selectedLabelTextStyle: TextStyle(color: AppColors.primary),
        unselectedLabelTextStyle: TextStyle(color: AppColors.textHint),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimensions.radiusLg)),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.textPrimary,
        contentTextStyle: const TextStyle(color: AppColors.surface),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimensions.radiusSm)),
        behavior: SnackBarBehavior.floating,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.divider,
        thickness: 1,
        space: 1,
      ),
    );
  }

  static ThemeData get darkTheme {
    final base = ThemeData.dark(useMaterial3: true);
    
    return base.copyWith(
      primaryColor: AppColors.darkPrimary,
      scaffoldBackgroundColor: AppColors.darkBackground,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.darkPrimary,
        onPrimary: AppColors.darkSurface,
        primaryContainer: AppColors.darkPrimaryLight,
        onPrimaryContainer: AppColors.darkSurface,
        secondary: AppColors.darkSecondary,
        onSecondary: AppColors.darkSurface,
        tertiary: AppColors.darkAccent,
        onTertiary: AppColors.darkTextPrimary,
        error: AppColors.darkError,
        onError: AppColors.darkSurface,
        surface: AppColors.darkSurface,
        onSurface: AppColors.darkTextPrimary,
      ),
      textTheme: _buildTextTheme(base.textTheme, AppColors.darkTextPrimary, AppColors.darkTextSecondary),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.darkSurface,
        foregroundColor: AppColors.darkTextPrimary,
        elevation: AppDimensions.elevationNone,
        centerTitle: true,
      ),
      cardTheme: CardThemeData(
        color: AppColors.darkCard,
        elevation: AppDimensions.elevationSm,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimensions.radiusMd)),
        margin: const EdgeInsets.all(AppDimensions.sm),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.darkPrimary,
          foregroundColor: AppColors.darkSurface,
          elevation: AppDimensions.elevationSm,
          padding: const EdgeInsets.symmetric(horizontal: AppDimensions.lg, vertical: AppDimensions.md),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimensions.radiusSm)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.darkPrimaryLight,
          side: const BorderSide(color: AppColors.darkPrimaryLight),
          padding: const EdgeInsets.symmetric(horizontal: AppDimensions.lg, vertical: AppDimensions.md),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimensions.radiusSm)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.darkCard,
        contentPadding: const EdgeInsets.all(AppDimensions.md),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
          borderSide: const BorderSide(color: AppColors.darkDivider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
          borderSide: const BorderSide(color: AppColors.darkDivider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
          borderSide: const BorderSide(color: AppColors.darkPrimary),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
          borderSide: const BorderSide(color: AppColors.darkError),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.darkCard,
        labelStyle: const TextStyle(color: AppColors.darkTextPrimary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimensions.radiusSm)),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.darkSurface,
        selectedItemColor: AppColors.darkPrimaryLight,
        unselectedItemColor: AppColors.darkTextHint,
        elevation: AppDimensions.elevationLg,
      ),
      navigationRailTheme: const NavigationRailThemeData(
        backgroundColor: AppColors.darkSurface,
        selectedIconTheme: IconThemeData(color: AppColors.darkPrimaryLight),
        unselectedIconTheme: IconThemeData(color: AppColors.darkTextHint),
        selectedLabelTextStyle: TextStyle(color: AppColors.darkPrimaryLight),
        unselectedLabelTextStyle: TextStyle(color: AppColors.darkTextHint),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.darkSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimensions.radiusLg)),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.darkTextPrimary,
        contentTextStyle: const TextStyle(color: AppColors.darkBackground),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimensions.radiusSm)),
        behavior: SnackBarBehavior.floating,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.darkDivider,
        thickness: 1,
        space: 1,
      ),
    );
  }
}
