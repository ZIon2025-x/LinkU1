# 跳蚤市场固定任务卡片开发文档

## 1. 功能概述

在任务列表页面（Tasks页面）中，当用户点击"二手任务类型"（Second-hand & Rental）时，会在任务列表的第一个位置显示一个固定的"跳蚤市场"任务卡片。点击该卡片后，会跳转到一个专门的二手交易页面，用户可以在该页面上传和管理二手交易商品。

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

#### 2.2.1 FleaMarketCard 组件
- **位置**: `frontend/src/components/FleaMarketCard.tsx`
- **功能**: 显示固定的跳蚤市场卡片
- **样式**: 与普通TaskCard保持一致，但具有特殊标识
- **交互**: 点击后跳转到 `/${lang}/flea-market` 路由（需带语言前缀）

#### 2.2.2 FleaMarketPage 组件
- **位置**: `frontend/src/pages/FleaMarketPage.tsx`
- **功能**: 二手交易商品展示和管理页面
- **主要功能**:
  - 商品列表展示
  - 商品上传表单
  - 商品编辑和删除
  - 商品搜索和筛选

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
const fleaMarketCard = {
  id: 'flea-market-card', // 特殊ID，用于识别固定卡片
  title: '跳蚤市场', // 或 'Flea Market'
  description: '在这里可以上传和浏览二手交易商品',
  task_type: 'Second-hand & Rental',
  location: 'Online',
  task_level: 'normal',
  // ... 其他必要字段
};
```

### 3.2 条件渲染逻辑

```typescript
// 在Tasks.tsx中
import { TaskType } from '../constants/taskTypes';

const displayTasks = useMemo(() => {
  let tasks = filteredTasks;
  
  // 如果选择了二手任务类型，在第一个位置插入固定卡片
  if (filters.type === TaskType.SecondHandAndRental) {
    tasks = [fleaMarketCard, ...tasks];
  }
  
  return tasks;
}, [filteredTasks, filters.type]);
```

### 3.3 点击处理

```typescript
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

## 4. 二手交易页面功能

### 4.1 数据流设计

**页面加载流程**：
1. 组件挂载时调用 `GET /api/flea-market/items` 获取商品列表
2. 支持分页：`GET /api/flea-market/items?page=1&pageSize=20`
3. 支持搜索和筛选：`GET /api/flea-market/items?keyword=xxx&category=yyy&page=1&pageSize=20`
4. 只显示 `status='active'` 的商品（在售商品）

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

### 4.2 页面布局

```
┌─────────────────────────────────────┐
│  跳蚤市场 / Flea Market              │
├─────────────────────────────────────┤
│  [上传商品] 按钮                     │
├─────────────────────────────────────┤
│  商品列表（网格布局）                │
│  ┌────┐ ┌────┐ ┌────┐              │
│  │商品1│ │商品2│ │商品3│              │
│  └────┘ └────┘ └────┘              │
└─────────────────────────────────────┘
```

### 4.3 商品上传表单

表单字段：
- 商品名称（必填）
- 商品描述（必填）
- 价格（必填，单位：GBP）
- 商品图片（支持多张，最多5张）
- 商品分类（可选）
- 联系方式（可选）

### 4.4 商品数据结构

**商品数据结构**（flea_market_items表）：
```typescript
interface FleaMarketItem {
  id: number;
  title: string;              // 商品名称
  description: string;         // 商品描述
  price: number;              // 标价（GBP）
  currency: 'GBP';            // 货币类型，固定为GBP
  images: string[];           // 图片URL数组（注意：不是File对象）
  category?: string;          // 商品分类
  contact?: string;           // 联系方式
  status: 'active' | 'sold' | 'deleted';  // 商品状态
  seller_id: string;          // 卖家ID（提供商品的人）
  created_at: string;         // ISO 8601格式，例如 '2025-11-19T12:00:00Z'
  updated_at: string;         // 更新时间
}
```

