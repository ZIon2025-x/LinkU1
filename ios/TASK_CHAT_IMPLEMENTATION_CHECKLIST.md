# 任务聊天视图实现检查清单

## ✅ 已按照开发文档实现的功能

### 1. 键盘避让机制 ✅

**文档要求**：
- ✅ 列表底部 padding = 输入区真实高度（不涉及 keyboardHeight）
- ✅ 键盘避让交给系统（VStack 布局）
- ✅ keyboardHeight 只用于滚动动画同步

**当前实现**：
```swift
// TaskChatView.swift
bottomInset: inputAreaHeight  // ✅ 始终使用输入区真实高度

// TaskChatMessageListView.swift
.padding(.bottom, bottomInset)  // ✅ 直接用输入区高度
```

**状态**：✅ 已实现

---

### 2. 滚动到底部逻辑 ✅

**文档要求**：
- ✅ 永远滚动到 `bottomAnchorId`，不滚动 `lastMessage.id`
- ✅ 滚动触发只保留 3 个来源

**当前实现**：
```swift
// TaskChatMessageListView.swift
Color.clear.frame(height: 1).id(bottomAnchorId)  // ✅ 永久底部锚点

proxy.scrollTo(bottomAnchorId, anchor: .bottom)  // ✅ 滚动到锚点

// TaskChatView.swift - 3 个触发点
1. onChange(of: viewModel.isInitialLoadComplete)  // ✅ 首次加载完成
2. onChange(of: viewModel.messages.count)  // ✅ 新消息到达
3. onChange(of: keyboardObserver.keyboardHeight)  // ✅ 键盘弹出
```

**状态**：✅ 已实现

---

### 3. 滚动动画同步 ✅

**文档要求**：
- ✅ 键盘弹出时，使用 `keyboardObserver.keyboardAnimation` 同步滚动

**当前实现**：
```swift
// TaskChatMessageListView.swift
keyboardAnimation: keyboardObserver.keyboardHeight > 0 ? keyboardObserver.keyboardAnimation : nil

// 滚动时使用键盘动画
if let animation = keyboardAnimation {
    withAnimation(animation) {
        proxy.scrollTo(bottomAnchorId, anchor: .bottom)
    }
}
```

**状态**：✅ 已实现

---

### 4. 多行输入 ✅

**文档要求**：
- ✅ 使用 `.lineLimit(1...5)`（SwiftUI 原生 API）
- ✅ 不要用 `.lineLimit(1.4)` 或类似错误写法

**当前实现**：
```swift
// TaskChatInputArea.swift
TextField(..., axis: .vertical)
    .lineLimit(1...5)  // ✅ 正确用法
```

**状态**：✅ 已实现

---

### 5. 交互优化 ✅

**文档要求**：
- ✅ `.scrollDismissesKeyboard(.interactively)` 必开
- ✅ 点击空白区域收起键盘

**当前实现**：
```swift
// TaskChatView.swift
.scrollDismissesKeyboard(.interactively)  // ✅ 已实现

// TaskChatMessageListView.swift
.scrollDismissesKeyboard(.interactively)  // ✅ 已实现

// TaskChatView.swift
.onTapGesture {
    isInputFocused = false
    hideKeyboard()
}
```

**状态**：✅ 已实现

---

### 6. 输入区高度测量 ✅

**文档要求**：
- ✅ 动态测量输入区真实高度（包含 action menu 展开）

**当前实现**：
```swift
// TaskChatViewHelpers.swift
extension View {
    func readHeight(into binding: Binding<CGFloat>) -> some View {
        background(
            GeometryReader { geo in
                Color.clear.preference(key: HeightPreferenceKey.self, value: geo.size.height)
            }
        )
        .onPreferenceChange(HeightPreferenceKey.self) { h in
            binding.wrappedValue = h
        }
    }
}

// TaskChatView.swift
.readHeight(into: $inputAreaHeight)  // ✅ 动态测量
```

**状态**：✅ 已实现

---

### 7. 组件拆分 ✅

**文档要求**：
- ✅ 拆分为 `TaskChatView`、`TaskChatMessageListView`、`TaskChatInputArea`、`TaskChatActionMenu`

**当前实现**：
- ✅ `TaskChatView.swift` - 主视图（状态协调、动画、滚动触发）
- ✅ `TaskChatMessageListView.swift` - 消息列表（渲染、底部锚点、nearBottom 检测）
- ✅ `TaskChatInputArea.swift` - 输入区域（多行输入、action menu、任务关闭状态）
- ✅ `TaskChatActionMenu.swift` - 功能菜单（图片、任务详情、位置详情）
- ✅ `TaskChatViewHelpers.swift` - 辅助工具（高度测量）

