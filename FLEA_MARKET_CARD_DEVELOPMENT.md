# 跳蚤市场开发文档

> **文档更新时间**: 2025-01-20  
> **前端实现状态**: ✅ 已完成（所有前端功能已实现）  
> **后端实现状态**: ❌ 未开始（数据库和API待实现）

## 📖 文档导航

**如果你是后端开发者** → 重点关注以下章节：
- **数据库设计**：第5节（表结构、字段说明、迁移文件）
- **后端API设计**：第6节（所有API的详细说明）
- **后端任务清单**：第10.2节（开发任务清单）

**后端实现顺序建议**：
1. **数据库迁移**：迁移文件1/2/3（用户表字段、商品表、购买申请表）
2. **基础API**：列表 / 上传 / 编辑 / my-purchases
3. **购买流程API**：direct-purchase + purchase-request + accept-purchase
4. **自动删除定时任务**：实现商品自动删除逻辑

**如果你是前端开发者** → 重点关注以下章节：
- **技术实现方案**：第2节（架构设计、组件说明）
- **二手交易页面功能**：第4节（数据流、页面布局）
- **前端实现现状**：第9节（组件结构、状态管理）
- **前端任务清单**：第10.1节（开发任务清单）

**如果你是QA测试** → 重点关注以下章节：
- **测试场景清单**：第13节（商品生命周期测试、购买流程测试、权限测试等）
- **API设计**：第6节（了解API行为和错误响应）
- **状态机规则**：第5.3.4节（了解商品状态流转规则）

**快速查找**：
- 购买流程设计 → 第6.8节
- 数据库表结构 → 第5.3节
- 字段映射规则 → 第4.4节
- 图片存储说明 → 第5.3.4节
- API设计规范 → 第6.0节（响应格式、错误码、幂等性）

## 📋 当前实现状态总览

### ✅ 前端已完成功能

#### 核心组件
- ✅ **FleaMarketCard组件**：已实现并集成到Tasks.tsx，支持视频背景、响应式设计、点击跳转
- ✅ **FleaMarketPage页面**：完整的跳蚤市场页面，包含所有核心功能

#### 页面功能
- ✅ **页面布局和导航**：完整的导航栏、顶部横幅、搜索筛选、商品列表
- ✅ **商品列表展示**：网格布局，支持无限滚动加载
- ✅ **商品管理**：上传、编辑、删除（权限控制，前端已实现）
- ✅ **搜索和筛选**：
  - 关键词搜索（300ms防抖优化）
  - 分类筛选（10个预设分类）
  - 城市/地点筛选
- ✅ **无限滚动**：自动加载更多商品（距离底部200px触发）
- ✅ **须知弹窗**：首次进入显示，需勾选同意（当前使用localStorage，待后端API）
- ✅ **我的闲置弹窗**：查看发布的商品和购买的商品（两个标签页）
- ✅ **图片上传**：支持多张图片上传（最多5张），使用现有图片上传API

#### 技术实现
- ✅ **性能优化**：
  - React优化（React.memo、useCallback、useMemo）
  - 滚动节流（useThrottledCallback，100ms）
  - CSS优化（GPU加速、content-visibility、contain等）
- ✅ **国际化**：完整的中英文支持（所有文本使用翻译系统）
- ✅ **SEO优化**：使用SEOHead组件设置meta标签
- ✅ **响应式设计**：支持移动端和桌面端

#### 集成状态
- ✅ **Tasks.tsx集成**：FleaMarketCard已集成到任务列表页面
  - 当选择"Second-hand & Rental"任务类型时，在列表第一个位置显示固定卡片
  - 点击卡片跳转到 `/${lang}/flea-market` 路由
  - 使用TaskType枚举常量，避免硬编码

### ❌ 后端待实现功能

#### 数据库
- ❌ **数据库表创建**：
  - `flea_market_items` 表（商品表）
  - `users` 表添加 `flea_market_notice_agreed_at` 字段
  - `flea_market_purchase_requests` 表（**必建**，购买申请表，用于议价购买流程）
- ❌ **数据库迁移**：Alembic迁移文件
- ❌ **ORM模型**：SQLAlchemy模型定义

#### 后端API
- ❌ **商品列表API**：`GET /api/flea-market/items`（分页、搜索、筛选）
- ❌ **商品详情API**：`GET /api/flea-market/items/:id`（自动增加浏览量）
- ❌ **商品上传API**：`POST /api/flea-market/items`
- ❌ **商品编辑/删除API**：`PUT /api/flea-market/items/:id`
- ❌ **商品刷新API**：`POST /api/flea-market/items/:id/refresh`（重置自动删除计时器）
- ❌ **须知同意API**：`PUT /api/flea-market/agree-notice`
- ❌ **我的购买商品API**：`GET /api/flea-market/my-purchases`
- ❌ **购买流程API**：
  - `POST /api/flea-market/items/:id/direct-purchase`（直接购买，无议价，直接创建任务）
  - `POST /api/flea-market/items/:id/purchase-request`（议价申请，创建购买申请记录）
  - `POST /api/flea-market/items/:id/accept-purchase`（接受购买，创建任务并更新申请状态）

### ⏳ 待完成功能（前后端协作）
- **购买流程**：直接购买（无议价，直接创建任务）或议价购买（走申请表流程）
- **商品详情页**：独立的商品详情页面（前端路由已预留）
- **图片路径说明**：商品创建任务后，图片路径不变（直接复制URL数组，不移动文件）

## 📝 实现总结

### 已完成的工作

#### 前端实现（100%完成）
1. **FleaMarketCard组件** (`frontend/src/components/FleaMarketCard.tsx`)
   - ✅ 视频背景展示（`/static/flea.mp4`）
   - ✅ 响应式设计（移动端和桌面端）
   - ✅ 国际化支持（中英文）
   - ✅ 点击跳转到跳蚤市场页面
   - ✅ 特殊视觉标识（绿色主题、✨标识）

2. **Tasks.tsx集成**
   - ✅ 引入TaskType枚举
   - ✅ 条件渲染固定卡片（当选择"Second-hand & Rental"时）
   - ✅ 点击处理逻辑（跳转到跳蚤市场页面）
   - ✅ 性能优化（useMemo优化displayTasks）

3. **FleaMarketPage页面** (`frontend/src/pages/FleaMarketPage.tsx`)
   - ✅ 完整的页面布局（导航栏、横幅、搜索、列表）
   - ✅ 商品列表展示（网格布局、无限滚动）
   - ✅ 商品管理功能（上传、编辑、删除）
   - ✅ 搜索和筛选（关键词搜索、分类筛选、城市筛选）
   - ✅ 须知弹窗（首次进入显示）
   - ✅ 我的闲置弹窗（两个标签页）
   - ✅ 性能优化（React.memo、useCallback、useMemo、滚动节流）
   - ✅ CSS性能优化（GPU加速、content-visibility等）
   - ✅ 国际化支持（所有文本使用翻译系统）
   - ✅ SEO优化（SEOHead组件）

4. **API调用（前端已实现，等待后端）**
   - ✅ `GET /api/flea-market/items` - 商品列表（分页、搜索、筛选）
   - ✅ `POST /api/flea-market/items` - 商品上传
   - ✅ `PUT /api/flea-market/items/:id` - 商品编辑/删除
   - ⏳ `PUT /api/flea-market/agree-notice` - 须知同意（前端已调用，后端待实现）
   - ⏳ `GET /api/flea-market/my-purchases` - 我的购买商品（前端已调用，后端待实现）

### 待完成的工作

#### 后端实现（0%完成）
1. **数据库**
   - ❌ 创建 `flea_market_items` 表
   - ❌ 更新 `users` 表（添加 `flea_market_notice_agreed_at` 字段）
   - ❌ **必建**：创建 `flea_market_purchase_requests` 表（用于议价购买流程，记录购买申请历史）
   - ❌ 数据库迁移文件（Alembic）

2. **ORM模型**
   - ❌ `FleaMarketItem` 模型定义
   - ❌ Pydantic schema（JSON字段序列化/反序列化）

3. **后端API**
   - ❌ 商品列表API（分页、搜索、筛选）
   - ❌ 商品详情API（自动增加浏览量）
   - ❌ 商品上传API
   - ❌ 商品编辑/删除API
   - ❌ 须知同意API
   - ❌ 我的购买商品API
   - ❌ 购买流程API（直接购买、议价申请、接受购买）

4. **业务逻辑**
   - ❌ 商品到任务的转换逻辑
   - ❌ 图片文件管理（存储路径、自动删除）
   - ❌ 权限验证（仅商品所有者可编辑/删除）

## 1. 功能概述

跳蚤市场是一个专门的二手交易平台，用户可以在该页面上传、浏览、搜索和管理二手交易商品。

**主要功能**：
- ✅ 商品列表展示（网格布局，无限滚动加载）
- ✅ 商品搜索和筛选（关键词搜索、分类筛选）
- ✅ 商品上传（支持多张图片，最多5张）
- ✅ 商品编辑和删除（仅限商品所有者）
- ✅ 城市选择（使用固定城市列表）
- ✅ 跳蚤市场须知弹窗（首次进入时显示，需勾选同意）
- ✅ 我的闲置管理（查看发布的商品和购买的商品）
- ✅ 性能优化（React.memo、useCallback、useMemo、滚动节流、CSS优化）
- ✅ 国际化支持（中英文）
- ✅ SEO优化
- ✅ 导航栏（与首页一致）

**页面路由**：`/${lang}/flea-market`（需带语言前缀）

## 2. 技术实现方案

### 2.1 架构设计

```
Tasks.tsx (任务列表页面)
  ├── CategoryIcons (任务类型选择器)
  ├── FleaMarketCard (固定卡片组件) [新增]
  └── TaskCard (普通任务卡片)
        └── 点击跳转到任务详情

FleaMarketPage.tsx (二手交易页面) [新增]
  ├── 商品列表展示
  ├── 商品上传表单
  └── 商品管理功能
```

### 2.2 核心组件

#### 2.2.1 FleaMarketCard 组件 ✅ 已实现
- **位置**: `frontend/src/components/FleaMarketCard.tsx`
- **功能**: 显示固定的跳蚤市场卡片
- **样式**: 
  - 视频背景（`/static/flea.mp4`）
  - 响应式设计（支持移动端和桌面端）
  - 特殊标识（绿色主题、✨标识、任务类型标签）
  - 渐变遮罩层和毛玻璃效果
- **交互**: 点击后跳转到 `/${lang}/flea-market` 路由（需带语言前缀）
- **集成**: 已集成到 `Tasks.tsx`，当选择"Second-hand & Rental"任务类型时显示

#### 2.2.2 FleaMarketPage 组件
- **位置**: `frontend/src/pages/FleaMarketPage.tsx` ✅ **已实现**
- **功能**: 二手交易商品展示和管理页面
- **主要功能**:
  - ✅ 商品列表展示（网格布局，无限滚动）
  - ✅ 商品上传表单（支持多图上传，城市选择）
  - ✅ 商品编辑和删除（权限控制）
  - ✅ 商品搜索和筛选（关键词搜索、分类筛选）
  - ✅ 跳蚤市场须知弹窗
  - ✅ 我的闲置管理弹窗
  - ✅ 导航栏（语言切换、通知、用户菜单）
  - ✅ 性能优化（React优化、CSS优化）

### 2.3 路由配置

在 `App.tsx` 中添加新路由：

**URL规范**：
- **列表页**: `/${lang}/flea-market`
- **详情页**: `/${lang}/flea-market/:id`（未来扩展）

```typescript
<Route path="/:lang/flea-market" element={<FleaMarketPage />} />
<Route path="/:lang/flea-market/:id" element={<FleaMarketDetailPage />} /> // 未来扩展
```

**注意**: 
- 路由定义使用 `/:lang/...` 模式字符串，`lang` 从 `useParams()` 或上层路由获取
- 导航时使用 `navigate(\`/${language}/flea-market\`)` 动态拼接语言前缀
- 统一使用 `/flea-market` 作为路径前缀，避免出现 `/items/:id` 等不一致的路径
- 示例：`<Route path="/:lang/flea-market" element={<FleaMarketPage />} />`

### 2.4 集成逻辑

在 `Tasks.tsx` 中：
1. 检测当前选中的任务类型是否为 `TaskType.SecondHandAndRental`（使用枚举常量，见3.1节）
2. 如果是，在 `filteredTasks` 数组的第一个位置插入固定卡片
3. 固定卡片使用特殊的标识（如 `id: 'flea-market-card'`）以区分普通任务

**任务类型枚举定义**：
```typescript
// 建议在 frontend/src/constants/taskTypes.ts 中定义
export enum TaskType {
  Housekeeping = 'Housekeeping',
  CampusLife = 'Campus Life',
  SecondHandAndRental = 'Second-hand & Rental',
  ErrandRunning = 'Errand Running',
  SkillService = 'Skill Service',
  SocialHelp = 'Social Help',
  Transportation = 'Transportation',
  PetCare = 'Pet Care',
  LifeConvenience = 'Life Convenience',
  Other = 'Other'
}

// 使用方式
if (filters.type === TaskType.SecondHandAndRental) {
  // 显示固定卡片
}
```

**重要**: 判断类型/传值统一使用枚举常量，避免字符串硬编码导致的拼写错误。

## 3. 实现细节

### 3.1 固定卡片数据结构

```typescript
import { TaskType } from '../constants/taskTypes';
import { useLanguage } from '../contexts/LanguageContext';

// 在组件中使用
const { t } = useLanguage();

const fleaMarketCard = {
  id: 'flea-market-card', // 特殊ID，用于识别固定卡片
  title: t('fleaMarket.cardTitle'), // 使用翻译：'跳蚤市场' / 'Flea Market'
  description: t('fleaMarket.cardDescription'), // 使用翻译：'在这里可以上传和浏览二手交易商品'
  task_type: TaskType.SecondHandAndRental, // 使用枚举，避免拼写错误
  location: 'Online',
  task_level: 'normal',
  // ... 其他必要字段
};
```

**翻译key建议**（在 `locales/zh.json` 和 `locales/en.json` 中添加）：
```json
{
  "fleaMarket": {
    "cardTitle": "跳蚤市场",
    "cardDescription": "在这里可以上传和浏览二手交易商品"
  }
}
```

### 3.2 条件渲染逻辑

```typescript
// 在Tasks.tsx中
import { TaskType } from '../constants/taskTypes';

const displayTasks = useMemo(() => {
  // 如果选择了二手任务类型，在第一个位置插入固定卡片
  if (filters.type === TaskType.SecondHandAndRental) {
    return [fleaMarketCard, ...filteredTasks];
  }
  return filteredTasks;
}, [filteredTasks, filters.type]);
```

### 3.3 点击处理

