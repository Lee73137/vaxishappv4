import 'package:flutter/material.dart';

/// Semantic surface/text colors that adapt between light and dark mode.
/// Brand colors (brandRed/brandRedDark in widgets/glossy_widgets.dart) stay
/// fixed across both themes — only backgrounds, cards, and text tones adapt,
/// same as most apps keep their logo/accent color constant in dark mode.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.scaffoldBackground,
    required this.surface,
    required this.surfaceVariant,
    required this.card,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.divider,
    required this.iconInactive,
    required this.overlay,
    required this.shadow,
  });

  /// Page/Scaffold background (was Color(0xFFF7F7F8)/F7F7F9 everywhere).
  final Color scaffoldBackground;

  /// Cards, sheets, dialogs, app bars (was Colors.white everywhere).
  final Color surface;

  /// Input fields, inactive pills, subtle fill backgrounds (was Color(0xFFF0F0F2)).
  final Color surfaceVariant;

  /// Same role as surface but kept distinct for widgets that already had
  /// their own "card" background concept.
  final Color card;

  /// Primary reading text (was Color(0xFF1A1A1A) / Colors.black87).
  final Color textPrimary;

  /// Secondary/label text (was Colors.black54 / black45).
  final Color textSecondary;

  /// Tertiary/hint/disabled text (was Colors.black38 / black26).
  final Color textTertiary;

  /// Hairline dividers and borders.
  final Color divider;

  /// Inactive nav icons / unselected state (was Color(0xFF9A9AA2)).
  final Color iconInactive;

  /// Scrims/overlays behind dialogs, placeholders, skeletons.
  final Color overlay;

  /// Drop-shadow color used under cards/buttons (was Colors.black.withValues(...)).
  final Color shadow;

  static const light = AppColors(
    scaffoldBackground: Color(0xFFF7F7F9),
    surface: Colors.white,
    surfaceVariant: Color(0xFFF0F0F2),
    card: Colors.white,
    textPrimary: Color(0xFF1A1A1A),
    textSecondary: Colors.black54,
    textTertiary: Colors.black38,
    divider: Color(0xFFE7E7EA),
    iconInactive: Color(0xFF9A9AA2),
    overlay: Colors.black12,
    shadow: Colors.black,
  );

  static const dark = AppColors(
    scaffoldBackground: Color(0xFF121214),
    surface: Color(0xFF1E1E22),
    surfaceVariant: Color(0xFF2C2C31),
    card: Color(0xFF1E1E22),
    textPrimary: Color(0xFFF2F2F3),
    textSecondary: Color(0xFFB7B7BC),
    textTertiary: Color(0xFF87878D),
    divider: Color(0xFF313136),
    iconInactive: Color(0xFF87878D),
    overlay: Colors.black45,
    shadow: Colors.black,
  );

  @override
  AppColors copyWith({
    Color? scaffoldBackground,
    Color? surface,
    Color? surfaceVariant,
    Color? card,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? divider,
    Color? iconInactive,
    Color? overlay,
    Color? shadow,
  }) {
    return AppColors(
      scaffoldBackground: scaffoldBackground ?? this.scaffoldBackground,
      surface: surface ?? this.surface,
      surfaceVariant: surfaceVariant ?? this.surfaceVariant,
      card: card ?? this.card,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      divider: divider ?? this.divider,
      iconInactive: iconInactive ?? this.iconInactive,
      overlay: overlay ?? this.overlay,
      shadow: shadow ?? this.shadow,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      scaffoldBackground: Color.lerp(scaffoldBackground, other.scaffoldBackground, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceVariant: Color.lerp(surfaceVariant, other.surfaceVariant, t)!,
      card: Color.lerp(card, other.card, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textTertiary: Color.lerp(textTertiary, other.textTertiary, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      iconInactive: Color.lerp(iconInactive, other.iconInactive, t)!,
      overlay: Color.lerp(overlay, other.overlay, t)!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
    );
  }
}

/// `context.colors.textPrimary` instead of `Theme.of(context).extension<AppColors>()!.textPrimary`.
extension AppColorsX on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppColors>() ?? AppColors.light;
}
