import 'package:flutter/material.dart';

/// Design System Palette - Light Theme ONLY
/// Crafted specifically for bright daylight and tube-lit Indian grocery counters.
class AppColors {
  // Base & Surface
  static const Color background = Color(0xFFF7F6F2); // Warm paper white (cool, non-yellow)
  static const Color surface = Color(0xFFFFFFFF);    // Pure white cards & sheets
  static const Color surfaceMuted = Color(0xFFEFECE6); // Slightly darker tint for chips/headers

  // Brand / Trust / Primary
  static const Color primary = Color(0xFF1F3A5F);    // Deep ledger-book indigo/navy
  static const Color primaryLight = Color(0xFF2C4F7C);
  static const Color primaryDark = Color(0xFF13253E);
  static const Color primaryContainer = Color(0xFFE2EAF4);

  // Accent / Highlights / CTAs
  static const Color accent = Color(0xFFE8A33D);     // Marigold / turmeric gold
  static const Color accentHover = Color(0xFFD6922D);
  static const Color accentLight = Color(0xFFFDF4E7);

  // Semantics
  static const Color success = Color(0xFF3F7D4F);    // Muted leaf green (in-stock, completed)
  static const Color successLight = Color(0xFFEBF4ED);

  static const Color alert = Color(0xFFB3402D);      // Muted brick red (due amount, low stock)
  static const Color alertLight = Color(0xFFF9ECE9);

  static const Color warning = Color(0xFFD97706);    // Amber warning
  static const Color warningLight = Color(0xFFFEF3C7);

  // Text
  static const Color textPrimary = Color(0xFF1C1C1A);  // Near-black for maximum contrast
  static const Color textSecondary = Color(0xFF6B6862);// Muted subtitle text
  static const Color textMuted = Color(0xFF9E9B93);

  // Structural
  static const Color divider = Color(0xFFE4E1D9);    // Clean ledger grid lines
  static const Color border = Color(0xFFD5D1C7);
  static const Color inputBorder = Color(0xFFCCC8BE);

  // Thermal receipt paper simulation
  static const Color thermalPaper = Color(0xFFFAFAF7);
  static const Color thermalText = Color(0xFF111111);
}
