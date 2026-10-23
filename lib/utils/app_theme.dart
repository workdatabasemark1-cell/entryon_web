import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// Futuristic Theme Design Tokens & Global ThemeData
/// ─────────────────────────────────────────────────────────────────────────────

class FuturisticColors {
  // Deep Cyber Canvas & Surfaces
  static const bgVoid = Color(0xFF070B14);        // Primary deep obsidian background
  static const bgSurface = Color(0xFF0E1626);     // Secondary surface / nav container
  static const bgCard = Color(0xFF131F35);        // Glassmorphic card surface
  static const bgCardHover = Color(0xFF1A2A47);   // Card hover / elevated surface
  static const bgElevated = Color(0xFF1A2A47);    // Elevated surface
  static const bgInput = Color(0xFF0A101D);       // Deep input field background

  // Cyber Neon Accents
  static const neonCyan = Color(0xFF00F2FE);      // Primary cyber electric cyan
  static const neonTeal = Color(0xFF00F5A0);      // Secondary emerald cyber glow
  static const neonViolet = Color(0xFF8B5CF6);    // Holographic purple
  static const neonAmber = Color(0xFFFFB703);     // Cyber alert / gold warning
  static const neonCrimson = Color(0xFFFF3366);   // Laser danger red
  static const neonBlue = Color(0xFF38BDF8);      // Electric sky blue

  // Neon Glow & Rim Borders
  static const cyberBorder = Color(0x3300F2FE);    // 20% neon cyan border
  static const borderSubtle = Color(0xFF1E2D4A);   // Structural subtle border
  static const glowShadow = Color(0x2600F2FE);     // Ambient cyber glow shadow

  // Typography
  static const textPrimary = Color(0xFFF8FAFC);   // Crisp luminous white
  static const textSecondary = Color(0xFF94A3B8); // High-tech muted silver
  static const textMuted = Color(0xFF64748B);     // Dimmed slate
}

class AppTheme {
  /// Check if dark futuristic theme is active from BuildContext
  static bool isDark(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark;
  }

  // ── Semantic Color Helpers ───────────────────────────────────────────────
  static Color scaffoldBg(BuildContext context) =>
      isDark(context) ? FuturisticColors.bgVoid : const Color(0xFFF8FAFC);

  static Color surfaceBg(BuildContext context) =>
      isDark(context) ? FuturisticColors.bgSurface : Colors.white;

  static Color cardBg(BuildContext context) =>
      isDark(context) ? FuturisticColors.bgCard : Colors.white;

  static Color cardBorderColor(BuildContext context) =>
      isDark(context) ? FuturisticColors.borderSubtle : const Color(0xFFE2E8F0);

  static BorderSide cardBorder(BuildContext context) => BorderSide(
        color: cardBorderColor(context),
        width: isDark(context) ? 1.0 : 1.0,
      );

  static Color textPrimary(BuildContext context) =>
      isDark(context) ? FuturisticColors.textPrimary : const Color(0xFF0F172A);

  static Color textSecondary(BuildContext context) =>
      isDark(context) ? FuturisticColors.textSecondary : const Color(0xFF64748B);

  static Color textMuted(BuildContext context) =>
      isDark(context) ? FuturisticColors.textMuted : const Color(0xFF94A3B8);

  static Color inputBg(BuildContext context) =>
      isDark(context) ? FuturisticColors.bgInput : const Color(0xFFF1F5F9);

  static Color accent(BuildContext context) =>
      isDark(context) ? FuturisticColors.neonCyan : const Color(0xFF0D9488);

  static Color divider(BuildContext context) =>
      isDark(context) ? FuturisticColors.borderSubtle : const Color(0xFFE2E8F0);

  static Color dialogBg(BuildContext context) =>
      isDark(context) ? FuturisticColors.bgCard : Colors.white;

  // ── Light Theme (Clean Professional Slate & Teal) ─────────────────────────
  static ThemeData get lightTheme {
    const primary = Color(0xFF0D9488);
    const slate = Color(0xFF0F172A);
    const bg = Color(0xFFF8FAFC);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: primary,
      scaffoldBackgroundColor: bg,
      colorScheme: const ColorScheme.light(
        primary: primary,
        secondary: Color(0xFF0284C7),
        surface: Colors.white,
        error: Color(0xFFEF4444),
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: slate,
      ),
      fontFamily: GoogleFonts.inter().fontFamily,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: slate,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(
          color: slate,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFFE2E8F0),
        thickness: 1,
      ),
    );
  }

  // ── Dark Futuristic Theme (Cyberpunk / Obsidian Neon) ─────────────────────
  static ThemeData get darkFuturisticTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: FuturisticColors.neonCyan,
      scaffoldBackgroundColor: FuturisticColors.bgVoid,
      canvasColor: FuturisticColors.bgSurface,
      colorScheme: const ColorScheme.dark(
        primary: FuturisticColors.neonCyan,
        secondary: FuturisticColors.neonTeal,
        surface: FuturisticColors.bgSurface,
        error: FuturisticColors.neonCrimson,
        onPrimary: Color(0xFF070B14),
        onSecondary: Color(0xFF070B14),
        onSurface: FuturisticColors.textPrimary,
        onError: Colors.white,
      ),
      fontFamily: GoogleFonts.inter().fontFamily,
      appBarTheme: const AppBarTheme(
        backgroundColor: FuturisticColors.bgSurface,
        foregroundColor: FuturisticColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(
          color: FuturisticColors.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
        ),
        iconTheme: IconThemeData(color: FuturisticColors.neonCyan),
      ),
      cardTheme: CardThemeData(
        color: FuturisticColors.bgCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: FuturisticColors.borderSubtle, width: 1),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: FuturisticColors.bgSurface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: FuturisticColors.cyberBorder, width: 1.2),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: FuturisticColors.borderSubtle,
        thickness: 1,
      ),
      tabBarTheme: const TabBarThemeData(
        indicatorColor: FuturisticColors.neonCyan,
        labelColor: FuturisticColors.neonCyan,
        unselectedLabelColor: FuturisticColors.textSecondary,
      ),
      dataTableTheme: DataTableThemeData(
        headingRowColor: const WidgetStatePropertyAll(FuturisticColors.bgSurface),
        dataRowColor: const WidgetStatePropertyAll(FuturisticColors.bgCard),
        headingTextStyle: const TextStyle(
          color: FuturisticColors.neonCyan,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
        dataTextStyle: const TextStyle(
          color: FuturisticColors.textPrimary,
          fontSize: 13,
        ),
        dividerThickness: 1,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: FuturisticColors.bgSurface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: FuturisticColors.borderSubtle),
        ),
        textStyle: const TextStyle(color: FuturisticColors.textPrimary),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: FuturisticColors.bgSurface,
        contentTextStyle: TextStyle(color: FuturisticColors.textPrimary),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: FuturisticColors.bgInput,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: FuturisticColors.borderSubtle),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: FuturisticColors.borderSubtle),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: FuturisticColors.neonCyan, width: 1.5),
        ),
        hintStyle: const TextStyle(color: FuturisticColors.textMuted, fontSize: 13),
        labelStyle: const TextStyle(color: FuturisticColors.textSecondary, fontSize: 13),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: FuturisticColors.neonCyan,
          foregroundColor: const Color(0xFF070B14),
          elevation: 0,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }
}
