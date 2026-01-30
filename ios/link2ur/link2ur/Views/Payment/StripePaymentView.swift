import SwiftUI
import StripePaymentSheet

struct StripePaymentView: View {
    let taskId: Int
    let amount: Double
    let clientSecret: String?
    let customerId: String?
    let ephemeralKeySecret: String?
    let taskTitle: String?
    let applicantName: String?
    let paymentExpiresAt: String?  // 支付过期时间（ISO 格式）
    let onPaymentSuccess: (() -> Void)?
    
    @StateObject private var viewModel: PaymentViewModel
    @Environment(\.dismiss) var dismiss
    @StateObject private var keyboardObserver = KeyboardHeightObserver()
    @State private var showSuccessOverlay = false

    init(taskId: Int, amount: Double, clientSecret: String? = nil, customerId: String? = nil, ephemeralKeySecret: String? = nil, taskTitle: String? = nil, applicantName: String? = nil, paymentExpiresAt: String? = nil, onPaymentSuccess: (() -> Void)? = nil) {
        Logger.debug("StripePaymentView init - taskId: \(taskId), clientSecret: \(clientSecret?.prefix(20) ?? "nil")...", category: .api)
        self.taskId = taskId
        self.amount = amount
        self.clientSecret = clientSecret
        self.customerId = customerId
        self.ephemeralKeySecret = ephemeralKeySecret
        self.taskTitle = taskTitle
        self.applicantName = applicantName
        self.paymentExpiresAt = paymentExpiresAt
        self.onPaymentSuccess = onPaymentSuccess
        _viewModel = StateObject(
            wrappedValue: PaymentViewModel(
                taskId: taskId,
                amount: amount,
                clientSecret: clientSecret,
                customerId: customerId,
                ephemeralKeySecret: ephemeralKeySecret
            )
        )
        Logger.debug("StripePaymentView init 完成", category: .api)
    }
    
