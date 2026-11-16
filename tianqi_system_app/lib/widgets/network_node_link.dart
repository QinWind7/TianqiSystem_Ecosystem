import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/theme_provider.dart';
import '../screens/forum_web_screen.dart';
import '../theme.dart';

/// 悬浮的「动态网络节点」：双线六边形 + 十字准星，呼吸闪烁后进入天启系统网。
class NetworkNodeLink extends StatefulWidget {
  const NetworkNodeLink({super.key, this.size = 70});

  final double size;

  @override
  State<NetworkNodeLink> createState() => _NetworkNodeLinkState();
}

class _NetworkNodeLinkState extends State<NetworkNodeLink>
    with TickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final AnimationController _rippleController;

  bool _navigating = false;

  @override
  void initState() {
    super.initState();
    // 全息待机闪烁：0.4 → 1.0，1.5 秒一个来回。
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _rippleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _rippleController.dispose();
    super.dispose();
  }

  Future<void> _handleTap() async {
    if (_navigating) return;
    _navigating = true;
    unawaited(HapticFeedback.mediumImpact());
    _rippleController.forward(from: 0);

    await Future<void>.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const ForumWebScreen()),
    );
    if (mounted) _navigating = false;
  }

  @override
  Widget build(BuildContext context) {
    // 直接监听 ThemeProvider：主题切换时组件自身重建，不依赖外层是否刷新。
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDarkRed;
    // 极简白用深蓝，黑红警报用血红，不在组件里写死颜色。
    final palette = isDark ? AppPalette.darkRed : AppPalette.light;
    final color = palette.accent;

    return Semantics(
      button: true,
      label: 'ACCESS NETWORK 天启系统网',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _handleTap,
        child: AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            final t = Curves.easeInOut.transform(_pulseController.value);
            return Opacity(opacity: 0.4 + 0.6 * t, child: child);
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: widget.size + 20,
                height: widget.size + 20,
                child: Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [
                    // 点击波纹：极快扩散后淡出。
                    AnimatedBuilder(
                      animation: _rippleController,
                      builder: (context, _) {
                        // 未点击时不绘制，避免静止状态多出一圈描边。
                        if (_rippleController.value == 0) {
                          return const SizedBox.shrink();
                        }
                        final t = Curves.easeOut.transform(_rippleController.value);
                        return Opacity(
                          opacity: (1 - t) * 0.75,
                          child: Transform.scale(
                            scale: 1 + 0.95 * t,
                            child: CustomPaint(
                              size: Size.square(widget.size),
                              painter: _NodeRipplePainter(color),
                            ),
                          ),
                        );
                      },
                    ),
                    SizedBox(
                      width: widget.size,
                      height: widget.size,
                      child: CustomPaint(
                        // repaint 绑定主题：即使外层未重建，切主题也会强制重绘。
                        painter: _NodePainter(
                          color: color,
                          isDark: isDark,
                          repaint: themeProvider,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '[ ACCESS NETWORK ]',
                style: TextStyle(
                  fontSize: 8,
                  height: 1.1,
                  fontFamily: 'monospace',
                  letterSpacing: 0.3,
                  color: color.withValues(alpha: 0.85),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 双线六边形 + 十字准星，外部带主题色光晕。
class _NodePainter extends CustomPainter {
  _NodePainter({
    required this.color,
    required this.isDark,
    super.repaint,
  });

  final Color color;
  final bool isDark;

  Path _hexagon(Size size, double scale) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 * scale;
    final path = Path();
    for (var i = 0; i < 6; i++) {
      final angle = -math.pi / 2 + i * math.pi / 3;
      final point = Offset(
        center.dx + radius * math.cos(angle),
        center.dy + radius * math.sin(angle),
      );
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    return path..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final outer = _hexagon(size, 1);
    final inner = _hexagon(size, 0.84);
    final center = size.center(Offset.zero);

    // 极淡底色，让六边形在纯白/纯黑底上都能立住。
    canvas.drawPath(
      outer,
      Paint()
        ..style = PaintingStyle.fill
        ..color = color.withValues(alpha: isDark ? 0.06 : 0.04),
    );

    // 外发光：黑红模式更亮，像警戒浮游炮。
    canvas.drawPath(
      outer,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = isDark ? 3 : 2.2
        ..color = color.withValues(alpha: isDark ? 0.5 : 0.2)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, isDark ? 7 : 4.5),
    );

    // 双线细边框。
    canvas.drawPath(
      outer,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = color.withValues(alpha: 0.95),
    );
    canvas.drawPath(
      inner,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = color.withValues(alpha: 0.45),
    );

    // 中心十字准星：圆环 + 四向刻度 + 实心点。
    final ringRadius = size.shortestSide * 0.13;
    canvas.drawCircle(
      center,
      ringRadius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = color.withValues(alpha: 0.9),
    );
    final tick = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = color.withValues(alpha: 0.9);
    const dirs = [Offset(0, -1), Offset(1, 0), Offset(0, 1), Offset(-1, 0)];
    for (final dir in dirs) {
      canvas.drawLine(
        center + dir * (ringRadius + 2),
        center + dir * (ringRadius + 6),
        tick,
      );
    }
    canvas.drawCircle(
      center,
      1.7,
      Paint()
        ..style = PaintingStyle.fill
        ..color = color.withValues(alpha: 0.95),
    );
  }

  @override
  bool shouldRepaint(covariant _NodePainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.isDark != isDark;
  }
}

/// 点击后的快速扩散波纹。
class _NodeRipplePainter extends CustomPainter {
  const _NodeRipplePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawCircle(
      size.center(Offset.zero),
      size.shortestSide / 2 - 1,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1
        ..color = color.withValues(alpha: 0.45),
    );
  }

  @override
  bool shouldRepaint(covariant _NodeRipplePainter oldDelegate) =>
      oldDelegate.color != color;
}
