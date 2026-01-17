# 板块申请功能完善和优化清单

## 📋 已实现的功能

### ✅ 后端功能
- [x] 用户提交板块申请
- [x] 管理员查看申请列表
- [x] 管理员审核申请（批准/拒绝）
- [x] 批准后自动创建板块
- [x] 输入验证和错误处理
- [x] 重复申请检查
- [x] 管理员操作日志记录

### ✅ 前端功能
- [x] iOS端申请表单
- [x] Web端管理员审核界面
- [x] 状态筛选功能
- [x] 审核模态框

---

## 🔧 需要完善和优化的功能

### 1. ⚠️ **通知功能缺失**（高优先级）

**问题**：审核通过或拒绝后，申请人没有收到通知

**需要实现**：
- [ ] 审核通过时发送通知给申请人
- [ ] 审核拒绝时发送通知给申请人（包含拒绝原因）
- [ ] 使用推送通知和站内通知

**实现位置**：
- `backend/app/forum_routes.py` - `review_category_request` 函数

---

### 2. 📊 **申请人信息缺失**（中优先级）

**问题**：`ForumCategoryRequestOut` 没有包含申请人的姓名和头像

**需要实现**：
- [ ] 在 `ForumCategoryRequestOut` 中添加 `requester_name` 和 `requester_avatar` 字段
- [ ] 在查询时使用 `selectinload` 加载申请人信息
- [ ] 更新 Web 端显示申请人信息

**实现位置**：
- `backend/app/schemas.py` - `ForumCategoryRequestOut`
- `backend/app/forum_routes.py` - `get_category_requests` 和 `get_my_category_requests`

---

### 3. 📄 **分页功能缺失**（中优先级）

**问题**：申请列表没有分页，如果申请数量多会影响性能

**需要实现**：
- [ ] 在 `get_category_requests` 添加分页参数
- [ ] 在 `get_my_category_requests` 添加分页参数
- [ ] Web 端添加分页控件
- [ ] iOS 端支持分页加载

**实现位置**：
- `backend/app/forum_routes.py`
- `frontend/src/pages/AdminDashboard.tsx`
- `ios/link2ur/link2ur/Views/Forum/ForumView.swift`

---

### 4. 🔍 **搜索功能缺失**（低优先级）

**问题**：管理员无法搜索申请

**需要实现**：
- [ ] 添加按板块名称搜索
- [ ] 添加按申请人搜索
- [ ] Web 端添加搜索框

**实现位置**：
- `backend/app/forum_routes.py`
- `frontend/src/pages/AdminDashboard.tsx`

---

### 5. 📱 **iOS端查看我的申请功能缺失**（中优先级）

**问题**：iOS端用户无法查看自己提交的申请状态

**需要实现**：
- [ ] 在 iOS 端添加"我的申请"页面
- [ ] 显示申请列表和状态
- [ ] 显示审核意见（如果已审核）

**实现位置**：
- `ios/link2ur/link2ur/Views/Forum/ForumView.swift` 或新建页面
- `ios/link2ur/link2ur/Services/APIService+Endpoints.swift`

---

### 6. 🛡️ **申请频率限制缺失**（中优先级）

**问题**：没有限制用户提交申请的频率，可能被滥用

**需要实现**：
- [ ] 限制用户每天/每周提交申请的数量
- [ ] 检查用户是否有待审核的申请（已有）
- [ ] 返回友好的错误提示

**实现位置**：
- `backend/app/forum_routes.py` - `request_new_category`

---

### 7. 📝 **申请详情查看功能缺失**（低优先级）

**问题**：管理员无法查看申请的完整详情

**需要实现**：
- [ ] 添加申请详情查看模态框
- [ ] 显示所有申请信息（包括审核历史）

**实现位置**：
- `frontend/src/pages/AdminDashboard.tsx`

---

### 8. 🔄 **排序功能缺失**（低优先级）

**问题**：申请列表只能按创建时间倒序排列

**需要实现**：
- [ ] 支持按状态排序
- [ ] 支持按申请时间排序
- [ ] 支持按审核时间排序