```typescript
// 从路由参数或语言上下文获取当前语言
const { lang } = useParams<{ lang: string }>(); // 或使用 useLanguage hook
const language = lang || 'en';

const handleCardClick = (taskId: string | number) => {
  if (taskId === 'flea-market-card') {
    // 跳转到二手交易页面
    navigate(`/${language}/flea-market`);
  } else {
    // 正常处理任务详情
    handleViewTask(taskId);
  }
};
```

**注意**：`language` 变量需要从路由参数（`useParams`）或语言上下文（`useLanguage`）获取，确保路由跳转时保留语言前缀。

## 4. 二手交易页面功能

### 4.1 数据流设计

**页面加载流程**：
1. 组件挂载时调用 `GET /api/flea-market/items` 获取商品列表
2. 支持分页：`GET /api/flea-market/items?page=1&pageSize=20`
3. 支持搜索和筛选：`GET /api/flea-market/items?keyword=xxx&category=yyy&page=1&pageSize=20`
4. 只显示 `status='active'` 的商品（在售商品）

**商品展示策略**：
- **普通跳蚤市场列表**：默认只展示 `status='active'` 的商品（在售商品），不展示已售出或已删除的商品
- **我的购买/我收的闲置**：在"我的闲置"弹窗的"我收的闲置"标签页中，会展示 `status='sold'` 的商品（已售出且已创建任务的商品）
- **已售商品标识**：已售出商品在列表中会显示"已售出"标记，但不会出现在普通商品列表中

**数据更新流程**：
- **上传成功**: 重新请求列表（`GET /api/flea-market/items`）或本地追加新商品
- **编辑成功**: 重新请求列表或本地更新对应商品
- **删除成功**: 更新商品状态为 `deleted`，重新请求列表或本地移除对应商品
- **售出成功**: 更新商品状态为 `sold`，在tasks表中创建任务，重新请求列表或本地移除对应商品

**前端参数映射**：
```typescript
// 搜索框输入 -> keyword 参数
// 分类选择 -> category 参数
// 分页 -> page, pageSize 参数
const params = {
  page: currentPage,
  pageSize: 20,
  keyword: searchKeyword || undefined,
  category: selectedCategory || undefined,
  status: 'active'  // 只显示在售商品（后端默认筛选）
};
```

### 4.2 页面布局 ✅ 已实现

**实际页面结构**：

```
┌─────────────────────────────────────────────────────────┐
│  导航栏（Header）                                        │
│  ├── Logo                                              │
│  ├── 语言切换器（LanguageSwitcher）                     │
│  ├── 通知按钮（NotificationButton）                    │
│  └── 用户菜单（HamburgerMenu）                         │
├─────────────────────────────────────────────────────────┤
│  顶部横幅区域（HeroSection）                             │
│  ├── 🛍️ 跳蚤市场 - 二手交易平台                         │
│  ├── 页面描述                                           │
│  └── [出闲置] [我的闲置] 按钮                           │
├─────────────────────────────────────────────────────────┤
│  搜索和筛选区域（FiltersSection）                       │
│  ├── 搜索框（Search，300ms防抖）                        │
│  └── 分类筛选（Select）                                 │
├─────────────────────────────────────────────────────────┤
│  商品列表区域（ItemsSection）                            │
│  ┌────────┐ ┌────────┐ ┌────────┐                   │
│  │ 商品卡片 │ │ 商品卡片 │ │ 商品卡片 │                   │
│  │ 图片    │ │ 图片    │ │ 图片    │                   │
│  │ 标题    │ │ 标题    │ │ 标题    │                   │
│  │ 价格    │ │ 价格    │ │ 价格    │                   │
│  │ 编辑/删除│ │ 编辑/删除│ │ 编辑/删除│                   │
│  └────────┘ └────────┘ └────────┘                   │
│  ...（无限滚动加载）                                    │
└─────────────────────────────────────────────────────────┘
```

**弹窗组件**：
- 上传/编辑商品模态框（UploadModal）
- 跳蚤市场须知弹窗（NoticeModal）
- 我的闲置弹窗（MyItemsModal，包含两个标签页）

### 4.3 商品上传表单 ✅ 已实现

**表单字段**（实际实现）：
- ✅ 商品名称（必填，Input组件）
- ✅ 商品描述（必填，TextArea组件）
- ✅ 价格（必填，InputNumber组件，单位：GBP，必须大于0）
- ✅ 商品图片（支持多张，最多5张，Upload组件）
  - 先上传图片获取URL，再提交表单
  - 支持预览和删除
- ✅ 交易地点（必填，Select组件，城市下拉选择）
  - 使用固定的CITIES常量（从Tasks.tsx导入）
  - 支持搜索过滤城市
  - 默认值为"Online"
- ✅ 商品分类（可选，Select下拉选择）
- ❌ 联系方式（**前端不显示也不获取**，只在任务进行中后在聊天框发送）

**表单验证**：
- ✅ 商品名称、描述、价格为必填项
- ✅ 价格必须大于0
- ✅ 图片最多5张
- ✅ 提交时显示loading状态，防止重复提交

**编辑功能**：
- ✅ 点击商品卡片的编辑按钮打开表单
- ✅ 表单预填充商品现有数据
- ✅ 支持修改所有字段

### 4.4 商品数据结构

**商品数据结构**（flea_market_items表）：
```typescript
interface FleaMarketItem {
  id: string | number;  // 跳蚤市场商品ID格式：S + 数字（如：S1234），数据库存储为整数，返回给前端时格式化为S开头
  title: string;              // 商品名称
  description: string;         // 商品描述
  price: number;              // 标价（GBP）
  currency: 'GBP';            // 货币类型，固定为GBP
  images: string[];           // 图片URL数组（注意：不是File对象）
  location?: string;          // 线下交易地点或"Online"
  category?: string;          // 商品分类
  // contact?: string;  // 预留字段，本期不使用，所有API都不返回此字段
  status: 'active' | 'sold' | 'deleted';  // 商品状态
  seller_id: string;          // 卖家ID（提供商品的人）
  created_at: string;         // ISO 8601格式，例如 '2025-11-19T12:00:00Z'
  updated_at: string;         // 更新时间
}
```

**任务数据结构**（交易达成后在tasks表中创建）：
```typescript
import { TaskType } from '../constants/taskTypes';

// 注意：以下为字段映射规则，基于现有 tasks 表结构
// tasks 表已包含以下字段：images (TEXT), base_reward (DECIMAL), agreed_reward (DECIMAL), reward (FLOAT)
// 注意：跳蚤市场相关的所有ID格式为 S + 数字（如：S1234），包括商品ID、购买申请ID、任务ID
interface Task {
  id: string | number;  // 跳蚤市场任务ID格式：S + 数字（如：S1234），数据库存储为整数，返回给前端时格式化为S开头
  title: string;              // 商品名称（从flea_market_items.title复制）
  description: string;         // 合并字段：商品描述 + 商品分类
                                // 格式："{description}\n\n分类：{category}"
                                // 注意：不包含联系方式，联系方式只在任务进行中后在聊天框发送
  reward: number;             // 任务金额（从flea_market_items.price复制，或使用agreed_reward的值）
  base_reward: number;        // 商品原始标价（从flea_market_items.price复制）
  agreed_reward?: number;     // 最终成交价（如果有议价，存储议价后的价格；否则为NULL）
  currency: 'GBP';            // 货币类型
  images: string[];           // 图片URL数组（从flea_market_items.images复制）
  location: string;           // 任务城市（从flea_market_items.location复制，如果为空则默认为"Online"）
  task_type: TaskType.SecondHandAndRental;  // 固定任务类型（使用枚举）
  poster_id: string;          // 买家ID（付钱的人）
  taker_id: string;           // 卖家ID（获得钱的人，从flea_market_items.seller_id复制）
  status: 'in_progress';      // 直接进入进行中状态
  is_flexible: 1;             // 灵活时间模式（无截止日期）
  deadline: null;             // 无截止日期
  created_at: string;         // 任务创建时间（交易达成时间）
  // ... 其他任务字段（以现有 tasks 表结构为准）
}
```

**字段映射关系**（商品表 → 任务表）：
| 商品表字段 | 任务表字段 | 说明 |
|-----------|-----------|------|
| `title` | `title` | 商品名称直接作为任务标题 |
| `description` + `category` | `description` | 合并为任务描述，格式：`"{description}\n\n分类：{category}"`（**不包含联系方式**） |
| `location` | `location` | 交易地点作为任务城市（如果为空则默认为"Online"） |
| `price` 或 议价后的价格 | `reward` | 任务金额（直接购买时使用商品标价，议价购买时使用最终成交价） |
| `price` | `base_reward` | 商品原始标价 |
| 议价后的价格 | `agreed_reward` | 最终成交价（如果有议价，否则为NULL） |
| `images` | `images` | 图片URL数组直接复制 |
| `seller_id` | `taker_id` | 卖家ID作为任务接收者 |
| 买家ID | `poster_id` | 买家ID作为任务发布者 |

**任务描述合并规则**：
- 如果 `category` 存在：`"{description}\n\n分类：{category}"`
- 如果 `category` 为空：`"{description}"`
- **注意**：**不包含联系方式字段**，联系方式只在任务进入 `in_progress` 状态后，由卖家在任务聊天框中发送

**字段说明**：
- **商品表**：`seller_id` = 卖家（提供商品的人）
- **任务表**：`poster_id` = 买家（付钱的人），`taker_id` = 卖家（获得钱的人）
- `currency`: 使用字面量类型 `'GBP'`，确保不会传入其他货币类型
- `images`: 存储的是图片URL字符串数组，不是File对象
- `status`: 商品状态独立于任务状态
- **联系方式字段**：`contact` 字段在商品表中保留（**预留字段，本期不使用**）
  - **前端不显示也不获取**：上传/编辑表单中不包含联系方式字段
  - **后端应忽略**：后端API不应读取或写入 `contact` 字段
  - **不在任务描述中包含**：创建任务时不在 `description` 中包含联系方式
  - **只在任务聊天中发送**：任务进入 `in_progress` 状态后，卖家可以在任务聊天框中发送联系方式给买家
  - **未来用途**：此字段预留用于内部后台管理或客服手工录入（如有需要）

**图片路径处理说明**：
- **商品创建任务后，图片路径不会变化**：
  - 图片文件位置不变：仍保留在 `uploads/flea_market/{item_id}/` 目录
  - 图片URL直接复制：任务表的 `images` 字段直接复制商品表的 `images` 字段（URL数组）
  - 不移动或复制文件：只复制URL引用，不进行文件操作
  - 共享同一份文件：商品和任务引用相同的图片文件
- **优势**：
  - 节省存储空间（不重复存储）
  - 简化管理（文件位置不变）
  - 保持一致性（商品和任务使用相同的图片）
- **⚠️ 存储空间优化**：
  - **任务完成后清理**：任务完成后超过3天，系统会自动清理任务图片（参考 `cleanup_completed_tasks_files`）
  - **同时清理商品图片**：清理任务图片时，需要同时清理关联的商品图片目录（`uploads/flea_market/{item_id}/`）
  - **实现方式**：在 `cleanup_completed_tasks_files` 中，通过 `flea_market_items.sold_task_id` 找到关联的商品，清理商品图片目录
  - **避免永久占用**：这样可以避免已售出商品的图片永久占用存储空间，任务完成后3天即可清理

## 5. 数据库设计

### 5.1 用户表字段更新

**用户表（users）需要新增字段**：

| 字段名 | 类型 | 约束 | 说明 |
|--------|------|------|------|
| flea_market_notice_agreed_at | TIMESTAMPTZ | NULL | 用户同意跳蚤市场须知的时间（UTC） |

**字段说明**：
- 当用户首次进入跳蚤市场页面并勾选同意须知后，记录同意时间
- 如果该字段为 `NULL`，表示用户尚未同意须知，需要显示须知弹窗
- 如果该字段有值，表示用户已同意须知，不再显示弹窗
- 该字段用于替代前端 `localStorage` 的存储方式，确保数据持久化和跨设备同步

**SQL DDL（用户表字段更新）**：
```sql
-- 为用户表添加跳蚤市场须知同意时间字段
ALTER TABLE users 
ADD COLUMN flea_market_notice_agreed_at TIMESTAMPTZ NULL;

-- 添加索引（可选，如果需要按同意时间查询）
CREATE INDEX idx_users_flea_market_notice_agreed_at ON users(flea_market_notice_agreed_at);
```

**ORM模型更新（SQLAlchemy）**：
```python
# backend/app/models.py

class User(Base):
    """用户表"""
    __tablename__ = "users"
    
    # ... 现有字段 ...
    
    # 跳蚤市场须知同意时间
    flea_market_notice_agreed_at = Column(DateTime(timezone=True), nullable=True)
    
    # ... 其他字段 ...
```

**API更新**：
- 用户同意须知时，调用后端API更新该字段：
  ```
  PUT /api/flea-market/agree-notice
  Headers:
    - Authorization: Bearer <token>  // 需要登录
  Body: (空)
  Response: { success: true, agreed_at: "2025-01-20T10:30:00Z" }
  ```
- 获取用户信息时，返回该字段，前端根据该字段判断是否需要显示须知弹窗

### 5.2 设计方案

**核心设计理念**：
- **保持任务系统的一致性**：`poster_id` 始终是发布者（付钱的人），`taker_id` 始终是接收者（获得任务金额的人）
- **跳蚤市场ID格式统一**：跳蚤市场相关的所有数据库ID都以 `S` 开头，便于关联和识别
  - **商品ID**（`flea_market_items.id`）：格式为 `S + 数字`（如：`S1234`）
  - **购买申请ID**（`flea_market_purchase_requests.id`）：格式为 `S + 数字`（如：`S1234`）
  - **任务ID**（`tasks.id`，跳蚤市场创建的任务）：格式为 `S + 数字`（如：`S1234`）
  - **数据库存储**：所有ID在数据库中存储为整数（自增ID）
  - **前端返回**：需要格式化为 `S + 数字` 格式（如：数据库ID 1234 → 前端返回 `S1234`）
  - **实现方式**：可通过 `format_flea_market_id(db_id: int) -> str` 函数格式化（参考 `id_generator.py` 的模式）
  - **优势**：通过ID前缀可以快速识别跳蚤市场相关的数据，便于关联查询和调试
- **商品交易流程**：
  1. 卖家在 `flea_market_items` 表中发布商品（商品信息）
  2. 买家申请购买（可能包含议价）
  3. 卖家同意购买后，在 `tasks` 表中创建任务：
     - `poster_id` = 买家（付钱的人）
     - `taker_id` = 卖家（获得钱的人）
     - `status` = `'in_progress'`（直接进入进行中状态）
     - `task_type` = `TaskType.SecondHandAndRental`（使用枚举常量）
     - `is_flexible` = `1`（灵活时间模式，无截止日期）
     - `deadline` = `NULL`（无截止日期）
     - `location` = 商品location或"Online"（从商品表复制，如果为空则默认为"Online"）

