# 技能类型系统统一设计

## 概述

将 `skill_categories` 表确立为技能类型的唯一权威数据源，通过新增 `task_type` 字段桥接现有的三套系统（任务类型、论坛技能板块、技能排行榜），消除隐式字符串约定。

## 现状问题

三套系统各自独立，靠隐式字符串匹配关联：
- `skill_categories` 表存在但为空，排行榜和用户能力系统无法工作
- `recalculate_leaderboard()` 用 `SkillCategory.name_en` 匹配 `Task.task_type`，脆弱且不可靠
- `forum_categories.skill_type` 和 `skill_categories` 之间无任何关联

## 数据模型变更

### skill_categories 表扩展

新增 `task_type` 字段（VARCHAR(50), UNIQUE, NOT NULL），存储对应的任务类型标识。

### 统一后的关联关系

```
skill_categories.task_type (权威来源, UNIQUE)
    ├── Task.task_type — 字符串匹配
    ├── forum_categories.skill_type — 字符串匹配
    ├── SkillLeaderboard.skill_category — 字符串匹配
    └── UserSkill.skill_category — 字符串匹配

skill_categories.id (主键)
    └── UserCapability.category_id — FK（已有）
```

### 不改动的部分

- `forum_categories.skill_type` — 保持字符串，不加 FK
- `SkillLeaderboard.skill_category` — 保持字符串
- `Task.task_type` — 保持字符串
- `UserCapability.category_id` — 已经是 FK，不动

## 后端改动

### recalculate_leaderboard()

将 `db.query(models.SkillCategory.name_en)` 改为 `db.query(models.SkillCategory.task_type)`，用 `task_type` 匹配 `Task.task_type`。

### SkillCategory Model

添加 `task_type = Column(String(50), unique=True, nullable=False)`。

### SkillCategoryOut Schema

添加 `task_type: str` 字段，确保 API 响应包含此字段。

## Migration

一个 migration（148）完成所有变更：

1. 添加 `task_type` 列到 `skill_categories`（带临时 DEFAULT ''）
2. 插入 22 条种子数据，`task_type` 对应现有 TASK_TYPES
3. 移除 DEFAULT 约束

种子数据的 `name_zh`/`name_en`/`icon` 复用论坛板块命名和 emoji。

## 不需要前端改动

前端排行榜页面已经能正确展示 `skill_categories` 数据，之前表为空导致无数据。填入种子数据后即可工作。
