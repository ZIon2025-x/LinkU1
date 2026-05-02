# Expert Categories Expansion & Skill Board Wiring — Design

**Date**: 2026-05-01
**Owner**: Ryan
**Status**: Draft, awaiting review

## Goal

两件事，互相独立但同一批改：

1. **达人/达人服务的可选类别从 13 个扩到 30 个** — 在原有 13 个基础上**直接追加** 17 个与 `Task.task_type` / `skill_categories.task_type` 同名的新 key（即任务 22 个中除老 4 个共有和 `other` 外的全部）。
2. **技能板块（Skill Leaderboard 页）展示对应达人和服务** — 每个 category tab 选中时，除排行榜外，显示该 category 下的达人团队和达人服务列表。

## Non-Goals（明确不做）

- ❌ 不删除老 13 个独有 key（`food` / `beverage` / `cake` / `errand_transport` / `social_entertainment` / `beauty_skincare` / `handicraft` / `gaming` / `housekeeping`）— 老美容、游戏、烘焙、社交娱乐达人**原地不动**。
- ❌ 不写数据迁移 — 现有 `Expert.category` / `TaskExpertService.category` 的值不变。
- ❌ 不动 `skill_categories` 表的 22 个 seed — 技能板块字典不变。
- ❌ 不动 `Task.task_type` 的 22 个 keys。
- ❌ 老 13 个独有 key 在技能板块**不会**有展示入口（因为 `skill_categories` 表里没有这些 key），相应达人/服务只能在达人板块自己的 list 里被找到。这是接受的代价。
- ❌ **不改达人申请流程** — `ExpertApplication` 表保持现状（无 `category` 字段），用户申请时不选 category。`Expert.category` 只能由**管理员在 admin 后台审核通过后手动打标**。本次只扩充管理员可选的 category 字典，不改申请表结构、不加用户自选。

## 申请 / 打标 / 服务发布的责任分工（澄清）

| 对象 | 字段 | 谁能写入 | 在哪写入 |
|---|---|---|---|
| `ExpertApplication`（申请记录） | — | 用户 | 达人申请表单（**不含 category**） |
| `Expert.category`（团队主营方向） | category | **仅管理员** | admin 后台 `admin_expert_routes.py` 编辑端点 |
| `TaskExpertService.category`（具体服务分类） | category | 达人本人 | 达人 dashboard 服务发布表单 (`services_tab.dart`) |

**结论**：本次扩充 30 个 keys 的影响面只在 (a) admin 后台 `Expert.category` 下拉、(b) 达人 dashboard `TaskExpertService.category` 下拉、(c) 各类筛选/列表/技能板块的 label 渲染。申请表单**不改**。

## 终态字典

### 达人侧（`expert_constants.dart`）：13 → 30

老 13 个完全保留：
```
programming, translation, tutoring, food, beverage, cake,
errand_transport, social_entertainment, beauty_skincare,
handicraft, gaming, photography, housekeeping
```

新增 17 个（与 `skill_categories.task_type` 同名，因此天然能在技能板块出现）：

| # | key | zh | zh_Hant | en |
|---|---|---|---|---|
| 1 | `shopping` | 代购 | 代購 | Shopping |
| 2 | `design` | 设计 | 設計 | Design |
| 3 | `writing` | 写作 | 寫作 | Writing |
| 4 | `moving` | 搬家 | 搬家 | Moving |
| 5 | `cleaning` | 清洁 | 清潔 | Cleaning |
| 6 | `repair` | 维修 | 維修 | Repair |
| 7 | `pickup_dropoff` | 接送 | 接送 | Pickup & Dropoff |
| 8 | `cooking` | 烹饪 | 烹飪 | Cooking |
| 9 | `language_help` | 语言陪同 | 語言陪同 | Language Help |
| 10 | `government` | 政务办理 | 政務辦理 | Government |
| 11 | `pet_care` | 宠物照顾 | 寵物照顧 | Pet Care |
| 12 | `errand` | 跑腿 | 跑腿 | Errand |
| 13 | `accompany` | 陪伴 | 陪伴 | Accompany |
| 14 | `digital` | 数码/IT | 數碼/IT | Digital / IT |
| 15 | `rental_housing` | 租房协助 | 租房協助 | Rental Housing |
| 16 | `campus_life` | 校园生活 | 校園生活 | Campus Life |
| 17 | `second_hand` | 二手交易 | 二手交易 | Second-hand |

