import SwiftUI
import UIKit

struct TaskDetailView: View {
    let taskId: Int
    @StateObject private var viewModel = TaskDetailViewModel()
    @EnvironmentObject var appState: AppState
    @State private var showApplySheet = false
    @State private var applyMessage = ""
    @State private var negotiatedPrice: Double?
    @State private var showNegotiatePrice = false
    @State private var showFullScreenImage = false
    @State private var selectedImageIndex = 0
    @State private var actionLoading = false
    @State private var showReviewModal = false
    @State private var reviewRating = 5
    @State private var reviewComment = ""
    @State private var isAnonymousReview = false
    @State private var selectedReviewTags: [String] = []
    @State private var showCancelConfirm = false
    @State private var cancelReason = ""
    @State private var showLogin = false
    @State private var showShareSheet = false
    
    // 判断当前用户是否是任务发布者
    private var isPoster: Bool {
        guard let task = viewModel.task,
              let currentUserId = appState.currentUser?.id,
              let posterId = task.posterId else {
            return false
        }
        return String(posterId) == currentUserId
    }
    
    // 判断当前用户是否是任务接受者
    private var isTaker: Bool {
        guard let task = viewModel.task,
              let currentUserId = appState.currentUser?.id,
              let takerId = task.takerId else {
            return false
        }
        return String(takerId) == currentUserId
    }
    
    // 判断是否已申请
    private var hasApplied: Bool {
        viewModel.userApplication != nil
    }
    
    // 判断是否可以评价
    private var canReview: Bool {
        guard let task = viewModel.task,
              appState.currentUser != nil else {
            return false
        }
        return task.status == .completed && (isPoster || isTaker)
    }
    
    // 判断是否已评价
    private var hasReviewed: Bool {
        guard let currentUserId = appState.currentUser?.id else {
            return false
        }
        return viewModel.reviews.contains { review in
            String(review.reviewerId) == currentUserId
        }
    }
    
