import SwiftUI
import UIKit
import LinkPresentation
import Combine

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
    @State private var shareImage: UIImage?
    @State private var showApplySuccessAlert = false
    
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
            } else if let errorMessage = viewModel.errorMessage, viewModel.task == nil {
                // 显示错误状态
                ErrorStateView(
                    message: errorMessage,
                    retryAction: {
                        viewModel.loadTask(taskId: taskId)
                    }
                )
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
                    Text(LocalizationKey.tasksLoadFailed.localized)
                        .font(AppTypography.title3) // 使用 title3
                        .foregroundColor(AppColors.textPrimary)
                    Button(LocalizationKey.commonRetry.localized) {
                        viewModel.loadTask(taskId: taskId)
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }
            }
        }
    }
    
    var body: some View {
        contentView
            .navigationTitle(LocalizationKey.taskDetailTaskDetail.localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppColors.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            showShareSheet = true
                        } label: {
                            Label(LocalizationKey.taskDetailShare.localized, systemImage: "square.and.arrow.up")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.system(size: 20))
                            .foregroundColor(AppColors.primary)
                            .frame(width: 44, height: 44) // 增大点击区域
                            .contentShape(Rectangle())
                    }
                    .menuStyle(.automatic)
                    .menuIndicator(.hidden)
                }
            }
            .enableSwipeBack()
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
                if let task = viewModel.task {
                    TaskShareSheet(task: task, taskId: taskId, shareImage: shareImage)
                        .presentationDetents([.medium, .large])
                        .presentationDragIndicator(.visible)
                }
            }
            .alert(LocalizationKey.taskDetailCancelTask.localized, isPresented: $showCancelConfirm) {
                cancelTaskAlert
            } message: {
                Text(LocalizationKey.taskDetailCancelTaskConfirm.localized)
            }
            .alert(LocalizationKey.taskDetailApplicationSuccess.localized, isPresented: $showApplySuccessAlert) {
                Button(LocalizationKey.commonOk.localized) {
                    showApplySuccessAlert = false
                }
            } message: {
                Text(LocalizationKey.taskDetailApplicationSuccessMessage.localized)
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
                    // 加载分享用的图片
                    loadShareImage()
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
                            // 重新加载任务和申请列表
                            viewModel.loadTask(taskId: taskId)
                            viewModel.loadApplications(taskId: taskId, currentUserId: appState.currentUser?.id)
                            // 显示成功提示
                            showApplySuccessAlert = true
                            HapticFeedback.success()
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
                        // 重新加载评价列表，以更新 hasReviewed 状态并隐藏评价按钮
                        viewModel.loadReviews(taskId: taskId)
                        HapticFeedback.success()
                    }
                }
            }
        )
    }
    
    @ViewBuilder
    private var cancelTaskAlert: some View {
        TextField(LocalizationKey.actionsCancelReason.localized, text: $cancelReason)
        Button(LocalizationKey.actionsConfirm.localized, role: .destructive) {
            actionLoading = true
            viewModel.cancelTask(taskId: taskId, reason: cancelReason.isEmpty ? nil : cancelReason) { success in
                actionLoading = false
                if success {
                    cancelReason = ""
                    viewModel.loadTask(taskId: taskId)
                }
            }
        }
        Button(LocalizationKey.commonCancel.localized, role: .cancel) {
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
    
    private func loadShareImage() {
        guard let task = viewModel.task,
              let images = task.images,
              let firstImage = images.first,
              !firstImage.isEmpty,
              let url = URL(string: firstImage) else { return }
        
        URLSession.shared.dataTask(with: url) { data, _, _ in
            if let data = data, let image = UIImage(data: data) {
                DispatchQueue.main.async {
                    self.shareImage = image
                }
            }
        }.resume()
    }
}

// MARK: - 任务分享视图
struct TaskShareSheet: View {
    let task: Task
    let taskId: Int
    let shareImage: UIImage?
    @Environment(\.dismiss) var dismiss
    
    // 使用 API 域名，后端会为爬虫返回正确的 meta 标签，普通用户会被重定向到前端
    private var shareUrl: URL {
        URL(string: "https://api.link2ur.com/zh/tasks/\(taskId)") ?? URL(string: "https://www.link2ur.com")!
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 顶部拖动指示器
            Capsule()
                .fill(AppColors.separator)
                .frame(width: 36, height: 5)
                .padding(.top, 8)
                .padding(.bottom, 16)
            
            // 预览卡片
            VStack(spacing: AppSpacing.md) {
                // 封面图
                if let image = shareImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 150)
                        .clipped()
                        .cornerRadius(AppCornerRadius.medium)
                } else {
                    RoundedRectangle(cornerRadius: AppCornerRadius.medium)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [AppColors.primary.opacity(0.6), AppColors.primary]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(height: 150)
                        .overlay(
                            IconStyle.icon("doc.text.fill", size: 40)
                                .foregroundColor(.white.opacity(0.8))
                        )
                }
                
                // 标题和描述
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text(task.title)
                        .font(AppTypography.bodyBold)
                        .foregroundColor(AppColors.textPrimary)
                        .lineLimit(2)
                    
                    if !task.description.isEmpty {
                        Text(task.description)
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.textSecondary)
                            .lineLimit(2)
                    }
                    
                    // 任务信息
                    HStack(spacing: AppSpacing.md) {
                        Label("£\(String(format: "%.0f", task.reward))", systemImage: "sterlingsign.circle")
                        Label(task.location.obfuscatedLocation, systemImage: task.location.lowercased() == "online" ? "globe" : "mappin.circle")
                    }
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textTertiary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(AppSpacing.md)
            .background(AppColors.cardBackground)
            .cornerRadius(AppCornerRadius.large)
            .padding(.horizontal, AppSpacing.md)
            
            Spacer()
            
            // 分享按钮
            Button(action: shareContent) {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                    Text("分享到...")
                }
                .font(AppTypography.bodyBold)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(AppColors.primary)
                .cornerRadius(AppCornerRadius.large)
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.bottom, AppSpacing.lg)
        }
        .background(AppColors.background)
    }
    
    private func shareContent() {
        // 构建分享项目
        var shareItems: [Any] = []
        
        // 如果有图片，添加图片分享项（放在前面，微信会优先使用）
        if let image = shareImage {
            shareItems.append(TaskImageShareItem(image: image))
        }
        
        // 添加链接分享项
        let shareItem = TaskShareItem(
            url: shareUrl,
            title: task.title,
            description: task.description,
            image: shareImage
        )
        shareItems.append(shareItem)
        
        // 显示系统分享面板
        let activityVC = UIActivityViewController(
            activityItems: shareItems,
            applicationActivities: nil
        )
        
        activityVC.excludedActivityTypes = [
            .assignToContact,
            .addToReadingList,
            .openInIBooks
        ]
        
        // 获取当前的 UIViewController 并弹出分享面板
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            var topVC = rootVC
            while let presented = topVC.presentedViewController {
                topVC = presented
            }
            topVC.present(activityVC, animated: true)
        }
    }
}

