# Service Area / Radius Design

**Date:** 2026-04-10
**Status:** Approved

## Overview

为达人服务和活动添加"服务区域"功能，让达人声明自己的线下服务范围（圆形半径）。用户浏览时可以看到是否在服务区域内，但不做硬拦截。

## Requirements

- 线下服务（`in_person` / `both`）：达人设置一个圆心（复用已有 location 经纬度）+ 服务半径
- 线上服务：不限区域，`service_radius_km` 为 null
- 半径为预设档位：5km / 10km / 25km / 50km / 0（全城）
- 区域外用户能看到服务，但显示软提示，不拦截申请
- 服务和活动都支持

## Data Model

### TaskExpertService — 新增 1 个字段

```sql
ALTER TABLE task_expert_services
ADD COLUMN service_radius_km INTEGER DEFAULT NULL;
```

- `NULL` = 未设置 或 线上服务（不限）
- `0` = 全城不限
- `5 / 10 / 25 / 50` = 服务半径（公里）
- 圆心 = 已有的 `latitude` + `longitude`

### Activity — 新增 3 个字段

```sql
ALTER TABLE activities
ADD COLUMN latitude DECIMAL(10, 8) DEFAULT NULL,
ADD COLUMN longitude DECIMAL(11, 8) DEFAULT NULL,
ADD COLUMN service_radius_km INTEGER DEFAULT NULL;
```

Activity 目前只有文本 `location`，需要补上经纬度以支持距离计算。`service_radius_km` 逻辑同 TaskExpertService。

### Migration

文件：`backend/migrations/186_add_service_radius.sql`

## Backend API Changes

### Schema

**TaskExpertServiceCreate / TaskExpertServiceUpdate：**

```python
service_radius_km: Optional[Literal[0, 5, 10, 25, 50]] = None
```

- `location_type = online` 时传了 `service_radius_km`，静默忽略（设为 null）
- `location_type = in_person / both` 但没设 `service_radius_km`，允许（null = 未设置）

**ActivityCreate / ActivityUpdate：**

```python
latitude: Optional[condecimal(ge=-90, le=90, max_digits=10, decimal_places=8)] = None
longitude: Optional[condecimal(ge=-180, le=180, max_digits=11, decimal_places=8)] = None
service_radius_km: Optional[Literal[0, 5, 10, 25, 50]] = None
```

### 服务浏览接口（service_browse_routes.py）

扩展返回数据，新增两个字段：

```json
{
  "service_radius_km": 25,
  "distance_km": 12.3,
  "within_service_area": true
}
```

计算逻辑：
- `distance_km`：用户经纬度到服务圆心的 haversine 距离（已有计算，只需暴露）
- `within_service_area`：
  - `service_radius_km` 为 null 或 0 → `true`
  - 否则 → `distance_km <= service_radius_km`
- 用户未提供经纬度时，不返回 `distance_km` 和 `within_service_area`

**不做硬过滤**，区域外的服务依然返回。

### 活动浏览接口

同理，补上 `distance_km` 和 `within_service_area` 返回字段。

### 服务详情 / 活动详情接口

返回 `service_radius_km` 字段，供前端展示。

## Flutter Changes

### Models

**TaskExpertService**（`task_expert.dart`）：

```dart
final int? serviceRadiusKm;  // nullable
```

**Activity**（`activity.dart`）：

```dart
final double? latitude;       // 新增
final double? longitude;      // 新增
final int? serviceRadiusKm;   // 新增
```

### 达人创建/编辑服务 UI（services_tab.dart）

当 `location_type` 为 `in_person` 或 `both` 时，在 location 输入框下方显示服务半径选择器：

```
📍 服务地点：[LocationInputField]

📐 服务范围：
  [5km] [10km] [25km] [50km] [全城]    ← SegmentedButton
```

选 `online` 时隐藏整块。

### 活动创建 UI

将现有的纯文本 location 升级为 `LocationInputField`（复用服务的组件），并加服务半径选择器。

### 服务浏览 / 详情页

- **服务卡片**：显示"服务范围 25km"标签
- **服务详情页**：显示服务区域信息
- **区域外提示**：当 `within_service_area = false` 时，显示软提示 banner："该服务可能不在您的区域内，建议联系达人确认"
- 不拦截申请流程

### 活动浏览 / 详情页

同理，展示服务范围 + 区域外提示。

## Localization

| key | en | zh | zh_Hant |
|---|---|---|---|
| `serviceRadius` | Service Area | 服务范围 | 服務範圍 |
| `serviceRadiusKm` | {radius}km | {radius}公里 | {radius}公里 |
| `serviceRadiusWholeCity` | Whole City | 全城 | 全城 |
| `outsideServiceArea` | This service may not cover your area. Contact the expert to confirm. | 该服务可能不在您的区域内，建议联系达人确认 | 該服務可能不在您的區域內，建議聯繫達人確認 |
| `selectServiceRadius` | Select service area | 选择服务范围 | 選擇服務範圍 |

## Error Handling

- 后端：`location_type = online` 时传了 `service_radius_km`，静默忽略（设为 null），不报错
- 后端：`location_type = in_person/both` 但没设 `service_radius_km`，允许（null = 未设置，不强制）
- 前端：用户未授权定位时，`distance_km` 和 `within_service_area` 不返回，前端不显示区域提示

## Scope

### In Scope
- TaskExpertService + Activity 新增 `service_radius_km` 字段
- Activity 补上 `latitude` + `longitude`
- 达人创建/编辑服务和活动时选择服务半径
- 浏览接口返回 `distance_km` + `within_service_area`
- 前端展示服务范围标签 + 区域外软提示

### Out of Scope
- 多区域支持（一个服务多个圆形区域）
- 多边形区域
- PostGIS 空间索引
- 硬拦截（区域外不可申请）
- 达人团队级别的基地地址
