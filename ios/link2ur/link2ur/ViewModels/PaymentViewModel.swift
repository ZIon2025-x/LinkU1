import Foundation
import Combine
import SwiftUI
import UIKit
import StripePaymentSheet
import StripeCore
import StripeApplePay
import PassKit

// 尝试导入 StripePayments（如果可用）
#if canImport(StripePayments)
import StripePayments
#endif

// MARK: - Payment Method
enum PaymentMethodType: String, CaseIterable {
    case card = "card"
    case applePay = "applePay"
    
    var displayName: String {
        switch self {
        case .card:
            return "信用卡/借记卡"
        case .applePay:
            return "Apple Pay"
        }
    }
    
    var icon: String {
        switch self {
        case .card:
            return "creditcard.fill"
        case .applePay:
            return "applelogo"
        }
    }
}

@MainActor
class PaymentViewModel: NSObject, ObservableObject, ApplePayContextDelegate {
    @Published var isLoading = false
    @Published var paymentSheet: PaymentSheet?
    @Published var errorMessage: String?
    @Published var paymentSuccess = false
    @Published var paymentResponse: PaymentResponse?
    @Published var availableCoupons: [UserCoupon] = []
    @Published var isLoadingCoupons = false
    @Published var selectedCoupon: UserCoupon?
    @Published var selectedPaymentMethod: PaymentMethodType = .card
    
    private let apiService: APIService
    private let taskId: Int
    private let amount: Double
    private var cancellables = Set<AnyCancellable>()
    
    private var initialClientSecret: String?
    private var isCreatingPaymentIntent = false // 防止重复创建支付意图
    private var isLoadingPaymentInfo = false // 防止重复加载支付信息
    private var applePayContext: STPApplePayContext?
    
    init(taskId: Int, amount: Double, clientSecret: String? = nil, apiService: APIService? = nil) {
        self.taskId = taskId
        self.amount = amount
        self.initialClientSecret = clientSecret
        self.apiService = apiService ?? APIService.shared
        
        // 必须先调用 super.init() 因为继承自 NSObject
        super.init()
        
        // 初始化 Stripe
        let publishableKey = Constants.Stripe.publishableKey
        StripeAPI.defaultPublishableKey = publishableKey
        
        // PaymentSheet 需要 STPAPIClient.shared.publishableKey
        #if canImport(StripePayments)
        STPAPIClient.shared.publishableKey = publishableKey
        Logger.debug("STPAPIClient.publishableKey 已设置", category: .api)
        #else
        Logger.debug("StripePayments 未导入，PaymentSheet 可能使用 StripeAPI.defaultPublishableKey", category: .api)
        #endif
        
        // 如果提供了 client_secret，先调用 API 获取完整的支付信息
        // 然后使用返回的 client_secret 创建 Payment Sheet（确保使用最新的）
        if clientSecret != nil {
            // 先调用 API 获取完整的支付信息（包括金额、优惠券等）
            // 这样不会创建新的 PaymentIntent，而是获取已存在的 PaymentIntent 信息
            loadPaymentInfo()
        }
        
        // 加载可用优惠券
        loadAvailableCoupons()
        
        // 根据设备支持情况设置默认支付方式
        // 如果设备支持 Apple Pay 且已配置 Merchant ID，优先选择 Apple Pay
        if isApplePaySupported && Constants.Stripe.applePayMerchantIdentifier != nil {
            selectedPaymentMethod = .applePay
        } else {
            selectedPaymentMethod = .card
        }
    }
    
