import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/system_task.dart';

/// 调用智谱 GLM-4-Flash，按需生成单天任务。
///
/// API Key 通过 `--dart-define=GLM_API_KEY=xxx` 注入；
/// 未配置、请求失败或解析失败时返回当天的本地预设任务。
class AiService {
  const AiService();

  static const String _endpoint =
      'https://open.bigmodel.cn/api/paas/v4/chat/completions';
  static const String _apiKey = String.fromEnvironment('GLM_API_KEY');
  static const String _model = 'glm-4-flash';
  static const Duration _timeout = Duration(seconds: 30);
  static const int _minTasks = 4;
  static const int _maxTasks = 5;

  static const List<String> _categories = ['淬体', '冥想', '研习', '补给', '生存'];

  static String _systemPrompt(String goal, int day) =>
      '''
你是一个高冷的穿越系统。用户的目标是「$goal」，当前你需要专门为第 $day 天生成 4 到 5 个任务。

要求：
1. 只能在 07:00 到 23:00 之间安排任务，绝对不要在深夜安排高强度任务。
2. 同一天内任务的时间段不要重叠；上午适合逻辑思考，下午适合复习，晚上适合总结。
3. 每个任务时长控制在 30 分钟到 2 小时之间，任务之间留出 1-2 小时休息。
4. 每个任务必须包含 title、category、detailDescription、recommendedTime、searchKeyword、reward 字段。
5. detailDescription 请提供详细、专业且具有指导性的任务说明，字数在 80-120 字左右。说明中要包含具体的执行步骤或注意事项。
6. recommendedTime 格式严格为 "HH:mm - HH:mm"（24 小时制）。
7. title 为 3～6 个中文字主题词。
8. category 只能是：淬体、冥想、研习、补给、生存 之一。
9. searchKeyword 为 3～12 个中文字的搜索关键词，不要输出任何 URL。
10. reward 为「属性 +数值」格式，例如「体力 +2」。
11. 只返回 JSON 数组，绝对不要输出多余文字，也不要超过 5 个任务。

输出示例：
[{"title":"晨间阅读","category":"研习","detailDescription":"先通读 50 页并标记核心概念，再用自己的话写出三条要点笔记。阅读时关闭手机通知，每 25 分钟休息 5 分钟；遇到不理解的概念先记录，读完后统一查阅资料并补充到笔记中。","recommendedTime":"08:00 - 09:00","searchKeyword":"高效阅读方法","reward":"悟性 +1"}]
''';

  /// 为指定的一天生成 4～5 个任务，返回结果已按时间升序并写好 day 与编号。
  Future<List<SystemTask>> generateSingleDayPlan(String goal, int day) async {
    final targetDay = day.clamp(1, 7).toInt();

    if (_apiKey.isEmpty) {
      debugPrint('[AiService] 未配置 GLM_API_KEY，返回第 $targetDay 天本地任务');
      return _fallbackForDay(targetDay);
    }

    for (var attempt = 1; attempt <= 2; attempt++) {
      try {
        final response = await http
            .post(
              Uri.parse(_endpoint),
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $_apiKey',
              },
              body: jsonEncode({
                'model': _model,
                'messages': [
                  {'role': 'system', 'content': _systemPrompt(goal, targetDay)},
                  {'role': 'user', 'content': '生成第 $targetDay 天的任务。'},
                ],
                'temperature': 0.5,
                'max_tokens': 2048,
              }),
            )
            .timeout(_timeout);

        if (response.statusCode != 200) {
          debugPrint(
            '[AiService] HTTP ${response.statusCode}：${_snippet(response.body)}',
          );
          return _fallbackForDay(targetDay);
        }

        final content = _extractContent(response.bodyBytes);
        if (content == null) {
          debugPrint(
            '[AiService] 响应结构缺少 choices/message/content：'
            '${_snippet(utf8.decode(response.bodyBytes))}',
          );
          return _fallbackForDay(targetDay);
        }

        List<SystemTask> tasks;
        try {
          tasks = _parseTasks(content);
        } on FormatException catch (e) {
          debugPrint('[AiService] JSON 解析失败（第 $attempt 次）：$e');
          debugPrint('[AiService] 响应内容片段：${_snippet(content)}');
          if (attempt < 2) {
            debugPrint('[AiService] 自动重试一次...');
            continue;
          }
          return _fallbackForDay(targetDay);
        }

        if (tasks.length < _minTasks || tasks.length > _maxTasks) {
          debugPrint(
            '[AiService] 第 $targetDay 天任务数异常：'
            '${tasks.length}（要求 $_minTasks～$_maxTasks）',
          );
          if (attempt < 2) {
            debugPrint('[AiService] 自动重试一次...');
            continue;
          }
          return _fallbackForDay(targetDay);
        }

        return _finalizeSingleDayPlan(tasks, targetDay);
      } on TimeoutException catch (e) {
        debugPrint('[AiService] 请求超时（${_timeout.inSeconds}s）：$e');
        return _fallbackForDay(targetDay);
      } on http.ClientException catch (e) {
        debugPrint('[AiService] 网络请求失败：$e');
        return _fallbackForDay(targetDay);
      } on FormatException catch (e) {
        debugPrint('[AiService] 响应 JSON 解析失败：$e');
        return _fallbackForDay(targetDay);
      } catch (e, stackTrace) {
        debugPrint('[AiService] 生成失败 [${e.runtimeType}]：$e');
        debugPrint('[AiService] 堆栈：$stackTrace');
        return _fallbackForDay(targetDay);
      }
    }

