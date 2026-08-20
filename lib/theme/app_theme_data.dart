import 'package:flutter/material.dart';

import '../widgets/glossy_widgets.dart' show brandRed;
import 'app_colors.dart';

ThemeData buildAppTheme(AppColors colors, Brightness brightness) {
  return ThemeData(
    brightness: brightness,
    useMaterial3: true,
    scaffoldBackgroundColor: colors.scaffoldBackground,
    canvasColor: colors.scaffoldBackground,
    cardColor: colors.card,
    dividerColor: colors.divider,
    colorScheme: ColorScheme.fromSeed(
      seedColor: brandRed,
      brightness: brightness,
      surface: colors.surface,
    ),
    textTheme: (brightness == Brightness.dark ? ThemeData.dark() : ThemeData.light())
        .textTheme
        .apply(bodyColor: colors.textPrimary, displayColor: colors.textPrimary),
    appBarTheme: AppBarTheme(
      backgroundColor: colors.surface,
      foregroundColor: colors.textPrimary,
      elevation: 0,
    ),
    dialogTheme: DialogThemeData(backgroundColor: colors.surface),
    extensions: [colors],
  );
}
