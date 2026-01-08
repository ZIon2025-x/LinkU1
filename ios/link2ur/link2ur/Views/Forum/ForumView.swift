import SwiftUI

struct ForumView: View {
    @StateObject private var viewModel = ForumViewModel()
    @StateObject private var verificationViewModel = StudentVerificationViewModel()
    @EnvironmentObject var appState: AppState
    @State private var showLogin = false
    @State private var showVerification = false
    
    // 检查用户是否已登录且已通过学生认证
    private var isStudentVerified: Bool {
        guard appState.isAuthenticated else { return false }
        guard let verificationStatus = verificationViewModel.verificationStatus else { return false }
        return verificationStatus.isVerified
    }
    
    // 获取可见的板块（根据权限过滤）
    private var visibleCategories: [ForumCategory] {
        if !appState.isAuthenticated {
            // 未登录：只显示 general 类型的板块
            return viewModel.categories.filter { $0.type == "general" || $0.type == nil }
        } else if !isStudentVerified {
            // 已登录但未认证：只显示 general 类型的板块
            return viewModel.categories.filter { $0.type == "general" || $0.type == nil }
        } else {
            // 已登录且已认证：显示所有板块（后端已经根据学校筛选了 university 类型）
            return viewModel.categories
        }
    }
    
    var body: some View {
        ZStack {
            AppColors.background
                .ignoresSafeArea()
            
            if viewModel.isLoading && viewModel.categories.isEmpty {
                ProgressView()
            } else if visibleCategories.isEmpty {
                if !appState.isAuthenticated {
                    // 未登录且没有可见板块
                    UnauthenticatedForumView(showLogin: $showLogin)
                } else if verificationViewModel.isLoading {
                    // 加载认证状态中
                    ProgressView()
                } else if !isStudentVerified {
                    // 已登录但未认证，且没有 general 板块
                    UnverifiedForumView(
                        verificationStatus: verificationViewModel.verificationStatus,
                        showVerification: $showVerification
                    )
                } else {
                    // 已认证但没有板块
                    EmptyStateView(
                        icon: "bubble.left.and.bubble.right.fill",
                        title: "暂无板块",
                        message: "论坛板块加载中..."
                    )
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: AppSpacing.md) {
                        // 显示可见的板块
                        ForEach(visibleCategories) { category in
                            NavigationLink(destination: ForumPostListView(category: category)) {
                                CategoryCard(category: category)
                            }
                            .buttonStyle(ScaleButtonStyle())
                        }
                    }
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.vertical, AppSpacing.sm)
                }
            }
        }
        .refreshable {
            // 未登录用户也可以刷新，加载 general 类型的板块
            if appState.isAuthenticated {
                if isStudentVerified {
                    // 已认证用户：加载所有板块（包括学校板块）
                    let universityId = verificationViewModel.verificationStatus?.university?.id
                    viewModel.loadCategories(universityId: universityId)
                } else {
                    // 已登录但未认证：只加载 general 板块
                    viewModel.loadCategories(universityId: nil)
                    verificationViewModel.loadStatus()
                }
            } else {
                // 未登录：加载 general 板块（后端应该返回所有 general 板块）
                viewModel.loadCategories(universityId: nil)
            }
        }
        .onAppear {
            // 未登录用户也可以加载 general 类型的板块
            if appState.isAuthenticated {
                // 如果认证状态还未加载，则加载
                if verificationViewModel.verificationStatus == nil && !verificationViewModel.isLoading {
                    verificationViewModel.loadStatus()
                }
                // 如果已认证且板块为空，加载所有板块；否则只加载 general 板块
                if let verificationStatus = verificationViewModel.verificationStatus,
                   verificationStatus.isVerified {
                    if viewModel.categories.isEmpty && !viewModel.isLoading {
                        let universityId = verificationStatus.university?.id
                        viewModel.loadCategories(universityId: universityId)
                    }
                } else if viewModel.categories.isEmpty && !viewModel.isLoading {
                    viewModel.loadCategories(universityId: nil)
                }
            } else {
                // 未登录：如果板块为空，加载 general 板块
                if viewModel.categories.isEmpty && !viewModel.isLoading {
                    viewModel.loadCategories(universityId: nil)
                }
            }
        }
        .onChange(of: verificationViewModel.verificationStatus?.isVerified) { isVerified in
            // 当认证状态变为已认证时，重新加载板块（包括学校板块）
            if isVerified == true && !viewModel.isLoading {
                let universityId = verificationViewModel.verificationStatus?.university?.id
                viewModel.loadCategories(universityId: universityId)
            }
        }
        .sheet(isPresented: $showLogin) {
            LoginView()
        }
        .sheet(isPresented: $showVerification) {
            StudentVerificationView()
        }
        .onChange(of: showVerification) { isShowing in
            // 当认证页面关闭时，重新加载认证状态
            if !isShowing && appState.isAuthenticated {
                verificationViewModel.loadStatus()
            }
        }
    }
}

