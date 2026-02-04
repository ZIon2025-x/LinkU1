import SwiftUI

struct ServiceDetailView: View {
    let serviceId: Int
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = ServiceDetailViewModel()
    @State private var showApplySheet = false
    @State private var applicationMessage = ""
    @State private var counterPrice: Double?
    @State private var showCounterPrice = false
    @State private var currentImageIndex = 0
    @State private var showPaymentView = false
    @State private var paymentTaskId: Int?
    @State private var selectedDeadline: Date?
    @State private var isFlexible: Bool = false
    @State private var showSuccessOverlay = false
    @State private var successOverlayMessage: String = ""
    @State private var showApplyLoading = false
    @State private var showStripeSetupAlert = false
    @State private var showStripeOnboardingSheet = false

    var body: some View {
        ZStack(alignment: .bottom) {
            AppColors.background
                .ignoresSafeArea()
            
            if viewModel.isLoading && viewModel.service == nil {
                ScrollView {
                    DetailSkeleton()
                        .padding(.horizontal, AppSpacing.md)
                        .padding(.vertical, AppSpacing.lg)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let service = viewModel.service {
                ScrollView {
                    VStack(spacing: 0) {
                        // 1. 沉浸式图片区域
                        serviceImageGallery(service: service)
                        
                        // 2. 内容区域
                        VStack(spacing: 24) {
                            // 价格与标题卡片
                            priceAndTitleCard(service: service)
                                .padding(.top, -40)
                            
                            // 服务详情卡片
                            descriptionCard(service: service)
                            
                            // 评价卡片（始终显示，即使没有评价也显示"暂无评价"）
                            reviewsCard(reviews: viewModel.reviews, isLoading: viewModel.isLoadingReviews)
                            
                            // 可选时间段
                            if service.hasTimeSlots == true {
                                timeSlotsCard()
                            }
                            
                            // 底部安全区域
                            Spacer().frame(height: 120)
                        }
                    }
                }
                .ignoresSafeArea(edges: .top)
                .scrollIndicators(.hidden)
                
                // 3. 固定底部申请栏
                bottomApplyBar(service: service)
            } else {
                // 如果 service 为 nil 且不在加载中，显示错误状态（不应该发生，但作为保护）
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 48))
                        .foregroundColor(AppColors.textTertiary)
                    Text(LocalizationKey.serviceLoadFailed.localized)
                        .font(AppTypography.body)
                        .foregroundColor(AppColors.textSecondary)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .enableSwipeBack()
        .toolbar(.hidden, for: .tabBar)
        .overlay {
            if showSuccessOverlay {
                OperationResultOverlay(
                    isPresented: $showSuccessOverlay,
                    type: .success,
                    message: successOverlayMessage.isEmpty ? nil : successOverlayMessage,
                    autoDismissSeconds: 1.5,
                    onDismiss: { }
                )
            }
        }
        .sheet(isPresented: $showApplySheet) {
            ApplyServiceSheet(
                message: $applicationMessage,
                counterPrice: $counterPrice,
                showCounterPrice: $showCounterPrice,
                selectedDeadline: $selectedDeadline,
                isFlexible: $isFlexible,
                hasTimeSlots: viewModel.service?.hasTimeSlots == true,
                isSubmitting: $showApplyLoading,
                onApply: {
                    viewModel.applyService(
                        serviceId: serviceId,
                        message: applicationMessage.isEmpty ? nil : applicationMessage,
                        counterPrice: counterPrice,
                        deadline: isFlexible ? nil : selectedDeadline,
                        isFlexible: isFlexible ? 1 : 0
                    ) { success in
                        showApplyLoading = false
                        if success {
                            showApplySheet = false
                            applicationMessage = ""
                            counterPrice = nil
                            selectedDeadline = nil
                            isFlexible = false
                            successOverlayMessage = LocalizationKey.taskExpertApplicationSubmitted.localized
                            showSuccessOverlay = true
                        }
                    }
                }
            )
        }
        .onAppear {
            viewModel.loadService(serviceId: serviceId)
            viewModel.loadReviews(serviceId: serviceId)
            if viewModel.service?.hasTimeSlots == true {
                viewModel.loadTimeSlots(serviceId: serviceId)
            }
        }
        .onChange(of: viewModel.service?.hasTimeSlots) { hasSlots in
            if hasSlots == true {
                viewModel.loadTimeSlots(serviceId: serviceId)
            }
        }
        .sheet(isPresented: $showPaymentView) {
            if let taskId = paymentTaskId {
                NavigationView {
                    TaskDetailView(taskId: taskId)
                        .environmentObject(appState)
                }
            }
        }
        .onChange(of: viewModel.shouldPromptStripeSetup) { _, newValue in
            if newValue { showStripeSetupAlert = true }
        }
        .alert(LocalizationKey.paymentPleaseSetupFirst.localized, isPresented: $showStripeSetupAlert) {
            Button(LocalizationKey.commonGoSetup.localized) {
                showStripeOnboardingSheet = true
                viewModel.shouldPromptStripeSetup = false
            }
            Button(LocalizationKey.commonCancel.localized, role: .cancel) {
                viewModel.shouldPromptStripeSetup = false
            }
        } message: {
            Text(LocalizationKey.paymentPleaseSetupMessage.localized)
        }
        .sheet(isPresented: $showStripeOnboardingSheet) {
            StripeConnectOnboardingView()
        }
    }
    
    // MARK: - Sub Components
    
    @ViewBuilder
    private func serviceImageGallery(service: TaskExpertService) -> some View {
        if let images = service.images, !images.isEmpty {
            // 使用 maxWidth + aspectRatio 替代 UIScreen.main.bounds，避免申请弹窗出现时
            // 父级尺寸变化导致图片右侧和底部被裁切、露出背后容器
            ZStack(alignment: .bottom) {
                TabView(selection: $currentImageIndex) {
                    // 性能优化：使用稳定ID (\.element) 替代 (\.offset)
                    ForEach(Array(images.enumerated()), id: \.element) { index, imageUrl in
                        AsyncImageView(urlString: imageUrl, placeholder: Image(systemName: "photo.fill"))
                            .aspectRatio(contentMode: .fill)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .clipped()
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(maxWidth: .infinity)
                .aspectRatio(5 / 4, contentMode: .fit)
                
                if images.count > 1 {
                    HStack(spacing: 6) {
                        ForEach(0..<images.count, id: \.self) { index in
                            Circle()
                                .fill(currentImageIndex == index ? Color.white : Color.white.opacity(0.4))
                                .frame(width: currentImageIndex == index ? 8 : 6, height: currentImageIndex == index ? 8 : 6)
                                .animation(.easeInOut(duration: 0.2), value: currentImageIndex)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color.black.opacity(0.3)))
                    .padding(.bottom, 50)
                }
            }
            .frame(maxWidth: .infinity)
            .aspectRatio(5 / 4, contentMode: .fit)
        } else {
            ZStack {
                LinearGradient(
                    colors: [AppColors.primaryLight, AppColors.primaryLight.opacity(0.5)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                VStack(spacing: 12) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 40))
                        .foregroundColor(AppColors.primary.opacity(0.3))
                    Text("暂无图片")
                        .font(.system(size: 12))
                        .foregroundColor(AppColors.primary.opacity(0.4))
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 240)
        }
    }
    
    @ViewBuilder
    private func priceAndTitleCard(service: TaskExpertService) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("£")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(Color(red: 0.9, green: 0.3, blue: 0.2))
                
                Text(String(format: "%.2f", service.basePrice))
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(Color(red: 0.9, green: 0.3, blue: 0.2))
                
                Spacer()
                
                Text(service.currency)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(AppColors.textTertiary)
            }
            
            Text(service.serviceName)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(AppColors.textPrimary)
                .lineSpacing(4)
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color(UIColor.systemBackground))
                .shadow(color: Color.black.opacity(0.1), radius: 20, x: 0, y: 8)
        )
        .padding(.horizontal, 20)
    }
    
