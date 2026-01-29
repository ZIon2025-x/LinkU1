import SwiftUI
import Combine

struct ForumView: View {
    @StateObject private var viewModel = ForumViewModel()
    @StateObject private var verificationViewModel = StudentVerificationViewModel()
    @EnvironmentObject var appState: AppState
    @State private var showLogin = false
    @State private var showVerification = false
    @State private var showCategoryRequest = false
    @State private var showMyCategoryRequests = false
    
    // 检查用户是否已登录且已通过学生认证
    private var isStudentVerified: Bool {
        guard appState.isAuthenticated else { return false }
        guard let verificationStatus = verificationViewModel.verificationStatus else { return false }
        return verificationStatus.isVerified
    }
    
    // 获取可见的板块（根据权限过滤，收藏的板块优先显示）
    private var visibleCategories: [ForumCategory] {
        let categories: [ForumCategory]
        if !appState.isAuthenticated {
            // 未登录：只显示 general 类型的板块
            categories = viewModel.categories.filter { $0.type == "general" || $0.type == nil }
        } else if !isStudentVerified {
            // 已登录但未认证：只显示 general 类型的板块
            categories = viewModel.categories.filter { $0.type == "general" || $0.type == nil }
        } else {
            // 已登录且已认证：显示所有板块（后端已经根据学校筛选了 university 类型）
            categories = viewModel.categories
        }
        
        // 优先显示收藏的板块
        let favorited = categories.filter { $0.isFavorited == true }
        let notFavorited = categories.filter { $0.isFavorited != true }
        return favorited + notFavorited
    }
    
