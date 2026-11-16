import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/theme_provider.dart';
import '../theme.dart';
import 'hud_sheet_shell.dart';

/// HUD 风格时间选择器：Cupertino 滚轮 + 主题色 + 选中行装饰线。
class HudTimePickerSheet extends StatefulWidget {
  const HudTimePickerSheet({super.key, required this.initialTime});

  final TimeOfDay initialTime;

  @override
  State<HudTimePickerSheet> createState() => _HudTimePickerSheetState();
}

class _HudTimePickerSheetState extends State<HudTimePickerSheet> {
  late DateTime _value = DateTime(
    2020,
    1,
    1,
    widget.initialTime.hour,
    widget.initialTime.minute,
  );

  TimeOfDay get _time => TimeOfDay(hour: _value.hour, minute: _value.minute);

  String get _label {
    final hour = _time.hour.toString().padLeft(2, '0');
    final minute = _time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final palette = theme.isDarkRed ? AppPalette.darkRed : AppPalette.light;

    return HudSheetShell(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HudSheetHeader(
            label: '// SET WAKE TIME',
            onClose: () => Navigator.of(context).pop(),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  '选择唤醒时间',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: palette.textPrimary,
                  ),
                ),
              ),
              Text(
                'TIME: [ $_label ]',
                style: TextStyle(
                  fontSize: 12,
                  fontFamily: 'monospace',
                  letterSpacing: 0.4,
                  color: palette.accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            height: 196,
            decoration: BoxDecoration(
              color: palette.surfaceMuted.withValues(alpha: 0.35),
              border: Border(
                top: BorderSide(color: palette.divider, width: 1),
                bottom: BorderSide(color: palette.divider, width: 1),
              ),
            ),
            child: CupertinoTheme(
              data: CupertinoThemeData(
                brightness: palette.isDark ? Brightness.dark : Brightness.light,
                primaryColor: palette.accent,
                textTheme: CupertinoTextThemeData(
                  dateTimePickerTextStyle: TextStyle(
                    fontSize: 20,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w500,
                    color: palette.accent,
                  ),
                ),
              ),
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.time,
                use24hFormat: true,
                minuteInterval: 1,
                initialDateTime: _value,
                backgroundColor: Colors.transparent,
                onDateTimeChanged: (value) => setState(() => _value = value),
                selectionOverlayBuilder:
                    (context, {required selectedIndex, required columnCount}) {
                      return _HudSelectionOverlay(color: palette.accent);
                    },
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.of(context).pop(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Text(
                    '[ CANCEL ]',
                    style: TextStyle(
                      fontSize: 11,
                      fontFamily: 'monospace',
                      color: palette.textSecondary,
                    ),
                  ),
                ),
              ),
              const Spacer(),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.of(context).pop(_time),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Text(
                    '[ OK ]',
                    style: TextStyle(
                      fontSize: 11,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w700,
                      color: palette.accent,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 选中行的上下装饰线 + 两侧 `[ ]` 折角。
class _HudSelectionOverlay extends StatelessWidget {
  const _HudSelectionOverlay({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(painter: _HudSelectionPainter(color)),
    );
  }
}

class _HudSelectionPainter extends CustomPainter {
  const _HudSelectionPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final centerY = size.height / 2;
    final top = centerY - 21;
    final bottom = centerY + 21;
    final line = Paint()
      ..color = color.withValues(alpha: 0.55)
      ..strokeWidth = 1;

    canvas.drawLine(Offset(6, top), Offset(size.width - 6, top), line);
    canvas.drawLine(Offset(6, bottom), Offset(size.width - 6, bottom), line);

    // 左右极简折角，模拟 [ ]。
    final bracket = Paint()
      ..color = color.withValues(alpha: 0.8)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    canvas.drawPath(
      Path()
        ..moveTo(8, top - 5)
        ..lineTo(3, top - 5)
        ..lineTo(3, bottom + 5)
        ..lineTo(8, bottom + 5),
      bracket,
    );
    canvas.drawPath(
      Path()
        ..moveTo(size.width - 8, top - 5)
        ..lineTo(size.width - 3, top - 5)
        ..lineTo(size.width - 3, bottom + 5)
        ..lineTo(size.width - 8, bottom + 5),
      bracket,
    );
  }

  @override
  bool shouldRepaint(covariant _HudSelectionPainter oldDelegate) =>
      oldDelegate.color != color;
}
