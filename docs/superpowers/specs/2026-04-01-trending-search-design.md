# 热搜榜功能设计

## 概述

为发现页新增热搜榜功能。基于用户真实搜索词，通过 jieba 分词 + Jaccard 相似度聚类，将相似搜索合并后按热度排名展示 Top10。

## 核心设计决策

| 决策项 | 选择 | 说明 |
|--------|------|------|
| 关键词处理 | Jaccard 相似度聚类 | 不拆词，合并相似搜索词，展示搜索量最高的原始表述 |
| 时间窗口 | 7天滚动，近期加权 | 今天 ×7，昨天 ×6 ... 第7天 ×1 |
| 展示条数 | Top 10 | 附带浏览量 + 涨跌标签 |
| 热度指标 | 加权搜索次数 | 纯搜索次数 × 天数权重 |
| 浏览量 | 相关内容 view_count 总和 | 聚合帖子/任务/活动中包含该关键词的内容浏览量，缓存时一并计算 |
| 更新频率 | 每小时 | Celery 定时任务 |
| 上榜门槛 | ≥3 个不同用户搜过 | 防止垃圾词 |
| 人工干预 | 黑名单 + 置顶 | Admin 接口管理 |

## 涨跌标签规则

三种标签，每个词只显示一个，优先级：热 > NEW > 升

| 标签 | 条件 |
|------|------|
| 🔥 热 | 上一个7天窗口 Top3 **且** 当前窗口仍 Top3 |
| NEW | 上一窗口不在榜（Top10 之外），当前窗口首次进榜 |
| ↑ 升 | 当前窗口加权搜索次数比上一窗口涨幅 >50% |

## 聚类算法

1. 对每条搜索词用 jieba 分词，得到词集合
2. 计算任意两条搜索词的 Jaccard 相似度 = |交集| / |并集|
3. 相似度 > 0.5 的归为一组
4. 每组取加权搜索次数最高的原始搜索词作为展示词，组内次数求和

示例：
- "毕业照跟拍 伦敦" → `{毕业照, 跟拍, 伦敦}`
- "伦敦毕业照" → `{伦敦, 毕业照}`
- Jaccard = 2/3 = 0.67 > 0.5 → 合并，展示搜索量更高的那条

优化：只对7天内 ≥3 个不同用户搜过的词做聚类，控制计算量。

## 数据模型

### search_logs（搜索日志）

| 字段 | 类型 | 说明 |
|------|------|------|
| id | Integer, PK | 主键 |
| user_id | String, FK | 搜索用户（可为空，允许未登录搜索） |
| raw_query | String | 原始搜索词 |
| tokens | JSON | jieba 分词结果，如 `["毕业照", "跟拍", "伦敦"]` |
| created_at | DateTime | 搜索时间 |

索引：`created_at`（时间窗口查询）、`user_id`（去重统计）

### trending_blacklist（黑名单）

| 字段 | 类型 | 说明 |
|------|------|------|
| id | Integer, PK | 主键 |
| keyword | String, unique | 屏蔽关键词 |
| created_by | String, FK | 操作管理员 |
| created_at | DateTime | 创建时间 |

匹配规则：展示词包含黑名单中任一关键词即过滤。

### trending_pinned（置顶词）

| 字段 | 类型 | 说明 |
|------|------|------|
| id | Integer, PK | 主键 |
| keyword | String | 置顶展示词 |
| display_heat | String | 展示用的热度文案（如"2.3w浏览"），管理员手填 |
| sort_order | Integer | 排序，越小越靠前 |
| created_by | String, FK | 操作管理员 |
| expires_at | DateTime | 过期时间，到期自动下线 |
| created_at | DateTime | 创建时间 |

## Celery 定时任务流程

每小时执行一次 `compute_trending_searches`：

