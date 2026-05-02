"""达人/达人服务/个人服务的 category 字典 — 唯一来源.

历史 13 keys 是早期版本，2026-05-01 扩到 30 keys 与
`skill_categories.task_type` 对齐（见 migration 148）。

注意:
- `Expert.category` / `TaskExpertService.category` 在 DB 层是自由 String(50)
  以保留现有数据兼容性（包含可能存在的历史野值）。
- 写入路径（Pydantic 创建/更新 schema）通过此常量做 enum 校验，防止新写入
  野值。读取路径不校验，让历史值原样透出.
- AI 工具 (`services/ai_tools.py`) 的 `_VALID_SERVICE_CATEGORIES` 也应该
  和此清单保持同步.
"""

# 30 个 keys：13 老 + 17 新
EXPERT_CATEGORIES: list[str] = [
    # 老 13 个（保留兼容历史数据）
    "programming",
    "translation",
    "tutoring",
    "food",
    "beverage",
    "cake",
    "errand_transport",
    "social_entertainment",
    "beauty_skincare",
    "handicraft",
    "gaming",
    "photography",
    "housekeeping",
    # 新 17 个（与 skill_categories.task_type 同名）
    "shopping",
    "design",
    "writing",
    "moving",
    "cleaning",
    "repair",
    "pickup_dropoff",
    "cooking",
    "language_help",
    "government",
    "pet_care",
    "errand",
    "accompany",
    "digital",
    "rental_housing",
    "campus_life",
    "second_hand",
]

EXPERT_CATEGORIES_SET: frozenset[str] = frozenset(EXPERT_CATEGORIES)
