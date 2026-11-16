import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/system_task.dart';
import '../providers/theme_provider.dart';
import '../services/ai_service.dart';
import '../services/api_service.dart';
import '../services/host_state_store.dart';
import '../services/notification_service.dart';
import '../theme.dart';
import '../widgets/app_background.dart';
import '../widgets/goal_template_sheet.dart';
import '../widgets/network_node_link.dart';
import '../widgets/wake_time_sheet.dart';

/// 系统主界面：顶部可收起的控制台 + 居中专注任务卡 + 底部任务切换。
class SystemHomeScreen extends StatefulWidget {
  const SystemHomeScreen({super.key});

  @override
  State<SystemHomeScreen> createState() => _SystemHomeScreenState();
}

class _SystemHomeScreenState extends State<SystemHomeScreen> {
  /// 已完成任务按编号记录。
  final Set<String> _completed = <String>{};
  final AiService _aiService = const AiService();
  final HostStateStore _stateStore = const HostStateStore();
  final TextEditingController _goalController = TextEditingController();
  final FocusNode _goalFocusNode = FocusNode();

  /// 按天缓存已生成的任务。
  final Map<int, List<SystemTask>> _dayPlansCache = {};

  int _level = 1;
  int _exp = 0;
  int _combo = 0;
  String _comboDate = '';
  int _currentDay = 1;
  String _activeGoal = '';
  String _savedGoal = '';
  double _taskDragDx = 0;
  bool _isLoadingDay = false;
  int _requestId = 0;
  int _activeTaskIndex = 0;

  /// 当前展开的卡片标识；与 _focusCardKey 不同时默认收起。
  String _expandedCardKey = '';
  bool get _isCardExpanded => _expandedCardKey == _focusCardKey;
  bool _panelOpen = false;
  TimeOfDay _wakeTime = const TimeOfDay(hour: 8, minute: 0);
  bool _sheetOpen = false;
  bool _levelUpVisible = false;
  Timer? _levelUpTimer;

  List<SystemTask> get _visibleTasks => _dayPlansCache[_currentDay] ?? const [];

  bool get _allTasksDone =>
      _visibleTasks.isNotEmpty && _doneCount == _visibleTasks.length;

  SystemTask? get _activeTask {
    final tasks = _visibleTasks;
    if (tasks.isEmpty || _allTasksDone) return null;
    final index = _activeTaskIndex.clamp(0, tasks.length - 1);
    return tasks[index];
  }

  int get _doneCount =>
      _visibleTasks.where((task) => _completed.contains(task.code)).length;
  int get _todayCombo => _comboDate == _todayKey() ? _combo : 0;

  /// 根据当前时间智能挑选要展示的任务。
  ///
  /// 优先级：时间段内 → 最近的下一个未完成任务 → 最近已过期的未完成任务。
  /// 全部完成或没有任务时返回 null。
  SystemTask? getCurrentTask(List<SystemTask> tasks) {
    if (tasks.isEmpty) return null;

    final now = DateTime.now();
    final nowMinutes = now.hour * 60 + now.minute;

    SystemTask? inProgress;
    SystemTask? upcoming;
    SystemTask? overdue;
    SystemTask? untimed;
    var upcomingGap = 1 << 30;
    var overdueGap = 1 << 30;

    for (final task in tasks) {
      if (_completed.contains(task.code)) continue;

      final range = _timeRange(task.recommendedTime);
      if (range == null) {
        untimed ??= task;
        continue;
      }

      final start = range.$1;
      final end = range.$2;
      if (nowMinutes >= start && nowMinutes < end) {
        inProgress ??= task;
      } else if (start >= nowMinutes) {
        final gap = start - nowMinutes;
        if (gap < upcomingGap) {
          upcoming = task;
          upcomingGap = gap;
        }
      } else {
        final gap = nowMinutes - start;
        if (gap < overdueGap) {
          overdue = task;
          overdueGap = gap;
        }
      }
    }

    return inProgress ?? upcoming ?? overdue ?? untimed;
  }

  /// 解析 "12:00 - 13:00" 为起止分钟数；只有一个时间时按 60 分钟计。
  (int, int)? _timeRange(String recommendedTime) {
    final matches = RegExp(r'(\d{1,2}):(\d{2})')
        .allMatches(recommendedTime)
        .toList();
    if (matches.isEmpty) return null;

    int toMinutes(RegExpMatch match) {
      final hour = int.tryParse(match.group(1)!);
      final minute = int.tryParse(match.group(2)!);
      if (hour == null || minute == null) return -1;
      return hour * 60 + minute;
    }

    final start = toMinutes(matches.first);
    if (start < 0) return null;
    final end = matches.length > 1 ? toMinutes(matches[1]) : start + 60;
    if (end <= start) return null;
    return (start, end);
  }

  int _smartIndexFor(List<SystemTask> tasks) {
    if (tasks.isEmpty) return 0;
    final task = getCurrentTask(tasks);
    if (task == null) return 0;
    final index = tasks.indexWhere((item) => item.code == task.code);
    return index < 0 ? 0 : index;
  }

  static String _todayKey() {
    final now = DateTime.now();
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    return '${now.year}-$month-$day';
  }

  @override
  void initState() {
    super.initState();
    _restoreState();
    _restoreGoal();
    _restorePlans();
    _restoreWakeTime();
  }

