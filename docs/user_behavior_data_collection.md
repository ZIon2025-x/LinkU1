# 用户行为数据收集完善说明

## 📊 数据收集现状

### ✅ 已收集的数据

1. **基础交互数据**
   - 交互类型：view, click, apply, skip, accept, complete
   - 交互时间
   - 浏览时长（duration_seconds）

2. **设备信息**
   - 设备类型：mobile, desktop, tablet
   - 操作系统：Windows, macOS, iOS, Android, Linux
   - 操作系统版本
   - 浏览器：Chrome, Safari, Firefox, Edge, Opera
   - 浏览器版本
   - 屏幕尺寸（宽度、高度）
   - 是否支持触摸

3. **推荐相关数据**
   - 是否为推荐任务（is_recommended）
   - 推荐算法（recommendation_algorithm）
   - 匹配分数（match_score）
   - 来源页面（source_page）

4. **上下文信息**
   - 任务在列表中的位置（list_position）
   - 来源页面（tasks_page, task_detail等）

## 🔧 技术实现

### 前端设备检测

**文件**: `frontend/src/utils/deviceDetector.ts`

**功能**:
- ✅ 准确识别设备类型（mobile/tablet/desktop）
- ✅ 检测操作系统和版本
- ✅ 检测浏览器和版本
- ✅ 获取屏幕尺寸
- ✅ 检测触摸支持

**使用示例**:
```typescript
import { getDeviceInfo, getDeviceType } from './utils/deviceDetector';

// 获取完整设备信息
const deviceInfo = getDeviceInfo();
// {
//   type: 'mobile',
//   os: 'iOS',
//   osVersion: '17.0',
//   browser: 'Safari',
//   browserVersion: '17.0',
//   screenWidth: 390,
//   screenHeight: 844,
//   isTouchDevice: true,
//   userAgent: '...'
// }

// 获取简化的设备类型
const deviceType = getDeviceType(); // 'mobile' | 'tablet' | 'desktop'
```

### API调用

**文件**: `frontend/src/api.ts`

**改进**:
- ✅ 自动检测设备类型（如果未提供）
- ✅ 自动收集设备详细信息
- ✅ 支持传递额外metadata

**使用示例**:
```typescript
// 自动检测设备类型
recordTaskInteraction(
  taskId,
  'click',
  undefined,
  undefined, // 自动检测
  isRecommended,
  {
    recommendation_algorithm: 'hybrid',
    match_score: 0.85,
    source_page: 'tasks_page',
    list_position: 3
  }
);
```

### 后端数据存储

**文件**: `backend/app/user_behavior_tracker.py`

**改进**:
- ✅ 支持接收metadata参数
- ✅ 自动合并推荐信息到metadata
- ✅ 设备信息存储在metadata中

**数据模型**: `UserTaskInteraction`
```python
{
    "id": 1,
    "user_id": "12345678",
    "task_id": 123,
    "interaction_type": "click",
    "interaction_time": "2025-01-27T10:00:00Z",
    "duration_seconds": null,
    "device_type": "mobile",
    "metadata": {
        "is_recommended": true,
        "recommendation_algorithm": "hybrid",
        "match_score": 0.85,
        "source_page": "tasks_page",
        "list_position": 3,
        "device_info": {
            "os": "iOS",
            "os_version": "17.0",
            "browser": "Safari",
            "browser_version": "17.0",
            "screen_width": 390,
            "screen_height": 844,
            "is_touch_device": true
        }
    }
}
```

## 📈 数据收集覆盖范围

### 移动端（手机）数据收集

✅ **已完善**:
- 设备类型识别（mobile/tablet/desktop）
- 操作系统检测（iOS/Android）
- 操作系统版本
- 浏览器检测
- 屏幕尺寸
- 触摸支持

✅ **收集位置**:
- 任务浏览（view）
- 任务点击（click）
- 任务申请（apply）
- 任务跳过（skip）

### 数据完整性

| 数据类型 | 收集状态 | 说明 |
|---------|---------|------|
| 基础交互 | ✅ 完善 | view, click, apply, skip |
| 设备类型 | ✅ 完善 | mobile, tablet, desktop |
| 操作系统 | ✅ 完善 | iOS, Android, Windows, macOS |
| 浏览器 | ✅ 完善 | Chrome, Safari, Firefox, Edge |
| 屏幕尺寸 | ✅ 完善 | width, height |
| 触摸支持 | ✅ 完善 | is_touch_device |
| 推荐信息 | ✅ 完善 | is_recommended, algorithm, score |
| 上下文信息 | ✅ 完善 | source_page, list_position |

## 🎯 使用场景

### 1. 推荐系统优化
- 分析不同设备类型的推荐效果
- 优化移动端推荐算法
- 根据屏幕尺寸调整推荐数量

### 2. 用户体验优化
- 分析移动端用户行为模式
- 优化移动端界面布局
- 根据设备类型调整功能

### 3. 数据分析
- 设备类型分布统计
- 操作系统版本分析
- 浏览器兼容性分析
- 屏幕尺寸分布

## 📝 数据查询示例

### 查询移动端用户行为
```sql
SELECT 
    interaction_type,
    COUNT(*) as count,
    AVG(duration_seconds) as avg_duration
FROM user_task_interactions
WHERE device_type = 'mobile'
    AND interaction_time >= NOW() - INTERVAL '7 days'
GROUP BY interaction_type;
```

### 查询设备信息
```sql
SELECT 
    metadata->>'device_info'->>'os' as os,
    metadata->>'device_info'->>'browser' as browser,
    COUNT(*) as count
FROM user_task_interactions
WHERE metadata->>'device_info' IS NOT NULL
GROUP BY os, browser;
```

### 查询推荐效果（按设备类型）
```sql
SELECT 
    device_type,
    COUNT(*) FILTER (WHERE metadata->>'is_recommended' = 'true') as recommended_count,
    COUNT(*) as total_count,
    ROUND(
        100.0 * COUNT(*) FILTER (WHERE metadata->>'is_recommended' = 'true') / COUNT(*),
        2
    ) as recommendation_rate
FROM user_task_interactions
WHERE interaction_type = 'click'
    AND interaction_time >= NOW() - INTERVAL '7 days'
GROUP BY device_type;
```

## ✅ 总结

用户行为数据收集已经**完善**，特别是移动端（手机）的数据：

1. ✅ **设备检测完善** - 准确识别mobile/tablet/desktop
2. ✅ **详细信息收集** - OS、浏览器、屏幕尺寸等
3. ✅ **自动收集** - 无需手动指定，自动检测和收集
4. ✅ **数据完整** - 覆盖所有交互类型
5. ✅ **推荐数据** - 完整的推荐相关信息
6. ✅ **上下文信息** - 来源页面、列表位置等

所有数据都存储在`user_task_interactions`表的`metadata`字段中，便于后续分析和使用。
