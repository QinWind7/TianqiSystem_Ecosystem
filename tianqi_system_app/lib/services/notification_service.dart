import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../models/system_task.dart';

/// 每日唤醒与单任务定时提醒。
class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  static const int _dailyReminderId = 1001;
  static const String _wakeTimeKey = 'wake_time_minutes';
  static const String _channelId = 'system_daily_wake';
  static const String _channelName = '每日唤醒';
  static const String _taskChannelId = 'system_task_reminder';
  static const String _taskChannelName = '任务提醒';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> _ensureInitialized() async {
    if (_initialized) return;

    tzdata.initializeTimeZones();
    try {
      final timezone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timezone.identifier));
    } catch (_) {
      // 获取系统时区失败时保持默认时区。
    }

    const settings = InitializationSettings(
      android: AndroidInitializationSettings('ic_stat_system'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );
    await _plugin.initialize(settings: settings);
    _initialized = true;
  }

  /// 初始化通知插件（App 启动时调用）。
  Future<void> initialize() => _ensureInitialized();

  /// App 启动时恢复已保存的每日提醒。
  ///
  /// 先取消旧 ID 再重新调度，防止系统清理或强制停止后提醒丢失/重复。
  Future<void> rescheduleSaved() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final minutes = prefs.getInt(_wakeTimeKey);
      if (minutes == null) return;

      await _ensureInitialized();
      await _scheduleDaily(
        TimeOfDay(hour: (minutes ~/ 60) % 24, minute: minutes % 60),
      );
    } catch (_) {
      // 恢复提醒失败不影响 App 启动。
    }
  }

  /// Android 13+ 的 POST_NOTIFICATIONS 与 iOS 通知权限。
  Future<bool> _requestPermission() async {
    if (kIsWeb) return false;

    if (defaultTargetPlatform == TargetPlatform.android) {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      final granted = await android?.requestNotificationsPermission();
      return granted ?? false;
    }

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final ios = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      final granted = await ios?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return granted ?? false;
    }

    return false;
  }

  /// 读取已保存的唤醒时间，默认 08:00。
  Future<TimeOfDay> loadWakeTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final minutes = prefs.getInt(_wakeTimeKey) ?? 8 * 60;
      return TimeOfDay(hour: (minutes ~/ 60) % 24, minute: minutes % 60);
    } catch (_) {
      return const TimeOfDay(hour: 8, minute: 0);
    }
  }

  /// 保存唤醒时间并重新调度每日提醒，返回通知权限是否已授予。
  ///
  /// 每次修改都会先取消旧通知，再重新 [zonedSchedule]，避免重复堆叠。
  Future<bool> setWakeTime(TimeOfDay time) async {
    await _ensureInitialized();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_wakeTimeKey, time.hour * 60 + time.minute);

    final granted = await _requestPermission();
    await _scheduleDaily(time);

    return granted;
  }

  /// 为任务生成稳定的唯一通知 ID，避免不同任务互相覆盖。
  ///
  /// 任务编号按 `(day - 1) * 10 + index` 生成，因此 `day * 100 + code`
  /// 在 7 天范围内不会重复，也不会与每日唤醒的 ID 冲突。
  static int notificationIdForTask(SystemTask task) {
    final numeric = int.tryParse(task.code);
    if (numeric != null) return task.day * 100 + numeric;
    return 100000 + (task.title.hashCode & 0x7fffffff) % 800000;
  }

  /// 从推荐时间中解析开始时间，如 "12:00 - 13:00" → 12:00。
  TimeOfDay? _parseStartTime(String recommendedTime) {
    final match = RegExp(r'(\d{1,2}):(\d{2})').firstMatch(recommendedTime);
    if (match == null) return null;

    final hour = int.tryParse(match.group(1)!);
    final minute = int.tryParse(match.group(2)!);
    if (hour == null || minute == null) return null;
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;

    return TimeOfDay(hour: hour, minute: minute);
  }

  /// 为单个任务设置定时提醒，返回是否成功。
  ///
  /// 推荐时间无效或通知权限未授予时返回 false。
  Future<bool> scheduleTaskReminder(SystemTask task) async {
    final time = _parseStartTime(task.recommendedTime);
    if (time == null) return false;

    try {
      await _ensureInitialized();
      final granted = await _requestPermission();
      if (!granted) return false;

      final now = tz.TZDateTime.now(tz.local);
      var next = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        time.hour,
        time.minute,
      );
      if (!next.isAfter(now)) {
        next = next.add(const Duration(days: 1));
      }

      await _plugin.zonedSchedule(
        id: notificationIdForTask(task),
        title: '【天命系统】任务发布',
        body: '宿主，请立即执行：${task.title}。',
        scheduledDate: next,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            _taskChannelId,
            _taskChannelName,
            channelDescription: '在任务推荐时间提醒宿主执行任务',
            importance: Importance.max,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: 'task_${task.day}_${task.code}',
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  /// 取消单任务的定时提醒。
  Future<void> cancelTaskReminder(SystemTask task) async {
    try {
      await _ensureInitialized();
      await _plugin.cancel(id: notificationIdForTask(task));
    } catch (_) {
      // 取消失败不阻塞主流程。
    }
  }

  /// 取消旧通知后重新调度，确保只有一个每日提醒。
  Future<void> _scheduleDaily(TimeOfDay time) async {
    await _plugin.cancel(id: _dailyReminderId);

    final now = tz.TZDateTime.now(tz.local);
    var next = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );
    if (!next.isAfter(now)) {
      next = next.add(const Duration(days: 1));
    }

    await _plugin.zonedSchedule(
      id: _dailyReminderId,
      title: '【叮！】',
      body: '宿主，新的一天开始了，任务已发布，请速速前往面板查看！',
      scheduledDate: next,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: '每天定时提醒宿主查看今日任务',
          importance: Importance.max,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: 'daily_wake',
    );
  }
}
