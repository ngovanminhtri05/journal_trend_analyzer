import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// App theme: "Premium Utilitarian Minimalism" — warm monochrome canvas,
/// editorial serif headings, geometric sans body, mono for numeric meta,
/// ultra-flat surfaces (1px borders, no heavy shadows), pastel spot accents.
class AppTheme {
  // Warm monochrome palette.
  static const Color canvas = Color(0xFFFBFBFA); // off-white background
  static const Color surface = Color(0xFFFFFFFF); // cards
  static const Color border = Color(0xFFEAEAEA); // hairline dividers
  static const Color ink = Color(
    0xFF2F3437,
  ); // charcoal text (never pure black)
  static const Color muted = Color(0xFF787774); // secondary text
  static const Color fill = Color(0xFFF1F0EE); // track / muted fill

  // Spot pastel accents (used sparingly).
  static const Color paleBlue = Color(0xFFE1F3FE);
  static const Color paleBlueInk = Color(0xFF1F6C9F);
  static const Color errorInk = Color(0xFF9F2F2D);

  /// Mono style for numeric metadata (years, citation counts, ranks).
  static TextStyle mono(BuildContext context, {double? size, Color? color}) {
    return GoogleFonts.jetBrainsMono(
      fontSize: size ?? 12,
      color: color ?? muted,
      fontWeight: FontWeight.w500,
    );
  }

  static ThemeData build() {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: ink,
          brightness: Brightness.light,
        ).copyWith(
          surface: surface,
          onSurface: ink,
          primary: ink,
          onPrimary: Colors.white,
          secondary: paleBlueInk,
          outline: muted,
          outlineVariant: border,
          surfaceContainerHighest: fill,
          error: errorInk,
        );

    // Sans body + editorial serif headings.
    final sans = GoogleFonts.manropeTextTheme();
    TextStyle serif(double size, FontWeight w) => GoogleFonts.fraunces(
      fontSize: size,
      fontWeight: w,
      height: 1.1,
      letterSpacing: -0.4,
      color: ink,
    );

    final textTheme = sans
        .copyWith(
          headlineSmall: serif(26, FontWeight.w600),
          titleLarge: serif(22, FontWeight.w600),
          titleMedium: GoogleFonts.manrope(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          bodyMedium: GoogleFonts.manrope(fontSize: 14, height: 1.6),
        )
        .apply(bodyColor: ink, displayColor: ink);

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: canvas,
      textTheme: textTheme,
      cardTheme: CardThemeData(
        elevation: 0,
        color: surface,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: border),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: canvas,
        foregroundColor: ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: serif(24, FontWeight.w600),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        elevation: 0,
        indicatorColor: paleBlue,
        surfaceTintColor: Colors.transparent,
        labelTextStyle: WidgetStatePropertyAll(
          GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ),
      dividerTheme: const DividerThemeData(color: border, thickness: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: ink, width: 1.5),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: fill,
        side: BorderSide.none,
        shape: const StadiumBorder(),
        labelStyle: GoogleFonts.manrope(fontSize: 12, color: ink),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      ),
    );
  }
}
