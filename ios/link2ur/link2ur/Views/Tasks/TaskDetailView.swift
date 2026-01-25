import SwiftUI
import UIKit
import LinkPresentation
import Combine
import PhotosUI

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
    @State private var reviewRating: Double = 5.0
    @State private var reviewComment = ""
    @State private var isAnonymousReview = false
    @State private var selectedReviewTags: [String] = []
    @State private var showCancelConfirm = false
    @State private var cancelReason = ""
    @State private var showLogin = false
    @State private var showShareSheet = false
    @State private var shareImage: UIImage?
    @State private var showApplySuccessAlert = false
    @State private var showPaymentView = false
    @State private var paymentClientSecret: String?
    @State private var paymentCustomerId: String?
    @State private var paymentEphemeralKeySecret: String?
    @State private var approvedApplicantName: String?
    @State private var shareImageCancellable: AnyCancellable?
    @State private var isShareImageLoading = false // 分享图片加载状态
    @State private var showConfirmCompletionSuccess = false // 确认完成成功提示
    @State private var showCompleteTaskSheet = false // 显示完成任务页面
    @State private var interactionCancellables = Set<AnyCancellable>()  // 用于交互记录的 cancellables
    @State private var lastInteractionType: String? = nil  // 上次交互类型（用于防抖）
    @State private var lastInteractionTime: Date? = nil  // 上次交互时间
    @State private var viewStartTime: Date? // 增强：记录任务详情页查看开始时间（用于计算浏览时长）
    @State private var retryWorkItem: DispatchWorkItem? // 用于取消递归重试任务
    
    // 判断当前用户是否是任务发布者
    // ⚠️ 重要：确保类型比较正确
    private var isPoster: Bool {
        guard let task = viewModel.task,
              let currentUserId = appState.currentUser?.id,
              let posterId = task.posterId else {
            return false
        }
        // posterId 和 currentUserId 都是 String 类型，直接比较
        return posterId == currentUserId
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
              let currentUserId = appState.currentUser?.id else {
            return false
        }
        
        // 任务必须已完成
        guard task.status == .completed else {
            return false
        }
        
        // 单人任务：发布者或接受者可以评价
        if task.isMultiParticipant != true {
            return isPoster || isTaker
        }
        
        // 多人任务：参与者可以评价达人创建者
        // 检查是否是参与者（通过originatingUserId或TaskParticipant）
        // 注意：iOS端可能没有完整的参与者列表，这里先检查基本条件
        // 如果用户是originatingUserId（第一个申请者）或takerId（达人），可以评价
        if let originatingUserId = task.originatingUserId, String(originatingUserId) == currentUserId {
            return true  // 第一个申请者可以评价
        }
        if isTaker {
            return true  // 达人可以评价（虽然通常达人评价参与者，但这里先允许）
        }
        // 对于其他参与者，后端会验证，这里暂时允许（后端会最终验证）
        // 如果任务在"我的任务"中显示，说明用户是参与者
        return true  // 后端会最终验证用户是否是参与者
    }
    
    // 判断是否已评价
    private var hasReviewed: Bool {
        guard let currentUserId = appState.currentUser?.id else {
            return false
        }
        // reviewerId 和 currentUserId 都是 String 类型，直接比较
        return viewModel.reviews.contains { review in
            review.reviewerId == currentUserId
        }
    }
    
    @ViewBuilder
    private var contentView: some View {
        ZStack {
            AppColors.background
                .ignoresSafeArea()
            
            if viewModel.isLoading && viewModel.task == nil {
                LoadingView()
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
                    showPaymentView: $showPaymentView,
                    paymentClientSecret: $paymentClientSecret,
                    paymentCustomerId: $paymentCustomerId,
                    paymentEphemeralKeySecret: $paymentEphemeralKeySecret,
                    approvedApplicantName: $approvedApplicantName,
                    showConfirmCompletionSuccess: $showConfirmCompletionSuccess,
                    showCompleteTaskSheet: $showCompleteTaskSheet,
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
                toolbarContent
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
                shareSheetContent
            }
            .sheet(isPresented: $showPaymentView) {
                paymentSheetContent
            }
            .sheet(isPresented: $showCompleteTaskSheet) {
                completeTaskSheet
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
            }
            .alert(LocalizationKey.taskDetailConfirmCompletionSuccess.localized, isPresented: $showConfirmCompletionSuccess) {
                Button(LocalizationKey.commonOk.localized, role: .cancel) {
                    showConfirmCompletionSuccess = false
                }
            } message: {
                Text(LocalizationKey.taskDetailConfirmCompletionSuccessMessage.localized)
            }
            .sheet(isPresented: $showLogin) {
                LoginView()
            }
            .onAppear {
                // 优化：只在首次加载或任务ID变化时加载
                if viewModel.task?.id != taskId {
                    viewModel.loadTask(taskId: taskId)
                }
                
                // 增强：记录任务查看开始时间（用于计算浏览时长）
                viewStartTime = Date()
            }
            .onDisappear {
                // 取消所有待执行的重试任务，防止View销毁后仍执行任务
                retryWorkItem?.cancel()
                retryWorkItem = nil
                
                // 增强：计算浏览时长并记录（用于推荐系统学习）
                if let startTime = viewStartTime {
                    let duration = Int(Date().timeIntervalSince(startTime))
                    if duration > 0 {
                        recordTaskInteraction(type: "view", duration: duration)
                    }
                }
            }
            .onChange(of: viewModel.task?.id) { newTaskId in
                // 优化：只在任务ID确实变化且不为nil时处理
                guard let newTaskId = newTaskId, newTaskId == taskId else { return }
                handleTaskChange()
                // 优化：不在任务加载时立即加载分享图片，延迟到用户点击分享时再加载
                // loadShareImage() // 延迟加载
            }
            .onChange(of: viewModel.task?.status) { newStatus in
                // 优化：只在状态确实变化时处理
                guard newStatus != nil else { return }
                // 只在特定状态变化时重新加载申请列表
                if newStatus == .open || newStatus == .inProgress {
                    handleTaskChange()
                }
            }
    }
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
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
    
    @ViewBuilder
    private var shareSheetContent: some View {
        if let task = viewModel.task, !task.displayDescription.isEmpty {
            // 确保任务数据完整后再显示分享视图
            TaskShareSheet(
                task: task,
                taskId: taskId,
                shareImage: shareImage,
                isShareImageLoading: isShareImageLoading
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .onAppear {
                // 当分享面板出现时，开始加载图片（如果还没有加载）
                if shareImage == nil && !isShareImageLoading {
                    loadShareImage()
                }
            }
        } else {
            // 如果任务数据未就绪，显示加载状态
            VStack(spacing: AppSpacing.lg) {
                CompactLoadingView()
                Text(LocalizationKey.commonLoading.localized)
                    .font(AppTypography.body)
                    .foregroundColor(AppColors.textSecondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .presentationDetents([.medium])
        }
    }
    
    @ViewBuilder
    private var paymentSheetContent: some View {
        if let task = viewModel.task {
            // 计算需要支付的金额（任务金额，后端会计算最终金额，包括积分和优惠券抵扣）
            let paymentAmount = task.agreedReward ?? task.baseReward ?? task.reward
            let applicantName = approvedApplicantName ?? viewModel.applications.first { $0.status == "approved" }?.applicantName
            
            StripePaymentView(
                taskId: taskId,
                amount: paymentAmount,
                clientSecret: paymentClientSecret,
                customerId: paymentCustomerId,
                ephemeralKeySecret: paymentEphemeralKeySecret,
                taskTitle: task.title,
                applicantName: applicantName,
                onPaymentSuccess: {
                    // 支付成功后的回调
                    // 清除 client_secret 和申请者名字
                    paymentClientSecret = nil
                    paymentCustomerId = nil
                    paymentEphemeralKeySecret = nil
                    approvedApplicantName = nil
                    // 关闭支付视图
                    showPaymentView = false
                    // 刷新任务详情（带重试机制）
                    refreshTaskWithRetry(attempt: 1, maxAttempts: 5)
                }
            )
            .onDisappear {
                // 清除 client_secret 和申请者名字（如果还没清除）
                paymentClientSecret = nil
                paymentCustomerId = nil
                paymentEphemeralKeySecret = nil
                approvedApplicantName = nil
            }
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
                            // 记录申请交互（用于推荐系统）
                            recordTaskInteraction(type: "apply")
                            // 发送任务更新通知，触发推荐任务实时刷新
                            NotificationCenter.default.post(name: .taskUpdated, object: viewModel.task)
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
    private var completeTaskSheet: some View {
        if let task = viewModel.task {
            CompleteTaskSheet(
                taskId: taskId,
                task: task,
                onComplete: { evidenceImageUrls in
                    viewModel.completeTask(taskId: taskId, evidenceImages: evidenceImageUrls.isEmpty ? nil : evidenceImageUrls) { success in
                        if success {
                            showCompleteTaskSheet = false
                            viewModel.loadTask(taskId: taskId)
                            HapticFeedback.success()
                            // 注意：系统消息已由后端自动发送，不需要前端再次发送
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
                    rating: reviewRating,
                    comment: reviewComment.isEmpty ? nil : reviewComment,
                    isAnonymous: isAnonymousReview
                ) { success in
                    if success {
                        showReviewModal = false
                        reviewRating = 5.0
                        reviewComment = ""
                        isAnonymousReview = false
                        selectedReviewTags = []
                        // 立即重新加载评价列表，以更新 hasReviewed 状态并隐藏评价按钮
                        DispatchQueue.main.async {
                            viewModel.loadReviews(taskId: taskId)
                            // 也重新加载任务详情，确保状态同步
                            viewModel.loadTask(taskId: taskId)
                        }
                        HapticFeedback.success()
                    }
                    // 错误信息已通过ErrorHandler统一显示，不需要在这里额外处理
                    // 如果失败，保持弹窗打开，让用户可以看到错误并重试
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
    
    /// 记录任务交互（用于推荐系统，带防抖和异步优化）
    private func recordTaskInteraction(type: String, duration: Int? = nil) {
        guard appState.isAuthenticated else { return }
        
        // 防抖：相同类型的交互在1秒内只记录一次
        let now = Date()
        if let lastType = lastInteractionType,
           let lastTime = lastInteractionTime,
           lastType == type,
           now.timeIntervalSince(lastTime) < 1.0 {
            Logger.debug("跳过重复交互记录: type=\(type)", category: .api)
            return
        }
        
        lastInteractionType = type
        lastInteractionTime = now
        
        let task = viewModel.task
        let isRecommended = task?.isRecommended == true
        
        // 获取设备类型
        let deviceType = DeviceInfo.isPad ? "tablet" : "mobile"
        
        // 构建 metadata
        var metadata: [String: Any] = [
            "source": "task_detail",
            "list_position": 0  // 详情页没有位置概念
        ]
        
        if let matchScore = task?.matchScore {
            metadata["match_score"] = matchScore
        }
        if let recommendationReason = task?.recommendationReason {
            metadata["recommendation_reason"] = recommendationReason
        }
        
        // 异步非阻塞方式记录交互（不等待结果，不影响用户体验）
        // 注意：TaskDetailView 是 struct，不需要 weak 引用
        let currentTaskId = taskId
        DispatchQueue.global(qos: .utility).async {
            // 调用 API 记录交互
            // 使用 AnyCancellable 来保持订阅活跃，直到请求完成
            var cancellable: AnyCancellable?
            cancellable = APIService.shared.recordTaskInteraction(
                taskId: currentTaskId,
                interactionType: type,
                durationSeconds: duration, // 增强：传递浏览时长
                deviceType: deviceType,
                isRecommended: isRecommended,
                metadata: metadata
            )
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        Logger.warning("记录任务交互失败: \(error.localizedDescription)", category: .api)
                    }
                    // 请求完成后，释放 cancellable
                    cancellable = nil
                },
                receiveValue: { _ in
                    Logger.debug("已记录任务交互: type=\(type), taskId=\(currentTaskId)", category: .api)
                }
            )
            // 保持 cancellable 活跃直到请求完成
            _ = cancellable
        }
    }
    
    private func handleTaskChange() {
        // 优化：当任务加载完成后，加载申请列表和评价
        guard let task = viewModel.task else { return }
        
        // 优化：避免重复加载，检查是否已有数据
        let shouldLoadApplications = (isPoster && task.status == .open) || 
                                     (appState.currentUser != nil && viewModel.applications.isEmpty)
        
        if shouldLoadApplications {
            viewModel.loadApplications(taskId: taskId, currentUserId: appState.currentUser?.id)
        }
        
        // 优化：只在评价列表为空时加载
        if viewModel.reviews.isEmpty {
            viewModel.loadReviews(taskId: taskId)
        }
    }
    
    // 优化：延迟加载分享图片，只在需要时加载
    private func loadShareImage() {
        guard let task = viewModel.task,
              let images = task.images,
              let firstImage = images.first,
              !firstImage.isEmpty else {
            shareImage = nil
            isShareImageLoading = false
            return
        }
        
        // 如果图片已经加载，不需要重新加载
        if shareImage != nil {
            return
        }
        
        // 取消之前的加载
        shareImageCancellable?.cancel()
        isShareImageLoading = true
        
        // 使用 ImageCache 加载图片，支持缓存和优化
        shareImageCancellable = ImageCache.shared.loadImage(from: firstImage)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    self.isShareImageLoading = false
                    if case .failure = completion {
                        // 图片加载失败，不影响分享功能
                        self.shareImage = nil
                    }
                },
                receiveValue: { image in
                    self.shareImage = image
                    self.isShareImageLoading = false
                }
            )
    }
    
    
    /// 刷新任务详情，带重试机制（优化版）
    /// 由于 webhook 是异步处理的，可能需要多次尝试才能获取到更新后的状态
    private func refreshTaskWithRetry(attempt: Int, maxAttempts: Int) {
        guard attempt <= maxAttempts else {
            return
        }
        
        // 取消之前的重试任务（如果存在）
        retryWorkItem?.cancel()
        
        // 优化：使用指数退避策略，减少不必要的请求
        let delay = min(Double(attempt * attempt), 10.0) // 最大延迟10秒
        let currentTaskId = taskId
        
        let workItem = DispatchWorkItem { [weak viewModel, weak appState] in
            guard let viewModel = viewModel else { return }
            
            viewModel.loadTask(taskId: currentTaskId)
            
            // 检查任务状态是否已更新
            if let task = viewModel.task,
               task.status == .inProgress || task.status == .pendingConfirmation {
                // 状态已更新，停止重试
                viewModel.loadApplications(taskId: currentTaskId, currentUserId: appState?.currentUser?.id)
                return
            }
            
            // 如果还没更新，继续重试
            if attempt < maxAttempts {
                // 递归调用，创建下一个重试任务
                let nextDelay = min(Double((attempt + 1) * (attempt + 1)), 10.0)
                let nextWorkItem = DispatchWorkItem { [weak viewModel, weak appState] in
                    guard let viewModel = viewModel else { return }
                    viewModel.loadTask(taskId: currentTaskId)
                    
                    if let task = viewModel.task,
                       task.status == .inProgress || task.status == .pendingConfirmation {
                        viewModel.loadApplications(taskId: currentTaskId, currentUserId: appState?.currentUser?.id)
                    } else if attempt + 1 < maxAttempts {
                        // 继续递归重试
                        DispatchQueue.main.async {
                            self.refreshTaskWithRetry(attempt: attempt + 2, maxAttempts: maxAttempts)
                        }
                    }
                }
                // 在主线程更新retryWorkItem并安排执行
                // 注意：struct 是值类型，不需要 weak self
                DispatchQueue.main.async {
                    self.retryWorkItem = nextWorkItem
                    DispatchQueue.main.asyncAfter(deadline: .now() + nextDelay, execute: nextWorkItem)
                }
            }
        }
        
        retryWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }
}

// MARK: - 任务分享视图
struct TaskShareSheet: View {
    let task: Task
    let taskId: Int
    let shareImage: UIImage?
    let isShareImageLoading: Bool
    @Environment(\.dismiss) var dismiss
    
    // 使用 @State 确保描述在视图更新时正确传递
    @State private var shareDescription: String = ""
    
    // 使用前端网页 URL，确保微信能抓取到正确的 meta 标签（weixin:title, weixin:description, weixin:image）
    // 前端页面已经设置了这些标签，微信会直接抓取
    private var shareUrl: URL {
        // 使用前端域名，确保微信能抓取到正确的 meta 标签
        // 使用固定版本号（v=3 绕过微信缓存）
        let urlString = "https://www.link2ur.com/zh/tasks/\(taskId)?v=2"
        if let url = URL(string: urlString) {
            return url
        }
        // 如果URL构建失败，返回默认URL
        return URL(string: "https://www.link2ur.com")!
    }
    
    // 计算属性：确保描述始终是最新的
    private var currentDescription: String {
        // 优先使用 @State 中的值，如果为空则使用 task.displayDescription
        return shareDescription.isEmpty ? task.displayDescription : shareDescription
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
                } else if isShareImageLoading {
                    // 图片加载中
                    ZStack {
                        RoundedRectangle(cornerRadius: AppCornerRadius.medium)
                            .fill(AppColors.cardBackground)
                            .frame(height: 150)
                        
                        VStack(spacing: AppSpacing.sm) {
                            CompactLoadingView()
                            Text(LocalizationKey.commonLoadingImage.localized)
                                .font(AppTypography.caption)
                                .foregroundColor(AppColors.textSecondary)
                        }
                    }
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
                    Text(task.displayTitle)
                        .font(AppTypography.bodyBold)
                        .foregroundColor(AppColors.textPrimary)
                        .lineLimit(2)
                    
                    if !currentDescription.isEmpty {
                        Text(currentDescription)
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
            
            // 自定义分享面板（类似小红书）
            CustomSharePanel(
                title: task.title,
                description: currentDescription,
                url: shareUrl,
                image: shareImage,
                taskType: task.taskType,
                location: task.location.lowercased() == "online" 
                    ? (LocalizationHelper.currentLanguage.hasPrefix("zh") ? "线上" : "Online")
                    : task.location.obfuscatedLocation,
                reward: {
                    let currencySymbol = task.currency == "GBP" ? "£" : "¥"
                    return "\(currencySymbol)\(String(format: "%.0f", task.reward))"
                }(),
                onDismiss: {
                    dismiss()
                }
            )
            .padding(.top, AppSpacing.md)
        }
        .background(AppColors.background)
        .onAppear {
            // 确保在视图出现时更新描述
            shareDescription = task.description
        }
        .onChange(of: task.displayDescription) { newDescription in
            // 当任务描述更新时，同步更新分享描述
            shareDescription = newDescription
        }
    }
}

// MARK: - 任务分享内容提供者
class TaskShareItem: NSObject, UIActivityItemSource {
    let url: URL
    let title: String
    let descriptionText: String
    let taskType: String
    let location: String
    let reward: String
    let image: UIImage?
    
    init(url: URL, title: String, description: String, taskType: String, location: String, reward: String, image: UIImage?) {
        self.url = url
        self.title = title
        self.descriptionText = description
        self.taskType = taskType
        self.location = location
        self.reward = reward
        self.image = image
        super.init()
    }
    
    // 占位符 - 返回URL，让微信知道这是一个链接分享
    // 微信会尝试抓取这个URL的meta标签（weixin:title, weixin:description, weixin:image等）
    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        return url
    }
    
    // 实际分享的内容 - 参考小红书做法：主要返回URL，让微信抓取网页的meta标签
    func activityViewController(_ activityViewController: UIActivityViewController, itemForActivityType activityType: UIActivity.ActivityType?) -> Any? {
        // 检测是否是微信（使用统一的工具方法）
        if ShareHelper.isWeChatShare(activityType) {
            // 微信分享：返回URL，让微信自动抓取网页的 weixin:title, weixin:description, weixin:image 等标签
            // 前端已经设置好了这些标签，微信会生成漂亮的分享卡片
            return url
        }
        
        // 对于邮件应用，返回 URL 以便显示为链接
        // 邮件应用支持 LPLinkMetadata，会调用 activityViewControllerLinkMetadata 获取富媒体预览
        if activityType == .mail {
            return url
        }
        
        // 对于其他支持 LPLinkMetadata 的应用（如 iMessage），返回 URL
        // 系统会调用 activityViewControllerLinkMetadata 获取富媒体预览
        if activityType == nil {
            // nil 通常表示 iMessage 等原生应用
            return url
        }
        
        // 对于不支持 LPLinkMetadata 的应用（如复制、短信等），返回包含完整详情的文本
        let descriptionPreview = descriptionText.prefix(100)
        let descriptionSuffix = descriptionText.count > 100 ? "..." : ""
        let shareText = """
        \(title)
        
        \(descriptionPreview)\(descriptionSuffix)
        
        任务类型: \(taskType)
        地点: \(location)
        金额: \(reward)
        
        立即查看: \(url.absoluteString)
        """
        return shareText
    }
    
    // 提供富链接预览元数据（用于 iMessage 等原生 App）
    func activityViewControllerLinkMetadata(_ activityViewController: UIActivityViewController) -> LPLinkMetadata? {
        // 注意：此方法无法直接检测分享目标类型
        // 微信不支持 LPLinkMetadata，会直接使用 activityViewController 返回的 URL
        // 对于支持 LPLinkMetadata 的应用（如 iMessage、邮件等），返回元数据
        let metadata = LPLinkMetadata()
        
        // 重要：不设置 url 或 originalURL，避免系统尝试自动获取元数据
        // 设置这些属性会导致系统尝试访问URL获取元数据，从而触发沙盒扩展错误
        // 系统会自动从 activityViewController 返回的 URL 中识别链接信息
        // 我们只提供手动设置的元数据（title 和 image），避免网络请求
        
        // 设置标题（这是最重要的，会显示在链接预览中）
        metadata.title = title
        
        // 注意：LPLinkMetadata 在 iOS 16.3+ 中移除了 summary 属性
        // 描述信息会通过网页的 Open Graph 标签提供，或者通过 activityViewController 方法中的文本分享
        
        // 如果有图片，设置为预览图（重要：这会让分享显示图片）
        if let image = image {
            let imageProvider = NSItemProvider(object: image)
            metadata.imageProvider = imageProvider
            metadata.iconProvider = imageProvider
        }
        
        return metadata
    }
    
    // 分享主题
    func activityViewController(_ activityViewController: UIActivityViewController, subjectForActivityType activityType: UIActivity.ActivityType?) -> String {
        return title
    }
}

// MARK: - 任务文本分享项（确保微信能正确读取文本信息）
class TaskTextShareItem: NSObject, UIActivityItemSource {
    let text: String
    
    init(text: String) {
        self.text = text
        super.init()
    }
    
    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        return text
    }
    
    func activityViewController(_ activityViewController: UIActivityViewController, itemForActivityType activityType: UIActivity.ActivityType?) -> Any? {
        // 对于所有应用，都返回包含完整信息的文本
        return text
    }
}

// MARK: - 任务图片分享项（用于微信等需要图片的场景）
class TaskImageShareItem: NSObject, UIActivityItemSource {
    let image: UIImage
    
    init(image: UIImage) {
        // 优化：压缩图片以减少内存占用和分享大小
        // 微信等平台对图片大小有限制，压缩后可以更快分享
        // 使用同步压缩（在初始化时），因为图片已经在内存中，压缩很快
        // 如果图片很大，可以考虑使用异步压缩，但会增加复杂度
        if let compressedImage = image.compressedForSharing() {
            self.image = compressedImage
        } else {
            // 如果压缩失败，使用原图（不应该发生，但作为后备）
            self.image = image
        }
        super.init()
    }
    
    deinit {
        // 确保图片在释放时及时清理内存
        // UIImage 会自动管理内存，但显式清理可以更快释放
    }
    
    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        return image
    }
    
    func activityViewController(_ activityViewController: UIActivityViewController, itemForActivityType activityType: UIActivity.ActivityType?) -> Any? {
        return image
    }
}

// MARK: - UIImage 扩展：图片压缩优化
extension UIImage {
    /// 压缩图片用于分享（优化内存和文件大小）
    /// - Parameters:
    ///   - maxSize: 最大尺寸（默认1200px，适合大多数分享平台）
    ///   - quality: 压缩质量（0.0-1.0，默认0.8，平衡质量和文件大小）
    /// - Returns: 压缩后的图片，如果压缩失败则返回 nil
    /// - Note: 此方法在主线程执行，对于大图片（>5MB）可能需要几毫秒
    ///         如果需要在后台压缩，使用 compressedForSharingAsync
    func compressedForSharing(maxSize: CGFloat = 1200, quality: CGFloat = 0.8) -> UIImage? {
        // 使用 autoreleasepool 确保及时释放中间对象
        return autoreleasepool {
            // 计算缩放比例
            let ratio = min(maxSize / size.width, maxSize / size.height)
            
            // 如果图片已经小于最大尺寸，直接压缩质量
            if ratio >= 1.0 {
                return compressed(quality: quality)
            }
            
            // 先缩放尺寸（减少内存占用）
            let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)
            UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
            defer { UIGraphicsEndImageContext() }
            
            draw(in: CGRect(origin: .zero, size: newSize))
            guard let resizedImage = UIGraphicsGetImageFromCurrentImageContext() else {
                return nil
            }
            
            // 再压缩质量（减少文件大小）
            return resizedImage.compressed(quality: quality)
        }
    }
    
    /// 异步压缩图片用于分享（在后台队列执行）
    /// - Parameters:
    ///   - maxSize: 最大尺寸（默认1200px）
    ///   - quality: 压缩质量（0.0-1.0，默认0.8）
    ///   - completion: 完成回调，在主线程执行
    /// - Note: 适用于大图片（>5MB）或需要避免阻塞主线程的场景
    func compressedForSharingAsync(maxSize: CGFloat = 1200, quality: CGFloat = 0.8, completion: @escaping (UIImage?) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            let compressed = self.compressedForSharing(maxSize: maxSize, quality: quality)
            DispatchQueue.main.async {
                completion(compressed)
            }
        }
    }
    
    /// 压缩图片质量（JPEG压缩）
    /// - Parameter quality: 压缩质量（0.0-1.0）
    /// - Returns: 压缩后的图片，如果压缩失败则返回 nil
    private func compressed(quality: CGFloat) -> UIImage? {
        guard let imageData = jpegData(compressionQuality: quality) else {
            return nil
        }
        // 限制最大文件大小为 5MB（微信等平台限制）
        let maxDataSize = 5 * 1024 * 1024 // 5MB
        if imageData.count > maxDataSize {
            // 如果仍然太大，降低质量重试
            let adjustedQuality = quality * 0.7
            return jpegData(compressionQuality: adjustedQuality).flatMap { UIImage(data: $0) }
        }
        return UIImage(data: imageData)
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
    @Binding var reviewRating: Double
    @Binding var reviewComment: String
    @Binding var isAnonymousReview: Bool
    @Binding var selectedReviewTags: [String]
    @Binding var showCancelConfirm: Bool
    @Binding var cancelReason: String
    @Binding var showLogin: Bool
    @Binding var showPaymentView: Bool
    @Binding var paymentClientSecret: String?
    @Binding var paymentCustomerId: String?
    @Binding var paymentEphemeralKeySecret: String?
    @Binding var approvedApplicantName: String?
    @Binding var showConfirmCompletionSuccess: Bool
    @Binding var showCompleteTaskSheet: Bool
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
                // 图片轮播区域（过滤掉空或纯空格的 URL，避免占位无效条目）
                TaskImageCarouselView(
                    images: (task.images ?? []).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty },
                    selectedIndex: $selectedImageIndex,
                    showFullScreen: $showFullScreenImage
                )
                
                // 内容区域 - iPad上限制最大宽度并居中
                VStack(spacing: DeviceInfo.isPad ? AppSpacing.lg : AppSpacing.md) {
                    // 标题和状态卡片
                    TaskHeaderCard(task: task)
                    
                    // 任务详情卡片
                    TaskInfoCard(task: task)
                    
                    // 发布者查看自己任务时的提示信息
                    if isPoster && task.status == .open {
                        PosterInfoCard()
                            .padding(.horizontal, DeviceInfo.isPad ? AppSpacing.lg : AppSpacing.md)
                    }
                    
                    // 发布者：申请列表
                    if isPoster && task.status == .open {
                            ApplicationsListView(
                                applications: viewModel.applications,
                                isLoading: viewModel.isLoadingApplications,
                                taskId: taskId,
                                taskTitle: task.displayTitle,
                                onApprove: { applicationId in
                                    actionLoading = true
                                    // 获取申请者名字（在批准前保存）
                                    let application = viewModel.applications.first { $0.id == applicationId }
                                    let applicantName = application?.applicantName
                                    
                                    viewModel.approveApplication(taskId: taskId, applicationId: applicationId) { success, clientSecret, customerId, ephemeralKeySecret in
                                        if success {
                                            // 保存申请者名字
                                            approvedApplicantName = applicantName
                                            
                                            // 如果返回了 client_secret，立即显示支付界面（不等待任务重新加载）
                                            if let clientSecret = clientSecret, !clientSecret.isEmpty {
                                                // 保存 client_secret 并立即显示支付界面
                                                paymentClientSecret = clientSecret
                                                paymentCustomerId = customerId
                                                paymentEphemeralKeySecret = ephemeralKeySecret
                                                
                                                // 立即显示支付界面，不等待
                                                DispatchQueue.main.async {
                                                    actionLoading = false
                                                    showPaymentView = true
                                                }
                                                
                                                // 在后台重新加载任务信息（不阻塞支付界面显示）
                                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                                    viewModel.loadTask(taskId: taskId)
                                                    viewModel.loadApplications(taskId: taskId, currentUserId: appState.currentUser?.id)
                                                }
                                            } else {
                                                // 没有立即返回 client_secret，立即显示支付界面
                                                // StripePaymentView 会自动调用 API 获取支付信息
                                                paymentClientSecret = nil
                                                paymentCustomerId = nil
                                                paymentEphemeralKeySecret = nil
                                                
                                                // 立即显示支付界面，让 StripePaymentView 自动获取支付信息
                                                DispatchQueue.main.async {
                                                    actionLoading = false
                                                    showPaymentView = true
                                                }
                                                
                                                // 在后台重新加载任务信息
                                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                                    viewModel.loadTask(taskId: taskId)
                                                    viewModel.loadApplications(taskId: taskId, currentUserId: appState.currentUser?.id)
                                                }
                                            }
                                        } else {
                                            actionLoading = false
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
                            .padding(.horizontal, DeviceInfo.isPad ? AppSpacing.lg : AppSpacing.md)
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
                        showPaymentView: $showPaymentView,
                        paymentClientSecret: $paymentClientSecret,
                        paymentCustomerId: $paymentCustomerId,
                        paymentEphemeralKeySecret: $paymentEphemeralKeySecret,
                        showConfirmCompletionSuccess: $showConfirmCompletionSuccess,
                        showCompleteTaskSheet: $showCompleteTaskSheet,
                        showNegotiatePrice: $showNegotiatePrice,
                        negotiatedPrice: $negotiatedPrice,
                        taskId: taskId,
                        viewModel: viewModel
                    )
                    .padding(.horizontal, DeviceInfo.isPad ? AppSpacing.lg : AppSpacing.md)
                    
                    // 评价列表（只显示当前用户自己的评价）
                    let userReviews = viewModel.reviews.filter { review in
                        guard let currentUserId = appState.currentUser?.id else { return false }
                        return String(review.reviewerId) == currentUserId
                    }
                    if !userReviews.isEmpty {
                        TaskReviewsSection(reviews: userReviews)
                            .padding(.horizontal, DeviceInfo.isPad ? AppSpacing.lg : AppSpacing.md)
                    }
                }
                .padding(.top, DeviceInfo.isPad ? -30 : -20) // iPad上更大的重叠效果
                .frame(maxWidth: DeviceInfo.isPad ? 900 : .infinity) // iPad上限制最大宽度
            }
        }
        .frame(maxWidth: .infinity) // 确保在iPad上居中
    }
}