    var body: some View {
        ZStack {
            AppColors.background
                .ignoresSafeArea()
            
            if viewModel.isLoading && viewModel.categories.isEmpty {
                // 使用骨架屏替代LoadingView，提供更好的加载体验
                ScrollView {
                    LazyVStack(spacing: DeviceInfo.isPad ? AppSpacing.lg : AppSpacing.md) {
                        ForEach(0..<5, id: \.self) { index in
                            ForumCategorySkeleton()
                                .listItemAppear(index: index, totalItems: 5)
                        }
                    }
                    .padding(.horizontal, DeviceInfo.isPad ? AppSpacing.xl : AppSpacing.md)
                    .padding(.vertical, DeviceInfo.isPad ? AppSpacing.md : AppSpacing.sm)
                    .frame(maxWidth: DeviceInfo.isPad ? 900 : .infinity) // iPad上限制最大宽度
                    .frame(maxWidth: .infinity, alignment: .center) // 确保在iPad上居中
                }
            } else if visibleCategories.isEmpty {
                if !appState.isAuthenticated {
                    // 未登录且没有可见板块
                    UnauthenticatedForumView(showLogin: $showLogin)
                } else if verificationViewModel.isLoading {
                    // 加载认证状态中
                    LoadingView()
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
                        title: LocalizationKey.forumNoCategories.localized,
                        message: LocalizationKey.forumCategoriesLoading.localized
                    )
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: DeviceInfo.isPad ? AppSpacing.lg : AppSpacing.md) {
                        // 显示可见的板块 - 添加错落入场动画
                        ForEach(Array(visibleCategories.enumerated()), id: \.element.id) { index, category in
                            NavigationLink(destination: ForumPostListView(category: category)) {
                                CategoryCard(category: category)
                                    .environmentObject(appState)
                            }
                            .buttonStyle(ScaleButtonStyle())
                            .listItemAppear(index: index, totalItems: visibleCategories.count)
                        }
                    }
                    .padding(.horizontal, DeviceInfo.isPad ? AppSpacing.xl : AppSpacing.md)
                    .padding(.vertical, DeviceInfo.isPad ? AppSpacing.md : AppSpacing.sm)
                    .frame(maxWidth: DeviceInfo.isPad ? 900 : .infinity) // iPad上限制最大宽度
                    .frame(maxWidth: .infinity, alignment: .center) // 确保在iPad上居中
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
        .task {
            // 优化：先从缓存加载，避免初次进入时显示空状态
            // 论坛板块肯定不是空的，应该先从缓存加载
            if viewModel.categories.isEmpty {
                // 尝试从缓存加载
                if let cachedCategories = CacheManager.shared.loadForumCategories() {
                    viewModel.categories = cachedCategories
                    Logger.success("从缓存加载了 \(cachedCategories.count) 个论坛板块", category: .cache)
                }
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
                // 优化：只在缓存也为空时才加载，避免不必要的网络请求
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
                // 未登录：如果板块为空（包括缓存也为空），加载 general 板块
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
        .sheet(isPresented: $showCategoryRequest) {
            ForumCategoryRequestView()
        }
        .sheet(isPresented: $showMyCategoryRequests) {
            MyCategoryRequestsView()
        }
        .onChange(of: showVerification) { isShowing in
            // 当认证页面关闭时，重新加载认证状态
            if !isShowing && appState.isAuthenticated {
                verificationViewModel.loadStatus()
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 12) {
                    // 查看我的申请按钮
                    if appState.isAuthenticated {
                        Button(action: {
                            showMyCategoryRequests = true
                        }) {
                            Image(systemName: "list.bullet.rectangle")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(AppColors.primary)
                        }
                    }
                    
                    // 申请新建板块按钮
                    Button(action: {
                        if !appState.isAuthenticated {
                            showLogin = true
                        } else {
                            showCategoryRequest = true
                        }
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(AppColors.primary)
                    }
                }
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
                Text(LocalizationKey.forumCompleteVerificationMessage.localized)
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

// 板块卡片 - 更现代的设计 + 丝滑交互
struct CategoryCard: View {
    let category: ForumCategory
    @State private var isAppeared = false
    @EnvironmentObject var appState: AppState
    @State private var isFavorited: Bool?
    @State private var isTogglingFavorite = false
    @State private var cancellables = Set<AnyCancellable>()
    private let apiService = APIService.shared
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            HStack(spacing: DeviceInfo.isPad ? AppSpacing.lg : AppSpacing.md) {
                // 图标容器 - 渐变背景 + 丝滑动画
                ZStack {
                RoundedRectangle(cornerRadius: AppCornerRadius.large, style: .continuous)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: AppColors.gradientPrimary),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 64, height: 64)
                    .shadow(color: AppColors.primary.opacity(0.2), radius: 8, x: 0, y: 4)
                    .scaleEffect(isAppeared ? 1.0 : 0.8)
                    .opacity(isAppeared ? 1.0 : 0.0)
                
                if let icon = category.icon, !icon.isEmpty {
                    // 检查是否是有效的 URL（以 http:// 或 https:// 开头）
                    if icon.hasPrefix("http://") || icon.hasPrefix("https://") {
                        // 性能优化：使用 AsyncImageView 替代系统 AsyncImage
                        AsyncImageView(
                            urlString: icon,
                            placeholder: Image(systemName: "folder.fill"),
                            width: 36,
                            height: 36,
                            contentMode: .fit
                        )
                    } else {
                        // 如果是 emoji 或其他文本，直接显示
                        // 使用更大的frame并确保居中，避免emoji被裁剪
                        Text(icon)
                            .font(.system(size: 36))
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .multilineTextAlignment(.center)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                    }
                } else {
                    Image(systemName: "folder.fill")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
            .frame(width: DeviceInfo.isPad ? 80 : 64, height: DeviceInfo.isPad ? 80 : 64)
            .clipShape(RoundedRectangle(cornerRadius: AppCornerRadius.large))
            
            // 信息区域
            VStack(alignment: .leading, spacing: DeviceInfo.isPad ? AppSpacing.md : AppSpacing.sm) {
                Text(category.displayName)
                    .font(AppTypography.body)
                    .fontWeight(.bold)
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                
                if let description = category.displayDescription {
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
                            Text(latestPost.displayTitle)
                                .font(AppTypography.caption)
                                .fontWeight(.medium)
                                .foregroundColor(AppColors.textPrimary)
                                .lineLimit(1)
                                .truncationMode(.tail)
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
            
            // 收藏图标提示（仅在已收藏时显示）
            if (isFavorited ?? category.isFavorited ?? false) {
                Image(systemName: "star.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.yellow)
                    .padding(6)
                    .background(
                        Circle()
                            .fill(Color.white.opacity(0.9))
                            .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
                    )
                    .padding(8)
            }
        }
        .padding(DeviceInfo.isPad ? AppSpacing.lg : AppSpacing.md)
        .cardStyle(cornerRadius: AppCornerRadius.large)
        .onAppear {
            // 图标入场动画
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7, blendDuration: 0).delay(0.05)) {
                isAppeared = true
            }
            // 初始化收藏状态
            isFavorited = category.isFavorited
        }
        .onChange(of: category.isFavorited) { newValue in
            isFavorited = newValue
        }
    }
    
    private func handleToggleFavorite() {
        guard !isTogglingFavorite else { return }
        isTogglingFavorite = true
        
        apiService.toggleCategoryFavorite(categoryId: category.id)
            .sink(receiveCompletion: { result in
                DispatchQueue.main.async {
                    isTogglingFavorite = false
                    if case .failure(let error) = result {
                        ErrorHandler.shared.handle(error, context: "收藏操作")
                    }
                }
            }, receiveValue: { response in
                DispatchQueue.main.async {
                    isFavorited = response.favorited
                }
            })
            .store(in: &cancellables)
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

// MARK: - 申请新建板块视图

struct ForumCategoryRequestView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appState: AppState
    private let apiService = APIService.shared
    
    @State private var categoryName = ""
    @State private var categoryDescription = ""
    @State private var categoryIcon = ""
    @State private var isLoading = false
    @State private var showSuccessAlert = false
    @State private var errorMessage: String?
    @State private var hasSubmitted = false // 防重复提交
    @FocusState private var focusedField: Field?
    
    // 字符限制
    private let maxNameLength = 100
    private let maxDescriptionLength = 500
    private let maxIconLength = 1 // emoji 只能输入一个
    
    enum Field: Hashable {
        case name, description, icon
    }
    
    // 计算属性：字符计数
    private var nameCharacterCount: Int {
        categoryName.count
    }
    
    private var descriptionCharacterCount: Int {
        categoryDescription.count
    }
    
    private var iconCharacterCount: Int {
        categoryIcon.count
    }
    
    // 验证状态
    private var isNameValid: Bool {
        !categoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private var isDescriptionValid: Bool {
        descriptionCharacterCount <= maxDescriptionLength
    }
    
    private var isIconValid: Bool {
        iconCharacterCount <= maxIconLength
    }
    
    private var canSubmit: Bool {
        isNameValid && isDescriptionValid && isIconValid && !isLoading && !hasSubmitted
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.background
                    .ignoresSafeArea()
                
                KeyboardAvoidingScrollView(extraPadding: 20) {
                    VStack(spacing: AppSpacing.lg) {
                        // 说明文字
                        VStack(alignment: .leading, spacing: AppSpacing.sm) {
                            HStack(spacing: 8) {
                                Image(systemName: "info.circle.fill")
                                    .foregroundColor(AppColors.primary)
                                Text(LocalizationKey.forumRequestInstructions.localized)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(AppColors.textPrimary)
                            }
                            
                            Text(LocalizationKey.forumRequestInstructionsText.localized)
                                .font(.system(size: 14))
                                .foregroundColor(AppColors.textSecondary)
                                .lineSpacing(4)
                        }
                        .padding(AppSpacing.md)
                        .background(AppColors.primary.opacity(0.05))
                        .cornerRadius(AppCornerRadius.medium)
                        .padding(.horizontal, AppSpacing.md)
                        .padding(.top, AppSpacing.md)
                        
                        // 表单
                        VStack(spacing: AppSpacing.md) {
                            // 板块名称
                            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                                HStack {
                                    Text(LocalizationKey.forumCategoryName.localized)
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundColor(AppColors.textPrimary)
                                    Text("*")
                                        .foregroundColor(AppColors.error)
                                }
                                
                                TextField(LocalizationKey.forumCategoryNamePlaceholder.localized, text: $categoryName)
                                    .font(.system(size: 15))
                                    .padding(AppSpacing.md)
                                    .background(AppColors.cardBackground)
                                    .cornerRadius(AppCornerRadius.medium)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: AppCornerRadius.medium)
                                            .stroke(
                                                focusedField == .name 
                                                    ? AppColors.primary 
                                                    : (isNameValid ? AppColors.separator : AppColors.error),
                                                lineWidth: focusedField == .name ? 1.5 : 1
                                            )
                                    )
                                    .focused($focusedField, equals: .name)
                                    .onChange(of: categoryName) { newValue in
                                        // 限制字符长度
                                        if newValue.count > maxNameLength {
                                            categoryName = String(newValue.prefix(maxNameLength))
                                        }
                                    }
                                
                                // 字符计数
                                HStack {
                                    Spacer()
                                    Text("\(nameCharacterCount)/\(maxNameLength)")
                                        .font(.system(size: 12))
                                        .foregroundColor(
                                            nameCharacterCount > maxNameLength 
                                                ? AppColors.error 
                                                : AppColors.textSecondary
                                        )
                                }
                            }
                            
                            // 板块描述
                            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                                Text(LocalizationKey.forumCategoryDescription.localized)
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(AppColors.textPrimary)
                                
                                ZStack(alignment: .topLeading) {
                                    TextEditor(text: $categoryDescription)
                                        .font(.system(size: 15))
                                        .frame(minHeight: 100)
                                        .padding(AppSpacing.sm)
                                        .scrollContentBackground(.hidden)
                                        .background(AppColors.cardBackground)
                                        .cornerRadius(AppCornerRadius.medium)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: AppCornerRadius.medium)
                                                .stroke(
                                                    focusedField == .description 
                                                        ? AppColors.primary 
                                                        : (isDescriptionValid ? AppColors.separator : AppColors.error),
                                                    lineWidth: focusedField == .description ? 1.5 : 1
                                                )
                                        )
                                        .focused($focusedField, equals: .description)
                                        .onChange(of: categoryDescription) { newValue in
                                            // 限制字符长度
                                            if newValue.count > maxDescriptionLength {
                                                categoryDescription = String(newValue.prefix(maxDescriptionLength))
                                            }
                                        }
                                    
                                    if categoryDescription.isEmpty {
                                        Text(LocalizationKey.forumCategoryDescriptionPlaceholder.localized)
                                            .font(.system(size: 15))
                                            .foregroundColor(AppColors.textTertiary)
                                            .padding(.top, AppSpacing.sm + 4)
                                            .padding(.leading, AppSpacing.sm + 4)
                                            .allowsHitTesting(false)
                                    }
                                }
                                
                                // 字符计数
                                HStack {
                                    Spacer()
                                    Text("\(descriptionCharacterCount)/\(maxDescriptionLength)")
                                        .font(.system(size: 12))
                                        .foregroundColor(
                                            descriptionCharacterCount > maxDescriptionLength 
                                                ? AppColors.error 
                                                : AppColors.textSecondary
                                        )
                                }
                            }
                            
                            // 板块图标（可选）
                            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                                Text(LocalizationKey.forumCategoryIcon.localized)
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(AppColors.textPrimary)
                                
                                Text(LocalizationKey.forumCategoryIconHint.localized)
                                    .font(.system(size: 12))
                                    .foregroundColor(AppColors.textSecondary)
                                
                                TextField(LocalizationKey.forumCategoryIconExample.localized, text: $categoryIcon)
                                    .font(.system(size: 24))
                                    .multilineTextAlignment(.center)
                                    .padding(AppSpacing.md)
                                    .background(AppColors.cardBackground)
                                    .cornerRadius(AppCornerRadius.medium)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: AppCornerRadius.medium)
                                            .stroke(
                                                focusedField == .icon 
                                                    ? AppColors.primary 
                                                    : (isIconValid ? AppColors.separator : AppColors.error),
                                                lineWidth: focusedField == .icon ? 1.5 : 1
                                            )
                                    )
                                    .focused($focusedField, equals: .icon)
                                    .onChange(of: categoryIcon) { newValue in
                                        // 限制只能输入一个 emoji（取第一个字符）
                                        if newValue.count > 1 {
                                            // 取第一个字符（支持复合 emoji，如带肤色的 emoji）
                                            categoryIcon = String(newValue.prefix(1))
                                        }
                                    }
                                
                                // 提示信息（仅当有输入时显示）
                                if !categoryIcon.isEmpty {
                                    HStack {
                                        Spacer()
                                        Text(LocalizationKey.forumCategoryIconEntered.localized)
                                            .font(.system(size: 12))
                                            .foregroundColor(AppColors.textSecondary)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, AppSpacing.md)
                        
                        // 提交按钮
                        Button(action: {
                            submitRequest()
                        }) {
                            HStack {
                                if isLoading {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Text(LocalizationKey.forumSubmitRequest.localized)
                                        .font(.system(size: 16, weight: .semibold))
                                }
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(
                                canSubmit
                                    ? AppColors.primary
                                    : AppColors.textTertiary
                            )
                            .cornerRadius(AppCornerRadius.medium)
                        }
                        .disabled(!canSubmit)
                        .padding(.horizontal, AppSpacing.md)
                        .padding(.top, AppSpacing.sm)
                        
                        // 错误提示
                        if let errorMessage = errorMessage {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(AppColors.error)
                                Text(errorMessage)
                                    .font(.system(size: 14))
                                    .foregroundColor(AppColors.error)
                            }
                            .padding(AppSpacing.md)
                            .background(AppColors.error.opacity(0.1))
                            .cornerRadius(AppCornerRadius.medium)
                            .padding(.horizontal, AppSpacing.md)
                        }
                    }
                }
                .scrollDismissesKeyboard(.interactively)
                .contentShape(Rectangle())
                .onTapGesture {
                    focusedField = nil
                }
            }
            .navigationTitle(LocalizationKey.forumRequestNewCategory.localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(LocalizationKey.commonCancel.localized) {
                        dismiss()
                    }
                }
                // 键盘上方的完成按钮
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button(LocalizationKey.commonDone.localized) {
                        focusedField = nil
                    }
                }
            }
            .alert(LocalizationKey.forumRequestSubmitted.localized, isPresented: $showSuccessAlert) {
                Button(LocalizationKey.commonOk.localized) {
                    dismiss()
                }
            } message: {
                Text(LocalizationKey.forumRequestSubmittedMessage.localized)
            }
        }
    }
    
    private func submitRequest() {
        // 防重复提交检查
        guard !hasSubmitted && !isLoading else { return }
        
        // 验证输入
        let trimmedName = categoryName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            errorMessage = LocalizationKey.forumRequestNameRequired.localized
            return
        }
        
        guard trimmedName.count <= maxNameLength else {
            errorMessage = LocalizationKey.forumRequestNameTooLong.localized(argument: maxNameLength)
            return
        }
        
        guard categoryDescription.count <= maxDescriptionLength else {
            errorMessage = LocalizationKey.forumRequestDescriptionTooLong.localized(argument: maxDescriptionLength)
            return
        }
        
        guard categoryIcon.count <= maxIconLength else {
            errorMessage = LocalizationKey.forumRequestIconTooLong.localized(argument: maxIconLength)
            return
        }
        
        isLoading = true
        hasSubmitted = true
        errorMessage = nil
        
        // 构建申请数据（移除nil值，并去除首尾空格）
        var requestData: [String: Any] = [
            "name": trimmedName,
            "type": "general" // 默认申请普通板块
        ]
        
        let trimmedDescription = categoryDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedDescription.isEmpty {
            requestData["description"] = trimmedDescription
        }
        
        let trimmedIcon = categoryIcon.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedIcon.isEmpty {
            requestData["icon"] = trimmedIcon
        }
        
        // 调用API提交申请
        apiService.request(
            ForumCategoryRequestResponse.self,
            "/api/forum/categories/request",
            method: "POST",
            body: requestData
        )
        .receive(on: DispatchQueue.main)
        .sink(
            receiveCompletion: { completion in
                isLoading = false
                if case .failure(let error) = completion {
                    hasSubmitted = false // 失败后允许重新提交
                    // 解析错误信息，提供更友好的提示
                    switch error {
                    case .httpError(let code):
                        if code == 400 {
                            errorMessage = LocalizationKey.forumRequestSubmitFailed.localized
                        } else if code == 401 {
                            errorMessage = LocalizationKey.forumRequestLoginExpired.localized
                        } else {
                            errorMessage = error.userFriendlyMessage
                        }
                    default:
                        errorMessage = error.userFriendlyMessage
                    }
                }
            },
            receiveValue: { response in
                isLoading = false
                showSuccessAlert = true
                // 清空表单
                categoryName = ""
                categoryDescription = ""
                categoryIcon = ""
                hasSubmitted = false // 成功后重置，允许再次提交
            }
        )
        .store(in: &cancellables)
    }
    
    @State private var cancellables = Set<AnyCancellable>()
}


