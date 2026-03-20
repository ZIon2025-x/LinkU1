# 附近任务推送 — 设计规格

## 目标

用户打开 App 时，如果附近 1km 内有新发布的线下任务，自动推送一条通知提醒用户。

## 核心流程

```
用户打开 App
  → 检查"附近任务提醒"开关是否开启
  → 检查距上次上传是否 ≥ 6 小时
  → 获取 GPS 坐标
  → POST /api/profile/location {latitude, longitude}
  → 后端存储位置
  → 后端查 1km 内最新未推送任务
  → 推送一条通知
  → 用户点击通知 → 跳转任务详情
```

## 数据模型

### 新增表：user_locations

存储用户最近一次上报的位置。

| 字段 | 类型 | 说明 |
|------|------|------|
| id | SERIAL PK | |
| user_id | VARCHAR(8) UNIQUE FK | 每用户一条记录，upsert |
| latitude | DECIMAL(10,8) NOT NULL | |
| longitude | DECIMAL(11,8) NOT NULL | |
| updated_at | TIMESTAMPTZ | 上次上报时间 |

索引：
- `UNIQUE (user_id)`
- `GIST (point(longitude, latitude))` — 空间查询

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

新增字段：

| 字段 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| nearby_push_enabled | BOOLEAN | FALSE | 附近任务提醒开关 |

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

**处理逻辑**：
1. 验证用户已认证
2. Upsert `user_locations` 记录
3. 检查 `nearby_push_enabled` 是否开启，未开启则直接返回
4. 检查冷却时间：查 `nearby_task_pushes` 该用户最近一条记录，如果 `pushed_at` 距现在 < 6 小时，跳过
5. 查询 1km 内符合条件的最新任务（见下方查询逻辑）
6. 如果找到，异步推送 + 写入 `nearby_task_pushes`
7. 返回 `{"message": "ok"}`

**响应**：始终返回 200，推送是异步的，不影响 App 启动速度。

### 附近任务查询逻辑

使用 Haversine 公式 + 已有的 GiST 索引：

```sql
SELECT t.id, t.title_zh, t.title_en, t.location,
       earth_distance(
         ll_to_earth(user_lat, user_lon),
         ll_to_earth(t.latitude, t.longitude)
       ) AS distance_m
FROM tasks t
WHERE t.latitude IS NOT NULL
  AND t.longitude IS NOT NULL
  AND t.status = 'open'
  AND t.poster_id != :user_id
  AND t.id NOT IN (
    SELECT task_id FROM nearby_task_pushes WHERE user_id = :user_id
  )
  AND t.id NOT IN (
    SELECT task_id FROM task_applications WHERE applicant_id = :user_id
  )
  AND earth_distance(
    ll_to_earth(:user_lat, :user_lon),
    ll_to_earth(t.latitude, t.longitude)
  ) <= 1000
ORDER BY t.created_at DESC
LIMIT 1
```

**注意**：如果 PostgreSQL 没有 `earthdistance` 扩展，使用 Haversine 公式的 Python 实现作为 fallback：

```python
from math import radians, sin, cos, sqrt, atan2

def haversine_m(lat1, lon1, lat2, lon2):
    R = 6371000  # 地球半径（米）
    dlat = radians(lat2 - lat1)
    dlon = radians(lon2 - lon1)
    a = sin(dlat/2)**2 + cos(radians(lat1)) * cos(radians(lat2)) * sin(dlon/2)**2
    return R * 2 * atan2(sqrt(a), sqrt(1-a))
```

**过滤规则汇总**：
- 排除用户自己发布的任务
- 排除用户已申请过的任务
- 排除已完成/已取消/已过期的（只要 status='open'）
- 排除无坐标的任务（线上任务）
- 排除已推送过的任务（nearby_task_pushes）
- 1km 半径内
- 按发布时间降序，取最新一条

## 推送通知

### 新增通知类型：nearby_task

**模板**：

| 语言 | 标题 | 内容 |
|------|------|------|
| zh | 附近有新任务 | {task_title}，就在你附近 |
| en | New task nearby | {task_title}, near you |

**推送 payload**：
```json
{
  "type": "nearby_task",
  "task_id": "123",
  "localized": {
    "zh": {"title": "附近有新任务", "body": "帮我搬家，就在你附近"},
    "en": {"title": "New task nearby", "body": "Help me move, near you"}
  }
}
```

**点击行为**：跳转到 `/tasks/{task_id}` 任务详情页。

## Flutter 端

### 设置开关

在用户设置页添加"附近任务提醒"开关：
- 默认关闭
- 开启时请求定位权限（"使用 App 时允许"即可，不需要"始终允许"）
- 如果用户拒绝定位权限，开关自动关闭并提示
- 开关状态通过 `PUT /api/profile/preferences` 同步到后端 `nearby_push_enabled`

### App 启动位置上传

在 `app.dart` 的初始化流程中（用户已认证后）：

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
- 每天凌晨清理 30 天前的记录
- 注册到 Celery beat + TaskScheduler（双调度器模式，与子项目 1 一致）

## 不做的事

- 不做后台持续定位（不需要"始终允许"权限）
- 不做实时推送（不在任务发布时触发，而是用户打开 App 时触发）
- 不做画像匹配过滤（子项目 2 的范畴）
- 不做距离展示（推送文案不显示具体米数，简洁为主）
- 不做多任务推送（每次最多推一条）
