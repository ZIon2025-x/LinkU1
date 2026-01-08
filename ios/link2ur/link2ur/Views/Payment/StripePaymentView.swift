import SwiftUI
import StripePaymentSheet

struct StripePaymentView: View {
    let taskId: Int
    let amount: Double
    let clientSecret: String?
    
    @StateObject private var viewModel: PaymentViewModel
    @Environment(\.dismiss) var dismiss
    @State private var presentingPaymentSheet = false
    
    init(taskId: Int, amount: Double, clientSecret: String? = nil) {
        self.taskId = taskId
        self.amount = amount
        self.clientSecret = clientSecret
        _viewModel = StateObject(wrappedValue: PaymentViewModel(taskId: taskId, amount: amount, clientSecret: clientSecret))
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
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
                    } else if let paymentResponse = viewModel.paymentResponse, viewModel.paymentSheet != nil {
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
                }
            }
            .onAppear {
                // 如果没有提供 client_secret，才调用 API 创建支付意图
                if clientSecret == nil {
                    viewModel.createPaymentIntent()
                }
            }
            .sheet(isPresented: $presentingPaymentSheet) {
                if let paymentSheet = viewModel.paymentSheet {
                    PaymentSheetViewController(
                        paymentSheet: paymentSheet,
                        onResult: { result in
                            viewModel.handlePaymentResult(result)
                            presentingPaymentSheet = false
                        }
                    )
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
            // 然后关闭支付界面，让父视图刷新任务状态
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                dismiss()
            }
        }
    }
    
    // MARK: - Payment Error View
    private func paymentErrorView(error: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundColor(AppColors.error)
            
            Text("支付错误")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(AppColors.textPrimary)
            
            Text(error)
                .font(.subheadline)
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button("重试") {
                viewModel.createPaymentIntent()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity, minHeight: 400)
    }
    
    // MARK: - Payment Info View
    private func paymentInfoView(paymentResponse: PaymentResponse) -> some View {
        VStack(spacing: 24) {
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
            Button(action: {
                presentingPaymentSheet = true
            }) {
                HStack {
                    Image(systemName: "creditcard.fill")
                        .font(.system(size: 18))
                    Text("继续支付")
                        .font(AppTypography.title3)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(AppColors.primary)
                .cornerRadius(AppCornerRadius.large)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.vertical)
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

// Payment Sheet UIViewController 包装器
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