**实现位置**：
- `backend/app/forum_routes.py`
- `frontend/src/pages/AdminDashboard.tsx`

---

### 9. ✏️ **审核意见显示优化**（低优先级）

**问题**：审核模态框没有显示已有的审核信息（如果已审核）

**需要实现**：
- [ ] 如果申请已审核，显示审核人和审核时间
- [ ] 显示审核意见
- [ ] 禁用已审核申请的审核按钮

**实现位置**：
- `frontend/src/pages/AdminDashboard.tsx`

---

### 10. 🎨 **UI/UX 优化**（低优先级）

**问题**：部分界面可以进一步优化

**需要实现**：
- [ ] 优化申请列表的显示样式
- [ ] 添加加载状态指示器
- [ ] 优化错误提示显示
- [ ] 添加空状态提示

**实现位置**：
- `frontend/src/pages/AdminDashboard.tsx`
- `ios/link2ur/link2ur/Views/Forum/ForumView.swift`

---

## 🎯 优先级建议

### 高优先级（立即实现）
1. **通知功能** - 用户体验关键功能

### 中优先级（近期实现）
2. **申请人信息** - 管理员需要查看申请人信息
3. **分页功能** - 性能优化
4. **iOS端查看我的申请** - 用户体验
5. **申请频率限制** - 防止滥用

### 低优先级（后续优化）
6. **搜索功能** - 功能增强
7. **申请详情查看** - 功能增强
8. **排序功能** - 功能增强
9. **审核意见显示优化** - UI优化
10. **UI/UX 优化** - 界面优化

---

## 📝 实现建议

### 通知功能实现示例

```python
# 在 review_category_request 函数中，审核后发送通知
if action == "approve":
    # 发送批准通知
    notification = models.Notification(
        user_id=category_request.requester_id,
        type="forum_category_approved",
        title="板块申请已通过",
        content=f"您申请的板块「{category_request.name}」已通过审核，板块已创建。",
        related_id=str(category_request.id)
    )
    db.add(notification)
    
    # 发送推送通知
    send_push_notification_async_safe(
        async_db=db,
        user_id=category_request.requester_id,
        title="板块申请已通过",
        body=f"您申请的板块「{category_request.name}」已通过审核",
        notification_type="forum_category_approved",
        data={"request_id": request_id, "category_name": category_request.name}
    )
else:
    # 发送拒绝通知
    notification = models.Notification(
        user_id=category_request.requester_id,
        type="forum_category_rejected",
        title="板块申请已拒绝",
        content=f"您申请的板块「{category_request.name}」已被拒绝。{review_comment or '无审核意见'}",
        related_id=str(category_request.id)
    )
    db.add(notification)
    
    # 发送推送通知
    send_push_notification_async_safe(
        async_db=db,
        user_id=category_request.requester_id,
        title="板块申请已拒绝",
        body=f"您申请的板块「{category_request.name}」已被拒绝",
        notification_type="forum_category_rejected",
        data={"request_id": request_id, "category_name": category_request.name}
    )
```

### 申请人信息实现示例

```python
# 在 schemas.py 中
class ForumCategoryRequestOut(BaseModel):
    """申请新建板块输出"""
    id: int
    requester_id: str
    requester_name: Optional[str] = None  # 新增
    requester_avatar: Optional[str] = None  # 新增
    name: str
    # ... 其他字段

# 在 forum_routes.py 中
@router.get("/categories/requests", response_model=List[schemas.ForumCategoryRequestOut])
async def get_category_requests(...):
    query = select(models.ForumCategoryRequest).options(
        selectinload(models.ForumCategoryRequest.requester),  # 加载申请人信息
        selectinload(models.ForumCategoryRequest.admin)
    )
    # ...
    # 在返回时，需要手动构建包含 requester_name 和 requester_avatar 的响应
```

---

## ✅ 检查清单

在实现每个功能后，请检查：

- [ ] 后端API测试通过
- [ ] 前端功能正常
- [ ] 错误处理完善
- [ ] 日志记录完整
- [ ] 性能优化到位
- [ ] 用户体验良好
- [ ] 安全性检查通过
