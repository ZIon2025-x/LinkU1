import SwiftUI
import UIKit
import PassKit
import Combine
import StripeApplePay
import StripeCore

// 尝试导入 StripePayments（如果可用）
#if canImport(StripePayments)
import StripePayments
#endif

/// 使用原生 STPApplePayContext 的 Apple Pay 支付视图
/// 这种方式提供更多的自定义控制，但实现更复杂
/// 
/// 注意：根据 Stripe iOS SDK 版本，可能需要使用不同的 API
/// 如果编译错误，请检查 SDK 文档并调整
struct ApplePayNativeView: View {
    let taskId: Int
    let amount: Double
    let clientSecret: String?
    let taskTitle: String?
    let applicantName: String?
    let onPaymentSuccess: (() -> Void)?
    
    @StateObject private var viewModel: ApplePayNativeViewModel
    @Environment(\.dismiss) var dismiss
    
    init(
        taskId: Int,
        amount: Double,
        clientSecret: String? = nil,
        taskTitle: String? = nil,
        applicantName: String? = nil,
        onPaymentSuccess: (() -> Void)? = nil
    ) {
        self.taskId = taskId
        self.amount = amount
        self.clientSecret = clientSecret
        self.taskTitle = taskTitle
        self.applicantName = applicantName
        self.onPaymentSuccess = onPaymentSuccess
        _viewModel = StateObject(wrappedValue: ApplePayNativeViewModel(
            taskId: taskId,
            amount: amount,
            clientSecret: clientSecret
        ))
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                if !ApplePayHelper.isApplePaySupported() {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.orange)
                        Text(LocalizationKey.applePayNotSupported.localized)
                            .font(.headline)
                        Text(LocalizationKey.applePayUseOtherMethod.localized)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                } else if viewModel.isLoading {
                    VStack(spacing: 16) {
                        LoadingView(message: LocalizationKey.paymentPreparing.localized)
                            .foregroundColor(.secondary)
                    }
                } else if viewModel.paymentSuccess {
                    // 支付成功
                    paymentSuccessView
                } else if let error = viewModel.errorMessage {
                    // 错误状态
                    paymentErrorView(error: error)
                } else {
                    // 显示支付信息和 Apple Pay 按钮
                    paymentInfoView
                }
            }
            .padding()
            .navigationTitle(LocalizationKey.applePayTitle.localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(LocalizationKey.commonCancel.localized) {
                        dismiss()
                    }
                }
            }
            .onAppear {
                if clientSecret == nil {
                    viewModel.createPaymentIntent()
                }
            }
        }
    }
    
    // MARK: - Payment Success View
    
    private var paymentSuccessView: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(.green)
            
            Text(LocalizationKey.paymentSuccess.localized)
                .font(.title)
                .fontWeight(.bold)
            
            Text(LocalizationKey.paymentSuccessCompleted.localized)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Button(LocalizationKey.paymentComplete.localized) {
                onPaymentSuccess?()
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .frame(maxWidth: .infinity)
        }
        .padding()
    }
    
    // MARK: - Payment Error View
    
    private func paymentErrorView(error: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 48))
                .foregroundColor(.red)
            
            Text(LocalizationKey.paymentFailed.localized)
                .font(.headline)
            
            Text(error)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button(LocalizationKey.commonRetry.localized) {
                viewModel.createPaymentIntent()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .frame(maxWidth: .infinity)
        }
        .padding()
    }
    
    // MARK: - Payment Info View
    
    private var paymentInfoView: some View {
        VStack(spacing: 24) {
            // 支付信息
            if let paymentResponse = viewModel.paymentResponse {
                VStack(alignment: .leading, spacing: 12) {
                    if let title = taskTitle {
                        Text("\(LocalizationKey.paymentTaskTitle.localized): \(title)")
                            .font(.headline)
                    }
                    
                    if let applicant = applicantName {
                        Text("\(LocalizationKey.paymentApplicant.localized): \(applicant)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Divider()
                    
                    HStack {
                        Text(LocalizationKey.paymentAmount.localized)
                        Spacer()
                        Text(paymentResponse.finalAmountDisplay)
                            .fontWeight(.semibold)
                    }
                    
                    if let couponDiscount = paymentResponse.couponDiscount, couponDiscount > 0 {
                        HStack {
                            Text(LocalizationKey.paymentCouponDiscount.localized)
                            Spacer()
                            Text("-\(paymentResponse.couponDiscountDisplay ?? "0")")
                                .foregroundColor(.green)
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
            
            // Apple Pay 按钮
            ApplePayButton {
                viewModel.presentApplePay()
            }
            .frame(height: 50)
        }
    }
}

// MARK: - Apple Pay Button

struct ApplePayButton: UIViewRepresentable {
    let action: () -> Void
    
    func makeUIView(context: Context) -> PKPaymentButton {
        let button = PKPaymentButton(
            paymentButtonType: .plain,
            paymentButtonStyle: .black
        )
        button.addTarget(
            context.coordinator,
            action: #selector(Coordinator.buttonTapped),
            for: .touchUpInside
        )
        return button
    }
    
    func updateUIView(_ uiView: PKPaymentButton, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(action: action)
    }
    
    class Coordinator: NSObject {
        let action: () -> Void
        
        init(action: @escaping () -> Void) {
            self.action = action
        }
        
        @objc func buttonTapped() {
            action()
        }
    }
}

// MARK: - View Model

@MainActor
class ApplePayNativeViewModel: NSObject, ObservableObject, ApplePayContextDelegate {
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var paymentSuccess = false
    @Published var paymentResponse: PaymentResponse?
    
    private let apiService: APIService
    private let taskId: Int
    private let amount: Double
    private var cancellables = Set<AnyCancellable>()
    private var applePayContext: STPApplePayContext?
    
    init(taskId: Int, amount: Double, clientSecret: String? = nil, apiService: APIService? = nil) {
        self.taskId = taskId
        self.amount = amount
        self.apiService = apiService ?? APIService.shared
        
        // 初始化 Stripe
        let publishableKey = Constants.Stripe.publishableKey
        StripeAPI.defaultPublishableKey = publishableKey
    }
    
    func createPaymentIntent() {
        isLoading = true
        errorMessage = nil
        
        let requestBody: [String: Any] = [
            "payment_method": "stripe"
        ]
        
        apiService.request(
            PaymentResponse.self,
            APIEndpoints.Payment.createTaskPayment(taskId),
            method: "POST",
            body: requestBody
        )
        .sink(
            receiveCompletion: { [weak self] completion in
                self?.isLoading = false
                if case .failure(let error) = completion {
                    self?.errorMessage = error.userFriendlyMessage
                }
            },
            receiveValue: { [weak self] response in
                self?.isLoading = false
                self?.paymentResponse = response
            }
        )
        .store(in: &cancellables)
    }
    
    func presentApplePay() {
        guard let merchantId = Constants.Stripe.applePayMerchantIdentifier else {
            errorMessage = LocalizationKey.applePayNotConfigured.localized
            return
        }
        
        guard let paymentResponse = paymentResponse else {
            errorMessage = LocalizationKey.applePayPaymentInfoNotReady.localized
            return
        }
        
        // 创建支付请求
        let currency = paymentResponse.currency.uppercased()
        let amountDecimal = ApplePayHelper.decimalAmount(
            from: paymentResponse.finalAmount,
            currency: currency
        )
        
        // 创建摘要项
        var summaryItems: [PKPaymentSummaryItem] = []
        
        // note 是 String 类型，不是 Optional，直接检查是否为空
        let taskTitle = !paymentResponse.note.isEmpty ? paymentResponse.note : LocalizationKey.applePayTaskPaymentFallback.localized
        let item = PKPaymentSummaryItem(
            label: taskTitle,
            amount: NSDecimalNumber(decimal: amountDecimal)
        )
        summaryItems.append(item)
        
        // 总金额项（会显示为 "Pay Link²Ur [金额]"）
        let totalItem = PKPaymentSummaryItem(
            label: "Link²Ur",
            amount: NSDecimalNumber(decimal: amountDecimal)
        )
        summaryItems.append(totalItem)
        
        let paymentRequest = ApplePayHelper.createPaymentRequest(
            merchantIdentifier: merchantId,
            countryCode: "GB", // 根据你的业务所在国家修改
            currency: currency,
            amount: amountDecimal,
            summaryItems: summaryItems
        )
        
        // 创建 Apple Pay Context
        guard let applePayContext = STPApplePayContext(paymentRequest: paymentRequest, delegate: self) else {
            errorMessage = LocalizationKey.applePayUnableToCreateForm.localized
            return
        }
        
        self.applePayContext = applePayContext
        
        // 展示支付表单（使用新的 API，不需要传入 viewController）
        applePayContext.presentApplePay {
            // completion 回调，错误会通过 delegate 方法处理
        }
    }
    
    // MARK: - ApplePayContextDelegate
    
    // 注意：根据 Stripe iOS SDK 25.3.1，使用 async/await API
    func applePayContext(
        _ context: STPApplePayContext,
        didCreatePaymentMethod paymentMethod: StripeAPI.PaymentMethod,
        paymentInformation: PKPayment
    ) async throws -> String {
        // 从服务器获取 PaymentIntent client secret
        // 这里需要调用你的后端 API 来创建或确认 PaymentIntent
        guard let paymentResponse = paymentResponse,
              let clientSecret = paymentResponse.clientSecret else {
            throw NSError(
                domain: "ApplePayError",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: LocalizationKey.applePayUnableToGetPaymentInfo.localized]
            )
        }
        
        // 返回 client secret，Stripe 会自动完成支付
        return clientSecret
    }
    
    func applePayContext(
        _ context: STPApplePayContext,
        didCompleteWith status: STPApplePayContext.PaymentStatus,
        error: Error?
    ) {
        switch status {
        case .success:
            paymentSuccess = true
            errorMessage = nil
        case .error:
            if let error = error {
                errorMessage = error.localizedDescription
            } else {
                errorMessage = LocalizationKey.paymentFailed.localized
            }
        case .userCancellation:
            break
        @unknown default:
            errorMessage = LocalizationKey.paymentUnknownError.localized
        }
    }
}