    @ViewBuilder
    private var contentView: some View {
        ZStack {
            AppColors.background
                .ignoresSafeArea()
            
            if viewModel.isLoading && viewModel.task == nil {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let task = viewModel.task {
                TaskDetailContentView(
                    task: task,
                    selectedImageIndex: $selectedImageIndex,
                    showFullScreenImage: $showFullScreenImage,
                    showApplySheet: $showApplySheet,
                    applyMessage: $applyMessage,
                    negotiatedPrice: $negotiatedPrice,
                    showNegotiatePrice: $showNegotiatePrice,
                    actionLoading: $actionLoading,
                    showReviewModal: $showReviewModal,
                    reviewRating: $reviewRating,
                    reviewComment: $reviewComment,
                    isAnonymousReview: $isAnonymousReview,
                    selectedReviewTags: $selectedReviewTags,
                    showCancelConfirm: $showCancelConfirm,
                    cancelReason: $cancelReason,
                    showLogin: $showLogin,
                    isPoster: isPoster,
                    isTaker: isTaker,
                    hasApplied: hasApplied,
                    canReview: canReview,
                    hasReviewed: hasReviewed,
                    taskId: taskId,
                    viewModel: viewModel
                )
            } else {
                // 错误状态（符合 HIG）
                VStack(spacing: AppSpacing.lg) {
                    IconStyle.icon("exclamationmark.triangle.fill", size: 50)
                        .foregroundColor(AppColors.error)
                    Text("加载失败")
                        .font(AppTypography.title3) // 使用 title3
                        .foregroundColor(AppColors.textPrimary)
                    Button("重试") {
                        viewModel.loadTask(taskId: taskId)
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }
            }
        }
    }
    
    var body: some View {
        contentView
            .navigationTitle("任务详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppColors.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: {
                            showShareSheet = true
                        }) {
                            Label("分享", systemImage: "square.and.arrow.up")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .foregroundColor(AppColors.primary)
                            .frame(width: 24, height: 24)
                    }
                }
            }
            .fullScreenCover(isPresented: $showFullScreenImage) {
                fullScreenImageView
            }
            .sheet(isPresented: $showApplySheet) {
                applyTaskSheet
            }
            .sheet(isPresented: $showReviewModal) {
                reviewModal
            }
            .sheet(isPresented: $showShareSheet) {
                shareSheet
            }
            .alert("取消任务", isPresented: $showCancelConfirm) {
                cancelTaskAlert
            } message: {
                Text("确定要取消这个任务吗？")
            }
            .sheet(isPresented: $showLogin) {
                LoginView()
            }
            .onAppear {
                viewModel.loadTask(taskId: taskId)
            }
            .onChange(of: viewModel.task?.id) { newTaskId in
                // 当任务加载完成或任务ID变化时，加载申请列表和评价
                if newTaskId != nil {
                    handleTaskChange()
                }
            }
            .onChange(of: viewModel.task?.status) { _ in
                // 当任务状态变化时，重新加载申请列表（例如从 open 变为 inProgress）
                handleTaskChange()
            }
    }
    
    @ViewBuilder
    private var fullScreenImageView: some View {
        if let images = viewModel.task?.images, !images.isEmpty {
            FullScreenImageView(
                images: images,
                selectedIndex: $selectedImageIndex,
                isPresented: $showFullScreenImage
            )
        }
    }
    
    @ViewBuilder
    private var applyTaskSheet: some View {
        if let task = viewModel.task {
            ApplyTaskSheet(
                message: $applyMessage,
                negotiatedPrice: $negotiatedPrice,
                showNegotiatePrice: $showNegotiatePrice,
                task: task,
                onApply: {
                    viewModel.applyTask(
                        taskId: taskId,
                        message: applyMessage.isEmpty ? nil : applyMessage,
                        negotiatedPrice: negotiatedPrice
                    ) { success in
                        if success {
                            showApplySheet = false
                            applyMessage = ""
                            negotiatedPrice = nil
                            showNegotiatePrice = false
                            viewModel.loadTask(taskId: taskId)
                        }
                    }
                }
            )
        }
    }
    
    @ViewBuilder
    private var reviewModal: some View {
        ReviewModal(
            rating: $reviewRating,
            comment: $reviewComment,
            isAnonymous: $isAnonymousReview,
            selectedTags: $selectedReviewTags,
            task: viewModel.task,
            isPoster: isPoster,
            onSubmit: {
                viewModel.createReview(
                    taskId: taskId,
                    rating: Double(reviewRating),
                    comment: reviewComment.isEmpty ? nil : reviewComment,
                    isAnonymous: isAnonymousReview
                ) { success in
                    if success {
                        showReviewModal = false
                        reviewRating = 5
                        reviewComment = ""
                        isAnonymousReview = false
                        selectedReviewTags = []
                        viewModel.loadTask(taskId: taskId)
                        viewModel.loadReviews(taskId: taskId)
                    }
                }
            }
        )
    }
    
    @ViewBuilder
    private var cancelTaskAlert: some View {
        TextField("取消原因（可选）", text: $cancelReason)
        Button("确定", role: .destructive) {
            actionLoading = true
            viewModel.cancelTask(taskId: taskId, reason: cancelReason.isEmpty ? nil : cancelReason) { success in
                actionLoading = false
                if success {
                    cancelReason = ""
                    viewModel.loadTask(taskId: taskId)
                }
            }
        }
        Button("取消", role: .cancel) {
            cancelReason = ""
        }
    }
    
    private func handleTaskChange() {
        // 当任务加载完成后，加载申请列表和评价
        guard let task = viewModel.task else { return }
        
        // 加载申请列表：
        // 1. 如果是发布者且任务状态是 open，需要查看所有申请
        // 2. 如果用户已登录（非发布者），需要查看自己的申请状态
        if isPoster && task.status == .open {
            // 发布者查看所有申请
            viewModel.loadApplications(taskId: taskId, currentUserId: appState.currentUser?.id)
        } else if appState.currentUser != nil {
            // 非发布者查看自己的申请状态
            viewModel.loadApplications(taskId: taskId, currentUserId: appState.currentUser?.id)
        }
        
        // 加载评价
        viewModel.loadReviews(taskId: taskId)
    }
    
    @ViewBuilder
    private var shareSheet: some View {
        if let task = viewModel.task {
            // 构建分享内容
            let shareText = buildShareText(for: task)
            let shareURL = buildShareURL(for: task)
            
            ShareSheet(items: [shareText, shareURL])
        }
    }
    
    private func buildShareText(for task: Task) -> String {
        var text = "\(task.title)\n\n"
        
        if !task.description.isEmpty {
            let description = task.description.count > 200 
                ? String(task.description.prefix(200)) + "..." 
                : task.description
            text += "\(description)\n\n"
        }
        
        text += "奖励: £\(String(format: "%.2f", task.reward))"
        if let pointsReward = task.pointsReward, pointsReward > 0 {
            text += " + \(pointsReward)积分"
        }
        text += "\n"
        
        text += "位置: \(task.location)\n"
        text += "类型: \(task.taskType)\n\n"
        
        text += "在 Link²Ur 查看详情"
        
        return text
    }
    
    private func buildShareURL(for task: Task) -> URL {
        // 构建任务详情页的URL（根据实际后端API调整）
        let baseURL = "https://www.link2ur.com"
        let taskURL = "\(baseURL)/tasks/\(taskId)"
        return URL(string: taskURL) ?? URL(string: baseURL)!
    }
}

// MARK: - TaskDetailContentView (拆分出来的主要内容视图)
struct TaskDetailContentView: View {
    let task: Task
    @Binding var selectedImageIndex: Int
    @Binding var showFullScreenImage: Bool
    @Binding var showApplySheet: Bool
    @Binding var applyMessage: String
    @Binding var negotiatedPrice: Double?
    @Binding var showNegotiatePrice: Bool
    @Binding var actionLoading: Bool
    @Binding var showReviewModal: Bool
    @Binding var reviewRating: Int
    @Binding var reviewComment: String
    @Binding var isAnonymousReview: Bool
    @Binding var selectedReviewTags: [String]
    @Binding var showCancelConfirm: Bool
    @Binding var cancelReason: String
    @Binding var showLogin: Bool
    let isPoster: Bool
    let isTaker: Bool
    let hasApplied: Bool
    let canReview: Bool
    let hasReviewed: Bool
    let taskId: Int
    @ObservedObject var viewModel: TaskDetailViewModel
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // 图片轮播区域
                TaskImageCarouselView(
                    images: task.images ?? [],
                    selectedIndex: $selectedImageIndex,
                    showFullScreen: $showFullScreenImage
                )
                