// MARK: - 图片轮播视图
struct TaskImageCarouselView: View {
    let images: [String]
    @Binding var selectedIndex: Int
    @Binding var showFullScreen: Bool
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // 占位背景（避免闪烁）
            Rectangle()
                .fill(AppColors.cardBackground)
                .frame(height: DeviceInfo.isPad ? 450 : 300)
            
            if !images.isEmpty {
                TabView(selection: $selectedIndex) {
                    ForEach(Array(images.enumerated()), id: \.offset) { index, imageUrl in
                        TaskImageView(imageUrl: imageUrl, index: index, selectedIndex: $selectedIndex, showFullScreen: $showFullScreen)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(height: DeviceInfo.isPad ? 450 : 300) // iPad上更高的图片显示
                
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
                .frame(height: DeviceInfo.isPad ? 450 : 300)
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
            placeholder: Image(systemName: "photo.fill"),
            width: nil,
            height: DeviceInfo.isPad ? 450 : 300,
            contentMode: .fill,
            cornerRadius: 0
        )
        .frame(height: DeviceInfo.isPad ? 450 : 300)
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
                Text(task.displayTitle)
                    .font(AppTypography.title)
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
                
                // 价格和积分
                TaskRewardView(task: task)
            }
            
            // 分类和位置标签（位置模糊显示，只显示城市）
            HStack(spacing: AppSpacing.sm) {
                // 跳蚤市场任务：从描述中的 "Category: {分类}" 定位商品分类（后端创建任务时追加）
                if task.isFleaMarketTask {
                    if let productType = extractFleaMarketCategoryFromDescription(task.displayDescription), !productType.isEmpty {
                        Label(productType, systemImage: "tag.fill")
                            .font(AppTypography.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(AppColors.primary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(AppColors.primaryLight)
                            .clipShape(Capsule())
                    }
                } else {
                    // 普通任务：显示分类
                    Label(task.taskType, systemImage: "tag.fill")
                        .font(AppTypography.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.primary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(AppColors.primaryLight)
                        .clipShape(Capsule())
                }
                
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
        .padding(DeviceInfo.isPad ? AppSpacing.xl : AppSpacing.lg)
        .background(AppColors.cardBackground)
        .cornerRadius(AppCornerRadius.xlarge, corners: [.topLeft, .topRight])
        .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: -5)
        .padding(.horizontal, DeviceInfo.isPad ? AppSpacing.lg : AppSpacing.md)
    }
    
    /// 从描述中按 "Category: {分类}" 提取跳蚤市场商品分类（后端创建任务时在描述末尾追加）
    private func extractFleaMarketCategoryFromDescription(_ text: String) -> String? {
        let prefix = "Category: "
        guard let range = text.range(of: prefix, options: .backwards) else { return nil }
        let after = String(text[range.upperBound...])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return after.isEmpty ? nil : after
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
                    Text(String(format: LocalizationKey.pointsAmountFormat.localized, pointsReward))
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
                
                Text(task.displayDescription)
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
                
                TaskPosterInfoView(poster: poster, task: task)
            }
        }
        .padding(DeviceInfo.isPad ? AppSpacing.xl : AppSpacing.lg)
        .background(AppColors.cardBackground)
        .cornerRadius(AppCornerRadius.large)
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)
        .padding(.horizontal, DeviceInfo.isPad ? AppSpacing.lg : AppSpacing.md)
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
    let task: Task
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack {
                IconStyle.icon("person.fill", size: 18)
                    .foregroundColor(AppColors.primary)
                Text(roleTitle)
                    .font(AppTypography.title3)
                    .foregroundColor(AppColors.textPrimary)
            }
            
            NavigationLink(destination: userProfileDestination(user: poster)) {
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
    
    /// 根据任务来源返回角色标题
    private var roleTitle: String {
        if task.isFleaMarketTask {
            // 跳蚤市场任务：poster 是买家，taker 是卖家
            // 这里显示的是 poster，所以是买家
            return LocalizationKey.taskDetailBuyer.localized
        } else {
            return LocalizationKey.taskDetailPublisher.localized
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
    @Binding var showPaymentView: Bool
    @Binding var paymentClientSecret: String?
    @Binding var paymentCustomerId: String?
    @Binding var paymentEphemeralKeySecret: String?
    @Binding var showConfirmCompletionSuccess: Bool
    @Binding var showCompleteTaskSheet: Bool
    @Binding var showNegotiatePrice: Bool
    @Binding var negotiatedPrice: Double?
    let taskId: Int
    @ObservedObject var viewModel: TaskDetailViewModel
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        VStack(spacing: AppSpacing.md) {
            // ⚠️ 支付按钮（发布者已接受申请且任务未支付时显示）
            // 支付条件：
            // 1. 用户是发布者（isPoster == true）
            // 2. 任务状态是 pendingPayment（已接受但未支付，等待支付后进入进行中状态）
            // 注意：
            // - pendingConfirmation 状态不应该显示支付按钮，因为任务已经支付过了
            // - takerId 可能为 nil（后端在 accept_application 时不设置 taker_id，等待支付成功后由 webhook 设置）
            //   所以不检查 takerId，只要状态是 pendingPayment 且用户是发布者，就显示支付按钮
            // ⚠️ 重要：即使奖励金额为 0，也要显示支付按钮，因为可能涉及平台服务费或其他费用
            // StripePaymentView 会自动处理金额为 0 的情况（优惠券全额抵扣等）
            if isPoster && task.status == .pendingPayment {
                Button(action: {
                    // 优化：如果已有支付信息，直接使用；否则让 StripePaymentView 自动获取
                    // 后端 API 会复用已有的 PaymentIntent（如果存在且未完成），不会创建新的
                    // 只有在以下情况才清除支付信息：
                    // 1. 支付信息不存在（首次支付）
                    // 2. 需要刷新支付信息（比如优惠券变更等）
                    // 这里不清除，让 StripePaymentView 根据 clientSecret 是否存在来决定是否调用 API
                    // 如果 clientSecret 为 nil，StripePaymentView 会自动调用 API 获取
                    // 后端会检查是否有已有的 PaymentIntent，如果有且未完成，会复用而不是创建新的
                    showPaymentView = true
                }) {
                    HStack {
                        Image(systemName: "creditcard.fill")
                        Text("支付平台服务费")
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                }
                .buttonStyle(PrimaryButtonStyle())
            }
            
            // 申请按钮或状态显示
            if !isPoster {
                // 如果用户是接受者且任务状态是待支付，显示继续支付按钮
                if isTaker && task.status == .pendingPayment {
                    Button(action: {
                        // 打开支付页面，StripePaymentView 会自动获取支付信息
                        showPaymentView = true
                    }) {
                        Label(LocalizationKey.activityContinuePayment.localized, systemImage: "creditcard.fill")
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }
                // 如果用户已申请，无论任务状态如何，都显示申请状态卡片
                else if let userApp = viewModel.userApplication {
                    ApplicationStatusCard(application: userApp, task: task, isTaker: isTaker)
                }
                // 如果用户未申请，且任务状态为 open 且没有接受者，显示申请按钮
                else if task.status == .open && task.takerId == nil {
                    Button(action: {
                        if appState.isAuthenticated {
                            // 直接打开申请表单，议价默认关闭
                            showNegotiatePrice = false
                            negotiatedPrice = nil
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
                    showCompleteTaskSheet = true
                }) {
                    HStack(spacing: AppSpacing.sm) {
                        IconStyle.icon("checkmark.circle.fill", size: 20)
                        Text(LocalizationKey.actionsMarkComplete.localized)
                    }
                }
                .buttonStyle(PrimaryButtonStyle(useGradient: false))
                .tint(AppColors.success)
            }
            
            if task.status == .pendingConfirmation && isPoster {
                Button(action: {
                    actionLoading = true
                    
                    viewModel.confirmTaskCompletion(taskId: taskId) { success in
                        DispatchQueue.main.async {
                            actionLoading = false
                            if success {
                                // 触觉反馈：成功
                                HapticFeedback.success()
                                
                                // 显示成功提示
                                showConfirmCompletionSuccess = true
                                
                                // 立即强制刷新任务详情以获取最新状态
                                viewModel.loadTask(taskId: taskId, force: true)
                            }
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
            if (task.status == .inProgress || task.status == .pendingConfirmation || task.status == .pendingPayment) && (isPoster || isTaker) {
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
                
                HStack(spacing: 2) {
                    ForEach(1...5, id: \.self) { star in
                        let fullStars = Int(review.rating)
                        let hasHalfStar = review.rating - Double(fullStars) >= 0.5
                        
                        if star <= fullStars {
                            IconStyle.icon("star.fill", size: IconStyle.small)
                                .foregroundColor(AppColors.warning)
                        } else if star == fullStars + 1 && hasHalfStar {
                            IconStyle.icon("star.lefthalf.fill", size: IconStyle.small)
                                .foregroundColor(AppColors.warning)
                        } else {
                            IconStyle.icon("star", size: IconStyle.small)
                                .foregroundColor(AppColors.textTertiary)
                        }
                    }
                }
            }
            
            if let comment = review.comment, !comment.isEmpty {
                Text(comment)
                    .font(AppTypography.body)
                    .foregroundColor(AppColors.textSecondary)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
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
                            SectionHeader(title: LocalizationKey.taskApplicationApplyInfo.localized, icon: "pencil.line")
                            
                            EnhancedTextEditor(
                                title: nil,
                                placeholder: LocalizationKey.taskApplicationAdvantagePlaceholder.localized,
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
                                SectionHeader(title: LocalizationKey.taskDetailPriceNegotiation.localized, icon: "dollarsign.circle.fill")
                                
                                Toggle(isOn: $showNegotiatePrice) {
                                    HStack {
                                        Text(LocalizationKey.taskApplicationIWantToNegotiatePrice.localized)
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
                                        title: LocalizationKey.taskApplicationExpectedAmount.localized,
                                        placeholder: "0.00",
                                        value: $negotiatedPrice,
                                        prefix: "£",
                                        isRequired: true
                                    )
                                    .transition(.opacity.combined(with: .move(edge: .top)))
                                    
                                    Text(LocalizationKey.taskApplicationNegotiatePriceHint.localized)
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
                                Text(LocalizationKey.taskApplicationSubmitApplication.localized)
                                    .font(AppTypography.bodyBold)
                            }
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .padding(.top, AppSpacing.lg)
                    }
                    .padding(AppSpacing.md)
                }
            }
            .navigationTitle(LocalizationKey.taskApplicationApplyTask.localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(LocalizationKey.commonCancel.localized) {
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
    let isTaker: Bool  // 用户是否是任务接受者
    
    private var statusColor: Color {
        switch application.status {
        case "pending":
            return AppColors.warning
        case "approved":
            // ⚠️ 重要：如果任务状态是待支付，使用警告颜色（橙色），而不是成功颜色（绿色）
            if task.status == .pendingPayment {
                return AppColors.warning
            } else if task.status == .pendingConfirmation {
                return Color.purple
            } else {
                return AppColors.success
            }
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
            // ⚠️ 重要：如果任务状态是待支付，显示待支付状态，而不是"申请已批准"
            if task.status == .pendingPayment {
                return LocalizationKey.taskStatusPendingPayment.localized
            } else if task.status == .pendingConfirmation {
                return LocalizationKey.taskDetailTaskCompleted.localized
            } else {
                return LocalizationKey.taskDetailApplicationApproved.localized
            }
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
            // ⚠️ 重要：如果任务状态是待支付，显示待支付描述
            if task.status == .pendingPayment {
                return LocalizationKey.taskDetailPendingPaymentMessage.localized
            } else if task.status == .pendingConfirmation {
                return LocalizationKey.taskDetailTaskCompletedMessage.localized
            } else {
                return LocalizationKey.taskDetailApplicationApprovedMessage.localized
            }
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
                
                // 优化：如果任务已被其他用户接受，且用户不是接受者，显示提示
                if task.takerId != nil && !isTaker && application.status == "pending" {
                    HStack(spacing: 4) {
                        Image(systemName: "info.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(AppColors.warning)
                        Text(LocalizationKey.taskDetailTaskAcceptedByOthers.localized)
                            .font(.system(size: 12))
                            .foregroundColor(AppColors.warning)
                    }
                    .padding(.top, 2)
                }
                
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
            // ⚠️ 重要：如果任务状态是待支付，使用支付图标
            if task.status == .pendingPayment {
                return "creditcard.fill"
            } else if task.status == .pendingConfirmation {
                return "checkmark.seal.fill"
            } else {
                return "checkmark.circle.fill"
            }
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
    @State private var showRejectConfirm = false
    
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
                    Text(application.applicantName ?? LocalizationKey.taskApplicationUnknownUser.localized)
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
            
            // 操作按钮（优化：使用图标按钮，更美观）
            if application.status == "pending" {
                HStack(spacing: AppSpacing.md) {
                    // 批准按钮 - 图标样式
                    Button(action: {
                        HapticFeedback.success()
                        onApprove()
                    }) {
                        IconStyle.icon("checkmark.circle.fill", size: 24)
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(
                                LinearGradient(
                                    gradient: Gradient(colors: [AppColors.success, AppColors.success.opacity(0.8)]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .clipShape(Circle())
                            .shadow(color: AppColors.success.opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                    .buttonStyle(ScaleButtonStyle())
                    
                    // 增加间距，防止误触
                    Spacer()
                        .frame(width: 16)
                    
                    // 拒绝按钮 - 图标样式
                    Button(action: {
                        HapticFeedback.warning()
                        showRejectConfirm = true
                    }) {
                        IconStyle.icon("xmark.circle.fill", size: 24)
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(
                                LinearGradient(
                                    gradient: Gradient(colors: [AppColors.error, AppColors.error.opacity(0.8)]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .clipShape(Circle())
                            .shadow(color: AppColors.error.opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                    .buttonStyle(ScaleButtonStyle())
                    
                    Spacer()
                    
                    // 留言按钮 - 保持文字样式，但优化设计
                    Button(action: {
                        HapticFeedback.light()
                        showMessageSheet = true
                    }) {
                        HStack(spacing: 6) {
                            IconStyle.icon("message.fill", size: 16)
                            Text(LocalizationKey.taskApplicationMessage.localized)
                                .font(AppTypography.caption)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(AppColors.primary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(AppColors.primaryLight.opacity(0.3))
                        .cornerRadius(AppCornerRadius.medium)
                        .overlay(
                            RoundedRectangle(cornerRadius: AppCornerRadius.medium)
                                .stroke(AppColors.primary.opacity(0.3), lineWidth: 1)
                        )
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
                .padding(.top, AppSpacing.xs)
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
        .alert(LocalizationKey.taskDetailRejectApplication.localized, isPresented: $showRejectConfirm) {
            Button(LocalizationKey.commonCancel.localized, role: .cancel) {
                showRejectConfirm = false
            }
            Button(LocalizationKey.commonConfirm.localized, role: .destructive) {
                onReject()
            }
        } message: {
            Text(LocalizationKey.taskDetailRejectApplicationConfirm.localized)
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
                            SectionHeader(title: LocalizationKey.taskApplicationMessage.localized, icon: "message.fill")
                            
                            TextEditor(text: $message)
                                .font(AppTypography.body)
                                .frame(minHeight: 120)
                                .padding(AppSpacing.sm)
                                .background(AppColors.cardBackground)
                                .cornerRadius(AppCornerRadius.medium)
                                .overlay(
                                    Group {
                                        if message.isEmpty {
                                            Text(LocalizationKey.taskApplicationMessageToApplicant.localized)
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
                                    Text(LocalizationKey.taskApplicationIsNegotiatePrice.localized)
                                        .font(AppTypography.bodyBold)
                                        .foregroundColor(AppColors.textPrimary)
                                }
                            }
                            .toggleStyle(SwitchToggleStyle(tint: AppColors.primary))
                            
                            if showNegotiatePrice {
                                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                                    Text(LocalizationKey.taskApplicationNegotiateAmount.localized)
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
                                Text(LocalizationKey.taskApplicationSendMessage.localized)
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
            .navigationTitle(LocalizationKey.taskApplicationMessageToApplicant.localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(LocalizationKey.commonCancel.localized) {
                        dismiss()
                    }
                }
            }
            .alert(LocalizationKey.errorUnknownError.localized, isPresented: $showError) {
                Button(LocalizationKey.commonOk.localized, role: .cancel) {}
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
    @Binding var rating: Double
    @Binding var comment: String
    @Binding var isAnonymous: Bool
    @Binding var selectedTags: [String]
    let task: Task?
    let isPoster: Bool
    let onSubmit: () -> Void
    @Environment(\.dismiss) var dismiss
    @State private var hoverRating: Double = 0
    
    private var reviewTags: [String] {
        guard task != nil else { return [] }
        
        if isPoster {
            return [
                LocalizationKey.ratingTagHighQuality.localized,
                LocalizationKey.ratingTagOnTime.localized,
                LocalizationKey.ratingTagResponsible.localized,
                LocalizationKey.ratingTagGoodCommunication.localized,
                LocalizationKey.ratingTagProfessionalEfficient.localized,
                LocalizationKey.ratingTagTrustworthy.localized,
                LocalizationKey.ratingTagStronglyRecommended.localized,
                LocalizationKey.ratingTagExcellent.localized
            ]
        } else {
            return [
                LocalizationKey.ratingTagClearTask.localized,
                LocalizationKey.ratingTagTimelyCommunication.localized,
                LocalizationKey.ratingTagTimelyPayment.localized,
                LocalizationKey.ratingTagReasonableRequirements.localized,
                LocalizationKey.ratingTagPleasantCooperation.localized,
                LocalizationKey.ratingTagStronglyRecommended.localized,
                LocalizationKey.ratingTagTrustworthy.localized,
                LocalizationKey.ratingTagVeryProfessional.localized
            ]
        }
    }
    
    private var ratingText: String {
        let fullStars = Int(rating)
        let hasHalfStar = rating - Double(fullStars) >= 0.5
        
        if hasHalfStar {
            switch fullStars {
            case 0: return LocalizationKey.rating05Stars.localized
            case 1: return LocalizationKey.rating15Stars.localized
            case 2: return LocalizationKey.rating25Stars.localized
            case 3: return LocalizationKey.rating35Stars.localized
            case 4: return LocalizationKey.rating45Stars.localized
            default: return ""
            }
        } else {
            switch fullStars {
            case 1: return LocalizationKey.ratingVeryPoor.localized
            case 2: return LocalizationKey.ratingPoor.localized
            case 3: return LocalizationKey.ratingAverage.localized
            case 4: return LocalizationKey.ratingGood.localized
            case 5: return LocalizationKey.ratingExcellent.localized
            default: return ""
            }
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
                            SectionHeader(title: LocalizationKey.taskApplicationOverallRating.localized, icon: "star.fill")
                            
                            VStack(spacing: AppSpacing.sm) {
                                HStack(spacing: AppSpacing.md) {
                                    ForEach(1...5, id: \.self) { star in
                                        StarRatingButton(
                                            starNumber: star,
                                            rating: $rating,
                                            hoverRating: $hoverRating
                                        )
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
                            SectionHeader(title: LocalizationKey.taskApplicationRatingTags.localized, icon: "tag.fill")
                            
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
                            SectionHeader(title: LocalizationKey.taskApplicationRatingContent.localized, icon: "square.and.pencil")
                            
                            EnhancedTextEditor(
                                title: nil,
                                placeholder: LocalizationKey.taskApplicationReviewPlaceholder.localized,
                                text: $comment,
                                height: 150,
                                characterLimit: 500
                            )
                            
                            Toggle(isOn: $isAnonymous) {
                                Text(LocalizationKey.ratingAnonymous.localized)
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
                            // 验证评分是否有效
                            guard rating >= 0.5 && rating <= 5.0 else {
                                return
                            }
                            
                            HapticFeedback.success()
                            // 将标签添加到评论中
                            if !selectedTags.isEmpty {
                                let separator = LocalizationKey.commonTagSeparator.localized
                                let tagsText = selectedTags.joined(separator: separator)
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
                                Text(LocalizationKey.ratingSubmit.localized)
                                    .font(AppTypography.bodyBold)
                            }
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(rating < 0.5 || rating > 5.0)
                        .opacity((rating >= 0.5 && rating <= 5.0) ? 1.0 : 0.6)
                        .padding(.top, AppSpacing.lg)
                        .padding(.bottom, AppSpacing.xxl)
                    }
                    .padding(AppSpacing.md)
                }
            }
            .navigationTitle(LocalizationKey.actionsRateTask.localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(LocalizationKey.commonCancel.localized) {
                        dismiss()
                    }
                }
            }
        }
    }
}

// 支持0.5星选择的星级按钮
struct StarRatingButton: View {
    let starNumber: Int
    @Binding var rating: Double
    @Binding var hoverRating: Double
    
    private var displayRating: Double {
        hoverRating > 0 ? hoverRating : rating
    }
    
    private var starState: StarState {
        let fullStars = Int(displayRating)
        let hasHalfStar = displayRating - Double(fullStars) >= 0.5
        
        if starNumber <= fullStars {
            return .filled
        } else if starNumber == fullStars + 1 && hasHalfStar {
            return .halfFilled
        } else {
            return .empty
        }
    }
    
    enum StarState {
        case filled
        case halfFilled
        case empty
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // 背景（空星）
                Image(systemName: "star")
                    .font(.system(size: 36))
                    .foregroundColor(AppColors.textQuaternary)
                
                // 根据评分显示填充
                switch starState {
                case .filled:
                    Image(systemName: "star.fill")
                        .font(.system(size: 36))
                        .foregroundColor(AppColors.warning)
                case .halfFilled:
                    Image(systemName: "star.lefthalf.fill")
                        .font(.system(size: 36))
                        .foregroundColor(AppColors.warning)
                case .empty:
                    EmptyView()
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let x = value.location.x
                        let width = geometry.size.width
                        let isLeftHalf = x < width / 2
                        
                        if isLeftHalf {
                            // 点击左半部分：0.5星（确保不小于0.5）
                            rating = max(0.5, Double(starNumber) - 0.5)
                        } else {
                            // 点击右半部分：整数星
                            rating = Double(starNumber)
                        }
                        HapticFeedback.selection()
                    }
                    .onEnded { _ in
                        hoverRating = 0
                    }
            )
            .onTapGesture { location in
                let width = geometry.size.width
                let isLeftHalf = location.x < width / 2
                
                if isLeftHalf {
                    // 点击左半部分：0.5星（确保不小于0.5）
                    rating = max(0.5, Double(starNumber) - 0.5)
                } else {
                    // 点击右半部分：整数星
                    rating = Double(starNumber)
                }
                HapticFeedback.selection()
            }
        }
        .frame(width: 36, height: 36)
    }
}

// 完成任务页面
struct CompleteTaskSheet: View {
    let taskId: Int
    let task: Task
    let onComplete: ([String]) -> Void
    @Environment(\.dismiss) var dismiss
    
    @State private var selectedImages: [UIImage] = []
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var isUploading = false
    @State private var uploadedImageUrls: [String] = []
    @State private var errorMessage: String?
    @State private var uploadProgress: (current: Int, total: Int) = (0, 0)
    @State private var imageSizeErrors: [String] = []
    
    var body: some View {
        NavigationView {
            ZStack {
                AppColors.background
                    .ignoresSafeArea()
                
                KeyboardAvoidingScrollView(extraPadding: 20) {
                    VStack(spacing: AppSpacing.xl) {
                        // 1. 说明文字
                        VStack(alignment: .leading, spacing: AppSpacing.md) {
                            HStack(spacing: AppSpacing.sm) {
                                IconStyle.icon("checkmark.circle.fill", size: 24)
                                    .foregroundColor(AppColors.success)
                                Text("任务已完成")
                                    .font(AppTypography.title3)
                                    .fontWeight(.semibold)
                                    .foregroundColor(AppColors.textPrimary)
                            }
                            
                            Text("您已完成此任务。请上传相关证据图片（可选），以便发布者确认任务完成情况。")
                                .font(AppTypography.body)
                                .foregroundColor(AppColors.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(AppSpacing.md)
                        .background(AppColors.cardBackground)
                        .cornerRadius(AppCornerRadius.large)
                        .shadow(color: Color.black.opacity(0.03), radius: 10, x: 0, y: 4)
                        
                        // 2. 证据图片上传
                        VStack(alignment: .leading, spacing: AppSpacing.md) {
                            HStack {
                                SectionHeader(title: "证据图片（可选）", icon: "photo.on.rectangle")
                                Spacer()
                                Text("\(selectedImages.count)/5")
                                    .font(AppTypography.caption)
                                    .foregroundColor(AppColors.textTertiary)
                            }
                            
                            // 图片大小限制提示
                            HStack(spacing: 4) {
                                Image(systemName: "info.circle.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(AppColors.textTertiary)
                                Text("单张图片不超过 5MB，最多上传 5 张")
                                    .font(AppTypography.caption)
                                    .foregroundColor(AppColors.textTertiary)
                            }
                            .padding(.horizontal, 4)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: AppSpacing.md) {
                                    // 添加按钮
                                    if selectedImages.count < 5 {
                                        PhotosPicker(selection: $selectedItems, maxSelectionCount: 5 - selectedImages.count, matching: .images) {
                                            VStack(spacing: 8) {
                                                Image(systemName: "plus.viewfinder")
                                                    .font(.system(size: 28))
                                                    .foregroundColor(AppColors.primary)
                                                Text("添加图片")
                                                    .font(.system(size: 11, weight: .medium))
                                                    .foregroundColor(AppColors.textSecondary)
                                            }
                                            .frame(width: 90, height: 90)
                                            .background(AppColors.background)
                                            .cornerRadius(AppCornerRadius.medium)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: AppCornerRadius.medium)
                                                    .stroke(AppColors.primary.opacity(0.2), style: StrokeStyle(lineWidth: 1, dash: [5, 3]))
                                            )
                                        }
                                        .onChange(of: selectedItems) { _ in
                                            handleImageSelection()
                                        }
                                    }
                                    
                                    // 图片预览
                                    ForEach(Array(selectedImages.enumerated()), id: \.offset) { index, image in
                                        ZStack(alignment: .topTrailing) {
                                            Image(uiImage: image)
                                                .resizable()
                                                .aspectRatio(contentMode: .fill)
                                                .frame(width: 90, height: 90)
                                                .clipShape(RoundedRectangle(cornerRadius: AppCornerRadius.medium))
                                            
                                            Button(action: {
                                                withAnimation {
                                                    selectedImages.remove(at: index)
                                                    selectedItems = []
                                                    HapticFeedback.light()
                                                }
                                            }) {
                                                Image(systemName: "xmark.circle.fill")
                                                    .font(.system(size: 20))
                                                    .foregroundColor(.white)
                                                    .background(Circle().fill(Color.black.opacity(0.5)))
                                            }
                                            .padding(4)
                                        }
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        .padding(AppSpacing.md)
                        .background(AppColors.cardBackground)
                        .cornerRadius(AppCornerRadius.large)
                        .shadow(color: Color.black.opacity(0.03), radius: 10, x: 0, y: 4)
                        
                        // 图片大小错误提示
                        if !imageSizeErrors.isEmpty {
                            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                                ForEach(imageSizeErrors, id: \.self) { error in
                                    HStack(spacing: 8) {
                                        IconStyle.icon("exclamationmark.triangle.fill", size: 16)
                                        Text(error)
                                            .font(AppTypography.caption)
                                            .fontWeight(.medium)
                                    }
                                    .foregroundColor(AppColors.warning)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(AppColors.warning.opacity(0.08))
                            .cornerRadius(AppCornerRadius.medium)
                        }
                        
                        // 上传错误提示
                        if let errorMessage = errorMessage {
                            HStack(spacing: 8) {
                                IconStyle.icon("exclamationmark.octagon.fill", size: 16)
                                Text(errorMessage)
                                    .font(AppTypography.caption)
                                    .fontWeight(.medium)
                            }
                            .foregroundColor(AppColors.error)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(AppColors.error.opacity(0.08))
                            .cornerRadius(AppCornerRadius.medium)
                        }
                        
                        // 上传进度
                        if isUploading && uploadProgress.total > 0 {
                            VStack(spacing: AppSpacing.xs) {
                                HStack {
                                    Text("上传进度")
                                        .font(AppTypography.caption)
                                        .foregroundColor(AppColors.textSecondary)
                                    Spacer()
                                    Text("\(uploadProgress.current)/\(uploadProgress.total)")
                                        .font(AppTypography.caption)
                                        .fontWeight(.semibold)
                                        .foregroundColor(AppColors.primary)
                                }
                                
                                ProgressView(value: Double(uploadProgress.current), total: Double(uploadProgress.total))
                                    .tint(AppColors.primary)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(AppColors.cardBackground)
                            .cornerRadius(AppCornerRadius.medium)
                        }
                        
                        // 提交按钮
                        Button(action: {
                            submitCompletion()
                        }) {
                            HStack(spacing: 8) {
                                if isUploading {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    IconStyle.icon("checkmark.circle.fill", size: 18)
                                }
                                if isUploading {
                                    Text("上传中 \(uploadProgress.current)/\(uploadProgress.total)...")
                                        .font(AppTypography.bodyBold)
                                } else {
                                    Text("确认完成任务")
                                        .font(AppTypography.bodyBold)
                                }
                            }
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(isUploading)
                        .padding(.top, AppSpacing.lg)
                    }
                    .padding(AppSpacing.md)
                }
            }
            .navigationTitle("完成任务")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                    .disabled(isUploading)
                }
            }
        }
    }
    
    private func handleImageSelection() {
        _Concurrency.Task {
            var newSizeErrors: [String] = []
            let maxImageSize = 5 * 1024 * 1024 // 5MB
            
            for item in selectedItems {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    // 检查图片大小（压缩前）
                    if data.count > maxImageSize {
                        let sizeInMB = Double(data.count) / (1024 * 1024)
                        newSizeErrors.append(String(format: "图片过大 (%.1fMB)，请选择较小的图片", sizeInMB))
                        continue
                    }
                    
                    if let image = UIImage(data: data) {
                        // 在主线程更新UI
                        DispatchQueue.main.async {
                            if selectedImages.count < 5 {
                                selectedImages.append(image)
                            } else {
                                newSizeErrors.append("最多只能上传 5 张图片")
                            }
                        }
                    }
                }
            }
            
            // 在主线程更新UI
            DispatchQueue.main.async {
                imageSizeErrors = newSizeErrors
                selectedItems = [] // 清空以备下次选择
            }
        }
    }
    
    private func submitCompletion() {
        guard !isUploading else { return }
        
        errorMessage = nil
        imageSizeErrors = []
        
        if selectedImages.isEmpty {
            // 没有图片，直接提交
            onComplete([])
            dismiss()
            return
        }
        
        // 检查图片大小（压缩后）
        let maxImageSize = 5 * 1024 * 1024 // 5MB
        var sizeErrors: [String] = []
        var validImages: [(UIImage, Int)] = []
        
        for (index, image) in selectedImages.enumerated() {
            if let imageData = image.jpegData(compressionQuality: 0.7) {
                if imageData.count > maxImageSize {
                    let sizeInMB = Double(imageData.count) / (1024 * 1024)
                    sizeErrors.append(String(format: "第 %d 张图片压缩后仍过大 (%.1fMB)，请选择较小的图片", index + 1, sizeInMB))
                } else {
                    validImages.append((image, index + 1))
                }
            } else {
                sizeErrors.append("第 \(index + 1) 张图片无法处理，请重新选择")
            }
        }
        
        if !sizeErrors.isEmpty {
            imageSizeErrors = sizeErrors
            return
        }
        
        if validImages.isEmpty {
            errorMessage = "没有可上传的图片"
            return
        }
        
        // 上传图片
        isUploading = true
        uploadedImageUrls = []
        uploadProgress = (0, validImages.count)
        
        let uploadGroup = DispatchGroup()
        var uploadErrors: [(Error, Int)] = []
        
        for (image, index) in validImages {
            uploadGroup.enter()
            // 直接使用 uploadImage 方法，它会自动压缩（0.7质量）
            // 使用任务ID作为路径，存储在任务文件夹中
            let path = "tasks/\(taskId)"
            APIService.shared.uploadImage(image, path: path, taskId: taskId) { result in
                switch result {
                case .success(let url):
                    DispatchQueue.main.async {
                        uploadedImageUrls.append(url)
                        uploadProgress.current += 1
                    }
                case .failure(let error):
                    uploadErrors.append((error, index))
                }
                uploadGroup.leave()
            }
        }
        
        uploadGroup.notify(queue: .main) {
            isUploading = false
            
            if uploadErrors.isEmpty {
                // 所有图片上传成功，提交完成任务
                onComplete(uploadedImageUrls)
                dismiss()
            } else {
                // 生成详细的错误信息
                var errorDetails: [String] = []
                for (error, index) in uploadErrors {
                    let errorDescription = getDetailedErrorMessage(error)
                    errorDetails.append("第 \(index) 张图片：\(errorDescription)")
                }
                
                if errorDetails.count == validImages.count {
                    // 所有图片都上传失败
                    errorMessage = "所有图片上传失败。\n" + errorDetails.joined(separator: "\n")
                } else {
                    // 部分图片上传失败
                    errorMessage = "部分图片上传失败：\n" + errorDetails.joined(separator: "\n")
                }
            }
        }
    }
    
    /// 获取详细的错误信息
    private func getDetailedErrorMessage(_ error: Error) -> String {
        if let apiError = error as? APIError {
            switch apiError {
            case .requestFailed(let underlyingError):
                if let urlError = underlyingError as? URLError {
                    switch urlError.code {
                    case .notConnectedToInternet, .networkConnectionLost:
                        return "网络连接失败，请检查网络设置"
                    case .timedOut:
                        return "上传超时，请重试"
                    case .cannotFindHost, .cannotConnectToHost:
                        return "无法连接到服务器，请稍后重试"
                    default:
                        return "网络错误：\(urlError.localizedDescription)"
                    }
                }
                return "网络请求失败：\(underlyingError.localizedDescription)"
            case .httpError(let statusCode):
                switch statusCode {
                case 400:
                    return "请求格式错误，请检查图片格式"
                case 401:
                    return "未授权，请重新登录"
                case 403:
                    return "无权限上传图片"
                case 413:
                    return "图片文件过大，请选择较小的图片"
                case 500...599:
                    return "服务器错误（\(statusCode)），请稍后重试"
                default:
                    return "服务器错误（\(statusCode)）"
                }
            case .serverError(let statusCode, let message):
                switch statusCode {
                case 400:
                    return "请求格式错误：\(message)"
                case 401:
                    return "未授权，请重新登录"
                case 403:
                    return "无权限上传图片"
                case 413:
                    return "图片文件过大：\(message)"
                case 500...599:
                    return "服务器错误（\(statusCode)）：\(message)"
                default:
                    return "服务器错误（\(statusCode)）：\(message)"
                }
            case .decodingError(let error):
                return "解析响应失败：\(error.localizedDescription)"
            case .invalidURL:
                return "无效的URL"
            case .invalidResponse:
                return "服务器响应格式错误"
            case .unauthorized:
                return "未授权，请重新登录"
            case .unknown:
                return "未知错误，请重试"
            }
        }
        return error.localizedDescription
    }
}
