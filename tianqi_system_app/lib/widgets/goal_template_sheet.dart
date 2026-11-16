import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/theme_provider.dart';
import '../theme.dart';
import 'hud_sheet_shell.dart';

/// 系统预设目标指令。
class GoalTemplate {
  const GoalTemplate({
    required this.id,
    required this.title,
    required this.description,
    required this.fullPrompt,
  });

  final String id;
  final String title;
  final String description;
  final String fullPrompt;
}

/// 目标模板选择面板：点击后返回完整目标文本。
class GoalTemplateSheet extends StatelessWidget {
  const GoalTemplateSheet({super.key});

  static const List<GoalTemplate> templates = [
    GoalTemplate(
      id: 'SYS-T-01',
      title: '考研突围',
      description: '3个月完成初试全科复习，每日高效备考。',
      fullPrompt: '考研冲刺：3个月内完成初试全科复习，每天保持6小时高效学习',
    ),
    GoalTemplate(
      id: 'SYS-T-02',
      title: '基因重构',
      description: '体脂下降5%，强化力量与有氧训练。',
      fullPrompt: '减脂增肌：3个月内体脂率下降5%，每周4次力量训练并控制饮食',
    ),
    GoalTemplate(
      id: 'SYS-T-03',
      title: '知识汲取',
      description: '每周精读一本书并输出结构化笔记。',
      fullPrompt: '高效阅读：2个月内每周读完一本书，并输出一篇结构化读书笔记',
    ),
    GoalTemplate(
      id: 'SYS-T-04',
      title: '编制夺取',
      description: '行测申论双线推进，全真模拟冲刺。',
      fullPrompt: '考公上岸：3个月内完成行测与申论的系统复习，每周进行一次全真模拟',
    ),
    GoalTemplate(
      id: 'SYS-T-05',
      title: '外语破解',
      description: '词汇量突破8000，攻克长难句。',
      fullPrompt: '英语逆袭：2个月内词汇量突破8000，每天精读一篇外刊',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final palette = theme.isDarkRed ? AppPalette.darkRed : AppPalette.light;

    return HudSheetShell(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 4),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.72,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              HudSheetHeader(
                label: '// SYSTEM PRESETS',
                onClose: () => Navigator.of(context).pop(),
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Text(
                      '系统预设指令',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: palette.textPrimary,
                      ),
                    ),
                  ),
                  Text(
                    '[ ${templates.length.toString().padLeft(2, '0')} ]',
                    style: TextStyle(
                      fontSize: 9,
                      fontFamily: 'monospace',
                      color: palette.techLabel,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'SELECT PROTOCOL // 选择协议，快速注入目标',
                style: TextStyle(
                  fontSize: 10,
                  height: 1.4,
                  color: palette.textSecondary,
                ),
              ),
              const SizedBox(height: 6),
              for (var i = 0; i < templates.length; i++) ...[
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () =>
                      Navigator.of(context).pop(templates[i].fullPrompt),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 88,
                          child: Text(
                            '[ ${templates[i].id} ]',
                            style: TextStyle(
                              fontSize: 9,
                              height: 1.6,
                              fontFamily: 'monospace',
                              letterSpacing: 0.2,
                              color: palette.accent,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                templates[i].title,
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: palette.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                templates[i].description,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  height: 1.5,
                                  color: palette.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '>>',
                          style: TextStyle(
                            fontSize: 11,
                            fontFamily: 'monospace',
                            color: palette.accent.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (i != templates.length - 1)
                  Divider(height: 1, thickness: 1, color: palette.divider),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