                // 内容区域
                VStack(spacing: AppSpacing.md) {
                    // 标题和状态卡片
                    TaskHeaderCard(task: task)
                    
                    // 任务详情卡片
                    TaskInfoCard(task: task)
                    
                    // 申请状态显示
                    if !isPoster && hasApplied, let userApp = viewModel.userApplication {
                        ApplicationStatusCard(application: userApp, task: task)
                            .padding(.horizontal, AppSpacing.md)
                    }
                    
                    // 发布者查看自己任务时的提示信息
                    if isPoster && task.status == .open {
                        PosterInfoCard()
                            .padding(.horizontal, AppSpacing.md)
                    }
                    
                    // 发布者：申请列表
                    if isPoster && task.status == .open {
                        ApplicationsListView(
                            applications: viewModel.applications,
                            isLoading: viewModel.isLoadingApplications,
                            taskId: taskId,
                            taskTitle: task.title,
                            onApprove: { applicationId in
                                actionLoading = true
                                viewModel.approveApplication(taskId: taskId, applicationId: applicationId) { success in
                                    actionLoading = false
                                    if success {
                                        viewModel.loadTask(taskId: taskId)
                                        viewModel.loadApplications(taskId: taskId, currentUserId: appState.currentUser?.id)
                                    }
                                }
                            },
                            onReject: { applicationId in
                                actionLoading = true
                                viewModel.rejectApplication(taskId: taskId, applicationId: applicationId) { success in
                                    actionLoading = false
                                    if success {
                                        viewModel.loadTask(taskId: taskId)
                                        viewModel.loadApplications(taskId: taskId, currentUserId: appState.currentUser?.id)
                                    }
                                }
                            }
                        )
                        .padding(.horizontal, AppSpacing.md)
                    }
                    
                    // 操作按钮区域
                    TaskActionButtonsView(
                        task: task,
                        isPoster: isPoster,
                        isTaker: isTaker,
                        canReview: canReview,
                        hasReviewed: hasReviewed,
                        actionLoading: $actionLoading,
                        showApplySheet: $showApplySheet,
                        showReviewModal: $showReviewModal,
                        showCancelConfirm: $showCancelConfirm,
                        showLogin: $showLogin,
                        taskId: taskId,
                        viewModel: viewModel
                    )
                    .padding(.horizontal, AppSpacing.md)
                    
                    // 评价列表
                    if !viewModel.reviews.isEmpty {
                        TaskReviewsSection(reviews: viewModel.reviews)
                            .padding(.horizontal, AppSpacing.md)
                    }
                }
                .padding(.top, -20) // 让内容卡片与图片重叠
            }
        }
    }
}

// MARK: - 图片轮播视图
struct TaskImageCarouselView: View {
    let images: [String]
    @Binding var selectedIndex: Int
    @Binding var showFullScreen: Bool
    
    var body: some View {
        if !images.isEmpty {
            TabView(selection: $selectedIndex) {
                ForEach(Array(images.enumerated()), id: \.offset) { index, imageUrl in
                    TaskImageView(imageUrl: imageUrl, index: index, selectedIndex: $selectedIndex, showFullScreen: $showFullScreen)
                        .tag(index)
                }
            }
            .tabViewStyle(.page)
            .frame(height: 280)
        } else {
            // 无图片时显示占位图
            ZStack {
                Rectangle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [AppColors.primary.opacity(0.2), AppColors.primary.opacity(0.1)]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Image("Logo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 120, height: 120)
                    .opacity(0.6)
            }
            .frame(height: 280)
        }
    }
}

// MARK: - 单个图片视图
struct TaskImageView: View {
    let imageUrl: String
    let index: Int
    @Binding var selectedIndex: Int
    @Binding var showFullScreen: Bool
    
    var body: some View {
        ZStack {
            AsyncImage(url: imageUrl.toImageURL()) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                case .failure(_), .empty:
                    ZStack {
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [AppColors.primary.opacity(0.2), AppColors.primary.opacity(0.1)]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        Image("Logo")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 120, height: 120)
                            .opacity(0.6)
                    }
                @unknown default:
                    Rectangle()
                        .fill(AppColors.cardBackground)
                }
            }
            .frame(height: 280)
            .clipped()
            
            // 点击区域
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    selectedIndex = index
                    showFullScreen = true
                }
        }
    }
}

