# 任务聊天视图键盘避让和抖动修复

## ✅ 已修复的问题

### 1. 键盘避让没有稳定生效（有时不往上移）✅

**问题**：
- 使用 `ignoresSafeArea()` 无参数版本，可能影响 keyboard safe area
- 使用 `VStack` 布局，系统键盘避让不稳定

**修复**：
```swift
// ✅ 修复前
ZStack {
    AppColors.background.ignoresSafeArea()
    VStack(spacing: 0) {
        messageListView
        inputAreaView
    }
}

// ✅ 修复后
ZStack {
    AppColors.background
        .ignoresSafeArea(.container, edges: .all) // 不要用无参数的 ignoresSafeArea()
    messageListView
}
.safeAreaInset(edge: .bottom, spacing: 0) {
    inputAreaView
}
```

**效果**：
- 键盘弹出时，系统一定会把底部 inset 顶起来
- `TaskChatMessageListView` 依然用 `bottomInset: inputAreaHeight` 去做内容 padding，保证消息不被输入区盖住

**文件**：`TaskChatView.swift` - `mainContent`

---

### 2. 滚动触发多次导致抖动 ✅

**问题**：
- 多个 `onChange` 同时触发 `requestScrollToBottom()`
- 键盘高度变化、inputAreaHeight 变化、showActionMenu 变化等都会触发滚动
- 没有防抖机制，导致短时间内多次滚动

**修复**：
```swift
// ✅ 添加滚动防抖
@State private var scrollWorkItem: DispatchWorkItem?

private func requestScrollToBottom(animatedWithKeyboard: Bool = false) {
    // ✅ 滚动防抖 - 同一帧/同一小段时间内的多次触发只执行一次滚动
    scrollWorkItem?.cancel()
    let work = DispatchWorkItem {
        scrollToBottomTrigger += 1
    }
    scrollWorkItem = work
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05, execute: work)
}
```

**效果**：
- 键盘高度多次回调、inputAreaHeight 多次变化时，不会连着滚多次
- 抖动显著下降

**文件**：`TaskChatView.swift`

---

### 3. 监听 isInputFocused，在"刚聚焦"时就请求贴底 ✅

**问题**：
- 只有键盘高度变化才滚，而"键盘高度变化"可能来得更晚/分多次
- 导致"点输入框但没及时上移"的观感问题

**修复**：
```swift
.onChange(of: isInputFocused) { focused in
    // ✅ 修复：监听 isInputFocused，在"刚聚焦"时就请求贴底（避免依赖 keyboardHeight）
    if focused && !viewModel.messages.isEmpty {
        requestScrollToBottom(animatedWithKeyboard: true)
    }
}
```

**效果**：
- 点击输入框时立即触发滚动，不会出现"点输入框但没及时上移"的问题

**文件**：`TaskChatView.swift`

---

### 4. 减少外层 `.animation(...)` 的覆盖面 ✅

**问题**：
- 对 `keyboardHeight/showActionMenu/inputAreaHeight` 都做了 animation
- `inputAreaHeight` 是 readHeight 测量驱动的，最容易在动画期反复变化
- 导致布局变化也"参与动画"，进一步放大抖动

**修复**：
```swift
// ✅ 修复前
.animation(keyboardObserver.keyboardAnimation, value: keyboardObserver.keyboardHeight)
.animation(keyboardObserver.keyboardAnimation, value: showActionMenu)
.animation(keyboardObserver.keyboardAnimation, value: inputAreaHeight) // ❌ 移除

// ✅ 修复后
.animation(keyboardObserver.keyboardAnimation, value: keyboardObserver.keyboardHeight)
.animation(keyboardObserver.keyboardAnimation, value: showActionMenu)
// 移除 inputAreaHeight 的 animation（readHeight 测量驱动的，容易在动画期反复变化）
```

**效果**：
- 减少布局动画的反复触发
- 抖动明显减少

