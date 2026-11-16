import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme.dart';

/// 全局主题状态：持久化用户选择，并同步更新 [AppColors] 与系统栏图标亮度。
class ThemeProvider extends ChangeNotifier {
  static const String _storageKey = 'app_theme_mode';

  AppThemeMode _mode = AppThemeMode.light;

  AppThemeMode get mode => _mode;

  bool get isDarkRed => _mode == AppThemeMode.darkRed;

  AppPalette get palette => isDarkRed ? AppPalette.darkRed : AppPalette.light;

  /// 启动时读取上次选择；读取失败时回落到极简白。
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_storageKey);
      _mode = AppThemeMode.values.firstWhere(
        (item) => item.name == saved,
        orElse: () => AppThemeMode.light,
      );
    } catch (_) {
      _mode = AppThemeMode.light;
    }
    AppColors.apply(_mode);
    _applySystemUi();
  }

  /// 切换并立即落盘。
  Future<void> setMode(AppThemeMode mode) async {
    if (_mode == mode) return;
    _mode = mode;
    AppColors.apply(_mode);
    _applySystemUi();
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageKey, _mode.name);
    } catch (_) {
      // 存储不可用时仅保留本次会话内的效果。
    }
  }

  Future<void> toggle() => setMode(
    isDarkRed ? AppThemeMode.light : AppThemeMode.darkRed,
  );

  void _applySystemUi() {
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDarkRed ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDarkRed ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarDividerColor: Colors.transparent,
        systemNavigationBarIconBrightness: isDarkRed ? Brightness.light : Brightness.dark,
        systemStatusBarContrastEnforced: false,
        systemNavigationBarContrastEnforced: false,
      ),
    );
  }
}