// MARK: - 任务头部卡片
struct TaskHeaderCard: View {
    let task: Task
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    // 任务等级标签
                    if let taskLevel = task.taskLevel, taskLevel != "normal" {
                        Label(
                            taskLevel == "vip" ? "VIP任务" : "超级任务",
                            systemImage: taskLevel == "vip" ? "star.fill" : "flame.fill"
                        )
                        .font(AppTypography.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, AppSpacing.sm)
                        .padding(.vertical, 4)
                        .background(taskLevel == "vip" ? Color.orange : Color.purple)
                        .clipShape(Capsule())
                    }
                    
                    Text(task.title)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(AppColors.textPrimary)
                        .lineLimit(3)
                    
                    // 价格和积分
                    TaskRewardView(task: task)
                }
                
                Spacer()
                
                StatusBadge(status: task.status)
            }
            
            // 分类和位置标签
            HStack(spacing: AppSpacing.sm) {
                Label(task.taskType, systemImage: "tag.fill")
                    .font(AppTypography.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.vertical, 6)
                    .background(AppColors.primary)
                    .clipShape(Capsule())
                
                Label(task.location, systemImage: task.location == "Online" ? "globe" : "mappin.circle.fill")
                    .font(AppTypography.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.textPrimary)
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.vertical, 6)
                    .background(AppColors.cardBackground)
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(AppColors.separator, lineWidth: 0.5)
                    )
            }
        }
        .padding(AppSpacing.md)
        .background(AppColors.cardBackground)
        .cornerRadius(AppCornerRadius.large, corners: [.topLeft, .topRight])
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: -2)
    }
}

// MARK: - 任务奖励视图
struct TaskRewardView: View {
    let task: Task
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if task.reward > 0 {
                HStack(spacing: 4) {
                    Text("£")
                        .font(.system(size: 20, weight: .bold))
                    Text(formatPrice(task.reward))
                        .font(.system(size: 28, weight: .bold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, AppSpacing.md)
                .padding(.vertical, AppSpacing.sm)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: AppColors.gradientSuccess),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(AppCornerRadius.medium)
                .shadow(color: AppColors.success.opacity(0.3), radius: 8, x: 0, y: 4)
            }
            
            if let pointsReward = task.pointsReward, pointsReward > 0 {
                Label("\(pointsReward)积分", systemImage: "star.fill")
                    .font(AppTypography.body)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.horizontal, AppSpacing.sm)
                    .padding(.vertical, AppSpacing.sm)
                    .background(Color.purple)
                    .clipShape(RoundedRectangle(cornerRadius: AppCornerRadius.medium, style: .continuous))
            }
        }
    }
    
    private func formatPrice(_ price: Double) -> String {
        if price.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", price)
        } else {
            return String(format: "%.2f", price)
        }
    }
}

// MARK: - 任务信息卡片
struct TaskInfoCard: View {
    let task: Task
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            // 描述
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Text("任务描述")
                    .font(AppTypography.title3)
                    .foregroundColor(AppColors.textPrimary)
                
                Text(task.description)
                    .font(AppTypography.body)
                    .foregroundColor(AppColors.textSecondary)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Divider()
                .background(AppColors.separator)
            
            // 时间信息
            TaskTimeInfoView(task: task)
            
            // 发布者信息
            if let poster = task.poster {
                Divider()
                    .background(AppColors.separator)
                
                TaskPosterInfoView(poster: poster)
            }
        }
        .padding(AppSpacing.md)
        .cardStyle(useMaterial: true)
        .padding(.horizontal, AppSpacing.md)
    }
}

// MARK: - 时间信息视图
struct TaskTimeInfoView: View {
    let task: Task
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("时间信息")
                .font(AppTypography.title3)
                .foregroundColor(AppColors.textPrimary)
            
            VStack(spacing: AppSpacing.md) {
                HStack(spacing: AppSpacing.sm) {
                    IconStyle.icon("clock.fill", size: IconStyle.medium)
                        .foregroundColor(AppColors.primary)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("发布时间")
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.textSecondary)
                        Text(DateFormatterHelper.shared.formatTime(task.createdAt))
                            .font(AppTypography.body)
                            .foregroundColor(AppColors.textPrimary)
                    }
                    
                    Spacer()
                }
                
                if let deadline = task.deadline {
                    HStack(spacing: AppSpacing.sm) {
                        IconStyle.icon("calendar.badge.exclamationmark", size: IconStyle.medium)
                            .foregroundColor(AppColors.error)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("截止时间")
                                .font(AppTypography.caption)
                                .foregroundColor(AppColors.textSecondary)
                            Text(DateFormatterHelper.shared.formatDeadline(deadline))
                                .font(AppTypography.body)
                                .foregroundColor(AppColors.textPrimary)
                        }
                        
                        Spacer()
                    }
                }
            }
        }
    }
}

// MARK: - 发布者信息视图
struct TaskPosterInfoView: View {
    let poster: User
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("发布者")
                .font(AppTypography.title3)
                .foregroundColor(AppColors.textPrimary)
            