    var body: some View {
        NavigationView {
            KeyboardAvoidingScrollView(extraPadding: 20) {
                VStack(spacing: 24) {
                    // 支付倒计时横幅
                    if let paymentExpiresAt = paymentExpiresAt, !paymentExpiresAt.isEmpty {
                        PaymentCountdownBanner(expiresAt: paymentExpiresAt)
                            .padding(.horizontal)
                    }
                    
                    if viewModel.isLoading {
                        ListSkeleton(itemCount: 5, itemHeight: 56)
                            .padding(.vertical, AppSpacing.md)
                            .frame(maxWidth: .infinity, minHeight: 400)
                    } else if viewModel.paymentSuccess {
                        paymentSuccessView
                    } else if let error = viewModel.errorMessage {
                        paymentErrorView(error: error)
                    } else if let paymentResponse = viewModel.paymentResponse {
                        paymentInfoView(paymentResponse: paymentResponse)
                    } else if clientSecret != nil {
                        // 批准申请支付：外部已提供 PaymentIntent client_secret，此时 paymentResponse 可能为空
                        approvalPaymentFallbackView
                    } else {
                        ListSkeleton(itemCount: 5, itemHeight: 56)
                            .padding(.vertical, AppSpacing.md)
                            .frame(maxWidth: .infinity, minHeight: 400)
                    }
                }
                .padding()
            }
            .navigationTitle(LocalizationKey.paymentPayment.localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(LocalizationKey.paymentCancel.localized) {
                        dismiss()
                    }
                    .foregroundColor(AppColors.primary)
                }
            }
            .overlay {
                if showSuccessOverlay {
                    OperationResultOverlay(
                        isPresented: $showSuccessOverlay,
                        type: .success,
                        message: LocalizationKey.paymentSuccess.localized,
                        autoDismissSeconds: 1.5,
                        onDismiss: {}
                    )
                }
            }
            .onChange(of: viewModel.paymentSuccess) { newValue in
                if newValue { showSuccessOverlay = true }
            }
            .onAppear {
                // ⚠️ 检查支付是否已过期
                if let paymentExpiresAt = paymentExpiresAt, !paymentExpiresAt.isEmpty {
                    let formatter = ISO8601DateFormatter()
                    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                    
                    var expiryDate: Date?
                    if let date = formatter.date(from: paymentExpiresAt) {
                        expiryDate = date
                    } else {
                        formatter.formatOptions = [.withInternetDateTime]
                        expiryDate = formatter.date(from: paymentExpiresAt)
                    }
                    
                    if let expiryDate = expiryDate, Date() >= expiryDate {
                        // 支付已过期，显示错误信息
                        viewModel.errorMessage = LocalizationKey.paymentCountdownExpired.localized
                        return
                    }
                }
                
                // 🔍 先检查支付状态（防止闪退后重复支付）
                // 如果支付已在后台完成（例如支付宝跳转后闪退），直接显示成功
                viewModel.checkPaymentStatus { alreadyPaid in
                    if alreadyPaid {
                        // 支付已完成，不需要再创建支付意图
                        Logger.info("支付状态检查：已完成支付，跳过创建支付意图", category: .api)
                        return
                    }
                    
                    // 支付未完成，继续正常流程
                    // 如果没有提供 client_secret，才调用 API 创建支付意图
                    if self.clientSecret == nil {
                        self.viewModel.createPaymentIntent()
                    } else {
                        // 已提供 client_secret：立即初始化 PaymentSheet，减少延迟
                        // 移除延迟，因为 sheet 已经显示，可以立即初始化
                        self.viewModel.ensurePaymentSheetReady()
                    }
                }
                
                // 延迟加载优惠券，避免阻塞支付页面初始化
                // 使用异步延迟，让支付页面先显示，然后后台加载优惠券
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    viewModel.loadAvailableCoupons()
                }
            }
            .alert(LocalizationKey.paymentError.localized, isPresented: .constant(viewModel.errorMessage != nil && !viewModel.isLoading)) {
                Button(LocalizationKey.commonOk.localized, role: .cancel) {
                    viewModel.errorMessage = nil
                }
                if viewModel.paymentSheet != nil {
                    Button(LocalizationKey.paymentRetry.localized) {
                        viewModel.errorMessage = nil
                        // 获取当前视图控制器并弹出 PaymentSheet
                        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                           let rootViewController = windowScene.windows.first?.rootViewController {
                            var topViewController = rootViewController
                            while let presented = topViewController.presentedViewController {
                                topViewController = presented
                            }
                            if let paymentSheet = viewModel.paymentSheet {
                                paymentSheet.present(from: topViewController) { result in
                                    viewModel.handlePaymentResult(result)
                                }
                            }
                        }
                    }
                }
            } message: {
                if let error = viewModel.errorMessage {
                    Text(error)
                }
            }
        }
    }
    
    // MARK: - Payment Success View
    private var paymentSuccessView: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(AppColors.success)
            
            Text(LocalizationKey.paymentSuccess.localized)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(AppColors.textPrimary)
            
            Text(LocalizationKey.paymentSuccessMessage.localized)
                .font(.subheadline)
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 400)
        .onAppear {
            // 等待后端 webhook 处理完成（通常需要 1-2 秒）
            // 然后调用成功回调，让父视图刷新任务状态
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                onPaymentSuccess?()
            }
        }
    }
    
    // MARK: - Payment Error View
    private func paymentErrorView(error: String) -> some View {
        VStack(spacing: 24) {
            VStack(spacing: 16) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(AppColors.error)
                
                Text(LocalizationKey.paymentError.localized)
                    .font(AppTypography.title2)
                    .foregroundColor(AppColors.textPrimary)
                
                Text(error)
                    .font(AppTypography.body)
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacing.md)
            }
            .padding(AppSpacing.xl)
            .frame(maxWidth: .infinity)
            .background(AppColors.cardBackground)
            .cornerRadius(AppCornerRadius.large)
            .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
            
            VStack(spacing: 12) {
                Button(LocalizationKey.paymentRetryPayment.localized) {
                    if viewModel.paymentSheet != nil {
                        viewModel.errorMessage = nil
                        // 获取当前视图控制器并弹出 PaymentSheet
                        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                           let rootViewController = windowScene.windows.first?.rootViewController {
                            var topViewController = rootViewController
                            while let presented = topViewController.presentedViewController {
                                topViewController = presented
                            }
                            if let paymentSheet = viewModel.paymentSheet {
                                paymentSheet.present(from: topViewController) { result in
                                    viewModel.handlePaymentResult(result)
                                }
                            }
                        }
                    } else {
                        viewModel.errorMessage = nil
                        viewModel.createPaymentIntent()
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .frame(maxWidth: .infinity)
                
                Button(LocalizationKey.commonBack.localized) {
                    dismiss()
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .frame(maxWidth: .infinity)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, minHeight: 400)
    }
    
    // MARK: - Payment Info View with Embedded Payment Element
    @ViewBuilder
    private func paymentInfoView(paymentResponse: PaymentResponse) -> some View {
        VStack(spacing: 24) {
            // 任务信息卡片
            if taskTitle != nil || applicantName != nil {
                VStack(alignment: .leading, spacing: 16) {
                    // 标题
                    HStack {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(AppColors.primary)
                            .font(.system(size: 18))
                        Text(LocalizationKey.paymentTaskInfo.localized)
                            .font(AppTypography.title3)
                            .foregroundColor(AppColors.textPrimary)
                        Spacer()
                    }
                    
                    Divider()
                    
                    // 任务标题
                    if let taskTitle = taskTitle {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 8) {
                                Image(systemName: "list.bullet.rectangle")
                                    .foregroundColor(AppColors.textSecondary)
                                    .font(.system(size: 14))
                                Text(LocalizationKey.paymentTaskTitle.localized)
                                    .font(AppTypography.subheadline)
                                    .foregroundColor(AppColors.textSecondary)
                            }
                            
                            Text(taskTitle)
                                .font(AppTypography.bodyBold)
                                .foregroundColor(AppColors.textPrimary)
                                .lineLimit(3)
                        }
                    }
                    
                    // 申请者名字
                    if let applicantName = applicantName {
                        if taskTitle != nil {
                            Divider()
                        }
                        
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 8) {
                                Image(systemName: "person.fill")
                                    .foregroundColor(AppColors.textSecondary)
                                    .font(.system(size: 14))
                                Text(LocalizationKey.paymentApplicant.localized)
                                    .font(AppTypography.subheadline)
                                    .foregroundColor(AppColors.textSecondary)
                            }
                            
                            Text(applicantName)
                                .font(AppTypography.bodyBold)
                                .foregroundColor(AppColors.textPrimary)
                        }
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppColors.cardBackground)
                .cornerRadius(AppCornerRadius.large)
                .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
            }
            
            // 优惠券选择卡片
            couponSelectionCard
            
            // 支付信息卡片（显示详细计算过程）
            VStack(spacing: 16) {
                // 如果有计算步骤，使用计算步骤显示
                if let calculationSteps = paymentResponse.calculationSteps, !calculationSteps.isEmpty {
                    ForEach(Array(calculationSteps.enumerated()), id: \.offset) { index, step in
                        if index > 0 {
                            Divider()
                        }
                        PaymentInfoRow(
                            label: step.label,
                            value: step.amountDisplay,
                            currency: paymentResponse.currency,
                            isHighlighted: step.type == "discount" || step.type == "final",
                            icon: step.type == "discount" ? "tag.fill" : nil,
                            iconColor: step.type == "discount" ? .green : nil,
                            isFinal: step.type == "final"
                        )
                    }
                } else {
                    // 兼容旧格式：如果没有计算步骤，使用原有显示方式
                    // 原始金额
                    PaymentInfoRow(
                        label: LocalizationKey.paymentTotalAmount.localized,
                        value: paymentResponse.originalAmountDisplay,
                        currency: paymentResponse.currency,
                        isHighlighted: false
                    )
                    
                    // 优惠券折扣（如果有）
                    if let couponDiscount = paymentResponse.couponDiscountDisplay, !couponDiscount.isEmpty {
                        Divider()
                        PaymentInfoRow(
                            label: LocalizationKey.paymentCouponDiscount.localized + (paymentResponse.couponName != nil ? "（\(paymentResponse.couponName!)）" : ""),
                            value: "-\(couponDiscount)",
                            currency: paymentResponse.currency,
                            isHighlighted: true,
                            icon: "tag.fill",
                            iconColor: .green
                        )
                    }
                    
                    // 最终支付金额
                    Divider()
                    PaymentInfoRow(
                        label: LocalizationKey.paymentFinalPayment.localized,
                        value: paymentResponse.finalAmountDisplay,
                        currency: paymentResponse.currency,
                        isHighlighted: true,
                        isFinal: true
                    )
                }
            }
            .padding()
            .background(AppColors.cardBackground)
            .cornerRadius(AppCornerRadius.large)
            .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
            
            // 备注信息（如果有）
            if !paymentResponse.note.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(AppColors.primary)
                        Text(LocalizationKey.paymentTip.localized)
                            .font(AppTypography.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(AppColors.textPrimary)
                    }
                    
                    Text(paymentResponse.note)
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppColors.primary.opacity(0.1))
                .cornerRadius(AppCornerRadius.medium)
            }
            
            // 支付方式选择卡片
            paymentMethodSelectionCard
                .transaction { transaction in
                    // 禁用支付方式选择卡片的隐式动画，确保切换流畅
                    transaction.animation = nil
                }
            
            // 支付按钮
            paymentButton
        }
        .padding(.vertical)
    }

    // MARK: - Approval Payment Fallback View (client_secret provided, no paymentResponse)
    private var approvalPaymentFallbackView: some View {
        VStack(spacing: 24) {
            // 任务信息卡片（如果有）
            if taskTitle != nil || applicantName != nil {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(AppColors.primary)
                            .font(.system(size: 18))
                        Text(LocalizationKey.paymentTaskInfo.localized)
                            .font(AppTypography.title3)
                            .foregroundColor(AppColors.textPrimary)
                        Spacer()
                    }
                    Divider()

                    if let taskTitle = taskTitle {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 8) {
                                Image(systemName: "list.bullet.rectangle")
                                    .foregroundColor(AppColors.textSecondary)
                                    .font(.system(size: 14))
                                Text(LocalizationKey.paymentTaskTitle.localized)
                                    .font(AppTypography.subheadline)
                                    .foregroundColor(AppColors.textSecondary)
                            }
                            Text(taskTitle)
                                .font(AppTypography.bodyBold)
                                .foregroundColor(AppColors.textPrimary)
                                .lineLimit(3)
                        }
                    }

                    if let applicantName = applicantName {
                        if taskTitle != nil { Divider() }
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 8) {
                                Image(systemName: "person.fill")
                                    .foregroundColor(AppColors.textSecondary)
                                    .font(.system(size: 14))
                                Text(LocalizationKey.paymentApplicant.localized)
                                    .font(AppTypography.subheadline)
                                    .foregroundColor(AppColors.textSecondary)
                            }
                            Text(applicantName)
                                .font(AppTypography.bodyBold)
                                .foregroundColor(AppColors.textPrimary)
                        }
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppColors.cardBackground)
                .cornerRadius(AppCornerRadius.large)
                .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
            }

            // 金额卡片（简化版）
            VStack(spacing: 16) {
                PaymentInfoRow(
                    label: LocalizationKey.paymentFinalPayment.localized,
                    value: String(format: "%.2f", amount),
                    currency: "GBP",
                    isHighlighted: true,
                    isFinal: true
                )
            }
            .padding()
            .background(AppColors.cardBackground)
            .cornerRadius(AppCornerRadius.large)
            .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)

            // 支付方式选择 + 支付按钮
            paymentMethodSelectionCard
            paymentButton
        }
        .padding(.vertical)
    }
    
    // MARK: - Payment Button
    
    @ViewBuilder
    private var paymentButton: some View {
        if viewModel.selectedPaymentMethod == .card {
            // 信用卡支付按钮
            if viewModel.isSwitchingPaymentMethod {
                paymentMethodSwitchPlaceholderButton(
                    gradient: LinearGradient(gradient: Gradient(colors: AppColors.gradientPrimary), startPoint: .leading, endPoint: .trailing)
                ) {
                    Image(systemName: "lock.shield.fill").font(.system(size: 18))
                }
            } else if viewModel.paymentSheet != nil {
                Button(action: { viewModel.performPayment() }) {
                    HStack(spacing: 12) {
                        if viewModel.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .frame(width: 18, height: 18)
                        } else {
                            Image(systemName: "lock.shield.fill").font(.system(size: 18))
                        }
                        Text(viewModel.isLoading ? LocalizationKey.paymentPreparingPayment.localized : LocalizationKey.paymentConfirmPayment.localized)
                            .font(AppTypography.title3)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppSpacing.md)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: AppColors.gradientPrimary),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(AppCornerRadius.large)
                    .shadow(color: AppColors.primary.opacity(0.3), radius: 8, x: 0, y: 4)
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(viewModel.isLoading)
                .opacity(viewModel.isLoading ? 0.8 : 1)
            } else {
                paymentFormLoadingView {
                    viewModel.ensurePaymentSheetReady()
                }
            }
        } else if viewModel.selectedPaymentMethod == .applePay {
            // Apple Pay 按钮
            if viewModel.hasActivePaymentClientSecret {
                Button(action: {
                    viewModel.performPayment()
                }) {
                    HStack(spacing: 12) {
                        if viewModel.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .frame(width: 18, height: 18)
                        } else {
                            Image(systemName: "applelogo")
                                .font(.system(size: 18))
                        }
                        Text(viewModel.isLoading ? LocalizationKey.paymentPreparingPayment.localized : LocalizationKey.paymentPayWithApplePay.localized)
                            .font(AppTypography.title3)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppSpacing.md)
                    .background(Color.black)
                    .cornerRadius(AppCornerRadius.large)
                    .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(viewModel.isLoading)
                .opacity(viewModel.isLoading ? 0.8 : 1)
            } else {
                // 加载状态
                VStack(spacing: 16) {
                    CompactLoadingView()
                    Text(LocalizationKey.paymentPreparingPayment.localized)
                        .font(AppTypography.subheadline)
                        .foregroundColor(AppColors.textSecondary)
                }
                .frame(maxWidth: .infinity, minHeight: 100)
                .padding()
            }
        } else if viewModel.selectedPaymentMethod == .wechatPay {
            // 微信支付按钮（使用直接跳转方式）
            if viewModel.isSwitchingPaymentMethod || viewModel.isProcessingDirectPayment {
                // 准备中或正在处理支付
                paymentMethodSwitchPlaceholderButton(
                    gradient: LinearGradient(
                        gradient: Gradient(colors: [Color(red: 0.2, green: 0.8, blue: 0.2), Color(red: 0.1, green: 0.7, blue: 0.1)]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                ) {
                    if viewModel.isProcessingDirectPayment {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .frame(width: 18, height: 18)
                    } else {
                        SwiftUI.Image("WeChatPayLogo")
                            .renderingMode(SwiftUI.Image.TemplateRenderingMode.template)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 18, height: 18)
                            .foregroundColor(SwiftUI.Color.white)
                    }
                }
            } else if viewModel.hasActivePaymentClientSecret {
                // 有 client_secret，可以支付
                Button(action: { viewModel.performPayment() }) {
                    HStack(spacing: 12) {
                        if viewModel.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .frame(width: 18, height: 18)
                        } else {
                            SwiftUI.Image("WeChatPayLogo")
                                .renderingMode(SwiftUI.Image.TemplateRenderingMode.template)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 18, height: 18)
                                .foregroundColor(SwiftUI.Color.white)
                        }
                        Text(viewModel.isLoading ? LocalizationKey.paymentPreparingPayment.localized : LocalizationKey.paymentPayWithWeChatPay.localized)
                            .font(AppTypography.title3)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppSpacing.md)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [Color(red: 0.2, green: 0.8, blue: 0.2), Color(red: 0.1, green: 0.7, blue: 0.1)]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(AppCornerRadius.large)
                    .shadow(color: Color.green.opacity(0.3), radius: 8, x: 0, y: 4)
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(viewModel.isLoading)
                .opacity(viewModel.isLoading ? 0.8 : 1)
            } else {
                // 加载 PaymentIntent 中
                paymentFormLoadingView { viewModel.createPaymentIntent(isMethodSwitch: true) }
            }
        } else if viewModel.selectedPaymentMethod == .alipayPay {
            // 支付宝支付按钮（使用直接跳转方式）
            if viewModel.isSwitchingPaymentMethod || viewModel.isProcessingDirectPayment {
                // 准备中或正在处理支付
                paymentMethodSwitchPlaceholderButton(
                    gradient: LinearGradient(
                        gradient: Gradient(colors: [Color(red: 0.2, green: 0.5, blue: 0.95), Color(red: 0.1, green: 0.4, blue: 0.9)]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                ) {
                    if viewModel.isProcessingDirectPayment {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .frame(width: 18, height: 18)
                    } else {
                        SwiftUI.Image("AlipayLogo")
                            .renderingMode(SwiftUI.Image.TemplateRenderingMode.original)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 18, height: 18)
                    }
                }
            } else if viewModel.hasActivePaymentClientSecret {
                // 有 client_secret，可以支付
                Button(action: { viewModel.performPayment() }) {
                    HStack(spacing: 12) {
                        if viewModel.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .frame(width: 18, height: 18)
                        } else {
                            SwiftUI.Image("AlipayLogo")
                                .renderingMode(SwiftUI.Image.TemplateRenderingMode.original)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 18, height: 18)
                        }
                        Text(viewModel.isLoading ? LocalizationKey.paymentPreparingPayment.localized : LocalizationKey.paymentPayWithAlipay.localized)
                            .font(AppTypography.title3)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppSpacing.md)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [Color(red: 0.2, green: 0.5, blue: 0.95), Color(red: 0.1, green: 0.4, blue: 0.9)]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(AppCornerRadius.large)
                    .shadow(color: Color.blue.opacity(0.3), radius: 8, x: 0, y: 4)
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(viewModel.isLoading)
                .opacity(viewModel.isLoading ? 0.8 : 1)
            } else {
                // 加载 PaymentIntent 中
                paymentFormLoadingView { viewModel.createPaymentIntent(isMethodSwitch: true) }
            }
        } else {
            // 默认加载状态
            VStack(spacing: 16) {
                CompactLoadingView()
                Text(LocalizationKey.paymentPreparingPayment.localized)
                    .font(AppTypography.subheadline)
                    .foregroundColor(AppColors.textSecondary)
            }
            .frame(maxWidth: .infinity, minHeight: 100)
            .padding()
        }
    }
    
    /// 切换支付方式时的占位按钮：与真实按钮同款样式，禁用态 +「准备支付…」
    @ViewBuilder
    private func paymentMethodSwitchPlaceholderButton<Icon: View>(
        gradient: LinearGradient,
        @ViewBuilder icon: () -> Icon
    ) -> some View {
        HStack(spacing: 12) {
            icon()
            Text(LocalizationKey.paymentPreparing.localized)
                .font(AppTypography.title3)
                .fontWeight(.semibold)
        }
        .foregroundColor(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.md)
        .background(gradient)
        .cornerRadius(AppCornerRadius.large)
        .opacity(0.85)
        .allowsHitTesting(false)
    }
    
    /// 「正在加载支付表单」区块，onAppear 时执行 onPrepare（如 ensurePaymentSheetReady）
    @ViewBuilder
    private func paymentFormLoadingView(onPrepare: @escaping () -> Void) -> some View {
        VStack(spacing: 16) {
            CompactLoadingView()
            Text(LocalizationKey.paymentPreparingPayment.localized)
                .font(AppTypography.subheadline)
                .foregroundColor(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity, minHeight: 100)
        .padding()
        .onAppear { onPrepare() }
    }
    
    // MARK: - Payment Method Selection Card
    
    private var paymentMethodSelectionCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 标题
            HStack {
                Image(systemName: "creditcard.fill")
                    .foregroundColor(AppColors.primary)
                    .font(.system(size: 18))
                Text(LocalizationKey.paymentSelectMethod.localized)
                    .font(AppTypography.title3)
                    .foregroundColor(AppColors.textPrimary)
                Spacer()
            }
            
            Divider()
            
            // 支付方式选项
            // 注意：paymentInfoView 只有在 paymentResponse 存在时才会显示
            // 所以这里可以安全地假设 viewModel.paymentResponse 存在
            VStack(spacing: 12) {
                // 信用卡/借记卡选项
                PaymentMethodOption(
                    method: .card,
                    isSelected: viewModel.selectedPaymentMethod == .card,
                    isAvailable: true  // 允许用户自由切换
                ) {
                    // 禁用动画，立即响应
                    withTransaction(Transaction(animation: nil)) {
                        viewModel.selectPaymentMethod(.card)
                    }
                }
                
                // Apple Pay 选项（仅在设备支持时显示）
                if viewModel.isApplePaySupported {
                    PaymentMethodOption(
                        method: .applePay,
                        isSelected: viewModel.selectedPaymentMethod == .applePay,
                        isAvailable: true  // 允许用户自由切换
                    ) {
                        // 禁用动画，立即响应
                        withTransaction(Transaction(animation: nil)) {
                            viewModel.selectPaymentMethod(.applePay)
                        }
                    }
                }
                
                // 微信支付选项（需在 Stripe Dashboard 启用 WeChat Pay）
                PaymentMethodOption(
                    method: .wechatPay,
                    isSelected: viewModel.selectedPaymentMethod == .wechatPay,
                    isAvailable: true
                ) {
                    withTransaction(Transaction(animation: nil)) {
                        viewModel.selectPaymentMethod(.wechatPay)
                    }
                }
                
                // 支付宝选项
                PaymentMethodOption(
                    method: .alipayPay,
                    isSelected: viewModel.selectedPaymentMethod == .alipayPay,
                    isAvailable: true
                ) {
                    withTransaction(Transaction(animation: nil)) {
                        viewModel.selectPaymentMethod(.alipayPay)
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.cardBackground)
        .cornerRadius(AppCornerRadius.large)
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
    }
    
    // MARK: - Payment Method Option
    
    struct PaymentMethodOption: View {
        let method: PaymentMethodType
        let isSelected: Bool
        let isAvailable: Bool
        let action: () -> Void
        
        var body: some View {
            Button(action: action) {
                HStack(spacing: 16) {
                    // 图标：统一 40×40 圆形容器，微信/支付宝 logo 缩小至与 Apple Pay 相当并裁成圆形
                    ZStack {
                        Circle()
                            .fill(isSelected ? AppColors.primary.opacity(0.1) : AppColors.surface)
                        if method.isAssetIcon {
                            Image(method.icon)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 24, height: 24)
                                .clipShape(Circle())
                        } else {
                            Image(systemName: method.icon)
                                .font(.system(size: 24))
                                .foregroundColor(isSelected ? AppColors.primary : AppColors.textSecondary)
                        }
                    }
                    .frame(width: 40, height: 40)
                    
                    // 名称
                    Text(method.displayName)
                        .font(AppTypography.body)
                        .foregroundColor(isAvailable ? AppColors.textPrimary : AppColors.textSecondary)
                    
                    Spacer()
                    
                    // 选中指示器
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(AppColors.primary)
                            .font(.system(size: 20))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading) // 确保填满整个宽度
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
                .background(
                    RoundedRectangle(cornerRadius: AppCornerRadius.medium)
                        .fill(isSelected ? AppColors.primary.opacity(0.05) : Color.clear)
                        .overlay(
                            RoundedRectangle(cornerRadius: AppCornerRadius.medium)
                                .stroke(isSelected ? AppColors.primary : AppColors.separator, lineWidth: isSelected ? 2 : 1)
                        )
                )
                .contentShape(Rectangle()) // 确保整个矩形区域都可以点击
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(!isAvailable)
            .opacity(isAvailable ? 1.0 : 0.6)
            .transaction { transaction in
                // 禁用切换时的隐式动画，确保立即响应
                transaction.animation = nil
            }
        }
    }
    
    // MARK: - Coupon Selection Card
    @ViewBuilder
    private var couponSelectionCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 标题
            HStack {
                Image(systemName: "tag.fill")
                    .foregroundColor(AppColors.primary)
                    .font(.system(size: 18))
                Text(LocalizationKey.paymentCoupons.localized)
                    .font(AppTypography.title3)
                    .foregroundColor(AppColors.textPrimary)
                Spacer()
                
                if viewModel.isLoadingCoupons {
                    CompactLoadingView()
                }
            }
            
            Divider()
            
            // 已选择的优惠券
            if let selectedCoupon = viewModel.selectedCoupon {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(selectedCoupon.coupon.name)
                                .font(AppTypography.bodyBold)
                                .foregroundColor(AppColors.textPrimary)
                            
                            Text(String(format: LocalizationKey.couponDiscount.localized, selectedCoupon.coupon.discountValueDisplay))
                                .font(AppTypography.caption)
                                .foregroundColor(AppColors.success)
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            viewModel.removeCoupon()
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(AppColors.textSecondary)
                                .font(.system(size: 20))
                        }
                    }
                    .padding()
                    .background(AppColors.success.opacity(0.1))
                    .cornerRadius(AppCornerRadius.medium)
                }
            } else {
                // 优惠券列表
                if viewModel.availableCoupons.isEmpty {
                    HStack {
                        Image(systemName: "tag.slash")
                            .foregroundColor(AppColors.textTertiary)
                        Text(LocalizationKey.paymentNoAvailableCoupons.localized)
                            .font(AppTypography.subheadline)
                            .foregroundColor(AppColors.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(viewModel.availableCoupons) { coupon in
                                CouponCard(
                                    coupon: coupon,
                                    isSelected: viewModel.selectedCoupon?.id == coupon.id,
                                    onSelect: {
                                        viewModel.selectCoupon(coupon)
                                    }
                                )
                            }
                        }
                        .padding(.horizontal, 4)
                    }
                }
            }
        }
        .padding()
        .background(AppColors.cardBackground)
        .cornerRadius(AppCornerRadius.large)
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
    }
}

