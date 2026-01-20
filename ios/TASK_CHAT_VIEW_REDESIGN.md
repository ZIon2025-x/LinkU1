# 任务聊天视图重构开发文档

## 📋 文档概述

本文档描述任务聊天视图（TaskChatView）的重构方案，旨在解决当前实现中的键盘避让、布局同步等问题，并优化代码结构和用户体验。

**产品定位**：对标 WhatsApp、微信、Facebook Messenger 等主流聊天应用，打造一流的任务聊天体验。

**核心目标**：
- ✅ 彻底解决键盘避让问题，实现输入框与消息列表完美同步
- ✅ 输入区高度动态适配，支持多行输入和扩展菜单
- ✅ UI 清晰简洁，交互响应顺畅自然
- ✅ 代码结构清晰，易于维护和扩展

**创建时间**: 2025-01-XX  
**目标版本**: iOS App v2.0  
**负责人**: 开发团队

---

## 🔍 当前问题分析

### 1. 键盘避让问题（核心问题）

**问题描述**：
- 点击输入框后，输入框会上移，但消息容器没有同步上移
- 最后几条消息被键盘遮挡，用户无法看到最新消息
- 键盘弹出时，滚动到底部的行为不够流畅

**根本原因**：
- 当前使用 `safeAreaInset(edge: .bottom)` 放置输入区域
- 消息列表的 ScrollView 没有相应的底部 padding/inset
- 缺少与键盘高度同步的布局调整机制

**相关代码位置**：
```swift
// 当前实现（有问题）
messageListView
    .safeAreaInset(edge: .bottom, spacing: 0) {
        inputAreaView
    }
```

### 2. 代码结构问题

**问题描述**：
- `TaskChatView` 和 `TaskChatListView` 放在 `Views/Notification/` 文件夹
- 从功能角度看，任务聊天本质上是"聊天"功能，不是"通知"功能
- 文件位置与功能定位不匹配

**影响**：
- 代码组织不够清晰
- 后续扩展普通聊天功能时，结构会混乱

### 3. 状态管理复杂

**问题描述**：
- `TaskChatView` 包含大量 `@State` 变量（15+ 个）
- 状态之间的依赖关系复杂
- 难以维护和测试

**当前状态变量**：
```swift
@State private var messageText = ""
@State private var lastMessageId: String?
@State private var scrollWorkItem: DispatchWorkItem?
@State private var showLogin = false
@State private var showActionMenu = false
@State private var showImagePicker = false
@State private var showTaskDetail = false
@State private var selectedImage: UIImage?
@State private var showCustomerService = false
@State private var showLocationDetail = false
@State private var taskDetail: Task?
@State private var lastAppearTime: Date?
@State private var hasLoadedFromNotification = false
@State private var isWebSocketConnected = false
@State private var showNewMessageButton = false
@State private var isNearBottom = true
@State private var scrollPosition: CGFloat = 0
@State private var markAsReadWorkItem: DispatchWorkItem?
```

### 4. 键盘交互体验问题

**问题描述**：
- 使用 `.scrollDismissesKeyboard(.never)`，无法通过拖动列表收起键盘
- 与 WhatsApp 等主流聊天应用的交互习惯不一致
- 缺少平滑的键盘动画

---

## 🌟 主流聊天应用对标分析

### 设计原则对标

在重新构建任务聊天框时，必须对标并优化以下 UX 特性，取自 WhatsApp、微信、Facebook Messenger 的优秀体验：

| 特性 | WhatsApp | 微信 | Facebook Messenger | 我们的目标 |
|------|----------|------|-------------------|-----------|
| **键盘同步** | ✅ 输入框固定在底部，键盘弹出时消息列表整体上移 | ✅ 输入框与键盘完美同步，无遮挡 | ✅ 键盘动画与布局动画一致 | ✅ 必须实现 |
| **输入框动态高度** | ✅ 支持多行输入，高度自适应 | ✅ 多行输入，emoji 面板展开时平滑过渡 | ✅ 输入框高度随内容扩展 | ✅ 必须实现 |
| **拖动收起键盘** | ✅ 向下滑动消息列表可收起键盘 | ✅ 支持滑动收起键盘 | ✅ 交互式键盘收起 | ✅ 必须实现 |
| **附件菜单** | ✅ 简洁的附件按钮，菜单在输入框上方展开 | ✅ 表情/附件面板在输入框上方，动画平滑 | ✅ 附件菜单与键盘协调 | ✅ 必须实现 |
| **消息气泡** | ✅ 简洁的圆角气泡，清晰的视觉层次 | ✅ 渐变背景，精致的阴影效果 | ✅ 统一的视觉风格 | ✅ 保持现有风格 |
| **滚动体验** | ✅ 流畅的滚动，自动滚动到底部 | ✅ 新消息自动滚动，滚动动画平滑 | ✅ 高性能滚动 | ✅ 优化性能 |
| **状态反馈** | ✅ 发送状态、已读状态清晰显示 | ✅ 消息状态图标明确 | ✅ 状态一致性 | ✅ 保持现有功能 |

### WhatsApp 核心 UX 特性分析

**1. 极简布局设计**
- 只有必要元素暴露（发送、表情、附件等）
- 输入框伴随键盘上移，底部行为在输入状态下动态调整
- 动作按钮集中在输入栏，避免过度分散注意力

