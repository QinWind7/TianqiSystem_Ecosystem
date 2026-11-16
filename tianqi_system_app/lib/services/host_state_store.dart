import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/system_task.dart';

/// 宿主状态：等级、经验、已完成任务编号、当天连击。
class HostState {
  const HostState({
    this.level = 1,
    this.exp = 0,
    this.completed = const <String>{},
    this.combo = 0,
    this.comboDate = '',
  });

  final int level;
  final int exp;
  final Set<String> completed;
  final int combo;
  final String comboDate;

  Map<String, dynamic> toJson() => {
    'level': level,
    'exp': exp,
    'completed': completed.toList(),
    'combo': combo,
    'comboDate': comboDate,
  };

  factory HostState.fromJson(Map<String, dynamic> json) {
    final rawCompleted = json['completed'];
    return HostState(
      level: (json['level'] as num?)?.toInt() ?? 1,
      exp: (json['exp'] as num?)?.toInt() ?? 0,
      completed: rawCompleted is List
          ? rawCompleted.map((item) => item.toString()).toSet()
          : const <String>{},
      combo: (json['combo'] as num?)?.toInt() ?? 0,
      comboDate: (json['comboDate'] ?? '').toString(),
    );
  }
}

/// 已持久化的分天任务缓存。
class CachedPlans {
  const CachedPlans({
    required this.currentDay,
    required this.goal,
    required this.dayTasks,
  });

  final int currentDay;
  final String goal;
  final Map<int, List<SystemTask>> dayTasks;
}

/// 将宿主状态序列化为 JSON 存入 SharedPreferences。
class HostStateStore {
  const HostStateStore();

  static const String _key = 'host_state';
  static const String _goalKey = 'host_goal';
  static const String _plansKey = 'cached_day_tasks';

  Future<String> loadGoal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_goalKey)?.trim() ?? '';
    } catch (_) {
      return '';
    }
  }

  Future<void> saveGoal(String goal) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_goalKey, goal);
    } catch (_) {
      // 目标持久化失败不阻塞主流程。
    }
  }

  Future<HostState> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null || raw.isEmpty) return const HostState();

      final decoded = jsonDecode(raw);
      if (decoded is! Map) return const HostState();

      return HostState.fromJson(Map<String, dynamic>.from(decoded));
    } catch (_) {
      return const HostState();
    }
  }

  Future<void> save(HostState state) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, jsonEncode(state.toJson()));
    } catch (_) {
      // 持久化失败不阻塞主流程。
    }
  }

  Future<CachedPlans?> loadPlans() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_plansKey);
      if (raw == null || raw.isEmpty) return null;

      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;

      final rawDays = decoded['days'];
      if (rawDays is! Map) return null;

      final dayTasks = <int, List<SystemTask>>{};
      for (final entry in rawDays.entries) {
        final day = int.tryParse(entry.key.toString());
        final value = entry.value;
        if (day == null || value is! List) continue;

        dayTasks[day] = [
          for (final item in value)
            if (item is Map)
              SystemTask.fromJson(Map<String, dynamic>.from(item)),
        ];
      }

      final rawDay = decoded['currentDay'] is num
          ? (decoded['currentDay'] as num).toInt()
          : 1;

      return CachedPlans(
        currentDay: rawDay.clamp(1, 7).toInt(),
        goal: (decoded['goal'] ?? '').toString(),
        dayTasks: dayTasks,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> savePlans(
    Map<int, List<SystemTask>> dayTasks,
    int currentDay,
    String goal,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _plansKey,
        jsonEncode({
          'currentDay': currentDay,
          'goal': goal,
          'days': {
            for (final entry in dayTasks.entries)
              entry.key.toString(): [
                for (final task in entry.value) task.toJson(),
              ],
          },
        }),
      );
    } catch (_) {
      // 缓存失败不阻塞主流程。
    }
  }

  Future<void> clearPlans() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_plansKey);
    } catch (_) {
      // 清除失败不阻塞主流程。
    }
  }
}
