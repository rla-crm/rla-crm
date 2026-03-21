import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // Base
  static const Color background = Color(0xFFF8F8FA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceGlass = Color(0xCCFFFFFF);

  // Text
  static const Color textPrimary = Color(0xFF1A1A2E);
  static const Color textSecondary = Color(0xFF6B6B80);
  static const Color textMuted = Color(0xFFB0B0C0);

  // Borders
  static const Color border = Color(0xFFEAEAF0);
  static const Color divider = Color(0xFFF0F0F5);

  // Pastel Gradients
  static const Color lavender = Color(0xFFC9B8FF);
  static const Color lavenderLight = Color(0xFFE8E0FF);
  static const Color pink = Color(0xFFFFB8D9);
  static const Color pinkLight = Color(0xFFFFE0EE);
  static const Color peach = Color(0xFFFFD4A8);
  static const Color orange = Color(0xFFFFB347);
  static const Color sky = Color(0xFFB8EEFF);
  static const Color cyan = Color(0xFF7FD9F0);
  static const Color mint = Color(0xFFB8FFE4);
  static const Color teal = Color(0xFF7FE0C2);

  // Deep green gradient for success banners/cards (white text readable on top)
  static const Color successDeep = Color(0xFF1A8F5C);
  static const Color successDark = Color(0xFF0D6B47);

  // Pipeline stage colors
  static const Color stageNew = Color(0xFFC9B8FF);
  static const Color stageContacted = Color(0xFFB8EEFF);
  static const Color stageSiteVisit = Color(0xFFFFD4A8);
  static const Color stageNegotiation = Color(0xFFFFB8D9);
  static const Color stageClosed = Color(0xFFB8FFE4);
  static const Color stageLost = Color(0xFFE0E0E8);

  // Gradients
  static const LinearGradient gradientPrimary = LinearGradient(
    colors: [lavender, pink],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient gradientSecondary = LinearGradient(
    colors: [peach, orange],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient gradientTertiary = LinearGradient(
    colors: [sky, cyan],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient gradientSuccess = LinearGradient(
    colors: [successDeep, successDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient gradientCTA = LinearGradient(
    colors: [Color(0xFFC9B8FF), Color(0xFFFFB8D9), Color(0xFFFFD4A8)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );
}

class AppTheme {
  static ThemeData get theme => ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.lavender,
          surface: AppColors.surface,
        ),
        textTheme: GoogleFonts.interTextTheme().copyWith(
          displayLarge: GoogleFonts.inter(
            fontSize: 32, fontWeight: FontWeight.w700, color: AppColors.textPrimary,
            letterSpacing: -0.5,
          ),
          displayMedium: GoogleFonts.inter(
            fontSize: 24, fontWeight: FontWeight.w600, color: AppColors.textPrimary,
            letterSpacing: -0.3,
          ),
          titleLarge: GoogleFonts.inter(
            fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary,
          ),
          titleMedium: GoogleFonts.inter(
            fontSize: 16, fontWeight: FontWeight.w500, color: AppColors.textPrimary,
          ),
          bodyLarge: GoogleFonts.inter(
            fontSize: 15, fontWeight: FontWeight.w400, color: AppColors.textPrimary,
          ),
          bodyMedium: GoogleFonts.inter(
            fontSize: 13, fontWeight: FontWeight.w400, color: AppColors.textSecondary,
          ),
          bodySmall: GoogleFonts.inter(
            fontSize: 11, fontWeight: FontWeight.w400, color: AppColors.textMuted,
          ),
          labelSmall: GoogleFonts.inter(
            fontSize: 10, fontWeight: FontWeight.w500, color: AppColors.textMuted,
            letterSpacing: 0.8,
          ),
        ),
        cardTheme: CardThemeData(
          color: AppColors.surface,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          titleTextStyle: GoogleFonts.inter(
            fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary,
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.lavender, width: 1.5),
          ),
          labelStyle: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary),
          hintStyle: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      );
}

// Glass card decoration
BoxDecoration glassDecoration({double radius = 20, Color? borderColor}) {
  return BoxDecoration(
    color: AppColors.surfaceGlass,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: borderColor ?? AppColors.border, width: 1),
    boxShadow: [
      BoxShadow(
        color: const Color(0xFF1A1A2E).withValues(alpha: 0.04),
        blurRadius: 20,
        offset: const Offset(0, 4),
      ),
    ],
  );
}
