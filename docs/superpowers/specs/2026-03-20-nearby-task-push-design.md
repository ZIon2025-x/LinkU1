# 附近任务推送 — 设计规格

## 目标

用户打开 App 时，如果附近 1km 内有新发布的线下任务，自动推送一条通知提醒用户。

## 核心流程

```
用户打开 App
  → 检查"附近任务提醒"开关是否开启
  → 检查距上次上传是否 ≥ 6 小时（客户端冷却）
  → 获取 GPS 坐标
  → POST /api/profile/location {latitude, longitude}
  → 后端存储位置
  → 后端检查推送冷却（≥ 6 小时）
  → 后端查 1km 内最新未推送任务
  → 推送一条通知
  → 用户点击通知 → 跳转任务详情
```

**双重冷却机制**：客户端和后端各自检查 6 小时冷却。客户端检查避免无意义 API 调用；后端检查是权威校验，防止客户端绕过。两者独立计时，可能有微小偏差，但行为一致：确保同一用户不会在 6 小时内收到多条附近任务推送。

## 数据模型

### 新增表：user_locations

存储用户最近一次上报的位置。独立建表（不合并到 user_profile_preferences），因为位置数据可复用于未来的附近推荐、地图展示等功能。

| 字段 | 类型 | 说明 |
|------|------|------|
| id | SERIAL PK | |
| user_id | VARCHAR(8) UNIQUE FK | 每用户一条记录，upsert |
| latitude | DECIMAL(10,8) NOT NULL | |
| longitude | DECIMAL(11,8) NOT NULL | |
| updated_at | TIMESTAMPTZ | 上次上报时间 |

索引：
- `UNIQUE (user_id)`

### 新增表：nearby_task_pushes

记录已推送过的 (用户, 任务) 组合，防止重复推送。

| 字段 | 类型 | 说明 |
|------|------|------|
| id | SERIAL PK | |
| user_id | VARCHAR(8) FK | |
| task_id | INTEGER FK | |
| pushed_at | TIMESTAMPTZ | 推送时间 |

约束：
- `UNIQUE (user_id, task_id)` — 同一任务不重复推送给同一用户

索引：
- `(user_id, pushed_at)` — 查冷却时间

### 修改表：user_profile_preferences

新增字段（需新 migration + 更新 SQLAlchemy model）：

| 字段 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| nearby_push_enabled | BOOLEAN | FALSE | 附近任务提醒开关 |

### 修改涉及的现有代码

- `backend/app/models.py`：`UserProfilePreference` 模型新增 `nearby_push_enabled` 列
- `backend/app/routes/user_profile.py`：`PreferenceUpdate` schema 新增该字段；GET/PUT/summary 响应包含该字段
- Flutter `UserProfilePreference` model：新增 `nearbyPushEnabled` 字段

## 后端 API

### POST /api/profile/location

接收用户位置，触发附近任务匹配和推送。

**请求体**：
```json
{
  "latitude": 51.5074,
  "longitude": -0.1278
}
```

**输入验证**：
- 使用已有的 `validate_coordinates()` 函数校验范围（latitude -90~90，longitude -180~180）
- 无效坐标返回 422

**限流**：复用已有的 `rate_limiting.py`，限制每用户 5 分钟 1 次。

**处理逻辑**：
1. 验证用户已认证
2. 验证坐标合法性
3. Upsert `user_locations` 记录
4. 检查 `nearby_push_enabled` 是否开启，未开启则直接返回
5. 检查冷却时间：查 `nearby_task_pushes` 该用户最近一条记录，如果 `pushed_at` 距现在 < 6 小时，跳过
6. 查询 1km 内符合条件的最新任务（见下方查询逻辑）
7. 如果找到，异步推送 + 写入 `nearby_task_pushes`
8. 返回 `{"message": "ok"}`

**响应**：始终返回 200，推送是异步的，不影响 App 启动速度。

### 附近任务查询逻辑

**策略**：使用 Python Haversine 计算距离。先用 SQL 矩形边界框粗筛（利用 B-tree 索引），再在 Python 中精确计算。

复用已有的 `backend/app/utils/location_utils.py` 中的距离计算函数（返回 km），避免重复实现。

**SQL 粗筛**（矩形边界框，约 ±0.009 纬度 ≈ 1km）：

