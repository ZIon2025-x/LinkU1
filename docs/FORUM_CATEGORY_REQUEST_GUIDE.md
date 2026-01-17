# 论坛板块申请功能完善说明

## 已完成的功能

### 1. 后端API

#### 用户申请新建板块
- **端点**: `POST /api/forum/categories/request`
- **权限**: 需登录
- **功能**: 用户提交新建板块申请
- **请求体**:
```json
{
  "name": "板块名称",
  "description": "板块描述（可选）",
  "icon": "图标emoji或URL（可选）",
  "type": "general"
}
```

#### 用户查看自己的申请
- **端点**: `GET /api/forum/categories/requests/my`
- **权限**: 需登录
- **功能**: 查看自己提交的所有板块申请及状态

#### 管理员查看所有申请
- **端点**: `GET /api/forum/categories/requests?status=pending`
- **权限**: 管理员
- **功能**: 查看待审核/已通过/已拒绝的板块申请
- **参数**: `status` (可选): pending, approved, rejected

#### 管理员审核申请
- **端点**: `PUT /api/forum/categories/requests/{request_id}/review?action=approve&review_comment=审核意见`
- **权限**: 管理员
- **功能**: 审核板块申请，通过后自动创建板块
- **参数**:
  - `action` (必填): approve 或 reject
  - `review_comment` (可选): 审核意见

### 2. 数据库

#### ForumCategoryRequest 表
```sql
CREATE TABLE forum_category_requests (
    id SERIAL PRIMARY KEY,
    requester_id VARCHAR(8) NOT NULL REFERENCES users(id),
    name VARCHAR(100) NOT NULL,
    description TEXT,
    icon VARCHAR(200),
    type VARCHAR(20) DEFAULT 'general',
    country VARCHAR(10),
    university_code VARCHAR(50),
    status VARCHAR(20) DEFAULT 'pending',  -- pending, approved, rejected
    admin_id VARCHAR(5) REFERENCES admin_users(id),
    reviewed_at TIMESTAMP WITH TIME ZONE,
    review_comment TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

#### 数据库迁移
执行迁移文件: `backend/migrations/054_add_forum_category_requests_table.sql`

```bash
cd /Users/dyf/Downloads/LinkU1/backend
psql $DATABASE_URL -f migrations/054_add_forum_category_requests_table.sql
```

### 3. iOS 前端

#### 需要手动修改的文件

**文件**: `ios/link2ur/link2ur/Views/Forum/ForumView.swift`

**位置**: `submitRequest()` 方法 (第617-661行)

**需要修改的代码**:

将以下代码:
```swift
// 构建申请数据
let requestData: [String: Any] = [
    "name": categoryName,
    "description": categoryDescription.isEmpty ? nil : categoryDescription,
    "icon": categoryIcon.isEmpty ? nil : categoryIcon,
    "type": "general"
]

// 调用API提交申请
apiService.request(
    [String: Any].self,
    "/api/forum/categories/request",
    method: "POST",
    body: requestData
)
```

**修改为**:
```swift
// 构建申请数据（移除nil值）
var requestData: [String: Any] = [
    "name": categoryName,
    "type": "general"
]

if !categoryDescription.isEmpty {
    requestData["description"] = categoryDescription
}

if !categoryIcon.isEmpty {
    requestData["icon"] = categoryIcon
}

// 调用API提交申请
apiService.request(
    ForumCategoryRequestResponse.self,
    "/api/forum/categories/request",
    method: "POST",
    body: requestData
)
```

同时将 `receiveValue` 闭包中的参数从 `{ _ in` 改为 `{ response in`。

#### 新增的数据模型

已在 `ios/link2ur/link2ur/Models/Forum.swift` 中添加:
- `ForumCategoryRequestResponse`: API响应模型
- `ForumCategoryRequestDetail`: 申请详情模型（包含状态颜色、文本等）

## 功能流程

1. **用户申请**:
   - 用户在论坛页面点击加号按钮
   - 填写板块名称（必填）、描述、图标
   - 提交申请

2. **申请保存**:
   - 后端检查板块名称是否已存在
   - 检查用户是否已有相同名称的待审核申请
   - 保存申请到数据库
   - 返回申请ID

3. **管理员审核**:
   - 管理员查看待审核的申请列表
   - 选择通过或拒绝，可添加审核意见
   - 如果通过，系统自动创建板块
   - 记录审核日志

4. **用户查看状态**:
   - 用户可以查看自己的所有申请及审核状态
   - 显示待审核、已通过、已拒绝等状态

## 下一步优化建议

1. **通知功能**: 审核完成后向用户发送通知
2. **申请历史**: 在用户个人中心显示申请历史
3. **管理后台**: 创建专门的管理界面展示申请列表
4. **申请撤回**: 允许用户撤回待审核的申请
5. **批量审核**: 管理员批量处理多个申请
