/// 一条系统任务的数据结构。
class SystemTask {
  const SystemTask({
    required this.code,
    required this.category,
    required this.title,
    required this.detail,
    required this.reward,
    this.detailDescription = '',
    this.recommendedTime = '',
    this.resourceUrl = '',
    this.isReminderOn = true,
    this.day = 1,
  });

  /// 任务编号，如 01。
  final String code;

  /// 任务分类，如“淬体”。
  final String category;

  /// 任务标题。
  final String title;

  /// 任务描述（一句话简述）。
  final String detail;

  /// 完成奖励。
  final String reward;

  /// 具体执行建议：分步骤说明该怎么做。
  final String detailDescription;

  /// 推荐完成时间段，格式如 “08:00 - 09:00”；未知时为空字符串。
  final String recommendedTime;

  /// 学习资料链接；没有合适资源时为空字符串。
  final String resourceUrl;

  /// 是否开启该任务的提醒，默认开启。
  final bool isReminderOn;

  /// 所属计划天数，从 1 开始。
  final int day;

  Map<String, dynamic> toJson() {
    return {
      'code': code,
      'category': category,
      'title': title,
      'detail': detail,
      'reward': reward,
      'detailDescription': detailDescription,
      'recommendedTime': recommendedTime,
      'resourceUrl': resourceUrl,
      'isReminderOn': isReminderOn,
      'day': day,
    };
  }

  factory SystemTask.fromJson(Map<String, dynamic> json) {
    final rawDay = json['day'] is num ? (json['day'] as num).toInt() : 1;
    return SystemTask(
      code: (json['code'] ?? '').toString(),
      category: (json['category'] ?? '研习').toString(),
      title: (json['title'] ?? '').toString(),
      detail: (json['detail'] ?? '').toString(),
      reward: (json['reward'] ?? '经验 +1').toString(),
      detailDescription: (json['detailDescription'] ?? '').toString(),
      recommendedTime: (json['recommendedTime'] ?? '').toString(),
      resourceUrl: (json['resourceUrl'] ?? '').toString(),
      isReminderOn: json['isReminderOn'] is bool
          ? json['isReminderOn'] as bool
          : true,
      day: rawDay.clamp(1, 7).toInt(),
    );
  }

  SystemTask copyWith({
    String? code,
    String? title,
    String? detail,
    String? detailDescription,
    String? recommendedTime,
    bool? isReminderOn,
    int? day,
  }) {
    return SystemTask(
      code: code ?? this.code,
      category: category,
      title: title ?? this.title,
      detail: detail ?? this.detail,
      reward: reward,
      detailDescription: detailDescription ?? this.detailDescription,
      recommendedTime: recommendedTime ?? this.recommendedTime,
      resourceUrl: resourceUrl,
      isReminderOn: isReminderOn ?? this.isReminderOn,
      day: day ?? this.day,
    );
  }
}