    /// 加载支付信息（当已有 client_secret 时使用）
    private func loadPaymentInfo() {
        // 防止重复请求
        guard !isLoadingPaymentInfo else {
            Logger.debug("支付信息加载中，跳过重复请求", category: .network)
            return
        }
        
        isLoadingPaymentInfo = true
        isLoading = true
        errorMessage = nil
        
        Logger.debug("开始加载支付信息，taskId: \(taskId)", category: .api)
        
        // 调用 API 获取支付信息（不创建新的 PaymentIntent）
        // 后端会检查是否已存在 PaymentIntent，如果存在则返回其信息
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
                self?.isLoadingPaymentInfo = false
                self?.isLoading = false
                if case .failure(let error) = completion {
                    Logger.error("加载支付信息失败: \(error.localizedDescription)", category: .api)
                    self?.errorMessage = error.userFriendlyMessage
                }
            },
            receiveValue: { [weak self] response in
                self?.isLoadingPaymentInfo = false
                self?.isLoading = false
                Logger.debug("支付信息加载成功，finalAmount: \(response.finalAmount)", category: .api)
                self?.handlePaymentResponse(response)
            }
        )
        .store(in: &cancellables)
    }
    
    /// 加载可用优惠券（状态为 active 的优惠券）
    func loadAvailableCoupons() {
        isLoadingCoupons = true
        apiService.getMyCoupons(status: "active")
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoadingCoupons = false
                    if case .failure(let error) = completion {
                        // 加载优惠券失败不影响支付流程，只记录错误
                        Logger.warning("加载优惠券失败: \(error.localizedDescription)", category: .network)
                    }
                },
                receiveValue: { [weak self] response in
                    self?.availableCoupons = response.data
                    self?.isLoadingCoupons = false
                }
            )
            .store(in: &cancellables)
    }
    
    /// 选择优惠券并重新创建支付意图
    func selectCoupon(_ coupon: UserCoupon?) {
        selectedCoupon = coupon
        // 重新创建支付意图，应用优惠券
        createPaymentIntent(couponCode: coupon?.coupon.code)
    }
    
    /// 移除优惠券并重新创建支付意图
    func removeCoupon() {
        selectedCoupon = nil
        // 重新创建支付意图，不应用优惠券
        createPaymentIntent()
    }
    
    func setupPaymentElement(with clientSecret: String) {
        // 配置 Payment Sheet（仅用于信用卡支付）
        var configuration = PaymentSheet.Configuration()
        configuration.merchantDisplayName = "Link²Ur"
        configuration.allowsDelayedPaymentMethods = true
        
        // 设置默认账单地址国家为英国（GB）
        // 说明：这里用“先取出再写回”的方式，兼容 BillingDetails / Address 可能为可选的 SDK 版本差异
        var defaultBillingDetails = configuration.defaultBillingDetails
        var defaultAddress = defaultBillingDetails.address ?? .init()
        defaultAddress.country = "GB"
        defaultBillingDetails.address = defaultAddress
        configuration.defaultBillingDetails = defaultBillingDetails
        
        // 如果支付响应包含 Customer ID 和 Ephemeral Key，配置保存支付方式功能
        // 这样用户可以保存银行卡信息，下次支付时可以直接选择已保存的卡
        // 注意：CVV 安全码不会被保存，这是 Stripe 的安全机制
        if let customerId = paymentResponse?.customerId,
           let ephemeralKeySecret = paymentResponse?.ephemeralKeySecret {
            configuration.customer = PaymentSheet.CustomerConfiguration(
                id: customerId,
                ephemeralKeySecret: ephemeralKeySecret
            )
            Logger.debug("PaymentSheet 已配置 Customer，支持保存支付方式", category: .api)
        } else {
            Logger.debug("PaymentSheet 未配置 Customer，支付方式不会被保存", category: .api)
        }
        
        // 注意：不再在 PaymentSheet 中配置 Apple Pay，因为使用原生实现
        
        // 自定义外观以匹配应用设计
        var appearance = PaymentSheet.Appearance()
        
        // 颜色配置
        appearance.colors.primary = UIColor(AppColors.primary)
        appearance.colors.background = UIColor(AppColors.cardBackground)
        appearance.colors.componentBackground = UIColor(AppColors.surface)
        appearance.colors.componentBorder = UIColor(AppColors.separator)
        appearance.colors.componentDivider = UIColor(AppColors.separator)
        appearance.colors.text = UIColor(AppColors.textPrimary)
        appearance.colors.textSecondary = UIColor(AppColors.textSecondary)
        appearance.colors.danger = UIColor(AppColors.error)
        
        // 字体配置
        appearance.font.base = UIFont.preferredFont(forTextStyle: .body)
        appearance.font.sizeScaleFactor = 1.0
        
        // 边框和圆角
        appearance.cornerRadius = AppCornerRadius.medium
        appearance.borderWidth = 1.0
        
        // 阴影
        appearance.shadow = PaymentSheet.Appearance.Shadow(
            color: UIColor.black.withAlphaComponent(0.05),
            opacity: 1.0,
            offset: CGSize(width: 0, height: 2),
            radius: 4
        )
        
        configuration.appearance = appearance
        
        // 创建 Payment Sheet（弹出式）
        let paymentSheet = PaymentSheet(
            paymentIntentClientSecret: clientSecret,
            configuration: configuration
        )
        
        self.paymentSheet = paymentSheet
        Logger.debug("PaymentSheet 创建成功，clientSecret: \(clientSecret.prefix(20))...", category: .api)
    }
    
    func createPaymentIntent(paymentMethod: String = "stripe", pointsAmount: Double? = nil, couponCode: String? = nil) {
        // 防止重复请求
        guard !isCreatingPaymentIntent else {
            Logger.debug("支付意图创建中，跳过重复请求", category: .network)
            return
        }
        
        isCreatingPaymentIntent = true
        isLoading = true
        errorMessage = nil
        
        var requestBody: [String: Any] = [
            "payment_method": paymentMethod
        ]
        
        if let pointsAmount = pointsAmount {
            requestBody["points_amount"] = Int(pointsAmount * 100) // 转换为便士
        }
        
        // 优先使用传入的 couponCode，否则使用已选择的优惠券
        let finalCouponCode = couponCode ?? selectedCoupon?.coupon.code
        if let finalCouponCode = finalCouponCode {
            requestBody["coupon_code"] = finalCouponCode.uppercased()
        }
        
        // 调用 API - 使用 Combine Publisher
        apiService.request(
            PaymentResponse.self,
            APIEndpoints.Payment.createTaskPayment(taskId),
            method: "POST",
            body: requestBody
        )
        .sink(
            receiveCompletion: { [weak self] completion in
                self?.isCreatingPaymentIntent = false
                self?.isLoading = false
                if case .failure(let error) = completion {
                    self?.errorMessage = error.userFriendlyMessage
                }
            },
            receiveValue: { [weak self] response in
                self?.isCreatingPaymentIntent = false
                self?.handlePaymentResponse(response)
            }
        )
        .store(in: &cancellables)
    }
    
    private func handlePaymentResponse(_ response: PaymentResponse) {
        // 保存支付响应信息
        paymentResponse = response
        
        Logger.debug("处理支付响应: finalAmount=\(response.finalAmount), hasClientSecret=\(response.clientSecret != nil)", category: .api)
        
        // 如果纯积分支付，直接成功
        if response.finalAmount == 0 {
            Logger.info("纯积分支付，无需支付", category: .api)
            paymentSuccess = true
            return
        }
        
        // 如果有 client_secret，根据当前选择的支付方式创建相应的支付表单
        guard let clientSecret = response.clientSecret else {
            Logger.error("支付响应中缺少 client_secret", category: .api)
            errorMessage = "无法创建支付表单，请重试"
            return
        }
        
        // 更新 initialClientSecret 为最新的
        initialClientSecret = clientSecret
        
        // 无论选择哪种支付方式，都创建 PaymentSheet（用于信用卡支付）
        // 这样用户可以在两种支付方式之间切换
        // 如果 PaymentSheet 已存在且使用相同的 client_secret，则不需要重新创建
        if let existingClientSecret = initialClientSecret,
           existingClientSecret == clientSecret,
           paymentSheet != nil {
            Logger.debug("PaymentSheet 已存在且 client_secret 相同，跳过重新创建", category: .api)
            return
        }
        
        // 始终创建 PaymentSheet（用于信用卡支付），无论当前选择的支付方式是什么
        // 这样用户可以在两种支付方式之间切换
        Logger.debug("创建 PaymentSheet，clientSecret: \(clientSecret.prefix(20))...", category: .api)
        setupPaymentElement(with: clientSecret)
    }
    
    // 不再需要 confirmPayment 方法，直接使用 PaymentSheet.present()
    
    private func formatPaymentError(_ error: Error) -> String {
        let errorDescription = error.localizedDescription.lowercased()
        
        // 常见错误的中文化
        if errorDescription.contains("card") && errorDescription.contains("declined") {
            return "银行卡被拒绝，请尝试其他支付方式"
        } else if errorDescription.contains("insufficient") {
            return "余额不足，请检查您的账户"
        } else if errorDescription.contains("expired") {
            return "支付方式已过期，请更新"
        } else if errorDescription.contains("network") || errorDescription.contains("connection") {
            return "网络连接失败，请检查网络后重试"
        } else if errorDescription.contains("timeout") {
            return "请求超时，请重试"
        } else {
            return "支付失败: \(error.localizedDescription)"
        }
    }
    
    // 保留用于兼容性（如果需要弹出式 Payment Sheet）
    func handlePaymentResult(_ result: PaymentSheetResult) {
        switch result {
        case .completed:
            Logger.info("支付成功", category: .api)
            paymentSuccess = true
        case .failed(let error):
            Logger.error("支付失败: \(error.localizedDescription)", category: .api)
            // 使用格式化的错误消息
            errorMessage = formatPaymentError(error)
        case .canceled:
            // 用户取消，不显示错误
            Logger.debug("用户取消支付", category: .api)
            break
        }
    }
    
    // MARK: - Apple Pay 原生实现
    
    /// 检查是否支持 Apple Pay
    var isApplePaySupported: Bool {
        return ApplePayHelper.isApplePaySupported()
    }
    
    /// 使用 Apple Pay 原生实现支付
    func payWithApplePay() {
        guard let merchantId = Constants.Stripe.applePayMerchantIdentifier else {
            errorMessage = "Apple Pay 未配置，请使用其他支付方式"
            Logger.warning("Apple Pay Merchant ID 未配置", category: .api)
            return
        }
        
        guard let paymentResponse = paymentResponse else {
            errorMessage = "支付信息未准备好，请稍后再试"
            Logger.warning("支付信息未准备好，无法使用 Apple Pay", category: .api)
            // 如果支付信息未准备好，尝试创建支付意图
            createPaymentIntent()
            return
        }
        
        // 检查最终支付金额
        guard paymentResponse.finalAmount > 0 else {
            Logger.info("最终支付金额为 0，无需支付", category: .api)
            paymentSuccess = true
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
        let taskTitle = !paymentResponse.note.isEmpty ? paymentResponse.note : "Link²Ur 任务支付"
        let item = PKPaymentSummaryItem(
            label: taskTitle,
            amount: NSDecimalNumber(decimal: amountDecimal)
        )
        summaryItems.append(item)
        
        // 总金额项
        let totalItem = PKPaymentSummaryItem(
            label: "Link²Ur",
            amount: NSDecimalNumber(decimal: amountDecimal)
        )
        summaryItems.append(totalItem)
        
        let paymentRequest = ApplePayHelper.createPaymentRequest(
            merchantIdentifier: merchantId,
            countryCode: "GB",
            currency: currency,
            amount: amountDecimal,
            summaryItems: summaryItems
        )
        
        // 创建 Apple Pay Context
        guard let applePayContext = STPApplePayContext(paymentRequest: paymentRequest, delegate: self) else {
            errorMessage = "无法创建 Apple Pay 支付表单"
            return
        }
        
        self.applePayContext = applePayContext
        
        // 展示支付表单（使用新的 API，不需要传入 viewController）
        Logger.debug("准备弹出 Apple Pay 表单", category: .api)
        applePayContext.presentApplePay {
            // completion 回调，错误会通过 delegate 方法处理
            Logger.debug("Apple Pay 表单已显示", category: .api)
        }
    }
    
    // MARK: - ApplePayContextDelegate
    
    func applePayContext(
        _ context: STPApplePayContext,
        didCreatePaymentMethod paymentMethod: StripeAPI.PaymentMethod,
        paymentInformation: PKPayment
    ) async throws -> String {
        guard let paymentResponse = paymentResponse,
              let clientSecret = paymentResponse.clientSecret else {
            throw NSError(
                domain: "ApplePayError",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "无法获取支付信息"]
            )
        }
        return clientSecret
    }
    
    func applePayContext(
        _ context: STPApplePayContext,
        didCompleteWith status: STPApplePayContext.PaymentStatus,
        error: Error?
    ) {
        switch status {
        case .success:
            Logger.info("Apple Pay 支付成功", category: .api)
            paymentSuccess = true
            errorMessage = nil
        case .error:
            if let error = error {
                Logger.error("Apple Pay 支付失败: \(error.localizedDescription)", category: .api)
                errorMessage = formatPaymentError(error)
            } else {
                errorMessage = "支付失败"
            }
        case .userCancellation:
            Logger.debug("用户取消 Apple Pay 支付", category: .api)
            break
        @unknown default:
            errorMessage = "未知错误"
        }
    }
    
    /// 执行支付（根据选择的支付方式）
    func performPayment() {
        // 确保支付信息已准备好
        guard let paymentResponse = paymentResponse else {
            errorMessage = "支付信息未准备好，正在加载..."
            Logger.warning("尝试支付但支付信息未准备好，重新创建支付意图", category: .api)
            createPaymentIntent()
            return
        }
        
        // 检查最终支付金额
        guard paymentResponse.finalAmount > 0 else {
            Logger.info("最终支付金额为 0，无需支付", category: .api)
            paymentSuccess = true
            return
        }
        
        switch selectedPaymentMethod {
        case .card:
            // 使用 PaymentSheet 支付
            if let paymentSheet = paymentSheet {
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let rootViewController = windowScene.windows.first?.rootViewController {
                    var topViewController = rootViewController
                    while let presented = topViewController.presentedViewController {
                        topViewController = presented
                    }
                    Logger.debug("准备弹出 PaymentSheet", category: .api)
                    paymentSheet.present(from: topViewController) { [weak self] result in
                        Logger.debug("PaymentSheet 结果: \(result)", category: .api)
                        self?.handlePaymentResult(result)
                    }
                } else {
                    errorMessage = "无法打开支付界面，请重试"
                    Logger.error("无法获取顶层视图控制器", category: .api)
                }
            } else {
                errorMessage = "支付表单未准备好，请稍后重试"
                Logger.warning("PaymentSheet 为 nil，尝试重新创建", category: .api)
                // 尝试重新创建 PaymentSheet
                if let clientSecret = paymentResponse.clientSecret {
                    setupPaymentElement(with: clientSecret)
                }
            }
        case .applePay:
            // 使用 Apple Pay 原生实现
            Logger.debug("使用 Apple Pay 原生实现支付", category: .api)
            payWithApplePay()
        }
    }
}