// MARK: - 我的板块申请视图

struct MyCategoryRequestsView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appState: AppState
    private let apiService = APIService.shared
    
    @State private var requests: [ForumCategoryRequestDetail] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedStatus: String? = nil
    
    @State private var cancellables = Set<AnyCancellable>()
    
    var filteredRequests: [ForumCategoryRequestDetail] {
        if let status = selectedStatus {
            return requests.filter { $0.status == status }
        }
        return requests
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.background
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // 状态筛选器
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: AppSpacing.sm) {
                            StatusFilterButton(title: LocalizationKey.forumRequestStatusAll.localized, status: nil, selectedStatus: $selectedStatus)
                            StatusFilterButton(title: LocalizationKey.forumRequestStatusPending.localized, status: "pending", selectedStatus: $selectedStatus)
                            StatusFilterButton(title: LocalizationKey.forumRequestStatusApproved.localized, status: "approved", selectedStatus: $selectedStatus)
                            StatusFilterButton(title: LocalizationKey.forumRequestStatusRejected.localized, status: "rejected", selectedStatus: $selectedStatus)
                        }
                        .padding(.horizontal, AppSpacing.md)
                        .padding(.vertical, AppSpacing.sm)
                    }
                    .background(AppColors.cardBackground)
                    .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 2)
                    
                    if isLoading && requests.isEmpty {
                        ProgressView()
                            .padding()
                    } else if let errorMessage = errorMessage {
                        VStack(spacing: AppSpacing.md) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 48))
                                .foregroundColor(AppColors.error)
                            Text(errorMessage)
                                .font(.system(size: 16))
                                .foregroundColor(AppColors.textSecondary)
                                .multilineTextAlignment(.center)
                            Button("重试") {
                                loadRequests()
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .padding()
                    } else if filteredRequests.isEmpty {
                        EmptyStateView(
                            icon: "tray.fill",
                            title: LocalizationKey.forumNoRequests.localized,
                            message: selectedStatus == nil ? LocalizationKey.forumNoRequestsMessage.localized : LocalizationKey.forumNoRequestsFiltered.localized
                        )
                    } else {
                        List {
                            ForEach(filteredRequests) { request in
                                CategoryRequestCard(request: request)
                                    .listRowBackground(AppColors.cardBackground)
                                    .listRowSeparator(.hidden)
                                    .padding(.vertical, AppSpacing.xs)
                            }
                        }
                        .listStyle(.plain)
                        .refreshable {
                            loadRequests()
                        }
                    }
                }
            }
            .navigationTitle(LocalizationKey.forumMyRequests.localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(LocalizationKey.commonClose.localized) {
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadRequests()
            }
        }
    }
    
    private func loadRequests() {
        isLoading = true
        errorMessage = nil
        
        apiService.getMyCategoryRequests()
            .receive(on: DispatchQueue.main)
            .sink { completion in
                isLoading = false
                if case .failure(let error) = completion {
                    errorMessage = error.userFriendlyMessage
                }
            } receiveValue: { requests in
                self.requests = requests
            }
            .store(in: &cancellables)
    }
}