**仅 `other` 不加** — 达人需要明确专业方向，"其他"留兜底会乱选。

### 技能板块字典（`skill_categories` 表）：22，不变

22 个 task_type 一行不动。新增的 17 个达人 key 全部**已存在**于这张表，因此天然能在技能板块里被发现。

### 三方关系（最终）

```
达人侧 30 keys = 老 13 + 新 17
技能板块 22 keys
任务类型 22 keys

达人 ∩ 技能板块 = 4 个老共有（programming, translation, tutoring, photography）
                  + 17 个新增（见上表）
                  = 21 keys
  → 这 21 个 tab 在技能板块下会显示达人/服务

达人独有 = 9 个老 key（food, beverage, cake, errand_transport, social_entertainment,
                     beauty_skincare, handicraft, gaming, housekeeping）
  → 这些 category 的达人/服务不在技能板块出现，只在达人板块的 list/筛选里出现

技能板块独有 = 1 个（other）
  → 该 tab 在技能板块下"达人区"为空（other 不给达人挂）
```

## 改动清单

### 前端（Flutter）

#### 1. `link2ur/lib/core/constants/expert_constants.dart`

`categoryKeys` 和 `serviceCategoryKeys` 末尾各追加 17 个 key（保持 17 个的相对顺序与上表一致）。

```dart
// categoryKeys: 'all' + 13 老 + 17 新 = 31 项
static const List<String> categoryKeys = [
  'all',
  // 老 13 个
  'programming', 'translation', 'tutoring',
  'food', 'beverage', 'cake',
  'errand_transport', 'social_entertainment', 'beauty_skincare',
  'handicraft', 'gaming', 'photography', 'housekeeping',
  // 新 17 个（与 skill_categories.task_type 同名）
  'shopping', 'design', 'writing', 'moving', 'cleaning',
  'repair', 'pickup_dropoff', 'cooking', 'language_help',
  'government', 'pet_care', 'errand', 'accompany',
  'digital', 'rental_housing', 'campus_life', 'second_hand',
];

// serviceCategoryKeys: 同上去掉 'all'，30 项
```

#### 2. i18n ARB 文件

为新 17 个 key 添加 `expertCategory*` 翻译（命名沿用现有 PascalCase 习惯）：

`app_en.arb` / `app_zh.arb` / `app_zh_Hant.arb` 各加 17 条：

```
expertCategoryShopping, expertCategoryDesign, expertCategoryWriting,
expertCategoryMoving, expertCategoryCleaning, expertCategoryRepair,
expertCategoryPickupDropoff, expertCategoryCooking, expertCategoryLanguageHelp,
expertCategoryGovernment, expertCategoryPetCare, expertCategoryErrand,
expertCategoryAccompany, expertCategoryDigital, expertCategoryRentalHousing,
expertCategoryCampusLife, expertCategorySecondHand
```

每个 key 加 `@expertCategoryXxx` metadata 块（沿用现有写法）。改完后跑 `flutter gen-l10n` 重新生成 `app_localizations*.dart`。

#### 3. `link2ur/lib/features/task_expert/views/task_expert_list_view.dart`

`_categoryLabel(BuildContext, String key)` 的 switch 在 default 之前加 17 个 case，映射到新 i18n getter。

#### 4. `link2ur/lib/features/task_expert/views/task_expert_search_view.dart`

如果该文件也有相同的 switch，同步加（前面 grep 看到该文件也用 `ExpertConstants.categoryKeys` 渲染选项；如果它把 label 翻译委托到了同一处则不需要改，否则要同步）。

#### 5. `link2ur/lib/features/expert_dashboard/views/tabs/services_tab.dart`

服务发布表单的下拉框已经按 `ExpertConstants.serviceCategoryKeys` 渲染，添加 17 个 key 后会自动出现，**0 改动**（除非 label 翻译走的是和 list_view 同样独立的 switch，需检查）。

#### 6. `link2ur/lib/features/skill_leaderboard/views/skill_leaderboard_view.dart`

在 `_buildContent` 里，`_LeaderboardList` 上方插入两个新 widget：

```
Column
├── _CategoryTabs (existing)
└── Expanded
    └── ListView (新)
        ├── _ExpertsForCategorySection (新)  ← 该 category 下的达人团队，水平滚动卡片
        ├── _ServicesForCategorySection (新)  ← 该 category 下的达人服务，水平滚动卡片
        └── _LeaderboardList (existing)
```