    @ViewBuilder
    private func descriptionCard(service: TaskExpertService) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                RoundedRectangle(cornerRadius: 2)
                    .fill(AppColors.primary)
                    .frame(width: 4, height: 16)
                Text("服务详情")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppColors.textPrimary)
            }
            
            if let description = service.description, !description.isEmpty {
                Text(description)
                    .font(.system(size: 15))
                    .foregroundColor(AppColors.textSecondary)
                    .lineSpacing(6)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("暂无详细描述")
                    .font(.system(size: 14))
                    .foregroundColor(AppColors.textTertiary)
                    .italic()
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(UIColor.systemBackground))
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 4)
        .padding(.horizontal, 20)
    }
    
    @ViewBuilder
    private func reviewsCard(reviews: [PublicReview], isLoading: Bool) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                RoundedRectangle(cornerRadius: 2)
                    .fill(AppColors.primary)
                    .frame(width: 4, height: 18)
                
                Text(LocalizationKey.taskExpertReviews.localized)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(AppColors.textPrimary)
                
                Spacer()
                
                if viewModel.reviewsTotal > 0 {
                    Text(String(format: LocalizationKey.taskExpertReviewsCount.localized, viewModel.reviewsTotal))
                        .font(.system(size: 13))
                        .foregroundColor(AppColors.textTertiary)
                }
            }
            
            if isLoading && reviews.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
            } else if reviews.isEmpty {
                Text(LocalizationKey.taskExpertNoReviews.localized)
                    .font(.system(size: 14))
                    .foregroundColor(AppColors.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                LazyVStack(spacing: 16) {
                    ForEach(reviews) { review in
                        reviewRow(review: review)
                    }
                    
                    // 加载更多按钮
                    if viewModel.hasMoreReviews {
                        Button(action: {
                            viewModel.loadMoreReviews(serviceId: serviceId)
                        }) {
                            HStack(spacing: 8) {
                                if viewModel.isLoadingMoreReviews {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "arrow.down.circle")
                                        .font(.system(size: 14))
                                }
                                Text(viewModel.isLoadingMoreReviews ? LocalizationKey.commonLoading.localized : LocalizationKey.commonLoadMore.localized)
                                    .font(.system(size: 13))
                            }
                            .foregroundColor(AppColors.textSecondary)
                            .padding(.vertical, 12)
                            .frame(maxWidth: .infinity)
                        }
                        .disabled(viewModel.isLoadingMoreReviews)
                    }
                }
            }
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(UIColor.systemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 2)
        )
        .padding(.horizontal, 16)
    }
    
    @ViewBuilder
    private func reviewRow(review: PublicReview) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                // 星级评分（支持0.5星）
                HStack(spacing: 2) {
                    ForEach(1...5, id: \.self) { star in
                        let fullStars = Int(review.rating)
                        let hasHalfStar = review.rating - Double(fullStars) >= 0.5
                        
                        if star <= fullStars {
                            Image(systemName: "star.fill")
                                .font(.system(size: 14))
                                .foregroundColor(AppColors.warning)
                        } else if star == fullStars + 1 && hasHalfStar {
                            Image(systemName: "star.lefthalf.fill")
                                .font(.system(size: 14))
                                .foregroundColor(AppColors.warning)
                        } else {
                            Image(systemName: "star")
                                .font(.system(size: 14))
                                .foregroundColor(AppColors.textTertiary)
                        }
                    }
                }
                
                Spacer()
                
                // 评价时间
                Text(DateFormatterHelper.shared.formatTime(review.createdAt))
                    .font(.system(size: 12))
                    .foregroundColor(AppColors.textTertiary)
            }
            
            if let comment = review.comment, !comment.isEmpty {
                Text(comment)
                    .font(.system(size: 14))
                    .foregroundColor(AppColors.textPrimary)
                    .lineSpacing(4)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(AppColors.cardBackground)
        )
    }
    
    private func timeSlotsCard() -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                RoundedRectangle(cornerRadius: 2)
                    .fill(AppColors.primary)
                    .frame(width: 4, height: 16)
                Text(LocalizationKey.taskExpertOptionalTimeSlots.localized)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppColors.textPrimary)
            }
            
            if viewModel.timeSlots.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "calendar.badge.exclamationmark")
                        .foregroundColor(AppColors.textQuaternary)
                    Text(LocalizationKey.taskExpertNoAvailableSlots.localized)
                        .font(.system(size: 14))
                        .foregroundColor(AppColors.textTertiary)
                }
                .padding(.vertical, 8)
            } else {
                VStack(spacing: 12) {
                    ForEach(viewModel.timeSlots) { slot in
                        TimeSlotCard(slot: slot)
                    }
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(UIColor.systemBackground))
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 4)
        .padding(.horizontal, 20)
    }
    
    @ViewBuilder
    private func bottomApplyBar(service: TaskExpertService) -> some View {
        HStack {
            if service.userApplicationId != nil {
                // 已申请，根据状态显示不同按钮
                if let hasNegotiation = service.userApplicationHasNegotiation, hasNegotiation,
                   let taskStatus = service.userTaskStatus, taskStatus == "pending_payment" {
                    // 有议价且待支付，显示等待达人回应按钮（灰色不可点击）
                    Text(LocalizationKey.serviceWaitingExpertResponse.localized)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(AppColors.textQuaternary)
                        .cornerRadius(27)
                } else if let taskStatus = service.userTaskStatus, taskStatus == "pending_payment",
                          let isPaid = service.userTaskIsPaid, !isPaid,
                          let taskId = service.userTaskId {
                    // 待支付且未支付，显示继续支付按钮
                    Button(action: {
                        paymentTaskId = taskId
                        showPaymentView = true
                    }) {
                        Text(LocalizationKey.serviceContinuePayment.localized)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(AppColors.primary)
                            .cornerRadius(27)
                            .shadow(color: AppColors.primary.opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                } else if let hasNegotiation = service.userApplicationHasNegotiation, hasNegotiation,
                          let appStatus = service.userApplicationStatus, appStatus == "pending" {
                    // 有议价且申请状态为pending，等待达人回应
                    Text(LocalizationKey.serviceWaitingExpertResponse.localized)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(AppColors.textQuaternary)
                        .cornerRadius(27)
                } else {
                    // 其他情况，显示已申请（灰色不可点击）
                    Text(LocalizationKey.serviceApplied.localized)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(AppColors.textQuaternary)
                        .cornerRadius(27)
                }
            } else {
                // 未申请，显示申请按钮
                Button(action: {
                    showApplySheet = true
                    HapticFeedback.selection()
                }) {
                    Text(LocalizationKey.taskExpertApplyService.localized)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(AppColors.primary)
                        .cornerRadius(27)
                        .shadow(color: AppColors.primary.opacity(0.3), radius: 8, x: 0, y: 4)
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .padding(.bottom, 24)
        .background(
            Rectangle()
                .fill(.ultraThinMaterial)
                .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: -5)
                .ignoresSafeArea(edges: .bottom)
        )
    }
}

// MARK: - Time Slot Card

struct TimeSlotCard: View {
    let slot: ServiceTimeSlot
    
    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(formatDateTime(slot.slotStartDatetime))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppColors.textPrimary)
                
                HStack(spacing: 4) {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 10))
                    Text("\(slot.currentParticipants)/\(slot.maxParticipants) \(LocalizationKey.activityPersonsBooked.localized)")
                        .font(.system(size: 11))
                }
                .foregroundColor(AppColors.textSecondary)
            }
            
            Spacer()
            
            if slot.isAvailable {
                Text("可选")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(AppColors.success)
                    .cornerRadius(8)
            } else {
                Text(LocalizationKey.taskExpertFull.localized)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(AppColors.textTertiary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(8)
            }
        }
        .padding(12)
        .background(AppColors.primaryLight.opacity(0.5))
        .cornerRadius(12)
    }
    
    private func formatDateTime(_ dateString: String) -> String {
        return DateFormatterHelper.shared.formatFullTime(dateString)
    }
}

