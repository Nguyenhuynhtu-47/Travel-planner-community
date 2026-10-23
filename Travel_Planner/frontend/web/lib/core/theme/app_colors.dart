import 'package:flutter/material.dart';

/// Design tokens aligned with DESIGN.md and docs/ai/04-ui-design-system.md
class AppColors {
  // Brand & Accent Tokens (from DESIGN.md)
  static const Color primary = Color(
    0xFFFF385C,
  ); // Rausch - Primary Brand Accent
  static const Color primaryActive = Color(
    0xFFE00B41,
  ); // Press / pointer-down variant
  static const Color primaryDisabled = Color(
    0xFFFFD1DA,
  ); // Disabled button fill
  static const Color primaryAccessible = Color(
    0xFFD90740,
  ); // Documented accessible proposal
  static const Color primaryLight = Color(0xFFFFF0F2); // Subtle Rausch tint
  static const Color primaryDark = Color(0xFFE00B41);
  static const Color accent = Color(0xFFFF385C);

  // Surface & Canvas Tokens
  static const Color background = Color(0xFFFFFFFF); // Canvas-first pure white
  static const Color surface = Color(0xFFFFFFFF); // Card & surface fill
  static const Color surfaceSoft = Color(
    0xFFF7F7F7,
  ); // Lightest fill (disabled fields, neutral chips)
  static const Color surfaceStrong = Color(
    0xFFF2F2F2,
  ); // Icon button backgrounds, neutral avatars

  // Borders & Hairlines
  static const Color border = Color(0xFFDDDDDD); // 1px hairline border
  static const Color hairline = Color(0xFFDDDDDD);
  static const Color hairlineSoft = Color(0xFFEBEBEB);
  static const Color borderStrong = Color(0xFFC1C1C1); // Heavier outline stroke

  // Text & Typography Tokens
  static const Color textPrimary = Color(0xFF222222); // Ink - dominant text
  static const Color textBody = Color(
    0xFF3F3F3F,
  ); // Body - secondary running text
  static const Color textSecondary = Color(
    0xFF6A6A6A,
  ); // Muted - captions, sub-labels
  static const Color muted = Color(0xFF6A6A6A);
  static const Color mutedSoft = Color(0xFF929292); // Placeholders

  // Semantic & Feedback Tokens
  static const Color error = Color(
    0xFFC13515,
  ); // Primary error text (WCAG AA compliant inline error)
  static const Color errorHover = Color(0xFFB32505);
  static const Color success = Color(0xFF10B981); // Emerald 500
  static const Color warning = Color(0xFFF59E0B); // Amber 500
  static const Color info = Color(0xFF3B82F6); // Blue 500
}