// MARK: - 任务分享内容提供者
class TaskShareItem: NSObject, UIActivityItemSource {
    let url: URL
    let title: String
    let descriptionText: String
    let image: UIImage?
    
    init(url: URL, title: String, description: String, image: UIImage?) {
        self.url = url
        self.title = title
        self.descriptionText = description
        self.image = image
        super.init()
    }
    
    // 占位符 - 返回图片（如果有）让微信识别为图片分享
    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        // 返回 URL，让系统知道这是链接分享
        return url
    }
    
    // 实际分享的内容 - 根据分享目标返回不同内容
    func activityViewController(_ activityViewController: UIActivityViewController, itemForActivityType activityType: UIActivity.ActivityType?) -> Any? {
        // 对于微信等不支持 LPLinkMetadata 的 App，返回包含链接的文本
        // 这样用户可以看到完整的信息
        let shareText = """
        \(title)
        
        \(descriptionText.prefix(100))\(descriptionText.count > 100 ? "..." : "")
        
        👉 查看详情: \(url.absoluteString)
        """
        
        // 如果是复制或短信等，返回纯文本
        if activityType == .copyToPasteboard || activityType == .message {
            return shareText
        }
        
        // 其他情况返回 URL
        return url
    }
    
    // 提供富链接预览元数据（用于 iMessage 等原生 App）
    func activityViewControllerLinkMetadata(_ activityViewController: UIActivityViewController) -> LPLinkMetadata? {
        let metadata = LPLinkMetadata()
        metadata.originalURL = url
        metadata.url = url
        metadata.title = title
        
        // 如果有图片，设置为预览图
        if let image = image {
            metadata.imageProvider = NSItemProvider(object: image)
            metadata.iconProvider = NSItemProvider(object: image)
        }
        
        return metadata
    }
    
    // 分享主题
    func activityViewController(_ activityViewController: UIActivityViewController, subjectForActivityType activityType: UIActivity.ActivityType?) -> String {
        return title
    }
}

// MARK: - 任务图片分享项（用于微信等需要图片的场景）
class TaskImageShareItem: NSObject, UIActivityItemSource {
    let image: UIImage
    
