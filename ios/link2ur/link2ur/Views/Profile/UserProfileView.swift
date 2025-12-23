import SwiftUI
import Combine

struct UserProfileView: View {
    let userId: String
    @StateObject private var viewModel = UserProfileViewModel()
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        ZStack {
            AppColors.background
                .ignoresSafeArea()
            
            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let profile = viewModel.userProfile {
                ScrollView {
                    VStack(spacing: AppSpacing.lg) {
                        // 用户信息卡片
                        UserInfoCard(profile: profile)
                            .padding(.horizontal, AppSpacing.md)
                            .padding(.top, AppSpacing.md)
                        
                        // 统计数据
                        StatsRow(profile: profile)
                            .padding(.horizontal, AppSpacing.md)
                        
                        // 最近任务
                        if !profile.recentTasks.isEmpty {
                            VStack(alignment: .leading, spacing: AppSpacing.md) {
                                HStack {
                                    Image(systemName: "list.bullet.rectangle")
                                        .foregroundColor(AppColors.primary)
                                        .font(.system(size: 18))
                                    Text("最近任务")
                                        .font(AppTypography.title3)
                                        .fontWeight(.semibold)
                                        .foregroundColor(AppColors.textPrimary)
                                }
                                .padding(.horizontal, AppSpacing.md)
                                
                                ForEach(profile.recentTasks.prefix(5)) { task in
                                    NavigationLink(destination: TaskDetailView(taskId: task.id)) {
                                        TaskRowView(task: task)
                                    }
                                    .buttonStyle(ScaleButtonStyle())
                                    .padding(.horizontal, AppSpacing.md)
                                }
                            }
                            .padding(.top, AppSpacing.md)
                        }
                        
                        // 评价
                        if !profile.reviews.isEmpty {
                            VStack(alignment: .leading, spacing: AppSpacing.md) {
                                HStack {
                                    Image(systemName: "star.fill")
                                        .foregroundColor(.yellow)
                                        .font(.system(size: 18))
                                    Text("用户评价")
                                        .font(AppTypography.title3)
                                        .fontWeight(.semibold)
                                        .foregroundColor(AppColors.textPrimary)
                                }
                                .padding(.horizontal, AppSpacing.md)
                                
                                ForEach(profile.reviews.prefix(5)) { review in
                                    ReviewRowView(review: review)
                                        .padding(.horizontal, AppSpacing.md)
                                }
                            }
                            .padding(.top, AppSpacing.md)
                        }
                        
                        Spacer(minLength: AppSpacing.xl)
                    }
                    .padding(.bottom, AppSpacing.xl)
                }
            } else if let error = viewModel.errorMessage {
                ErrorStateView(
                    message: error,
                    retryAction: {
                        viewModel.loadUserProfile(userId: userId)
                    }
                )
            }
        }
        .navigationTitle("用户资料")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(AppColors.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .onAppear {
            if viewModel.userProfile == nil {
                viewModel.loadUserProfile(userId: userId)
            }
        }
    }
}

// MARK: - ViewModel

@MainActor
class UserProfileViewModel: ObservableObject {
    @Published var userProfile: UserProfileResponse?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private var cancellables = Set<AnyCancellable>()
    private let apiService = APIService.shared
    
    func loadUserProfile(userId: String) {
        isLoading = true
        errorMessage = nil
        
        // 使用完整资料 API
        apiService.getUserProfileDetail(userId: userId)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    if case .failure(let error) = completion {
                        // 使用 ErrorHandler 统一处理错误
                        ErrorHandler.shared.handle(error, context: "加载用户资料")
                        // 错误处理：直接使用 APIError 的 userFriendlyMessage 或 localizedDescription
                        self?.errorMessage = (error as? APIError)?.userFriendlyMessage ?? error.localizedDescription
                    }
                },
                receiveValue: { [weak self] profile in
                    self?.userProfile = profile
                    self?.isLoading = false
                }
            )
            .store(in: &cancellables)
    }
}

// MARK: - Models (已移至 Models/User.swift)

// MARK: - Views

struct UserInfoCard: View {
    let profile: UserProfileResponse
    
