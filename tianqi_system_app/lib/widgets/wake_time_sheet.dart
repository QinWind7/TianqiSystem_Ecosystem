import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/theme_provider.dart';
import '../theme.dart';
import 'hud_sheet_shell.dart';
import 'hud_time_picker_sheet.dart';

/// 系统设置：设置每日唤醒时间。
class WakeTimeSheet extends StatefulWidget {
  const WakeTimeSheet({super.key, required this.initialTime});

  final TimeOfDay initialTime;

  @override
  State<WakeTimeSheet> createState() => _WakeTimeSheetState();
}

class _WakeTimeSheetState extends State<WakeTimeSheet> {
  late TimeOfDay _time = widget.initialTime;

  String get _label {
    final hour = _time.hour.toString().padLeft(2, '0');
    final minute = _time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  Future<void> _pickTime() async {
    final picked = await showModalBottomSheet<TimeOfDay>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      builder: (_) => HudTimePickerSheet(initialTime: _time),
    );
    if (picked != null && mounted) {
      setState(() => _time = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final palette = theme.isDarkRed ? AppPalette.darkRed : AppPalette.light;

    return HudSheetShell(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HudSheetHeader(
            label: '// SYSTEM CONFIG',
            onClose: () => Navigator.of(context).pop(),
          ),
          const SizedBox(height: 10),
          Text(
            '系统设置',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: palette.textPrimary,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Text(
                'WAKE_TIME',
                style: TextStyle(
                  fontSize: 9,
                  fontFamily: 'monospace',
                  letterSpacing: 0.5,
                  color: palette.techLabel,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '系统唤醒时间',
                  style: TextStyle(fontSize: 13, color: palette.textPrimary),
                ),
              ),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _pickTime,
                child: Container(
                  padding: const EdgeInsets.only(bottom: 3),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: palette.accent.withValues(alpha: 0.45),
                        width: 1,
                      ),
                    ),
                  ),
                  child: Text(
                    'TIME: [ $_label ]',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'monospace',
                      letterSpacing: 0.3,
                      color: palette.accent,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '每天到点后，系统会推送通知提醒宿主查看今日任务。',
            style: TextStyle(
              fontSize: 11,
              height: 1.5,
              color: palette.textSecondary,
            ),
          ),
          const SizedBox(height: 22),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.of(context).pop(_time),
            child: Container(
              width: double.infinity,
              height: 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(2),
                border: Border.all(color: palette.accent, width: 1),
              ),
              child: Text(
                '>> SAVE_AND_ENABLE_ALARM()',
                style: TextStyle(
                  fontSize: 12,
                  fontFamily: 'monospace',
                  letterSpacing: 0.6,
                  fontWeight: FontWeight.w600,
                  color: palette.accent,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
