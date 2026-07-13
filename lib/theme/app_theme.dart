import 'package:flutter/material.dart';

/// Pastel fills used for player rectangles, matching the benchmark palette.
class RectPalette {
  static const List<Color> light = [
    Color(0xFF8FC79B), // green
    Color(0xFF93A7D0), // slate blue
    Color(0xFF83C3B5), // teal
    Color(0xFFC98FBE), // mauve
    Color(0xFFB39DDB), // purple
    Color(0xFFE3D48C), // yellow
    Color(0xFFC2A98B), // tan
    Color(0xFFDD8B8B), // salmon
    Color(0xFF9CC2E5), // light blue
    Color(0xFFE0A98F), // peach
  ];

  static const List<Color> dark = [
    Color(0xFF7FB98C),
    Color(0xFF8397C0),
    Color(0xFF73B3A5),
    Color(0xFFBF85B4),
    Color(0xFF9E8FCB),
    Color(0xFFD3C47C),
    Color(0xFFB2997B),
    Color(0xFFCD7B7B),
    Color(0xFF8CB2D5),
    Color(0xFFD0997F),
  ];

  static Color at(int index, bool isDark) {
    final list = isDark ? dark : light;
    return list[index % list.length];
  }
}

/// Semantic colours resolved per brightness. Read via `AppColors.of(context)`.
class AppColors {
  final Color background;
  final Color cell;
  final Color cellText;
  final Color rectText;
  final Color toolbar;
  final Color toolbarIcon;
  final Color headerText;
  final Color subtleText;
  final Color badge;
  final Color badgeText;
  final Color accent;
  final bool isDark;

  const AppColors({
    required this.background,
    required this.cell,
    required this.cellText,
    required this.rectText,
    required this.toolbar,
    required this.toolbarIcon,
    required this.headerText,
    required this.subtleText,
    required this.badge,
    required this.badgeText,
    required this.accent,
    required this.isDark,
  });

  static const AppColors darkColors = AppColors(
    background: Color(0xFF141821),
    cell: Color(0xFF2B2F38),
    cellText: Color(0xFFF2F4F8),
    rectText: Color(0xFF20242C),
    toolbar: Color(0xFF20242C),
    toolbarIcon: Color(0xFFB7BCC6),
    headerText: Color(0xFFF2F4F8),
    subtleText: Color(0xFF8A909C),
    badge: Color(0xFF2B2F38),
    badgeText: Color(0xFFF2F4F8),
    accent: Color(0xFFE05555),
    isDark: true,
  );

  static const AppColors lightColors = AppColors(
    background: Color(0xFFF4EFEC),
    cell: Color(0xFFFFFFFF),
    cellText: Color(0xFF2A2A2E),
    rectText: Color(0xFF20242C),
    toolbar: Color(0xFFFFFFFF),
    toolbarIcon: Color(0xFF3A3A40),
    headerText: Color(0xFF2A2A2E),
    subtleText: Color(0xFF9A938E),
    badge: Color(0xFFFFFFFF),
    badgeText: Color(0xFF2A2A2E),
    accent: Color(0xFFCC3B3B),
    isDark: false,
  );

  static AppColors of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkColors : lightColors;
}

/// App-wide serif/monospace styling to echo the benchmark's typography.
class AppTheme {
  static const String serif = 'serif';
  static const String mono = 'monospace';

  static ThemeData build(Brightness brightness) {
    final c = brightness == Brightness.dark
        ? AppColors.darkColors
        : AppColors.lightColors;

    final base = ThemeData(
      brightness: brightness,
      useMaterial3: true,
      scaffoldBackgroundColor: c.background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: c.accent,
        brightness: brightness,
      ).copyWith(surface: c.background),
      fontFamily: serif,
    );

    return base.copyWith(
      textTheme: base.textTheme.apply(
        bodyColor: c.headerText,
        displayColor: c.headerText,
        fontFamily: serif,
      ),
    );
  }

  static TextStyle title(AppColors c) => TextStyle(
        fontFamily: serif,
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: c.headerText,
      );

  static TextStyle heading(AppColors c) => TextStyle(
        fontFamily: serif,
        fontSize: 26,
        fontWeight: FontWeight.w700,
        color: c.headerText,
      );

  static TextStyle monoLabel(AppColors c) => TextStyle(
        fontFamily: mono,
        fontSize: 15,
        color: c.headerText,
      );
}