**数据流**：
```
flea_market_items (商品表)
  ↓ 买家申请购买
  ↓ 卖家同意
tasks (任务表) - 创建交易任务
```

### 5.3 表结构设计

#### 5.3.1 二手商品表（flea_market_items）

**表名**: `flea_market_items`

**字段定义**：

| 字段名 | 类型 | 约束 | 说明 |
|--------|------|------|------|
| id | INTEGER | PRIMARY KEY, AUTO_INCREMENT | 商品ID（数据库存储为整数，返回给前端时格式化为 `S + 数字` 格式，如：S1234） |
| title | VARCHAR(200) | NOT NULL | 商品名称 |
| description | TEXT | NOT NULL | 商品描述 |
| price | DECIMAL(12, 2) | NOT NULL | 标价（GBP） |
| currency | VARCHAR(3) | NOT NULL, DEFAULT 'GBP' | 货币类型，固定为GBP |
| images | TEXT | NULL | JSON数组，存储图片URL列表 |
| location | VARCHAR(100) | NULL | 线下交易地点或"Online" |
| category | VARCHAR(100) | NULL | 商品分类 |
| contact | VARCHAR(200) | NULL | 联系方式 |
| status | VARCHAR(20) | NOT NULL, DEFAULT 'active' | 商品状态：active, sold, deleted |
| seller_id | VARCHAR(8) | NOT NULL, FOREIGN KEY | 卖家ID，关联users表 |
| sold_task_id | INTEGER | NULL, FOREIGN KEY | 售出后关联的任务ID（关联tasks表，用于my-purchases查询） |
| view_count | INTEGER | NOT NULL, DEFAULT 0 | 浏览量 |
| refreshed_at | TIMESTAMPTZ | NOT NULL, DEFAULT NOW() | 刷新时间（UTC），用于自动删除机制 |
| created_at | TIMESTAMPTZ | NOT NULL, DEFAULT NOW() | 创建时间（UTC） |
| updated_at | TIMESTAMPTZ | NOT NULL, DEFAULT NOW() | 更新时间（UTC） |

**注意**：
- `seller_id` 是卖家（提供商品的人，未来会成为任务的 `taker_id`）
- 商品状态独立于任务状态
- 当商品售出后，会在 `tasks` 表中创建对应的任务记录
- **浏览量字段**：每次用户查看商品详情时，`view_count` 自增1
- **刷新时间字段**：商品发布者可以刷新商品，更新 `refreshed_at` 为当前时间
- **自动删除机制**：如果商品发布者超过10天没有刷新商品（`refreshed_at` < NOW() - INTERVAL '10 days'），商品会被自动删除（`status` 设为 `'deleted'`），同时删除商品图片文件

#### 5.3.2 SQL DDL

```sql
CREATE TABLE flea_market_items (
    id SERIAL PRIMARY KEY,
    title VARCHAR(200) NOT NULL,
    description TEXT NOT NULL,
    price DECIMAL(12, 2) NOT NULL CHECK (price >= 0),
    currency VARCHAR(3) NOT NULL DEFAULT 'GBP' CHECK (currency = 'GBP'),
    images TEXT,  -- JSON数组，例如：'["url1", "url2"]'
    -- ⚠️ 重要：推荐生产环境将 images 改为 JSONB 类型，示例 DDL 为 TEXT 仅为兼容性示例，实际以项目 schema 为准
    -- 如果使用 PostgreSQL，强烈建议改为：images JSONB
    location VARCHAR(100),  -- 线下交易地点或"Online"
    category VARCHAR(100),
    contact VARCHAR(200),
    status VARCHAR(20) NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'sold', 'deleted')),
    seller_id VARCHAR(8) NOT NULL REFERENCES users(id) ON DELETE CASCADE,  -- 卖家ID
    sold_task_id INTEGER REFERENCES tasks(id) ON DELETE SET NULL,  -- 售出后关联的任务ID（用于my-purchases查询）
    view_count INTEGER NOT NULL DEFAULT 0,  -- 浏览量
    refreshed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),  -- 刷新时间，用于自动删除机制
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 单列索引
CREATE INDEX idx_flea_market_items_seller_id ON flea_market_items(seller_id);
CREATE INDEX idx_flea_market_items_status ON flea_market_items(status);
CREATE INDEX idx_flea_market_items_category ON flea_market_items(category);
-- 注意：排序使用 ORDER BY refreshed_at DESC（主要排序字段），created_at 仅用于统计
CREATE INDEX idx_flea_market_items_created_at ON flea_market_items(created_at);
CREATE INDEX idx_flea_market_items_price ON flea_market_items(price);
CREATE INDEX idx_flea_market_items_refreshed_at ON flea_market_items(refreshed_at);  -- 用于自动删除查询
CREATE INDEX idx_flea_market_items_view_count ON flea_market_items(view_count);  -- 用于按浏览量排序

-- ⚠️ 生产环境强烈推荐创建以下复合索引（性能优化，必做）：
CREATE INDEX idx_flea_market_items_status_refreshed ON flea_market_items(status, refreshed_at DESC);  -- 最重要：用于列表查询和排序（高频查询）
CREATE INDEX idx_flea_market_items_status_category_refreshed ON flea_market_items(status, category, refreshed_at DESC);  -- 用于分类筛选
CREATE INDEX idx_flea_market_items_status_location_refreshed ON flea_market_items(status, location, refreshed_at DESC);  -- 用于城市筛选（可选）

-- 全文搜索索引（如果使用PostgreSQL）
-- 注意：暂时使用 'simple' 分词，若主要内容为中文，需要根据最终 DB/扩展选型调整全文检索方案
CREATE INDEX idx_flea_market_items_title_search ON flea_market_items USING gin(to_tsvector('simple', title));
CREATE INDEX idx_flea_market_items_description_search ON flea_market_items USING gin(to_tsvector('simple', description));

-- 更新时间触发器（自动更新updated_at）
CREATE OR REPLACE FUNCTION update_flea_market_items_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_flea_market_items_updated_at
    BEFORE UPDATE ON flea_market_items
    FOR EACH ROW
    EXECUTE FUNCTION update_flea_market_items_updated_at();
```

#### 5.3.3 ORM模型定义（SQLAlchemy）

```python
# backend/app/models.py

from sqlalchemy import Column, Integer, String, Text, DECIMAL, DateTime, ForeignKey, Index, CheckConstraint
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from app.models import Base, get_utc_time

class FleaMarketItem(Base):
    """跳蚤市场商品表"""
    __tablename__ = "flea_market_items"
    
    id = Column(Integer, primary_key=True, index=True)
    title = Column(String(200), nullable=False)
    description = Column(Text, nullable=False)
    price = Column(DECIMAL(12, 2), nullable=False)
    currency = Column(String(3), nullable=False, default="GBP")
    images = Column(Text, nullable=True)  # JSON数组存储图片URL列表
    location = Column(String(100), nullable=True)  # 线下交易地点或"Online"
    category = Column(String(100), nullable=True)
    contact = Column(String(200), nullable=True)
    status = Column(String(20), nullable=False, default="active")
    seller_id = Column(String(8), ForeignKey("users.id", ondelete="CASCADE"), nullable=False)  # 卖家ID
    sold_task_id = Column(Integer, ForeignKey("tasks.id", ondelete="SET NULL"), nullable=True)  # 售出后关联的任务ID
    view_count = Column(Integer, nullable=False, default=0)  # 浏览量
    refreshed_at = Column(DateTime(timezone=True), default=get_utc_time, server_default=func.now())  # 刷新时间
    created_at = Column(DateTime(timezone=True), default=get_utc_time, server_default=func.now())
    updated_at = Column(DateTime(timezone=True), default=get_utc_time, onupdate=get_utc_time, server_default=func.now())
    
    # 关系
    seller = relationship("User", backref="flea_market_items")  # 卖家关系
    
    __table_args__ = (
        Index("idx_flea_market_items_seller_id", seller_id),
        Index("idx_flea_market_items_status", status),
        Index("idx_flea_market_items_category", category),
        Index("idx_flea_market_items_created_at", created_at),
        Index("idx_flea_market_items_price", price),
        Index("idx_flea_market_items_refreshed_at", refreshed_at),  # 用于自动删除查询
        Index("idx_flea_market_items_view_count", view_count),  # 用于按浏览量排序
        CheckConstraint("price >= 0", name="check_price_positive"),
        CheckConstraint("currency = 'GBP'", name="check_currency_gbp"),
        CheckConstraint("status IN ('active', 'sold', 'deleted')", name="check_status_valid"),
    )
```

#### 5.3.4 数据存储说明

1. **images字段**：
   - 存储格式：JSON数组字符串，例如：`'["https://example.com/img1.jpg", "https://example.com/img2.jpg"]'`
   - **图片存储路径**：商品图片需要存储在特定文件夹中，方便自动删除
     - 建议路径：`uploads/flea_market/{item_id}/` 或 `uploads/flea_market/{seller_id}/{item_id}/`
     - 图片命名：使用唯一标识符（如UUID）或时间戳，避免文件名冲突
     - **重要**：与任务图片存储方式一致，确保删除商品时能正确删除图片文件
   - **ORM层处理建议**：在 Pydantic schema / service 层做 `images: List[str]` 与数据库字符串之间的序列化/反序列化，避免在业务代码里到处手动 `json.loads`/`json.dumps`
   - **生产环境强烈推荐使用JSONB**（如果数据库是PostgreSQL）：
     - 可以直接存储JSON数组，无需手动序列化/反序列化
     - 查询性能更好，支持JSON操作符
     - 如果使用JSONB，ORM层可以直接使用 `JSONB` 类型，Pydantic schema 自动处理
     - **注意**：示例DDL中使用 `TEXT` 类型仅为兼容性考虑，**生产环境应使用 `JSONB` 类型**
     - **推荐生产环境将 images 改为 JSONB 类型，示例 DDL 为 TEXT 仅为兼容性示例，实际以项目 schema 为准**

2. **status字段**（商品状态机）：

**状态定义**：
- `active`: 正常在售商品（上架中）
- `sold`: 已售出（保留记录，但不显示在列表中）
- `deleted`: 已删除（软删除，保留记录）

**状态流转规则**（状态机）：

```
创建商品 → active
    ↓
active → sold        （接受购买申请，或直接购买）
    ↓
active → deleted     （用户手动删除 / 自动过期）
    ↓
sold → deleted       （可选：允许手动删除已售出商品，仅对列表隐藏）
```

**状态流转详细说明**：

| 当前状态 | 允许转换到 | 触发条件 | 说明 |
|---------|-----------|---------|------|
| - | `active` | 创建商品 | 商品创建后默认为active |
| `active` | `sold` | 接受购买申请或直接购买 | 交易达成，创建任务 |
| `active` | `deleted` | 用户手动删除 / 自动过期 | 软删除，保留记录 |
| `sold` | `deleted` | 用户手动删除（可选） | 仅对列表隐藏，保留历史记录 |

**重要规则**：
- ✅ **`sold` 的商品永远不会自动删除**（只允许手动删除，如果支持）
- ✅ **自动删除任务只处理 `status='active'` 的商品**
- ✅ **`sold` 的商品操作限制**（已售出商品信息应保持不变，只能通过任务系统处理后续事宜）：
  - **不允许编辑**：不允许编辑任何核心字段（title/price/images等）
  - **不允许再发起新的购买流程**：商品已售出后，不能再接受新的购买申请或直接购买
  - **不允许刷新**：已售出商品不需要刷新功能
- ✅ **`deleted` 的商品操作限制**（软删除后不可逆）：
  - **不允许恢复**：删除后无法恢复，只能重新发布新商品
  - **不允许再创建任务**：已删除商品不能创建任务
  - **不允许编辑**：已删除商品不能编辑
- ⚠️ **中间状态**：商品有购买申请但未接受时，商品状态仍为 `active`，通过 `flea_market_purchase_requests` 表联合表示

3. **view_count字段**：
   - 浏览量统计，每次用户查看商品详情时自增1
   - 可用于商品排序（按热度排序）
   - **实现建议**：
     - **MVP阶段**：直接 `UPDATE flea_market_items SET view_count = view_count + 1 WHERE id = :id`
     - **后续优化**：
       - 可以用 Redis 记 `item_id:user_id:date` 做去重
       - 或积累到 Redis Hash 每 N 分钟 flush 到 DB
       - 对单用户/单IP做简单节流（短时间多次访问只算一次）
       - 或使用异步队列/Redis累积浏览量，再批量落库

4. **refreshed_at字段**：
   - 商品刷新时间，用于自动删除机制
   - 商品发布者可以刷新商品，更新该字段为当前时间
   - **自动删除规则**：如果 `refreshed_at` < NOW() - INTERVAL '10 days'，商品会被自动删除
   - **删除操作**：
     1. 更新商品状态为 `'deleted'`
     2. 删除商品图片文件（从 `images` 字段中读取图片路径并删除）
     3. 记录删除日志（可选）

5. **外键关系**：
   - `seller_id` 关联 `users.id`，使用 `ON DELETE CASCADE`，用户删除时自动删除其发布的商品

6. **索引说明**：
   - **复合索引（生产环境强烈推荐，必做）**：
     - `(status, refreshed_at DESC)`: **最重要**，用于列表查询和排序（高频查询）
     - `(status, category, refreshed_at DESC)`: 用于分类筛选
     - `(status, location, refreshed_at DESC)`: 用于城市筛选（可选）
   - **单列索引**：
     - `seller_id`: 用于查询卖家发布的商品
     - `status`: 用于筛选活跃商品（默认只显示status='active'）
     - `category`: 用于分类筛选
     - `created_at`: **仅用于统计和展示，不参与排序**（不作为排序依据）
     - `price`: 用于价格排序和筛选
     - `refreshed_at`: **主要排序字段**，用于列表排序（`ORDER BY refreshed_at DESC`）和自动删除查询（查询超过10天未刷新的商品）
     - `view_count`: 用于按浏览量排序
   - **全文搜索索引**：用于标题和描述的搜索功能

