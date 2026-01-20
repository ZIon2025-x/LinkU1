# 任务聊天视图迁移总结

## ✅ 已完成的工作

### 1. 文件结构重组

**新文件位置**：
- `Views/Message/TaskChatView.swift` - 主视图（重构版）
- `Views/Message/TaskChatMessageListView.swift` - 消息列表组件
- `Views/Message/TaskChatInputArea.swift` - 输入区域组件
- `Views/Message/TaskChatActionMenu.swift` - 功能菜单组件
- `Views/Message/TaskChatViewHelpers.swift` - 辅助工具（高度测量）

**保留的文件**：
- `Views/Notification/TaskChatListView.swift` - 任务聊天列表（包含 `TaskChatRow`）

### 2. 业务逻辑迁移

#### ✅ WebSocket 连接和消息监听
- 已迁移 `connectWebSocket()` 方法
- 实现了消息去重和有序插入
- 自动标记已读（防抖机制，延迟 0.3 秒）
- 推送通知处理（后台/不可见时）

#### ✅ 消息加载逻辑
- 已迁移完整的 `setupOnAppear()` 逻辑
- 支持多种刷新策略：
  - 有未读消息时强制刷新
  - 从推送通知进入时刷新
  - 距离上次出现超过 30 秒时刷新
  - 首次出现时刷新

#### ✅ 标记已读逻辑
- 已迁移防抖标记已读机制
- 支持 `uptoMessageId` 参数
- 在 `onDisappear` 中清理工作项

#### ✅ 推送通知处理
- 已迁移 `handleRefreshNotification()` 方法
- 监听 `RefreshTaskChat` 通知
- 支持从通知进入时自动刷新

#### ✅ 位置详情功能
- 已迁移 `loadTaskDetailAndShowLocation()` 方法
- 支持在 action menu 中显示位置详情按钮（仅在 `in_progress` 或 `pending_confirmation` 时）
- 使用 `TaskDetailViewModel` 加载任务详情

#### ✅ 客服中心功能
- 已迁移客服中心 sheet
- 在工具栏菜单中提供入口

#### ✅ 工具栏菜单
- 已迁移工具栏菜单（任务详情、需要帮助）
- 使用 `Menu` 组件

#### ✅ 图片上传逻辑
- 已完善图片上传逻辑
- 添加了文件大小检查（限制 5MB）
- 图片压缩（quality: 0.7）

### 3. 核心改进（对标 WhatsApp/微信）

#### ✅ 键盘避让
- **旧方案**：`safeAreaInset` + 缺少 ScrollView 底部 inset
- **新方案**：`VStack` + `bottomInset = inputAreaHeight`（不涉及 keyboardHeight）
- keyboardHeight 只用于滚动动画同步

#### ✅ 滚动到底部
- **旧方案**：滚动到 `lastMessage.id`
- **新方案**：永远滚动到 `bottomAnchorId`（避免抖动）

#### ✅ 滚动触发
- **旧方案**：多个 `onChange` 触发点，容易互相打架
- **新方案**：收敛到 3 个触发点：
  1. 首次加载完成
  2. 新消息到达（且用户在底部/正在输入）
  3. 键盘弹起（且正在输入）

#### ✅ 多行输入
- **旧方案**：`.lineLimit(1.4)`（错误用法）
- **新方案**：`.lineLimit(1...5)`（SwiftUI 原生 API）

#### ✅ 交互优化
- `.scrollDismissesKeyboard(.interactively)` - 拖动列表收起键盘
- 点击空白区域收起键盘
- Action menu 展开时自动收起键盘

### 4. 组件拆分

#### TaskChatView（主视图）
- 状态协调
- 动画管理
- 滚动触发
- 生命周期管理

#### TaskChatMessageListView（消息列表）
- 消息渲染
- 底部锚点
- nearBottom 检测
- 新消息按钮

#### TaskChatInputArea（输入区域）
- 多行输入（1-5 行）
- Action menu 集成
- 任务关闭状态处理

#### TaskChatActionMenu（功能菜单）
- 图片选择
- 任务详情
- 位置详情（条件显示）

### 5. 引用更新

**已确认的引用位置**：
1. ✅ `Views/Notification/TaskChatListView.swift` - 使用 `TaskChatView`
2. ✅ `Views/Message/MessageView.swift` - 使用 `TaskChatView`
3. ✅ `Views/Tasks/TaskDetailView.swift` - 使用 `TaskChatView`（缺少 `taskChat` 参数，但这是可选的）

**注意**：Swift 会自动找到同模块内的类型，无需显式导入。

## 📋 待验证的功能

### 功能测试清单

- [ ] 键盘弹出时消息容器同步上移
- [ ] 最后几条消息始终可见
- [ ] 拖动列表可以收起键盘
- [ ] 输入框高度动态扩展（1-5 行）
- [ ] 附件菜单展开/收起平滑
- [ ] WebSocket 消息实时接收
- [ ] 自动标记已读功能
- [ ] 推送通知处理
- [ ] 位置详情功能
- [ ] 客服中心功能
- [ ] 图片上传功能
- [ ] 任务关闭状态处理

## 🔧 技术细节

### 关键公式

**列表底部 padding**：
```swift
bottomInset = inputAreaHeight  // 输入区真实高度（包含 action menu）
```

**滚动触发**：
```swift
// 只保留 3 个触发点
1. viewModel.isInitialLoadComplete -> true
2. viewModel.messages.count 变化 && (isNearBottom || isInputFocused)
3. keyboardObserver.keyboardHeight > 0 && isInputFocused
```

**滚动目标**：
```swift
// 永远滚动到 bottom anchor
proxy.scrollTo("task_chat_bottom_anchor", anchor: .bottom)
```

### 状态管理

**UI 状态**（在 View 中）：
- `messageText` - 输入框文本
- `showActionMenu` - 菜单显示状态
- `isInputFocused` - 输入框焦点状态
- `inputAreaHeight` - 输入区高度
- `isNearBottom` - 是否接近底部
- `scrollToBottomTrigger` - 滚动触发器

**业务状态**（在 ViewModel 中）：
- `messages` - 消息列表
- `isLoading` - 加载状态
- `isSending` - 发送状态
- `errorMessage` - 错误信息

## 🎯 关键原则（已遵循）

1. ✅ **永远滚 bottom anchor**，不要滚 `lastMessage.id`
2. ✅ **列表 bottomInset = 输入区真实高度**，不要用 keyboardHeight 算布局
3. ✅ **`.scrollDismissesKeyboard(.interactively)` 必开**
4. ✅ **滚动触发只保留 3 个来源**，避免互相打架

## 📝 注意事项

1. **TaskChatRow** 仍然在 `Views/Notification/TaskChatListView.swift` 中，因为它在列表视图中使用
2. **TaskDetailView** 中的引用缺少 `taskChat` 参数，但这是可选的，不影响功能
3. 所有业务逻辑已完整迁移，包括 WebSocket、消息加载、标记已读、推送通知等

## 🚀 下一步

1. 运行应用，测试所有功能
2. 验证键盘避让是否正常工作
3. 验证滚动行为是否流畅
4. 验证 WebSocket 消息接收是否正常
5. 验证推送通知处理是否正常

---

**迁移完成时间**：2024年（当前会话）