```sql
SELECT t.id, t.title_zh, t.title_en, t.location, t.latitude, t.longitude, t.created_at
FROM tasks t
WHERE t.latitude IS NOT NULL
  AND t.longitude IS NOT NULL
  AND t.status = 'open'
  AND t.created_at >= NOW() - INTERVAL '7 days'
  AND t.poster_id != :user_id
  AND t.latitude BETWEEN :lat - 0.009 AND :lat + 0.009
  AND t.longitude BETWEEN :lon - 0.013 AND :lon + 0.013
  AND NOT EXISTS (
    SELECT 1 FROM nearby_task_pushes ntp
    WHERE ntp.task_id = t.id AND ntp.user_id = :user_id
  )
  AND NOT EXISTS (
    SELECT 1 FROM task_applications ta
    WHERE ta.task_id = t.id AND ta.applicant_id = :user_id
  )
ORDER BY t.created_at DESC
LIMIT 10
```

**Python 精筛**：对粗筛结果逐条计算 Haversine 距离，取 ≤ 1km 中最新的一条。

**过滤规则汇总**：
- 排除用户自己发布的任务
- 排除用户已申请过的任务（`NOT EXISTS`）
- 排除已完成/已取消/已过期的（只要 `status='open'`）
- 排除 7 天前的旧任务（保证推送内容新鲜）
- 排除无坐标的任务（线上任务）
- 排除已推送过的任务（`NOT EXISTS nearby_task_pushes`）
- 1km 半径内
- 按发布时间降序，取最新一条

## 推送通知

### 新增通知类型：nearby_task

在已有的 `push_notification_templates.py` 中注册 `nearby_task` 模板，复用现有模板系统：

**模板变量**：`task_title`（自动根据 device_language 选择 title_zh / title_en）

| 语言 | 标题 | 内容 |
|------|------|------|
| zh | 附近有新任务 | {task_title}，就在你附近 |
| en | New task nearby | {task_title}, near you |

**推送 payload**：
```json
{
  "type": "nearby_task",
  "task_id": "123"
}
```

**点击行为**：跳转到 `/tasks/{task_id}` 任务详情页。如果任务已被接/取消/完成，用户会看到当前状态，无需额外处理。

## Flutter 端

### 设置开关

在用户设置页添加"附近任务提醒"开关：
- 默认关闭
- 开启时请求定位权限（"使用 App 时允许"即可，不需要"始终允许"）
- 如果用户拒绝定位权限，开关自动关闭并提示
- 开关状态通过 `PUT /api/profile/preferences` 同步到后端 `nearby_push_enabled`
- Flutter `UserProfilePreference` model 和 `PreferenceEditView` 需要新增该字段
- 本地也缓存开关状态到 `StorageService`，App 启动时读取无需额外 API 调用

### App 启动位置上传

在 `app.dart` 的初始化流程中（用户已认证后），异步执行：

```
if (已登录 && nearby_push_enabled) {
  last_upload = StorageService.get('last_location_upload')
  if (last_upload == null || 距现在 >= 6 小时) {
    position = await Geolocator.getCurrentPosition()
    await api.post('/api/profile/location', {lat, lon})
    StorageService.set('last_location_upload', now)
  }
}
```

**要点**：
- 不阻塞 App 启动，异步执行
- 6 小时冷却在客户端也检查一次，避免无意义的 API 调用
- 定位失败静默忽略，不影响正常使用

### 推送点击处理

在 `PushNotificationService` 的路由映射中新增：

```dart
case 'nearby_task':
  context.push('/tasks/${data['task_id']}');
```

## 数据清理

`nearby_task_pushes` 表会持续增长。添加定时清理任务：
- 每天凌晨清理 30 天前的记录（基于 `pushed_at` 字段）
- 注册到 Celery beat + TaskScheduler（双调度器模式，与子项目 1 一致）

## 不做的事

- 不做后台持续定位（不需要"始终允许"权限）
- 不做实时推送（不在任务发布时触发，而是用户打开 App 时触发）
- 不做画像匹配过滤（子项目 2 的范畴）
- 不做距离展示（推送文案不显示具体米数，简洁为主）
- 不做多任务推送（每次最多推一条）