    init(image: UIImage) {
        self.image = image
        super.init()
    }
    
    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        return image
    }
    
    func activityViewController(_ activityViewController: UIActivityViewController, itemForActivityType activityType: UIActivity.ActivityType?) -> Any? {
        return image
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
                    
                    // 评价列表（只显示当前用户自己的评价）
                    let userReviews = viewModel.reviews.filter { review in
                        guard let currentUserId = appState.currentUser?.id else { return false }
                        return String(review.reviewerId) == currentUserId
                    }
                    if !userReviews.isEmpty {
                        TaskReviewsSection(reviews: userReviews)
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
        ZStack(alignment: .bottom) {
            if !images.isEmpty {
                TabView(selection: $selectedIndex) {
                    ForEach(Array(images.enumerated()), id: \.offset) { index, imageUrl in
                        TaskImageView(imageUrl: imageUrl, index: index, selectedIndex: $selectedIndex, showFullScreen: $showFullScreen)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(height: 300) // 略微增加高度
                
                // 自定义指示器 (符合 HIG)
                if images.count > 1 {
                    HStack(spacing: 6) {
                        ForEach(0..<images.count, id: \.self) { index in
                            Capsule()
                                .fill(selectedIndex == index ? Color.white : Color.white.opacity(0.4))
                                .frame(width: selectedIndex == index ? 16 : 6, height: 6)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .padding(.bottom, 24) // 避开下方卡片的圆角
                }
            } else {
                // 无图片时显示更美观的占位图
                ZStack {
                    Rectangle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [AppColors.primary.opacity(0.15), AppColors.primary.opacity(0.05)]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    VStack(spacing: AppSpacing.md) {
                        IconStyle.icon("photo.on.rectangle.angled", size: 60)
                            .foregroundColor(AppColors.primary.opacity(0.3))
                        Text(LocalizationKey.taskDetailNoTaskImages.localized)
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.textTertiary)
                    }
                }
                .frame(height: 300)
            }
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
        AsyncImageView(
            urlString: imageUrl,
            placeholder: Image(systemName: "photo.fill")
        )
        .aspectRatio(contentMode: .fill)
        .frame(height: 300)
        .frame(maxWidth: .infinity)
        .clipped()
        .contentShape(Rectangle())
        .onTapGesture {
            selectedIndex = index
            showFullScreen = true
        }
    }
}

// MARK: - 任务头部卡片
struct TaskHeaderCard: View {
    let task: Task
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            // 状态和等级标签行
            HStack {
                HStack(spacing: AppSpacing.sm) {
                    if let taskLevel = task.taskLevel, taskLevel != "normal" {
                        Label(
                            taskLevel == "vip" ? LocalizationKey.taskDetailVipTask.localized : LocalizationKey.taskDetailSuperTask.localized,
                            systemImage: taskLevel == "vip" ? "star.fill" : "flame.fill"
                        )
                        .font(AppTypography.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(taskLevel == "vip" ? Color.orange : Color.purple)
                        .clipShape(Capsule())
                    }
                    
                    StatusBadge(status: task.status)
                }
                
                Spacer()
                
                // 分享/收藏等快速操作按钮（如有需要可添加）
            }
            
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Text(task.title)
                    .font(AppTypography.title)
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                
                // 价格和积分
                TaskRewardView(task: task)
            }
            
            // 分类和位置标签（位置模糊显示，只显示城市）
            HStack(spacing: AppSpacing.sm) {
                Label(task.taskType, systemImage: "tag.fill")
                    .font(AppTypography.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.primary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(AppColors.primaryLight)
                    .clipShape(Capsule())
                
                Label(task.location.obfuscatedLocation, systemImage: task.location.lowercased() == "online" ? "globe" : "mappin.circle.fill")
                    .font(AppTypography.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.textSecondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(AppColors.background)
                    .clipShape(Capsule())
            }
        }
        .padding(AppSpacing.lg)
        .background(AppColors.cardBackground)
        .cornerRadius(AppCornerRadius.xlarge, corners: [.topLeft, .topRight])
        .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: -5)
    }
}

// MARK: - 任务奖励视图
struct TaskRewardView: View {
    let task: Task
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            if task.reward > 0 {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("£")
                        .font(AppTypography.title3)
                        .fontWeight(.bold)
                    Text(formatPrice(task.reward))
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                }
                .foregroundColor(AppColors.primary)
            }
            
            if let pointsReward = task.pointsReward, pointsReward > 0 {
                HStack(spacing: 4) {
                    IconStyle.icon("star.circle.fill", size: 16)
                    Text("\(pointsReward) 积分")
                        .font(AppTypography.bodyBold)
                }
                .foregroundColor(.orange)
                .padding(.bottom, 4)
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
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            // 描述
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                HStack {
                    IconStyle.icon("text.alignleft", size: 18)
                        .foregroundColor(AppColors.primary)
                    Text(LocalizationKey.taskDetailTaskDescription.localized)
                        .font(AppTypography.title3)
                        .foregroundColor(AppColors.textPrimary)
                }
                
                Text(task.description)
                    .font(AppTypography.body)
                    .foregroundColor(AppColors.textSecondary)
                    .lineSpacing(6)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Divider()
                .background(AppColors.divider)
            
            // 时间信息
            TaskTimeInfoView(task: task)
            
            // 发布者信息
            if let poster = task.poster {
                Divider()
                    .background(AppColors.divider)
                
                TaskPosterInfoView(poster: poster)
            }
        }
        .padding(AppSpacing.lg)
        .background(AppColors.cardBackground)
        .cornerRadius(AppCornerRadius.large)
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)
        .padding(.horizontal, AppSpacing.md)
    }
}

// MARK: - 时间信息视图
struct TaskTimeInfoView: View {
    let task: Task
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack {
                IconStyle.icon("clock.fill", size: 18)
                    .foregroundColor(AppColors.primary)
                Text(LocalizationKey.taskDetailTimeInfo.localized)
                    .font(AppTypography.title3)
                    .foregroundColor(AppColors.textPrimary)
            }
            