            NavigationLink(destination: UserProfileView(userId: poster.id)) {
                HStack(spacing: 12) {
                    AvatarView(
                        urlString: poster.avatar,
                        size: 56,
                        placeholder: Image(systemName: "person.fill")
                    )
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(poster.name)
                            .font(AppTypography.body)
                            .fontWeight(.semibold)
                            .foregroundColor(AppColors.textPrimary)
                        
                        Text(poster.email ?? "未提供邮箱")
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.textSecondary)
                        
                        if let userLevel = poster.userLevel {
                            Label(userLevel.uppercased(), systemImage: "star.fill")
                                .font(AppTypography.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal, AppSpacing.sm)
                                .padding(.vertical, 4)
                                .background(AppColors.warning)
                                .clipShape(Capsule())
                        }
                    }
                    
                    Spacer()
                    
                    IconStyle.icon("chevron.right", size: IconStyle.small)
                        .foregroundColor(AppColors.textTertiary)
                }
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
}

// MARK: - 发布者提示卡片
struct PosterInfoCard: View {
    var body: some View {
        VStack(spacing: AppSpacing.sm) {
            Label("这是您发布的任务", systemImage: "info.circle.fill")
                .font(AppTypography.body)
                .foregroundColor(AppColors.textPrimary)
            
            Text("您可以在下方查看申请者列表并管理任务")
                .font(AppTypography.caption)
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(AppSpacing.md)
        .frame(maxWidth: .infinity)
        .background(AppColors.primaryLight)
        .clipShape(RoundedRectangle(cornerRadius: AppCornerRadius.medium, style: .continuous))
    }
}

// MARK: - 任务操作按钮视图
struct TaskActionButtonsView: View {
    let task: Task
    let isPoster: Bool
    let isTaker: Bool
    let canReview: Bool
    let hasReviewed: Bool
    @Binding var actionLoading: Bool
    @Binding var showApplySheet: Bool
    @Binding var showReviewModal: Bool
    @Binding var showCancelConfirm: Bool
    @Binding var showLogin: Bool
    let taskId: Int
    @ObservedObject var viewModel: TaskDetailViewModel
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        VStack(spacing: AppSpacing.sm) {
            // 申请按钮
            if task.status == .open && !isPoster {
                Button(action: {
                    if appState.isAuthenticated {
                        showApplySheet = true
                    } else {
                        showLogin = true
                    }
                }) {
                    HStack(spacing: AppSpacing.sm) {
                        IconStyle.icon("hand.raised.fill", size: IconStyle.medium)
                        Text("申请任务")
                            .font(AppTypography.bodyBold)
                        IconStyle.icon("chevron.right", size: IconStyle.small)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(AppColors.primary)
                    .clipShape(RoundedRectangle(cornerRadius: AppCornerRadius.medium, style: .continuous))
                }
                .buttonStyle(PrimaryButtonStyle(cornerRadius: AppCornerRadius.medium, useGradient: false))
            }
            
            // 其他操作按钮
            if task.status == .inProgress && isTaker {
                Button(action: {
                    actionLoading = true
                    viewModel.completeTask(taskId: taskId) { success in
                        actionLoading = false
                        if success {
                            viewModel.loadTask(taskId: taskId)
                        }
                    }
                }) {
                    HStack(spacing: AppSpacing.sm) {
                        if actionLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            IconStyle.icon("checkmark.circle.fill", size: IconStyle.medium)
                        }
                        Text(actionLoading ? "处理中..." : "标记完成")
                    }
                    .font(AppTypography.bodyBold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(AppColors.success)
                    .clipShape(RoundedRectangle(cornerRadius: AppCornerRadius.medium, style: .continuous))
                }
                .disabled(actionLoading)
            }
            
            if task.status == .pendingConfirmation && isPoster {
                Button(action: {
                    actionLoading = true
                    viewModel.confirmTaskCompletion(taskId: taskId) { success in
                        actionLoading = false
                        if success {
                            viewModel.loadTask(taskId: taskId)
                        }
                    }
                }) {
                    HStack(spacing: AppSpacing.sm) {
                        if actionLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            IconStyle.icon("checkmark.seal.fill", size: IconStyle.medium)
                        }
                        Text(actionLoading ? "处理中..." : "确认完成")
                    }
                    .font(AppTypography.bodyBold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(AppColors.success)
                    .clipShape(RoundedRectangle(cornerRadius: AppCornerRadius.medium, style: .continuous))
                }
                .disabled(actionLoading)
            }
            
            if (isPoster || isTaker) && (task.status == .open || task.status == .inProgress) {
                Button(action: {
                    showCancelConfirm = true
                }) {
                    Label("取消任务", systemImage: "xmark.circle.fill")
                        .font(AppTypography.bodyBold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(AppColors.error)
                        .clipShape(RoundedRectangle(cornerRadius: AppCornerRadius.medium, style: .continuous))
                }
            }
            
            if task.status == .inProgress && task.takerId != nil {
                NavigationLink(destination: TaskChatView(taskId: taskId, taskTitle: task.title)) {
                    Label(isPoster ? "联系接受者" : "联系发布者", systemImage: "message.fill")
                        .font(AppTypography.bodyBold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(AppColors.primary)
                        .clipShape(RoundedRectangle(cornerRadius: AppCornerRadius.medium, style: .continuous))
                }
            }
            
            if canReview && !hasReviewed {
                Button(action: {
                    showReviewModal = true
                }) {
                    Label("评价任务", systemImage: "star.fill")
                        .font(AppTypography.bodyBold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(AppColors.warning)
                        .clipShape(RoundedRectangle(cornerRadius: AppCornerRadius.medium, style: .continuous))
                }
            }
        }
    }
}

// MARK: - 任务评价区域
struct TaskReviewsSection: View {
    let reviews: [Review]
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("评价 (\(reviews.count))")
                .font(AppTypography.title3)
                .foregroundColor(AppColors.textPrimary)
            
            ForEach(reviews) { review in
                ReviewRow(review: review)
            }
        }
        .padding(AppSpacing.md)
        .cardStyle(useMaterial: true)
    }
}

// MARK: - 评价行
struct ReviewRow: View {
    let review: Review
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack {
                Text(review.isAnonymous == true ? "匿名用户" : (review.reviewer?.name ?? "未知用户"))
                    .font(AppTypography.body)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.textPrimary)
                