// MARK: - Apply Service Sheet

struct ApplyServiceSheet: View {
    @Binding var message: String
    @Binding var counterPrice: Double?
    @Binding var showCounterPrice: Bool
    @Binding var selectedDeadline: Date?
    @Binding var isFlexible: Bool
    let hasTimeSlots: Bool
    @Binding var isSubmitting: Bool
    let onApply: () -> Void
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            ZStack {
            KeyboardAvoidingScrollView(extraPadding: 20) {
                VStack(spacing: 24) {
                    // 留言
                    VStack(alignment: .leading, spacing: 12) {
                        Text("申请留言")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(AppColors.textSecondary)
                        
                        TextEditor(text: $message)
                            .frame(height: 120)
                            .padding(12)
                            .scrollContentBackground(.hidden)
                            .background(Color(UIColor.secondarySystemBackground))
                            .cornerRadius(12)
                            .overlay(
                                Group {
                                    if message.isEmpty {
                                        Text(LocalizationKey.serviceNeedDescription.localized)
                                            .font(.system(size: 14))
                                            .foregroundColor(AppColors.textTertiary)
                                            .padding(.leading, 16)
                                            .padding(.top, 20)
                                            .allowsHitTesting(false)
                                    }
                                },
                                alignment: .topLeading
                            )
                    }
                    
                    // 议价
                    VStack(spacing: 16) {
                        Toggle(isOn: $showCounterPrice) {
                            HStack {
                                Image(systemName: "dollarsign.circle.fill")
                                    .foregroundColor(.orange)
                                Text("我想议价")
                                    .font(.system(size: 15, weight: .medium))
                            }
                        }
                        .tint(AppColors.primary)
                        
                        if showCounterPrice {
                            HStack {
                                Text("£")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(AppColors.textSecondary)
                                
                                TextField("期望价格", value: $counterPrice, format: .number)
                                    .keyboardType(.decimalPad)
                                    .font(.system(size: 20, weight: .bold, design: .rounded))
                            }
                            .padding(16)
                            .background(Color(UIColor.secondarySystemBackground))
                            .cornerRadius(12)
                            .transition(.move(edge: .top).combined(with: .opacity))
                        }
                    }
                    .padding(16)
                    .background(Color(UIColor.secondarySystemBackground).opacity(0.3))
                    .cornerRadius(16)
                    
                    // 日期和灵活模式（仅当服务没有时间段时显示）
                    if !hasTimeSlots {
                        VStack(spacing: 16) {
                            // 灵活模式选项
                            Toggle(isOn: $isFlexible) {
                                HStack {
                                    Image(systemName: "clock.fill")
                                        .foregroundColor(.blue)
                                    Text("灵活时间")
                                        .font(.system(size: 15, weight: .medium))
                                }
                            }
                            .tint(AppColors.primary)
                            
                            // 日期选择器（非灵活模式时显示）
                            if !isFlexible {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("期望完成日期")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(AppColors.textSecondary)
                                    
                                    DatePicker(
                                        "选择日期",
                                        selection: Binding(
                                            get: { 
                                                if let deadline = selectedDeadline {
                                                    return deadline
                                                } else {
                                                    // 默认选择7天后
                                                    let defaultDate = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
                                                    selectedDeadline = defaultDate
                                                    return defaultDate
                                                }
                                            },
                                            set: { selectedDeadline = $0 }
                                        ),
                                        in: Date()..., // 只能选择今天及以后的日期
                                        displayedComponents: [.date]
                                    )
                                    .datePickerStyle(.compact)
                                    .padding(12)
                                    .background(Color(UIColor.secondarySystemBackground))
                                    .cornerRadius(12)
                                }
                            }
                        }
                        .padding(16)
                        .background(Color(UIColor.secondarySystemBackground).opacity(0.3))
                        .cornerRadius(16)
                    }
                    
                    Spacer(minLength: 40)
                }
                .padding(24)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color(UIColor.systemBackground))
            .navigationTitle("申请服务")
            .navigationBarTitleDisplayMode(.inline)
            .enableSwipeBack()
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") { dismiss() }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        guard !isSubmitting else { return }
                        if !hasTimeSlots && !isFlexible && selectedDeadline == nil {
                            selectedDeadline = Calendar.current.date(byAdding: .day, value: 7, to: Date())
                        }
                        isSubmitting = true
                        onApply()
                    }) {
                        Text("提交")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(AppColors.primary)
                            .clipShape(Capsule())
                    }
                    .disabled(isSubmitting)
                }
            }
            if isSubmitting {
                LoadingOverlay(message: LocalizationKey.commonSubmitting.localized)
            }
            }
        }
    }
}