加载策略：
- category tab 切换时，由 `SkillLeaderboardBloc` 触发**新增的 2 个 sub event**（或用一个 `LeaderboardCategorySelected` 副作用）：`SkillExpertsLoadRequested(category)`、`SkillServicesLoadRequested(category)`
- 复用 BLoC pattern：state 加 `experts: List<Expert>`、`services: List<TaskExpertService>`、各自的 `expertsStatus`、`servicesStatus`

加载时机：懒加载，category 选中时才触发。

空状态：达人/服务区块为空时不显示该 section（避免在仅 1 个技能独有 key `other` tab 下出现"暂无"占位）。

### 后端（Python / FastAPI）

#### 1. `Expert.category` / `TaskExpertService.category` 模型 — 0 改动

字段是自由 `String(50)`，不做枚举约束，新 key 直接能存。

#### 2. 已有接口：`expert_routes.py:GET /api/experts?category=X` — 0 改动

`expert_routes.py:490` 已经支持 `category` query param 精确筛选。前端拿来就能用。

#### 3. 服务列表按 category 查询 — 确认是否已有

需要在 spec planning 阶段确认 `TaskExpertService` 是否有 `GET /api/expert-services?category=X` 类似接口，如果没有，要新增一个轻量端点或扩展现有的 service 列表接口。

候选位置：`backend/app/routes/` 下 `expert_service_routes.py`（如果存在）或 `expert_routes.py`。

签名（建议）：

```python
@router.get("/expert-services", response_model=List[TaskExpertServiceOut])
def list_expert_services(
    category: Optional[str] = Query(None),
    limit: int = Query(20, le=50),
    offset: int = Query(0, ge=0),
    db: Session = Depends(get_db),
):
    """List active expert services, optionally filtered by category."""
    ...
```

#### 4. 不需要的改动

- `skill_categories` 表 — 不动
- 数据迁移 — 不写
- admin 后台 category 下拉枚举 — 如果是从 `Expert.category` 读 distinct 自然出现新值；如果是硬编码下拉则同步加 17 项

## 风险与权衡

### 风险 1：重叠桶并存（达人侧出现"两个相似选项"）

加完后达人下拉里会出现 4 对语义相近的桶：

| 老桶 | 新增的 task-aligned 桶 | 区别 |
|---|---|---|
| `food` 美食 | `cooking` 烹饪 | food = 卖食物外送；cooking = 上门做饭 |
| `housekeeping` 家政 | `cleaning` 清洁 | housekeeping = 综合（含做饭/带娃）；cleaning = 单纯打扫 |
| `errand_transport` 跑腿运输 | `errand` 跑腿 + `pickup_dropoff` 接送 | 老粗桶被任务侧拆细 |
| `social_entertainment` 社交娱乐 | `accompany` 陪伴 | social = KTV/聚会陪玩；accompany = 看病/办事陪同 |

**应对**：i18n 翻译里用清晰的中文表述区分（如 `housekeeping=家政（综合）`、`cleaning=清洁（打扫）`），降低混淆。**不做**强制迁移或合并。

### 风险 2：`second_hand` 在达人侧的边界

留学生有"代卖二手 / 估价 / 鉴定"业务需求，但和跳蚤市场板块功能重叠。**应对**：先放进字典；如果上线后无人挂或被滥用，前端把这一项 hide 即可（零代码代价）。

### 风险 3：`Expert.category` / `TaskExpertService.category` 是自由 String，不强制校验

前端用枚举常量保证写入合法值；admin 后台 / 脚本 / 历史数据可能存在野值。**应对**：本次不加 enum 约束；后续可补 DB CHECK 约束或 Pydantic enum 校验。

### 风险 4：达人独有 9 个 key 在技能板块没入口

已确认接受。如果未来需要展示，再单独把 `skill_categories` 表补这 9 行（一条 SQL migration），零破坏性。

### 风险 5：申请通过 → 管理员打标 之间存在"无分类窗口期"

由于本次保持申请表单**不含 category**（用户决策 A），新达人审核通过后到管理员手动打标之间，`Expert.category` 为 NULL。这段时间该达人在按 category 筛选/搜索/技能板块"该类下达人"section 里**搜不到**。

