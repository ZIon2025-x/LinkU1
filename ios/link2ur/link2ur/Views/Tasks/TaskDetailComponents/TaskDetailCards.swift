//
//  TaskDetailCards.swift
//  link2ur
//
//  任务详情页可复用的卡片组件
//  这些组件从 TaskDetailView.swift 中提取，可独立使用
//

import SwiftUI
import Combine

// MARK: - 任务状态徽章

/// 任务状态徽章组件
struct TaskStatusBadge: View {
    let status: TaskStatus
    
    var body: some View {
        Text(status.displayText)
            .font(AppTypography.caption)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(statusColor)
            .clipShape(Capsule())
    }
    
    private var statusColor: Color {
        switch status {
        case .open:
            return AppColors.primary
        case .inProgress:
            return .blue
        case .completed:
            return .green
        case .cancelled:
            return .red
        case .pendingConfirmation:
            return .orange
        case .pendingPayment:
            return .purple
        }
    }
}

// MARK: - 任务金额显示

/// 任务金额显示组件
/// 支持从 Task 对象直接初始化，也支持独立参数初始化
struct TaskAmountView: View {
    let reward: Double
    let currency: String
    let pointsReward: Int?
    let fontSize: CGFloat
    let useLocalizedPoints: Bool
    
    /// 独立参数初始化
    init(reward: Double, currency: String = "GBP", pointsReward: Int? = nil, fontSize: CGFloat = 28, useLocalizedPoints: Bool = false) {
        self.reward = reward
        self.currency = currency
        self.pointsReward = pointsReward
        self.fontSize = fontSize
        self.useLocalizedPoints = useLocalizedPoints
    }
    
    /// 从 Task 对象初始化（兼容原 TaskRewardView）
    init(task: Task, fontSize: CGFloat = 32) {
        self.reward = task.reward
        self.currency = "GBP"
        self.pointsReward = task.pointsReward
        self.fontSize = fontSize
        self.useLocalizedPoints = true
    }
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            // 现金奖励
            if reward > 0 {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(currencySymbol)
                        .font(AppTypography.title3)
                        .fontWeight(.bold)
                    Text(formattedReward)
                        .font(.system(size: fontSize, weight: .bold, design: .rounded))
                }
                .foregroundColor(AppColors.primary)
            }
            
            // 积分奖励
            if let points = pointsReward, points > 0 {
                HStack(spacing: 4) {
                    IconStyle.icon("star.circle.fill", size: 16)
                    Text(pointsText(points))
                        .font(AppTypography.bodyBold)
                }
                .foregroundColor(.orange)
                .padding(.bottom, 4)
            }
        }
    }
    
    private var currencySymbol: String {
        switch currency.uppercased() {
        case "GBP": return "£"
        case "USD": return "$"
        case "EUR": return "€"
        case "CNY": return "¥"
        default: return currency
        }
    }
    
    private var formattedReward: String {
        if reward.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", reward)
        } else {
            return String(format: "%.2f", reward)
        }
    }
    
    private func pointsText(_ points: Int) -> String {
        if useLocalizedPoints {
            return String(format: LocalizationKey.pointsAmountFormat.localized, points)
        } else {
            return "+\(points)"
        }
    }
}

// MARK: - 任务信息行

/// 任务信息单行组件
struct TaskInfoRow: View {
    let icon: String
    let title: String
    let value: String
    var iconColor: Color = AppColors.primary
    
    var body: some View {
        HStack(spacing: AppSpacing.md) {
            Circle()
                .fill(iconColor.opacity(0.1))
                .frame(width: 36, height: 36)
                .overlay(
                    Image(systemName: icon)
                        .font(.system(size: 14))
                        .foregroundColor(iconColor)
                )
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textSecondary)
                Text(value)
                    .font(AppTypography.body)
                    .fontWeight(.medium)
                    .foregroundColor(AppColors.textPrimary)
            }
            
            Spacer()
        }
    }
}

// MARK: - 任务标签视图

/// 任务标签样式枚举
enum TaskTagStyle: Equatable {
    case primary       // 主色调：主色前景 + 浅主色背景
    case secondary     // 次要：灰色前景 + 灰色背景
    case vip           // VIP：白色前景 + 橙色背景
    case superTask     // Super：白色前景 + 紫色背景
    case custom(foreground: Color, background: Color)
    
