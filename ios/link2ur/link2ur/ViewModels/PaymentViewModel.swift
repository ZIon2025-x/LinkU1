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
    case wechatPay = "wechatPay"
    
    var displayName: String {
        switch self {
        case .card:
            return "信用卡/借记卡"
        case .applePay:
            return "Apple Pay"
        case .wechatPay:
            return "微信支付"
        }
    }
    
    var icon: String {
        switch self {
        case .card:
            return "creditcard.fill"
        case .applePay:
            return "applelogo"
        case .wechatPay:
            return "WeChatLogo"  // 使用 asset 中的微信图标
        }
    }
    
    /// 判断图标是否为 asset 图标（而非系统图标）
    var isAssetIcon: Bool {
        switch self {
        case .card, .applePay:
            return false
        case .wechatPay:
            return true
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
    private var initialCustomerId: String?
    private var initialEphemeralKeySecret: String?
    private var paymentSheetClientSecret: String?
    private var isCreatingPaymentIntent = false // 防止重复创建支付意图
    private var isLoadingPaymentInfo = false // 防止重复加载支付信息
    private var applePayContext: STPApplePayContext?

    /// 当前应使用的 PaymentIntent client_secret
    /// - Note: 批准申请支付会直接传入 client_secret，此时 paymentResponse 可能为空
    private var activeClientSecret: String? {
        return paymentResponse?.clientSecret ?? initialClientSecret
    }

    /// 当前支付金额（便士）
    /// - Note: 若 paymentResponse 为空（批准申请支付），使用初始化时传入的 amount（英镑）推算
    private var activeFinalAmountPence: Int {
        if let pence = paymentResponse?.finalAmount {
            return pence
        }
        return Int((amount * 100).rounded())
    }

    private var activeCurrency: String {
        return paymentResponse?.currency.uppercased() ?? "GBP"
    }

    private var activeNote: String {
        if let note = paymentResponse?.note, !note.isEmpty {
            return note
        }
        return "Link²Ur 任务支付"
    }

    /// 是否已具备可发起支付的 client_secret
    var hasActivePaymentClientSecret: Bool {
        return activeClientSecret != nil
    }
    
    init(taskId: Int, amount: Double, clientSecret: String? = nil, customerId: String? = nil, ephemeralKeySecret: String? = nil, apiService: APIService? = nil) {
        self.taskId = taskId
        self.amount = amount
        self.initialClientSecret = clientSecret
        self.initialCustomerId = customerId
        self.initialEphemeralKeySecret = ephemeralKeySecret
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
        
        // 如果外部传入了 client_secret（例如"批准申请支付"创建的 PaymentIntent）
        // 则直接使用该 PaymentIntent，不再去 coupon-points 创建新的 PaymentIntent，避免支付成功后任务状态无法推进
        // 注意：延迟初始化 PaymentSheet，直到 sheet 真正显示，避免阻塞主线程
        // ensurePaymentSheetReady() 将在 StripePaymentView 的 onAppear 中调用
        
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
        // 配置 Payment Sheet
        var configuration = PaymentSheet.Configuration()
        configuration.merchantDisplayName = "Link²Ur"
        // 注意：WeChat Pay 不支持 delayed payment methods
        // 如果设置为 true，WeChat Pay 可能会被过滤掉
        configuration.allowsDelayedPaymentMethods = false
        
        // 设置默认账单地址国家为英国（GB）
        // 说明：这里用“先取出再写回”的方式，避免直接链式修改导致的可变性问题
        var defaultBillingDetails = configuration.defaultBillingDetails
        var defaultAddress = defaultBillingDetails.address
        defaultAddress.country = "GB"
        defaultBillingDetails.address = defaultAddress
        configuration.defaultBillingDetails = defaultBillingDetails
        
        // 如果支付响应包含 Customer ID 和 Ephemeral Key，配置保存支付方式功能
        // 这样用户可以保存银行卡信息，下次支付时可以直接选择已保存的卡
        // 注意：CVV 安全码不会被保存，这是 Stripe 的安全机制
        let customerIdToUse = paymentResponse?.customerId ?? initialCustomerId
        let ephemeralKeyToUse = paymentResponse?.ephemeralKeySecret ?? initialEphemeralKeySecret
        if let customerId = customerIdToUse,
           let ephemeralKeySecret = ephemeralKeyToUse {
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
        
        // 配置 returnURL，用于 WeChat Pay 等需要跳转的支付方式回调
        // 格式：yourapp://stripe-redirect
        // 这允许用户在完成微信支付后返回到应用
        configuration.returnURL = "link2ur://stripe-redirect"
        Logger.debug("PaymentSheet 已配置 returnURL: link2ur://stripe-redirect", category: .api)
        
        // 创建 Payment Sheet（弹出式）
        let paymentSheet = PaymentSheet(
            paymentIntentClientSecret: clientSecret,
            configuration: configuration
        )
        
        self.paymentSheet = paymentSheet
        self.paymentSheetClientSecret = clientSecret
        Logger.debug("PaymentSheet 创建成功，clientSecret: \(clientSecret.prefix(20))...", category: .api)
    }

    /// 确保 PaymentSheet 已准备好（仅在 clientSecret 变化时重建）
    /// - Note: 统一入口，避免 View 层多处重复触发 setup
    /// 优化：延迟初始化，避免阻塞 UI
    func ensurePaymentSheetReady() {
        guard let clientSecret = activeClientSecret, !clientSecret.isEmpty else {
            return
        }

        if paymentSheet != nil, paymentSheetClientSecret == clientSecret {
            return
        }

        // 延迟初始化 PaymentSheet，避免阻塞 UI
        // 使用异步延迟，让 UI 先响应切换操作
        // 注意：PaymentSheet 的创建必须在主线程执行
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            // 再次检查，避免重复创建
            if self.paymentSheet == nil || self.paymentSheetClientSecret != clientSecret {
                self.setupPaymentElement(with: clientSecret)
            }
        }
    }

    /// 统一的支付方式切换入口（便于扩展更多支付方式）
    /// 优化：立即更新 UI，延迟准备支付方式，避免阻塞
    func selectPaymentMethod(_ method: PaymentMethodType) {
        // 如果已经是当前选择的方式，直接返回，避免重复操作
        guard selectedPaymentMethod != method else {
            return
        }
        
        // 立即更新 UI，不阻塞
        selectedPaymentMethod = method

        // 延迟准备支付方式，避免阻塞 UI 切换动画
        // 使用 debounce 机制，避免快速切换时重复调用
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self = self, self.selectedPaymentMethod == method else {
                return
            }
            
            switch method {
            case .card:
                // 优先预热 PaymentSheet；如果还没拿到 clientSecret，则拉取一次支付信息
                if self.activeClientSecret == nil {
                    self.createPaymentIntent()
                } else {
                    // 只在 PaymentSheet 不存在时才创建，避免重复初始化
                    if self.paymentSheet == nil {
                        self.ensurePaymentSheetReady()
                    }
                }
            case .applePay:
                // Apple Pay 需要 paymentResponse；如果没有则拉取
                if self.activeClientSecret == nil {
                    self.createPaymentIntent()
                }
                // Apple Pay 不需要额外准备，直接可用
            case .wechatPay:
                // WeChat Pay 使用 PaymentSheet，需要 clientSecret
                if self.activeClientSecret == nil {
                    self.createPaymentIntent()
                } else {
                    // 只在 PaymentSheet 不存在时才创建，避免重复初始化
                    if self.paymentSheet == nil {
                        self.ensurePaymentSheetReady()
                    }
                }
            }
        }
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

        // 无论当前选择哪种支付方式，都预热 PaymentSheet（用于信用卡支付）
        // 这样用户可以自由切换；且 ensure 内部会避免重复重建
        ensurePaymentSheetReady()
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
            // 清除支付缓存，因为有了新的支付记录
            CacheManager.shared.invalidatePaymentCache()
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

        // 必须有 client_secret 才能确认 PaymentIntent
        guard activeClientSecret != nil else {
            errorMessage = "支付信息未准备好，请稍后再试"
            Logger.warning("缺少 client_secret，无法使用 Apple Pay，尝试创建支付意图", category: .api)
            createPaymentIntent()
            return
        }

        // 检查最终支付金额
        guard activeFinalAmountPence > 0 else {
            Logger.info("最终支付金额为 0，无需支付", category: .api)
            paymentSuccess = true
            return
        }
        
        // 创建支付请求
        let currency = activeCurrency
        let amountDecimal = ApplePayHelper.decimalAmount(
            from: activeFinalAmountPence,
            currency: currency
        )
        
        // 创建摘要项
        var summaryItems: [PKPaymentSummaryItem] = []
        let taskTitle = activeNote
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
        guard let clientSecret = activeClientSecret else {
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
            // 清除支付缓存，因为有了新的支付记录
            CacheManager.shared.invalidatePaymentCache()
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
        // 必须有 client_secret 才能发起支付；没有则创建支付意图
        guard activeClientSecret != nil else {
            errorMessage = "支付信息未准备好，正在加载..."
            Logger.warning("缺少 client_secret，重新创建支付意图", category: .api)
            createPaymentIntent()
            return
        }

        // 检查最终支付金额
        guard activeFinalAmountPence > 0 else {
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
                // 尝试按统一入口创建/复用 PaymentSheet
                ensurePaymentSheetReady()
            }
        case .applePay:
            // 使用 Apple Pay 原生实现
            Logger.debug("使用 Apple Pay 原生实现支付", category: .api)
            payWithApplePay()
        case .wechatPay:
            // 使用 PaymentSheet 支付（WeChat Pay 通过 PaymentSheet 处理）
            // PaymentSheet 会自动显示 WeChat Pay 选项（如果后端支持）
            if let paymentSheet = paymentSheet {
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let rootViewController = windowScene.windows.first?.rootViewController {
                    var topViewController = rootViewController
                    while let presented = topViewController.presentedViewController {
                        topViewController = presented
                    }
                    Logger.debug("准备弹出 PaymentSheet（WeChat Pay）", category: .api)
                    paymentSheet.present(from: topViewController) { [weak self] result in
                        Logger.debug("PaymentSheet 结果（WeChat Pay）: \(result)", category: .api)
                        self?.handlePaymentResult(result)
                    }
                } else {
                    errorMessage = "无法打开支付界面，请重试"
                    Logger.error("无法获取顶层视图控制器", category: .api)
                }
            } else {
                errorMessage = "支付表单未准备好，请稍后重试"
                Logger.warning("PaymentSheet 为 nil，尝试重新创建", category: .api)
                // 尝试按统一入口创建/复用 PaymentSheet
                ensurePaymentSheetReady()
            }
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