            VStack(spacing: AppSpacing.md) {
                HStack(spacing: AppSpacing.md) {
                    Circle()
                        .fill(AppColors.primary.opacity(0.1))
                        .frame(width: 36, height: 36)
                        .overlay(
                            IconStyle.icon("paperplane.fill", size: 14)
                                .foregroundColor(AppColors.primary)
                        )
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(LocalizationKey.taskDetailPublishTime.localized)
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.textSecondary)
                        Text(DateFormatterHelper.shared.formatTime(task.createdAt))
                            .font(AppTypography.body)
                            .fontWeight(.medium)
                            .foregroundColor(AppColors.textPrimary)
                    }
                    
                    Spacer()
                }
                
                if let deadline = task.deadline {
                    HStack(spacing: AppSpacing.md) {
                        Circle()
                            .fill(AppColors.error.opacity(0.1))
                            .frame(width: 36, height: 36)
                            .overlay(
                                IconStyle.icon("calendar.badge.exclamationmark", size: 14)
                                    .foregroundColor(AppColors.error)
                            )
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(LocalizationKey.taskDetailDeadline.localized)
                                .font(AppTypography.caption)
                                .foregroundColor(AppColors.textSecondary)
                            Text(DateFormatterHelper.shared.formatDeadline(deadline))
                                .font(AppTypography.body)
                                .fontWeight(.medium)
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
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack {
                IconStyle.icon("person.fill", size: 18)
                    .foregroundColor(AppColors.primary)
                Text(LocalizationKey.taskDetailPublisher.localized)
                    .font(AppTypography.title3)
                    .foregroundColor(AppColors.textPrimary)
            }
            
            NavigationLink(destination: UserProfileView(userId: poster.id)) {
                HStack(spacing: 12) {
                    ZStack {
                        AvatarView(
                            urlString: poster.avatar,
                            size: 52,
                            placeholder: Image(systemName: "person.fill")
                        )
                        .clipShape(Circle())
                        
                        Circle()
                            .stroke(AppColors.primary.opacity(0.1), lineWidth: 1)
                            .frame(width: 58, height: 58)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text(poster.name)
                                .font(AppTypography.bodyBold)
                                .foregroundColor(AppColors.textPrimary)
                            
                            if let userLevel = poster.userLevel {
                                Text(userLevel.uppercased())
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(AppColors.warning)
                                    .clipShape(Capsule())
                            }
                        }
                        
                        Text(poster.email ?? LocalizationKey.taskDetailEmailNotProvided.localized)
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.textSecondary)
                    }
                    
                    Spacer()
                    
                    IconStyle.icon("chevron.right", size: 14)
                        .foregroundColor(AppColors.textQuaternary)
                }
                .padding(AppSpacing.sm)
                .background(AppColors.background.opacity(0.5))
                .cornerRadius(AppCornerRadius.medium)
            }
            .buttonStyle(ScaleButtonStyle())
        }
    }
}

// MARK: - 发布者提示卡片
struct PosterInfoCard: View {
    var body: some View {
        HStack(spacing: AppSpacing.md) {
            IconStyle.icon("info.circle.fill", size: 24)
                .foregroundColor(AppColors.primary)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(LocalizationKey.taskDetailYourTask.localized)
                    .font(AppTypography.bodyBold)
                    .foregroundColor(AppColors.textPrimary)
                
                Text(LocalizationKey.taskDetailManageTask.localized)
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textSecondary)
            }
            