    var foregroundColor: Color {
        switch self {
        case .primary: return AppColors.primary
        case .secondary: return AppColors.textSecondary
        case .vip, .superTask: return .white
        case .custom(let fg, _): return fg
        }
    }
    
    var backgroundColor: Color {
        switch self {
        case .primary: return AppColors.primaryLight
        case .secondary: return AppColors.background
        case .vip: return .orange
        case .superTask: return .purple
        case .custom(_, let bg): return bg
        }
    }
    
    var font: Font {
        switch self {
        case .vip, .superTask: return AppTypography.caption2
        default: return AppTypography.caption
        }
    }
}

/// 任务标签组件（分类、位置、等级等）
struct TaskTagView: View {
    let text: String
    let icon: String
    var style: TaskTagStyle = .secondary
    
    /// 便捷初始化：兼容原有 isPrimary 用法
    init(text: String, icon: String, isPrimary: Bool = false) {
        self.text = text
        self.icon = icon
        self.style = isPrimary ? .primary : .secondary
    }
    
    /// 完整初始化：支持所有样式
    init(text: String, icon: String, style: TaskTagStyle) {
        self.text = text
        self.icon = icon
        self.style = style
    }
    
    var body: some View {
        Label(text, systemImage: icon)
            .font(style.font)
            .fontWeight(style == .vip || style == .superTask ? .bold : .semibold)
            .foregroundColor(style.foregroundColor)
            .padding(.horizontal, style == .vip || style == .superTask ? 8 : 10)
            .padding(.vertical, style == .vip || style == .superTask ? 4 : 6)
            .background(style.backgroundColor)
            .clipShape(Capsule())
    }
}

// MARK: - 任务描述卡片

/// 任务描述展示卡片
struct TaskDescriptionCard: View {
    let description: String
    @State private var isExpanded: Bool = false
    
    private let maxCollapsedLines = 5
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack {
                Image(systemName: "text.alignleft")
                    .font(.system(size: 18))
                    .foregroundColor(AppColors.primary)
                Text(LocalizationKey.taskDetailTaskDescription.localized)
                    .font(AppTypography.title3)
                    .foregroundColor(AppColors.textPrimary)
            }
            
            Text(description)
                .font(AppTypography.body)
                .foregroundColor(AppColors.textSecondary)
                .lineSpacing(6)
                .lineLimit(isExpanded ? nil : maxCollapsedLines)
                .fixedSize(horizontal: false, vertical: true)
            
            // 展开/收起按钮（如果文本较长）
            if description.count > 200 {
                Button(action: { withAnimation { isExpanded.toggle() } }) {
                    HStack(spacing: 4) {
                        Text(isExpanded ? LocalizationKey.taskDetailCollapse.localized : LocalizationKey.taskDetailExpandAll.localized)
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    }
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.primary)
                }
            }
        }
        .padding(DeviceInfo.isPad ? AppSpacing.xl : AppSpacing.lg)
        .background(AppColors.cardBackground)
        .cornerRadius(AppCornerRadius.large)
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)
    }
}

// MARK: - 用户信息卡片

/// 用户信息展示卡片（发布者/接单者）
struct TaskUserCard: View {
    let avatarUrl: String?
    let displayName: String
    let rating: Double?
    let completedTasks: Int?
    let isVerified: Bool
    let role: String // "poster" 或 "taker"
    