**状态**：✅ 已实现

---

### 8. 业务逻辑迁移 ✅

**文档要求**：
- ✅ 迁移所有业务逻辑（WebSocket、消息加载、标记已读、推送通知等）

**当前实现**：
- ✅ WebSocket 连接和消息监听
- ✅ 消息加载逻辑（多种刷新策略）
- ✅ 标记已读逻辑（防抖机制）
- ✅ 推送通知处理
- ✅ 位置详情功能
- ✅ 客服中心功能
- ✅ 工具栏菜单
- ✅ 图片上传逻辑（含文件大小检查）

**状态**：✅ 已实现

---

## ⚠️ 需要注意的点

### 1. 键盘避让机制

**文档的核心思想**：
- 使用 `VStack` 布局，系统自动处理键盘避让
- 列表底部 padding 只需要是输入区高度，确保消息不被输入区挡住
- 当键盘弹出时，系统会自动把输入区推上去，消息列表的可视区域会自动变小

**当前实现**：
- ✅ 使用 `VStack` 布局
- ✅ 列表底部 padding = `inputAreaHeight`
- ✅ 系统自动处理键盘避让

**如果还有问题**，可能需要检查：
1. `VStack` 是否正确填充可用空间
2. 输入区是否被正确推上去
3. 消息列表的可视区域是否正确调整

---

### 2. 滚动触发时机

**文档要求**：只保留 3 个触发点

**当前实现**：
- ✅ 触发点 1：`onChange(of: viewModel.isInitialLoadComplete)`
- ✅ 触发点 2：`onChange(of: viewModel.messages.count)`（且用户在底部/正在输入）
- ✅ 触发点 3：`onChange(of: keyboardObserver.keyboardHeight)`（且正在输入）

**已删除的触发点**：
- ✅ `onChange(of: isInputFocused)` - 已删除（由 keyboardHeight 处理）
- ✅ `onChange(of: showActionMenu)` - 已删除（不需要）

**状态**：✅ 已实现

---

## 📋 测试清单

### 功能测试

- [ ] 点击输入框，键盘弹出，消息列表同步上移
- [ ] 最后几条消息始终可见，不被键盘遮挡
- [ ] 拖动列表可以收起键盘
- [ ] 输入框高度动态扩展（1-5 行）
- [ ] Action menu 展开/收起平滑
- [ ] 新消息到达时自动滚动到底部
- [ ] 键盘弹出时滚动动画与键盘动画同步
- [ ] WebSocket 消息实时接收
- [ ] 自动标记已读功能
- [ ] 推送通知处理
- [ ] 位置详情功能
- [ ] 客服中心功能
- [ ] 图片上传功能
- [ ] 任务关闭状态处理

### 边界情况测试

- [ ] 空消息列表状态
- [ ] 网络错误状态
- [ ] WebSocket 连接断开/重连
- [ ] 任务关闭状态下的输入框显示
- [ ] 横竖屏切换
- [ ] 不同 iPhone 型号（有刘海、没有、有 home indicator）

---

## 🎯 关键原则（已遵循）

1. ✅ **永远滚 bottom anchor**，不要滚 `lastMessage.id`
2. ✅ **列表 bottomInset = 输入区真实高度**，不要用 keyboardHeight 算布局
3. ✅ **`.scrollDismissesKeyboard(.interactively)` 必开**
4. ✅ **滚动触发只保留 3 个来源**，避免互相打架
5. ✅ **keyboardHeight 只用于滚动动画同步**

---

## 📝 总结

**按照开发文档的实现状态**：✅ **已完成**

所有核心功能已按照开发文档的要求实现：
- ✅ 键盘避让机制（使用 inputAreaHeight，不涉及 keyboardHeight）
- ✅ 滚动到底部逻辑（使用 bottom anchor，3 个触发点）
- ✅ 滚动动画同步（使用 keyboardAnimation）
- ✅ 多行输入（使用 .lineLimit(1...5)）
- ✅ 交互优化（.scrollDismissesKeyboard(.interactively)）
- ✅ 输入区高度测量（动态测量）
- ✅ 组件拆分（4 个组件）
- ✅ 业务逻辑迁移（完整迁移）

**如果点击输入框还有问题**，可能需要：
1. 检查 `VStack` 布局是否正确
2. 检查输入区是否被系统正确推上去
3. 检查消息列表的可视区域是否正确调整
4. 检查滚动触发时机是否正确

---

**最后更新**：2024年（当前会话）
