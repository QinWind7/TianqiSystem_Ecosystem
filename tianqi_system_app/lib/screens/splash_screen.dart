import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/token_storage.dart';
import '../theme.dart';
import 'login_screen.dart';
import 'system_home_screen.dart';

/// 启动页：数据方块向中心汇聚、波纹散开、文字浮现后进入主界面。
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  static const Duration _totalDuration = Duration(milliseconds: 3000);

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _totalDuration,
  );
  late final List<_SquareSeed> _squares = _buildSquares();

  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _controller.addStatusListener(_handleStatus);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.removeStatusListener(_handleStatus);
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleStatus(AnimationStatus status) async {
    if (status != AnimationStatus.completed || _navigated || !mounted) return;
    _navigated = true;

    // 本地有 Token 直接进入主界面，否则先登录。
    final loggedIn = await TokenStorage.instance.hasAccessToken();
    if (!mounted) return;

    final Widget next = loggedIn ? const SystemHomeScreen() : const LoginScreen();
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 420),
        pageBuilder: (_, _, _) => next,
        transitionsBuilder: (_, animation, _, child) {
          return FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
            child: child,
          );
        },
      ),
    );
  }

  static List<_SquareSeed> _buildSquares() {
    final random = math.Random(20261116);
    final colors = [
      AppColors.accent,
      AppColors.accent.withValues(alpha: 0.75),
      AppColors.accent.withValues(alpha: 0.45),
      AppColors.textTertiary,
    ];

    return [
      for (var i = 0; i < 26; i++)
        _SquareSeed(
          fromTop: i.isEven,
          x: 0.06 + random.nextDouble() * 0.88,
          size: 4 + random.nextDouble() * 5,
          delay: random.nextDouble() * 0.12,
          color: colors[i % colors.length],
          endOffset: Offset(
            math.cos(i * 2.399963) * (18 + random.nextDouble() * 52),
            math.sin(i * 2.399963) * (18 + random.nextDouble() * 52) * 0.9,
          ),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          RepaintBoundary(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                return CustomPaint(
                  painter: _SquareRainPainter(
                    progress: _controller.value,
                    squares: _squares,
                  ),
                );
              },
            ),
          ),
          Center(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                final t = ((_controller.value - 0.5) / 0.2).clamp(0.0, 1.0);
                final eased = Curves.easeOutCubic.transform(t);
                return Opacity(
                  opacity: eased,
                  child: Transform.translate(
                    offset: Offset(0, 12 * (1 - eased)),
                    child: child,
                  ),
                );
              },
              child: Text(
                '天启系统',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 12,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 单个数据方块的运动参数。
class _SquareSeed {
  const _SquareSeed({
    required this.fromTop,
    required this.x,
    required this.size,
    required this.delay,
    required this.color,
    required this.endOffset,
  });

  final bool fromTop;
  final double x;
  final double size;
  final double delay;
  final Color color;
  final Offset endOffset;
}

/// 绘制下落的方块、拖尾与汇聚后的波纹。
class _SquareRainPainter extends CustomPainter {
  _SquareRainPainter({required this.progress, required this.squares});

  final double progress;
  final List<_SquareSeed> squares;

  /// 方块汇聚并淡出的时间点。
  static const double _convergeEnd = 0.46;
  static const double _fadeEnd = 0.58;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final fade =
        1 -
        ((progress - _convergeEnd) / (_fadeEnd - _convergeEnd)).clamp(0.0, 1.0);
    if (fade > 0) {
      for (final square in squares) {
        _paintSquare(canvas, size, center, square, fade);
      }
    }
    _paintRipple(canvas, size, center);
  }

  void _paintSquare(
    Canvas canvas,
    Size size,
    Offset center,
    _SquareSeed square,
    double fade,
  ) {
    final span = _convergeEnd - square.delay;
    final raw = span <= 0 ? 1.0 : (progress - square.delay) / span;
    final t = raw.clamp(0.0, 1.0);
    final eased = Curves.easeInOutCubic.transform(t);

    final start = Offset(
      square.x * size.width,
      square.fromTop ? -square.size : size.height + square.size,
    );
    final end = center + square.endOffset;
    final head = Offset.lerp(start, end, eased)!;

    final paint = Paint()..color = square.color;
    // 数据流拖尾：沿运动路径逐渐变淡的小方块。
    for (var i = 4; i >= 1; i--) {
      final trailT = (t - i * 0.055).clamp(0.0, 1.0);
      final trail = Offset.lerp(
        start,
        end,
        Curves.easeInOutCubic.transform(trailT),
      )!;
      final trailAlpha = fade * (0.32 - i * 0.06);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: trail,
            width: square.size * (1 - i * 0.08),
            height: square.size * (1 - i * 0.08),
          ),
          const Radius.circular(1.5),
        ),
        paint
          ..color = square.color.withValues(alpha: trailAlpha.clamp(0.0, 1.0)),
      );
    }

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: head, width: square.size, height: square.size),
        const Radius.circular(1.8),
      ),
      paint..color = square.color.withValues(alpha: fade * 0.9),
    );
  }

  void _paintRipple(Canvas canvas, Size size, Offset center) {
    if (progress < 0.48) return;

    final t = ((progress - 0.48) / 0.4).clamp(0.0, 1.0);
    final eased = Curves.easeOutCubic.transform(t);
    final maxRadius = math.min(size.width, size.height) * 0.34;
    final radius = 8 + maxRadius * eased;
    final alpha = (1 - t) * 0.2;

    final soft = Paint()
      ..style = PaintingStyle.fill
      ..color = AppColors.accent.withValues(alpha: alpha * 0.18);
    canvas.drawCircle(center, radius * 0.92, soft);

    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = AppColors.accent.withValues(alpha: alpha);
    canvas.drawCircle(center, radius, ring);

    if (t > 0.12) {
      final innerT = ((t - 0.12) / 0.88).clamp(0.0, 1.0);
      final innerRing = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = AppColors.accent.withValues(alpha: (1 - innerT) * 0.12);
      canvas.drawCircle(center, radius * 0.62, innerRing);
    }
  }

  @override
  bool shouldRepaint(covariant _SquareRainPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