    var body: some View {
        HStack(spacing: AppSpacing.md) {
            // 头像
            AsyncImageView(
                urlString: avatarUrl ?? "",
                placeholder: Image(systemName: "person.circle.fill"),
                width: 50,
                height: 50,
                contentMode: .fill,
                cornerRadius: 25
            )
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Text(displayName)
                        .font(AppTypography.bodyBold)
                        .foregroundColor(AppColors.textPrimary)
                    
                    if isVerified {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
                
                HStack(spacing: AppSpacing.md) {
                    if let rating = rating {
                        HStack(spacing: 2) {
                            Image(systemName: "star.fill")
                                .font(.caption2)
                                .foregroundColor(.yellow)
                            Text(String(format: "%.1f", rating))
                                .font(AppTypography.caption)
                                .foregroundColor(AppColors.textSecondary)
                        }
                    }
                    
                    if let completed = completedTasks {
                        Text(LocalizationKey.taskDetailCompletedCount.localized(completed))
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
            }
            
            Spacer()
            
            // 角色标签
            Text(role == "poster" ? LocalizationKey.myTasksRolePoster.localized : LocalizationKey.myTasksRoleTaker.localized)
                .font(AppTypography.caption)
                .foregroundColor(AppColors.textSecondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(AppColors.background)
                .cornerRadius(4)
        }
        .padding(AppSpacing.md)
        .background(AppColors.cardBackground)
        .cornerRadius(AppCornerRadius.medium)
    }
}

// MARK: - 操作按钮样式

/// 主要操作按钮
struct TaskPrimaryActionButton: View {
    let title: String
    let icon: String?
    let isLoading: Bool
    let action: () -> Void
    
    init(title: String, icon: String? = nil, isLoading: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.isLoading = isLoading
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else {
                    if let icon = icon {
                        Image(systemName: icon)
                    }
                    Text(title)
                        .fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(AppColors.primary)
            .foregroundColor(.white)
            .cornerRadius(AppCornerRadius.medium)
        }
        .disabled(isLoading)
    }
}

/// 次要操作按钮
struct TaskSecondaryActionButton: View {
    let title: String
    let icon: String?
    let color: Color
    let action: () -> Void
    
    init(title: String, icon: String? = nil, color: Color = AppColors.textSecondary, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.color = color
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon = icon {
                    Image(systemName: icon)
                }
                Text(title)
                    .fontWeight(.medium)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(color.opacity(0.1))
            .foregroundColor(color)
            .cornerRadius(AppCornerRadius.medium)
            .overlay(
                RoundedRectangle(cornerRadius: AppCornerRadius.medium)
                    .stroke(color.opacity(0.3), lineWidth: 1)
            )
        }
    }
}

// MARK: - 截止时间倒计时

/// 截止时间倒计时组件
struct TaskDeadlineCountdown: View {
    let deadline: Date
    @State private var timeRemaining: String = ""
    @State private var isUrgent: Bool = false
    
    let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: isUrgent ? "exclamationmark.circle.fill" : "clock.fill")
                .foregroundColor(isUrgent ? .red : AppColors.primary)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(LocalizationKey.taskDetailDeadlineLabel.localized)
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textSecondary)
                Text(timeRemaining)
                    .font(AppTypography.bodyBold)
                    .foregroundColor(isUrgent ? .red : AppColors.textPrimary)
            }
        }
        .onAppear { updateTimeRemaining() }
        .onReceive(timer) { _ in updateTimeRemaining() }
    }
    
    private func updateTimeRemaining() {
        let now = Date()
        let remaining = deadline.timeIntervalSince(now)
        
        if remaining <= 0 {
            timeRemaining = LocalizationKey.taskDetailExpired.localized
            isUrgent = true
        } else if remaining < 3600 {
            let minutes = Int(remaining / 60)
            timeRemaining = LocalizationKey.taskDetailRemainingMinutes.localized(minutes)
            isUrgent = true
        } else if remaining < 86400 {
            let hours = Int(remaining / 3600)
            timeRemaining = LocalizationKey.taskDetailRemainingHours.localized(hours)
            isUrgent = remaining < 7200
        } else {
            let days = Int(remaining / 86400)
            timeRemaining = LocalizationKey.taskDetailRemainingDays.localized(days)
            isUrgent = false
        }
    }
}

// MARK: - Preview

#if DEBUG
struct TaskDetailCards_Previews: PreviewProvider {
    static var previews: some View {
        ScrollView {
            VStack(spacing: 20) {
                TaskStatusBadge(status: .open)
                TaskStatusBadge(status: .inProgress)
                TaskStatusBadge(status: .completed)
                
                TaskAmountView(reward: 50, pointsReward: 100)
                
                TaskInfoRow(icon: "clock.fill", title: LocalizationKey.tasksPublishTime.localized, value: "2024-01-15 10:30")
                
                TaskTagView(text: "跑腿", icon: "tag.fill", isPrimary: true)
                
                TaskPrimaryActionButton(title: "申请任务", icon: "hand.raised.fill", isLoading: false) {}
                
                TaskSecondaryActionButton(title: "取消", icon: "xmark") {}
            }
            .padding()
        }
    }
}
#endif