**应对**：
- 现状本来就是这样（不是新风险），只是 spec 显式承认
- 管理员审核通过时**养成同步打标的习惯**（admin 后台编辑页同一个表单里做）
- 如果未来发现窗口期太长导致体验问题，再考虑切到方案 B（申请时让用户选首选 category 给管理员参考）

---

## 全面回归测试（项目变更确认）

本次改动看起来是"加 17 项常量"，但 `category` 字段被全栈很多地方读写，必须全面回归。下面分模块列受影响点和验证用例。

### A. 受影响模块清单（前置审计）

实施前先 grep 一次，确认所有读写 `Expert.category` / `TaskExpertService.category` / `expertCategory*` i18n 的位置都被覆盖：

```bash
# 后端
grep -rn "Expert.category\|TaskExpertService.category" backend/app
grep -rn "experts.category\|task_expert_services.category" backend/app

# 前端
grep -rn "expertCategory\|categoryKeys\|serviceCategoryKeys" link2ur/lib

# admin 前端
grep -rn "expert.*category\|task_expert.*category" admin/src frontend/src 2>/dev/null
```

预期受影响模块（已知）：

| 模块 | 文件 | 受影响内容 |
|---|---|---|
| **达人申请表单** | 申请页（用户侧） | ❌ **不改** — 申请表本来就没 category 字段 |
| **Admin 后台编辑 Expert.category** | `admin_expert_routes.py` + `admin/src/api.ts` 编辑达人页 + `frontend/src` 如果有 | ✅ **下拉框新增 17 项**（这是本次的关键改点） |
| 服务发布/编辑表单（达人 dashboard） | `expert_dashboard/views/tabs/services_tab.dart` | category 下拉新增 17 项（用 `serviceCategoryKeys`） |
| 达人列表页（buyer 视角） | `task_expert/views/task_expert_list_view.dart` | category 筛选 chips、卡片 label |
| 达人搜索页 | `task_expert/views/task_expert_search_view.dart` | category filter |
| 达人详情页 | `task_expert/views/task_expert_detail_view.dart`（如存在） | category label 渲染 |
| 服务详情页 | service detail view | category label 渲染 |
| Home 推荐卡 | `home/views/...` | 涉及 expert category 时的 label |
| 关注 Feed | `follow_feed_routes.py` + 前端 feed view | services/activities 的 category 字段 |
| 技能板块 | `skill_leaderboard/views/skill_leaderboard_view.dart` | 新增 2 个 section（达人 / 服务） |
| Admin 后台达人列表筛选 | `admin_task_expert_routes.py` 筛选端点 + admin 前端 | category 筛选下拉新增 17 项 |
| AI 推荐 / 需求推断 | `services/demand_inference.py`、`services/ai_agent.py`、`services/ai_tools.py` | 按 category 聚合统计的 SQL，会自动适配新值，无需改 |
| Celery 调度 | `celery_tasks.py:compute_skill_category_counts_task`、`task_scheduler.py` | 同上 |
| 全文搜索/Trending | `routes/system_routes.py` 等 | 如果 category 在搜索 hint 里 |

### B. 冒烟测试（最低门槛）

- [ ] App 启动成功，无 i18n key missing 错误（`flutter analyze` 通过）
- [ ] **达人申请表单不改**（无 category 字段，保持现状）
- [ ] **Admin 后台编辑达人 category 下拉框**：能看到 30 项（不含 `all`）—— 这是本次扩充的主入口
- [ ] 达人 dashboard 服务发布表单下拉框，能看到 30 个选项
- [ ] 达人列表顶部 category chips 显示 31 项（含 `all`）
- [ ] 技能板块顶部 22 个 tabs 渲染正常

### C. 数据写入测试

| # | 操作 | 在哪做 | 预期 |
|---|---|---|---|
| 1 | 用户提交达人申请 | 申请表单 | 表单里**没有** category 字段（保持现状），写入 `expert_applications` 不含 category |
| 2 | 管理员审核通过申请 | admin 后台 | 创建 `Expert` 记录，`category` 为 NULL（待管理员后续打标） |
| 3 | 管理员把某达人 category 从 `food` 改成 `shopping` | admin 后台编辑页 | DB `experts.category='shopping'`，列表筛选生效 |
| 4 | 管理员把某达人 category 设为 `cleaning`（新加 key） | admin 后台 | 写入成功，下拉里能选到 |
| 5 | 达人在 dashboard 发布一个 `cleaning` 服务 | 达人 dashboard | DB `task_expert_services.category='cleaning'` |
| 6 | 达人发布一个 `second_hand` 服务 | 达人 dashboard | 写入成功（OK 上线后再观察是否 hide 该选项） |

