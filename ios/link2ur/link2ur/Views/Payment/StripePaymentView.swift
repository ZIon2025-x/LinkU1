import SwiftUI
import StripePaymentSheet

struct StripePaymentView: View {
    let taskId: Int
    let amount: Double
    let clientSecret: String?
    let taskTitle: String?
    let applicantName: String?
    let onPaymentSuccess: (() -> Void)?
    
    @StateObject private var viewModel: PaymentViewModel
    @Environment(\.dismiss) var dismiss
    @StateObject private var keyboardObserver = KeyboardHeightObserver()
    
    init(taskId: Int, amount: Double, clientSecret: String? = nil, taskTitle: String? = nil, applicantName: String? = nil, onPaymentSuccess: (() -> Void)? = nil) {
        self.taskId = taskId
        self.amount = amount
        self.clientSecret = clientSecret
        self.taskTitle = taskTitle
        self.applicantName = applicantName
        self.onPaymentSuccess = onPaymentSuccess
        _viewModel = StateObject(wrappedValue: PaymentViewModel(taskId: taskId, amount: amount, clientSecret: clientSecret))
    }
    
    var body: some View {
        NavigationView {
            KeyboardAvoidingScrollView(extraPadding: 20) {
                VStack(spacing: 24) {
                    if viewModel.isLoading {
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.5)
                            Text("正在加载支付表单...")
                                .foregroundColor(AppColors.textSecondary)
                        }
                        .frame(maxWidth: .infinity, minHeight: 400)
                    } else if viewModel.paymentSuccess {
                        paymentSuccessView
                    } else if let error = viewModel.errorMessage {
                        paymentErrorView(error: error)
                    } else if let paymentResponse = viewModel.paymentResponse {
                        paymentInfoView(paymentResponse: paymentResponse)
                    } else {
                        VStack(spacing: 16) {
                            ProgressView()
                            Text("准备支付...")
                                .foregroundColor(AppColors.textSecondary)
                        }
                        .frame(maxWidth: .infinity, minHeight: 400)
                    }
                }
                .padding()
            }
            .navigationTitle("支付")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                    .foregroundColor(AppColors.primary)
                }
            }
            .onAppear {
                // 如果没有提供 client_secret，才调用 API 创建支付意图
                if clientSecret == nil {
                    viewModel.createPaymentIntent()
                }
            }
            .alert("支付错误", isPresented: .constant(viewModel.errorMessage != nil && !viewModel.isLoading)) {
                Button("确定", role: .cancel) {
                    viewModel.errorMessage = nil
                }
                if viewModel.paymentSheet != nil {
                    Button("重试") {
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
            
            Text("支付成功！")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(AppColors.textPrimary)
            
            Text("任务已成功支付，正在更新状态...")
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
                
                Text("支付错误")
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
                Button("重试支付") {
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
                
                Button("返回") {
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
                        Text("任务信息")
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
                                Text("任务标题")
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
                                Text("申请者")
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
            
            // 支付信息卡片
            VStack(spacing: 16) {
                // 总金额
                PaymentInfoRow(
                    label: "总金额",
                    value: paymentResponse.totalAmountDisplay,
                    currency: paymentResponse.currency,
                    isHighlighted: false
                )
                
                // 积分抵扣（如果有）
                if let pointsUsed = paymentResponse.pointsUsedDisplay, !pointsUsed.isEmpty {
                    Divider()
                    PaymentInfoRow(
                        label: "积分抵扣",
                        value: "-\(pointsUsed)",
                        currency: paymentResponse.currency,
                        isHighlighted: true,
                        icon: "star.fill",
                        iconColor: .orange
                    )
                }
                
                // 优惠券折扣（如果有）
                if let couponDiscount = paymentResponse.couponDiscountDisplay, !couponDiscount.isEmpty {
                    Divider()
                    PaymentInfoRow(
                        label: "优惠券折扣",
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
                    label: "最终支付",
                    value: paymentResponse.finalAmountDisplay,
                    currency: paymentResponse.currency,
                    isHighlighted: true,
                    isFinal: true
                )
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
                        Text("提示")
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
            
            // 支付按钮
            if viewModel.paymentSheet != nil {
                Button(action: {
                    // 获取当前最顶层的视图控制器
                    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                       let rootViewController = windowScene.windows.first?.rootViewController {
                        var topViewController = rootViewController
                        while let presented = topViewController.presentedViewController {
                            topViewController = presented
                        }
                        // 弹出 PaymentSheet
                        if let paymentSheet = viewModel.paymentSheet {
                            paymentSheet.present(from: topViewController) { result in
                                viewModel.handlePaymentResult(result)
                            }
                        }
                    }
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: "lock.shield.fill")
                            .font(.system(size: 18))
                        Text("确认支付")
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
            } else {
                // 如果 PaymentSheet 未准备好，显示加载状态
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("正在准备支付...")
                        .font(AppTypography.subheadline)
                        .foregroundColor(AppColors.textSecondary)
                }
                .frame(maxWidth: .infinity, minHeight: 100)
                .padding()
            }
        }
        .padding(.vertical)
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
                Text("优惠券")
                    .font(AppTypography.title3)
                    .foregroundColor(AppColors.textPrimary)
                Spacer()
                
                if viewModel.isLoadingCoupons {
                    ProgressView()
                        .scaleEffect(0.8)
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
                            
                            Text("优惠: \(selectedCoupon.coupon.discountValueDisplay)")
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
                        Text("暂无可用优惠券")
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
                    Text("满\(coupon.coupon.minAmountDisplay)可用")
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
