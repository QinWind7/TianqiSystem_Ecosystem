import 'dart:async';

import 'package:flutter/material.dart';

import '../theme.dart';

/// 逐字显示的文字，末尾带一个闪烁光标。
class TypewriterText extends StatefulWidget {
  const TypewriterText({
    super.key,
    required this.text,
    this.style,
    this.charDelay = const Duration(milliseconds: 55),
    this.onCompleted,
  });

  final String text;
  final TextStyle? style;
  final Duration charDelay;

  /// 全部字符显示完毕后回调一次。
  final VoidCallback? onCompleted;

  @override
  State<TypewriterText> createState() => _TypewriterTextState();
}

class _TypewriterTextState extends State<TypewriterText>
    with SingleTickerProviderStateMixin {
  Timer? _timer;
  int _visible = 0;
  bool _notified = false;

  late final AnimationController _cursor = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  )..repeat(reverse: true);

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(widget.charDelay, (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_visible >= widget.text.length) {
        timer.cancel();
        if (!_notified) {
          _notified = true;
          widget.onCompleted?.call();
        }
        return;
      }
      setState(() => _visible++);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _cursor.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textStyle = widget.style ?? const TextStyle();
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: widget.text.substring(0, _visible)),
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: FadeTransition(
              opacity: _cursor,
              child: Container(
                width: 2,
                height: (textStyle.fontSize ?? 14) * 1.15,
                margin: const EdgeInsets.only(left: 3),
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            ),
          ),
        ],
      ),
      style: textStyle,
    );
  }
}
