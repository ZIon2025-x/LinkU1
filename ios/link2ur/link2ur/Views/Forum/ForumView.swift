import SwiftUI
import Combine

struct ForumView: View {
    @StateObject private var viewModel = ForumViewModel()
    @StateObject private var verificationViewModel = StudentVerificationViewModel()
    @EnvironmentObject var appState: AppState
    @State private var showLogin = false
    @State private var showVerification = false
    @State private var showCategoryRequest = false
    
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
        .sheet(isPresented: $showCategoryRequest) {
            ForumCategoryRequestView()
        }
        .onChange(of: showVerification) { isShowing in
            // 当认证页面关闭时，重新加载认证状态
            if !isShowing && appState.isAuthenticated {
                verificationViewModel.loadStatus()
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
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
                                .font(.system(size: 24, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        .frame(width: 36, height: 36)
                        .clipped()
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
            .frame(width: 64, height: 64)
            .clipShape(RoundedRectangle(cornerRadius: AppCornerRadius.large))
            
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

// MARK: - 申请新建板块视图

struct ForumCategoryRequestView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appState: AppState
    @StateObject private var apiService = APIService.shared
    
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
    private let maxIconLength = 200
    
    enum Field {
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
                
                ScrollView {
                    VStack(spacing: AppSpacing.lg) {
                        // 说明文字
                        VStack(alignment: .leading, spacing: AppSpacing.sm) {
                            HStack(spacing: 8) {
                                Image(systemName: "info.circle.fill")
                                    .foregroundColor(AppColors.primary)
                                Text("申请说明")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(AppColors.textPrimary)
                            }
                            
                            Text("填写以下信息申请新建论坛板块。您的申请将由管理员审核，审核通过后板块将正式创建。")
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
                                    Text("板块名称")
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundColor(AppColors.textPrimary)
                                    Text("*")
                                        .foregroundColor(AppColors.error)
                                }
                                
                                TextField("请输入板块名称", text: $categoryName)
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
                                Text("板块描述")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(AppColors.textPrimary)
                                
                                ZStack(alignment: .topLeading) {
                                    TextEditor(text: $categoryDescription)
                                        .font(.system(size: 15))
                                        .frame(minHeight: 100)
                                        .padding(AppSpacing.sm)
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
                                        Text("请简要描述这个板块的用途和讨论主题")
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
                                Text("板块图标（可选）")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(AppColors.textPrimary)
                                
                                Text("可以输入一个 emoji 表情作为板块图标，例如：💬、📚、🎮 等")
                                    .font(.system(size: 12))
                                    .foregroundColor(AppColors.textSecondary)
                                
                                TextField("例如：💬", text: $categoryIcon)
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
                                        // 限制字符长度
                                        if newValue.count > maxIconLength {
                                            categoryIcon = String(newValue.prefix(maxIconLength))
                                        }
                                    }
                                
                                // 字符计数（仅当有输入时显示）
                                if !categoryIcon.isEmpty {
                                    HStack {
                                        Spacer()
                                        Text("\(iconCharacterCount)/\(maxIconLength)")
                                            .font(.system(size: 12))
                                            .foregroundColor(
                                                iconCharacterCount > maxIconLength 
                                                    ? AppColors.error 
                                                    : AppColors.textSecondary
                                            )
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
                                    Text("提交申请")
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
                    .padding(.bottom, AppSpacing.xl)
                }
            }
            .navigationTitle("申请新建板块")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
            .alert("申请已提交", isPresented: $showSuccessAlert) {
                Button("确定") {
                    dismiss()
                }
            } message: {
                Text("您的申请已成功提交，管理员将在审核后通知您结果。")
            }
        }
    }
    
    private func submitRequest() {
        // 防重复提交检查
        guard !hasSubmitted && !isLoading else { return }
        
        // 验证输入
        let trimmedName = categoryName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            errorMessage = "请输入板块名称"
            return
        }
        
        guard trimmedName.count <= maxNameLength else {
            errorMessage = "板块名称不能超过\(maxNameLength)个字符"
            return
        }
        
        guard categoryDescription.count <= maxDescriptionLength else {
            errorMessage = "板块描述不能超过\(maxDescriptionLength)个字符"
            return
        }
        
        guard categoryIcon.count <= maxIconLength else {
            errorMessage = "图标不能超过\(maxIconLength)个字符"
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
        .sink(
            receiveCompletion: { completion in
                DispatchQueue.main.async {
                    isLoading = false
                    if case .failure(let error) = completion {
                        hasSubmitted = false // 失败后允许重新提交
                        // 解析错误信息，提供更友好的提示
                        if let apiError = error as? APIError {
                            switch apiError {
                            case .httpError(let code):
                                if code == 400 {
                                    errorMessage = "提交失败，请检查输入内容是否正确"
                                } else if code == 401 {
                                    errorMessage = "登录已过期，请重新登录"
                                } else {
                                    errorMessage = error.userFriendlyMessage
                                }
                            default:
                                errorMessage = error.userFriendlyMessage
                            }
                        } else {
                            errorMessage = error.userFriendlyMessage
                        }
                    }
                }
            },
            receiveValue: { response in
                DispatchQueue.main.async {
                    isLoading = false
                    showSuccessAlert = true
                    // 清空表单
                    categoryName = ""
                    categoryDescription = ""
                    categoryIcon = ""
                    hasSubmitted = false // 成功后重置，允许再次提交
                }
            }
        )
        .store(in: &cancellables)
    }
    
    private var cancellables = Set<AnyCancellable>()
}