    var body: some View {
        VStack(spacing: 0) {
            // 顶部装饰性渐变条
            LinearGradient(
                gradient: Gradient(colors: AppColors.gradientPrimary),
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(height: 4)
            .cornerRadius(2, corners: [.topLeft, .topRight])
            
            VStack(spacing: AppSpacing.lg) {
                // 渐变背景
                ZStack {
                    // 装饰性圆形背景
                    Circle()
                        .fill(
                            RadialGradient(
                                gradient: Gradient(colors: [
                                    AppColors.primary.opacity(0.15),
                                    AppColors.primary.opacity(0.05),
                                    Color.clear
                                ]),
                                center: .center,
                                startRadius: 0,
                                endRadius: 80
                            )
                        )
                        .frame(width: 160, height: 160)
                        .offset(y: -20)
                    
                    VStack(spacing: AppSpacing.lg) {
                        // 头像 - 带阴影和边框
                        ZStack {
                            // 外层光晕效果
                            Circle()
                                .fill(
                                    RadialGradient(
                                        gradient: Gradient(colors: [
                                            AppColors.primary.opacity(0.2),
                                            Color.clear
                                        ]),
                                        center: .center,
                                        startRadius: 0,
                                        endRadius: 60
                                    )
                                )
                                .frame(width: 120, height: 120)
                                .blur(radius: 8)
                            
                            // 渐变边框
                            Circle()
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: AppColors.gradientPrimary),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 110, height: 110)
                                .shadow(color: AppColors.primary.opacity(0.4), radius: 16, x: 0, y: 8)
                            
                            AvatarView(
                                urlString: profile.user.avatar,
                                size: 100,
                                placeholder: Image(systemName: "person.fill")
                            )
                            .overlay(
                                Circle()
                                    .stroke(.white, lineWidth: 4)
                            )
                        }
                        
                        // 用户名和等级
                        VStack(spacing: AppSpacing.sm) {
                            HStack(spacing: AppSpacing.sm) {
                                Text(profile.user.name)
                                    .font(AppTypography.largeTitle)
                                    .fontWeight(.bold)
                                    .foregroundColor(AppColors.textPrimary)
                                
                                if profile.user.isVerified == 1 {
                                    ZStack {
                                        Circle()
                                            .fill(AppColors.success.opacity(0.2))
                                            .frame(width: 28, height: 28)
                                        
                                        Image(systemName: "checkmark.seal.fill")
                                            .foregroundColor(AppColors.success)
                                            .font(.system(size: 18, weight: .bold))
                                    }
                                    .shadow(color: AppColors.success.opacity(0.3), radius: 6, x: 0, y: 3)
                                }
                            }
                            
                            // 用户等级和评分
                            HStack(spacing: AppSpacing.md) {
                                if let userLevel = profile.user.userLevel {
                                    HStack(spacing: 4) {
                                        Image(systemName: "crown.fill")
                                            .font(.system(size: 12))
                                        Text(userLevel.uppercased())
                                            .font(AppTypography.caption)
                                            .fontWeight(.bold)
                                    }
                                    .foregroundColor(.white)
                                    .padding(.horizontal, AppSpacing.md)
                                    .padding(.vertical, 6)
                                    .background(
                                        LinearGradient(
                                            gradient: Gradient(colors: AppColors.gradientWarning),
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .cornerRadius(AppCornerRadius.medium)
                                    .shadow(color: AppColors.warning.opacity(0.4), radius: 6, x: 0, y: 3)
                                }
                                
                                if let avgRating = profile.user.avgRating, avgRating > 0 {
                                    HStack(spacing: 4) {
                                        Image(systemName: "star.fill")
                                            .foregroundColor(.yellow)
                                            .font(.system(size: 16))
                                        Text(String(format: "%.1f", avgRating))
                                            .font(AppTypography.subheadline)
                                            .fontWeight(.bold)
                                            .foregroundColor(AppColors.textPrimary)
                                    }
                                    .padding(.horizontal, AppSpacing.sm)
                                    .padding(.vertical, 6)
                                    .background(
                                        LinearGradient(
                                            gradient: Gradient(colors: [
                                                Color.yellow.opacity(0.2),
                                                Color.orange.opacity(0.1)
                                            ]),
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .cornerRadius(AppCornerRadius.medium)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: AppCornerRadius.medium)
                                            .stroke(Color.yellow.opacity(0.3), lineWidth: 1)
                                    )
                                }
                            }
                            
                            // 加入天数
                            if let daysSinceJoined = profile.user.daysSinceJoined, daysSinceJoined > 0 {
                                HStack(spacing: 4) {
                                    Image(systemName: "calendar")
                                        .font(.system(size: 11))
                                        .foregroundColor(AppColors.textSecondary)
                                    Text("加入 \(daysSinceJoined) 天")
                                        .font(AppTypography.caption)
                                        .foregroundColor(AppColors.textSecondary)
                                }
                                .padding(.top, 2)
                            }
                        }
                    }
                }
            }
            .padding(AppSpacing.xl)
        }
        .background(AppColors.cardBackground)
        .cornerRadius(AppCornerRadius.large)
        .shadow(color: AppShadow.medium.color, radius: AppShadow.medium.radius, x: AppShadow.medium.x, y: AppShadow.medium.y)
        .overlay(
            RoundedRectangle(cornerRadius: AppCornerRadius.large)
                .stroke(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            AppColors.primary.opacity(0.1),
                            Color.clear
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }
}

struct StatsRow: View {
    let profile: UserProfileResponse
    
    var body: some View {
        HStack(spacing: AppSpacing.md) {
            EnhancedStatItem(
                label: "发布任务",
                value: "\(profile.stats.postedTasks)",
                icon: "square.and.pencil",
                gradient: AppColors.gradientPrimary
            )
            
            EnhancedStatItem(
                label: "接取任务",
                value: "\(profile.stats.takenTasks)",
                icon: "hand.raised.fill",
                gradient: AppColors.gradientSuccess
            )
            
            EnhancedStatItem(
                label: "完成任务",
                value: "\(profile.stats.completedTasks)",
                icon: "checkmark.circle.fill",
                gradient: AppColors.gradientWarning
            )
        }
        .padding(AppSpacing.md)
        .background(AppColors.cardBackground)
        .cornerRadius(AppCornerRadius.large)
        .shadow(color: AppShadow.small.color, radius: AppShadow.small.radius, x: AppShadow.small.x, y: AppShadow.small.y)
    }
}

struct EnhancedStatItem: View {
    let label: String
    let value: String
    let icon: String
    let gradient: [Color]
    
    var body: some View {
        VStack(spacing: AppSpacing.xs) {
            // 图标背景
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: gradient),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 40, height: 40)
                
                Image(systemName: icon)
                    .foregroundColor(.white)
                    .font(.system(size: 16, weight: .semibold))
            }
            .shadow(color: gradient.first?.opacity(0.3) ?? Color.clear, radius: 4, x: 0, y: 2)
            
            Text(value)
                .font(AppTypography.title2)
                .fontWeight(.bold)
                .foregroundColor(gradient.first ?? AppColors.textPrimary)
            
            Text(label)
                .font(AppTypography.caption)
                .foregroundColor(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.sm)
    }
}

struct TaskRowView: View {
    let task: UserProfileTask
    