7. **自动删除任务**：
   - 建议使用定时任务（如Celery Beat）每天执行一次
   - **查询条件**：`status = 'active' AND refreshed_at < NOW() - INTERVAL '10 days'`
   - **重要规则**：
     - **永远不删除 `status='sold'` 的商品**（已售出商品保留记录）
     - **只删除从未售出且长期未刷新的商品**（`status='active'`）
     - 保证不会误删任务正在使用的图片（已售出商品的图片可能被任务引用）
   - **⚠️ 存储空间优化**：已售出商品的图片不会永久保留
     - 任务完成后超过3天，系统会自动清理任务图片（参考 `cleanup_completed_tasks_files`）
     - **需要实现**：清理任务图片时，通过 `flea_market_items.sold_task_id` 找到关联的商品，同时清理商品图片目录（`uploads/flea_market/{item_id}/`）
     - 这样可以避免已售出商品的图片永久占用存储空间
   - **删除步骤**（注意：这里的删除为软删除，仅更新status='deleted'，保留DB记录，物理删除只有图片文件）：
     1. 查询符合条件的商品（`status='active'` 且超过10天未刷新）
     2. 遍历每个商品的 `images` 字段
     3. 删除图片文件（从文件系统中物理删除）
     4. 更新商品状态为 `'deleted'`（软删除，保留DB记录）
     5. 记录删除日志（可选）
   - **附加考虑**：
     - 记录删除日志表（`item_id`, `deleted_at`, `reason='expired'`）
     - 报警指标建议：自动删除失败量、图片删除失败量等（可选，看运维习惯）

### 5.4 购买申请表设计（当前版本采用该方案）

**当前版本决策**：
- ✅ **当前版本已采用有历史记录方案**，即**必建** `flea_market_purchase_requests` 表
- ✅ 该表用于记录所有购买申请历史，支持多个买家同时申请、卖家选择接受哪个申请等功能
- ⚠️ **简化方案**（见下方）仅作为未来瘦身时的备选，**不在本期实现**

**表名**: `flea_market_purchase_requests`

**字段定义**：

| 字段名 | 类型 | 约束 | 说明 |
|--------|------|------|------|
| id | INTEGER | PRIMARY KEY, AUTO_INCREMENT | 申请ID（数据库存储为整数，返回给前端时格式化为 `S + 数字` 格式，如：S1234） |
| item_id | INTEGER | NOT NULL, FOREIGN KEY | 商品ID，关联flea_market_items表（数据库存储为整数） |
| buyer_id | VARCHAR(8) | NOT NULL, FOREIGN KEY | 买家ID，关联users表 |
| proposed_price | DECIMAL(12, 2) | NULL | 议价金额（如果买家议价） |
| message | TEXT | NULL | 购买留言 |
| status | VARCHAR(20) | NOT NULL, DEFAULT 'pending' | 申请状态：pending, accepted, rejected |
| created_at | TIMESTAMPTZ | NOT NULL, DEFAULT NOW() | 创建时间（UTC） |
| updated_at | TIMESTAMPTZ | NOT NULL, DEFAULT NOW() | 更新时间（UTC） |

**说明**：
- 一个商品可以有多个购买申请（多个买家可以同时申请）
- 申请状态：`pending`（待处理）、`accepted`（已接受）、`rejected`（已拒绝）
- 当卖家接受申请后，状态更新为 `accepted`，并在 `tasks` 表中创建任务
- 当卖家接受其中一个申请时，其他所有 `pending` 状态的申请自动标记为 `rejected`

**简化方案**（仅作备选，本期不实现）：
- 不创建独立的购买申请表
- 在商品表中添加 `pending_buyer_id` 和 `pending_price` 字段
- 卖家接受后直接创建任务，清空这些字段
- ⚠️ **注意**：此方案无法记录申请历史，不支持多个买家同时申请，当前版本不采用

#### 5.4.1 SQL DDL（当前版本必建）

```sql
CREATE TABLE flea_market_purchase_requests (
    id SERIAL PRIMARY KEY,
    item_id INTEGER NOT NULL REFERENCES flea_market_items(id) ON DELETE CASCADE,
    buyer_id VARCHAR(8) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    proposed_price DECIMAL(12, 2),  -- 议价金额（如果买家议价）
    message TEXT,  -- 购买留言
    status VARCHAR(20) NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'rejected')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 索引
CREATE INDEX idx_flea_market_purchase_requests_item_id ON flea_market_purchase_requests(item_id);
CREATE INDEX idx_flea_market_purchase_requests_buyer_id ON flea_market_purchase_requests(buyer_id);
CREATE INDEX idx_flea_market_purchase_requests_status ON flea_market_purchase_requests(status);
CREATE INDEX idx_flea_market_purchase_requests_created_at ON flea_market_purchase_requests(created_at);

-- 唯一约束：一个买家对同一个商品只能有一个pending状态的申请
CREATE UNIQUE INDEX idx_flea_market_purchase_requests_unique_pending 
    ON flea_market_purchase_requests(item_id, buyer_id) 
    WHERE status = 'pending';

-- 更新时间触发器
CREATE OR REPLACE FUNCTION update_flea_market_purchase_requests_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_flea_market_purchase_requests_updated_at
    BEFORE UPDATE ON flea_market_purchase_requests
    FOR EACH ROW
    EXECUTE FUNCTION update_flea_market_purchase_requests_updated_at();
```

#### 5.4.2 ORM模型定义（SQLAlchemy）

```python
# backend/app/models.py

from sqlalchemy import Column, Integer, String, Text, DECIMAL, DateTime, ForeignKey, Index, CheckConstraint, UniqueConstraint
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from app.models import Base, get_utc_time

class FleaMarketPurchaseRequest(Base):
    """跳蚤市场购买申请表"""
    __tablename__ = "flea_market_purchase_requests"
    
    id = Column(Integer, primary_key=True, index=True)
    item_id = Column(Integer, ForeignKey("flea_market_items.id", ondelete="CASCADE"), nullable=False)
    buyer_id = Column(String(8), ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    proposed_price = Column(DECIMAL(12, 2), nullable=True)  # 议价金额（如果买家议价）
    message = Column(Text, nullable=True)  # 购买留言
    status = Column(String(20), nullable=False, default="pending")
    created_at = Column(DateTime(timezone=True), default=get_utc_time, server_default=func.now())
    updated_at = Column(DateTime(timezone=True), default=get_utc_time, onupdate=get_utc_time, server_default=func.now())
    
    # 关系
    item = relationship("FleaMarketItem", backref="purchase_requests")  # 商品关系
    buyer = relationship("User", backref="flea_market_purchase_requests")  # 买家关系
    
    __table_args__ = (
        Index("idx_flea_market_purchase_requests_item_id", item_id),
        Index("idx_flea_market_purchase_requests_buyer_id", buyer_id),
        Index("idx_flea_market_purchase_requests_status", status),
        Index("idx_flea_market_purchase_requests_created_at", created_at),
        # 唯一约束：一个买家对同一个商品只能有一个pending状态的申请
        Index("idx_flea_market_purchase_requests_unique_pending", item_id, buyer_id, 
              postgresql_where=(status == 'pending'), unique=True),
        CheckConstraint("status IN ('pending', 'accepted', 'rejected')", name="check_status_valid"),
    )
```

**索引说明**：
- `item_id`: 用于查询某个商品的所有购买申请
- `buyer_id`: 用于查询某个买家的所有购买申请
- `status`: 用于筛选特定状态的申请
- `created_at`: **仅用于统计和展示，不参与排序**
- **唯一约束**：一个买家对同一个商品只能有一个`pending`状态的申请，避免重复申请

### 5.5 数据迁移

如果使用Alembic进行数据库迁移：

**迁移文件1：添加用户表字段**
```python
# migrations/versions/xxxx_add_flea_market_notice_agreed_at.py

def upgrade():
    # 为用户表添加跳蚤市场须知同意时间字段
    op.add_column('users', sa.Column('flea_market_notice_agreed_at', sa.DateTime(timezone=True), nullable=True))
    # 可选：添加索引
    op.create_index('idx_users_flea_market_notice_agreed_at', 'users', ['flea_market_notice_agreed_at'])

def downgrade():
    op.drop_index('idx_users_flea_market_notice_agreed_at', table_name='users')
    op.drop_column('users', 'flea_market_notice_agreed_at')
```

**迁移文件2：创建跳蚤市场商品表**
```python
# migrations/versions/xxxx_add_flea_market_items.py

def upgrade():
    op.create_table(
        'flea_market_items',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('title', sa.String(200), nullable=False),
        sa.Column('description', sa.Text(), nullable=False),
        sa.Column('price', sa.DECIMAL(12, 2), nullable=False),
        sa.Column('currency', sa.String(3), nullable=False, server_default='GBP'),
        sa.Column('images', sa.Text(), nullable=True),
        sa.Column('location', sa.String(100), nullable=True),
        sa.Column('category', sa.String(100), nullable=True),
        sa.Column('contact', sa.String(200), nullable=True),
        sa.Column('status', sa.String(20), nullable=False, server_default='active'),
        sa.Column('seller_id', sa.String(8), nullable=False),
        sa.Column('sold_task_id', sa.Integer(), nullable=True),
        sa.Column('view_count', sa.Integer(), nullable=False, server_default='0'),
        sa.Column('refreshed_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
        sa.Column('updated_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
        sa.ForeignKeyConstraint(['seller_id'], ['users.id'], ondelete='CASCADE'),
        sa.ForeignKeyConstraint(['sold_task_id'], ['tasks.id'], ondelete='SET NULL'),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index('idx_flea_market_items_seller_id', 'flea_market_items', ['seller_id'])
    op.create_index('idx_flea_market_items_sold_task_id', 'flea_market_items', ['sold_task_id'])
    op.create_index('idx_flea_market_items_status', 'flea_market_items', ['status'])
    op.create_index('idx_flea_market_items_category', 'flea_market_items', ['category'])
    # 注意：示例为简化版，实际 Alembic 用法按项目现有规范来写
    # 排序使用 refreshed_at DESC（主要排序字段），created_at 仅用于统计
    op.create_index('idx_flea_market_items_created_at', 'flea_market_items', ['created_at'])
    # 复合索引（性能优化，建议添加）
    op.create_index('idx_flea_market_items_status_refreshed', 'flea_market_items', ['status', sa.text('refreshed_at DESC')])
    op.create_index('idx_flea_market_items_status_category_refreshed', 'flea_market_items', ['status', 'category', sa.text('refreshed_at DESC')])
    op.create_index('idx_flea_market_items_price', 'flea_market_items', ['price'])
    op.create_index('idx_flea_market_items_refreshed_at', 'flea_market_items', ['refreshed_at'])
    op.create_index('idx_flea_market_items_view_count', 'flea_market_items', ['view_count'])

def downgrade():
    op.drop_index('idx_flea_market_items_price', table_name='flea_market_items')
    op.drop_index('idx_flea_market_items_created_at', table_name='flea_market_items')
    op.drop_index('idx_flea_market_items_category', table_name='flea_market_items')
    op.drop_index('idx_flea_market_items_status', table_name='flea_market_items')
    op.drop_index('idx_flea_market_items_seller_id', table_name='flea_market_items')
    op.drop_table('flea_market_items')
```

**迁移文件3：创建购买申请表**（**必建**，当前版本采用有历史记录方案）
```python
# migrations/versions/xxxx_add_flea_market_purchase_requests.py

def upgrade():
    op.create_table(
        'flea_market_purchase_requests',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('item_id', sa.Integer(), nullable=False),
        sa.Column('buyer_id', sa.String(8), nullable=False),
        sa.Column('proposed_price', sa.DECIMAL(12, 2), nullable=True),
        sa.Column('message', sa.Text(), nullable=True),
        sa.Column('status', sa.String(20), nullable=False, server_default='pending'),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
        sa.Column('updated_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
        sa.ForeignKeyConstraint(['item_id'], ['flea_market_items.id'], ondelete='CASCADE'),
        sa.ForeignKeyConstraint(['buyer_id'], ['users.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id'),
        sa.CheckConstraint("status IN ('pending', 'accepted', 'rejected')", name='check_status_valid')
    )
    op.create_index('idx_flea_market_purchase_requests_item_id', 'flea_market_purchase_requests', ['item_id'])
    op.create_index('idx_flea_market_purchase_requests_buyer_id', 'flea_market_purchase_requests', ['buyer_id'])
    op.create_index('idx_flea_market_purchase_requests_status', 'flea_market_purchase_requests', ['status'])
    op.create_index('idx_flea_market_purchase_requests_created_at', 'flea_market_purchase_requests', ['created_at'])
    # 唯一约束：一个买家对同一个商品只能有一个pending状态的申请
    op.create_index('idx_flea_market_purchase_requests_unique_pending', 
                    'flea_market_purchase_requests', 
                    ['item_id', 'buyer_id'],
                    unique=True,
                    postgresql_where=sa.text("status = 'pending'"))

def downgrade():
    op.drop_index('idx_flea_market_purchase_requests_unique_pending', table_name='flea_market_purchase_requests')
    op.drop_index('idx_flea_market_purchase_requests_created_at', table_name='flea_market_purchase_requests')
    op.drop_index('idx_flea_market_purchase_requests_status', table_name='flea_market_purchase_requests')
    op.drop_index('idx_flea_market_purchase_requests_buyer_id', table_name='flea_market_purchase_requests')
    op.drop_index('idx_flea_market_purchase_requests_item_id', table_name='flea_market_purchase_requests')
    op.drop_table('flea_market_purchase_requests')
```

**迁移顺序**：
1. 先执行用户表字段更新（`xxxx_add_flea_market_notice_agreed_at.py`）
2. 再执行商品表创建（`xxxx_add_flea_market_items.py`）
3. 执行购买申请表创建（`xxxx_add_flea_market_purchase_requests.py`，**必建**，用于议价购买流程）

## 6. 后端API设计

### 6.0 API设计规范

#### 6.0.1 响应格式统一

**所有API统一使用以下响应格式**：
```json
{
  "success": true,
  "data": {
    // 具体数据内容
  },
  "message": "操作成功"  // 可选，用于提示信息
}
```

**分页列表API统一格式**：
```json
{
  "success": true,
  "data": {
    "items": [...],
    "page": 1,
    "pageSize": 20,
    "total": 10,
    "hasMore": false
  }
}
```

#### 6.0.2 错误码约定

| HTTP状态码 | 场景 | 建议错误码 |
|-----------|------|-----------|
| 400 | 参数缺失/格式错误 | `INVALID_REQUEST` |
| 401 | 未登录 | `UNAUTHORIZED` |
| 403 | 操作非本人资源（编辑/刷新/接受申请） | `FORBIDDEN` |
| 404 | 商品不存在或已删除 | `ITEM_NOT_FOUND` |
| 409 | 已售出 / 已有pending申请 / 重复接受 | `CONFLICT` / `ITEM_ALREADY_SOLD` / `REQUEST_ALREADY_PROCESSED` / `PURCHASE_REQUEST_ALREADY_PENDING` |

**错误响应格式**：
```json
{
  "success": false,
  "error": {
    "code": "ITEM_ALREADY_SOLD",
    "message": "该商品已售出"
  }
}
```

#### 6.0.3 幂等性要求

**直接购买API（direct-purchase）**：
- 若商品已 `sold` 或已有被接受的申请，应返回 409（业务冲突），确保不会创建多个任务
- 使用条件更新 `WHERE status='active'` 防止并发超卖

