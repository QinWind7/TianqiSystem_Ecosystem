"""云端数据重建：清空旧二次元分区/帖子，写入「天启系统」初始数据。

放置位置：
    anime-forum/backend/seed_cloud.py   （与 manage.py 同级）

运行方式（二选一）：
    # 方式 A：通过 manage.py shell 读取（推荐）
    cd /path/to/anime-forum/backend
    source .venv/bin/activate
    export DJANGO_SETTINGS_MODULE=config.settings.prod
    export SEED_CLOUD_CONFIRM=yes
    python manage.py shell < seed_cloud.py

    # 方式 B：直接执行
    export DJANGO_SETTINGS_MODULE=config.settings.prod
    export SEED_CLOUD_CONFIRM=yes
    python seed_cloud.py

注意：
    1. 必须显式设置 DJANGO_SETTINGS_MODULE，否则 manage.py 会默认使用
       config.settings.dev，可能连到本地 SQLite 而不是线上 MySQL。
    2. 脚本会删除全部分区、帖子、评论与点赞记录，不可恢复，请先备份数据库。
    3. 不会删除用户账号，只修正「站长喵」这类旧昵称。
"""
import os
import sys
from datetime import timedelta

# 允许 `python seed_cloud.py` 直接运行；通过 manage.py shell 运行时该变量已存在。
if not os.environ.get("DJANGO_SETTINGS_MODULE"):
    os.environ["DJANGO_SETTINGS_MODULE"] = "config.settings.prod"

import django  # noqa: E402
from django.apps import apps as django_apps  # noqa: E402

if not django_apps.ready:
    django.setup()

from django.conf import settings  # noqa: E402
from django.contrib.auth import get_user_model  # noqa: E402
from django.db import transaction  # noqa: E402
from django.utils import timezone  # noqa: E402

from apps.forum.models import Board, LikeRecord, Post  # noqa: E402

User = get_user_model()


BOARDS = [
    {
        "slug": "task",
        "name": "任务大厅",
        "icon": "01",
        "color": "#4F46E5",
        "description": "系统广播、主线任务与日常任务发布",
        "sort_order": 10,
    },
    {
        "slug": "mainline",
        "name": "主线推演",
        "icon": "02",
        "color": "#4338CA",
        "description": "剧情推演、任务复盘与因果线记录",
        "sort_order": 20,
    },
    {
        "slug": "resource",
        "name": "资源置换",
        "icon": "05",
        "color": "#475569",
        "description": "情报、工具与物资互助置换",
        "sort_order": 30,
    },
    {
        "slug": "feedback",
        "name": "异常反馈",
        "icon": "06",
        "color": "#64748B",
        "description": "系统 Bug、任务冲突与规则申诉",
        "sort_order": 40,
    },
]


BROADCAST_POST = {
    "board": "task",
    "author": "system",
    "title": "【SYSTEM BROADCAST】因果律执行条例（第 7 版）",
    "summary": "系统广播：严禁篡改主线任务，异常请提交至异常反馈区。",
    "is_pinned": True,
    "is_essence": True,
    "view_count": 512,
    "like_count": 66,
    "content": """> 本广播由主神空间自动下发，优先级高于一切分区规则。

## 【警告】

请各位宿主遵守因果律法则。

- **严禁私自篡改主线任务**：修改目标、结算条件或时间窗口，均视为主线污染。
- **违者将被抹杀**：账号、因果线与全部进度将被系统回收，不做申诉处理。
- **异常请走正规信道**：可在【异常反馈】区提交系统 Bug，附时间戳与复现步骤。

## 当前系统状态

- 宿主属性同步：正常
- 任务推荐引擎：正常
- 异常反馈队列：处理中

> 系统不做无效解释。请各位宿主珍惜自己的因果线。
""",
}


