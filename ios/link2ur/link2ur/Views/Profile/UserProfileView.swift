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
                                Text("最近任务")
                                    .font(AppTypography.title3)
                                    .foregroundColor(AppColors.textPrimary)
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
                                Text("用户评价")
                                    .font(AppTypography.title3)
                                    .foregroundColor(AppColors.textPrimary)
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
                        if let apiError = error as? APIError {
                            self?.errorMessage = apiError.userFriendlyMessage
                        } else {
                            self?.errorMessage = error.localizedDescription
                        }
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
        VStack(spacing: AppSpacing.lg) {
            // 头像
            AvatarView(
                urlString: profile.user.avatar,
                size: 100,
                placeholder: Image(systemName: "person.fill")
            )
            .overlay(
                Circle()
                    .stroke(AppColors.primary.opacity(0.3), lineWidth: 3)
            )
            
            // 用户名和等级
            VStack(spacing: AppSpacing.sm) {
                HStack(spacing: AppSpacing.sm) {
                    Text(profile.user.name)
                        .font(AppTypography.title2)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.textPrimary)
                    
                    if profile.user.isVerified == 1 {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(AppColors.success)
                    }
                }
                
                if let userLevel = profile.user.userLevel {
                    Text(userLevel.uppercased())
                        .font(AppTypography.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, AppSpacing.md)
                        .padding(.vertical, 4)
                        .background(AppColors.warning)
                        .cornerRadius(AppCornerRadius.small)
                }
                
                if let avgRating = profile.user.avgRating, avgRating > 0 {
                    HStack(spacing: AppSpacing.xs) {
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                            .font(.system(size: 14))
                        Text(String(format: "%.1f", avgRating))
                            .font(AppTypography.subheadline)
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(AppSpacing.xl)
        .cardStyle(cornerRadius: AppCornerRadius.large)
    }
}

struct StatsRow: View {
    let profile: UserProfileResponse
    
    var body: some View {
        HStack(spacing: AppSpacing.md) {
            StatItem(
                label: "发布任务",
                value: "\(profile.stats.postedTasks)",
                color: AppColors.primary
            )
            
            StatItem(
                label: "接取任务",
                value: "\(profile.stats.takenTasks)",
                color: AppColors.success
            )
            
            StatItem(
                label: "完成任务",
                value: "\(profile.stats.completedTasks)",
                color: AppColors.warning
            )
        }
        .cardStyle()
    }
}

struct TaskRowView: View {
    let task: UserProfileTask
    
    var body: some View {
        HStack(spacing: AppSpacing.md) {
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text(task.title)
                    .font(AppTypography.body)
                    .fontWeight(.medium)
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(2)
                
                HStack(spacing: AppSpacing.sm) {
                    Text(task.taskType)
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textSecondary)
                    
                    Text("•")
                        .foregroundColor(AppColors.textTertiary)
                    
                    Text(DateFormatterHelper.shared.formatTime(task.createdAt))
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textSecondary)
                }
            }
            
            Spacer()
            
            Text("£\(Int(task.reward))")
                .font(AppTypography.body)
                .fontWeight(.semibold)
                .foregroundColor(AppColors.primary)
        }
        .padding(AppSpacing.md)
        .cardStyle()
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
                            .font(.system(size: 12))
                            .foregroundColor(index < Int(review.rating) ? .yellow : AppColors.textTertiary)
                    }
                }
                
                Spacer()
                
                Text(DateFormatterHelper.shared.formatTime(review.createdAt))
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textSecondary)
            }
            
            if let comment = review.comment, !comment.isEmpty {
                Text(comment)
                    .font(AppTypography.body)
                    .foregroundColor(AppColors.textPrimary)
                    .lineSpacing(2)
            }
        }
        .padding(AppSpacing.md)
        .cardStyle()
    }
}

#Preview {
    NavigationView {
        UserProfileView(userId: "12345678")
    }
}