// MARK: - Payment Response Model
struct PaymentResponse: Codable {
    let paymentId: Int?
    let feeType: String
    let totalAmount: Int
    let totalAmountDisplay: String
    let pointsUsed: Int?
    let pointsUsedDisplay: String?
    let couponDiscount: Int?
    let couponDiscountDisplay: String?
    let stripeAmount: Int?
    let stripeAmountDisplay: String?
    let currency: String
    let finalAmount: Int
    let finalAmountDisplay: String
    let checkoutUrl: String?
    let clientSecret: String?
    let paymentIntentId: String?
    let customerId: String?
    let ephemeralKeySecret: String?
    let note: String
    
    enum CodingKeys: String, CodingKey {
        case paymentId = "payment_id"
        case feeType = "fee_type"
        case totalAmount = "total_amount"
        case totalAmountDisplay = "total_amount_display"
        case pointsUsed = "points_used"
        case pointsUsedDisplay = "points_used_display"
        case couponDiscount = "coupon_discount"
        case couponDiscountDisplay = "coupon_discount_display"
        case stripeAmount = "stripe_amount"
        case stripeAmountDisplay = "stripe_amount_display"
        case currency
        case finalAmount = "final_amount"
        case finalAmountDisplay = "final_amount_display"
        case checkoutUrl = "checkout_url"
        case clientSecret = "client_secret"
        case paymentIntentId = "payment_intent_id"
        case customerId = "customer_id"
        case ephemeralKeySecret = "ephemeral_key_secret"
        case note
    }
}
