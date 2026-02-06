/// Design tokens for consistent spacing, radius, and sizing across the app.
///
/// Usage:
///   Padding(padding: EdgeInsets.all(AppSpacing.md))
///   BorderRadius.circular(AppRadius.sm)
///   Icon(Icons.home, size: AppIconSize.md)

/// Spacing scale (multiples of 4)
class AppSpacing {
  AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
}

/// Border radius scale
class AppRadius {
  AppRadius._();

  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
}

/// Icon size scale
class AppIconSize {
  AppIconSize._();

  static const double sm = 16;
  static const double md = 24;
  static const double lg = 32;
  static const double xl = 48;
}