    return _fallbackForDay(targetDay);
  }

  /// 强制写入当前 day，按推荐时间升序排序，并生成当天唯一编号。
  List<SystemTask> _finalizeSingleDayPlan(List<SystemTask> tasks, int day) {
    final ordered = [for (final task in tasks) task.copyWith(day: day)];

    final indexed = ordered.asMap().entries.toList()
      ..sort((a, b) {
        final byTime = _startMinutes(a.value).compareTo(_startMinutes(b.value));
        return byTime != 0 ? byTime : a.key.compareTo(b.key);
      });

    return [
      for (var i = 0; i < indexed.length; i++)
        indexed[i].value.copyWith(code: _codeFor(day, i)),
    ];
  }

  /// 每天预留 10 个编号区间，避免不同 day 的任务编号冲突。
  String _codeFor(int day, int index) {
    return ((day - 1) * 10 + index + 1).toString().padLeft(2, '0');
  }

  String _snippet(String text) {
    return text.length <= 300 ? text : '${text.substring(0, 300)}…';
  }

  String? _extractContent(List<int> bodyBytes) {
    final decoded = jsonDecode(utf8.decode(bodyBytes));
    if (decoded is! Map) return null;

    final choices = decoded['choices'];
    if (choices is! List || choices.isEmpty) return null;

    final first = choices.first;
    if (first is! Map) return null;

    final message = first['message'];
    if (message is! Map) return null;

    final content = message['content'];
    return content is String ? content : null;
  }

  List<SystemTask> _parseTasks(String? content) {
    if (content == null) return const [];

    final start = _minIndex(content.indexOf('{'), content.indexOf('['));
    final endBrace = content.lastIndexOf('}');
    final endBracket = content.lastIndexOf(']');
    final end = endBrace > endBracket ? endBrace : endBracket;
    if (start < 0 || end <= start) return const [];

    final decoded = jsonDecode(content.substring(start, end + 1));

    final List<dynamic> rawTasks;
    if (decoded is List) {
      rawTasks = decoded;
    } else if (decoded is Map && decoded['tasks'] is List) {
      rawTasks = decoded['tasks'] as List;
    } else {
      return const [];
    }

    final tasks = <SystemTask>[];
    for (final item in rawTasks) {
      if (item is! Map) continue;

      final title = (item['title'] ?? '').toString().trim();
      if (title.isEmpty) continue;

      final rawCategory = (item['category'] ?? '').toString().trim();
      final category = _categories.contains(rawCategory) ? rawCategory : '研习';

      final detail = (item['detail'] ?? item['description'] ?? '')
          .toString()
          .trim();
      final rawDetailDescription =
          (item['detailDescription'] ?? item['descriptionDetail'] ?? '')
              .toString()
              .trim();
      final recommendedTime = (item['recommendedTime'] ?? '').toString().trim();
      final searchKeyword = (item['searchKeyword'] ?? '').toString().trim();
      final resourceUrl = searchKeyword.isEmpty
          ? ''
          : Uri.https('search.bilibili.com', '/all', {
              'keyword': searchKeyword,
            }).toString();
      final reward = (item['reward'] ?? '').toString().trim();

      final safeDetail = detail.isEmpty ? '按系统计划完成今日任务。' : detail;

      tasks.add(
        SystemTask(
          code: '',
          category: category,
          title: title,
          detail: safeDetail,
          reward: reward.isEmpty ? '经验 +1' : reward,
          detailDescription: rawDetailDescription.isEmpty
              ? safeDetail
              : rawDetailDescription,
          recommendedTime: recommendedTime,
          resourceUrl: resourceUrl,
        ),
      );
    }

    return tasks;
  }

  int _minIndex(int a, int b) {
    if (a < 0) return b;
    if (b < 0) return a;
    return a < b ? a : b;
  }

  /// 提取 recommendedTime 的起始分钟数；无法解析时排到最后。
  int _startMinutes(SystemTask task) {
    final match = RegExp(r'(\d{1,2}):(\d{2})').firstMatch(task.recommendedTime);
    if (match == null) return 24 * 60;

    final hour = int.tryParse(match.group(1)!) ?? 24;
    final minute = int.tryParse(match.group(2)!) ?? 0;
    return hour * 60 + minute;
  }

  List<SystemTask> _fallbackForDay(int day) {
    return _finalizeSingleDayPlan(_fallbackTasks, day);
  }

  /// 任意一天的本地降级任务模板（5 条）。
  static const List<SystemTask> _fallbackTasks = [
    SystemTask(
      code: '',
      category: '淬体',
      title: '晨间淬体',
      detail: '完成 30 分钟晨练，唤醒身体状态。',
      reward: '体力 +2',
      detailDescription: '先进行 5 分钟关节活动与动态拉伸，激活肩颈和髋部；随后完成 20 分钟中低强度有氧，保持呼吸均匀；最后用 5 分钟静态拉伸放松大腿与背部，训练后及时补水。',
      recommendedTime: '07:30 - 08:30',
    ),
    SystemTask(
      code: '',
      category: '研习',
      title: '专注研习',
      detail: '专注学习核心知识，整理三条要点。',
      reward: '悟性 +2',
      detailDescription: '选定一个核心知识点，先精读教材或课程 40 分钟并标记关键句；再用 20 分钟整理三条可复述的笔记，尝试不看原文复述；最后做一组 5 道配套练习检验掌握程度，把错题与薄弱点单独记录。',
      recommendedTime: '10:00 - 11:30',
      resourceUrl: 'https://search.bilibili.com/all?keyword=%E5%AD%A6%E4%B9%A0%E6%96%B9%E6%B3%95',
    ),
    SystemTask(
      code: '',
      category: '研习',
      title: '午后复盘',
      detail: '回顾上午所学，完成一组针对性练习。',
      reward: '悟性 +1',
      detailDescription: '先花 10 分钟回顾上午笔记，找出两个仍模糊的知识点；随后完成一组针对性练习，限时 45 分钟并在完成后立即对答案；最后用 20 分钟整理错因，把两个薄弱点写成明日优先复习清单。',
      recommendedTime: '14:30 - 16:00',
    ),
    SystemTask(
      code: '',
      category: '补给',
      title: '补给休整',
      detail: '补充能量并短暂休息，恢复专注力。',
      reward: '体力 +1',
      detailDescription: '离开屏幕与工位，先补充 300-500ml 水分和一份含蛋白质的小食；随后到户外或走廊散步 15 分钟，活动肩颈与腰背；最后闭眼休息 5 分钟，避免刷短视频，让注意力真正恢复。',
      recommendedTime: '18:00 - 19:00',
    ),
    SystemTask(
      code: '',
      category: '冥想',
      title: '晚间总结',
      detail: '回顾当天完成情况，写下明日计划。',
      reward: '精神力 +2',
      detailDescription: '复盘今日已完成与未完成的任务，各写一句原因；记录今天遇到的一个问题及可能的解决思路；最后写下明日三个最重要的行动重点，并为每个重点预估所需时间，完成后关闭电子设备准备入睡。',
      recommendedTime: '20:30 - 21:30',
    ),
  ];
}
