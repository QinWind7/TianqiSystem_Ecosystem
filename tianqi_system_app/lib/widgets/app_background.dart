import 'package:flutter/material.dart';

import '../theme.dart';

/// 页面底层：静态径向渐变，中心微亮、四周轻微压暗（随皮肤切换）。
class AppBackground extends StatelessWidget {
  const AppBackground({super.key, required this.child, this.isDark});

  final Widget child;

  /// 显式传入当前是否暗色主题；不传时回落到 [Theme.of] 的 brightness。
  final bool? isDark;

  @override
  Widget build(BuildContext context) {
    final dark = isDark ?? Theme.of(context).brightness == Brightness.dark;
    final palette = dark ? AppPalette.darkRed : AppPalette.light;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(0, -0.25),
          radius: 1.15,
          colors: palette.backgroundGradient,
          stops: const [0.0, 0.55, 1.0],
        ),
      ),
      child: child,
    );
  }
}
