# TaskDetailView 组件库

## 概述

本目录包含从 `TaskDetailView.swift` 中提取的可复用 UI 组件。这些组件可以在任务详情页面及其他需要展示任务信息的地方使用。

## 迁移状态

| 组件 | 原位置 | 迁移状态 | 说明 |
|------|--------|----------|------|
| `TaskRewardView` | TaskDetailView.swift | ✅ 已迁移 | 使用 `TaskAmountView(task:)` 替代 |
| 分类/位置标签 | TaskHeaderCard 内联 | ✅ 已迁移 | 使用 `TaskTagView` 替代 |
| VIP/Super 标签 | TaskHeaderCard 内联 | ✅ 已迁移 | 使用 `TaskTagView(style: .vip/.superTask)` |
| `TaskPosterInfoView` | TaskDetailView.swift | ⏭️ 保留 | 含 NavigationLink 和业务逻辑 |
| `ConfirmationCountdownView` | TaskDetailView.swift | ⏭️ 保留 | 秒级精度需求，与组件库分钟级不同 |
| `TaskActionButtonsView` | TaskDetailView.swift | ⏭️ 保留 | 使用统一的 PrimaryButtonStyle |

## 组件文件

### TaskDetailCards.swift

包含以下可复用组件：

| 组件名 | 说明 | 用途 |
|--------|------|------|
| `TaskStatusBadge` | 任务状态徽章 | 显示任务状态（开放、进行中、已完成等） |
| `TaskAmountView` | 金额展示组件 | 显示任务报酬和积分奖励，支持 Task 对象或独立参数 |
| `TaskInfoRow` | 信息行组件 | 显示带图标的单行信息 |
| `TaskTagView` | 标签组件 | 显示任务分类、位置、等级等标签，支持多种样式 |
| `TaskTagStyle` | 标签样式枚举 | primary/secondary/vip/superTask/custom |
| `TaskDescriptionCard` | 描述卡片 | 展示任务描述，支持展开/收起 |
| `TaskUserCard` | 用户卡片 | 显示发布者/接单者信息 |
| `TaskPrimaryActionButton` | 主要操作按钮 | 申请、确认等主要操作 |
| `TaskSecondaryActionButton` | 次要操作按钮 | 取消、关闭等次要操作 |
| `TaskDeadlineCountdown` | 截止时间倒计时 | 显示任务截止时间及紧急状态（分钟级） |

## 使用示例

```swift
import SwiftUI

struct MyTaskView: View {
    let task: Task
    
    var body: some View {
        VStack(spacing: 16) {
            // 状态徽章
            TaskStatusBadge(status: task.status)
            
            // 金额显示 - 方式1：从 Task 对象
            TaskAmountView(task: task)
            
            // 金额显示 - 方式2：独立参数
            TaskAmountView(
                reward: 50.0,
                pointsReward: 100
            )
            
            // 标签 - 主色调
            TaskTagView(text: "跑腿", icon: "tag.fill", style: .primary)
            
            // 标签 - VIP 样式
            TaskTagView(text: "VIP任务", icon: "star.fill", style: .vip)
            
            // 信息行
            TaskInfoRow(
                icon: "mappin.circle.fill",
                title: "位置",
                value: task.location
            )
            
            // 操作按钮
            TaskPrimaryActionButton(
                title: "申请任务",
                icon: "hand.raised.fill",
                isLoading: false
            ) {
                // 处理申请
            }
        }
    }
}
```

## TaskDetailView 现有组件

`TaskDetailView.swift` 内部保留以下组件（紧密耦合业务逻辑）：

- `TaskHeaderCard` - 任务头部卡片（已使用 TaskTagView 和 TaskAmountView）
- `TaskInfoCard` - 任务信息卡片（描述、时间、发布者）
- `TaskTimeInfoView` - 时间信息视图
- `TaskPosterInfoView` - 发布者信息视图（含 NavigationLink）
- `ConfirmationCountdownView` - 确认倒计时（秒级精度）
- `TaskCompletionEvidenceCard` - 完成证据卡片
- `TaskDetailContentView` - 主体内容视图
- `TaskImageCarouselView` - 图片轮播
- `TaskActionButtonsView` - 操作按钮视图（使用 PrimaryButtonStyle）
- `StatusBadge` - 状态徽章

## 设计原则

1. **可复用性** - 组件不依赖特定的业务状态，通过参数传入数据
2. **一致性** - 使用 `AppColors`、`AppTypography`、`AppSpacing` 等设计系统
3. **可访问性** - 支持 Dynamic Type 和语义化颜色
4. **性能** - 使用 `@State` 管理本地状态，避免不必要的重绘
5. **渐进迁移** - 优先迁移低风险组件，复杂业务组件保留在原位置

## 未来扩展

如需进一步拆分 `TaskDetailView.swift`，建议：

1. 将紧密耦合的组件保留在原文件
2. 将可复用的 UI 组件提取到此目录
3. 使用 `@EnvironmentObject` 或 `@Binding` 传递状态
4. 为新组件添加 Preview 和单元测试
5. 新功能开发时优先使用组件库中的组件