  Future<void> _restorePlans() async {
    final cached = await _stateStore.loadPlans();
    if (!mounted || cached == null || cached.dayTasks.isEmpty) return;

    setState(() {
      _dayPlansCache
        ..clear()
        ..addAll(cached.dayTasks);
      _currentDay = cached.currentDay;
      _activeTaskIndex = _smartIndexFor(
        cached.dayTasks[cached.currentDay] ?? const [],
      );
      if (cached.goal.isNotEmpty) {
        _activeGoal = cached.goal;
        _savedGoal = cached.goal;
        if (_goalController.text.isEmpty) {
          _goalController.value = TextEditingValue(
            text: cached.goal,
            selection: TextSelection.collapsed(offset: cached.goal.length),
          );
        }
      }
    });
  }

  void _persistPlans() {
    final snapshot = <int, List<SystemTask>>{
      for (final entry in _dayPlansCache.entries)
        entry.key: List<SystemTask>.of(entry.value),
    };
    _stateStore.savePlans(
      snapshot,
      _currentDay,
      _activeGoal.isNotEmpty ? _activeGoal : _savedGoal,
    );
  }

  Future<void> _restoreGoal() async {
    final goal = await _stateStore.loadGoal();
    if (!mounted || goal.isEmpty) return;

    _savedGoal = goal;
    if (_goalController.text.isEmpty) {
      _goalController.value = TextEditingValue(
        text: goal,
        selection: TextSelection.collapsed(offset: goal.length),
      );
    }
  }

  Future<void> _restoreWakeTime() async {
    final time = await NotificationService.instance.loadWakeTime();
    if (!mounted) return;
    setState(() => _wakeTime = time);
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  Future<void> _openSettings() async {
    setState(() => _sheetOpen = true);
    final selected = await showModalBottomSheet<TimeOfDay>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.15),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      builder: (sheetContext) {
        return WakeTimeSheet(initialTime: _wakeTime);
      },
    );
    if (!mounted) return;
    setState(() => _sheetOpen = false);
    if (selected == null) return;

    setState(() => _wakeTime = selected);

    var granted = false;
    try {
      granted = await NotificationService.instance.setWakeTime(selected);
    } catch (_) {
      granted = false;
    }
    if (!mounted) return;

    final label = _formatTime(selected);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          granted ? '已设置每日 $label 系统唤醒提醒' : '已保存 $label，但通知权限未开启，可能无法收到提醒',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _restoreState() async {
    final state = await _stateStore.load();
    if (!mounted) return;

    setState(() {
      _level = state.level < 1 ? 1 : state.level;
      _exp = state.exp.clamp(0, 99).toInt();
      _completed
        ..clear()
        ..addAll(state.completed);
      _combo = state.combo;
      _comboDate = state.comboDate;
      // 完成记录恢复后，重新挑选当前时段应展示的任务。
      if (_visibleTasks.isNotEmpty) {
        _activeTaskIndex = _smartIndexFor(_visibleTasks);
      }
    });
  }

  void _saveState() {
    _stateStore.save(
      HostState(
        level: _level,
        exp: _exp,
        completed: Set<String>.of(_completed),
        combo: _combo,
        comboDate: _comboDate,
      ),
    );
  }

  @override
  void dispose() {
    _levelUpTimer?.cancel();
    _goalController.dispose();
    _goalFocusNode.dispose();
    super.dispose();
  }

  void _togglePanel() {
    if (_panelOpen) {
      _closePanel();
    } else {
      setState(() => _panelOpen = true);
    }
  }

  void _closePanel() {
    if (!_panelOpen) return;
    FocusScope.of(context).unfocus();
    setState(() => _panelOpen = false);
  }

  /// 左右滑动或点击箭头切换当前展示的任务。
  void _stepTask(int delta) {
    final tasks = _visibleTasks;
    if (tasks.length < 2) return;

    final next = (_activeTaskIndex + delta).clamp(0, tasks.length - 1);
    if (next == _activeTaskIndex) return;

    HapticFeedback.selectionClick();
    setState(() => _activeTaskIndex = next);
  }

