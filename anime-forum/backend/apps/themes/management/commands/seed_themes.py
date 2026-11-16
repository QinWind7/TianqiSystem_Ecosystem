"""写入内置皮肤种子数据。可重复执行（按 code upsert）。"""
from django.core.management.base import BaseCommand

from apps.themes.models import Theme

THEMES = [
    {
        "code": "sakura",
        "name": "极简白",
        "description": "浅色极简 HUD，默认皮肤",
        "is_dark": False,
        "sort_order": 10,
        "config": {
            "--color-primary": "#4F46E5",
            "--color-primary-soft": "#EEF2FF",
            "--color-secondary": "#E5E7EB",
            "--color-accent": "#E0E7FF",
            "--color-bg": "#F7F8FA",
            "--color-surface": "#FFFFFF",
            "--color-surface-2": "#F3F4F6",
            "--color-text": "#1F2937",
            "--color-text-muted": "#6B7280",
            "--color-border": "#E5E7EB",
            "--shadow-card": "0 1px 2px rgba(16, 24, 40, 0.04), 0 1px 3px rgba(16, 24, 40, 0.06)",
            "--radius-card": "16px",
            "--gradient-hero": "linear-gradient(135deg, #EEF2FF 0%, #F7F8FA 100%)",
        },
    },
    {
        "code": "alert",
        "name": "黑红警报 (Dark Alert)",
        "description": "纯黑底 + 血红警报，暗黑 HUD 皮肤",
        "is_dark": True,
        "sort_order": 15,
        "config": {
            "--color-primary": "#E53935",
            "--color-primary-soft": "#2A1415",
            "--color-secondary": "#242427",
            "--color-accent": "#3A1518",
            "--color-bg": "#0E0E10",
            "--color-surface": "#1A1A1D",
            "--color-surface-2": "#232326",
            "--color-text": "#E2E2E2",
            "--color-text-muted": "#888888",
            "--color-border": "#331111",
            "--shadow-card": "0 0 0 1px rgba(211,47,47,.06), 0 0 16px rgba(211,47,47,.16), 0 2px 10px rgba(0,0,0,.55)",
            "--radius-card": "16px",
            "--gradient-hero": "linear-gradient(135deg, #1E1012 0%, #0E0E10 100%)",
        },
    },
]


class Command(BaseCommand):
    help = "初始化/更新内置主题皮肤（幂等，可重复执行）"

    def handle(self, *args, **options):
        for item in THEMES:
            code = item["code"]
            defaults = {k: v for k, v in item.items() if k != "code"}
            _, created = Theme.objects.update_or_create(code=code, defaults=defaults)
            self.stdout.write(
                f"{'创建' if created else '更新'}皮肤：{item['name']}（{code}）"
            )

        # 旧版本的三套皮肤已从产品中移除，同时清理数据库记录（用户偏好 FK 为 SET_NULL）。
        obsolete = ("ocean", "midnight", "matcha")
        deleted, _ = Theme.objects.filter(code__in=obsolete).delete()
        if deleted:
            self.stdout.write(f"已移除旧皮肤：{', '.join(obsolete)}")

        self.stdout.write(self.style.SUCCESS(f"内置皮肤就绪，共 {len(THEMES)} 套"))