            Spacer()
        }
        .padding(AppSpacing.md)
        .background(AppColors.primaryLight)
        .cornerRadius(AppCornerRadius.medium)
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
        VStack(spacing: AppSpacing.md) {
            // 申请按钮或状态显示
            if !isPoster {
                // 如果用户已申请，无论任务状态如何，都显示申请状态卡片
                if let userApp = viewModel.userApplication {
                    ApplicationStatusCard(application: userApp, task: task)
                }
                // 如果用户未申请，且任务状态为 open 且没有接受者，显示申请按钮
                else if task.status == .open && task.takerId == nil {
                    Button(action: {
                        if appState.isAuthenticated {
                            showApplySheet = true
                        } else {
                            showLogin = true
                        }
                    }) {
                        Label(LocalizationKey.actionsApplyForTask.localized, systemImage: "hand.raised.fill")
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }
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
                                .tint(.white)
                        } else {
                            IconStyle.icon("checkmark.circle.fill", size: 20)
                        }
                        Text(actionLoading ? LocalizationKey.actionsProcessing.localized : LocalizationKey.actionsMarkComplete.localized)
                    }
                }
                .buttonStyle(PrimaryButtonStyle(useGradient: false))
                .tint(AppColors.success)
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
                                .tint(.white)
                        } else {
                            IconStyle.icon("checkmark.seal.fill", size: 20)
                        }
                        Text(actionLoading ? LocalizationKey.actionsProcessing.localized : LocalizationKey.actionsConfirmComplete.localized)
                    }
                }
                .buttonStyle(PrimaryButtonStyle(useGradient: false))
                .tint(AppColors.success)
                .disabled(actionLoading)
            }
            
            // 沟通按钮
            if (task.status == .inProgress || task.status == .pendingConfirmation) && (isPoster || isTaker) {
                NavigationLink(destination: TaskChatView(taskId: taskId, taskTitle: task.title)) {
                    Label(isPoster ? LocalizationKey.actionsContactRecipient.localized : LocalizationKey.actionsContactPoster.localized, systemImage: "message.fill")
                        .font(AppTypography.bodyBold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(AppColors.primary)
                        .cornerRadius(AppCornerRadius.medium)
                }
                .buttonStyle(ScaleButtonStyle())
            }
            
            // 评价按钮
            if canReview && !hasReviewed {
                Button(action: {
                    showReviewModal = true
                }) {
                    Label(LocalizationKey.actionsRateTask.localized, systemImage: "star.fill")
                }
                .buttonStyle(PrimaryButtonStyle(useGradient: false))
                .tint(AppColors.warning)
            }
            
            // 取消按钮 (次要操作)
            if (isPoster || isTaker) && (task.status == .open || task.status == .inProgress) {
                Button(action: {
                    showCancelConfirm = true
                }) {
                    Label(LocalizationKey.actionsCancelTask.localized, systemImage: "xmark.circle")
                        .font(AppTypography.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(AppColors.error)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(ScaleButtonStyle())
            }
        }
        .padding(.vertical, AppSpacing.sm)
    }
}

// MARK: - 任务评价区域
struct TaskReviewsSection: View {
    let reviews: [Review]
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text(LocalizationKey.taskDetailMyReviews.localized)
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
                Text(review.isAnonymous == true ? LocalizationKey.taskDetailAnonymousUser.localized : (review.reviewer?.name ?? LocalizationKey.taskDetailUnknownUser.localized))
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
            ZStack {
                AppColors.background
                    .ignoresSafeArea()
                
                KeyboardAvoidingScrollView(extraPadding: 20) {
                    VStack(spacing: AppSpacing.xl) {
                        // 1. 申请信息
                        VStack(alignment: .leading, spacing: AppSpacing.md) {
                            SectionHeader(title: "申请信息", icon: "pencil.line")
                            
                            EnhancedTextEditor(
                                title: nil,
                                placeholder: "简单说明您的优势或如何完成任务...",
                                text: $message,
                                height: 120,
                                characterLimit: 500
                            )
                        }
                        .padding(AppSpacing.md)
                        .background(AppColors.cardBackground)
                        .cornerRadius(AppCornerRadius.large)
                        .shadow(color: Color.black.opacity(0.03), radius: 10, x: 0, y: 4)
                        
                        // 2. 价格协商
                        if let task = task, task.isMultiParticipant != true {
                            VStack(alignment: .leading, spacing: AppSpacing.md) {
                                SectionHeader(title: "价格协商", icon: "dollarsign.circle.fill")
                                
                                Toggle(isOn: $showNegotiatePrice) {
                                    HStack {
                                        Text("我想要协商价格")
                                            .font(AppTypography.body)
                                            .foregroundColor(AppColors.textPrimary)
                                        Spacer()
                                    }
                                }
                                .tint(AppColors.primary)
                                .padding(.horizontal, 4)
                                .onChange(of: showNegotiatePrice) { isOn in
                                    if isOn {
                                        negotiatedPrice = task.baseReward ?? task.reward
                                    } else {
                                        negotiatedPrice = nil
                                    }
                                }
                                
                                if showNegotiatePrice {
                                    EnhancedNumberField(
                                        title: "期望金额",
                                        placeholder: "0.00",
                                        value: $negotiatedPrice,
                                        prefix: "£",
                                        isRequired: true
                                    )
                                    .transition(.opacity.combined(with: .move(edge: .top)))
                                    
                                    Text("提示: 协商价格可能会影响发布者的选择哦。")
                                        .font(AppTypography.caption)
                                        .foregroundColor(AppColors.textTertiary)
                                        .padding(.horizontal, 4)
                                }
                            }
                            .padding(AppSpacing.md)
                            .background(AppColors.cardBackground)
                            .cornerRadius(AppCornerRadius.large)
                            .shadow(color: Color.black.opacity(0.03), radius: 10, x: 0, y: 4)
                        }
                        
                        // 提交按钮
                        Button(action: {
                            HapticFeedback.success()
                            onApply()
                        }) {
                            HStack(spacing: 8) {
                                IconStyle.icon("hand.raised.fill", size: 18)
                                Text("提交申请")
                                    .font(AppTypography.bodyBold)
                            }
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .padding(.top, AppSpacing.lg)
                    }
                    .padding(AppSpacing.md)
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
            return task.status == .pendingConfirmation ? Color.purple : AppColors.success
        case "rejected":
            return AppColors.error
        default:
            return AppColors.textSecondary
        }
    }
    
    private var statusText: String {
        switch application.status {
        case "pending":
            return LocalizationKey.taskDetailWaitingReview.localized
        case "approved":
            return task.status == .pendingConfirmation ? LocalizationKey.taskDetailTaskCompleted.localized : LocalizationKey.taskDetailApplicationApproved.localized
        case "rejected":
            return LocalizationKey.taskDetailApplicationRejected.localized
        default:
            return LocalizationKey.taskDetailUnknownStatus.localized
        }
    }
    
    private var statusDescription: String {
        switch application.status {
        case "pending":
            return LocalizationKey.taskDetailApplicationSuccess.localized
        case "approved":
            return task.status == .pendingConfirmation
                ? LocalizationKey.taskDetailTaskCompletedMessage.localized
                : LocalizationKey.taskDetailApplicationApprovedMessage.localized
        case "rejected":
            return LocalizationKey.taskDetailApplicationRejectedMessage.localized
        default:
            return ""
        }
    }
    
    var body: some View {
        HStack(spacing: AppSpacing.md) {
            ZStack {
                Circle()
                    .fill(statusColor.opacity(0.15))
                    .frame(width: 48, height: 48)
                
                IconStyle.icon(statusIcon, size: 24)
                    .foregroundColor(statusColor)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(statusText)
                    .font(AppTypography.title3)
                    .foregroundColor(statusColor)
                
                Text(statusDescription)
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textSecondary)
                    .lineLimit(2)
                
                if let message = application.message, !message.isEmpty {
                    Text(LocalizationKey.taskDetailMessageLabel.localized(argument: message))
                        .font(.system(size: 11))
                        .foregroundColor(AppColors.textTertiary)
                        .padding(.top, 2)
                }
            }
            
            Spacer()
        }
        .padding(AppSpacing.md)
        .background(statusColor.opacity(0.05))
        .cornerRadius(AppCornerRadius.medium)
        .overlay(
            RoundedRectangle(cornerRadius: AppCornerRadius.medium)
                .stroke(statusColor.opacity(0.2), lineWidth: 1)
        )
    }
    
