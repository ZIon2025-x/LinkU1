# 任务聊天重构 - 快速开始指南

## 📁 已创建的文件

基于你提供的骨架代码，我已经创建了以下文件：

### 核心组件

1. **`TaskChatView.swift`** - 主视图
   - 状态协调和动画管理
   - 滚动触发逻辑（收敛到 3 个触发点）
   - 键盘动画同步

2. **`TaskChatMessageListView.swift`** - 消息列表组件
   - ✅ 使用 `bottomInset = inputAreaHeight`（不涉及 keyboardHeight）
   - ✅ 永远滚动到 `bottomAnchorId`（不滚动 lastMessage.id）
   - ✅ 复用现有的 `ScrollOffsetPreferenceKey` 逻辑

3. **`TaskChatInputArea.swift`** - 输入区域组件
   - ✅ 多行输入（`.lineLimit(1...5)`）
   - ✅ Action menu 展开/收起
   - ✅ 任务关闭状态处理

4. **`TaskChatActionMenu.swift`** - 功能菜单组件
   - 图片选择、任务详情、位置分享等

5. **`TaskChatViewHelpers.swift`** - 辅助工具
   - `readHeight` modifier：自动测量输入区高度

## ✅ 关键改进点（已实现）

### 1. 键盘避让（修正版）

**❌ 旧方案**（容易算错）：
```swift
keyboardPadding = max(keyboardHeight - inputAreaHeight, 0)
```

**✅ 新方案**（更稳）：
```swift
// 列表底部 padding = 输入区真实高度
messageListBottomPadding = inputAreaHeight

// keyboardHeight 只用于滚动动画同步
.onChange(of: keyboardObserver.keyboardHeight) { height in
    if height > 0, isInputFocused {
        requestScrollToBottom(animatedWithKeyboard: true)
    }
}
```

### 2. 滚动到底部（修正版）

**❌ 旧方案**（容易抖动）：
```swift
proxy.scrollTo(lastMessage.id, anchor: .bottom)
```

**✅ 新方案**（永远贴底）：
```swift
// 使用底部锚点
Color.clear
    .frame(height: 1)
    .id("task_chat_bottom_anchor")

// 滚动到锚点
proxy.scrollTo("task_chat_bottom_anchor", anchor: .bottom)
```

### 3. 滚动触发（收敛版）

**✅ 只保留 3 个触发点**（避免互相打架）：
1. 首次加载完成
2. 新消息到达（且用户在底部/正在输入）
3. 键盘弹起（且正在输入）

### 4. 多行输入（修正版）

**❌ 旧方案**（错误）：
```swift
.lineLimit(1.5) // ❌ 不支持
```

**✅ 新方案**（正确）：
```swift
TextField("", text: $messageText, axis: .vertical)
    .lineLimit(1...5) // ✅ SwiftUI 原生 API
```

### 5. 交互优化

**✅ 已实现**：
- `.scrollDismissesKeyboard(.interactively)` - 拖动列表收起键盘
- 点击空白区域收起键盘
- Action menu 展开时自动收起键盘

## 🔧 需要迁移的业务逻辑

以下逻辑需要从 `TaskChatListView.swift` 迁移到新组件：

### TaskChatView.swift

- [ ] WebSocket 连接逻辑
- [ ] 消息加载逻辑（`loadMessages`）
- [ ] 标记已读逻辑（`markAsRead`）
- [ ] 推送通知处理
- [ ] 图片上传逻辑（已有骨架，需要完善）

### TaskChatMessageListView.swift

- [ ] 加载更多历史消息（如果需要）
- [ ] 下拉刷新逻辑
- [ ] 消息状态更新（已读/未读）

### TaskChatInputArea.swift

- [ ] 字符计数提示（接近最大长度时）
- [ ] 输入验证逻辑

## 📝 使用步骤

### 步骤 1: 测试编译

1. 确保所有文件已创建
2. 检查编译错误
3. 修复任何缺失的依赖

### 步骤 2: 迁移业务逻辑

1. 从 `TaskChatListView.swift` 复制业务逻辑
2. 按组件职责分配到对应文件
3. 保持 API 接口不变

### 步骤 3: 更新引用

1. 搜索所有 `TaskChatView` 的引用
2. 更新 import 路径（从 `Notification` 改为 `Message`）
3. 测试功能是否正常

### 步骤 4: 测试验证

按照文档中的检查清单进行测试：
- ✅ 键盘弹出时消息容器同步上移
- ✅ 最后几条消息始终可见
- ✅ 拖动列表可以收起键盘
- ✅ 输入框高度动态扩展
- ✅ 附件菜单展开/收起平滑

## 🎯 关键原则（不要再踩坑）

1. **永远滚 bottom anchor**，不要滚 `lastMessage.id`
2. **列表 bottomInset = 输入区真实高度**，不要用 keyboardHeight 算布局
3. **`.scrollDismissesKeyboard(.interactively)` 必开**
4. **滚动触发只保留 3 个来源**，避免互相打架

## 📚 相关文档

- `TASK_CHAT_VIEW_REDESIGN.md` - 完整重构文档
- `TaskChatListView.swift` - 旧实现（参考业务逻辑）

---

**下一步**：你可以开始迁移业务逻辑，或者让我帮你完成某个特定部分的迁移。
