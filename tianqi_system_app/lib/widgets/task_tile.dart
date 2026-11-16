import 'dart:async';

import 'package:flutter/material.dart';

import '../models/system_task.dart';
import '../theme.dart';

/// 正方形任务块：只显示主题词与分类图标。
///
/// 点击打开任务详情，伴随轻微按压缩放。
class TaskTile extends StatefulWidget {
  const TaskTile({
    super.key,
    required this.task,
    required this.completed,
    required this.onTap,
    this.appearDelay = Duration.zero,
  });

  final SystemTask task;
  final bool completed;
  final VoidCallback onTap;
  final Duration appearDelay;

  @override
  State<TaskTile> createState() => _TaskTileState();
}

class _TaskTileState extends State<TaskTile>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  late final AnimationController _appear = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );

  Timer? _appearTimer;
  bool _pressed = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    if (widget.appearDelay == Duration.zero) {
      _appear.forward();
    } else {
      _appearTimer = Timer(widget.appearDelay, () {
        if (mounted) _appear.forward();
      });
    }
  }

  @override
  void dispose() {
    _appearTimer?.cancel();
    _appear.dispose();
    super.dispose();
  }

  void _handleTap() {
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return AnimatedBuilder(
      animation: _appear,
      builder: (context, _) {
        final appear = Curves.easeOutCubic.transform(_appear.value);
        return Opacity(
          opacity: appear,
          child: Transform.translate(
            offset: Offset(0, 10 * (1 - appear)),
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOut,
              opacity: widget.completed ? 0.55 : 1,
              child: _buildTile(),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTile() {
    final completed = widget.completed;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _handleTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.95 : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(24),
            boxShadow: AppShadows.card,
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: completed
                              ? AppColors.surfaceMuted
                              : AppColors.accentSoft,
                        ),
                        child: Icon(
                          _iconFor(widget.task.category),
                          size: 16,
                          color: completed
                              ? AppColors.textTertiary
                              : AppColors.accent,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        widget.task.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                          color: completed
                              ? AppColors.textTertiary
                              : AppColors.textPrimary,
                          decoration: completed
                              ? TextDecoration.lineThrough
                              : TextDecoration.none,
                          decorationColor: AppColors.textTertiary,
                          decorationThickness: 1.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: 'SYS-${widget.task.code} // ',
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 8.5,
                                letterSpacing: 0.4,
                                color: AppColors.techLabel.withValues(
                                  alpha: completed ? 0.55 : 1,
                                ),
                              ),
                            ),
                            TextSpan(
                              text: completed ? '已完成' : widget.task.category,
                              style: TextStyle(
                                fontSize: 9,
                                letterSpacing: 0.6,
                                color: AppColors.techLabel.withValues(
                                  alpha: completed ? 0.55 : 1,
                                ),
                              ),
                            ),
                          ],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                      if (widget.task.recommendedTime.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          widget.task.recommendedTime,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 7.5,
                            fontFamily: 'monospace',
                            letterSpacing: 0.2,
                            color: AppColors.techLabel.withValues(
                              alpha: completed ? 0.55 : 0.85,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              // HUD 细节：左上角十字准星、右下角 L 型折角。
              Positioned(
                top: 12,
                left: 12,
                child: IgnorePointer(
                  child: CustomPaint(
                    size: const Size(12, 12),
                    painter: _CrosshairPainter(
                      color: AppColors.textTertiary.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 12,
                right: 12,
                child: IgnorePointer(
                  child: CustomPaint(
                    size: const Size(12, 12),
                    painter: _CornerMarkPainter(
                      color: AppColors.textTertiary.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ),
              if (completed)
                Positioned(
                  top: 12,
                  right: 12,
                  child: Icon(
                    Icons.check_circle_rounded,
                    size: 16,
                    color: AppColors.success,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 极浅的十字准星。
class _CrosshairPainter extends CustomPainter {
  const _CrosshairPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    final cx = size.width / 2;
    final cy = size.height / 2;
    canvas.drawLine(Offset(cx, 0), Offset(cx, cy - 2), paint);
    canvas.drawLine(Offset(cx, cy + 2), Offset(cx, size.height), paint);
    canvas.drawLine(Offset(0, cy), Offset(cx - 2, cy), paint);
    canvas.drawLine(Offset(cx + 2, cy), Offset(size.width, cy), paint);
  }

  @override
  bool shouldRepaint(covariant _CrosshairPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// 右下角的 L 型 HUD 折角。
class _CornerMarkPainter extends CustomPainter {
  const _CornerMarkPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    final path = Path()
      ..moveTo(size.width - 7, size.height)
      ..lineTo(size.width, size.height)
      ..lineTo(size.width, size.height - 7);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _CornerMarkPainter oldDelegate) =>
      oldDelegate.color != color;
}

IconData _iconFor(String category) {
  switch (category) {
    case '淬体':
      return Icons.fitness_center_rounded;
    case '冥想':
      return Icons.self_improvement_rounded;
    case '研习':
      return Icons.menu_book_rounded;
    case '补给':
      return Icons.inventory_2_rounded;
    case '生存':
      return Icons.water_drop_rounded;
    default:
      return Icons.auto_awesome_rounded;
  }
}