**任务数据结构**（交易达成后在tasks表中创建）：
```typescript
interface Task {
  id: number;
  title: string;              // 商品名称（从flea_market_items复制）
  description: string;         // 商品描述（从flea_market_items复制）
  reward: number;             // 最终成交价（可能经过议价）
  base_reward: number;        // 商品原始标价（从flea_market_items.price复制）
  currency: 'GBP';            // 货币类型
  images: string[];           // 图片URL数组（从flea_market_items复制）
  location: string;           // 商品位置
  task_type: 'Second-hand & Rental';  // 固定任务类型
  poster_id: string;          // 买家ID（付钱的人）
  taker_id: string;            // 卖家ID（获得钱的人，从flea_market_items.seller_id复制）
  status: 'in_progress';      // 直接进入进行中状态
  is_flexible: 1;             // 灵活时间模式（无截止日期）
  deadline: null;              // 无截止日期
  created_at: string;         // 任务创建时间（交易达成时间）
  // ... 其他任务字段
}
```

**字段说明**：
- **商品表**：`seller_id` = 卖家（提供商品的人）
- **任务表**：`poster_id` = 买家（付钱的人），`taker_id` = 卖家（获得钱的人）
- `currency`: 使用字面量类型 `'GBP'`，确保不会传入其他货币类型
- `images`: 存储的是图片URL字符串数组，不是File对象
- `status`: 商品状态独立于任务状态

## 5. 数据库设计

### 5.1 设计方案

**核心设计理念**：
- **保持任务系统的一致性**：`poster_id` 始终是发布者（付钱的人），`taker_id` 始终是接收者（获得任务金额的人）
- **商品交易流程**：
  1. 卖家在 `flea_market_items` 表中发布商品（商品信息）
  2. 买家申请购买（可能包含议价）
  3. 卖家同意购买后，在 `tasks` 表中创建任务：
     - `poster_id` = 买家（付钱的人）
     - `taker_id` = 卖家（获得钱的人）
     - `status` = `'in_progress'`（直接进入进行中状态）
     - `task_type` = `'Second-hand & Rental'`
     - `is_flexible` = `1`（灵活时间模式，无截止日期）
     - `deadline` = `NULL`（无截止日期）

**数据流**：
```
flea_market_items (商品表)
  ↓ 买家申请购买
  ↓ 卖家同意
tasks (任务表) - 创建交易任务
```

### 5.2 表结构设计

#### 5.2.1 二手商品表（flea_market_items）

**表名**: `flea_market_items`

**字段定义**：

| 字段名 | 类型 | 约束 | 说明 |
|--------|------|------|------|
| id | INTEGER | PRIMARY KEY, AUTO_INCREMENT | 商品ID |
| title | VARCHAR(200) | NOT NULL | 商品名称 |
| description | TEXT | NOT NULL | 商品描述 |
| price | DECIMAL(12, 2) | NOT NULL | 标价（GBP） |
| currency | VARCHAR(3) | NOT NULL, DEFAULT 'GBP' | 货币类型，固定为GBP |
| images | TEXT | NULL | JSON数组，存储图片URL列表 |
| category | VARCHAR(100) | NULL | 商品分类 |
| contact | VARCHAR(200) | NULL | 联系方式 |
| status | VARCHAR(20) | NOT NULL, DEFAULT 'active' | 商品状态：active, sold, deleted |
| seller_id | VARCHAR(8) | NOT NULL, FOREIGN KEY | 卖家ID，关联users表 |
| created_at | TIMESTAMPTZ | NOT NULL, DEFAULT NOW() | 创建时间（UTC） |
| updated_at | TIMESTAMPTZ | NOT NULL, DEFAULT NOW() | 更新时间（UTC） |

**注意**：
- `seller_id` 是卖家（提供商品的人，未来会成为任务的 `taker_id`）
- 商品状态独立于任务状态
- 当商品售出后，会在 `tasks` 表中创建对应的任务记录