1. **取数据**：查询 search_logs 最近7天的记录
2. **去重过滤**：按 raw_query 分组，过滤掉 distinct user_id < 3 的词
3. **近期加权**：按天计算权重（今天 ×7 ... 第7天 ×1），得到每条搜索词的加权次数
4. **聚类合并**：
   - 遍历所有候选搜索词
   - 用 tokens 字段计算 Jaccard 相似度
   - 相似度 > 0.5 的归为一组
   - 每组取加权次数最高的 raw_query 作为展示词，组内加权次数求和
5. **计算浏览量**：对每个展示词，查询 forum_posts + tasks + activities 中标题包含该词（分词后有交集）的记录，SUM(view_count) 作为浏览量
6. **涨跌标签**：对比 Redis 中存储的上一周期 Top10，按规则打标签
7. **过滤黑名单**：展示词包含 trending_blacklist 中任一关键词的，移除
8. **插入置顶**：查询 trending_pinned 中未过期的词，按 sort_order 插入榜单头部
9. **输出 Top10**：写入 Redis key `trending:current`（当前榜单）和 `trending:previous`（上一期，用于下次涨跌对比）
10. **TTL**：缓存 70 分钟（略大于1小时更新周期，防止空窗）

## Redis 缓存结构

```
trending:current    → JSON (当前 Top10 榜单)
trending:previous   → JSON (上一期 Top10，用于涨跌对比)
```

缓存内容格式：
```json
[
  {
    "rank": 1,
    "keyword": "毕业照跟拍 伦敦",
    "heat_count": 23000,
    "heat_display": "2.3w浏览",
    "tag": "hot",
    "search_count": 1520
  }
]
```

## API 设计

### 公开接口

**GET /api/trending-searches**

无需登录，直接读 Redis 缓存返回。

响应：
```json
{
  "items": [
    {
      "rank": 1,
      "keyword": "毕业照跟拍 伦敦",
      "heat_display": "2.3w浏览",
      "tag": "hot"
    }
  ],
  "updated_at": "2026-04-01T15:00:00Z"
}
```

### 管理员接口

**POST /api/admin/trending/blacklist**
- 添加屏蔽词：`{ "keyword": "xxx" }`
- 立即触发一次缓存刷新

**DELETE /api/admin/trending/blacklist/{id}**
- 删除屏蔽词

**GET /api/admin/trending/blacklist**
- 查看所有屏蔽词

**POST /api/admin/trending/pin**
- 添加置顶词：`{ "keyword": "xxx", "display_heat": "1.2w浏览", "sort_order": 1, "expires_at": "2026-04-07T00:00:00Z" }`

**DELETE /api/admin/trending/pin/{id}**
- 删除置顶词

**GET /api/admin/trending/pin**
- 查看所有置顶词

## 搜索埋点

在现有搜索接口中增加写入逻辑。用户发起搜索时：

1. jieba 分词得到 tokens
2. 写入 search_logs 表（异步，不阻塞搜索响应）
3. 空搜索词、纯空格不记录

涉及的现有接口：
- `/api/forum/search`
- Flutter SearchBloc 中所有触发搜索的 API 调用

## Flutter 端

### 发现页热搜榜组件

- 调用 `GET /api/trending-searches`
- 渲染 Top10 列表，每条显示：排名 + 关键词 + 标签（热/升/NEW）+ 浏览量
- 点击某条 → 跳转搜索结果页，传入 keyword 作为搜索词

### API Endpoint 常量

在 `api_endpoints.dart` 中新增：
```dart
static const String trendingSearches = '/api/trending-searches';
```

### 数据模型

新增 `TrendingSearch` model：
```dart
class TrendingSearch extends Equatable {
  final int rank;
  final String keyword;
  final String heatDisplay;
  final String? tag; // "hot", "new", "up", null

  // fromJson / toJson / copyWith
}
```

## 依赖

- **jieba**：`pip install jieba`（后端分词）
- **Celery Beat**：定时任务调度（项目已有）
- **Redis**：缓存（项目已有）

## 数据清理

search_logs 表会持续增长，需要定期清理：
- 保留最近 30 天数据
- 超过 30 天的记录由 Celery 定时任务每天凌晨清理