                Spacer()
                
                HStack(spacing: 4) {
                    ForEach(1...5, id: \.self) { star in
                        IconStyle.icon("star.fill", size: IconStyle.small)
                            .foregroundColor(star <= Int(review.rating) ? AppColors.warning : AppColors.textTertiary)
                    }
                }
            }
            
            if let comment = review.comment, !comment.isEmpty {
                Text(comment)
                    .font(AppTypography.body)
                    .foregroundColor(AppColors.textSecondary)
            }
            
            Text(DateFormatterHelper.shared.formatTime(review.createdAt))
                .font(AppTypography.caption)
                .foregroundColor(AppColors.textTertiary)
        }
        .padding(.vertical, AppSpacing.sm)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(AppColors.separator),
            alignment: .bottom
        )
    }
}

// MARK: - 辅助函数
private func formatPrice(_ price: Double) -> String {
    if price.truncatingRemainder(dividingBy: 1) == 0 {
        return String(format: "%.0f", price)
    } else {
        return String(format: "%.2f", price)
    }
}

// 申请任务弹窗（符合 Apple HIG，支持价格协商）
struct ApplyTaskSheet: View {
    @Binding var message: String
    @Binding var negotiatedPrice: Double?
    @Binding var showNegotiatePrice: Bool
    let task: Task?
    let onApply: () -> Void
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 内容区域（符合 HIG）
                Form {
                    Section {
                        VStack(alignment: .leading, spacing: AppSpacing.sm) {
                            Text("留言（可选）")
                                .font(AppTypography.body) // 使用 body
                                .foregroundColor(AppColors.textPrimary)
                            
                            TextEditor(text: $message)
                                .frame(minHeight: 120)
                                .padding(AppSpacing.sm)
                                .background(AppColors.cardBackground)
                                .clipShape(RoundedRectangle(cornerRadius: AppCornerRadius.small, style: .continuous))
                        }
                    } header: {
                        Text("申请信息")
                    }
                    
                    // 价格协商（参考 frontend，仅非多人任务）
                    if let task = task, task.isMultiParticipant != true {
                        Section {
                            Toggle("想要协商价格", isOn: $showNegotiatePrice)
                                .font(AppTypography.body) // 使用 body
                                .onChange(of: showNegotiatePrice) { isOn in
                                    if isOn {
                                        negotiatedPrice = task.baseReward ?? task.reward
                                    } else {
                                        negotiatedPrice = nil
                                    }
                                }
                            
                            if showNegotiatePrice {
                                HStack {
                                    Text("£")
                                        .font(AppTypography.body) // 使用 body
                                    TextField("0.00", value: $negotiatedPrice, format: .number)
                                        .keyboardType(.decimalPad)
                                        .textFieldStyle(.roundedBorder)
                                }
                            }
                        } header: {
                            Text("价格协商")
                        } footer: {
                            Text("向发布者说明你的申请理由，有助于提高申请成功率")
                                .font(AppTypography.caption) // 使用 caption
                        }
                    }
                    
                    Section {
                        Button(action: onApply) {
                            Text("提交申请")
                                .font(AppTypography.bodyBold)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(AppColors.primary)
                                .clipShape(RoundedRectangle(cornerRadius: AppCornerRadius.medium, style: .continuous))
                        }
                    }
                }
            }
            .navigationTitle("申请任务")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// 申请状态卡片（参考 frontend）
struct ApplicationStatusCard: View {
    let application: TaskApplication
    let task: Task
    
    private var statusColor: Color {
        switch application.status {
        case "pending":
            return AppColors.warning
        case "approved":
            return task.status == .pendingConfirmation ? Color(red: 0.373, green: 0.188, blue: 0.639) : AppColors.success
        case "rejected":
            return AppColors.error
        default:
            return AppColors.textSecondary
        }
    }
    
    private var statusText: String {
        switch application.status {
        case "pending":
            return "等待发布者审核"
        case "approved":
            return task.status == .pendingConfirmation ? "任务已完成" : "申请已通过"
        case "rejected":
            return "申请被拒绝"
        default:
            return "未知状态"
        }
    }
    