// MARK: - Coupon Card
struct CouponCard: View {
    let coupon: UserCoupon
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(coupon.coupon.name)
                            .font(AppTypography.bodyBold)
                            .foregroundColor(isSelected ? .white : AppColors.textPrimary)
                            .lineLimit(1)
                        
                        Text(coupon.coupon.discountValueDisplay)
                            .font(AppTypography.caption)
                            .foregroundColor(isSelected ? .white.opacity(0.9) : AppColors.success)
                    }
                    
                    Spacer()
                    
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.white)
                            .font(.system(size: 20))
                    }
                }
                
                if let minAmount = Int(coupon.coupon.minAmountDisplay.replacingOccurrences(of: "£", with: "").replacingOccurrences(of: ",", with: "")),
                   minAmount > 0 {
                    Text(String(format: LocalizationKey.couponMinAmountAvailable.localized, coupon.coupon.minAmountDisplay))
                        .font(AppTypography.caption2)
                        .foregroundColor(isSelected ? .white.opacity(0.8) : AppColors.textSecondary)
                }
            }
            .padding(12)
            .frame(width: 160)
            .background(
                isSelected
                    ? LinearGradient(
                        gradient: Gradient(colors: AppColors.gradientPrimary),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    : LinearGradient(
                        gradient: Gradient(colors: [AppColors.surface, AppColors.surface]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
            )
            .cornerRadius(AppCornerRadius.medium)
            .overlay(
                RoundedRectangle(cornerRadius: AppCornerRadius.medium)
                    .stroke(isSelected ? Color.clear : AppColors.separator, lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Payment Info Row
struct PaymentInfoRow: View {
    let label: String
    let value: String
    let currency: String
    let isHighlighted: Bool
    var icon: String? = nil
    var iconColor: Color? = nil
    var isFinal: Bool = false
    
    var body: some View {
        HStack {
            // 图标（如果有）
            if let icon = icon, let iconColor = iconColor {
                Image(systemName: icon)
                    .foregroundColor(iconColor)
                    .font(.system(size: 16))
            }
            
            // 标签
            Text(label)
                .font(isFinal ? AppTypography.bodyBold : AppTypography.body)
                .foregroundColor(AppColors.textPrimary)
            
            Spacer()
            
            // 金额
            Text(formatAmount(value, currency: currency))
                .font(isFinal ? .system(size: 24, weight: .bold, design: .rounded) : AppTypography.bodyBold)
                .foregroundColor(isHighlighted ? (isFinal ? AppColors.primary : AppColors.success) : AppColors.textPrimary)
        }
    }
    
    private func formatAmount(_ value: String, currency: String) -> String {
        // 如果 value 已经包含货币符号，直接返回
        if value.contains("£") || value.contains("$") {
            return value
        }
        
        // 否则添加货币符号
        let currencySymbol = currency == "GBP" ? "£" : (currency == "USD" ? "$" : currency)
        return "\(currencySymbol)\(value)"
    }
}


// MARK: - Payment Sheet UIViewController 包装器（备用，用于弹出式）
struct PaymentSheetViewController: UIViewControllerRepresentable {
    let paymentSheet: PaymentSheet
    let onResult: (PaymentSheetResult) -> Void
    
    func makeUIViewController(context: Context) -> UIViewController {
        let vc = UIViewController()
        
        DispatchQueue.main.async {
            paymentSheet.present(from: vc) { result in
                onResult(result)
            }
        }
        
        return vc
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}
