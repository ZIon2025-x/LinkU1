# 任务聊天视图关键修复清单

## ✅ 已修复的问题

### 1. 强引用环（内存泄漏风险）✅

**问题**：
- `connectWebSocket()` 的 sink 闭包强捕获了 `self`，形成 `TaskChatView(self) -> viewModel -> cancellables -> closure -> self` 的循环引用
- `uploadAndSendImage()` 的 `receiveValue` 闭包也会隐式捕获 `self`

**修复**：
```swift
// WebSocket sink
.sink { [weak self, weak viewModel] message in
    guard let self = self, let viewModel = viewModel else { return }
    // 使用 self? 访问
    self.markAsReadWorkItem?.cancel()
    ...
}

// 图片上传 sink
.sink(
    receiveCompletion: { [weak viewModel] completion in ... },
    receiveValue: { [weak self, weak viewModel] imageUrl in
        guard let self = self, let viewModel = viewModel else { return }
        self.requestScrollToBottom()
    }
)
```

**文件**：`TaskChatView.swift`

---

### 2. 任务状态逻辑矛盾 ✅

**问题**：
- `pending_confirmation` 同时被当成"关闭态"（`isTaskClosed`）又想显示"详细地址"（`shouldShowLocationDetail`）
- 结果：`pending_confirmation` 下根本进不到 action menu，地址按钮永远出不来

**修复**：
- 将 `isTaskClosed` 中的 `pending_confirmation` 移除，只保留 `["completed", "cancelled"]`
- 新增 `isInputDisabled` 状态，专门处理 `pending_confirmation` 禁用输入但允许查看地址的情况
- 在 `TaskChatInputArea` 中添加 `isInputDisabled` 参数，当为 true 时：
  - 禁用输入框（`.disabled(isSending || isInputDisabled)`）
  - 显示提示信息（"任务待确认，无法发送消息"）
  - 但仍允许展开 action menu 查看地址

**文件**：
- `TaskChatView.swift`：新增 `isInputDisabled` 计算属性
- `TaskChatInputArea.swift`：添加 `isInputDisabled` 参数和 UI 处理

---

### 3. Action Menu 展开/收起保持贴底 ✅

**问题**：
- Action menu 展开会让 `inputAreaHeight` 变大，但滚动位置不动，导致最后几条消息"离底一截"

**修复**：
```swift
.onChange(of: showActionMenu) { _ in
    // ✅ 修复：action menu 展开/收起时，如果用户在底部，保持贴底
    if isNearBottom || isInputFocused {
        requestScrollToBottom(animatedWithKeyboard: true)
    }
}
```

**文件**：`TaskChatView.swift`

---

### 4. scrollDismissesKeyboard 重复 ✅

**问题**：
- 外层 `TaskChatView` 和 `TaskChatMessageListView` 的 `ScrollView` 都加了 `.scrollDismissesKeyboard(.interactively)`

**修复**：
- 删除外层 `TaskChatView` 的 `.scrollDismissesKeyboard(.interactively)`
- 只保留 `TaskChatMessageListView` 中 `ScrollView` 上的那一处

**文件**：
- `TaskChatView.swift`：删除外层 `.scrollDismissesKeyboard(.interactively)`
- `TaskChatMessageListView.swift`：保留 `ScrollView` 上的 `.scrollDismissesKeyboard(.interactively)`

---

### 5. Near-Bottom 判定优化 ✅

**问题**：
- 使用 `minY` 判定在内容少/空态时不够准确

**修复**：
- 改用 `maxY` 计算内容底部位置
- 使用 `maxY > 屏幕高度 - 200` 判定是否在底部
- 注意：这个判定在内容少时可能还不够完美，但已经比之前更准确

**文件**：`TaskChatMessageListView.swift`

```swift
// ✅ 优化：nearBottom 检测 - 使用 maxY 计算离底部的距离
.background(
    GeometryReader { contentGeo in
        Color.clear.preference(
            key: ScrollOffsetPreferenceKey.self,
            value: contentGeo.frame(in: .named("task_chat_scroll")).maxY
        )
    }
)
.onPreferenceChange(ScrollOffsetPreferenceKey.self) { contentMaxY in
    let threshold: CGFloat = 200
    let screenHeight = UIScreen.main.bounds.height
    isNearBottom = contentMaxY > screenHeight - threshold
}
```

---

## 📋 修复总结

### 必修项（已修复）
1. ✅ **强引用环** - WebSocket 和图片上传的 sink 闭包
2. ✅ **pending_confirmation 状态逻辑** - 拆分为 `isTaskClosed` 和 `isInputDisabled`

### 体验优化（已修复）
3. ✅ **Action menu 贴底** - 展开/收起时保持贴底
4. ✅ **scrollDismissesKeyboard 重复** - 只保留一处
5. ✅ **Near-bottom 判定** - 改用 maxY 计算

---

## 🎯 关键原则（已遵循）

1. ✅ **永远滚 bottom anchor**，不要滚 `lastMessage.id`
2. ✅ **列表 bottomInset = 输入区真实高度**，不要用 keyboardHeight 算布局
3. ✅ **`.scrollDismissesKeyboard(.interactively)` 必开**（只保留一处）
4. ✅ **滚动触发只保留 3 个来源**，避免互相打架
5. ✅ **keyboardHeight 只用于滚动动画同步**
6. ✅ **避免强引用环**，所有 sink 闭包使用 `[weak self, weak viewModel]`

---

## 📝 测试建议

### 内存泄漏测试
- [ ] 进入任务聊天页面
- [ ] 接收几条 WebSocket 消息
- [ ] 上传一张图片
- [ ] 退出页面
- [ ] 检查是否有内存泄漏（使用 Instruments）

### 状态逻辑测试
- [ ] `pending_confirmation` 状态：输入框应禁用，但可以展开 action menu 查看地址
- [ ] `completed` 状态：显示关闭提示，无法输入
- [ ] `cancelled` 状态：显示关闭提示，无法输入

### 交互体验测试
- [ ] Action menu 展开/收起时，消息列表保持贴底
- [ ] 拖动列表可以收起键盘
- [ ] 点击输入框，键盘弹出，消息列表同步上移
- [ ] 新消息到达时，如果在底部，自动滚动到底部

---

**最后更新**：2024年（当前会话）