**参考链接**：[WhatsApp Minimalist UX Principles](https://medium.com/design-bootcamp/whatsapp-minimalist-ux-principles-behind-the-chat-screen-94009e602a8d)

**2. 键盘处理机制**
- 输入框固定在屏幕底部
- 键盘弹出时，消息列表整体上移
- 确保最后一条消息始终可见
- 键盘动画与视图动画完全同步

**3. 交互细节**
- 向下拖拽消息列表可收起键盘
- 点击输入框以外区域可收起键盘
- 所有交互都有平滑的动画过渡

### 微信核心 UX 特性分析

**1. 输入框动态扩展**
- 输入框支持多行输入，高度随内容扩展（1-5 行）
- 超过最大行数时，输入框内部滚动
- emoji、表情包等扩展层在输入框上方浮层展开
- 键盘和浮层带来的布局变化整体动画平滑

**2. 附件菜单设计**
- 附件/表情板弹出与键盘弹出结合
- 菜单展开时，键盘自动收起
- 布局变化无闪烁、无重叠
- 动画持续时间约 0.25-0.3 秒

**3. 消息气泡设计**
- 渐变背景，精致的阴影效果
- 清晰的视觉层次
- 时间戳、状态图标布局合理

### Facebook Messenger 核心 UX 特性分析

**1. 一致性视觉风格**
- 输入框、按钮、消息状态等元素风格统一
- 动作按钮在输入条内部或紧邻输入条边缘
- 避免过度分散用户注意力

**2. 性能优化**
- 消息数量大时滚动流畅
- 键盘弹出不造成跳帧或大量布局重算
- 使用虚拟化列表优化性能

**3. 多平台适配**
- 支持不同屏幕尺寸（iPhone、iPad）
- 横竖屏切换适配
- 安全区域处理完善

### 对标总结：必须实现的核心特性

1. **✅ 键盘同步机制**（最高优先级）
   - 输入框固定在屏幕底部
   - 键盘弹出时，消息列表整体上移
   - 确保最后一条消息始终可见
   - 键盘动画与视图动画完全同步

2. **✅ 输入框动态高度**（高优先级）
   - 支持多行输入（1-5 行）
   - 高度随内容动态扩展
   - 超过最大行数时内部滚动
   - 输入区内部元素垂直居中

3. **✅ 拖动收起键盘**（高优先级）
   - 支持向下拖拽消息列表收起键盘
   - 点击输入框以外区域收起键盘
   - 使用 `.scrollDismissesKeyboard(.interactively)`

4. **✅ 附件菜单协调**（中优先级）
   - 附件菜单在输入框上方展开
   - 展开时与键盘协调，无冲突覆盖
   - 布局变动有平滑动画

5. **✅ 安全区域处理**（中优先级）
   - 适配不同 iPhone 型号（有刘海、没有、有 home indicator 等）
   - 正确处理 bottom safe area
   - 横竖屏切换适配

6. **✅ 任务关闭状态处理**（中优先级）
   - 任务关闭时输入框禁用或隐藏
   - 显示清晰的状态提示
   - 提供"重新开启任务"等操作

---

## ✅ 参考实现：ChatView

### 成功的关键点

1. **VStack 结构**：
   ```swift
   VStack(spacing: 0) {
       messageListView
       inputAreaView
   }
   ```

2. **键盘避让机制**：
   ```swift
   private var keyboardPadding: CGFloat {
       guard keyboardObserver.keyboardHeight > 0 else { return 0 }
       return max(keyboardObserver.keyboardHeight - 60, 0)
   }
   
   // 在 ScrollView 内容上添加 padding
   .padding(.bottom, keyboardPadding)
   ```

3. **交互式键盘收起**：
   ```swift
   .scrollDismissesKeyboard(.interactively)
   ```

4. **统一的动画**：
   ```swift
   .animation(keyboardObserver.keyboardAnimation, value: keyboardObserver.keyboardHeight)
   ```

---

## 🎯 重构目标

### 功能目标（对标主流应用）

1. ✅ **解决键盘避让问题**（对标 WhatsApp/微信）
   - 输入框固定在屏幕底部，键盘弹出时消息容器同步上移
   - 键盘弹出时，最后几条消息始终可见（100% 解决）
   - 平滑的键盘动画，与系统键盘动画完全同步
   - 支持拖动列表收起键盘（类似 WhatsApp）

2. ✅ **输入框动态高度适配**（对标微信）
   - 支持多行输入（1-5 行），高度随内容动态扩展
   - 超过最大行数时，输入框内部滚动
   - 输入区内部元素（发送按钮、附件等）垂直居中
   - 输入框高度变化时，布局平滑过渡

3. ✅ **附件菜单协调**（对标微信/Messenger）
   - 附件菜单在输入框上方展开，不影响主输入栏高度
   - 展开/收起菜单时，布局动画平滑（0.25-0.3 秒）
   - 菜单展开时与键盘协调，无冲突覆盖
   - 支持 emoji、图片、位置等多种附件类型

4. ✅ **任务关闭状态处理**（业务需求）
   - 任务关闭时输入框禁用或隐藏
   - 显示清晰的状态提示（已完成/已取消/待确认）
   - 提供"查看任务详情"等操作按钮
   - UI 状态变化清晰明了，不混乱

5. ✅ **改进代码结构**
   - 将任务聊天相关文件移到 `Views/Message/` 文件夹
   - 提取状态管理逻辑到 ViewModel
   - 拆分大文件，提高可维护性
   - 组件职责清晰，易于复用

### 非功能目标

1. **性能优化**（对标 Messenger）
   - 减少不必要的视图重建
   - 优化滚动性能（使用 LazyVStack）
   - 优化 WebSocket 消息处理（批量更新）
   - 消息数量大时滚动流畅，无卡顿

2. **代码质量**
   - 提高代码可读性
   - 减少状态变量数量（从 15+ 减少到 5-8 个）
   - 统一代码风格
   - 完善的注释和文档

3. **用户体验**
   - 所有交互都有平滑的动画过渡
   - 响应速度快，无延迟感
   - 视觉风格一致，符合 iOS 设计规范
   - 适配不同设备尺寸和横竖屏

---

## 🏗️ 技术架构设计

### 1. 文件结构重组

**当前结构**：
```
Views/
├── Message/
│   ├── ChatView.swift
│   └── MessageView.swift
└── Notification/
    ├── TaskChatListView.swift  ← 需要移动
    └── TaskChatView.swift      ← 需要移动（在 TaskChatListView.swift 内部）
```

**目标结构**：
```
Views/
├── Message/
│   ├── ChatView.swift
│   ├── MessageView.swift
│   ├── TaskChatListView.swift     ← 从 Notification 移过来
│   └── TaskChatView.swift          ← 从 TaskChatListView.swift 拆分出来
└── Notification/
    ├── NotificationListView.swift
    ├── SystemMessageView.swift
    └── InteractionMessageView.swift
```

### 2. 组件拆分（对标主流应用架构）

**当前**：`TaskChatView` 是一个巨大的视图（1200+ 行），职责不清

**目标**：拆分为多个职责清晰的小组件，便于维护和复用

**组件架构**：
```
TaskChatView (主视图，负责布局和状态协调)
├── TaskChatMessageListView (消息列表组件)
│   ├── TaskChatMessageBubble (消息气泡)
│   │   ├── MessageBubble (普通消息)
│   │   └── SystemMessageBubble (系统消息)
│   ├── MessageTimeStamp (时间戳)
│   └── MessageStatusIndicator (状态指示器)
├── TaskChatInputArea (输入区域组件)
│   ├── TaskChatInputBar (输入栏，支持动态高度)
│   │   ├── TaskChatTextField (多行输入框)
│   │   ├── SendButton (发送按钮)
│   │   └── AttachmentButton (附件按钮)
│   └── TaskChatActionMenu (功能菜单，对标微信)
│       ├── ImagePickerButton (图片选择)
│       ├── LocationButton (位置分享)
│       └── TaskDetailButton (任务详情)
├── TaskChatToolbar (工具栏)
│   ├── NavigationTitle (标题)
│   └── MenuButton (更多操作)
└── TaskChatStatusBar (状态栏，任务关闭时显示)
    └── TaskClosedIndicator (关闭状态提示)
```

**组件职责划分**：

1. **TaskChatView**（主视图）
   - 整体布局（VStack）
   - 键盘避让计算
   - 状态协调（ViewModel）
   - 动画管理

2. **TaskChatMessageListView**（消息列表）
   - 消息列表渲染
   - 滚动控制
   - 新消息提示
   - 加载更多

3. **TaskChatInputBar**（输入栏）
   - 多行文本输入
   - 动态高度计算
   - 发送按钮状态
   - 附件按钮

4. **TaskChatActionMenu**（功能菜单）
   - 菜单展开/收起
   - 功能按钮布局
   - 动画过渡

5. **MessageBubble**（消息气泡）
   - 消息内容渲染
   - 样式（发送者/接收者）
   - 时间戳显示
   - 状态指示器

### 3. 状态管理优化

**方案 A：使用 ViewModel 管理状态**（推荐）

```swift
class TaskChatViewModel: ObservableObject {
    // 消息相关
    @Published var messages: [Message] = []
    @Published var isLoading: Bool = false
    
    // 输入相关
    @Published var messageText: String = ""
    @Published var isSending: Bool = false
    
    // UI 状态
    @Published var showActionMenu: Bool = false
    @Published var showNewMessageButton: Bool = false
    @Published var isNearBottom: Bool = true
    
    // 业务逻辑方法
    func sendMessage() { ... }
    func loadMessages() { ... }
    // ...
}
```

**方案 B：使用专门的状态管理类**

```swift
class TaskChatUIState: ObservableObject {
    @Published var showActionMenu: Bool = false
    @Published var showImagePicker: Bool = false
    @Published var showTaskDetail: Bool = false
    // ...
}
```

### 4. 键盘避让实现方案（对标 WhatsApp/微信）

**核心思路**：完全参考 `ChatView` 的实现，并优化以匹配主流应用体验

**关键设计原则**：
1. 输入框固定在屏幕底部（不是相对定位）
2. 键盘弹出时，消息列表整体上移（通过 padding 实现）
3. 键盘动画与视图动画完全同步
4. 支持拖动列表收起键盘

**完整实现**（修正版：更稳的布局模型）：

```swift
struct TaskChatView: View {
    @StateObject private var keyboardObserver = KeyboardHeightObserver()
    @State private var inputAreaHeight: CGFloat = 60 // 动态测量
    
    // ✅ 列表底部 padding = 输入区真实高度（不涉及 keyboardHeight）
    private var messageListBottomPadding: CGFloat {
        return inputAreaHeight
    }
    
    var body: some View {
        ZStack {
            AppColors.background.ignoresSafeArea()
            
            // ✅ 使用 VStack 结构（对标 WhatsApp）
            VStack(spacing: 0) {
                // 消息列表（占据主区域）
                messageListView
                    .padding(.bottom, messageListBottomPadding) // ✅ 直接用输入区高度
                
                // 输入区域（固定在底部，系统自动处理键盘避让）
                TaskChatInputArea(
                    onHeightChange: { height in
                        inputAreaHeight = height // ✅ 动态测量输入区高度
                    }
                )
            }
        }
        // ✅ keyboardHeight 只用于滚动动画同步
        .onChange(of: keyboardObserver.keyboardHeight) { height in
            if height > 0 && isInputFocused {
                scrollToBottom(animation: keyboardObserver.keyboardAnimation)
            }
        }
        // ✅ 输入区高度变化时，布局自动调整（系统动画）
        .animation(keyboardObserver.keyboardAnimation, value: inputAreaHeight)
    }
}
```

**关键改进点**：
1. ✅ 不再用 `keyboardHeight - inputAreaHeight` 计算 padding
2. ✅ 直接用 `inputAreaHeight` 作为列表底部 padding
3. ✅ 系统自动处理键盘避让，输入区会被抬上去
4. ✅ keyboardHeight 只用于滚动动画同步

**输入框动态高度实现**（修正版：使用 SwiftUI 原生 API）：

**⚠️ 重要修正**：
- ❌ 不要用 `.lineLimit(1.5)` 或类似写法（SwiftUI 标准 API 不支持）
- ❌ 不要自己"数换行"去算高度（对自动换行、emoji、不同字体都不准）
- ✅ 使用 SwiftUI 原生的 `TextField(..., axis: .vertical)` 和 `.lineLimit(1...5)`

**✅ 正确的实现**：

```swift
struct TaskChatInputBar: View {
    @Binding var messageText: String
    let onHeightChange: (CGFloat) -> Void
    @FocusState private var isFocused: Bool
    
    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            // 输入框容器
            HStack(spacing: AppSpacing.sm) {
                // ✅ 使用 SwiftUI 原生 API
                TextField(
                    LocalizationKey.actionsEnterMessage.localized,
                    text: $messageText,
                    axis: .vertical  // ✅ 支持多行
                )
                .font(AppTypography.body)
                .lineLimit(1...5)  // ✅ 1-5 行，超过后内部滚动
                .focused($isFocused)
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, 10)
            .background(AppColors.cardBackground)
            .cornerRadius(AppCornerRadius.pill)
            .background(
                // ✅ 使用 GeometryReader 测量真实高度
                GeometryReader { geometry in
                    Color.clear
                        .onAppear {
                            onHeightChange(geometry.size.height)
                        }
                        .onChange(of: geometry.size.height) { newHeight in
                            onHeightChange(newHeight)
                        }
                }
            )
            
            // 发送按钮（垂直居中）
            Button(action: sendMessage) {
                // ...
            }
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.sm)
    }
}
```

**为什么这样更稳**：
1. ✅ 使用 SwiftUI 原生 API，系统自动处理换行和高度
2. ✅ 通过 GeometryReader 测量真实高度，而不是手动计算
3. ✅ 支持自动换行、emoji、不同字体大小
4. ✅ 超过最大行数时，系统自动启用内部滚动

---

## 📝 实现步骤

### Phase 1: 文件迁移和基础重构（1-2 天）

#### 步骤 1.1: 创建新文件结构

1. 在 `Views/Message/` 下创建新文件：
   - `TaskChatView.swift`（主视图）
   - `TaskChatListView.swift`（列表视图，如果需要独立文件）

2. 从 `Views/Notification/TaskChatListView.swift` 复制代码

3. 更新所有 import 和引用路径

#### 步骤 1.2: 拆分 TaskChatView

1. 将 `TaskChatView` 从 `TaskChatListView.swift` 中拆分出来
2. 创建独立的 `TaskChatView.swift` 文件
3. 保持 `TaskChatListView` 在同一个文件或独立文件

#### 步骤 1.3: 更新引用

1. 搜索所有引用 `TaskChatView` 和 `TaskChatListView` 的地方
2. 更新 import 路径
3. 测试编译

**验证点**：
- ✅ 代码可以编译通过
- ✅ 所有引用路径正确
- ✅ 功能未受影响

---

### Phase 2: 键盘避让修复（2-3 天）

#### 步骤 2.1: 重构布局结构

1. 将 `safeAreaInset` 改为 `VStack` 结构
2. 添加 `keyboardPadding` 计算属性
3. 在消息列表的 ScrollView 内容上添加 `.padding(.bottom, keyboardPadding)`

**代码示例**：
```swift
// 修改前
messageListView
    .safeAreaInset(edge: .bottom, spacing: 0) {
        inputAreaView
    }

// 修改后
VStack(spacing: 0) {
    messageListView
        .padding(.bottom, keyboardPadding)
    
    inputAreaView
}
```

#### 步骤 2.2: 优化键盘交互

1. 将 `.scrollDismissesKeyboard(.never)` 改为 `.interactively`
2. 添加键盘动画支持
3. 优化滚动到底部的逻辑

**代码示例**：
```swift
ScrollView {
    // ...
}
.scrollDismissesKeyboard(.interactively) // ✅ 改为 interactively
.onChange(of: keyboardObserver.keyboardHeight) { height in
    if height > 0 && isInputFocused && !viewModel.messages.isEmpty {
        scrollToBottom(animation: keyboardObserver.keyboardAnimation)
    }
}
```

#### 步骤 2.3: 处理输入区高度变化

1. 监听 `showActionMenu` 变化
2. 动态调整 `keyboardPadding` 计算
3. 添加平滑的布局动画

**代码示例**：
```swift
private var keyboardPadding: CGFloat {
    guard keyboardObserver.keyboardHeight > 0 else { return 0 }
    let inputAreaHeight: CGFloat = showActionMenu ? 160 : 60
    return max(keyboardObserver.keyboardHeight - inputAreaHeight, 0)
}

.onChange(of: showActionMenu) { _ in
    // 输入区高度变化时，同步更新布局
    if isInputFocused && !viewModel.messages.isEmpty {
        scrollToBottom(animation: keyboardObserver.keyboardAnimation)
    }
}
```

**验证点**：
- ✅ 键盘弹出时，消息容器同步上移
- ✅ 最后几条消息始终可见
- ✅ 拖动列表可以收起键盘
- ✅ 展开/收起 action menu 时，布局平滑过渡

---

### Phase 3: 状态管理优化（2-3 天）

#### 步骤 3.1: 提取 ViewModel

1. 创建或扩展现有的 `TaskChatDetailViewModel`
2. 将 UI 相关状态移到 ViewModel
3. 将业务逻辑方法移到 ViewModel

**示例**：
```swift
class TaskChatDetailViewModel: ObservableObject {
    // 消息相关
    @Published var messages: [Message] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    // 输入相关
    @Published var messageText: String = ""
    @Published var isSending: Bool = false
    
    // UI 状态（可选，也可以保留在 View 中）
    // @Published var showActionMenu: Bool = false
    
    func sendMessage(content: String, completion: @escaping (Bool) -> Void) {
        // 实现发送消息逻辑
    }
    
    func loadMessages(currentUserId: String) {
        // 实现加载消息逻辑
    }
}
```

#### 步骤 3.2: 简化 View 状态

1. 移除可以移到 ViewModel 的状态
2. 保留纯 UI 相关的状态（如 sheet 显示状态）
3. 使用 ViewModel 的 `@Published` 属性

**示例**：
```swift
struct TaskChatView: View {
    @StateObject private var viewModel: TaskChatDetailViewModel
    @StateObject private var keyboardObserver = KeyboardHeightObserver()
    
    // 只保留纯 UI 状态
    @State private var showLogin = false
    @State private var showActionMenu = false
    @State private var showImagePicker = false
    // ...
    
    // 使用 ViewModel 的状态
    // viewModel.messageText
    // viewModel.messages
    // ...
}
```

**验证点**：
- ✅ 状态管理更清晰
- ✅ View 代码更简洁
- ✅ 业务逻辑集中在 ViewModel

---

### Phase 4: 组件拆分和优化（3-4 天）

#### 步骤 4.1: 拆分消息列表组件

1. 创建 `TaskChatMessageListView` 组件
2. 将消息列表相关逻辑移到组件中
3. 保持接口简洁

**示例**：
```swift
struct TaskChatMessageListView: View {
    let messages: [Message]
    let currentUserId: String?
    let keyboardPadding: CGFloat
    let onScrollToBottom: () -> Void
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    // 消息列表内容
                }
                .padding(.bottom, keyboardPadding)
            }
            // ...
        }
    }
}
```

#### 步骤 4.2: 拆分输入区域组件

1. 创建 `TaskChatInputArea` 组件
2. 将输入栏和 action menu 逻辑移到组件中
3. 处理任务关闭状态的显示

**示例**：
```swift
struct TaskChatInputArea: View {
    @Binding var messageText: String
    @Binding var showActionMenu: Bool
    let isTaskClosed: Bool
    let closedStatusText: String
    let onSendMessage: () -> Void
    let onImagePicker: () -> Void
    // ...
    
    var body: some View {
        VStack(spacing: 0) {
            Divider()
            
            if isTaskClosed {
                // 任务关闭提示
            } else {
                // 正常输入区域
            }
        }
    }
}
```

#### 步骤 4.3: 拆分消息气泡组件

1. 确认 `MessageBubble` 和 `SystemMessageBubble` 是否可复用
2. 如果需要，创建任务聊天专用的气泡组件
3. 保持样式一致性

**验证点**：
- ✅ 组件职责清晰
- ✅ 代码可读性提高
- ✅ 组件可复用

---

### Phase 5: 测试和优化（2-3 天）

#### 步骤 5.1: 功能测试

1. **键盘避让测试**：
   - ✅ 键盘弹出时，消息容器同步上移
   - ✅ 最后几条消息始终可见
   - ✅ 拖动列表可以收起键盘

2. **交互测试**：
   - ✅ 聚焦输入框时，自动滚动到底部
   - ✅ 展开/收起 action menu 时，布局平滑过渡
   - ✅ 发送消息后，自动滚动到底部

3. **边界情况测试**：
   - ✅ 任务关闭状态下的输入框显示
   - ✅ 空消息列表状态
   - ✅ 网络错误状态
   - ✅ WebSocket 连接断开/重连

#### 步骤 5.2: 性能测试

1. 检查是否有不必要的视图重建
2. 优化滚动性能
3. 优化 WebSocket 消息处理

#### 步骤 5.3: 代码审查

1. 检查代码风格一致性
2. 检查是否有重复代码
3. 检查注释和文档

---

## 🔧 技术细节

### 1. 键盘避让计算（修正版：更稳的实现）

**⚠️ 重要修正**：不要用 `keyboardHeight - inputAreaHeight` 去算 padding，这容易算错。

**✅ 正确的做法**（对标 WhatsApp，更稳）：

**核心原则**：
- **列表只关心"输入区高度"**（确保消息不会被输入区挡住）
- **键盘避让交给系统**（不要再手算 keyboardHeight 去推布局）
- **keyboardHeight 只用于**：键盘弹出时滚到底部的动画同步

**核心公式**（修正）：
```swift
// ❌ 错误做法（容易算错）
keyboardPadding = max(keyboardHeight - inputAreaHeight, 0)

// ✅ 正确做法（更稳）
messageListBottomPadding = inputAreaHeight  // 直接用输入区高度
```

**实现方案**：
```swift
struct TaskChatView: View {
    @StateObject private var keyboardObserver = KeyboardHeightObserver()
    @State private var inputAreaHeight: CGFloat = 60 // 动态测量
    
    // ✅ 列表底部 padding = 输入区真实高度（不涉及 keyboardHeight）
    private var messageListBottomPadding: CGFloat {
        return inputAreaHeight
    }
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                LazyVStack {
                    // 消息列表
                }
                .padding(.bottom, messageListBottomPadding) // ✅ 直接用输入区高度
            }
            
            // 输入区（系统会自动处理键盘避让）
            TaskChatInputArea(
                onHeightChange: { height in
                    inputAreaHeight = height // ✅ 动态测量输入区高度
                }
            )
        }
        // keyboardHeight 只用于滚动动画同步
        .onChange(of: keyboardObserver.keyboardHeight) { height in
            if height > 0 && isInputFocused {
                scrollToBottom(animation: keyboardObserver.keyboardAnimation)
            }
        }
    }
}
```

**输入区高度测量**：
```swift
struct TaskChatInputArea: View {
    let onHeightChange: (CGFloat) -> Void
    @State private var measuredHeight: CGFloat = 60
    
    var body: some View {
        VStack(spacing: 0) {
            // 输入栏
            HStack { ... }
            
            // Action Menu（可展开）
            if showActionMenu {
                TaskChatActionMenu()
            }
        }
        .background(
            GeometryReader { geometry in
                Color.clear
                    .onAppear {
                        measuredHeight = geometry.size.height
                        onHeightChange(measuredHeight)
                    }
                    .onChange(of: geometry.size.height) { newHeight in
                        measuredHeight = newHeight
                        onHeightChange(measuredHeight)
                    }
            }
        )
    }
}
```

**为什么这样更稳**：
1. ✅ 不依赖 keyboardHeight 计算，避免算错
2. ✅ 系统自动处理键盘避让，输入区会被抬上去
3. ✅ 列表底部 padding 保证消息不被输入区挡住
4. ✅ 输入区高度变化时（action menu 展开/收起），布局自动调整

### 2. 滚动到底部逻辑（修正版：使用 bottom anchor）

**⚠️ 重要修正**：不要滚动到 `lastMessage.id`，应该滚动到 `scroll_bottom_anchor`。

**为什么**：
- ✅ 最后一条消息高度变化时（图片加载、文本换行），不会抖动
- ✅ action menu 展开/收起时，不会"离底一截"
- ✅ 更符合 WhatsApp/微信的"永远贴底"体验

**✅ 正确的实现**（收敛到 3 个触发点）：

```swift
struct TaskChatView: View {
    @State private var scrollWorkItem: DispatchWorkItem?
    
    // ✅ 统一滚动到底部锚点
    private func scrollToBottom(proxy: ScrollViewProxy, delay: TimeInterval = 0, animation: Animation? = nil) {
        scrollWorkItem?.cancel()
        
        let workItem = DispatchWorkItem {
            // ✅ 滚动到 bottom anchor，而不是 lastMessage.id
            if let animation = animation {
                withAnimation(animation) {
                    proxy.scrollTo("scroll_bottom_anchor", anchor: .bottom)
                }
            } else {
                withAnimation(.easeInOut(duration: 0.2)) {
                    proxy.scrollTo("scroll_bottom_anchor", anchor: .bottom)
                }
            }
        }
        
        scrollWorkItem = workItem
        
        if delay > 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
        } else {
            workItem.perform()
        }
    }
}
```

**滚动触发策略**（只保留 3 个来源，减少互相打架）：

```swift
ScrollViewReader { proxy in
    ScrollView {
        LazyVStack {
            // 消息列表
            ForEach(viewModel.messages) { message in
                MessageBubble(message: message)
            }
            
            // ✅ 底部锚点（关键）
            Color.clear
                .frame(height: 1)
                .id("scroll_bottom_anchor")
        }
        .padding(.bottom, messageListBottomPadding)
    }
    // ✅ 触发点 1：首次加载完成
    .onChange(of: viewModel.isInitialLoadComplete) { completed in
        if completed && !viewModel.messages.isEmpty {
            scrollToBottom(proxy: proxy, delay: 0.1)
        }
    }
    // ✅ 触发点 2：新消息到达且用户在底部（或输入框 focused）
    .onChange(of: viewModel.messages.count) { newCount in
        if newCount > 0 {
            if isInputFocused || isNearBottom {
                scrollToBottom(proxy: proxy, delay: 0.1)
            }
        }
    }
    // ✅ 触发点 3：键盘从 0 -> >0（同步键盘动画滚一下）
    .onChange(of: keyboardObserver.keyboardHeight) { height in
        if height > 0 && isInputFocused && !viewModel.messages.isEmpty {
            scrollToBottom(proxy: proxy, delay: 0, animation: keyboardObserver.keyboardAnimation)
        }
    }
}
```

**删除的触发点**（避免互相打架）：
- ❌ `onAppear` 中的滚动（已由 `isInitialLoadComplete` 处理）
- ❌ `onChange(of: isInputFocused)` 中的滚动（已由 `keyboardHeight` 处理）
- ❌ `onChange(of: showActionMenu)` 中的滚动（不需要）

### 3. 动画同步

**键盘动画**：
```swift
.animation(keyboardObserver.keyboardAnimation, value: keyboardObserver.keyboardHeight)
.animation(keyboardObserver.keyboardAnimation, value: showActionMenu)
```

**滚动动画**：
```swift
withAnimation(keyboardObserver.keyboardAnimation) {
    proxy.scrollTo(lastMessage.id, anchor: .bottom)
}
```

### 4. WebSocket 消息处理优化

**优化建议**（对标 Messenger 性能）：
1. 使用防抖机制处理消息更新
2. 批量更新消息列表，减少视图重建
3. 只在视图可见时处理消息
4. 使用 `@MainActor` 确保 UI 更新在主线程

**实现示例**：
```swift
class TaskChatDetailViewModel: ObservableObject {
    @Published var messages: [Message] = []
    private var messageUpdateWorkItem: DispatchWorkItem?
    
    func handleWebSocketMessage(_ message: Message) {
        // 防抖：取消之前的更新任务
        messageUpdateWorkItem?.cancel()
        
        // 创建新的更新任务（延迟 0.1 秒）
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            
            // 批量更新消息列表
            DispatchQueue.main.async {
                if !self.messages.contains(where: { $0.id == message.id }) {
                    // 使用二分插入保持有序
                    if let insertIndex = self.messages.firstIndex(where: { 
                        ($0.createdAt ?? "") > (message.createdAt ?? "") 
                    }) {
                        self.messages.insert(message, at: insertIndex)
                    } else {
                        self.messages.append(message)
                    }
                }
            }
        }
        
        messageUpdateWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: workItem)
    }
}
```

### 5. 安全区域处理（对标主流应用）

**关键点**：
- 适配不同 iPhone 型号（有刘海、没有、有 home indicator 等）
- 正确处理 bottom safe area
- 横竖屏切换适配

**实现方案**：
```swift
struct TaskChatView: View {
    @State private var safeAreaInsets = EdgeInsets()
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                messageListView
                    .padding(.bottom, keyboardPadding)
                
                inputAreaView
                    .padding(.bottom, safeAreaInsets.bottom) // ✅ 使用安全区域
            }
            .onAppear {
                // 获取安全区域
                safeAreaInsets = geometry.safeAreaInsets
            }
            .onChange(of: geometry.safeAreaInsets) { newInsets in
                // 横竖屏切换时更新
                safeAreaInsets = newInsets
            }
        }
    }
}
```

### 6. 性能优化最佳实践（对标 Messenger）

**1. 视图重建优化**：
```swift
// ✅ 使用 @StateObject 而不是 @ObservedObject
@StateObject private var viewModel: TaskChatDetailViewModel

// ✅ 使用 id 稳定化，避免不必要的重建
ForEach(viewModel.messages, id: \.id) { message in
    MessageBubble(message: message)
        .id(message.id) // 确保稳定的 id
}

// ✅ 使用 LazyVStack 进行虚拟化
LazyVStack(spacing: AppSpacing.sm) {
    // 只渲染可见的消息
}
```

**2. 滚动性能优化**：
```swift
ScrollView {
    LazyVStack(spacing: 0) {
        // 使用 LazyVStack 而不是 VStack
        // 只渲染可见区域的消息
    }
}
.scrollDismissesKeyboard(.interactively)
```

**3. 动画性能优化**：
```swift
// ✅ 使用系统键盘动画，而不是自定义动画
.animation(keyboardObserver.keyboardAnimation, value: keyboardObserver.keyboardHeight)

// ✅ 避免在动画中执行复杂计算
// ❌ 错误示例
.animation(.easeInOut(duration: 0.3), value: complexCalculation())

// ✅ 正确示例
.animation(keyboardObserver.keyboardAnimation, value: keyboardObserver.keyboardHeight)
```

---

## 📊 预期效果（对标主流应用）

### 用户体验改进（达到 WhatsApp/微信/Messenger 水平）

1. **键盘交互**（对标 WhatsApp）：
   - ✅ 键盘弹出时，消息容器同步上移（100% 解决）
   - ✅ 最后几条消息始终可见（100% 解决）
   - ✅ 拖动列表可以收起键盘（新增功能，对标 WhatsApp）
   - ✅ 键盘动画与视图动画完全同步（对标微信）
   - ✅ 所有交互都有平滑的动画过渡

2. **输入框体验**（对标微信）：
   - ✅ 支持多行输入（1-5 行）
   - ✅ 高度随内容动态扩展
   - ✅ 超过最大行数时内部滚动
   - ✅ 输入区元素垂直居中
   - ✅ 高度变化动画平滑（0.25-0.3 秒）

3. **附件菜单**（对标微信/Messenger）：
   - ✅ 菜单在输入框上方展开
   - ✅ 展开/收起动画平滑
   - ✅ 与键盘协调，无冲突覆盖
   - ✅ 布局变化无闪烁

4. **交互流畅度**（对标 Messenger）：
   - ✅ 平滑的键盘动画
   - ✅ 平滑的布局过渡
   - ✅ 更快的响应速度（< 100ms）
   - ✅ 消息数量大时滚动流畅（60fps）

5. **视觉一致性**（对标 Messenger）：
   - ✅ 统一的视觉风格
   - ✅ 清晰的视觉层次
   - ✅ 符合 iOS 设计规范
   - ✅ 适配不同设备尺寸

### 代码质量改进

1. **可维护性**：
   - ✅ 代码结构更清晰（组件化）
   - ✅ 组件职责更明确（单一职责原则）
   - ✅ 状态管理更简单（从 15+ 减少到 5-8 个状态变量）
   - ✅ 代码行数减少（从 1200+ 行拆分到多个小文件）

2. **可扩展性**：
   - ✅ 更容易添加新功能（组件化架构）
   - ✅ 更容易复用组件（独立组件）
   - ✅ 更容易测试（ViewModel 分离）
   - ✅ 更容易维护（清晰的代码结构）

3. **性能**（对标 Messenger）：
   - ✅ 减少不必要的视图重建（使用 @StateObject）
   - ✅ 优化滚动性能（使用 LazyVStack）
   - ✅ 优化 WebSocket 消息处理（批量更新）
   - ✅ 消息数量大时滚动流畅（虚拟化列表）

### 对标结果预期

| 特性 | 当前状态 | 目标状态 | 对标应用 |
|------|---------|---------|---------|
| 键盘同步 | ❌ 不同步 | ✅ 完美同步 | WhatsApp |
| 输入框高度 | ❌ 固定高度 | ✅ 动态扩展 | 微信 |
| 拖动收起键盘 | ❌ 不支持 | ✅ 支持 | WhatsApp |
| 附件菜单动画 | ⚠️ 不够平滑 | ✅ 平滑过渡 | 微信 |
| 滚动性能 | ⚠️ 一般 | ✅ 流畅（60fps） | Messenger |
| 代码结构 | ❌ 混乱 | ✅ 清晰 | - |

---

## ⚠️ 风险和注意事项

### 1. 迁移风险

**风险**：文件迁移可能导致引用路径错误

**缓解措施**：
- 使用全局搜索替换
- 逐个验证所有引用
- 充分测试

### 2. 兼容性风险

**风险**：新实现可能与现有功能不兼容

**缓解措施**：
- 保持 API 接口不变
- 逐步迁移，不要一次性替换
- 保留旧代码作为备份

### 3. 性能风险

**风险**：重构可能引入性能问题

**缓解措施**：
- 使用 Instruments 进行性能分析
- 优化视图重建逻辑
- 使用 `@StateObject` 而不是 `@ObservedObject`

---

## 📚 参考资料

### 内部文档

1. `ios/IOS_ISSUES_ANALYSIS.md` - iOS 问题分析
2. `ios/link2ur/link2ur/Views/Message/ChatView.swift` - 参考实现

### 外部资源

**Apple 官方文档**：
1. [SwiftUI Keyboard Handling](https://developer.apple.com/documentation/swiftui/managing-keyboard-input)
2. [Human Interface Guidelines - Messages](https://developer.apple.com/design/human-interface-guidelines/messages)

**UX 设计参考**：
1. [WhatsApp Minimalist UX Principles](https://medium.com/design-bootcamp/whatsapp-minimalist-ux-principles-behind-the-chat-screen-94009e602a8d)
2. [Why WhatsApp's Chat UI Just Works](https://medium.com/design-bootcamp/why-whatsapps-chat-ui-just-works-and-what-you-can-learn-from-it-bd89fb114423)
3. [WeChat Design Patterns](https://uxdesign.cc/wechat-design-patterns)

**技术实现参考**：
1. [SwiftUI Keyboard Avoidance](https://www.swiftbysundell.com/articles/handling-keyboards-in-swiftui/)
2. [iOS Keyboard Handling Best Practices](https://developer.apple.com/videos/play/wwdc2020/10052/)

**主流应用分析**：
1. WhatsApp - 极简设计，完美的键盘同步
2. 微信 - 动态输入框，平滑的动画过渡
3. Facebook Messenger - 一致性视觉风格，高性能滚动

---

## ✅ 检查清单（对标主流应用标准）

### Phase 1: 文件迁移
- [ ] 创建新文件结构
- [ ] 拆分 TaskChatView
- [ ] 更新所有引用
- [ ] 测试编译

### Phase 2: 键盘避让修复（对标 WhatsApp/微信）
- [ ] 重构布局结构（VStack + padding）
- [ ] 实现键盘同步机制（消息列表随键盘上移）
- [ ] 优化键盘交互（.interactively）
- [ ] 处理输入区高度变化（动态计算）
- [ ] 实现拖动收起键盘功能
- [ ] 键盘动画与视图动画同步
- [ ] 功能测试（所有设备型号）

### Phase 3: 输入框动态高度（对标微信）
- [ ] 实现多行输入（1-5 行）
- [ ] 动态高度计算
- [ ] 超过最大行数时内部滚动
- [ ] 输入区元素垂直居中
- [ ] 高度变化动画平滑

### Phase 4: 附件菜单协调（对标微信/Messenger）
- [ ] 菜单在输入框上方展开
- [ ] 展开/收起动画平滑（0.25-0.3 秒）
- [ ] 与键盘协调，无冲突覆盖
- [ ] 布局变化无闪烁

### Phase 5: 状态管理优化
- [ ] 提取 ViewModel
- [ ] 简化 View 状态（从 15+ 减少到 5-8 个）
- [ ] 测试状态管理
- [ ] 状态一致性检查

### Phase 6: 组件拆分
- [ ] 拆分消息列表组件
- [ ] 拆分输入区域组件（支持动态高度）
- [ ] 拆分附件菜单组件
- [ ] 拆分消息气泡组件
- [ ] 代码审查

### Phase 7: 任务关闭状态处理
- [ ] 输入框禁用/隐藏逻辑
- [ ] 状态提示清晰显示
- [ ] 操作按钮布局合理
- [ ] UI 状态变化测试

### Phase 8: 测试和优化（对标主流应用标准）
- [ ] **功能测试**
  - [ ] 键盘弹出时消息容器同步上移
  - [ ] 最后几条消息始终可见
  - [ ] 拖动列表可以收起键盘
  - [ ] 输入框高度动态扩展
  - [ ] 附件菜单展开/收起平滑
  - [ ] 任务关闭状态处理正确
- [ ] **性能测试**
  - [ ] 消息数量大时滚动流畅
  - [ ] 键盘弹出无跳帧
  - [ ] 无不必要的视图重建
  - [ ] WebSocket 消息处理优化
- [ ] **兼容性测试**
  - [ ] 不同 iPhone 型号（有刘海/无刘海/有 home indicator）
  - [ ] 横竖屏切换
  - [ ] 安全区域适配
  - [ ] 第三方键盘支持
- [ ] **代码审查**
  - [ ] 代码风格一致性
  - [ ] 无重复代码
  - [ ] 注释和文档完善
  - [ ] 组件可复用性

---

## 📝 更新日志

| 日期 | 版本 | 更新内容 | 作者 |
|------|------|----------|------|
| 2025-01-XX | 1.0 | 初始版本 | 开发团队 |

---

## 🤝 贡献指南

如有问题或建议，请：
1. 创建 Issue
2. 提交 Pull Request
3. 联系开发团队

---

**文档结束**