struct StatusFilterButton: View {
    let title: String
    let status: String?
    @Binding var selectedStatus: String?
    
    var isSelected: Bool {
        selectedStatus == status
    }
    
    var body: some View {
        Button(action: {
            selectedStatus = status
        }) {
            Text(title)
                .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
                .foregroundColor(isSelected ? .white : AppColors.textPrimary)
                .padding(.horizontal, AppSpacing.md)
                .padding(.vertical, AppSpacing.sm)
                .background(
                    Capsule()
                        .fill(isSelected ? AppColors.primary : AppColors.background)
                )
        }
    }
}

struct CategoryRequestCard: View {
    let request: ForumCategoryRequestDetail
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack {
                // Icon
                if let icon = request.icon, !icon.isEmpty {
                    Text(icon)
                        .font(.system(size: 28))
                        .frame(width: 48, height: 48)
                        .background(AppColors.primary.opacity(0.1))
                        .cornerRadius(AppCornerRadius.medium)
                } else {
                    Image(systemName: "text.bubble.fill")
                        .font(.system(size: 24))
                        .foregroundColor(AppColors.textSecondary)
                        .frame(width: 48, height: 48)
                        .background(AppColors.separator.opacity(0.2))
                        .cornerRadius(AppCornerRadius.medium)
                }
                
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text(request.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(AppColors.textPrimary)
                    
                    if let description = request.description, !description.isEmpty {
                        Text(description)
                            .font(.system(size: 13))
                            .foregroundColor(AppColors.textSecondary)
                            .lineLimit(2)
                    }
                }
                
                Spacer()
                
                Text(request.statusText)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(request.statusColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(request.statusColor.opacity(0.1))
                    .cornerRadius(AppCornerRadius.small)
            }
            
            if request.status != "pending" {
                if let reviewComment = request.reviewComment, !reviewComment.isEmpty {
                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        Text(LocalizationKey.forumReviewComment.localized)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(AppColors.textSecondary)
                        Text(reviewComment)
                            .font(.system(size: 13))
                            .foregroundColor(AppColors.textPrimary)
                            .padding(AppSpacing.sm)
                            .background(AppColors.background)
                            .cornerRadius(AppCornerRadius.small)
                    }
                }
                
                if let reviewedAt = request.reviewedAt {
                    HStack {
                        Text("\(LocalizationKey.forumReviewTime.localized): \(reviewedAt.formatDate())")
                            .font(.system(size: 12))
                            .foregroundColor(AppColors.textTertiary)
                        Spacer()
                    }
                }
            } else {
                HStack {
                    Text("\(LocalizationKey.forumRequestTime.localized): \(request.createdAt.formatDate())")
                        .font(.system(size: 12))
                        .foregroundColor(AppColors.textTertiary)
                    Spacer()
                }
            }
        }
        .padding(AppSpacing.md)
        .background(AppColors.cardBackground)
        .cornerRadius(AppCornerRadius.medium)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}