#### 5.2.2 SQL DDL

```sql
CREATE TABLE flea_market_items (
    id SERIAL PRIMARY KEY,
    title VARCHAR(200) NOT NULL,
    description TEXT NOT NULL,
    price DECIMAL(12, 2) NOT NULL CHECK (price >= 0),
    currency VARCHAR(3) NOT NULL DEFAULT 'GBP' CHECK (currency = 'GBP'),
    images TEXT,  -- JSON数组，例如：'["url1", "url2"]'
    category VARCHAR(100),
    contact VARCHAR(200),
    status VARCHAR(20) NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'sold', 'deleted')),
    seller_id VARCHAR(8) NOT NULL REFERENCES users(id) ON DELETE CASCADE,  -- 卖家ID
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 索引
CREATE INDEX idx_flea_market_items_seller_id ON flea_market_items(seller_id);
CREATE INDEX idx_flea_market_items_status ON flea_market_items(status);
CREATE INDEX idx_flea_market_items_category ON flea_market_items(category);
CREATE INDEX idx_flea_market_items_created_at ON flea_market_items(created_at DESC);
CREATE INDEX idx_flea_market_items_price ON flea_market_items(price);

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

#### 5.2.3 ORM模型定义（SQLAlchemy）

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
    category = Column(String(100), nullable=True)
    contact = Column(String(200), nullable=True)
    status = Column(String(20), nullable=False, default="active")
    seller_id = Column(String(8), ForeignKey("users.id", ondelete="CASCADE"), nullable=False)  # 卖家ID
    created_at = Column(DateTime(timezone=True), default=get_utc_time, server_default=func.now())
    updated_at = Column(DateTime(timezone=True), default=get_utc_time, onupdate=get_utc_time, server_default=func.now())
    
    # 关系
    seller = relationship("User", backref="flea_market_items")  # 卖家关系
    
    __table_args__ = (
        Index("idx_flea_market_items_seller_id", seller_id),
        Index("idx_flea_market_items_status", status),
        Index("idx_flea_market_items_category", category),
        Index("idx_flea_market_items_created_at", created_at.desc()),
        Index("idx_flea_market_items_price", price),
        CheckConstraint("price >= 0", name="check_price_positive"),
        CheckConstraint("currency = 'GBP'", name="check_currency_gbp"),
        CheckConstraint("status IN ('active', 'sold', 'deleted')", name="check_status_valid"),
    )
```

#### 5.2.4 数据存储说明

1. **images字段**：
   - 存储格式：JSON数组字符串，例如：`'["https://example.com/img1.jpg", "https://example.com/img2.jpg"]'`
   - **ORM层处理建议**：在 Pydantic schema / service 层做 `images: List[str]` 与数据库字符串之间的序列化/反序列化，避免在业务代码里到处手动 `json.loads`/`json.dumps`
   - 如果使用PostgreSQL，可以考虑使用JSONB类型以获得更好的查询性能

2. **status字段**：
   - `active`: 正常在售商品
   - `sold`: 已售出（保留记录，但不显示在列表中）
   - `deleted`: 已删除（软删除，保留记录）

3. **外键关系**：
   - `seller_id` 关联 `users.id`，使用 `ON DELETE CASCADE`，用户删除时自动删除其发布的商品

4. **索引说明**：
   - `seller_id`: 用于查询卖家发布的商品
   - `status`: 用于筛选活跃商品（默认只显示status='active'）
   - `category`: 用于分类筛选
   - `created_at`: 用于按时间排序
   - `price`: 用于价格排序和筛选
   - 全文搜索索引：用于标题和描述的搜索功能

### 5.3 购买申请表设计（可选）

**表名**: `flea_market_purchase_requests`

**字段定义**：

| 字段名 | 类型 | 约束 | 说明 |
|--------|------|------|------|
| id | INTEGER | PRIMARY KEY, AUTO_INCREMENT | 申请ID |
| item_id | INTEGER | NOT NULL, FOREIGN KEY | 商品ID，关联flea_market_items表 |
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
- 如果不需要记录申请历史，也可以简化设计，直接在商品表中记录当前申请信息