    private var statusDescription: String {
        switch application.status {
        case "pending":
            return "您已成功申请此任务，请等待任务发布者审核您的申请。"
        case "approved":
            return task.status == .pendingConfirmation
                ? "恭喜！您已完成任务，请等待发布者确认任务完成。"
                : "恭喜！您的申请已通过，现在可以开始执行任务了。"
        case "rejected":
            return "很抱歉，您的申请被拒绝了。"
        default:
            return ""
        }
    }
    
    var body: some View {
        HStack(spacing: AppSpacing.md) {
            // 使用 SF Symbols 图标
            IconStyle.icon(statusIcon, size: IconStyle.xlarge)
                .foregroundColor(statusColor)
            
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text(statusText)
                    .font(AppTypography.title3) // 使用 title3
                    .foregroundColor(statusColor)
                
                Text(statusDescription)
                    .font(AppTypography.body) // 使用 body
                    .foregroundColor(AppColors.textSecondary)
                    .lineLimit(nil)
                
                if let message = application.message, !message.isEmpty {
                    Label("申请留言：\(message)", systemImage: "message.fill")
                        .font(AppTypography.caption) // 使用 caption
                        .foregroundColor(AppColors.textTertiary)
                        .padding(.top, AppSpacing.xs)
                }
            }
            
            Spacer()
        }
        .padding(AppSpacing.md)
        .background(
            statusColor.opacity(0.1)
        )
        .clipShape(RoundedRectangle(cornerRadius: AppCornerRadius.medium, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppCornerRadius.medium, style: .continuous)
                .stroke(statusColor, lineWidth: 1)
        )
    }
    
    private var statusIcon: String {
        switch application.status {
        case "pending":
            return "clock.fill"
        case "approved":
            return task.status == .pendingConfirmation ? "clock.badge.checkmark.fill" : "checkmark.circle.fill"
        case "rejected":
            return "xmark.circle.fill"
        default:
            return "questionmark.circle.fill"
        }
    }
}

// 申请列表视图（参考 frontend）
struct ApplicationsListView: View {
    let applications: [TaskApplication]
    let isLoading: Bool
    let taskId: Int
    let taskTitle: String
    let onApprove: (Int) -> Void
    let onReject: (Int) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("申请者列表 (\(applications.count))")
                .font(AppTypography.title3) // 使用 title3
                .foregroundColor(AppColors.textPrimary)
            
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(AppSpacing.lg)
            } else if applications.isEmpty {
                Text("暂无申请者")
                    .font(AppTypography.body) // 使用 body
                    .foregroundColor(AppColors.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(AppSpacing.lg)
                    .cardStyle(useMaterial: true) // 使用材质效果
            } else {
                ForEach(applications) { app in
                    ApplicationItemCard(
                        application: app,
                        taskId: taskId,
                        taskTitle: taskTitle,
                        onApprove: { onApprove(app.id) },
                        onReject: { onReject(app.id) }
                    )
                }
            }
        }
        .padding(AppSpacing.md)
        .cardStyle(useMaterial: true) // 使用材质效果
    }
}

// 申请项卡片
struct ApplicationItemCard: View {
    let application: TaskApplication
    let taskId: Int
    let taskTitle: String
    let onApprove: () -> Void
    let onReject: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack {
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text(application.applicantName ?? "未知用户")
                        .font(AppTypography.body) // 使用 body
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.textPrimary)
                    
                    if let createdAt = application.createdAt {
                        Label("申请时间: \(DateFormatterHelper.shared.formatFullTime(createdAt))", systemImage: "calendar")
                            .font(AppTypography.caption) // 使用 caption
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
                
                Spacer()
                
                // 状态标签（使用 SF Symbols）
                Label(
                    application.status == "pending" ? "待审核" : application.status == "approved" ? "已通过" : "已拒绝",
                    systemImage: application.status == "pending" ? "clock.fill" : application.status == "approved" ? "checkmark.circle.fill" : "xmark.circle.fill"
                )
                .font(AppTypography.caption) // 使用 caption
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .padding(.horizontal, AppSpacing.sm)
                .padding(.vertical, 4)
                .background(
                    application.status == "pending" ? AppColors.warning :
                    application.status == "approved" ? AppColors.success : AppColors.error
                )
                .clipShape(Capsule())
            }
            