**购买申请API（purchase-request）**：
- 通过唯一 pending 索引限制"一个 buyer 对一个 item 只能有一个 pending"
- 当违反该唯一约束时，返回 409 + 错误码 `PURCHASE_REQUEST_ALREADY_PENDING`

**接受购买API（accept-purchase）**：
- 必须确保在同一个事务里：
  - 把该申请标记 `accepted`
  - 其它 pending 标记 `rejected`
  - 创建任务
  - 更新 `item.status = 'sold'`
- 如果申请已经是 `accepted` 或 `rejected`，直接返回最终状态，不再重复创建任务（幂等性）

**重要**：`direct-purchase` 和 `accept-purchase` 必须是事务性的幂等操作。

### 6.1 商品列表API
```
GET /api/flea-market/items
Query参数:
  - page: 页码（默认1）
  - pageSize: 每页数量（默认20）
  - category: 分类筛选（可选）
  - keyword: 关键词搜索（可选）
  - status: 商品状态（默认只返回'active'）

Response:
```json
{
  "success": true,
  "data": {
    "items": [
      {
        "id": 1,
        "title": "商品名称",
        "description": "商品描述",
        "price": 100.00,
        "currency": "GBP",
        "images": ["url1", "url2"],
        "location": "London",
        "category": "电子产品",
        // 注意：contact 字段不在API响应中返回（预留字段，本期不使用）
        "status": "active",
        "seller_id": "12345678",
        "view_count": 42,
        "refreshed_at": "2025-01-20T10:30:00Z",
        "created_at": "2025-01-15T10:30:00Z",
        "updated_at": "2025-01-20T10:30:00Z"
      }
    ],
    "page": 1,
    "pageSize": 20,
    "total": 100,
    "hasMore": true  // 后端计算：hasMore = page * pageSize < total
  }
}
```
```

**分页字段说明**：
- `total`: 符合条件的商品总数
- `hasMore`: 后端计算好的布尔值，表示是否还有更多数据（`hasMore = page * pageSize < total`）
- 前端可以直接使用 `hasMore` 判断是否继续加载，无需自己计算

**排序规则**（统一规范）：
- **默认排序**：`ORDER BY refreshed_at DESC, id DESC`
  - `refreshed_at DESC`: 最近刷新/更新的商品排在前面
  - `id DESC`: 作为次要排序，保证相同刷新时间的商品顺序稳定
- **字段说明**：
  - `refreshed_at`: 用户手动刷新时更新为当前时间，商品创建时也设置为当前时间。**这是主要排序字段**
  - `created_at`: **仅用于统计和展示，不参与排序**
- **索引建议**：推荐建立复合索引 `(status, refreshed_at DESC)` 用于高频列表查询，提升性能

**前端文案对齐**：
- ✅ 列表页标题/说明应使用"按最新刷新排序"或"最近刷新优先"
- ❌ 避免使用"按发布时间排序"，避免与 `refreshed_at` 的实际行为不一致
- ✅ 商品卡片可显示"刷新时间"或"最近更新"，而非仅显示"发布时间"

### 6.2 商品详情API（预留）

```
GET /api/flea-market/items/:id
Headers: (无需登录)

Response:
```json
{
  "success": true,
  "data": {
    "id": "S1234",  // 商品ID（格式：S + 数字）
    "title": "商品名称",
    "description": "商品描述",
    "price": 100.00,
    "currency": "GBP",
    "images": ["url1", "url2"],
    "location": "London",
    "category": "电子产品",
    // 注意：contact 字段不在API响应中返回（预留字段，本期不使用）
    "status": "active",
    "seller_id": "12345678",
    "view_count": 43,  // 自动自增1
    "refreshed_at": "2025-01-20T10:30:00Z",
    "created_at": "2025-01-15T10:30:00Z",
    "updated_at": "2025-01-20T10:30:00Z"
  }
}
```
```

**功能说明**：
- 返回单个商品的详细信息
- **浏览量统计**：每次调用时，`view_count` 自动自增1（用于统计商品热度）
- 无需登录即可查看商品详情
- **注意**：浏览量在GET详情接口中自动更新，无需单独的POST /view接口

### 6.3 商品上传API

**图片上传流程**：
1. 前端先调用现有的图片上传API上传File对象，获取图片URL
2. 前端将图片URL数组连同其他字段一起提交到商品上传API

**图片上传API**（复用现有）：
```
POST /api/upload/image  (或现有的图片上传接口)
Body: FormData
  - file: File
Response: { url: string }
```

**商品上传API**：
```
POST /api/flea-market/items
Headers:
  - Authorization: Bearer <token>  // 需要登录
Body:
  - title: string
  - description: string
  - price: number
  - images: string[]  // 图片URL数组（不是File对象）
  - location?: string  // 线下交易地点或"Online"
  - category?: string
  // 注意：不包含 contact 字段，前端不显示也不获取联系方式

Response:
{
  "success": true,
  "data": {
    "id": "S1234"  // 商品ID（格式：S + 数字）
  },
  "message": "商品上传成功"
}
```

**重要说明**：
- `images` 字段为图片URL数组，不是File对象
- 图片上传复用现有的图片上传API，前端先上传图片再提交URL
- 后端不需要处理文件上传，只需要存储URL数组
- 图片存储在特定文件夹中（如 `uploads/flea_market/{item_id}/`），方便后续删除
- 商品创建时，`refreshed_at` 自动设置为当前时间
- **注意**：`contact` 字段为**预留字段，本期不使用**。前端不会传入，后端也应忽略此字段。此字段保留在数据库表中，但**所有对外API都不应读取或返回此字段**。

### 6.4 商品管理API

**商品编辑/下架API**（共用同一个PUT接口）：
```
PUT /api/flea-market/items/:id
Headers:
  - Authorization: Bearer <token>  // 需要登录
Body:
  // 编辑操作：包含除status外的其他字段
  - title?: string
  - description?: string
  - price?: number
  - images?: string[]
  - location?: string  // 线下交易地点或"Online"
  - category?: string
  // 注意：contact 字段为预留字段，本期不使用
  // 后端应忽略此字段：不读取、不验证、不存储、不返回
  // 即使请求中包含 contact 字段，也应忽略
  
  // 下架操作：仅包含status字段
  - status?: 'deleted'  // 下架商品（软删除）
```

**接口行为规则**：
- **编辑操作**：Body中包含除`status`外的其他字段（如`title`、`description`、`price`等）时，视为编辑商品信息
- **下架操作**：Body中仅包含`status: 'deleted'`时，视为下架商品（软删除，仅更新状态，保留DB记录）
- **混合操作**：如果Body中同时包含其他字段和`status: 'deleted'`，先执行编辑操作，再执行下架操作
- **实现建议**：后端可以在同一个handler中处理编辑和下架逻辑，根据Body内容判断操作类型

**权限验证**：
- 编辑/删除操作需要验证：`seller_id === 当前登录用户id`
- 只有商品发布者（卖家）才能编辑/删除自己的商品

### 6.5 商品刷新API

```
POST /api/flea-market/items/:id/refresh
Headers:
  - Authorization: Bearer <token>  // 需要登录
Body: (空)
```

**功能说明**：
- 刷新商品，重置自动删除计时器
- 更新 `refreshed_at` 字段为当前时间（同时触发 `updated_at` 自动更新）
- **权限验证**：仅允许 `seller_id === 当前登录用户id` 的商品所有者刷新
- **刷新限制**：建议实现刷新频率限制（如每24小时最多刷新一次），避免恶意刷新
- **不影响**：`created_at` 字段保持不变

**Response**：
```json
{
  "success": true,
  "data": {
    "refreshed_at": "2025-01-20T10:30:00Z"
  },
  "message": "商品刷新成功"
}
```

### 6.6 我的购买商品API

```
GET /api/flea-market/my-purchases
Headers:
  - Authorization: Bearer <token>  // 需要登录
Query参数:
  - page: 页码（默认1）
  - pageSize: 每页数量（默认20）
```

**功能说明**：
- 查询当前登录用户作为买家购买的商品
- **过滤逻辑**：
  - 只返回 `status='sold'` 的商品（已售出且已创建任务）
  - 通过关联 `tasks` 表查询：`tasks.poster_id = 当前用户id AND tasks.task_type = 'Second-hand & Rental'`
  - **不包含**未完成任务的商品（只包含已创建任务的商品）
- **返回结构**：与普通商品列表API格式基本一致，额外包含以下字段：
  - `task_id`: 关联的任务ID（用于跳转到任务详情）
  - `final_price`: 最终成交价（优先从 `tasks.agreed_reward` 获取，如果为NULL则从 `tasks.reward` 获取，可能经过议价，与商品标价 `price` 不同）
- **分页参数**：支持 `page` 和 `pageSize`（默认值同列表API）
- **排序规则**：按任务创建时间倒序（`tasks.created_at DESC`），最近购买的在前面

**Response**：
```json
{
  "success": true,
  "data": {
    "items": [
      {
        "id": "S1234",  // 商品ID（格式：S + 数字）
        "title": "商品名称",
        "description": "商品描述",
        "price": 100.00,  // 商品原始标价
        "currency": "GBP",
        "images": ["url1", "url2"],
        "location": "London",
        "category": "电子产品",
        "status": "sold",
        "seller_id": "12345678",
        "view_count": 42,
        "refreshed_at": "2025-01-20T10:30:00Z",
        "created_at": "2025-01-15T10:30:00Z",
        "updated_at": "2025-01-20T10:30:00Z",
        "task_id": "S1234",  // 关联的任务ID（格式：S + 数字，用于跳转到任务详情）
        "final_price": 95.00  // 最终成交价（优先从tasks.agreed_reward获取，如果为NULL则从tasks.reward获取，可能经过议价）
      }
    ],
    "page": 1,
    "pageSize": 20,
    "total": 10,
    "hasMore": false
  }
}
```

**实现建议**：
- **关联方式**：通过 `flea_market_items.sold_task_id` 字段关联 `tasks.id`（创建任务后更新该字段）
- **ID格式说明**：跳蚤市场相关的所有ID都以 `S` 开头
  - 商品ID、购买申请ID、任务ID均格式化为 `S + 数字`（如：`S1234`）
  - 数据库存储：所有ID在数据库中存储为整数（自增ID）
  - 前端返回：需要将ID格式化为 `S + 数字` 格式（如：数据库ID 1234 → 前端返回 `S1234`）
  - 实现方式：可通过 `format_flea_market_id(db_id: int) -> str` 函数格式化（参考 `id_generator.py` 的模式）
  - **优势**：通过ID前缀可以快速识别跳蚤市场相关的数据，便于关联查询和调试
- 查询条件：
  ```sql
  WHERE tasks.poster_id = :current_user_id 
    AND tasks.task_type = 'Second-hand & Rental' 
    AND flea_market_items.status = 'sold'
    AND flea_market_items.sold_task_id = tasks.id
  ```
- 最终成交价从 `tasks.agreed_reward` 获取（如果有议价），否则从 `tasks.reward` 获取
- 排序：`ORDER BY tasks.created_at DESC`

### 6.7 须知同意API

```
PUT /api/flea-market/agree-notice
Headers:
  - Authorization: Bearer <token>  // 需要登录
Body: (空)
```

**功能说明**：
- 用户同意跳蚤市场须知，更新用户表中的 `flea_market_notice_agreed_at` 字段
- 该字段用于替代前端 `localStorage` 的存储方式，确保数据持久化和跨设备同步
- 如果该字段为 `NULL`，表示用户尚未同意须知，需要显示须知弹窗
- 如果该字段有值，表示用户已同意须知，不再显示弹窗

**Response**：
```json
{
  "success": true,
  "data": {
    "agreed_at": "2025-01-20T10:30:00Z"
  },
  "message": "已同意跳蚤市场须知"
}
```

**错误响应**：
- 401 Unauthorized: 未登录（错误码：`UNAUTHORIZED`）

**实现说明**：
- 获取用户信息时，应返回 `flea_market_notice_agreed_at` 字段
- 前端根据该字段判断是否需要显示须知弹窗

### 6.8 商品购买流程API

#### 6.8.1 购买流程概述

购买流程分为两种模式：

**模式1：直接购买（无议价）**
- 买家点击"购买"按钮，在确认弹窗中不勾选"议价"选项
- 直接调用 `POST /api/flea-market/items/:id/direct-purchase` API
- 后端直接创建进行中的任务，**不走购买申请表**
- 任务状态直接为 `in_progress`

**模式2：议价购买**
- 买家点击"购买"按钮，在确认弹窗中勾选"议价"选项
- 输入议价金额后，调用 `POST /api/flea-market/items/:id/purchase-request` API
- 创建购买申请记录，等待卖家同意/拒绝/再议价
- 卖家同意后，调用 `POST /api/flea-market/items/:id/accept-purchase` API创建任务

#### 6.8.2 直接购买API（无议价）

```
POST /api/flea-market/items/:id/direct-purchase
Headers:
  - Authorization: Bearer <token>  // 需要登录
Body: (空)
```

**流程说明**：
1. 买家调用 `direct-purchase` API直接购买（无议价，使用商品标价）
2. 后端自动执行（**必须在同一个数据库事务中完成**）：
   - 在 `tasks` 表中创建任务：
     - **ID格式说明**：跳蚤市场相关的所有ID都以 `S` 开头
       - 商品ID、购买申请ID、任务ID均格式化为 `S + 数字`（如：`S1234`）
       - 数据库存储：所有ID在数据库中存储为整数（自增ID）
       - 前端返回：需要格式化为 `S + 数字` 格式（如：数据库ID 1234 → 前端返回 `S1234`）
       - 实现方式：可通过 `format_flea_market_id(db_id: int) -> str` 函数格式化（参考 `id_generator.py` 的模式）
     - `poster_id` = 买家ID
     - `taker_id` = 卖家ID（从 `flea_market_items.seller_id` 获取）
     - `status` = `'in_progress'`（直接进入进行中状态）
     - `task_type` = `TaskType.SecondHandAndRental`（使用枚举常量）
     - `title` = 商品名称（从 `flea_market_items.title` 复制）
     - `description` = 合并字段：商品描述 + 商品分类
       - 格式：`"{description}\n\n分类：{category}"`
       - **注意**：不包含联系方式，联系方式只在任务进行中后在聊天框发送
       - 如果 `category` 为空，则省略对应行
     - `reward` = 商品标价（从 `flea_market_items.price` 复制）
     - `base_reward` = 商品原始标价（从 `flea_market_items.price` 复制）
     - `agreed_reward` = `NULL`（直接购买无议价）
     - `location` = 任务城市（从 `flea_market_items.location` 复制，如果为空则默认为"Online"）
     - `images` = 商品图片URL数组（从 `flea_market_items.images` 复制）
     - `is_flexible` = `1`（灵活时间模式，无截止日期）
     - `deadline` = `NULL`（无截止日期）
   - 更新商品状态：`flea_market_items.status` = `'sold'`
     - **并发控制**：使用条件更新 `UPDATE ... SET status='sold' WHERE id=:id AND status='active'`
     - 如果受影响行数为 0，则说明商品已被售出或下架，返回错误
   - 更新商品关联任务：`flea_market_items.sold_task_id` = 创建的任务ID
   - **不创建购买申请记录**（直接购买不走申请表）

