# 官方账号与官方活动 — 设计文档

**日期**：2026-02-23
**状态**：已批准
**方案**：扩展现有模型（方案 C）

---

## 背景

平台需要一个"官方"达人账号，出现在达人列表中，并能发布官方活动（抽奖、免费试吃、活动门票等）。

---

## 需求摘要

- 一个官方账号，置顶于达人列表，带官方标识
- 官方活动混入现有活动列表，并在官方达人详情页内可见
- 两种参与方式：**抽奖**（报名 + 截止开奖）和**抢位**（先到先得）
- 四种奖品形式：平台积分、实物奖品、库券代码、线下到场
- 开奖方式：自动（task scheduler，保留 Celery 接口）和手动（管理员触发）

---

## 数据库变更

### `task_experts` 表新增字段

| 字段 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `is_official` | BOOLEAN | FALSE | 是否官方账号 |
| `official_badge` | VARCHAR(50) | NULL | 徽章文字，如 "官方" / "Official" |

### `activities` 表新增字段

| 字段 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `activity_type` | VARCHAR(20) | `'standard'` | `standard` / `lottery` / `first_come` |
| `expert_service_id` | INTEGER | NULL | 改为可选（官方活动不绑定服务） |
| `prize_type` | VARCHAR(20) | NULL | `points` / `physical` / `voucher_code` / `in_person` |
| `prize_description` | TEXT | NULL | 奖品说明 |
| `prize_count` | INTEGER | NULL | 奖品数量（中奖名额数） |
| `voucher_codes` | JSONB | NULL | 库券代码列表，如 `["CODE1","CODE2"]` |
| `draw_mode` | VARCHAR(10) | NULL | `auto` / `manual` |
| `draw_at` | TIMESTAMP | NULL | 自动开奖时间 |
| `drawn_at` | TIMESTAMP | NULL | 实际开奖时间 |
| `winners` | JSONB | NULL | `[{user_id, name, prize_index}]` |
| `is_drawn` | BOOLEAN | FALSE | 是否已开奖 |

### 新增 `official_activity_applications` 表

```sql
CREATE TABLE official_activity_applications (
    id              SERIAL PRIMARY KEY,
    activity_id     INTEGER NOT NULL REFERENCES activities(id),
    user_id         VARCHAR(8) NOT NULL REFERENCES users(id),
    applied_at      TIMESTAMP DEFAULT NOW(),
    status          VARCHAR(20) DEFAULT 'pending',
                    -- 'pending', 'won', 'lost', 'attending'
    prize_index     INTEGER NULL,       -- 对应 voucher_codes 中第几个
    notified_at     TIMESTAMP NULL,     -- 通知中奖时间
    UNIQUE(activity_id, user_id)        -- 每人只能报名一次
);
```

---

## 后端 API

### 官方账号管理（管理员）

```
POST   /admin/official-account/setup              创建/更新官方账号
GET    /admin/official-account                    查看官方账号信息
```

### 官方活动管理（管理员）

```
POST   /admin/official-activities                 创建官方活动
PUT    /admin/official-activities/{id}            编辑活动
DELETE /admin/official-activities/{id}            删除/取消活动
POST   /admin/official-activities/{id}/draw       手动开奖
GET    /admin/official-activities/{id}/applicants 查看报名名单
```

### 用户侧接口

```
GET    /task-experts?page=1                       达人列表（官方账号始终排第一）
GET    /activities?include_official=true          活动列表（官方活动混入，带 is_official 标记）
GET    /official-activities/{id}                  官方活动详情
POST   /official-activities/{id}/apply            报名（抽奖/抢位均用此接口）
DELETE /official-activities/{id}/apply            取消报名（截止前）
GET    /official-activities/{id}/result           查看开奖结果
```

### 开奖逻辑

**自动开奖**（task scheduler，保留 Celery 接口以便切换）：
1. 创建活动时若 `draw_mode=auto`，注册 `draw_at` 时间的延时任务
2. 从 `official_activity_applications` 随机抽取 `prize_count` 个 `pending` 用户
3. 更新中奖者状态为 `won`，其余为 `lost`；填写 `drawn_at`、`is_drawn=True`
4. 发站内通知给中奖者（复用现有 Notification 系统）
5. 若 `prize_type=voucher_code`，自动分配对应 `voucher_codes[i]`

**手动开奖**：管理员调用 `/draw` 接口，执行相同逻辑。

**抢位活动**：`apply` 接口直接检查 `current_participants < prize_count`，满员返回失败。

---

## Flutter 端

### 模型变更

**`task_expert.dart`**：
- 新增 `isOfficial: bool`、`officialBadge: String?`

**`activity.dart`**：
- 新增 `activityType`、`prizeType`、`prizeDescription`、`prizeCount`
- 新增 `drawMode`、`drawAt`、`drawnAt`、`winners`、`isDrawn`、`isOfficial`
- 新增 `ActivityWinner` 模型

### BLoC 变更

`ActivityBloc` 新增事件：
- `ActivityApplyOfficial` — 报名官方活动
- `ActivityCancelApplyOfficial` — 取消报名
- `ActivityLoadResult` — 加载开奖结果

### View 变更

- **`task_expert_list_view.dart`**：官方账号卡片右上角显示官方徽章（后端已保证排序）
- **`activity_detail_view.dart`**：根据 `activityType` 动态渲染底部操作区
  - `lottery`：报名截止时间 + 当前人数 + "参与抽奖"；已开奖显示中奖名单
  - `first_come`：剩余名额，满员显示"已抢完"
  - `standard`：现有逻辑不变
- 新增小组件：奖品展示区块

---

## iOS 原生端

### 模型变更

**`TaskExpert.swift`**：
```swift
let isOfficial: Bool?
let officialBadge: String?
```

**`Activity.swift`**：
```swift
let activityType: String?
let prizeType: String?
let prizeDescription: String?
let prizeCount: Int?
let drawMode: String?
let drawAt: String?
let drawnAt: String?
let winners: [ActivityWinner]?
let isDrawn: Bool?
let isOfficial: Bool?

var isLottery: Bool { activityType == "lottery" }
var isFirstCome: Bool { activityType == "first_come" }
```

新增 `ActivityWinner` struct。

### API 扩展

新增 `APIService+OfficialActivities.swift`：
- `applyToOfficialActivity(activityId:)`
- `cancelOfficialActivityApplication(activityId:)`
- `getOfficialActivityResult(activityId:)` → `OfficialActivityResult`

### ViewModel 变更

**`ActivityViewModel.swift`** 新增：
- `applyToOfficialActivity(activityId:)`
- `cancelOfficialApplication(activityId:)`
- `loadOfficialActivityResult(activityId:)`
- `@Published var officialApplyResult: OfficialApplyStatus?`
- `@Published var myActivityResult: OfficialActivityResult?`

### View 变更

- **`TaskExpertListView.swift`**：官方账号卡片渲染 `OfficialBadgeView`
- **`ActivityDetailView.swift`**：根据 `activityType` 动态渲染底部操作栏
- 新增小组件（`Views/Components/`）：
  - `OfficialBadgeView.swift`
  - `ActivityPrizeSection.swift`
  - `WinnersListView.swift`

### 本地化

`Localizable.strings` 新增键：
```
"official", "activity_type_lottery", "activity_type_first_come",
"prize_type_points", "prize_type_physical", "prize_type_voucher", "prize_type_in_person",
"draw_pending", "draw_won", "draw_lost"
```

---

## 不在本次范围内

- 管理员前端（admin panel）的官方活动创建 UI
- 推送通知（现有站内通知已足够）
- 活动分享功能
