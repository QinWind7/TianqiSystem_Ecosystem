import 'package:flutter/material.dart';

/// App 支持的皮肤模式。
enum AppThemeMode { light, darkRed }

/// 一套完整的 HUD 配色。两套皮肤共用同一份字段，切换时只替换实例。
class AppPalette {
  const AppPalette({
    required this.background,
    required this.surface,
    required this.surfaceMuted,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.techLabel,
    required this.accent,
    required this.accentSoft,
    required this.success,
    required this.divider,
    required this.backgroundGradient,
    required this.shadowColor,
    required this.focusShadowColor,
    required this.isDark,
  });

  final Color background;
  final Color surface;
  final Color surfaceMuted;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color techLabel;
  final Color accent;
  final Color accentSoft;
  final Color success;
  final Color divider;
  final List<Color> backgroundGradient;
  final Color shadowColor;
  final Color focusShadowColor;
  final bool isDark;

  /// 极简白：浅灰底 + 纯白卡片 + 深蓝 HUD 强调。
  static const AppPalette light = AppPalette(
    background: Color(0xFFF3F4F6),
    surface: Color(0xFFFFFFFF),
    surfaceMuted: Color(0xFFF4F5F8),
    textPrimary: Color(0xFF1A1A1A),
    textSecondary: Color(0xFF888888),
    textTertiary: Color(0xFFB4B8C2),
    techLabel: Color(0xFFA3AFC2),
    accent: Color(0xFF4F46E5),
    accentSoft: Color(0xFFEEF0FD),
    success: Color(0xFF3FA47A),
    divider: Color(0xFFE8EAF0),
    backgroundGradient: [
      Color(0xFFFAFBFD),
      Color(0xFFF3F4F6),
      Color(0xFFE7EBF1),
    ],
    shadowColor: Color(0x0D1A1A1A),
    focusShadowColor: Color(0x1A607D8B),
    isDark: false,
  );

  /// 黑红警报：纯黑底 + 暗灰卡片 + 血红 HUD 强调，卡片用暗红光晕代替白影。
  static const AppPalette darkRed = AppPalette(
    background: Color(0xFF0E0E10),
    surface: Color(0xFF1A1A1D),
    surfaceMuted: Color(0xFF232326),
    textPrimary: Color(0xFFE2E2E2),
    textSecondary: Color(0xFF888888),
    textTertiary: Color(0xFF5E5E63),
    techLabel: Color(0xFF8A8A90),
    accent: Color(0xFFD32F2F),
    accentSoft: Color(0xFF2A1415),
    success: Color(0xFF4CAF7D),
    divider: Color(0xFF331111),
    backgroundGradient: [
      Color(0xFF161416),
      Color(0xFF0E0E10),
      Color(0xFF08080A),
    ],
    shadowColor: Color(0x33D32F2F),
    focusShadowColor: Color(0x40D32F2F),
    isDark: true,
  );
}

/// 全局调色板代理。
///
/// 现有页面大量使用 `AppColors.xxx` 静态引用，这里保持同样的调用方式，
/// 由 [AppColors.apply] 在主题切换时替换底层调色板，避免逐页改写 100+ 处颜色。
class AppColors {
  const AppColors._();

  static AppPalette _palette = AppPalette.light;

  static AppPalette get palette => _palette;

  static void apply(AppThemeMode mode) {
    _palette = mode == AppThemeMode.darkRed ? AppPalette.darkRed : AppPalette.light;
  }

  static Color get background => _palette.background;
  static Color get surface => _palette.surface;
  static Color get surfaceMuted => _palette.surfaceMuted;
  static Color get textPrimary => _palette.textPrimary;
  static Color get textSecondary => _palette.textSecondary;
  static Color get textTertiary => _palette.textTertiary;
  static Color get techLabel => _palette.techLabel;
  static Color get accent => _palette.accent;
  static Color get accentSoft => _palette.accentSoft;
  static Color get success => _palette.success;
  static Color get divider => _palette.divider;
  static Color get backgroundGradientStart => _palette.backgroundGradient[0];
  static Color get backgroundGradientMiddle => _palette.backgroundGradient[1];
  static Color get backgroundGradientEnd => _palette.backgroundGradient[2];
}

/// 统一的柔和投影：浅色为低透明度灰影，黑红模式自动替换为暗红光晕。
class AppShadows {
  const AppShadows._();

  /// 任务卡片。
  static List<BoxShadow> get card => [
    BoxShadow(color: AppColors.palette.shadowColor, blurRadius: 28, offset: const Offset(0, 8)),
  ];

  /// 外层大面板。
  static List<BoxShadow> get panel => [
    BoxShadow(color: AppColors.palette.shadowColor, blurRadius: 44, offset: const Offset(0, 14)),
  ];

  /// 居中专注卡片。
  static List<BoxShadow> get focusCard => [
    BoxShadow(
      color: AppColors.palette.focusShadowColor,
      blurRadius: 30,
      offset: const Offset(0, 10),
    ),
  ];
}

/// 根据调色板生成 Material 主题，交给 MaterialApp 的 theme / darkTheme。
ThemeData buildAppTheme(AppPalette palette, Brightness brightness) {
  final scheme = ColorScheme.fromSeed(
    seedColor: palette.accent,
    brightness: brightness,
  ).copyWith(
    primary: palette.accent,
    onPrimary: Colors.white,
    surface: palette.surface,
    onSurface: palette.textPrimary,
    error: palette.accent,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: palette.background,
    canvasColor: palette.surface,
    cardColor: palette.surface,
    dividerColor: palette.divider,
    splashFactory: NoSplash.splashFactory,
  );
}