POSTS = [
    {
        "board": "task",
        "author": "system",
        "title": "【新人必读】新手宿主生存指南与系统绑定须知",
        "summary": "绑定流程、因果律红线与日常任务机制，新宿主请完整阅读后再接取任务。",
        "is_pinned": False,
        "is_essence": True,
        "view_count": 328,
        "like_count": 26,
        "content": """> 系统提示：新绑定宿主请完整阅读后再接取任务。

## 一、绑定流程

1. 在移动端打开「天启系统」App，使用与论坛相同的账号登录。
2. 首次登录后，系统会自动下发一条 [新手引导] 任务，请不要跳过。
3. 完成任意一次日常任务后，等级、经验与当日连击会同步到论坛的宿主档案。
4. 若同步失败，本地进度不会丢失，可在网络恢复后重新完成一次任务触发同步。

## 二、因果律三条红线

- **禁止篡改主线任务**：任何修改任务目标、结算条件的行为，都会被判定为主线污染。
- **禁止向未绑定宿主泄露任务内容**：包括但不限于截图、转述与二次传播。
- **禁止利用系统漏洞刷取经验**：发现漏洞请在「异常反馈」区提交。

## 三、日常任务机制

- 每完成一个任务获得 10 点经验，经验满 100 自动升级并清零。
- 同一天内连续完成任务会累计「当日连击」，跨天自动重置。
- 连击只影响展示与结算加成，不突破每日任务上限。

## 四、常见问题

**Q：为什么我的等级和网页显示不一致？**
A：网页读取的是最后一次同步结果，回到 App 完成一次任务即可刷新。

**Q：任务失败会扣经验吗？**
A：不会。失败只影响当次结算奖励。

## 五、违规处理

- 轻度：系统警告 + 任务冻结 24 小时
- 中度：清空当日连击与经验收益
- 重度：账号抹杀，因果线回收
""",
    },
    {
        "board": "task",
        "author": "system",
        "title": "如何在 3 天内完成「百米冲刺」日常任务（附实战演示）",
        "summary": "把 6 次专注块拆进 3 天，附时间轴、失败点与结算演示。",
        "is_pinned": False,
        "is_essence": True,
        "view_count": 216,
        "like_count": 18,
        "content": """## 任务档案

- 任务名：百米冲刺
- 类型：日常 / 限时
- 目标：3 天内累计完成 6 次 30 分钟专注块
- 允许中断：单次中断不超过 5 分钟，超过则本次作废
- 结算奖励：经验 +60，积分 +30，连击 +1

## 为什么大多数人第二天就失败

1. 第一天一次性做完 4 次，第二天进入疲劳期直接放弃。
2. 把专注块安排在通勤、午休等碎片时段，天然容易被中断。
3. 忽略「当日连击」的跨天重置，误以为可以攒到第三天一起做。

## 三日实战排期

### Day 1：建立节奏

- 09:00 - 09:30　专注块 1（难度最低的整理类任务）
- 15:00 - 15:30　专注块 2（需要输入的任务）
- 晚上只做复盘，不再追加强度

### Day 2：稳定输出

- 10:00 - 10:30　专注块 3
- 20:00 - 20:30　专注块 4
- 若中途被打断，当场补一次 10 分钟微任务，保持连击不断

### Day 3：收尾结算

- 09:30 - 10:00　专注块 5
- 16:00 - 16:30　专注块 6，完成后立刻查看结算面板

## 实战演示（时间轴）

- 00:00　点击「开始专注」，系统进入静默模式
- 12:40　第一次分心，记录但不中断
- 29:50　提交任务，经验 +10，连击 +1
- 30:00　自动回到任务列表，等待下一次接取

## 三个提高通过率的细节

- **把手机放在视线之外**：切屏会直接作废。
- **每次只接一个任务**：并行接取会让推荐时间重叠。
- **失败后立刻补位**：当天补一次短任务，连击就不会断。

> 若在第三天发现推荐时间段重叠，请先到「异常反馈」区提交时间戳，不要强行开始任务。
""",
    },
    {
        "board": "task",
        "author": "system",
        "title": "S 级地狱难度任务：考研深渊 通关记录分享",
        "summary": "298 天、4 个阶段、2 次重开，一份不美化数据的通关记录。",
        "is_pinned": False,
        "is_essence": True,
        "view_count": 154,
        "like_count": 12,
        "content": """## 通关档案

- 任务难度：S（地狱）
- 任务周期：298 天
- 重开次数：2 次
- 最终评分：A-

## 阶段复盘

### 第一阶段：情报收集（第 1 - 30 天）

- 确定目标院校与专业课范围，避免中途改线。
- 建立每日任务模板：英语 1 小时、专业课 2 小时、政治 40 分钟。
- 把每日任务量打到实际能力的 70%，不要高估自己。

### 第二阶段：主线推进（第 31 - 180 天）

- 专业课完成两轮精读，错题单独建库。
- 英语真题按年份推进，阅读错误率从 8 个降到 3 个。
- 每周固定一次复盘：记录失效的学习方法并删除。

### 第三阶段：压力测试（第 181 - 270 天）

- 全真模拟 6 次，严格按考试时间执行。
- 第二次重开就在这一阶段：模拟分数连续下滑，及时砍掉低收益资料。
- 把睡眠写进任务列表，缺觉会直接提高后续任务失败率。

### 第四阶段：最终结算（第 271 - 298 天）

- 停止新增资料，只做错题与背诵。
- 考前一周降低任务强度，避免触发疲劳惩罚。

## 两次失败重开的教训

1. 第一次重开：同时推进三门课，导致每天都完不成任务，连击长期为 0。
2. 第二次重开：迷信新资料，真题只刷了一遍，模拟时暴露严重问题。

## 给后来者的三条警告

- **不要用时长自我感动**：系统只结算有效专注块。
- **不要在第 200 天后更换主线**：沉没成本会直接击穿心态。
- **失败不是抹杀**：任务失败只清零当次收益，你仍然可以重新接取。
""",
    },
    {
        "board": "feedback",
        "author": "host_0713",
        "title": "求助：AI 生成的任务推荐时间段重叠了，是系统出 Bug 了吗？",
        "summary": "同一天推荐了两个完全重叠的专注块，提交时间戳求复核。",
        "is_pinned": False,
        "is_essence": False,
        "view_count": 23,
        "like_count": 2,
        "content": """## 问题描述

今天早上打开 App，AI 生成的两条日常任务推荐时间段完全重叠：

- 任务 A：09:00 - 10:00　主线推演 · 文献精读
- 任务 B：09:00 - 10:00　百米冲刺 · 专注块 1

两条任务都要求「前台静默」，同时接取后无法正常结算。

## 复现步骤

1. 前一天晚上完成一次任务，连击为 3。
2. 次日 08:50 打开 App，进入任务推荐页。
3. 点击「刷新推荐」，等待 AI 生成。
4. 两条任务返回相同的时间窗口，且都被标记为「推荐」。

## 实际表现

- 接取任务 A 后，任务 B 仍然可以被接取。
- 完成 A 后，B 的进度停留在 0，但倒计时仍按 09:00 开始计算。
- 提交时提示「任务时间冲突，结算失败」。

## 期望表现

- 推荐阶段就应互斥，或明确提示时间段冲突。
- 冲突任务不应允许同时接取。
- 结算失败时应给出可恢复的补偿方案。

## 环境信息

- 客户端：Android 模拟器，天启系统 App
- 账号：host_0713
- 同步接口：POST /api/v1/sync_status/ 返回 200，排除网络问题
""",
    },
]