// MARK: - 未登录提示视图
struct UnauthenticatedForumView: View {
    @Binding var showLogin: Bool
    
    var body: some View {
        VStack(spacing: AppSpacing.lg) {
            Image(systemName: "lock.fill")
                .font(.system(size: 64))
                .foregroundColor(AppColors.textSecondary)
            
            Text(LocalizationKey.forumNeedLogin.localized)
                .font(AppTypography.title2)
                .fontWeight(.bold)
                .foregroundColor(AppColors.textPrimary)
            
            Text(LocalizationKey.forumCommunityLoginMessage.localized)
                .font(AppTypography.body)
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppSpacing.xl)
            
            Button(action: {
                showLogin = true
            }) {
                Text(LocalizationKey.forumLoginNow.localized)
                    .font(AppTypography.bodyBold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(AppColors.primary)
                    .clipShape(RoundedRectangle(cornerRadius: AppCornerRadius.medium, style: .continuous))
            }
            .padding(.horizontal, AppSpacing.xl)
        }
        .padding(.top, AppSpacing.xxl)
    }
}

// MARK: - 未认证提示视图
struct UnverifiedForumView: View {
    let verificationStatus: StudentVerificationStatusData?
    @Binding var showVerification: Bool
    
    var body: some View {
        VStack(spacing: AppSpacing.lg) {
            Image(systemName: "studentdesk")
                .font(.system(size: 64))
                .foregroundColor(AppColors.warning)
            
            Text(LocalizationKey.forumNeedStudentVerification.localized)
                .font(AppTypography.title2)
                .fontWeight(.bold)
                .foregroundColor(AppColors.textPrimary)
            
            if let status = verificationStatus {
                if status.status == "pending" {
                    Text(LocalizationKey.forumVerificationPending.localized)
                        .font(AppTypography.body)
                        .foregroundColor(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, AppSpacing.xl)
                } else if status.status == "rejected" {
                    Text(LocalizationKey.forumVerificationRejected.localized)
                        .font(AppTypography.body)
                        .foregroundColor(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, AppSpacing.xl)
                } else {
                    Text(LocalizationKey.forumCompleteVerification.localized)
                        .font(AppTypography.body)
                        .foregroundColor(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, AppSpacing.xl)
                }
            } else {
                Text("请完成学生认证以访问社区功能")
                    .font(AppTypography.body)
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacing.xl)
            }
            
            Button(action: {
                showVerification = true
            }) {
                Text(LocalizationKey.forumGoVerify.localized)
                    .font(AppTypography.bodyBold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(AppColors.primary)
                    .clipShape(RoundedRectangle(cornerRadius: AppCornerRadius.medium, style: .continuous))
            }
            .padding(.horizontal, AppSpacing.xl)
        }
        .padding(.top, AppSpacing.xxl)
    }
}

// 板块卡片 - 更现代的设计
struct CategoryCard: View {
    let category: ForumCategory
    
