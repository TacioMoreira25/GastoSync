import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  AppTheme._();

  // ---------------------------------------------------------------------------
  // DESIGN TOKENS V2 (FIGMA PROTOTYPE PALETTE)
  // ---------------------------------------------------------------------------
  /// Navy Escuro (Header Mobile, Sidebar Web, Hero Card e FAB G✨)
  static const Color navyDark = Color(0xFF0F172A); // Slate 900
  static const Color navySurface = Color(0xFF1E293B); // Slate 800
  static const Color navyBorder = Color(0xFF334155); // Slate 700

  /// Verde Esmeralda Primário (Botão +, Destaques, Receitas e Barras Saudáveis)
  static const Color emeraldPrimary = Color(0xFF10B981); // Emerald 500
  static const Color emeraldDark = Color(0xFF059669); // Emerald 600
  static const Color emeraldDeep = Color(0xFF047857); // Emerald 700
  static const Color emeraldBadgeBg = Color(0xFFD1FAE5); // Emerald 100
  static const Color emeraldSoftBg = Color(0xFFECFDF5); // Emerald 50

  /// Alerta / Limite Próximo (Burn Rate, Pendente local, Barras > 80%)
  static const Color warningAmber = Color(0xFFF59E0B); // Amber 500
  static const Color warningDark = Color(0xFFD97706); // Amber 600
  static const Color warningBadgeBg = Color(0xFFFEF3C7); // Amber 100
  static const Color warningBorder = Color(0xFFFCD34D); // Amber 300

  /// Fundos, Superfícies, Bordas e Tipografia
  static const Color backgroundLight = Color(0xFFF8FAFC); // Slate 50
  static const Color cardSurface = Color(0xFFFFFFFF);
  static const Color cardBorder = Color(0xFFE2E8F0); // Slate 200
  static const Color subtleSurface = Color(0xFFF1F5F9); // Slate 100
  static const Color textPrimary = Color(0xFF0F172A); // Slate 900
  static const Color textSecondary = Color(0xFF475569); // Slate 600
  static const Color textMuted = Color(0xFF64748B); // Slate 500

  // Compatibilidade com referências existentes
  static const Color primarySeedColor = emeraldPrimary;
  static const Color secondarySeedColor = navyDark;
  static const Color tertiarySeedColor = warningAmber;
  static const Color errorColor = Color(0xFFDC2626); // Red 600

  // ---------------------------------------------------------------------------
  // REUSABLE CARD & BADGE STYLES (PROTOTYPE V2)
  // ---------------------------------------------------------------------------
  static BoxDecoration get whiteCardDecoration => BoxDecoration(
        color: cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorder, width: 1),
      );

  static BoxDecoration get heroNavyCardDecoration => BoxDecoration(
        color: navyDark,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: navyBorder.withValues(alpha: 0.6), width: 1),
      );

  static BoxDecoration get warningBannerDecoration => BoxDecoration(
        color: warningBadgeBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: warningBorder, width: 1),
      );

  static BoxDecoration get emeraldBadgeDecoration => BoxDecoration(
        color: emeraldBadgeBg,
        borderRadius: BorderRadius.circular(999),
      );

  static BoxDecoration get warningBadgeDecoration => BoxDecoration(
        color: warningBadgeBg,
        borderRadius: BorderRadius.circular(999),
      );

  static BoxDecoration get subtleInsightBannerDecoration => BoxDecoration(
        color: subtleSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cardBorder, width: 1),
      );

  // ---------------------------------------------------------------------------
  // LIGHT THEME
  // ---------------------------------------------------------------------------
  static ThemeData get lightTheme {
    final baseScheme = ColorScheme.fromSeed(
      seedColor: emeraldPrimary,
      brightness: Brightness.light,
      surface: backgroundLight,
    );

    final colorScheme = baseScheme.copyWith(
      primary: emeraldPrimary,
      onPrimary: Colors.white,
      primaryContainer: emeraldBadgeBg,
      onPrimaryContainer: emeraldDeep,
      secondary: navyDark,
      onSecondary: Colors.white,
      secondaryContainer: subtleSurface,
      onSecondaryContainer: navyDark,
      tertiary: warningAmber,
      onTertiary: Colors.white,
      tertiaryContainer: warningBadgeBg,
      onTertiaryContainer: warningDark,
      error: errorColor,
      surface: backgroundLight,
      onSurface: textPrimary,
      onSurfaceVariant: textMuted,
      outline: cardBorder,
      outlineVariant: cardBorder,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: backgroundLight,
      textTheme: GoogleFonts.interTextTheme(ThemeData.light().textTheme).apply(
        bodyColor: textPrimary,
        displayColor: textPrimary,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: navyDark,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      cardTheme: CardThemeData(
        color: cardSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(
            color: cardBorder,
            width: 1,
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: cardSurface,
        selectedColor: navyDark,
        secondarySelectedColor: emeraldBadgeBg,
        side: const BorderSide(color: cardBorder),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
        ),
        labelStyle: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: textSecondary,
        ),
        secondaryLabelStyle: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: emeraldPrimary,
          foregroundColor: Colors.white,
          textStyle: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: cardSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 2,
        indicatorColor: emeraldSoftBg,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: emeraldPrimary, size: 24);
          }
          return const IconThemeData(color: textMuted, size: 24);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: emeraldPrimary,
            );
          }
          return GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: textMuted,
          );
        }),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: navyDark,
        elevation: 0,
        indicatorColor: emeraldPrimary.withValues(alpha: 0.18),
        selectedIconTheme: const IconThemeData(color: emeraldPrimary),
        unselectedIconTheme: const IconThemeData(color: Color(0xFF94A3B8)),
        selectedLabelTextStyle: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        unselectedLabelTextStyle: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: const Color(0xFF94A3B8),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // DARK THEME
  // ---------------------------------------------------------------------------
  static ThemeData get darkTheme {
    final baseScheme = ColorScheme.fromSeed(
      seedColor: emeraldPrimary,
      brightness: Brightness.dark,
      surface: navyDark,
    );

    final colorScheme = baseScheme.copyWith(
      primary: emeraldPrimary,
      onPrimary: Colors.white,
      primaryContainer: emeraldDeep,
      onPrimaryContainer: emeraldBadgeBg,
      secondary: emeraldPrimary,
      tertiary: warningAmber,
      error: errorColor,
      surface: navyDark,
      outline: navyBorder,
      outlineVariant: navyBorder,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: navyDark,
      textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
      appBarTheme: AppBarTheme(
        backgroundColor: navyDark,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: false,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: colorScheme.onSurface,
        ),
        iconTheme: IconThemeData(color: colorScheme.onSurface),
      ),
      cardTheme: CardThemeData(
        color: navySurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(
            color: navyBorder,
            width: 1,
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: navySurface,
        elevation: 2,
        indicatorColor: emeraldDeep.withValues(alpha: 0.4),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: emeraldPrimary,
            );
          }
          return GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: colorScheme.onSurfaceVariant,
          );
        }),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: navyDark,
        elevation: 1,
        indicatorColor: emeraldDeep.withValues(alpha: 0.4),
        selectedLabelTextStyle: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: emeraldPrimary,
        ),
        unselectedLabelTextStyle: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

