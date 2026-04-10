# Service Area / Radius Design

**Date:** 2026-04-10
**Status:** Approved

## Overview

为达人团队、服务和活动添加"服务区域"功能。达人在团队级别设置基地地址（经纬度）和默认服务半径，服务和活动默认继承团队设置，也可单独覆盖。用户浏览时可以看到是否在服务区域内，但不做硬拦截。

## Requirements

- 达人团队设置一次基地地址（经纬度）+ 默认服务半径
- 线下服务（`in_person` / `both`）：默认继承团队的经纬度和半径，可单独覆盖
- 线上服务：不限区域，`service_radius_km` 为 null
- 半径为预设档位：5km / 10km / 25km / 50km / 0（全城）
- 区域外用户能看到服务，但显示软提示，不拦截申请
- 服务和活动都支持

## Data Model

### Expert（达人团队）— 新增 2 个字段

```sql
ALTER TABLE experts
ADD COLUMN latitude DECIMAL(10, 8) DEFAULT NULL,
ADD COLUMN longitude DECIMAL(11, 8) DEFAULT NULL,
ADD COLUMN service_radius_km INTEGER DEFAULT NULL;
```

- Expert 已有 `location`（文本，如 "London"），新增经纬度作为精确坐标
- `service_radius_km`：团队默认服务半径，所有线下服务/活动继承此值
- `NULL` = 未设置，`0` = 全城不限，`5/10/25/50` = 半径（公里）

### TaskExpertService — 新增 1 个字段

```sql
ALTER TABLE task_expert_services
ADD COLUMN service_radius_km INTEGER DEFAULT NULL;
```

- `NULL` = 继承团队设置
- 显式设值（`0/5/10/25/50`）= 覆盖团队设置
- 已有 `latitude`、`longitude`、`location`、`location_type` 字段，无需新增
- 圆心 = 服务自身的 `latitude/longitude`，若为 null 则 fallback 到团队的

### Activity — 新增 3 个字段

```sql
ALTER TABLE activities
ADD COLUMN latitude DECIMAL(10, 8) DEFAULT NULL,
ADD COLUMN longitude DECIMAL(11, 8) DEFAULT NULL,
ADD COLUMN service_radius_km INTEGER DEFAULT NULL;
```

- Activity 目前只有文本 `location`，需要补上经纬度
- `service_radius_km` 同上，null = 继承团队设置
- 圆心 = 活动自身的 `latitude/longitude`，若为 null 则 fallback 到团队的

### Fallback 继承逻辑

对于任何服务或活动，获取"有效服务区域"的解析顺序：

```
有效经纬度 = service.latitude/longitude ?? expert.latitude/longitude
有效半径   = service.service_radius_km  ?? expert.service_radius_km
```

- 两级都为 null → 视为"未设置服务区域"，`within_service_area` 恒为 true
- `location_type = online` → 忽略服务区域，恒为 true

### Migration

文件：`backend/migrations/186_add_service_radius.sql`

## Backend API Changes

### Schema

**ExpertUpdate（团队编辑）：**

```python
latitude: Optional[condecimal(ge=-90, le=90, max_digits=10, decimal_places=8)] = None
longitude: Optional[condecimal(ge=-180, le=180, max_digits=11, decimal_places=8)] = None
service_radius_km: Optional[Literal[0, 5, 10, 25, 50]] = None
```

**TaskExpertServiceCreate / TaskExpertServiceUpdate：**

```python
service_radius_km: Optional[Literal[0, 5, 10, 25, 50]] = None
```

- `location_type = online` 时传了 `service_radius_km`，静默忽略（设为 null）
- `location_type = in_person / both` 但没设 `service_radius_km`，允许（null = 继承团队）

**ActivityCreate / ActivityUpdate：**

```python
latitude: Optional[condecimal(ge=-90, le=90, max_digits=10, decimal_places=8)] = None
longitude: Optional[condecimal(ge=-180, le=180, max_digits=11, decimal_places=8)] = None
service_radius_km: Optional[Literal[0, 5, 10, 25, 50]] = None
```