    var body: some View {
        HStack(spacing: AppSpacing.md) {
            // 图标容器 - 渐变背景
            ZStack {
                RoundedRectangle(cornerRadius: AppCornerRadius.large)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: AppColors.gradientPrimary),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 64, height: 64)
                    .shadow(color: AppColors.primary.opacity(0.2), radius: 8, x: 0, y: 4)
                
                if let icon = category.icon, !icon.isEmpty {
                    // 检查是否是有效的 URL（以 http:// 或 https:// 开头）
                    if icon.hasPrefix("http://") || icon.hasPrefix("https://") {
                        AsyncImage(url: icon.toImageURL()) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                        } placeholder: {
                            Image(systemName: "folder.fill")
                                .font(.system(size: 28, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        .frame(width: 32, height: 32)
                    } else {
                        // 如果是 emoji 或其他文本，直接显示
                        Text(icon)
                            .font(.system(size: 32))
                            .frame(width: 32, height: 32)
                    }
                } else {
                    Image(systemName: "folder.fill")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
            
            // 信息区域
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Text(category.name)
                    .font(AppTypography.body)
                    .fontWeight(.bold)
                    .foregroundColor(AppColors.textPrimary)
                
                if let description = category.description {
                    Text(description)
                        .font(AppTypography.subheadline)
                        .foregroundColor(AppColors.textSecondary)
                        .lineLimit(2)
                }
                
                // 显示最热门帖子预览
                if let latestPost = category.latestPost {
                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        // 帖子标题
                        HStack(spacing: AppSpacing.xs) {
                            Image(systemName: "message.fill")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(AppColors.primary)
                            Text(latestPost.title)
                                .font(AppTypography.caption)
                                .fontWeight(.medium)
                                .foregroundColor(AppColors.textPrimary)
                                .lineLimit(1)
                        }
                        
                        // 帖子元信息：发布人、回复数、浏览量、时间
                        HStack(spacing: AppSpacing.sm) {
                            if let author = latestPost.author {
                                HStack(spacing: 4) {
                                    Image(systemName: "person.fill")
                                        .font(.system(size: 9, weight: .medium))
                                    Text(author.name)
                                        .font(AppTypography.caption2)
                                }
                                .foregroundColor(AppColors.textSecondary)
                            }
                            
                            HStack(spacing: 4) {
                                Image(systemName: "bubble.right.fill")
                                    .font(.system(size: 9, weight: .medium))
                                Text(latestPost.replyCount.formatCount())
                                    .font(AppTypography.caption2)
                            }
                            .foregroundColor(AppColors.textTertiary)
                            
                            HStack(spacing: 4) {
                                Image(systemName: "eye.fill")
                                    .font(.system(size: 9, weight: .medium))
                                Text(latestPost.viewCount.formatCount())
                                    .font(AppTypography.caption2)
                            }
                            .foregroundColor(AppColors.textTertiary)
                            
                            if let lastReplyAt = latestPost.lastReplyAt {
                                HStack(spacing: 4) {
                                    Image(systemName: "clock.fill")
                                        .font(.system(size: 9, weight: .medium))
                                    Text(formatForumTime(lastReplyAt))
                                        .font(AppTypography.caption2)
                                }
                                .foregroundColor(AppColors.textTertiary)
                            }
                        }
                    }
                    .padding(.top, AppSpacing.xs)
                } else if category.postCount == 0 || category.postCount == nil {
                    // 如果没有帖子，显示提示
                    Text(LocalizationKey.forumNoPosts.localized)
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textTertiary)
                        .padding(.top, AppSpacing.xs)
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(AppColors.textTertiary)
        }
        .padding(AppSpacing.md)
        .cardStyle(cornerRadius: AppCornerRadius.large)
    }
    
    /// 格式化论坛时间显示为 "01/Jan" 格式
    private func formatForumTime(_ timeString: String) -> String {
        // 使用 DateFormatterHelper 解析日期
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        isoFormatter.timeZone = TimeZone(identifier: "UTC") ?? TimeZone(secondsFromGMT: 0)!
        
        guard let date = isoFormatter.date(from: timeString) else {
            // 尝试不带小数秒的格式
            let standardIsoFormatter = ISO8601DateFormatter()
            standardIsoFormatter.formatOptions = [.withInternetDateTime]
            standardIsoFormatter.timeZone = TimeZone(identifier: "UTC") ?? TimeZone(secondsFromGMT: 0)!
            guard let date = standardIsoFormatter.date(from: timeString) else {
                return ""
            }
            return formatDate(date)
        }
        
        return formatDate(date)
    }
    
    /// 格式化日期为 "01/Jan" 格式
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current // 使用用户系统 locale
        formatter.timeZone = TimeZone.current // 使用用户本地时区
        formatter.dateFormat = "dd/MMM" // 格式：01/Jan
        
        return formatter.string(from: date)
    }
}