**Response**：
```json
{
  "success": true,
  "data": {
    "task_id": "S1234",  // 创建的任务ID（格式：S + 数字）
    "item_status": "sold"  // 商品状态已更新为sold
  },
  "message": "购买成功，任务已创建"
}
```

**错误响应**：
- 401 Unauthorized: 未登录（错误码：`UNAUTHORIZED`）
- 404 Not Found: 商品不存在（错误码：`ITEM_NOT_FOUND`）
- 409 Conflict: 商品已售出或已下架（`status != 'active'`，错误码：`ITEM_ALREADY_SOLD`）

#### 6.8.3 购买申请API（议价购买）

**买家申请购买API**：
```
POST /api/flea-market/items/:id/purchase-request
Headers:
  - Authorization: Bearer <token>  // 需要登录
Body:
  - proposed_price: number  // 议价金额（必填，必须大于0）
  - message?: string  // 购买留言（可选）
```

**Response**（purchase-request）：
```json
{
  "success": true,
  "data": {
    "purchase_request_id": "S1234",  // 购买申请ID（格式：S + 数字）
    "status": "pending",  // 申请状态
    "proposed_price": 95.00,  // 议价金额
    "created_at": "2025-01-20T10:30:00Z"
  },
  "message": "购买申请已提交，等待卖家处理"
}
```

**错误响应**（purchase-request）：
- 401 Unauthorized: 未登录（错误码：`UNAUTHORIZED`）
- 404 Not Found: 商品不存在（错误码：`ITEM_NOT_FOUND`）
- 409 Conflict: 商品已售出或已下架（错误码：`ITEM_ALREADY_SOLD`）
- 409 Conflict: 您已提交购买申请，请等待卖家处理（错误码：`PURCHASE_REQUEST_ALREADY_PENDING`）
- 400 Bad Request: 议价金额必须大于0（错误码：`INVALID_REQUEST`）

**卖家接受购买API**（创建任务）：
```
POST /api/flea-market/items/:id/accept-purchase
Headers:
  - Authorization: Bearer <token>  // 需要登录
Body:
  - purchase_request_id: number  // 购买申请ID
  - agreed_price?: number  // 最终成交价（如果卖家再次议价，可选）
```

**购买流程UX细节**：

1. **多个购买申请的处理**：
   - ✅ **允许**：一个商品可以有多个 `pending` 状态的购买申请（多个买家可以同时申请）
   - ✅ **自动处理**：当卖家接受其中一个申请时，**其他所有 `pending` 状态的申请自动标记为 `rejected`**
   - ✅ **唯一约束**：一个买家对同一个商品只能有一个 `pending` 状态的申请（数据库唯一索引保证）
   - ⚠️ **重复提交处理**：如果买家对同一商品已有 `pending` 申请，再次提交应返回 **409 Conflict** 错误，提示"您已提交购买申请，请等待卖家处理"
   - ✅ **前端状态提示**：当卖家接受B的申请时，C/D等其他pending申请在前端显示的状态文案建议为："卖家已选择另一位买家"
   - ✅ **已售商品限制**：当商品已 `sold` 后，再申请时直接返回错误（409 Conflict 或 400 Bad Request），前端提示"该商品已售出"

2. **卖家修改最终价格**：
   - ✅ **支持**：卖家在接受购买申请时可以修改最终成交价
   - ✅ **接口支持**：`accept-purchase` API 的 `agreed_price` 参数可选，如果提供则使用此价格，否则使用 `proposed_price`
   - ✅ **记录完整**：
     - `tasks.reward` 存储最终成交价（直接购买时等于商品标价，议价购买时等于议价后的价格）
     - `tasks.agreed_reward` 存储最终成交价（如果有议价，否则为NULL）
     - `tasks.base_reward` 存储商品原始标价
     - `flea_market_purchase_requests.proposed_price` 存储买家议价

3. **买家取消申请**：
   - ❌ **不支持**：当前版本不支持买家主动撤回购买申请
   - ✅ **产品规则**：如需取消，请联系卖家由其拒绝申请
   - 💡 **未来扩展**：可考虑添加 `DELETE /api/flea-market/purchase-requests/:id` 或 `POST /api/flea-market/purchase-requests/:id/cancel` 接口

**流程说明**：
1. 买家调用 `purchase-request` API申请购买（包含议价）
   - 创建购买申请记录（`flea_market_purchase_requests` 表）
   - `status` = `'pending'`（待处理）
   - `proposed_price` = 买家议价金额
   - **幂等性**：如果已有 `pending` 申请，返回 409 错误（错误码：`PURCHASE_REQUEST_ALREADY_PENDING`）
2. 卖家调用 `accept-purchase` API接受购买
   - **幂等性**：如果申请已经是 `accepted` 或 `rejected`，直接返回最终状态，不再重复创建任务（错误码：`REQUEST_ALREADY_PROCESSED`）
3. 后端自动执行（**必须在同一个数据库事务中完成**）：
   - 在 `tasks` 表中创建任务：
     - **ID格式说明**：跳蚤市场相关的所有ID都以 `S` 开头
       - 商品ID、购买申请ID、任务ID均格式化为 `S + 数字`（如：`S1234`）
       - 数据库存储：所有ID在数据库中存储为整数（自增ID）
       - 前端返回：需要格式化为 `S + 数字` 格式（如：数据库ID 1234 → 前端返回 `S1234`）
       - 实现方式：可通过 `format_flea_market_id(db_id: int) -> str` 函数格式化（参考 `id_generator.py` 的模式）
     - `poster_id` = 买家ID
     - `taker_id` = 卖家ID（从 `flea_market_items.seller_id` 获取）
     - `status` = `'in_progress'`（直接进入进行中状态）
     - `task_type` = `TaskType.SecondHandAndRental`（使用枚举常量）
     - `title` = 商品名称（从 `flea_market_items.title` 复制）
     - `description` = 合并字段：商品描述 + 商品分类
       - 格式：`"{description}\n\n分类：{category}"`
       - **注意**：不包含联系方式，联系方式只在任务进行中后在聊天框发送
       - 如果 `category` 为空，则省略对应行
     - `reward` = 最终成交价（从 `agreed_price` 或 `proposed_price` 获取，如果没有提供agreed_price则使用proposed_price）
     - `base_reward` = 商品原始标价（从 `flea_market_items.price` 复制）
     - `agreed_reward` = 最终成交价（从 `agreed_price` 或 `proposed_price` 获取，如果有议价则存储，否则为NULL）
     - `location` = 任务城市（从 `flea_market_items.location` 复制，如果为空则默认为"Online"）
     - `images` = 商品图片URL数组（从 `flea_market_items.images` 复制）
     - `is_flexible` = `1`（灵活时间模式，无截止日期）
     - `deadline` = `NULL`（无截止日期）
   - 更新商品状态：`flea_market_items.status` = `'sold'`
     - **并发控制**：使用条件更新 `UPDATE ... SET status='sold' WHERE id=:id AND status='active'`
     - 如果受影响行数为 0，则说明商品已被售出或下架，返回错误
   - 更新商品关联任务：`flea_market_items.sold_task_id` = 创建的任务ID
   - 更新购买申请状态：`flea_market_purchase_requests.status` = `'accepted'`
   - **自动拒绝其他申请**：将该商品的所有其他 `pending` 申请自动标记为 `rejected`

**Response**（accept-purchase）：
```json
{
  "success": true,
  "data": {
    "task_id": "S1234",  // 创建的任务ID（格式：S + 数字）
    "item_status": "sold",  // 商品状态已更新为sold
    "final_price": 95.00,  // 最终成交价（从agreed_price或proposed_price获取）
    "purchase_request_status": "accepted"  // 购买申请状态
  },
  "message": "购买申请已接受，任务已创建"
}
```

**错误响应**（accept-purchase）：
- 401 Unauthorized: 未登录（错误码：`UNAUTHORIZED`）
- 403 Forbidden: 不是该商品的卖家（错误码：`FORBIDDEN`）
- 404 Not Found: 商品或购买申请不存在（错误码：`ITEM_NOT_FOUND`）
- 409 Conflict: 商品已售出或申请状态不是pending（错误码：`ITEM_ALREADY_SOLD` 或 `REQUEST_ALREADY_PROCESSED`）

**重要**：
- 创建任务 + 更新 `flea_market_items.status` 必须放在一个数据库事务中，保证原子性
- 更新商品状态时使用条件更新防止并发超卖：`WHERE status='active'`
- 避免出现商品变成 `sold` 但任务没创建，或创建了任务但商品还在 `active` 列表里的情况
- **联系方式处理**：任务创建时不在 `description` 中包含联系方式，联系方式只在任务进入 `in_progress` 状态后，由卖家在任务聊天框中发送

#### 6.8.4 购买流程前端交互

**购买确认弹窗流程**：

1. **用户点击"购买"按钮**
   - 打开购买确认弹窗（PurchaseConfirmModal）
   - 显示商品名称和原价

2. **议价选项**
   - 弹窗下方有"我要议价"复选框
   - 勾选后显示议价输入框
   - 输入议价金额（必须大于0）

3. **确认购买**
   - **无议价**：不勾选议价复选框，直接点击"确认购买"
     - 调用 `POST /api/flea-market/items/:id/direct-purchase`
     - 后端直接创建 `in_progress` 状态的任务
     - 不走购买申请表
   - **有议价**：勾选议价复选框，输入议价金额，点击"确认购买"
     - 调用 `POST /api/flea-market/items/:id/purchase-request`（包含 `proposed_price`）
     - 创建购买申请记录，状态为 `pending`
     - 等待卖家同意/拒绝/再议价

4. **联系方式处理**
   - **前端不显示也不获取**：购买确认弹窗中不包含联系方式字段
   - **不在任务描述中包含**：创建任务时不在 `description` 中包含联系方式
   - **只在任务聊天中发送**：任务进入 `in_progress` 状态后，卖家可以在任务聊天框中发送联系方式给买家

**任务完成API**（复用现有任务API）：
```
PUT /api/tasks/:task_id
Headers:
  - Authorization: Bearer <token>  // 需要登录
Body:
  - status: 'completed'  // 标记交易完成
```

## 7. 样式设计

### 7.1 固定卡片样式
- 与普通TaskCard保持一致的外观
- 可以添加特殊标识（如角标、边框颜色等）
- 响应式设计，支持移动端

### 7.2 二手交易页面样式 ✅ 已实现

**实际样式实现**（`FleaMarketPage.module.css`）：

- ✅ 使用与Tasks页面一致的设计语言
- ✅ 商品卡片采用响应式网格布局
- ✅ 上传表单使用模态框（Ant Design Modal）
- ✅ **CSS性能优化已实现**：
  - GPU加速：`transform: translateZ(0)`, `will-change`
  - 背面可见性：`backface-visibility: hidden`
  - 内容可见性：`content-visibility: auto`（提升长列表滚动性能）
  - 内容隔离：`contain: layout style paint`
  - 过渡优化：使用具体属性而非`all`
  - 图片渲染优化：`image-rendering`属性

**主要样式类**：
- `.heroSection`：顶部横幅区域（渐变背景）
- `.heroContent`：横幅内容容器
- `.heroTitle`：页面标题（大字体，居中）
- `.heroIcon`：标题图标（🛍️）
- `.uploadButton`：上传按钮（主色调，大尺寸）
- `.myItemsButton`：我的闲置按钮（默认样式）
- `.filtersSection`：搜索和筛选区域
- `.itemsSection`：商品列表区域
- `.itemsGrid`：商品网格布局（响应式，已优化性能）
- `.itemCard`：商品卡片（已优化GPU加速）

## 8. 国际化支持 ✅ 已实现

**所有文本内容已支持中英文**：

**翻译键值**（`locales/zh.json` 和 `locales/en.json`）：
- ✅ 固定卡片标题：`fleaMarket.cardTitle` → `跳蚤市场` / `Flea Market`
- ✅ 页面标题：`fleaMarket.pageTitle` → `跳蚤市场 - 二手交易平台` / `Flea Market - Second-hand Trading Platform`
- ✅ 按钮文本：
  - `fleaMarket.uploadItem` → `出闲置` / `Sell Item`
  - `fleaMarket.myItems` → `我的闲置` / `My Items`
- ✅ 表单标签：商品名称、描述、价格、图片、交易地点、分类、联系方式
- ✅ 须知弹窗：
  - `fleaMarket.noticeTitle` → `跳蚤市场须知` / `Flea Market Notice`
  - `fleaMarket.noticeContent` → 须知说明文本
  - `fleaMarket.noticeRules` → 规则数组（从翻译文件动态读取）
  - `fleaMarket.noticeAgree` → `我已阅读并同意遵守以上规定` / `I have read and agree...`
- ✅ 我的闲置弹窗：
  - `fleaMarket.myItemsModalTitle` → `我的闲置` / `My Items`
  - `fleaMarket.myPostedItems` → `我挂上的闲置` / `My Posted Items`
  - `fleaMarket.myPurchasedItems` → `我收的闲置` / `My Purchased Items`
- ✅ 空状态提示、错误消息等

**实现方式**：
- ✅ 使用 `useLanguage` hook 获取翻译函数 `t`
- ✅ 须知规则列表直接从翻译文件导入（`zhTranslations` / `enTranslations`）
- ✅ 所有用户可见文本都使用 `t('fleaMarket.xxx')` 格式

## 9. 前端实现现状

### 9.1 页面结构

**FleaMarketPage.tsx** (`frontend/src/pages/FleaMarketPage.tsx`)

当前页面包含以下主要部分：

1. **导航栏**（与首页一致）
   - 语言切换器（LanguageSwitcher）
   - 通知按钮（NotificationButton）
   - 用户菜单（HamburgerMenu）
   - 登录模态框（LoginModal）

2. **顶部横幅区域**
   - 页面标题和描述
   - "出闲置"按钮（上传商品）
   - "我的闲置"按钮（打开我的闲置弹窗）

3. **搜索和筛选区域**
   - 搜索框（支持关键词搜索，300ms防抖）
   - 分类筛选（下拉选择）

4. **商品列表区域**
   - 网格布局展示商品卡片
   - 无限滚动加载（距离底部200px时自动加载）
   - 加载状态和空状态提示

5. **上传/编辑商品模态框**
   - 商品名称、描述、价格
   - 图片上传（最多5张）
   - 交易地点（城市下拉选择，使用CITIES常量）
   - 商品分类、联系方式