### D. 数据读取测试（含老数据）

| # | 操作 | 预期 |
|---|---|---|
| 1 | 老 `food` 桶的达人在达人列表里依然能被筛出 | 列表显示，label="美食"/`Food` |
| 2 | 老 `gaming` 桶的达人在技能板块里**找不到**（接受） | 切技能板块所有 22 tabs 都不显示 |
| 3 | 新 `shopping` 桶的达人在达人列表能筛出 | 显示，label="代购"/`Shopping` |
| 4 | 新 `shopping` 桶的达人在技能板块的 `Shopping` tab 下显示 | 达人 section 有数据 |
| 5 | 切技能板块 `other` tab | 达人 section 隐藏（无数据） |
| 6 | 切技能板块 `programming` tab | 同时显示老共有 + 新共有的达人 / 服务 / 排行榜 |

### E. 跨语言测试

对每个新增的 17 个 key，检查在以下页面的 zh / zh_Hant / en 三套 locale 下都正确显示：

- [ ] 达人入驻表单下拉
- [ ] 服务发布表单下拉
- [ ] 达人列表 category chips
- [ ] 达人卡片 / 详情页 category 标签
- [ ] 技能板块 category tab（这部分翻译来自 `skill_categories` 表的 `name_zh` / `name_en`，**不**走 `expertCategory*` i18n —— 注意区分）

### F. AI / 推荐 / 调度回归

- [ ] `compute_skill_category_counts_task`（每小时）执行不报错，新 category 出现在 `skill_categories` 计数中
- [ ] AI 工具 `services/ai_tools.py` 中按 category 检索达人/服务的 prompt / function 不丢新 key
- [ ] Demand inference (`services/demand_inference.py`) 按 category group_by 不报错

### G. Admin 后台回归

- [ ] `admin/src/api.ts` 调用 `admin_task_expert_routes.py` 的编辑端点，category 字段能传入新 key 并保存
- [ ] admin 列表筛选下拉新增 17 项

### H. 全栈一致性检查

按 `~/.claude/skills/full-stack-consistency-check/SKILL.md` 跑：

```
DB Model:        Expert.category / TaskExpertService.category (String 50)  → 不动 ✅
Pydantic Schema: ExpertOut / TaskExpertServiceOut                          → 不动 ✅
API Route:       GET /api/experts?category=X                               → 已存在 ✅
                 GET /api/expert-services?category=X                       → 需确认/补
Frontend EP:     api_endpoints.dart                                        → 可能新增 1 条
Repository:      ExpertRepository / ExpertServiceRepository                → 新增 byCategory 方法
Model.fromJson:  Expert / TaskExpertService                                → 不动 ✅
BLoC:            SkillLeaderboardBloc                                      → 新增 2 个 event/state 字段
UI:              skill_leaderboard_view.dart                               → 新增 2 个 section
```

### I. 上线前的最后人工烟测（mobile + web）

- [ ] iOS 真机：达人入驻 → 选 `digital` → 详情页显示"数码/IT"
- [ ] Android 真机：技能板块 → 切到 `Shopping` tab → 看到代购达人卡片
- [ ] Web 端（如果使用）：全部下拉项显示正确
- [ ] 切语言到 zh_Hant：所有新 label 显示繁体翻译

### J. 回滚预案

如果上线后发现 17 个新 key 中有问题：

- 单个 key 想 hide：从 `expert_constants.dart` 的 `categoryKeys` / `serviceCategoryKeys` 删除即可（DB 里已挂这个 key 的达人不影响展示，因为 `_categoryLabel` 的 default 分支 fallback 到 raw key）
- 整体回滚：revert 一次 commit 即可，DB 没改动

---

## 后续可能的扩展（非本次）

- 把 `Expert.category` / `TaskExpertService.category` 加 enum 约束，强制只能写 30 keys 之一
- 把 `skill_categories` 表补 9 个达人独有 key（food / beverage / cake / 等），让美容/游戏等也进技能板块
- `Expert.category` 改为多值（一个达人挂多个分类）
- 老 `errand_transport` / `food` 等粗桶下的达人引导式迁移到更细的新桶
