import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/theme_provider.dart';
import '../theme.dart';

/// 统一的 HUD 弹窗外壳：极小圆角、1px 主题边框、随皮肤切换的底色。
class HudSheetShell extends StatelessWidget {
  const HudSheetShell({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(18, 14, 18, 16),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final palette = theme.isDarkRed ? AppPalette.darkRed : AppPalette.light;

    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(3),
          border: Border.all(color: palette.divider, width: 1),
          boxShadow: [
            BoxShadow(
              color: palette.shadowColor,
              blurRadius: 26,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// 弹窗顶部的 HUD 标题行：左侧协议名，右侧关闭指令。
class HudSheetHeader extends StatelessWidget {
  const HudSheetHeader({super.key, required this.label, this.onClose});

  final String label;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final palette = theme.isDarkRed ? AppPalette.darkRed : AppPalette.light;
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 9.5,
              fontFamily: 'monospace',
              letterSpacing: 0.8,
              color: palette.techLabel,
            ),
          ),
        ),
        if (onClose != null)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onClose,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
              child: Text(
                '[ CLOSE ]',
                style: TextStyle(
                  fontSize: 9,
                  fontFamily: 'monospace',
                  color: palette.textTertiary,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