6. **跳蚤市场须知弹窗**
   - 首次进入页面时自动显示
   - 显示规则列表（从翻译文件读取）
   - 必须勾选同意复选框才能确认
   - 使用localStorage记录已查看状态（待后端API实现后改为使用用户表字段）

7. **我的闲置弹窗**
   - 两个标签页："我挂上的闲置"和"我收的闲置"
   - 显示用户发布的商品和购买的商品
   - 支持编辑和删除（仅限自己发布的商品）

### 9.2 性能优化

已实现的性能优化：

1. **React性能优化**
   - `useMemo`：缓存筛选后的商品列表（`filteredItems`）
   - `useCallback`：优化所有事件处理函数
     - `loadItems`：加载商品列表
     - `loadMoreItems`：加载更多商品
     - `handleScroll`：滚动事件处理（使用节流）
     - `uploadImages`：图片上传
     - `handleSubmit`：提交商品
     - `handleDelete`：删除商品
     - `handleEdit`：编辑商品
     - `isOwner`：判断是否为商品所有者
   - `React.memo`：商品卡片组件（`FleaMarketItemCard`）使用memo包装，自定义比较函数
   - `useRef`：存储`loadItems`函数引用，避免循环依赖

2. **滚动优化**
   - 使用`useThrottledCallback`对滚动事件进行节流（100ms）
   - 动态预判加载（距离底部200px时开始加载）
   - `loadingMore`状态管理，避免重复加载

3. **搜索优化**
   - 搜索关键词300ms防抖，减少API请求

4. **CSS性能优化**（`FleaMarketPage.module.css`）
   - GPU加速：`transform: translateZ(0)`, `will-change`
   - 背面可见性：`backface-visibility: hidden`
   - 内容可见性：`content-visibility: auto`（提升长列表滚动性能）
   - 内容隔离：`contain: layout style paint`
   - 过渡优化：使用具体属性而非`all`
   - 图片渲染优化：`image-rendering`属性

### 9.3 功能实现状态

#### 已实现功能 ✅

- [x] 页面布局和导航栏
- [x] 商品列表展示（网格布局）
- [x] 商品搜索（关键词搜索，防抖）
- [x] 商品分类筛选
- [x] 无限滚动加载
- [x] 商品上传表单
- [x] 图片上传（最多5张）
- [x] 城市选择（使用CITIES常量）
- [x] 商品编辑
- [x] 商品删除（软删除）
- [x] 跳蚤市场须知弹窗
- [x] 我的闲置弹窗（两个标签页）
- [x] 性能优化（React.memo, useCallback, useMemo, 滚动节流等）
- [x] CSS性能优化
- [x] 国际化支持（中英文）
- [x] SEO优化（使用SEOHead组件）

#### 待实现功能 ⏳

- [ ] 后端API集成（当前使用localStorage，待改为调用后端API）
  - [ ] 调用`PUT /api/flea-market/agree-notice`更新用户同意时间
  - [ ] 从用户信息API获取`flea_market_notice_agreed_at`字段判断是否显示须知
  - [ ] 调用`GET /api/flea-market/my-purchases`获取用户购买的商品
- [ ] 商品详情页（未来扩展）
- [ ] 购买流程（申请购买、接受购买等）

### 9.4 组件结构

```
FleaMarketPage.tsx
├── SEOHead (SEO标签)
├── Header (导航栏)
│   ├── LanguageSwitcher
│   ├── NotificationButton
│   └── HamburgerMenu
├── LoginModal (登录弹窗)
├── NotificationPanel (通知面板)
├── HeroSection (顶部横幅)
│   ├── "出闲置"按钮
│   └── "我的闲置"按钮
├── FiltersSection (搜索和筛选)
│   ├── Search (搜索框)
│   └── Select (分类筛选)
├── ItemsSection (商品列表)
│   ├── LoadingContainer (加载状态)
│   ├── EmptyContainer (空状态)
│   └── ItemsGrid (商品网格)
│       └── FleaMarketItemCard (商品卡片，使用React.memo)
├── UploadModal (上传/编辑商品弹窗)
├── NoticeModal (须知弹窗)
├── MyItemsModal (我的闲置弹窗)
│   └── Tabs
│       ├── "我挂上的闲置"标签页
│       └── "我收的闲置"标签页
└── PurchaseConfirmModal (购买确认弹窗)
    ├── 商品信息显示
    ├── 议价复选框
    └── 议价输入框（勾选后显示）
```

### 9.5 状态管理

主要状态：

```typescript
// 用户和通知
const [user, setUser] = useState<any>(null);
const [notifications, setNotifications] = useState<any[]>([]);
const [unreadCount, setUnreadCount] = useState(0);
const [showLoginModal, setShowLoginModal] = useState(false);

// 商品列表
const [items, setItems] = useState<FleaMarketItem[]>([]);
const [loading, setLoading] = useState(false);
const [loadingMore, setLoadingMore] = useState(false);
const [searchKeyword, setSearchKeyword] = useState('');
const [debouncedSearchKeyword, setDebouncedSearchKeyword] = useState('');
const [selectedCategory, setSelectedCategory] = useState<string | undefined>(undefined);
const [currentPage, setCurrentPage] = useState(1);
const [hasMore, setHasMore] = useState(true);

// 上传表单
const [showUploadModal, setShowUploadModal] = useState(false);
const [uploading, setUploading] = useState(false);
const [formData, setFormData] = useState({...});
const [imageFiles, setImageFiles] = useState<File[]>([]);
const [editingItem, setEditingItem] = useState<FleaMarketItem | null>(null);

// 须知弹窗
const [showNoticeModal, setShowNoticeModal] = useState(false);
const [noticeAgreed, setNoticeAgreed] = useState(false);

// 我的闲置弹窗
const [showMyItemsModal, setShowMyItemsModal] = useState(false);
const [myPostedItems, setMyPostedItems] = useState<FleaMarketItem[]>([]);
const [myPurchasedItems, setMyPurchasedItems] = useState<FleaMarketItem[]>([]);
const [loadingMyItems, setLoadingMyItems] = useState(false);
```

### 9.6 翻译键值

**国际化key规范**：
- 所有跳蚤市场相关的翻译key统一挂在 `fleaMarket.xxx` 命名空间下
- 新增的弹窗、错误提示、成功消息等，统一使用 `fleaMarket.xxx` 格式
- 避免将新文案散落在 `common.xxx` 或 `errors.xxx` 中
- 示例：`fleaMarket.loadError`, `fleaMarket.purchaseSuccess`, `fleaMarket.refreshSuccess` 等

已添加的翻译键值（`locales/zh.json` 和 `locales/en.json`）：

```json
{
  "fleaMarket": {
    "cardTitle": "跳蚤市场",
    "cardDescription": "在这里可以上传和浏览二手交易商品",
    "pageTitle": "跳蚤市场 - 二手交易平台",
    "pageDescription": "在Link²Ur跳蚤市场浏览和发布二手商品...",
    "uploadItem": "出闲置",
    "myItems": "我的闲置",
    "myItemsModalTitle": "我的闲置",
    "myPostedItems": "我挂上的闲置",
    "myPurchasedItems": "我收的闲置",
    "noPostedItems": "您还没有发布任何闲置商品",
    "noPurchasedItems": "您还没有购买任何闲置商品",
    "noticeTitle": "跳蚤市场须知",
    "noticeContent": "欢迎使用跳蚤市场！为了维护良好的交易环境...",
    "noticeRules": [...], // 规则数组
    "noticeAgree": "我已阅读并同意遵守以上规定",
    "noticeConfirm": "确认",
    // ... 其他翻译键值
  }
}
```

## 10. 开发任务清单

### 10.1 前端任务

#### FleaMarketCard 组件 ✅ 已完成
- [x] 创建 `FleaMarketCard` 组件（`frontend/src/components/FleaMarketCard.tsx`）
- [x] 接入 i18n（标题 + 描述，使用 `fleaMarket.cardTitle` 和 `fleaMarket.cardDescription`）
- [x] 点击跳转 `/${lang}/flea-market`（使用 `useNavigate` 和 `useLanguage`）
- [x] 样式设计：视频背景、响应式布局、特殊标识（绿色主题、✨标识）
- [x] 使用 `TaskType.SecondHandAndRental` 枚举常量

#### Tasks.tsx 集成 ✅ 已完成
- [x] 引入 `TaskType` 枚举
- [x] 在 `filters.type === TaskType.SecondHandAndRental` 时插入固定卡片
- [x] `handleCardClick` 增加 `'flea-market-card'` 分支，跳转到跳蚤市场页面
- [x] 使用 `useMemo` 优化 `displayTasks` 逻辑（避免引用混淆）
- [x] 支持虚拟滚动和网格布局

#### FleaMarketPage 页面
- [x] 布局（列表 + 上传入口）
- [x] 调用 `GET /api/flea-market/items`（分页 + 搜索 + 筛选）
- [x] 商品卡片组件（图片、标题、价格、状态）
- [x] 上传商品表单
  - [x] 复用图片上传 API，获得 URL
  - [x] 调用 `POST /api/flea-market/items`
- [x] 编辑商品
  - [x] 调用 `PUT /api/flea-market/items/:id`
- [x] 删除商品（软删除）
  - [x] 调用 `PUT /api/flea-market/items/:id`，设置 `status='deleted'`
- [x] 导航栏（与首页一致）
- [x] 跳蚤市场须知弹窗
- [x] 我的闲置弹窗（两个标签页）
- [x] 城市选择（使用CITIES常量）
- [x] 无限滚动加载
- [x] 搜索防抖
- [x] 性能优化（React.memo, useCallback, useMemo等）
- [x] CSS性能优化

#### 交互增强
- [x] 加载/错误状态处理
- [x] 空列表占位 UI（"暂无商品"）
- [x] 表单校验（必填字段、价格必须大于0）
- [x] 上传时禁用重复提交（按钮 loading / 防抖）
- [x] API 异常时，统一用项目现有的 toast / 全局错误组件提示

#### SEO & 国际化
- [x] 使用 `SEOHead` 组件设置 title / description / og 标签
- [x] 全部文案接入现有翻译系统（`fleaMarket.*` namespace）

#### 后端API集成（待完成）
- [ ] 调用 `PUT /api/flea-market/agree-notice` 更新用户同意时间
- [ ] 从用户信息API获取 `flea_market_notice_agreed_at` 字段判断是否显示须知
- [ ] 调用 `GET /api/flea-market/my-purchases` 获取用户购买的商品
- [ ] 移除前端localStorage的使用，改为使用后端API

#### 购买流程功能（待完成）
- [ ] 购买确认弹窗（PurchaseConfirmModal）
  - [ ] 显示商品名称和价格
  - [ ] 议价复选框
  - [ ] 议价输入框（勾选后显示）
- [ ] 直接购买功能（无议价）
  - [ ] 调用 `POST /api/flea-market/items/:id/direct-purchase`
  - [ ] 直接创建进行中的任务
- [ ] 议价购买功能
  - [ ] 调用 `POST /api/flea-market/items/:id/purchase-request`（包含议价金额）
  - [ ] 创建购买申请记录
  - [ ] 等待卖家同意/拒绝/再议价
- [ ] 移除前端联系方式字段
  - [ ] 上传/编辑表单中移除联系方式输入框
  - [ ] API请求中不包含联系方式字段

### 10.2 后端任务

#### 表结构 & 迁移
- [ ] 创建 `flea_market_items` 表（按文档 DDL，包含 `location`、`view_count`、`refreshed_at` 字段）
- [ ] 更新 `users` 表，添加 `flea_market_notice_agreed_at` 字段
- [ ] **必建**：创建 `flea_market_purchase_requests` 表（用于议价购买流程）
- [ ] 添加单列索引（seller_id, status, category, created_at, price, refreshed_at, view_count）
- [ ] 添加复合索引（性能优化）：
  - `(status, refreshed_at DESC)` - 用于列表查询和排序
  - `(status, category, refreshed_at DESC)` - 用于分类筛选
  - `(status, location, refreshed_at DESC)` - 用于城市筛选（可选）
- [ ] 添加全文搜索索引（title, description，使用 'simple' 分词）
- [ ] 添加触发器（自动更新 updated_at）

#### ORM 定义
- [ ] `FleaMarketItem` 模型（含 `seller` 关系）
- [ ] 添加 `relationship` 的 import
- [ ] Pydantic schema 对 `images: List[str]` 做 JSON 字段转换

#### 商品 API
- [ ] `GET /api/flea-market/items`（分页 + 筛选 + 搜索，返回hasMore字段）
- [ ] `GET /api/flea-market/items/:id`（商品详情，自动增加浏览量，无需单独的POST /view接口）
- [ ] `POST /api/flea-market/items`（需要登录，自动用当前用户作 `seller_id`）
- [ ] `PUT /api/flea-market/items/:id`（编辑/下架共用，根据Body内容判断操作类型）
- [ ] `POST /api/flea-market/items/:id/refresh`（刷新商品，重置自动删除计时器）
- [ ] 权限校验：仅当 `seller_id === 当前登录用户id` 时，允许编辑/删除/刷新

#### 须知同意 API
- [ ] `PUT /api/flea-market/agree-notice`（需要登录，更新用户 `flea_market_notice_agreed_at` 字段）
- [ ] 获取用户信息时返回 `flea_market_notice_agreed_at` 字段

#### 购买流程 API
- [ ] `POST /api/flea-market/items/:id/direct-purchase`（直接购买，无议价，直接创建任务）
  - [ ] 事务内：创建任务 + 更新商品为 `sold`
  - [ ] 带条件的 `WHERE status='active'` 来防止并发超卖
  - [ ] 任务创建时设置 `is_flexible=1`, `deadline=NULL`
  - [ ] 任务创建时 `location` 从商品表复制（如果为空则默认为"Online"）
  - [ ] 任务创建时 `task_type` 使用 `TaskType.SecondHandAndRental` 枚举
  - [ ] 任务创建时字段映射规则见4.4节（title、description合并规则等）
  - [ ] **ID格式化**：返回给前端时，将所有跳蚤市场相关ID格式化为 `S + 数字` 格式
    - 商品ID：数据库ID 1234 → 返回 `S1234`
    - 购买申请ID：数据库ID 1234 → 返回 `S1234`
    - 任务ID：数据库ID 1234 → 返回 `S1234`
    - 实现方式：参考 `id_generator.py` 的模式，添加 `format_flea_market_id(db_id: int) -> str` 函数
    - 函数示例：`def format_flea_market_id(db_id: int) -> str: return f"S{db_id:04d}"`
  - [ ] **不走购买申请表**（直接购买不创建申请记录）
- [ ] `POST /api/flea-market/items/:id/purchase-request`（创建议价申请）
  - [ ] 创建购买申请记录（`flea_market_purchase_requests` 表）
  - [ ] 验证：一个买家对同一个商品只能有一个pending状态的申请
  - [ ] **ID格式化**：返回给前端时，将购买申请ID格式化为 `S + 数字` 格式（如：数据库ID 1234 → 返回 `S1234`）