**简化方案**（如果不需要申请历史）：
- 不创建独立的购买申请表
- 在商品表中添加 `pending_buyer_id` 和 `pending_price` 字段
- 卖家接受后直接创建任务，清空这些字段

### 5.4 数据迁移

如果使用Alembic进行数据库迁移：

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
        sa.Column('category', sa.String(100), nullable=True),
        sa.Column('contact', sa.String(200), nullable=True),
        sa.Column('status', sa.String(20), nullable=False, server_default='active'),
        sa.Column('seller_id', sa.String(8), nullable=False),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
        sa.Column('updated_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
        sa.ForeignKeyConstraint(['seller_id'], ['users.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index('idx_flea_market_items_seller_id', 'flea_market_items', ['seller_id'])
    op.create_index('idx_flea_market_items_status', 'flea_market_items', ['status'])
    op.create_index('idx_flea_market_items_category', 'flea_market_items', ['category'])
    op.create_index('idx_flea_market_items_created_at', 'flea_market_items', ['created_at'], postgresql_ops={'created_at': 'DESC'})
    op.create_index('idx_flea_market_items_price', 'flea_market_items', ['price'])

def downgrade():
    op.drop_index('idx_flea_market_items_price', table_name='flea_market_items')
    op.drop_index('idx_flea_market_items_created_at', table_name='flea_market_items')
    op.drop_index('idx_flea_market_items_category', table_name='flea_market_items')
    op.drop_index('idx_flea_market_items_status', table_name='flea_market_items')
    op.drop_index('idx_flea_market_items_seller_id', table_name='flea_market_items')
    op.drop_table('flea_market_items')
```

## 6. 后端API设计

### 6.1 商品列表API
```
GET /api/flea-market/items
Query参数:
  - page: 页码
  - pageSize: 每页数量
  - category: 分类筛选
  - keyword: 关键词搜索
  - status: 商品状态（默认只返回'active'）
```

**商品上传API**：

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
  - category?: string
  - contact?: string
```

**重要说明**：
- `images` 字段为图片URL数组，不是File对象
- 图片上传复用现有的图片上传API，前端先上传图片再提交URL
- 后端不需要处理文件上传，只需要存储URL数组

### 6.3 商品管理API

**商品编辑API**：
```
PUT /api/flea-market/items/:id
Headers:
  - Authorization: Bearer <token>  // 需要登录
Body:
  - title?: string
  - description?: string
  - price?: number
  - images?: string[]
  - category?: string
  - contact?: string
```

**商品删除/下架API**：
```
PUT /api/flea-market/items/:id
Headers:
  - Authorization: Bearer <token>  // 需要登录
Body:
  - status: 'deleted'  // 下架商品（软删除）
```

**权限验证**：
- 编辑/删除操作需要验证：`seller_id === 当前登录用户id`
- 只有商品发布者（卖家）才能编辑/删除自己的商品

### 6.4 商品购买流程API

**买家申请购买API**：
```
POST /api/flea-market/items/:id/purchase-request
Headers:
  - Authorization: Bearer <token>  // 需要登录
Body:
  - proposed_price?: number  // 议价金额（可选，如果不提供则使用商品标价）
  - message?: string  // 购买留言（可选）
```

**卖家接受购买API**（创建任务）：
```
POST /api/flea-market/items/:id/accept-purchase
Headers:
  - Authorization: Bearer <token>  // 需要登录
Body:
  - purchase_request_id: number  // 购买申请ID
  - agreed_price?: number  // 最终成交价（如果卖家再次议价）
```

**流程说明**：
1. 买家调用 `purchase-request` API申请购买（可包含议价）
   - 创建购买申请记录（如果使用购买申请表）
2. 卖家调用 `accept-purchase` API接受购买
3. 后端自动执行（**必须在同一个数据库事务中完成**）：
   - 在 `tasks` 表中创建任务：
     - `poster_id` = 买家ID
     - `taker_id` = 卖家ID（从 `flea_market_items.seller_id` 获取）
     - `status` = `'in_progress'`
     - `reward` = 最终成交价（可能经过议价）
     - `base_reward` = 商品原始标价
     - `is_flexible` = `1`（灵活时间模式，无截止日期）
     - `deadline` = `NULL`（无截止日期）
   - 更新商品状态：`flea_market_items.status` = `'sold'`
   - 更新购买申请状态：`flea_market_purchase_requests.status` = `'accepted'`（如果使用购买申请表）

**重要**：创建任务 + 更新 `flea_market_items.status` 必须放在一个数据库事务中，保证原子性。避免出现商品变成 `sold` 但任务没创建，或创建了任务但商品还在 `active` 列表里的情况。

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

### 7.2 二手交易页面样式
- 使用与Tasks页面一致的设计语言
- 商品卡片采用网格布局
- 上传表单使用模态框或独立页面

## 8. 国际化支持

所有文本内容需要支持中英文：
- 固定卡片标题：`跳蚤市场` / `Flea Market`
- 页面标题、按钮、表单标签等
- 使用现有的 `useLanguage` hook 和翻译文件

## 9. 开发步骤

1. ✅ 创建开发文档
2. ⬜ 创建 FleaMarketCard 组件
3. ⬜ 在 Tasks.tsx 中集成固定卡片逻辑
4. ⬜ 创建 FleaMarketPage 页面组件
5. ⬜ 添加路由配置
6. ⬜ 实现商品上传功能
7. ⬜ 添加国际化翻译
8. ⬜ 样式优化和响应式适配
9. ⬜ 测试和bug修复

## 10. 注意事项

1. **固定卡片标识**: 使用特殊的ID（如 `'flea-market-card'`）来区分固定卡片和普通任务
2. **路由跳转**: 确保路由跳转时保留语言前缀，统一使用 `/flea-market` 作为路径前缀
3. **数据持久化**: 商品数据存储在服务端数据库，前端仅缓存最近搜索条件/筛选项到 localStorage（不缓存商品本身）
4. **图片上传流程**: 
   - 前端先调用图片上传API上传File，获取URL
   - 再将URL数组提交到商品上传API
   - 图片字段为图片URL数组，不是File对象
5. **权限控制**:
   - **未登录用户**: 只能浏览商品列表，无法上传/编辑/删除
   - **登录用户**: 
     - 可以上传商品
     - 仅能编辑/删除自己发布的商品（后端通过 `seller_id` 验证）
   - 所有需要修改数据的API都需要验证登录状态和用户权限
6. **SEO优化**: 
   - 使用 `react-helmet` 或类似库注入SEO标签
   - 需要设置的标签：
     - `<title>`: 页面标题
     - `<meta name="description">`: 页面描述
     - Open Graph标签：`og:title`, `og:description`, `og:image` 等
   - 示例实现：
     ```typescript
     import { Helmet } from 'react-helmet';
     
     <Helmet>
       <title>{language === 'zh' ? '跳蚤市场 - 二手交易平台' : 'Flea Market - Second-hand Trading'}</title>
       <meta name="description" content={description} />
       <meta property="og:title" content={title} />
       <meta property="og:description" content={description} />
       <meta property="og:image" content={defaultImage} />
     </Helmet>
     ```

## 11. 未来扩展

### 11.1 商品详情页
- **路由**: `/${lang}/flea-market/:id`
- **功能**: 展示商品详细信息、图片轮播、联系发布者等

### 11.2 其他功能
- 商品搜索和筛选功能（已预留API参数）
- 用户收藏功能
- 商品评论和评分
- 交易记录管理
- 消息通知功能
- 商品状态管理（已售出、已下架等，已预留 `status` 字段）