def _ensure_author(username: str, nickname: str, bio: str) -> User:
    """创建不可登录的系统账号；已存在则直接复用，不改密码。"""
    user, created = User.objects.get_or_create(
        username=username,
        defaults={"nickname": nickname, "bio": bio},
    )
    if created:
        user.set_unusable_password()
        user.save(update_fields=["password"])
    return user


def main() -> None:
    if os.environ.get("SEED_CLOUD_CONFIRM") != "yes":
        db = settings.DATABASES.get("default", {})
        print("安全锁未开启，已中止，未修改任何数据。")
        print(f"目标数据库：{db.get('NAME')} @ {db.get('HOST') or 'local'}")
        print(f"settings：{os.environ.get('DJANGO_SETTINGS_MODULE')}")
        print("确认无误后执行：export SEED_CLOUD_CONFIRM=yes")
        raise SystemExit(1)

    db = settings.DATABASES.get("default", {})
    print(f"目标数据库：{db.get('NAME')} @ {db.get('HOST') or 'local'}")
    print(f"settings：{os.environ.get('DJANGO_SETTINGS_MODULE')}")

    with transaction.atomic():
        # 1. 清空旧二次元数据（评论、通知由外键级联删除）
        like_deleted, _ = LikeRecord.objects.all().delete()
        post_deleted, _ = Post.objects.all().delete()
        board_deleted, _ = Board.objects.all().delete()
        print(f"已清空：分区 {board_deleted}、帖子 {post_deleted}、点赞 {like_deleted}")

        # 2. 修正旧昵称，保留账号与等级数据
        renamed = 0
        for user in User.objects.filter(nickname__contains="站长"):
            user.nickname = "主神"
            user.bio = "系统核心 AI，负责维护因果律运转。"
            user.save(update_fields=["nickname", "bio", "updated_at"])
            renamed += 1
        if renamed:
            print(f"已修正 {renamed} 个旧昵称（站长喵 → 主神）")

        # 3. 重建分区
        board_map = {}
        for item in BOARDS:
            board_map[item["slug"]] = Board.objects.create(**item, post_count=0)
            print(f"创建分区：{item['name']}（{item['slug']}）")

        # 4. 重建系统账号与帖子
        system_user = _ensure_author("system", "天启系统", "系统广播与主线任务发布终端")
        host_user = _ensure_author("host_0713", "宿主0713", "编号 0713，正在申请异常复核")
        authors = {"system": system_user, "host_0713": host_user}

        now = timezone.now()
        all_posts = [BROADCAST_POST, *POSTS]
        offsets = [
            timedelta(days=5),  # 系统广播
            timedelta(days=3),  # 新人必读
            timedelta(days=2),  # 百米冲刺
            timedelta(days=1),  # 考研深渊
            timedelta(hours=6),  # 异常反馈
        ]

        for item, offset in zip(all_posts, offsets):
            post = Post.objects.create(
                board=board_map[item["board"]],
                author=authors[item["author"]],
                title=item["title"],
                summary=item["summary"],
                content=item["content"],
                status=Post.Status.PUBLISHED,
                is_pinned=item["is_pinned"],
                is_essence=item["is_essence"],
                view_count=item["view_count"],
                like_count=item["like_count"],
            )
            # created_at 是 auto_now_add，创建后回写以拉开时间线
            Post.objects.filter(pk=post.pk).update(
                created_at=now - offset,
                updated_at=now - offset,
            )
            print(f"创建帖子：{post.title}")

        # 5. 回填分区帖子数
        for board in board_map.values():
            count = Post.objects.filter(
                board=board,
                status=Post.Status.PUBLISHED,
            ).count()
            Board.objects.filter(pk=board.pk).update(post_count=count)

    print(
        f"完成：{len(BOARDS)} 个分区、{len(all_posts)} 个帖子；"
        "系统账号 system / host_0713 不可登录"
    )


main()