- [ ] `POST /api/flea-market/items/:id/accept-purchase`（接受购买，创建任务）：
  - [ ] 事务内：创建任务 + 更新商品为 `sold` + 更新申请状态
  - [ ] 带条件的 `WHERE status='active'` 来防止并发超卖
  - [ ] 任务创建时设置 `is_flexible=1`, `deadline=NULL`
  - [ ] 任务创建时 `location` 从商品表复制（如果为空则默认为"Online"）
  - [ ] 任务创建时 `task_type` 使用 `TaskType.SecondHandAndRental` 枚举
  - [ ] 任务创建时字段映射规则见4.4节（title、description合并规则等）
  - [ ] **ID格式化**：返回给前端时，将所有跳蚤市场相关ID格式化为 `S + 数字` 格式（商品ID、购买申请ID、任务ID）

#### 安全 & 校验
- [ ] 所有修改类接口都校验登录
- [ ] 对价格、状态、ID 做基本验证
- [ ] 对搜索 keyword 做最基本的长度 / 清洗处理

#### 存储空间优化（重要）
- [ ] **任务完成后清理商品图片**：
  - [ ] 在 `cleanup_completed_tasks_files` 函数中，添加清理关联商品图片的逻辑
  - [ ] 通过 `flea_market_items.sold_task_id` 找到关联的商品
  - [ ] 清理商品图片目录（`uploads/flea_market/{item_id}/`）
  - [ ] 确保任务完成后超过3天，商品图片也会被清理，避免永久占用存储空间

## 11. 权限与安全

### 11.1 权限验证规则

**写操作必须检查 owner**：

| 操作 | 权限验证规则 | 错误处理 |
|------|------------|---------|
| 编辑商品 | `seller_id === current_user_id` | 403 Forbidden |
| 删除商品 | `seller_id === current_user_id` | 403 Forbidden |
| 刷新商品 | `seller_id === current_user_id` | 403 Forbidden |
| 接受购买申请 | `item.seller_id === current_user_id` 且 `purchase_request.item_id` 属于该 seller | 403 Forbidden |
| 提交购买申请 | 需登录（`current_user_id` 存在） | 401 Unauthorized |

**权限验证补充**：
- **accept-purchase 权限检查**：需要同时检查：
  1. 当前用户是 `item.seller`
  2. 该 `purchase_request.item_id` 属于该 seller
- **my-purchases 查询安全**：查询时只用 `current_user_id` 过滤 `poster_id`，不要信任任何来自客户端的 `userId` 参数

**未登录用户**：
- ✅ 可以浏览商品列表（`GET /api/flea-market/items`）
- ✅ 可以查看商品详情（`GET /api/flea-market/items/:id`）
- ❌ 无法上传/编辑/删除商品
- ❌ 无法提交购买申请

**登录用户**：
- ✅ 可以上传商品（自动用当前用户作为 `seller_id`）
- ✅ 仅能编辑/删除自己发布的商品（后端通过 `seller_id` 验证）
- ✅ 可以提交购买申请
- ❌ 无法编辑/删除他人发布的商品

### 11.2 敏感字段处理

**contact 字段不回传**：
- ✅ **所有对外API（包含列表和详情）都不返回 `contact` 字段**
- ✅ 即使数据库中有 `contact` 字段，API响应中也不应包含
- ✅ 前端不应请求或显示 `contact` 字段

**避免通过错误信息泄露数据**：
- ✅ 当未登录或不是 owner 操作时，统一返回类似"无权限"或"资源不存在"
- ❌ 不要区分太细（如"您不是该商品的卖家"），以免被用来探测资源存在性
- ✅ 建议统一返回 404 或 403，不暴露具体原因

### 11.3 状态机约束

**后端实现注意事项**：

1. **购买流程前状态校验**：
   - `direct-purchase` / `accept-purchase` 前先校验：`item.status == 'active'`
   - 避免对 `deleted`/`sold` 继续创建任务
   - 如果商品状态不是 `active`，返回 409 错误（错误码：`ITEM_ALREADY_SOLD` 或 `ITEM_NOT_FOUND`）

2. **编辑接口状态限制**：
   - 拒绝对 `sold`/`deleted` 的编辑（返回 409 或 403）
   - `sold` 状态的商品不允许编辑任何核心字段
   - `deleted` 状态的商品不允许编辑

3. **状态流转原子性**：
   - 创建任务 + 更新商品状态必须在同一个事务中完成
   - 使用条件更新 `WHERE status='active'` 防止并发超卖

### 11.4 并发场景处理

**潜在并发问题**：

1. **两个买家几乎同时 direct-purchase 同一个 item**：
   - 使用数据库事务 + 条件更新 `WHERE status='active'` 防止超卖
   - 第一个请求成功后，第二个请求会因条件更新失败而返回 409 错误

2. **一个买家 direct-purchase 的同时，另一个通过 purchase-request + accept-purchase 走议价**：
   - 同样使用条件更新 `WHERE status='active'` 防止超卖
   - 先完成的事务会成功，后完成的事务会失败并返回 409 错误

**解决建议**（在文档中提醒后端）：

- **方案1（推荐）**：在 `tasks` 表里约定"一个 item 只能对应 0 或 1 个 SecondHandAndRental 类型任务"，如果已有则 `direct`/`accept` 都返回冲突
- **方案2（已采用）**：在 `flea_market_items` 增加 `sold_task_id` 字段，创建任务后更新该字段，用于关联查询
- **核心原则**：所有状态变更操作必须使用条件更新，确保原子性

### 11.5 数据安全

- ✅ 所有修改类接口都需要验证登录状态（401）
- ✅ 所有写操作都需要验证权限（403）
- ✅ 使用参数验证防止SQL注入、XSS等安全问题
- ✅ 图片上传需要验证文件类型和大小限制

## 12. 注意事项

1. **固定卡片标识**: 使用特殊的ID（如 `'flea-market-card'`）来区分固定卡片和普通任务
2. **路由跳转**: 确保路由跳转时保留语言前缀，统一使用 `/flea-market` 作为路径前缀
3. **数据持久化**: 商品数据存储在服务端数据库，前端仅缓存最近搜索条件/筛选项到 localStorage（不缓存商品本身）
4. **图片上传流程**: 
   - 前端先调用图片上传API上传File，获取URL
   - 再将URL数组提交到商品上传API
   - 图片字段为图片URL数组，不是File对象
5. **权限控制**: 详见第11节"权限与安全"
6. **SEO优化**: 
   - ✅ 已使用 `SEOHead` 组件设置SEO标签
   - 需要设置的标签：
     - `<title>`: 页面标题
     - `<meta name="description">`: 页面描述
     - Open Graph标签：`og:title`, `og:description`, `og:image` 等
7. **图片存储**：
   - 商品图片存储在特定文件夹中（如 `uploads/flea_market/{item_id}/`）
   - 与任务图片存储方式一致，方便删除
   - 删除商品时同时删除图片文件
8. **自动删除机制**：
   - 商品发布者超过10天未刷新商品，系统自动删除
   - **删除操作**（软删除）：
     - 更新商品状态为 `'deleted'`（保留DB记录，不物理删除数据库行）
     - 删除图片文件（从文件系统中物理删除）
   - 使用定时任务（如Celery Beat）每天执行一次

## 13. 测试与QA场景清单

### 13.1 商品生命周期测试

#### 创建商品
- [ ] **必填字段校验**：不提供 `title`、`description`、`price` 应返回 400 错误
- [ ] **价格校验**：价格为负数或0应返回 400 错误
- [ ] **图片上传**：最多5张图片，超过应提示错误
- [ ] **图片格式**：验证图片格式（jpg、png等）和大小限制
- [ ] **创建成功**：创建后商品状态为 `active`，`refreshed_at` 和 `created_at` 为当前时间

#### 编辑商品
- [ ] **修改标题**：可以修改商品标题
- [ ] **修改价格**：可以修改商品价格（必须大于0）
- [ ] **修改分类**：可以修改商品分类
- [ ] **修改图片**：可以替换/删除图片
- [ ] **权限验证**：非商品所有者无法编辑（返回 403）
- [ ] **已售出商品**：`sold` 状态的商品不允许编辑（返回 400 或 403）

#### 删除商品
- [ ] **软删除**：删除后商品状态变为 `deleted`，但数据库记录保留
- [ ] **列表隐藏**：删除后商品不再出现在列表中（`status='active'` 筛选）
- [ ] **详情不可见**：删除后访问详情接口应返回 404
- [ ] **权限验证**：非商品所有者无法删除（返回 403）

#### 刷新商品
- [ ] **刷新时间更新**：刷新后 `refreshed_at` 更新为当前时间
- [ ] **排序位置**：刷新后商品在列表中位置上浮（按 `refreshed_at DESC` 排序）
- [ ] **创建时间不变**：刷新后 `created_at` 保持不变
- [ ] **刷新频率限制**：如果实现24小时限制，短时间多次刷新应提示错误
- [ ] **权限验证**：非商品所有者无法刷新（返回 403）

### 13.2 购买流程测试

#### 正常流程
- [ ] **A发布商品 → B提交申请 → A接受 → 任务创建成功 → 商品标为sold**
  - [ ] 商品创建后状态为 `active`
  - [ ] B提交购买申请后，申请状态为 `pending`
  - [ ] A接受申请后，任务创建成功，商品状态变为 `sold`
  - [ ] 任务状态为 `in_progress`，`poster_id` 为B，`taker_id` 为A

#### 多人并发申请
- [ ] **B、C同时提交申请**：
  - [ ] B和C都能成功创建 `pending` 状态的申请
  - [ ] A接受B的申请后，C的申请自动变为 `rejected`
  - [ ] 商品状态变为 `sold`，不再接受新的申请

#### 重复点击处理
- [ ] **B连点"提交申请"按钮**：
  - [ ] 第一次提交成功，创建 `pending` 申请
  - [ ] 第二次提交返回 409 错误，提示"您已提交购买申请"
- [ ] **A连点"接受"按钮**：
  - [ ] 第一次接受成功，创建任务，商品变为 `sold`
  - [ ] 第二次接受返回最终状态，不再重复创建任务（幂等性）

#### 已售出商品的行为
- [ ] **已售出商品不再接受申请**：
  - [ ] 商品状态为 `sold` 时，提交购买申请应返回 409 错误
  - [ ] 直接购买已售出商品应返回 409 错误
- [ ] **列表展示**（如果展示已售出商品）：
  - [ ] 需加"已售出"标记
  - [ ] 默认列表不显示 `sold` 状态的商品

### 13.3 自动删除与图片测试

#### 自动删除任务
- [ ] **准备测试数据**：
  - [ ] 创建一条 `refreshed_at` 超过10天、`status='active'` 的商品
  - [ ] 创建一条 `refreshed_at` 超过10天、`status='sold'` 的商品（不应被删除）
- [ ] **执行定时任务**：
  - [ ] `active` 状态的商品被删除（状态变为 `deleted`）
  - [ ] `sold` 状态的商品**不被删除**（状态保持 `sold`）
  - [ ] 商品图片文件被物理删除
- [ ] **验证结果**：
  - [ ] 被删除的商品不再出现在列表中
  - [ ] 访问被删除商品的详情应返回 404
  - [ ] 图片文件已从文件系统中删除

#### 图片共享测试
- [ ] **商品创建任务后，图片路径不变**：
  - [ ] 商品A的图片路径为 `uploads/flea_market/123/img1.jpg`
  - [ ] 商品A被购买后创建任务，任务中的图片URL与商品一致
  - [ ] 商品A被删除后，如果任务仍在使用，图片文件不应被删除（或需要额外判断）

### 13.4 搜索与筛选测试

- [ ] **关键词搜索**：输入关键词，返回匹配的商品
- [ ] **分类筛选**：选择分类，只显示该分类的商品
- [ ] **城市筛选**：选择城市，只显示该城市的商品
- [ ] **组合筛选**：同时使用关键词、分类、城市筛选
- [ ] **分页**：验证分页功能，`hasMore` 字段正确

### 13.5 权限与安全测试

- [ ] **未登录访问**：
  - [ ] 可以访问列表和详情
  - [ ] 无法上传/编辑/删除商品
  - [ ] 无法提交购买申请
- [ ] **跨用户操作**：
  - [ ] 用户A无法编辑用户B的商品（返回 403）
  - [ ] 用户A无法删除用户B的商品（返回 403）
  - [ ] 用户A无法接受用户B商品的购买申请（返回 403）

## 14. 未来扩展

### 14.1 商品详情页
- **路由**: `/${lang}/flea-market/:id`
- **功能**: 展示商品详细信息、图片轮播、联系发布者等

### 14.2 后端API集成（待完成）
- ⏳ 调用 `PUT /api/flea-market/agree-notice` 更新用户同意时间
- ⏳ 从用户信息API获取 `flea_market_notice_agreed_at` 字段判断是否显示须知
- ⏳ 调用 `GET /api/flea-market/my-purchases` 获取用户购买的商品
- ⏳ 移除前端localStorage的使用，改为使用后端API

### 14.3 搜索与标签增强
- ⏳ **标签系统**：为商品添加标签（如"全新"、"九成新"等）
- ⏳ **高级搜索**：按价格区间、发布时间范围、浏览量等筛选
- ⏳ **搜索优化**：全文搜索优化（如果使用PostgreSQL，可考虑中文分词）

### 14.4 状态扩展
- ⏳ **reserved状态**：已有人下单但未完成任务（预留状态）
- ⏳ **状态流转优化**：更细粒度的状态管理

### 14.5 举报与风控
- ⏳ **举报接口**：用户举报违规商品
- ⏳ **手动下架**：管理员手动下架商品（`status='blocked'`）
- ⏳ **自动风控**：基于举报数量、用户行为等自动下架

### 14.6 统计与报表
- ⏳ **每日发布量**：统计每日新发布的商品数量
- ⏳ *转化率分析**：浏览 → 申请 → 成交的转化率
- ⏳ ***成交量统计**：统计每日/每周/每月的成交量
- ⏳ **热门商品**：基于浏览量、申请数等推荐热门商品

### 14.7 其他功能
- ✅ 商品搜索和筛选功能（已实现）
- ⏳ 用户收藏功能
- ⏳ 商品评论和评分
- ⏳ 交易记录管理
- ⏳ 消息通知功能
- ✅ 商品状态管理（已售出、已下架等，已预留 `status` 字段）
- ⏳ 购买流程（直接购买或议价购买）
  - ⏳ 购买确认弹窗（包含议价选项）
  - ⏳ 直接购买API（无议价，直接创建任务）
  - ⏳ 议价购买API（走申请表流程）
  - ⏳ 卖家接受/拒绝/再议价功能
  - ⏳ 买家取消申请功能

