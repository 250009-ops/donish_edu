import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// User-visible branding for Gotcha (display name, colors, typography).
class AppBranding {
  const AppBranding._();

  static const String displayName = 'Gotcha';
  static const String tagline = 'Master Uzbek Through Reading';
  static const String logoAsset = 'assets/images/logo.png';

  /// Sampled from the official Gotcha logo artwork.
  static const Color primary = Color(0xFF8840FE);
  static const Color primaryDark = Color(0xFF6F32D4);
  static const Color primaryLight = Color(0xFF9B5FFF);

  static TextStyle wordmark({
    required double fontSize,
    required Color color,
    FontWeight fontWeight = FontWeight.w700,
  }) {
    return GoogleFonts.varelaRound(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
    );
  }

  static TextTheme textTheme([TextTheme? base]) {
    return GoogleFonts.varelaRoundTextTheme(base);
  }
}