            if let message = application.message, !message.isEmpty {
                Label("\"\(message)\"", systemImage: "message.fill")
                    .font(AppTypography.body) // 使用 body
                    .foregroundColor(AppColors.textSecondary)
                    .padding(AppSpacing.sm)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppColors.primaryLight)
                    .clipShape(RoundedRectangle(cornerRadius: AppCornerRadius.small, style: .continuous))
            }
            
            // 操作按钮（符合 HIG）
            if application.status == "pending" {
                HStack(spacing: AppSpacing.sm) {
                    Button(action: onApprove) {
                        Label("批准", systemImage: "checkmark.circle.fill")
                            .font(AppTypography.body) // 使用 body
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, AppSpacing.sm)
                            .background(AppColors.success)
                            .clipShape(RoundedRectangle(cornerRadius: AppCornerRadius.small, style: .continuous))
                    }
                    
                    Button(action: onReject) {
                        Label("拒绝", systemImage: "xmark.circle.fill")
                            .font(AppTypography.body) // 使用 body
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, AppSpacing.sm)
                            .background(AppColors.error)
                            .clipShape(RoundedRectangle(cornerRadius: AppCornerRadius.small, style: .continuous))
                    }
                    
                    NavigationLink(destination: TaskChatView(taskId: taskId, taskTitle: taskTitle)) {
                        Label("联系", systemImage: "message.fill")
                            .font(AppTypography.body) // 使用 body
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, AppSpacing.sm)
                            .background(AppColors.primary)
                            .clipShape(RoundedRectangle(cornerRadius: AppCornerRadius.small, style: .continuous))
                    }
                }
            }
        }
        .padding(AppSpacing.md)
        .cardStyle(useMaterial: true) // 使用材质效果
    }
}

// 评价弹窗（参考 frontend）
struct ReviewModal: View {
    @Binding var rating: Int
    @Binding var comment: String
    @Binding var isAnonymous: Bool
    @Binding var selectedTags: [String]
    let task: Task?
    let isPoster: Bool
    let onSubmit: () -> Void
    @Environment(\.dismiss) var dismiss
    @State private var hoverRating = 0
    
    private var reviewTags: [String] {
        guard task != nil else { return [] }
        
        if isPoster {
            return [
                "工作质量好", "准时", "负责任", "态度好",
                "技能熟练", "值得信赖", "推荐", "优秀"
            ]
        } else {
            return [
                "任务清晰", "沟通及时", "付款及时", "要求合理",
                "合作愉快", "推荐", "值得信赖", "专业高效"
            ]
        }
    }
    
    private var ratingText: String {
        switch rating {
        case 1: return "非常差"
        case 2: return "差"
        case 3: return "一般"
        case 4: return "好"
        case 5: return "非常好"
        default: return ""
        }
    }
    
    var body: some View {
        NavigationView {
            Form {
                // 星级评价（符合 HIG）
                Section {
                    VStack(spacing: AppSpacing.sm) {
                        HStack(spacing: AppSpacing.xs) {
                            ForEach(1...5, id: \.self) { star in
                                Button(action: {
                                    rating = star
                                }) {
                                    IconStyle.icon("star.fill", size: IconStyle.xlarge)
                                        .foregroundColor(star <= (hoverRating > 0 ? hoverRating : rating) ? AppColors.warning : AppColors.textTertiary)
                                }
                                .onHover { hovering in
                                    hoverRating = hovering ? star : 0
                                }
                            }
                        }
                        
                        Text(ratingText)
                            .font(AppTypography.body) // 使用 body
                            .foregroundColor(AppColors.textPrimary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppSpacing.md)
                } header: {
                    Text("评分")
                }
                    
                // 标签选择（符合 HIG）
                Section {
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: AppSpacing.sm) {
                        ForEach(reviewTags, id: \.self) { tag in
                            Button(action: {
                                if selectedTags.contains(tag) {
                                    selectedTags.removeAll { $0 == tag }
                                } else {
                                    selectedTags.append(tag)
                                }
                            }) {
                                Text(tag)
                                    .font(AppTypography.caption) // 使用 caption
                                    .foregroundColor(selectedTags.contains(tag) ? .white : AppColors.textPrimary)
                                    .padding(.horizontal, AppSpacing.sm)
                                    .padding(.vertical, AppSpacing.xs)
                                    .background(selectedTags.contains(tag) ? AppColors.primary : AppColors.cardBackground)
                                    .clipShape(RoundedRectangle(cornerRadius: AppCornerRadius.small, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: AppCornerRadius.small, style: .continuous)
                                            .stroke(selectedTags.contains(tag) ? Color.clear : AppColors.separator, lineWidth: 0.5)
                                    )
                            }
                        }
                    }
                } header: {
                    Text("选择标签（可选）")
                }
                
                // 评论输入（符合 HIG）
                Section {
                    TextEditor(text: $comment)
                        .frame(minHeight: 120)
                } header: {
                    Text("评论（可选）")
                }
                
                // 匿名选项（符合 HIG）
                Section {
                    Toggle("匿名评价", isOn: $isAnonymous)
                }
                
                // 提交按钮（符合 HIG）
                Section {
                    Button(action: {
                        // 将标签添加到评论中
                        if !selectedTags.isEmpty {
                            let tagsText = selectedTags.joined(separator: "、")
                            if comment.isEmpty {
                                comment = tagsText
                            } else {
                                comment = "\(tagsText)\n\n\(comment)"
                            }
                        }
                        onSubmit()
                    }) {
                        Text("提交评价")
                            .font(AppTypography.bodyBold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(AppColors.primary)
                            .clipShape(RoundedRectangle(cornerRadius: AppCornerRadius.medium, style: .continuous))
                    }
                }
            }
            .navigationTitle("评价任务")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
        }
    }
}

