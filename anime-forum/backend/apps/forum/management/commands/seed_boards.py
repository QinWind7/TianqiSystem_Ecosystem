"""写入分区种子数据（幂等）。分区是论坛的骨架，共 4 个（天启系统分类）。"""
from django.core.management.base import BaseCommand

from apps.forum.models import Board

BOARDS = [
    {
        "slug": "task",
        "name": "任务大厅",
        "icon": "01",
        "color": "#4F46E5",
        "description": "系统公告、主线任务与日常任务发布",
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


class Command(BaseCommand):
    help = "初始化/更新论坛分区（幂等，可重复执行）"

    def handle(self, *args, **options):
        for item in BOARDS:
            slug = item["slug"]
            defaults = {k: v for k, v in item.items() if k != "slug"}
            _, created = Board.objects.update_or_create(slug=slug, defaults=defaults)
            self.stdout.write(f"{'创建' if created else '更新'}分区：{item['name']}（{slug}）")
        self.stdout.write(self.style.SUCCESS(f"分区就绪，共 {len(BOARDS)} 个"))
