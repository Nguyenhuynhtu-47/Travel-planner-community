import 'package:flutter/material.dart';

/// Semantic Enterprise Design Tokens for Travel Planner Web Admin.
/// Aligned with docs/plan/admin-design-system.md and UI/UX Pro Max Skill.
/// Follows Professional Enterprise SaaS Admin / Minimalism & Swiss Style.
class AppColors {
  // --- OFFICIAL BRAND TOKENS (Shared with Mobile App & DESIGN.md) ---
  /// Rausch - Primary Brand Accent for CTAs, active sidebar item text/indicator, focus rings.
  static const Color primary = Color(0xFFFF385C);
  /// Rausch Dark / Hover - Pointer-down / pressed variant for primary buttons
  static const Color primaryDark = Color(0xFFE00B41);
  static const Color primaryActive = Color(0xFFE00B41);
  /// Rausch Light / Tint - Subtle active row background, active sidebar tab background tint
  static const Color primaryLight = Color(0xFFFFF0F2);
  /// Rausch Border - Active selection border stroke
  static const Color primaryBorder = Color(0xFFFFD1DA);
  /// Rausch Disabled - Disabled button fill
  static const Color primaryDisabled = Color(0xFFFFD1DA);
  /// High-contrast accessible proposal token (WCAG 2.1 AA text on white: 4.5:1+)
  static const Color primaryAccessible = Color(0xFFD90740);

  // --- SECONDARY / ACCENT TOKENS ---
  /// Secondary Brand Accent for alerts, attention counters, saved badges
  static const Color accent = Color(0xFFFF385C);
  static const Color accentDark = Color(0xFFE00B41);
  static const Color accentLight = Color(0xFFFFF0F2);
  static const Color accentBorder = Color(0xFFFFD1DA);

  // --- HOVER & INTERACTION TINTS ---
  /// Ultra-light Rausch hover tint (Sidebar / row hover)
  static const Color primaryTint = Color(0xFFFFF7F8);
  /// Rausch deep active/pressed button state
  static const Color primaryPressed = Color(0xFFB80536);
  /// Brand-consistent table row hover (#FFF7F8 per design system)
  static const Color tableHover = Color(0xFFFFF7F8);

  // --- NEUTRAL SLATE SURFACES & CANVAS ---
  /// Pure white background floor for admin canvas
  static const Color background = Color(0xFFFFFFFF);
  /// Pure white surface fill for panels, tables, dialogs
  static const Color surface = Color(0xFFFFFFFF);
  /// Slate 50 - Lightest neutral fill for table headers, toolbar, sidebar background
  static const Color surfaceSubtle = Color(0xFFF8FAFC);
  static const Color surfaceSoft = Color(0xFFF8FAFC);
  /// Slate 100 - Row hover fill, button hover background
  static const Color surfaceHover = Color(0xFFF1F5F9);
  /// Slate 200 - Icon button background, neutral avatar surface
  static const Color surfaceStrong = Color(0xFFE2E8F0);

  // --- BORDERS & HAIRLINES (1px Hairlines) ---
  /// Slate 200 - Default 1px hairline border tone: table cell borders, dividers, separators
  static const Color border = Color(0xFFE2E8F0);
  static const Color hairline = Color(0xFFE2E8F0);
  /// Slate 100 - Ultra-subtle divider for nested table rows
  static const Color hairlineSoft = Color(0xFFF1F5F9);
  /// Slate 300 - Heavier stroke used for form input outlines, divider lines
  static const Color borderStrong = Color(0xFFCBD5E1);

  // --- TYPOGRAPHY INK TOKENS (WCAG 2.1 AA Compliant) ---
  /// Slate 900 - Dominant ink text color: headlines, table primary values (18.2:1 contrast vs white)
  static const Color textPrimary = Color(0xFF0F172A);
  /// Slate 700 - Secondary running text: descriptions, table body content (9.6:1 contrast vs white)
  static const Color textSecondary = Color(0xFF334155);
  static const Color textBody = Color(0xFF334155);
  /// Slate 500 - Captions, sub-labels, table headers, breadcrumbs (4.8:1 contrast vs white)
  static const Color textMuted = Color(0xFF64748B);
  static const Color muted = Color(0xFF64748B);
  /// Slate 400 - Placeholders, disabled text
  static const Color textDisabled = Color(0xFF94A3B8);
  static const Color mutedSoft = Color(0xFF94A3B8);

  // --- SEMANTIC FEEDBACK & STATUS TOKENS ---
  // Error (Red 600 / 50 / 200)
  static const Color error = Color(0xFFDC2626);
  static const Color errorHover = Color(0xFFB91C1C);
  static const Color errorLight = Color(0xFFFEF2F2);
  static const Color errorBorder = Color(0xFFFECACA);

  // Success (Green 600 / 50 / 200)
  static const Color success = Color(0xFF16A34A);
  static const Color successLight = Color(0xFFF0FDF4);
  static const Color successBorder = Color(0xFFBBF7D0);

  // Warning (Amber 600 / 100 / 200)
  static const Color warning = Color(0xFFD97706);
  static const Color warningLight = Color(0xFFFEF3C7);
  static const Color warningBorder = Color(0xFFFDE68A);

  // Info (Sky 600 / 50 / 200)
  static const Color info = Color(0xFF0284C7);
  static const Color infoLight = Color(0xFFF0F9FF);
  static const Color infoBorder = Color(0xFFBAE6FD);
}

/// Standard Spacing scale based on 4px grid.
class AppSpacing {
  static const double space1 = 4.0;
  static const double space2 = 8.0;
  static const double space3 = 12.0;
  static const double space4 = 16.0;
  static const double space5 = 20.0;
  static const double space6 = 24.0;
  static const double space8 = 32.0;

  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 20.0;
  static const double xxl = 24.0;
  static const double section = 32.0;
}