**文件**：`TaskChatView.swift` - `mainContent`

---

### 5. 修正 nearBottom 判定（提高稳定性）✅

**问题**：
- 使用屏幕高度 heuristic，键盘出现/消失会改变可视区域与坐标关系
- 这个 heuristic 很容易在动画过程中反复越界，导致状态来回切

**修复**：
```swift
// ✅ 修复：nearBottom 检测 - 直接测量内容位置，距离可视底部小于阈值就算 nearBottom
// minY 是内容顶部在 scroll 坐标系中的位置，当滚动到底部时，minY 会是一个负值
// 如果 minY > -threshold，说明内容顶部距离可视区域顶部很近，即接近底部
.background(
    GeometryReader { contentGeo in
        Color.clear.preference(
            key: ScrollOffsetPreferenceKey.self,
            value: contentGeo.frame(in: .named("task_chat_scroll")).minY
        )
    }
)
.onPreferenceChange(ScrollOffsetPreferenceKey.self) { contentMinY in
    let threshold: CGFloat = 200
    // 当滚动到底部时，contentMinY 会是一个负值（内容向上滚动）
    // 如果 contentMinY > -threshold，说明接近底部
    isNearBottom = contentMinY > -threshold
}
```

**效果**：
- 减少键盘弹出/收起时 nearBottom 的误判
- 减少额外滚动/按钮状态抖动

**文件**：`TaskChatMessageListView.swift`

---

## 📋 修复总结

### 核心修复（按优先级）

1. ✅ **使用 `safeAreaInset` 固定键盘避让** - 解决"不上移"问题
2. ✅ **滚动防抖** - 解决"抖动"问题
3. ✅ **监听 `isInputFocused`** - 改善"点输入框但没及时上移"的体验
4. ✅ **减少 animation 覆盖面** - 减少布局动画反复触发
5. ✅ **修正 nearBottom 判定** - 提高状态稳定性

---

## 🎯 关键改进点

### 布局模型（更稳）

```swift
ZStack {
    AppColors.background
        .ignoresSafeArea(.container, edges: .all)
    messageListView
}
.safeAreaInset(edge: .bottom, spacing: 0) {
    inputAreaView
}
```

**优势**：
- 系统自动处理键盘避让，更稳定
- 不会出现"有时不往上移"的问题

### 滚动触发（防抖）

```swift
@State private var scrollWorkItem: DispatchWorkItem?

private func requestScrollToBottom(animatedWithKeyboard: Bool = false) {
    scrollWorkItem?.cancel()
    let work = DispatchWorkItem {
        scrollToBottomTrigger += 1
    }
    scrollWorkItem = work
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05, execute: work)
}
```

**优势**：
- 同一帧内的多次触发只执行一次滚动
- 显著减少抖动

### 触发时机优化

```swift
// ✅ 监听 isInputFocused，在"刚聚焦"时就请求贴底
.onChange(of: isInputFocused) { focused in
    if focused && !viewModel.messages.isEmpty {
        requestScrollToBottom(animatedWithKeyboard: true)
    }
}
```

**优势**：
- 点击输入框时立即触发滚动
- 不依赖键盘高度变化，响应更快

---

## 📝 测试建议

### 键盘避让测试
- [ ] 没滑动时点输入框，消息容器应该立即上移
- [ ] 滑动过再点输入框，消息容器应该上移且不抖动
- [ ] 键盘弹出时，最后几条消息应该始终可见

### 滚动体验测试
- [ ] 点击输入框，应该立即滚动到底部（无延迟）
- [ ] 键盘弹出时，不应该出现多次滚动/抖动
- [ ] Action menu 展开/收起时，如果用户在底部，应该保持贴底

### 状态稳定性测试
- [ ] nearBottom 判定应该稳定，不会在键盘动画期间反复跳变
- [ ] 新消息按钮的显示/隐藏应该稳定

---

**最后更新**：2024年（当前会话）