### 服务浏览接口（service_browse_routes.py）

扩展返回数据，新增字段：

```json
{
  "service_radius_km": 25,
  "distance_km": 12.3,
  "within_service_area": true
}
```

计算逻辑：
- 使用 fallback 继承逻辑解析有效经纬度和有效半径
- `distance_km`：用户经纬度到有效圆心的 haversine 距离
- `within_service_area`：
  - 有效半径为 null 或 0 → `true`
  - `location_type = online` → `true`
  - 否则 → `distance_km <= 有效半径`
- 用户未提供经纬度时，不返回 `distance_km` 和 `within_service_area`

**不做硬过滤**，区域外的服务依然返回。

### 活动浏览接口

同理，补上 `distance_km` 和 `within_service_area` 返回字段。

### 达人详情接口

返回 `latitude`、`longitude`、`service_radius_km` 字段（经纬度按已有隐私策略做模糊处理）。

### 服务详情 / 活动详情接口

返回解析后的 `service_radius_km`（已 fallback）+ `within_service_area`。

## Flutter Changes

### Models

**Expert**（达人团队模型）：

```dart
final double? latitude;        // 新增
final double? longitude;       // 新增
final int? serviceRadiusKm;    // 新增
```

**TaskExpertService**（`task_expert.dart`）：

```dart
final int? serviceRadiusKm;    // 新增
```

**Activity**（`activity.dart`）：

```dart
final double? latitude;        // 新增
final double? longitude;       // 新增
final int? serviceRadiusKm;    // 新增
```

### 达人团队设置 UI

在达人团队编辑页面（团队资料设置）中新增"基地地址"区域：

```
📍 基地地址：[LocationInputField]    ← 复用已有组件
📐 默认服务范围：
  [5km] [10km] [25km] [50km] [全城]  ← SegmentedButton
```

这是团队级别的一次性设置，所有线下服务/活动默认继承。

### 达人创建/编辑服务 UI（services_tab.dart）

当 `location_type` 为 `in_person` 或 `both` 时：

- 地点输入框：**默认填充团队基地地址**，达人可修改
- 服务半径选择器：显示"继承团队默认"选项 + 5/10/25/50/全城
- 选 `online` 时隐藏整块

### 活动创建 UI

将现有的纯文本 location 升级为 `LocationInputField`（复用服务的组件），并加服务半径选择器。默认继承团队设置。

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
| `baseAddress` | Base Address | 基地地址 | 基地地址 |
| `defaultServiceRadius` | Default Service Area | 默认服务范围 | 預設服務範圍 |
| `inheritTeamDefault` | Use team default | 使用团队默认 | 使用團隊預設 |

## Error Handling

- 后端：`location_type = online` 时传了 `service_radius_km`，静默忽略（设为 null），不报错
- 后端：`location_type = in_person/both` 但没设 `service_radius_km`，允许（null = 继承团队）
- 后端：团队和服务都没设经纬度时，不计算距离，`within_service_area` 不返回
- 前端：用户未授权定位时，`distance_km` 和 `within_service_area` 不返回，前端不显示区域提示

## Scope

### In Scope
- Expert 团队新增 `latitude` + `longitude` + `service_radius_km`
- TaskExpertService 新增 `service_radius_km`（经纬度已有）
- Activity 新增 `latitude` + `longitude` + `service_radius_km`
- 两级 fallback 继承逻辑（服务/活动 → 团队）
- 达人团队设置页面：基地地址 + 默认半径
- 达人创建/编辑服务和活动时选择/继承服务半径
- 浏览接口返回 `distance_km` + `within_service_area`
- 前端展示服务范围标签 + 区域外软提示

### Out of Scope
- 多区域支持（一个服务多个圆形区域）
- 多边形区域
- PostGIS 空间索引
- 硬拦截（区域外不可申请）