  Future<void> _showTemplates() async {
    FocusScope.of(context).unfocus();
    setState(() => _sheetOpen = true);
    final goal = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.15),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      builder: (sheetContext) => const GoalTemplateSheet(),
    );
    if (!mounted) return;
    setState(() => _sheetOpen = false);
    if (goal == null) return;

    setState(() {
      _goalController.value = TextEditingValue(
        text: goal,
        selection: TextSelection.collapsed(offset: goal.length),
      );
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _goalFocusNode.requestFocus();
    });
  }

  Future<void> _generateTasks() async {
    FocusScope.of(context).unfocus();

    final goal = _goalController.text.trim();
    if (goal.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请先输入你的长期目标'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final previousGoal = _activeGoal.isNotEmpty ? _activeGoal : _savedGoal;
    final isNewPlan = previousGoal.isNotEmpty && previousGoal != goal;

    // 目标未变且已有缓存：不重复请求，也不重置任何进度。
    if (!isNewPlan && _dayPlansCache.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('当前目标已生成因果线，长按 Day 标签可重新生成该天任务'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (isNewPlan) {
      final confirmed = await _confirmNewPlan();
      if (!confirmed || !mounted) return;
    }

    final requestId = ++_requestId;
    setState(() {
      _activeGoal = goal;
      _savedGoal = goal;
      _panelOpen = false;
      _activeTaskIndex = 0;
      if (_dayPlansCache.isEmpty) _currentDay = 1;
      if (isNewPlan) {
        _currentDay = 1;
        _dayPlansCache.clear();
        _completed.clear();
        _level = 1;
        _exp = 0;
        _combo = 0;
        _comboDate = '';
        _levelUpTimer?.cancel();
        _levelUpVisible = false;
      }
      _isLoadingDay = true;
    });
    if (isNewPlan) {
      _stateStore.clearPlans();
      _saveState();
    }
    _stateStore.saveGoal(goal);

    List<SystemTask> tasks;
    try {
      tasks = await _aiService.generateSingleDayPlan(goal, 1);
    } catch (_) {
      if (!mounted || requestId != _requestId) return;
      setState(() => _isLoadingDay = false);
      return;
    }
    if (!mounted || requestId != _requestId) return;

    setState(() {
      _dayPlansCache[1] = tasks;
      _isLoadingDay = false;
      _activeTaskIndex = _smartIndexFor(tasks);
    });
    _persistPlans();
  }

  Future<bool> _confirmNewPlan() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('目标已修改'),
        content: const Text('将开启新档，清空当前任务缓存、等级、经验、连击与完成记录。是否继续？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('确认开新档'),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  void _selectDay(int day) {
    if (day == _currentDay) return;
    setState(() {
      _currentDay = day;
      _activeTaskIndex = _smartIndexFor(_dayPlansCache[day] ?? const []);
      _panelOpen = false;
    });
    _persistPlans();

    if (!_dayPlansCache.containsKey(day)) {
      _loadDay(day);
    }
  }

  /// 重新生成某一天的任务：只清除该天的缓存与完成记录，不动其余进度。
  Future<void> _refreshDay(int day) async {
    if (_isLoadingDay || _activeGoal.isEmpty) return;

    final oldTasks = _dayPlansCache[day];
    final requestId = ++_requestId;
    setState(() {
      _currentDay = day;
      _activeTaskIndex = 0;
      if (oldTasks != null) {
        final oldCodes = oldTasks.map((task) => task.code).toSet();
        _completed.removeAll(oldCodes);
        _dayPlansCache.remove(day);
      }
      _isLoadingDay = true;
    });
    _saveState();
    _persistPlans();

    List<SystemTask> tasks;
    try {
      tasks = await _aiService.generateSingleDayPlan(_activeGoal, day);
    } catch (_) {
      if (!mounted || requestId != _requestId) return;
      setState(() => _isLoadingDay = false);
      return;
    }
    if (!mounted || requestId != _requestId) return;

    setState(() {
      _dayPlansCache[day] = tasks;
      _isLoadingDay = false;
      _activeTaskIndex = _smartIndexFor(tasks);
    });
    _persistPlans();
  }

  /// 按需生成某一天的任务并写入缓存。
  Future<void> _loadDay(int day) async {
    if (_isLoadingDay || _dayPlansCache.containsKey(day)) return;
    if (_activeGoal.isEmpty) return;

    final requestId = ++_requestId;
    setState(() => _isLoadingDay = true);

    List<SystemTask> tasks;
    try {
      tasks = await _aiService.generateSingleDayPlan(_activeGoal, day);
    } catch (_) {
      if (!mounted || requestId != _requestId) return;
      setState(() => _isLoadingDay = false);
      return;
    }
    if (!mounted || requestId != _requestId) return;

    setState(() {
      _dayPlansCache[day] = tasks;
      _isLoadingDay = false;
      _activeTaskIndex = _smartIndexFor(tasks);
    });
    _persistPlans();
  }

  /// 当前天没有缓存且未在加载时，下一帧自动发起请求。
  void _scheduleAutoLoadIfNeeded() {
    if (_isLoadingDay || _visibleTasks.isNotEmpty) return;
    if (_activeGoal.isEmpty) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_isLoadingDay || _visibleTasks.isNotEmpty) return;
      _loadDay(_currentDay);
    });
  }

  void _handleComplete(String code) {
    if (_completed.contains(code)) return;

    final today = _todayKey();
    final sameDay = _comboDate == today;

    var level = _level;
    var exp = _exp + 10;
    var leveledUp = false;
    while (exp >= 100) {
      exp -= 100;
      level += 1;
      leveledUp = true;
    }

    setState(() {
      _completed.add(code);
      _level = level;
      _exp = exp;
      _combo = sameDay ? _combo + 1 : 1;
      _comboDate = today;
    });

    _saveState();
    unawaited(_syncStatusToCloud());

    if (leveledUp) _showLevelUp();
  }

  /// 静默上报宿主状态：未登录直接跳过，失败只做轻提示，不影响本地进度。
  Future<void> _syncStatusToCloud() async {
    if (!await ApiService.instance.hasSession()) return;

    try {
      await ApiService.instance.syncStatus(
        level: _level,
        exp: _exp,
        streak: _combo,
        streakDate: _comboDate.isEmpty ? null : _comboDate,
      );
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        const SnackBar(
          content: Text('任务完成，云端同步成功'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(milliseconds: 1600),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        const SnackBar(
          content: Text('云端同步失败，本地进度已保存'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// 居中卡片的主按钮：取消提醒并直接完成任务。
  void _completeTask(SystemTask task) {
    if (_completed.contains(task.code)) return;
    HapticFeedback.mediumImpact();
    unawaited(NotificationService.instance.cancelTaskReminder(task));
    if (task.isReminderOn) {
      _updateTask(task.copyWith(isReminderOn: false));
    }
    _handleComplete(task.code);
    _advanceToNextTask();
  }

  /// 完成一项后，自动切换到下一个当前时段应执行的任务。
  void _advanceToNextTask() {
    final tasks = _visibleTasks;
    if (tasks.isEmpty) return;

    final next = getCurrentTask(tasks);
    if (next == null) {
      // 当日任务已全部完成，卡片切换到提示态。
      setState(() => _activeTaskIndex = 0);
      return;
    }

    final index = tasks.indexWhere((item) => item.code == next.code);
    if (index < 0) return;

    setState(() => _activeTaskIndex = index);
  }

  void _showLevelUp() {
    _levelUpTimer?.cancel();
    setState(() => _levelUpVisible = true);
    _levelUpTimer = Timer(const Duration(milliseconds: 1600), () {
      if (mounted) setState(() => _levelUpVisible = false);
    });
  }

  /// 用最新的任务对象替换缓存中的同名任务并持久化。
  void _updateTask(SystemTask updated) {
    final dayTasks = _dayPlansCache[updated.day];
    if (dayTasks == null) return;
    final index = dayTasks.indexWhere((item) => item.code == updated.code);
    if (index < 0) return;

    setState(() => dayTasks[index] = updated);
    _persistPlans();
  }

  /// 卡片底部的提醒开关：开启时调度单任务通知，关闭时取消。
  Future<void> _toggleReminder(SystemTask task, bool value) async {
    if (!value) {
      _updateTask(task.copyWith(isReminderOn: false));
      await NotificationService.instance.cancelTaskReminder(task);
      return;
    }

    final scheduled = await NotificationService.instance.scheduleTaskReminder(
      task,
    );
    if (!mounted) return;
    if (!scheduled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('无法解析推荐时间或通知权限未开启，提醒未设置'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    _updateTask(task.copyWith(isReminderOn: true));
  }

  /// 打开任务的资料链接；没有链接时不做任何事。
  Future<void> _openResource(String url) async {
    final uri = Uri.tryParse(url.trim());
    if (uri == null) return;

    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened) throw Exception('launch failed');
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('无法打开资料链接'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// 解析开始时间，如 "12:00 - 13:00" → "12:00"。
  String _startLabel(String recommendedTime) {
    final match = RegExp(r'(\d{1,2}):(\d{2})').firstMatch(recommendedTime);
    if (match == null) return '--:--';
    final hour = int.tryParse(match.group(1)!);
    final minute = int.tryParse(match.group(2)!);
    if (hour == null || minute == null) return '--:--';
    return '${hour.toString().padLeft(2, '0')}:'
        '${minute.toString().padLeft(2, '0')}';
  }

  /// 由时间段计算限时时长，如 "12:00 - 12:45" → "45 min"。
  String _durationLabel(String recommendedTime) {
    final matches = RegExp(r'(\d{1,2}):(\d{2})')
        .allMatches(recommendedTime)
        .toList();
    if (matches.length < 2) return '—';

    int toMinutes(RegExpMatch match) {
      final hour = int.tryParse(match.group(1)!) ?? 0;
      final minute = int.tryParse(match.group(2)!) ?? 0;
      return hour * 60 + minute;
    }

    final minutes = toMinutes(matches[1]) - toMinutes(matches[0]);
    if (minutes <= 0) return '—';
    return '$minutes min';
  }

  @override
  Widget build(BuildContext context) {
    // 顶层显式依赖主题：切换皮肤时整页（背景、页码、版本号）一起重建。
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDarkRed;
    final scaffoldColor = isDark
        ? AppPalette.darkRed.background
        : AppPalette.light.background;
    final keyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;
    final tasks = _visibleTasks;

    return Scaffold(
      backgroundColor: scaffoldColor,
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          Positioned.fill(
            child: AppBackground(
              isDark: isDark,
              child: SafeArea(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final cardWidth = constraints.maxWidth * 0.85;

                    return Column(
                      children: [
                        // 顶部触发栏占位。
                        const SizedBox(height: 46),
                        Expanded(
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                NetworkNodeLink(),
                                const SizedBox(height: 18),
                                GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onHorizontalDragStart: (_) => _taskDragDx = 0,
                                  onHorizontalDragUpdate: (details) {
                                    _taskDragDx += details.delta.dx;
                                  },
                                  onHorizontalDragEnd: (_) {
                                    if (_taskDragDx <= -48) {
                                      _stepTask(1);
                                    } else if (_taskDragDx >= 48) {
                                      _stepTask(-1);
                                    }
                                    _taskDragDx = 0;
                                  },
                                  child: AnimatedSize(
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves.easeInOut,
                                    alignment: Alignment.center,
                                    child: SizedBox(
                                      width: cardWidth,
                                      child: AnimatedSwitcher(
                                        duration: const Duration(
                                          milliseconds: 340,
                                        ),
                                        switchInCurve: Curves.easeOutCubic,
                                        switchOutCurve: Curves.easeInCubic,
                                        layoutBuilder:
                                            (currentChild, previousChildren) {
                                              return Stack(
                                                alignment: Alignment.center,
                                                children: [
                                                  ...previousChildren,
                                                  ?currentChild,
                                                ],
                                              );
                                            },
                                        transitionBuilder: (child, animation) {
                                          final slide = Tween<Offset>(
                                            begin: const Offset(0.24, 0),
                                            end: Offset.zero,
                                          ).animate(animation);
                                          return ClipRect(
                                            child: FadeTransition(
                                              opacity: animation,
                                              child: SlideTransition(
                                                position: slide,
                                                child: child,
                                              ),
                                            ),
                                          );
                                        },
                                        child: KeyedSubtree(
                                          // key 中带入完成状态：完成后强制换新卡片并触发切换动画。
                                          key: ValueKey(
                                            '$_focusCardKey-'
                                            '${_completed.contains(_activeTask?.code ?? '')}',
                                          ),
                                          child: _buildFocusCard(_activeTask),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (!keyboardVisible) ...[
                          const SizedBox(height: 6),
                          _buildTaskNav(tasks),
                          const SizedBox(height: 8),
                          Text(
                            'SYSTEM VERSION 1.0.4 // ALL RIGHTS RESERVED',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 8,
                              letterSpacing: 1.1,
                              fontFamily: 'monospace',
                              color: AppColors.techLabel,
                            ),
                          ),
                          const SizedBox(height: 6),
                        ],
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
          // 顶部边缘触发区。
          _buildTopTrigger(),
          // 控制台展开时的遮罩，点击收起。
          Positioned.fill(
            child: IgnorePointer(
              ignoring: !_panelOpen,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _closePanel,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 220),
                  opacity: _panelOpen ? 1 : 0,
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
                    child: const ColoredBox(color: Color(0x0A000000)),
                  ),
                ),
              ),
            ),
          ),
          // 顶部滑出的功能控制台。
          _buildControlPanel(),
          // 弹窗打开时，主界面轻微变暗并柔化，突出弹窗层级。
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOut,
                opacity: _sheetOpen ? 1 : 0,
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
                  child: const ColoredBox(color: Color(0x0A000000)),
                ),
              ),
            ),
          ),
          // 升级提示：全屏微光，不拦截操作。
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 320),
                curve: Curves.easeOut,
                opacity: _levelUpVisible ? 1 : 0,
                child: _LevelUpFlash(level: _level),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopTrigger() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        bottom: false,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _togglePanel,
          onVerticalDragEnd: (details) {
            final velocity = details.primaryVelocity ?? 0;
            if (velocity > 120 && !_panelOpen) {
              setState(() => _panelOpen = true);
            } else if (velocity < -120 && _panelOpen) {
              _closePanel();
            }
          },
          child: SizedBox(
            height: 42,
            child: Center(
              child: AnimatedRotation(
                turns: _panelOpen ? 0.5 : 0,
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                child: Container(
                  width: 46,
                  height: 22,
                  decoration: BoxDecoration(
                    color: AppColors.surface.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(color: AppColors.divider),
                    boxShadow: AppShadows.card,
                  ),
                  child: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 15,
                    color: AppColors.textTertiary,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildControlPanel() {
    final maxHeight = MediaQuery.sizeOf(context).height * 0.72;
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: AnimatedSlide(
        offset: _panelOpen ? Offset.zero : const Offset(0, -1.05),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        child: GestureDetector(
          onVerticalDragEnd: (details) {
            if ((details.primaryVelocity ?? 0) > 120) _closePanel();
          },
          child: SafeArea(
            bottom: false,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxHeight),
              child: SingleChildScrollView(
                child: Container(
                  margin: const EdgeInsets.fromLTRB(10, 8, 10, 0),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: AppShadows.panel,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Stack(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildPanelHeader(),
                              const SizedBox(height: 12),
                              _buildHostStatus(),
                              const SizedBox(height: 10),
                              _buildThemeEntry(),
                              const SizedBox(height: 12),
                              _buildGoalInput(),
                              const SizedBox(height: 12),
                              _buildDaySwitcher(),
                              const SizedBox(height: 8),
                              Text(
                                '点击 Day 切换 · 长按重新生成该天任务',
                                style: TextStyle(
                                  fontSize: 8.5,
                                  letterSpacing: 0.2,
                                  color: AppColors.techLabel,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Positioned.fill(
                          child: IgnorePointer(
                            child: CustomPaint(
                              painter: _HudFramePainter(AppColors.accent),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPanelHeader() {
    return Row(
      children: [
        Container(
          width: 3,
          height: 14,
          decoration: BoxDecoration(
            color: AppColors.accent,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '天命系统',
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          'CONTROL',
          style: TextStyle(
            fontSize: 8.5,
            letterSpacing: 1.2,
            color: AppColors.textTertiary,
          ),
        ),
        const Spacer(),
        if (_visibleTasks.isNotEmpty) ...[
          Text(
            '$_doneCount/${_visibleTasks.length}',
            style: TextStyle(
              fontSize: 9.5,
              fontFamily: 'monospace',
              color: AppColors.techLabel,
            ),
          ),
          const SizedBox(width: 10),
        ],
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            _closePanel();
            _openSettings();
          },
          child: Padding(
            padding: EdgeInsets.all(4),
            child: Icon(
              Icons.settings_outlined,
              size: 16,
              color: AppColors.textTertiary,
            ),
          ),
        ),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _closePanel,
          child: Padding(
            padding: EdgeInsets.all(4),
            child: Icon(
              Icons.keyboard_arrow_up_rounded,
              size: 18,
              color: AppColors.textTertiary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHostStatus() {
    final combo = _todayCombo;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.accentSoft,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            'LV.$_level',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
              color: AppColors.accent,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: SizedBox(
              height: 3,
              child: Stack(
                children: [
                  Positioned.fill(child: ColoredBox(color: AppColors.divider)),
                  Positioned.fill(
                    child: TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: 0, end: _exp / 100),
                      duration: const Duration(milliseconds: 380),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, _) {
                        return FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: value,
                          child: ColoredBox(color: AppColors.accent),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          'EXP: $_exp/100',
          style: TextStyle(
            fontSize: 9.5,
            fontFamily: 'monospace',
            letterSpacing: 0.3,
            color: AppColors.techLabel,
          ),
        ),
        if (combo >= 2) ...[
          const SizedBox(width: 10),
          Text(
            '$combo 连击',
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w600,
              color: AppColors.accent,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildThemeEntry() {
    final themeProvider = context.watch<ThemeProvider>();
    return Row(
      children: [
        Text(
          'THEME',
          style: TextStyle(
            fontSize: 8.5,
            letterSpacing: 1.2,
            fontFamily: 'monospace',
            color: AppColors.techLabel,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: Container(height: 1, color: AppColors.divider)),
        const SizedBox(width: 8),
        _buildThemeChip(
          '极简白',
          !themeProvider.isDarkRed,
          () => themeProvider.setMode(AppThemeMode.light),
        ),
        const SizedBox(width: 6),
        _buildThemeChip(
          '黑红警报',
          themeProvider.isDarkRed,
          () => themeProvider.setMode(AppThemeMode.darkRed),
        ),
      ],
    );
  }

  Widget _buildThemeChip(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? AppColors.accent : AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: selected ? AppColors.accent : AppColors.divider,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
            color: selected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildGoalInput() {
    return Row(
      children: [
        SizedBox(
          height: 44,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _isLoadingDay ? null : _showTemplates,
            child: Center(
              child: Text(
                '[ 模板 ]',
                style: TextStyle(
                  fontSize: 11,
                  fontFamily: 'monospace',
                  letterSpacing: 0.4,
                  color: AppColors.accent,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: SizedBox(
            height: 44,
            child: Row(
              children: [
                Text(
                  '>_',
                  style: TextStyle(
                    fontSize: 12,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w600,
                    color: AppColors.accent,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: TextField(
                    controller: _goalController,
                    focusNode: _goalFocusNode,
                    enabled: !_isLoadingDay,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _generateTasks(),
                    style: TextStyle(
                      fontSize: 12,
                      fontFamily: 'monospace',
                      color: AppColors.textPrimary,
                    ),
                    cursorColor: AppColors.accent,
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: '输入你的长期目标',
                      hintStyle: TextStyle(
                        fontSize: 11.5,
                        fontFamily: 'monospace',
                        color: AppColors.textTertiary,
                      ),
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          height: 44,
          child: OutlinedButton(
            onPressed: _isLoadingDay
                ? null
                : () {
                    FocusScope.of(context).unfocus();
                    _generateTasks();
                  },
            style: OutlinedButton.styleFrom(
              backgroundColor: Colors.transparent,
              foregroundColor: AppColors.accent,
              disabledForegroundColor: AppColors.textTertiary,
              side: BorderSide(
                color: _isLoadingDay
                    ? AppColors.divider
                    : AppColors.accent.withValues(alpha: 0.75),
                width: 1,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            child: _isLoadingDay
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.accent,
                    ),
                  )
                : const Text(
                    '生成',
                    style: TextStyle(
                      fontSize: 11,
                      fontFamily: 'monospace',
                      letterSpacing: 0.4,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildDaySwitcher() {
    return SizedBox(
      height: 28,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: 7,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final day = index + 1;
          final selected = day == _currentDay;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _selectDay(day),
            onLongPress: () => _refreshDay(day),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: selected ? AppColors.accent : Colors.transparent,
                    width: 1.5,
                  ),
                ),
              ),
              child: Text(
                '[ Day $day ]',
                style: TextStyle(
                  fontSize: 9.5,
                  fontFamily: 'monospace',
                  letterSpacing: 0.3,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                  color: selected ? AppColors.accent : AppColors.textSecondary,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// 居中卡片的切换标识，用于 AnimatedSwitcher 的滑出动画。
  String get _focusCardKey {
    final task = _activeTask;
    if (task != null) return 'task-${task.code}';
    if (_isLoadingDay) return 'loading-$_currentDay';
    if (_allTasksDone) return 'done-$_currentDay';
    return 'idle-$_currentDay';
  }

  Widget _buildFocusCard(SystemTask? task) {
    if (task != null) return _buildActiveTaskCard(task);

    if (_isLoadingDay) {
      return _buildCardShell(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.accent,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '系统正在计算第 $_currentDay 天的因果线...',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: AppColors.textTertiary),
            ),
          ],
        ),
      );
    }

    _scheduleAutoLoadIfNeeded();

    return _buildCardShell(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const _PulseDot(),
          const SizedBox(height: 14),
          Text(
            '【系统提示】',
            style: TextStyle(
              fontSize: 10,
              letterSpacing: 1.2,
              color: AppColors.textTertiary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '当前时段无强制任务\n宿主可自行安排，或点击顶部生成新指令',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11.5,
              height: 1.7,
              color: AppColors.textSecondary,
            ),
          ),
          if (_activeGoal.isEmpty) ...[
            const SizedBox(height: 18),
            OutlinedButton(
              onPressed: () => setState(() => _panelOpen = true),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.accent,
                side: BorderSide(color: AppColors.divider),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('展开控制台', style: TextStyle(fontSize: 11.5)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCardShell({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        boxShadow: AppShadows.focusCard,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: DecoratedBox(
            decoration: BoxDecoration(color: AppColors.surface),
            child: Stack(
              children: [
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: _HudTexturePainter(AppColors.accent),
                    ),
                  ),
                ),
                Padding(padding: const EdgeInsets.all(16), child: child),
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: _HudFramePainter(AppColors.accent),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActiveTaskCard(SystemTask task) {
    final completed = _completed.contains(task.code);
    final description = task.detailDescription.trim().isEmpty
        ? task.detail
        : task.detailDescription;

    return _buildCardShell(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(
              () => _expandedCardKey = _isCardExpanded ? '' : _focusCardKey,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppColors.techLabel.withValues(alpha: 0.45),
                          width: 0.7,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _PulseDot(),
                          SizedBox(width: 6),
                          Text(
                            '【叮！】',
                            style: TextStyle(
                              fontSize: 9,
                              letterSpacing: 0.6,
                              color: AppColors.techLabel,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '当前时间，宿主需执行以下任务',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 9.5,
                          letterSpacing: 0.3,
                          color: AppColors.techLabel,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(3),
                        border: Border.all(
                          color: completed
                              ? AppColors.divider
                              : AppColors.accent.withValues(alpha: 0.35),
                          width: 0.7,
                        ),
                      ),
                      child: Text(
                        task.category,
                        style: TextStyle(
                          fontSize: 9,
                          letterSpacing: 0.8,
                          color: completed
                              ? AppColors.textTertiary
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'SYS-${task.code} // DAY $_currentDay',
                      style: TextStyle(
                        fontSize: 8,
                        fontFamily: 'monospace',
                        letterSpacing: 0.8,
                        color: AppColors.techLabel,
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      _isCardExpanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      size: 14,
                      color: AppColors.techLabel,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  task.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                    color: completed
                        ? AppColors.textTertiary
                        : AppColors.textPrimary,
                    decoration: completed
                        ? TextDecoration.lineThrough
                        : TextDecoration.none,
                    decorationColor: AppColors.textTertiary,
                  ),
                ),
                if (!_isCardExpanded) ...[
                  const SizedBox(height: 4),
                  const Text(
                    '[ 点击此区域解算任务详情 ]',
                    style: TextStyle(
                      fontSize: 12,
                      fontFamily: 'monospace',
                      color: Colors.grey,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (_isCardExpanded) ...[
            const SizedBox(height: 6),
            _TaskDetailTypewriter(
              task: task,
              description: description,
              onOpenResource: _openResource,
            ),
          ] else
            const SizedBox(height: 8),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '[ TIME: ${_startLabel(task.recommendedTime)} ] // '
                    '[ LIMIT: ${_durationLabel(task.recommendedTime).toUpperCase()} ]',
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 8.5,
                      fontFamily: 'monospace',
                      letterSpacing: 0.3,
                      color: AppColors.techLabel,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              _buildReminderToggle(task, completed),
            ],
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: completed ? null : () => _completeTask(task),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                child: Text(
                  completed
                      ? '>> EXECUTE_COMPLETED()'
                      : '>> EXECUTE_COMPLETE()',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontFamily: 'monospace',
                    letterSpacing: 0.4,
                    color: completed
                        ? AppColors.textTertiary
                        : AppColors.accent,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 极简提醒开关：开启调度单任务通知，关闭则取消。
  Widget _buildReminderToggle(SystemTask task, bool completed) {
    final value = !completed && task.isReminderOn;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: completed ? null : () => _toggleReminder(task, !value),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 32,
            height: 18,
            child: FittedBox(
              fit: BoxFit.contain,
              child: IgnorePointer(
                child: Switch(
                  value: value,
                  onChanged: completed ? null : (_) {},
                  activeThumbColor: Colors.white,
                  activeTrackColor: AppColors.accent,
                  inactiveThumbColor: AppColors.surface,
                  inactiveTrackColor: AppColors.divider,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          Text(
            value ? 'ALARM_ON' : 'ALARM_OFF',
            style: TextStyle(
              fontSize: 7.5,
              fontFamily: 'monospace',
              letterSpacing: 0.3,
              color: completed ? AppColors.textTertiary : AppColors.techLabel,
            ),
          ),
        ],
      ),
    );
  }

  /// 卡片下方的极简切换箭头与序号。
  Widget _buildTaskNav(List<SystemTask> tasks) {
    if (tasks.isEmpty) return const SizedBox(height: 8);

    final canPrev = _activeTaskIndex > 0;
    final canNext = _activeTaskIndex < tasks.length - 1;
    final position = (_activeTaskIndex + 1).toString().padLeft(2, '0');
    final total = tasks.length.toString().padLeft(2, '0');

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _navArrow(Icons.chevron_left_rounded, canPrev, () => _stepTask(-1)),
        const SizedBox(width: 12),
        Text(
          '$position / $total',
          style: TextStyle(
            fontSize: 8.5,
            fontFamily: 'monospace',
            letterSpacing: 1.2,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(width: 12),
        _navArrow(Icons.chevron_right_rounded, canNext, () => _stepTask(1)),
      ],
    );
  }

  Widget _navArrow(IconData icon, bool enabled, VoidCallback onTap) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: enabled ? onTap : null,
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Icon(
          icon,
          size: 18,
          color: enabled ? AppColors.textSecondary : AppColors.divider,
        ),
      ),
    );
  }
}

/// 展开态的任务详情打字机：逐字显示详情，打完后出现学习资料入口。
class _TaskDetailTypewriter extends StatefulWidget {
  const _TaskDetailTypewriter({
    required this.task,
    required this.description,
    required this.onOpenResource,
  });

  final SystemTask task;
  final String description;
  final Future<void> Function(String url) onOpenResource;

  @override
  State<_TaskDetailTypewriter> createState() => _TaskDetailTypewriterState();
}

class _TaskDetailTypewriterState extends State<_TaskDetailTypewriter>
    with SingleTickerProviderStateMixin {
  final ScrollController _scroll = ScrollController();
  late final AnimationController _controller;
  late final String _text;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _text = '任务详情：${widget.description}';
    final millis = (_text.length * 28).clamp(900, 3200);
    _controller =
        AnimationController(
            vsync: this,
            duration: Duration(milliseconds: millis),
          )
          ..addListener(_followText)
          ..addStatusListener((status) {
            if (status == AnimationStatus.completed && mounted) {
              setState(() => _done = true);
            }
          })
          ..forward();
  }

  void _followText() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasLink = widget.task.resourceUrl.trim().isNotEmpty;
    return SizedBox(
      height: 110,
      child: SingleChildScrollView(
        controller: _scroll,
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final count = (_controller.value * _text.length).round().clamp(
                  0,
                  _text.length,
                );
                return Text(
                  _text.substring(0, count),
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.8,
                    fontWeight: FontWeight.w400,
                    color: AppColors.textPrimary,
                  ),
                );
              },
            ),
            if (hasLink && _done) ...[
              const SizedBox(height: 6),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => widget.onOpenResource(widget.task.resourceUrl),
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 2),
                  child: Text(
                    '>> 查看学习资料',
                    style: TextStyle(fontSize: 12.5, color: AppColors.accent),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 卡片内极淡的 45° 斜向网格底纹。
class _HudTexturePainter extends CustomPainter {
  const _HudTexturePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.02)
      ..strokeWidth = 0.8;
    const step = 16.0;
    final height = size.height;
    for (double x = -height; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x + height, height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _HudTexturePainter oldDelegate) =>
      oldDelegate.color != color;
}

/// HUD 外框：四角 L 型折角 + 四边中央微型刻度。
class _HudFramePainter extends CustomPainter {
  const _HudFramePainter(this.color);

  final Color color;

  static const double _inset = 7;
  static const double _corner = 8;
  static const double _gap = 2.5;

  @override
  void paint(Canvas canvas, Size size) {
    final left = _inset;
    final top = _inset;
    final right = size.width - _inset;
    final bottom = size.height - _inset;

    // 角点处留出 2.5px 缺口，横竖线不再相交成直角。
    final corners = Path()
      // 左上
      ..moveTo(left, top + _gap)
      ..lineTo(left, top + _gap + _corner)
      ..moveTo(left + _gap, top)
      ..lineTo(left + _gap + _corner, top)
      // 右上
      ..moveTo(right - _gap - _corner, top)
      ..lineTo(right - _gap, top)
      ..moveTo(right, top + _gap)
      ..lineTo(right, top + _gap + _corner)
      // 右下
      ..moveTo(right, bottom - _gap - _corner)
      ..lineTo(right, bottom - _gap)
      ..moveTo(right - _gap - _corner, bottom)
      ..lineTo(right - _gap, bottom)
      // 左下
      ..moveTo(left + _gap, bottom)
      ..lineTo(left + _gap + _corner, bottom)
      ..moveTo(left, bottom - _gap - _corner)
      ..lineTo(left, bottom - _gap);

    // 极淡的外发光，模拟全息投影边缘。
    canvas.drawPath(
      corners,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.5)
        ..color = color.withValues(alpha: 0.16),
    );

    // 主色渐变的细折线。
    final shader = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        color.withValues(alpha: 0.55),
        color.withValues(alpha: 0.9),
        color.withValues(alpha: 0.55),
      ],
    ).createShader(Rect.fromLTRB(left, top, right, bottom));
    canvas.drawPath(
      corners,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..strokeCap = StrokeCap.round
        ..shader = shader,
    );

    final tickPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6
      ..color = color.withValues(alpha: 0.28);

    final centerX = size.width / 2;
    final centerY = size.height / 2;
    for (var i = -1; i <= 1; i++) {
      final dx = centerX + i * 6;
      canvas.drawLine(Offset(dx, top), Offset(dx, top + 4), tickPaint);
      canvas.drawLine(Offset(dx, bottom - 4), Offset(dx, bottom), tickPaint);

      final dy = centerY + i * 6;
      canvas.drawLine(Offset(left, dy), Offset(left + 4, dy), tickPaint);
      canvas.drawLine(Offset(right - 4, dy), Offset(right, dy), tickPaint);
    }

    // 极细浅灰实线边框，包裹整张卡片。
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(left, top, right, bottom),
        const Radius.circular(3),
      ),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8
        ..color = AppColors.divider,
    );

    // 四角外侧的微型科技编号。
    final sysLabel = _buildLabel('SYS_01');
    sysLabel.paint(canvas, Offset(left + 1, top - 6));
    final endLabel = _buildLabel('END_');
    endLabel.paint(
      canvas,
      Offset(right - endLabel.width - 1, bottom - endLabel.height + 6),
    );
  }

  TextPainter _buildLabel(String text) {
    return TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: 10,
          fontFamily: 'monospace',
          letterSpacing: 0.4,
          color: color.withValues(alpha: 0.32),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
  }

  @override
  bool shouldRepaint(covariant _HudFramePainter oldDelegate) =>
      oldDelegate.color != color;
}

/// 呼吸指示点（浅色版，无发光）。
class _PulseDot extends StatefulWidget {
  const _PulseDot();

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = Curves.easeInOut.transform(_controller.value);
        return Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.success.withValues(alpha: 0.3 + 0.7 * t),
          ),
        );
      },
    );
  }
}

/// 升级提示：全屏微光 + 中央系统提示卡。
class _LevelUpFlash extends StatelessWidget {
  const _LevelUpFlash({required this.level});

  final int level;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          colors: [
            AppColors.accent.withValues(alpha: 0.10),
            AppColors.accent.withValues(alpha: 0.03),
            Colors.transparent,
          ],
          stops: const [0.0, 0.45, 1.0],
        ),
      ),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 20),
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.94),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.accent.withValues(alpha: 0.15)),
            boxShadow: AppShadows.card,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '【系统提示】',
                style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 1.2,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '宿主等级提升！',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'LEVEL UP · LV.$level',
                style: TextStyle(
                  fontSize: 10,
                  fontFamily: 'monospace',
                  letterSpacing: 1,
                  color: AppColors.accent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