/// Disciplined Swiss Minimalist radius scale with refined micro-radii (4px-8px).
class AppRadius {
  static const double none = 0.0;
  static const double xs = 2.0; // Micro tags, inline code
  static const double badge = 4.0; // Status Badge (4-6px)
  static const double sm = 4.0; // Backward compatible base token (4px)
  static const double input = 6.0; // Input / Select (6px)
  static const double button = 6.0; // Button (6px)
  static const double sidebarItem = 6.0; // Sidebar active item (6px)
  static const double md = 6.0; // Medium surfaces (6px)
  static const double card = 8.0; // Card / Panel (8px)
  static const double dialog = 8.0; // Dialog / Modal (8px)
  static const double table = 8.0; // Table container (8px)
  static const double lg = 8.0; // Maximum allowed corner radius (8px)

  static const Radius radiusXs = Radius.circular(xs);
  static const Radius radiusBadge = Radius.circular(badge);
  static const Radius radiusSm = Radius.circular(sm);
  static const Radius radiusInput = Radius.circular(input);
  static const Radius radiusButton = Radius.circular(button);
  static const Radius radiusSidebarItem = Radius.circular(sidebarItem);
  static const Radius radiusMd = Radius.circular(md);
  static const Radius radiusCard = Radius.circular(card);
  static const Radius radiusDialog = Radius.circular(dialog);
  static const Radius radiusTable = Radius.circular(table);
  static const Radius radiusLg = Radius.circular(lg);

  static const BorderRadius borderXs = BorderRadius.all(radiusXs);
  static const BorderRadius borderBadge = BorderRadius.all(radiusBadge);
  static const BorderRadius borderSm = BorderRadius.all(radiusSm);
  static const BorderRadius borderInput = BorderRadius.all(radiusInput);
  static const BorderRadius borderButton = BorderRadius.all(radiusButton);
  static const BorderRadius borderSidebarItem = BorderRadius.all(radiusSidebarItem);
  static const BorderRadius borderMd = BorderRadius.all(radiusMd);
  static const BorderRadius borderCard = BorderRadius.all(radiusCard);
  static const BorderRadius borderDialog = BorderRadius.all(radiusDialog);
  static const BorderRadius borderTable = BorderRadius.all(radiusTable);
  static const BorderRadius borderLg = BorderRadius.all(radiusLg);
}

/// Standardized component sizing heights for Admin Web.
class AppHeights {
  static const double header = 52.0;
  static const double sidebarExpanded = 252.0;
  static const double sidebarCollapsed = 64.0;
  static const double toolbar = 46.0;
  static const double inputCompact = 32.0;
  static const double inputStandard = 38.0;
  static const double tableHeader = 38.0;
  static const double tableRow = 44.0;
  static const double tableRowComfortable = 52.0;
  static const double buttonSmall = 30.0;
  static const double buttonStandard = 36.0;
  static const double paginationBar = 42.0;
}

/// 8-step Typographic scale for Admin Web.
class AppTypography {
  static const String fontFamily = 'Inter';

  /// 24px Bold - Dashboard KPI metrics
  static const TextStyle displayKpi = TextStyle(
    fontFamily: fontFamily,
    fontSize: 24,
    fontWeight: FontWeight.w700,
    height: 1.17,
    letterSpacing: -0.5,
    color: AppColors.textPrimary,
  );

  /// 18px SemiBold - Admin Page Header main titles
  static const TextStyle titlePage = TextStyle(
    fontFamily: fontFamily,
    fontSize: 18,
    fontWeight: FontWeight.w600,
    height: 1.33,
    letterSpacing: -0.3,
    color: AppColors.textPrimary,
  );

  /// 15px SemiBold - Section headings, modal titles
  static const TextStyle titleSection = TextStyle(
    fontFamily: fontFamily,
    fontSize: 15,
    fontWeight: FontWeight.w600,
    height: 1.33,
    letterSpacing: -0.2,
    color: AppColors.textPrimary,
  );

  /// 13px Regular - Table data, form values, running text
  static const TextStyle bodyData = TextStyle(
    fontFamily: fontFamily,
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 1.38,
    color: AppColors.textSecondary,
  );

  /// 13px Medium - Highlighted table data, author names
  static const TextStyle bodyMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 13,
    fontWeight: FontWeight.w500,
    height: 1.38,
    color: AppColors.textPrimary,
  );

  /// 12.5px Medium - Form field labels, toolbar filters, buttons
  static const TextStyle labelControl = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12.5,
    fontWeight: FontWeight.w500,
    height: 1.28,
    color: AppColors.textPrimary,
  );

  /// 11.5px SemiBold Uppercase - Table column headers
  static const TextStyle captionTable = TextStyle(
    fontFamily: fontFamily,
    fontSize: 11.5,
    fontWeight: FontWeight.w600,
    height: 1.21,
    letterSpacing: 0.4,
    color: AppColors.textMuted,
  );

  /// 11px SemiBold - Semantic status badges
  static const TextStyle badgeMicro = TextStyle(
    fontFamily: fontFamily,
    fontSize: 11,
    fontWeight: FontWeight.w600,
    height: 1.27,
    letterSpacing: 0.2,
  );

  /// 12px Regular Monospace - IDs (#9104), coordinates, hashes
  static const TextStyle codeMono = TextStyle(
    fontFamily: 'monospace',
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1.33,
    letterSpacing: -0.1,
    color: AppColors.textPrimary,
  );
}