    private var statusIcon: String {
        switch application.status {
        case "pending":
            return "clock.fill"
        case "approved":
            return task.status == .pendingConfirmation ? "checkmark.seal.fill" : "checkmark.circle.fill"
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
            HStack {
                IconStyle.icon("person.2.fill", size: 18)
                    .foregroundColor(AppColors.primary)
                Text(LocalizationKey.taskDetailApplicantsList.localized(argument: applications.count))
                    .font(AppTypography.title3)
                    .foregroundColor(AppColors.textPrimary)
            }
            
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(AppSpacing.xl)
            } else if applications.isEmpty {
                VStack(spacing: AppSpacing.sm) {
                    IconStyle.icon("tray", size: 40)
                        .foregroundColor(AppColors.textQuaternary)
                    Text(LocalizationKey.taskDetailNoApplicants.localized)
                        .font(AppTypography.body)
                        .foregroundColor(AppColors.textTertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(AppSpacing.xl)
                .background(AppColors.background.opacity(0.5))
                .cornerRadius(AppCornerRadius.medium)
            } else {
                VStack(spacing: AppSpacing.md) {
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
        }
    }
}

// 申请项卡片
struct ApplicationItemCard: View {
    let application: TaskApplication
    let taskId: Int
    let taskTitle: String
    let onApprove: () -> Void
    let onReject: () -> Void
    @State private var showMessageSheet = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack {
                AvatarView(
                    urlString: nil, // 假设没有头像
                    size: 40,
                    placeholder: Image(systemName: "person.fill")
                )
                .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(application.applicantName ?? "未知用户")
                        .font(AppTypography.bodyBold)
                        .foregroundColor(AppColors.textPrimary)
                    
                    if let createdAt = application.createdAt {
                        Text(DateFormatterHelper.shared.formatTime(createdAt))
                            .font(AppTypography.caption2)
                            .foregroundColor(AppColors.textTertiary)
                    }
                }
                
                Spacer()
                
                // 状态标签
                Text(statusText)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(statusColor)
                    .clipShape(Capsule())
            }
            
            if let message = application.message, !message.isEmpty {
                Text(message)
                    .font(AppTypography.subheadline)
                    .foregroundColor(AppColors.textSecondary)
                    .padding(AppSpacing.sm)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppColors.background)
                    .cornerRadius(AppCornerRadius.small)
            }
            
            // 操作按钮
            if application.status == "pending" {
                HStack(spacing: AppSpacing.sm) {
                    Button(action: onApprove) {
                        Text(LocalizationKey.actionsApprove.localized)
                            .font(AppTypography.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(AppColors.success)
                            .cornerRadius(AppCornerRadius.small)
                    }
                    .buttonStyle(ScaleButtonStyle())
                    
                    Button(action: onReject) {
                        Text(LocalizationKey.actionsReject.localized)
                            .font(AppTypography.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(AppColors.error)
                            .cornerRadius(AppCornerRadius.small)
                    }
                    .buttonStyle(ScaleButtonStyle())
                    
                    Button(action: {
                        showMessageSheet = true
                    }) {
                        Text("留言")
                            .font(AppTypography.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(AppColors.primary)
                            .cornerRadius(AppCornerRadius.small)
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
            }
        }
        .padding(AppSpacing.md)
        .background(AppColors.cardBackground)
        .cornerRadius(AppCornerRadius.medium)
        .shadow(color: Color.black.opacity(0.03), radius: 5, x: 0, y: 2)
        .sheet(isPresented: $showMessageSheet) {
            ApplicationMessageSheet(
                application: application,
                taskId: taskId,
                taskTitle: taskTitle
            )
        }
    }
    
    private var statusColor: Color {
        switch application.status {
        case "pending": return AppColors.warning
        case "approved": return AppColors.success
        case "rejected": return AppColors.error
        default: return AppColors.textSecondary
        }
    }
    
    private var statusText: String {
        switch application.status {
        case "pending": return LocalizationKey.taskDetailPendingReview.localized
        case "approved": return LocalizationKey.taskDetailApproved.localized
        case "rejected": return LocalizationKey.taskDetailRejected.localized
        default: return ""
        }
    }
}

// 申请留言弹窗
struct ApplicationMessageSheet: View {
    let application: TaskApplication
    let taskId: Int
    let taskTitle: String
    @Environment(\.dismiss) var dismiss
    @State private var message = ""
    @State private var showNegotiatePrice = false
    @State private var negotiatedPrice: Double?
    @State private var isSending = false
    @State private var showError = false
    @State private var errorMessage = ""
    @StateObject private var viewModel = TaskDetailViewModel()
    @State private var cancellables = Set<AnyCancellable>()
    
    var body: some View {
        NavigationView {
            ZStack {
                AppColors.background
                    .ignoresSafeArea()
                
                KeyboardAvoidingScrollView(extraPadding: 20) {
                    VStack(spacing: AppSpacing.xl) {
                        // 留言输入
                        VStack(alignment: .leading, spacing: AppSpacing.md) {
                            SectionHeader(title: "留言内容", icon: "message.fill")
                            
                            TextEditor(text: $message)
                                .font(AppTypography.body)
                                .frame(minHeight: 120)
                                .padding(AppSpacing.sm)
                                .background(AppColors.cardBackground)
                                .cornerRadius(AppCornerRadius.medium)
                                .overlay(
                                    Group {
                                        if message.isEmpty {
                                            Text("给申请者留言...")
                                                .font(AppTypography.body)
                                                .foregroundColor(AppColors.textTertiary)
                                                .padding(.leading, 16)
                                                .padding(.top, 20)
                                                .allowsHitTesting(false)
                                        }
                                    },
                                    alignment: .topLeading
                                )
                        }
                        .padding(AppSpacing.md)
                        .background(AppColors.cardBackground)
                        .cornerRadius(AppCornerRadius.large)
                        
                        // 议价选项
                        VStack(alignment: .leading, spacing: AppSpacing.md) {
                            Toggle(isOn: $showNegotiatePrice) {
                                HStack {
                                    IconStyle.icon("poundsign.circle.fill", size: 18)
                                        .foregroundColor(AppColors.primary)
                                    Text("是否议价")
                                        .font(AppTypography.bodyBold)
                                        .foregroundColor(AppColors.textPrimary)
                                }
                            }
                            .toggleStyle(SwitchToggleStyle(tint: AppColors.primary))
                            
                            if showNegotiatePrice {
                                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                                    Text("议价金额")
                                        .font(AppTypography.caption)
                                        .foregroundColor(AppColors.textSecondary)
                                    
                                    HStack {
                                        Text("£")
                                            .font(AppTypography.bodyBold)
                                            .foregroundColor(AppColors.textPrimary)
                                        
                                        TextField("0.00", value: $negotiatedPrice, format: .number)
                                            .keyboardType(.decimalPad)
                                            .font(AppTypography.bodyBold)
                                            .foregroundColor(AppColors.textPrimary)
                                    }
                                    .padding(AppSpacing.sm)
                                    .background(AppColors.background)
                                    .cornerRadius(AppCornerRadius.small)
                                }
                            }
                        }
                        .padding(AppSpacing.md)
                        .background(AppColors.cardBackground)
                        .cornerRadius(AppCornerRadius.large)
                        
                        // 发送按钮
                        Button(action: sendMessage) {
                            if isSending {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text("发送留言")
                                    .font(AppTypography.bodyBold)
                                    .foregroundColor(.white)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AppSpacing.md)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: AppColors.gradientPrimary),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(AppCornerRadius.medium)
                        .disabled(isSending || message.trimmingCharacters(in: .whitespaces).isEmpty)
                        .opacity(isSending || message.trimmingCharacters(in: .whitespaces).isEmpty ? 0.6 : 1.0)
                    }
                    .padding(AppSpacing.md)
                }
            }
            .navigationTitle("给申请者留言")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
            .alert("发送失败", isPresented: $showError) {
                Button("确定", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .onAppear {
                // 加载任务信息以获取基础价格
                viewModel.loadTask(taskId: taskId)
            }
        }
    }
    
    private func sendMessage() {
        guard !message.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        
        isSending = true
        
        let price = showNegotiatePrice ? negotiatedPrice : nil
        
        APIService.shared.sendApplicationMessage(
            taskId: taskId,
            applicationId: application.id,
            message: message.trimmingCharacters(in: .whitespaces),
            price: price
        )
        .sink(
            receiveCompletion: { [self] result in
                isSending = false
                if case .failure(let error) = result {
                    errorMessage = error.userFriendlyMessage
                    showError = true
                } else {
                    dismiss()
                }
            },
            receiveValue: { _ in }
        )
        .store(in: &cancellables)
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
                "完成质量高", "准时到达", "态度负责", "沟通愉快",
                "专业高效", "值得信赖", "强烈推荐", "非常优秀"
            ]
        } else {
            return [
                "任务描述清晰", "沟通及时", "付款爽快", "要求合理",
                "合作愉快", "强烈推荐", "值得信赖", "非常专业"
            ]
        }
    }
    
    private var ratingText: String {
        switch rating {
        case 1: return "非常差"
        case 2: return "差"
        case 3: return "一般"
        case 4: return "好"
        case 5: return "极好"
        default: return ""
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                AppColors.background
                    .ignoresSafeArea()
                
                KeyboardAvoidingScrollView(extraPadding: 20) {
                    VStack(spacing: AppSpacing.xl) {
                        // 1. 评分
                        VStack(alignment: .leading, spacing: AppSpacing.md) {
                            SectionHeader(title: "整体评价", icon: "star.fill")
                            
                            VStack(spacing: AppSpacing.sm) {
                                HStack(spacing: AppSpacing.md) {
                                    ForEach(1...5, id: \.self) { star in
                                        Button(action: {
                                            rating = star
                                            HapticFeedback.selection()
                                        }) {
                                            IconStyle.icon(star <= rating ? "star.fill" : "star", size: 36)
                                                .foregroundColor(star <= rating ? AppColors.warning : AppColors.textQuaternary)
                                        }
                                    }
                                }
                                
                                Text(ratingText)
                                    .font(AppTypography.bodyBold)
                                    .foregroundColor(AppColors.warning)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, AppSpacing.md)
                        }
                        .padding(AppSpacing.md)
                        .background(AppColors.cardBackground)
                        .cornerRadius(AppCornerRadius.large)
                        .shadow(color: Color.black.opacity(0.03), radius: 10, x: 0, y: 4)
                        
                        // 2. 标签
                        VStack(alignment: .leading, spacing: AppSpacing.md) {
                            SectionHeader(title: "评价标签", icon: "tag.fill")
                            
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
                                        HapticFeedback.light()
                                    }) {
                                        Text(tag)
                                            .font(AppTypography.caption)
                                            .foregroundColor(selectedTags.contains(tag) ? .white : AppColors.textPrimary)
                                            .padding(.horizontal, AppSpacing.sm)
                                            .padding(.vertical, AppSpacing.sm)
                                            .frame(maxWidth: .infinity)
                                            .background(selectedTags.contains(tag) ? AppColors.primary : AppColors.background)
                                            .cornerRadius(AppCornerRadius.small)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: AppCornerRadius.small)
                                                    .stroke(selectedTags.contains(tag) ? Color.clear : AppColors.separator.opacity(0.3), lineWidth: 1)
                                            )
                                    }
                                }
                            }
                        }
                        .padding(AppSpacing.md)
                        .background(AppColors.cardBackground)
                        .cornerRadius(AppCornerRadius.large)
                        .shadow(color: Color.black.opacity(0.03), radius: 10, x: 0, y: 4)
                        
                        // 3. 评价内容
                        VStack(alignment: .leading, spacing: AppSpacing.md) {
                            SectionHeader(title: "评价内容", icon: "square.and.pencil")
                            
                            EnhancedTextEditor(
                                title: nil,
                                placeholder: "写下您的合作感受，帮助其他用户参考...",
                                text: $comment,
                                height: 150,
                                characterLimit: 500
                            )
                            
                            Toggle(isOn: $isAnonymous) {
                                Text("匿名评价")
                                    .font(AppTypography.subheadline)
                                    .foregroundColor(AppColors.textSecondary)
                            }
                            .tint(AppColors.primary)
                            .padding(.top, 4)
                        }
                        .padding(AppSpacing.md)
                        .background(AppColors.cardBackground)
                        .cornerRadius(AppCornerRadius.large)
                        .shadow(color: Color.black.opacity(0.03), radius: 10, x: 0, y: 4)
                        
                        // 提交按钮
                        Button(action: {
                            HapticFeedback.success()
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
                            HStack(spacing: 8) {
                                IconStyle.icon("checkmark.circle.fill", size: 18)
                                Text("提交评价")
                                    .font(AppTypography.bodyBold)
                            }
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .padding(.top, AppSpacing.lg)
                        .padding(.bottom, AppSpacing.xxl)
                    }
                    .padding(AppSpacing.md)
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