    var body: some View {
        HStack(spacing: AppSpacing.md) {
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text(task.title)
                    .font(AppTypography.body)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(2)
                
                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: "tag.fill")
                        .font(.system(size: 10))
                        .foregroundColor(AppColors.primary.opacity(0.7))
                    Text(task.taskType)
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textSecondary)
                    
                    Text("•")
                        .foregroundColor(AppColors.textTertiary)
                    
                    Image(systemName: "clock")
                        .font(.system(size: 10))
                        .foregroundColor(AppColors.textTertiary)
                    Text(DateFormatterHelper.shared.formatTime(task.createdAt))
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textSecondary)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text("£\(Int(task.reward))")
                    .font(AppTypography.title3)
                    .fontWeight(.bold)
                    .foregroundColor(AppColors.primary)
                Text("奖励")
                    .font(AppTypography.caption2)
                    .foregroundColor(AppColors.textTertiary)
            }
        }
        .padding(AppSpacing.md)
        .background(AppColors.cardBackground)
        .cornerRadius(AppCornerRadius.medium)
        .shadow(color: AppShadow.small.color, radius: AppShadow.small.radius, x: AppShadow.small.x, y: AppShadow.small.y)
    }
}

struct ReviewRowView: View {
    let review: UserProfileReview
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack {
                HStack(spacing: 4) {
                    ForEach(0..<5) { index in
                        Image(systemName: index < Int(review.rating) ? "star.fill" : "star")
                            .font(.system(size: 14))
                            .foregroundColor(index < Int(review.rating) ? .yellow : AppColors.textTertiary)
                    }
                    Text(String(format: "%.1f", review.rating))
                        .font(AppTypography.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.textSecondary)
                        .padding(.leading, 4)
                }
                
                Spacer()
                
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.system(size: 10))
                        .foregroundColor(AppColors.textTertiary)
                    Text(DateFormatterHelper.shared.formatTime(review.createdAt))
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textSecondary)
                }
            }
            
            if let comment = review.comment, !comment.isEmpty {
                Text(comment)
                    .font(AppTypography.body)
                    .foregroundColor(AppColors.textPrimary)
                    .lineSpacing(4)
                    .padding(.top, 2)
            }
        }
        .padding(AppSpacing.md)
        .background(AppColors.cardBackground)
        .cornerRadius(AppCornerRadius.medium)
        .shadow(color: AppShadow.small.color, radius: AppShadow.small.radius, x: AppShadow.small.x, y: AppShadow.small.y)
    }
}

#Preview {
    NavigationView {
        UserProfileView(userId: "12345678")
    }
}

