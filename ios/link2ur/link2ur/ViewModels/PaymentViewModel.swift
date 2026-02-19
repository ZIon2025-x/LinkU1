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
    case alipayPay = "alipayPay"
    
    var displayName: String {
        switch self {
        case .card:
            return "信用卡/借记卡"
        case .applePay:
            return "Apple Pay"
        case .wechatPay:
            return "微信支付"
        case .alipayPay:
            return "支付宝"
        }
    }
    
    var icon: String {
        switch self {
        case .card:
            return "creditcard.fill"
        case .applePay:
            return "applelogo"
        case .wechatPay:
            return "WeChatPayLogo"
        case .alipayPay:
            return "AlipayLogo"
        }
    }
    
    /// 判断图标是否为 asset 图标（而非系统图标）
    var isAssetIcon: Bool {
        switch self {
        case .card, .applePay:
            return false
        case .wechatPay, .alipayPay:
            return true
        }
    }
}

@MainActor
class PaymentViewModel: NSObject, ObservableObject, ApplePayContextDelegate, STPAuthenticationContext {
    @Published var isLoading = false
    @Published var paymentSheet: PaymentSheet?
    @Published var errorMessage: String?
    @Published var paymentSuccess = false
    @Published var paymentResponse: PaymentResponse?
    @Published var availableCoupons: [UserCoupon] = []
    @Published var isLoadingCoupons = false
    @Published var selectedCoupon: UserCoupon?
    @Published var selectedPaymentMethod: PaymentMethodType = .card
    /// 切换银行卡/微信/支付宝时為 true，用于展示「准备中」而非「正在加载支付表单」
    @Published var isSwitchingPaymentMethod = false
    /// 支付宝/微信直接支付时为 true，用于显示加载状态
    @Published var isProcessingDirectPayment = false
    
    // MARK: - 微信支付 WebView 相关（iOS PaymentSheet 不支持微信支付，需要通过 WebView 显示二维码）
    /// 是否显示微信支付 WebView
    @Published var showWeChatPayWebView = false
    /// 微信支付 Checkout Session URL
    @Published var wechatPayCheckoutURL: String?
    /// 是否正在创建微信支付 Checkout Session
    @Published var isCreatingWeChatCheckout = false
    
    private let apiService: APIService
    private let taskId: Int
    private let amount: Double
    /// 批准流程传入的 clientSecret：不参与 clear+create 切换，切换时保持使用该 PI（避免破坏 webhook 关联）
    private let hasApprovalFlowClientSecret: Bool
    private var cancellables = Set<AnyCancellable>()
    
    private var initialClientSecret: String?
    private var initialCustomerId: String?
    private var initialEphemeralKeySecret: String?
    private var paymentSheetClientSecret: String?
    private var isCreatingPaymentIntent = false // 防止重复创建支付意图
    private var isLoadingPaymentInfo = false // 防止重复加载支付信息
    private var applePayContext: STPApplePayContext?
    /// 支付中轮询支付状态（与 Flutter 一致：支付宝/Stripe 延迟确认时尽早发现成功）
    private var paymentStatusPollTimer: Timer?
    private var paymentStatusPollCount = 0

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
    
    /// 当前选中支付方式对应的 preferred_payment_method API 值；Apple Pay 不传
    private var preferredPaymentMethodForAPI: String? {
        switch selectedPaymentMethod {
        case .card: return "card"
        case .alipayPay: return "alipay"
        case .wechatPay: return "wechat_pay"
        case .applePay: return nil
        }
    }
    
    init(taskId: Int, amount: Double, clientSecret: String? = nil, customerId: String? = nil, ephemeralKeySecret: String? = nil, apiService: APIService? = nil) {
        self.taskId = taskId
        self.amount = amount
        self.initialClientSecret = clientSecret
        self.initialCustomerId = customerId
        self.initialEphemeralKeySecret = ephemeralKeySecret
        self.hasApprovalFlowClientSecret = (clientSecret != nil && !(clientSecret?.isEmpty ?? true))
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
        
        // 延迟加载优惠券，避免阻塞支付流程初始化
        // 优惠券加载将在支付页面显示后异步进行
        
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
        // 微信支付、支付宝等需跳转完成的支付方式属于 delayed payment methods，必须设为 true
        // 否则 PaymentSheet 会报：None of the payment methods can be used in PaymentSheet
        configuration.allowsDelayedPaymentMethods = true
        
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
    /// 优化：立即初始化，因为调用时已经在主线程（onAppear 或设置支付参数后）
    func ensurePaymentSheetReady() {
        guard let clientSecret = activeClientSecret, !clientSecret.isEmpty else {
            return
        }

        if paymentSheet != nil, paymentSheetClientSecret == clientSecret {
            return
        }

        // 立即初始化 PaymentSheet，因为调用时已经在主线程
        // 移除异步延迟，加快支付页面显示速度
        setupPaymentElement(with: clientSecret)
    }

    /// 统一的支付方式切换入口（便于扩展更多支付方式）
    /// 优化：立即更新 UI，延迟准备支付方式，避免阻塞
    /// 注意：微信支付使用 Checkout Session，不需要预先创建 PaymentIntent
    func selectPaymentMethod(_ method: PaymentMethodType) {
        // 如果已经是当前选择的方式，直接返回，避免重复操作
        guard selectedPaymentMethod != method else {
            return
        }
        
        // 立即更新 UI，不阻塞
        selectedPaymentMethod = method

        // 延迟准备支付方式，避免阻塞 UI 切换动画
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self = self, self.selectedPaymentMethod == method else {
                return
            }
            
            switch method {
            case .card:
                // 银行卡使用 PaymentSheet，需要创建只包含 card 的 PaymentIntent
                // 移除批准流程的特殊处理，始终创建新的 PI 以确保只包含 card
                self.clearPaymentSheetAndSecretForMethodSwitch()
                self.createPaymentIntent(isMethodSwitch: true)
            case .wechatPay:
                // 微信支付使用 Checkout Session，不需要预先创建 PaymentIntent
                // 显示加载状态 2 秒，防止用户点击太快导致 Checkout Session 还未创建好
                self.isSwitchingPaymentMethod = true
                Logger.debug("微信支付准备中，显示加载状态 2 秒", category: .api)
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                    guard let self = self, self.selectedPaymentMethod == .wechatPay else { return }
                    self.isSwitchingPaymentMethod = false
                    Logger.debug("微信支付准备完成", category: .api)
                }
            case .alipayPay:
                // 支付宝使用 PaymentSheet，需要创建包含 alipay 的 PaymentIntent
                self.clearPaymentSheetAndSecretForMethodSwitch()
                self.createPaymentIntent(isMethodSwitch: true)
            case .applePay:
                // Apple Pay 用原生流程，可复用已有 PI（因为后端会自动处理）
                if self.activeClientSecret == nil {
                    self.createPaymentIntent()
                }
            }
        }
    }
    
    /// 切换银行卡/微信/支付宝时清空 PI 与 PaymentSheet，后续 create 会按当前选中方式建单方式 PI
    /// 保留 paymentResponse（金额、步骤）用于展示，仅清空 sheet/secret；置 isSwitchingPaymentMethod 以显示「准备中」
    private func clearPaymentSheetAndSecretForMethodSwitch() {
        isSwitchingPaymentMethod = true
        initialClientSecret = nil
        paymentSheet = nil
        paymentSheetClientSecret = nil
    }
    
    func createPaymentIntent(couponCode: String? = nil, userCouponId: Int? = nil, isMethodSwitch: Bool = false) {
        // 防止重复请求
        guard !isCreatingPaymentIntent else {
            Logger.debug("支付意图创建中，跳过重复请求", category: .network)
            return
        }
        
        isCreatingPaymentIntent = true
        if !isMethodSwitch { isLoading = true }
        errorMessage = nil
        
        var requestBody: [String: Any] = [
            "payment_method": "stripe"  // 只支持 Stripe 支付
        ]
        
        // 传首选支付方式，后端创建仅含该方式的 PI，PaymentSheet 直接进对应流程不弹选择窗
        if let preferred = preferredPaymentMethodForAPI {
            requestBody["preferred_payment_method"] = preferred
            Logger.debug("createPaymentIntent 传入 preferred_payment_method=\(preferred)", category: .api)
        }
        
        // 优先使用传入的 couponCode，否则使用已选择的优惠券
        let finalCouponCode = couponCode ?? selectedCoupon?.coupon.code
        if let finalCouponCode = finalCouponCode {
            requestBody["coupon_code"] = finalCouponCode.uppercased()
        } else if let userCouponId = userCouponId ?? selectedCoupon?.id {
            requestBody["user_coupon_id"] = userCouponId
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
                self?.isSwitchingPaymentMethod = false
                if case .failure(let error) = completion {
                    self?.errorMessage = error.userFriendlyMessage
                }
            },
            receiveValue: { [weak self] response in
                self?.isCreatingPaymentIntent = false
                self?.isLoading = false
                self?.isSwitchingPaymentMethod = false
                self?.handlePaymentResponse(response)
            }
        )
        .store(in: &cancellables)
    }
    
    private func handlePaymentResponse(_ response: PaymentResponse) {
        // 保存支付响应信息
        paymentResponse = response
        
        Logger.debug("处理支付响应: finalAmount=\(response.finalAmount), hasClientSecret=\(response.clientSecret != nil)", category: .api)
        
        // 如果使用优惠券全额抵扣，直接成功（无需支付）
        if response.finalAmount == 0 {
            Logger.info("优惠券全额抵扣，无需支付", category: .api)
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

        isSwitchingPaymentMethod = false
        // 无论当前选择哪种支付方式，都预热 PaymentSheet（用于信用卡支付）
        ensurePaymentSheetReady()
    }
    
    // 不再需要 confirmPayment 方法，直接使用 PaymentSheet.present()
    
    private func formatPaymentError(_ error: Error) -> String {
        let errorDescription = error.localizedDescription.lowercased()
        let nsError = error as NSError
        
        // 检查 Stripe 特定错误域
        if nsError.domain == "com.stripe.lib" || nsError.domain.contains("stripe") {
            // Stripe SDK 错误代码处理
            switch nsError.code {
            case 50: // STPAPIError
                return "支付服务暂时不可用，请稍后重试"
            case 60: // STPConnectionError
                return "网络连接失败，请检查网络后重试"
            case 70: // STPInvalidRequestError
                return "支付请求无效，请重试"
            case 80: // STPAuthenticationError
                return "支付验证失败，请重试"
            default:
                break
            }
        }
        
        // 检查是否有 Stripe 返回的错误消息
        if let stripeErrorMessage = nsError.userInfo["com.stripe.lib:StripeErrorMessageKey"] as? String {
            let lowerMessage = stripeErrorMessage.lowercased()
            
            // 支付方式不匹配错误
            if lowerMessage.contains("payment_method_type") || lowerMessage.contains("not allowed") {
                return "当前支付方式不可用，请选择其他支付方式"
            }
            
            // 支付方式未启用
            if lowerMessage.contains("not enabled") || lowerMessage.contains("not supported") {
                return "该支付方式暂不可用，请选择其他支付方式"
            }
        }
        
        // 常见错误的中文化（基于错误描述）
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
        } else if errorDescription.contains("authentication") || errorDescription.contains("authenticate") {
            return "支付验证失败，请重试"
        } else if errorDescription.contains("canceled") || errorDescription.contains("cancelled") {
            return "支付已取消"
        } else if errorDescription.contains("invalid") && errorDescription.contains("request") {
            return "支付请求无效，请重试"
        }
        
        // 特殊处理"意外错误"（来自 Stripe SDK 的本地化消息）
        if errorDescription.contains("unexpected") || errorDescription.contains("意外") {
            return "支付服务暂时不可用，请稍后重试或使用其他支付方式"
        }
        
        // 默认错误消息
        return "支付失败: \(error.localizedDescription)"
    }
    
    // 保留用于兼容性（如果需要弹出式 Payment Sheet）
    func handlePaymentResult(_ result: PaymentSheetResult) {
        Logger.debug("PaymentSheet 结果处理", category: .api)
        
        switch result {
        case .completed:
            Logger.info("PaymentSheet 支付成功", category: .api)
            paymentSuccess = true
            // 清除支付缓存，因为有了新的支付记录
            CacheManager.shared.invalidatePaymentCache()
        case .failed(let error):
            let nsError = error as NSError
            Logger.error("PaymentSheet 支付失败: \(error.localizedDescription)", category: .api)
            Logger.error("PaymentSheet 错误详情 - 域: \(nsError.domain), 代码: \(nsError.code)", category: .api)
            Logger.error("PaymentSheet 错误 userInfo: \(nsError.userInfo)", category: .api)
            
            // 检查是否有嵌套的底层错误
            if let underlyingError = nsError.userInfo[NSUnderlyingErrorKey] as? NSError {
                Logger.error("PaymentSheet 底层错误 - 域: \(underlyingError.domain), 代码: \(underlyingError.code), 描述: \(underlyingError.localizedDescription)", category: .api)
            }
            
            // 使用格式化的错误消息
            errorMessage = formatPaymentError(error)
        case .canceled:
            // 用户取消，不显示错误
            Logger.debug("用户取消 PaymentSheet 支付", category: .api)
            break
        }
    }
    
    // MARK: - STPAuthenticationContext
    
    /// 返回用于显示支付认证界面的视图控制器
    /// 注意：此方法会被 Stripe SDK 调用，需要返回当前的顶层视图控制器
    func authenticationPresentingViewController() -> UIViewController {
        // 由于类已标记 @MainActor，此方法会在主线程执行
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            var topViewController = rootViewController
            while let presented = topViewController.presentedViewController {
                topViewController = presented
            }
            return topViewController
        }
        // 如果无法获取，返回一个空的视图控制器（不应该发生）
        return UIViewController()
    }
    
    // MARK: - Apple Pay 原生实现
    
    /// 检查是否支持 Apple Pay
    var isApplePaySupported: Bool {
        return ApplePayHelper.isApplePaySupported()
    }
    
    /// 使用 Apple Pay 原生实现支付
    func payWithApplePay() {
        // 记录设备信息用于调试
        let deviceType = UIDevice.current.userInterfaceIdiom == .pad ? "iPad" : "iPhone"
        let deviceModel = UIDevice.current.model
        Logger.debug("开始 Apple Pay 支付流程 - 设备类型: \(deviceType), 型号: \(deviceModel)", category: .api)
        
        guard let merchantId = Constants.Stripe.applePayMerchantIdentifier else {
            errorMessage = "Apple Pay 未配置，请使用其他支付方式"
            Logger.warning("Apple Pay Merchant ID 未配置", category: .api)
            return
        }

        // 检查设备是否支持 Apple Pay
        guard ApplePayHelper.isApplePaySupported() else {
            errorMessage = "此设备不支持 Apple Pay，请使用其他支付方式"
            Logger.warning("设备不支持 Apple Pay - 设备类型: \(deviceType)", category: .api)
            return
        }
        
        // 检查用户是否已添加支付卡
        guard ApplePayHelper.canMakePayments() else {
            errorMessage = "请先在\"设置\"中添加支付卡以使用 Apple Pay"
            Logger.warning("用户未添加支付卡 - 设备类型: \(deviceType)", category: .api)
            return
        }

        // 必须有 client_secret 才能确认 PaymentIntent
        guard let clientSecret = activeClientSecret else {
            errorMessage = "支付信息未准备好，请稍后再试"
            Logger.warning("缺少 client_secret，无法使用 Apple Pay，尝试创建支付意图 - 设备类型: \(deviceType)", category: .api)
            createPaymentIntent()
            return
        }
        
        // 验证 clientSecret 格式
        guard clientSecret.contains("_secret_") else {
            errorMessage = "支付信息无效，请刷新页面重试"
            Logger.error("Apple Pay clientSecret 格式无效: \(clientSecret.prefix(30))... - 设备类型: \(deviceType)", category: .api)
            return
        }

        // 检查最终支付金额
        guard activeFinalAmountPence > 0 else {
            Logger.info("最终支付金额为 0，无需支付", category: .api)
            paymentSuccess = true
            return
        }
        
        Logger.debug("Apple Pay 参数验证通过 - clientSecret: \(clientSecret.prefix(20))..., 金额: \(activeFinalAmountPence) 便士", category: .api)
        
        // 创建支付请求
        let currency = activeCurrency
        let amountDecimal = ApplePayHelper.decimalAmount(
            from: activeFinalAmountPence,
            currency: currency
        )
        
        Logger.debug("创建 Apple Pay 支付请求 - 金额: \(amountDecimal), 货币: \(currency), 设备类型: \(deviceType)", category: .api)
        
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
            let errorMsg = "无法创建 Apple Pay 支付表单 - 设备类型: \(deviceType)"
            Logger.error(errorMsg, category: .api)
            errorMessage = "无法启动 Apple Pay，请使用其他支付方式"
            return
        }
        
        self.applePayContext = applePayContext
        
        // 展示支付表单（使用新的 API，不需要传入 viewController）
        Logger.debug("准备弹出 Apple Pay 表单 - 设备类型: \(deviceType)", category: .api)
        
        // 在主线程执行，确保UI操作正确
        DispatchQueue.main.async {
            applePayContext.presentApplePay {
                // completion 回调，成功时调用
                Logger.debug("Apple Pay 表单已显示 - 设备类型: \(deviceType)", category: .api)
            }
            
            // 注意：如果 presentApplePay 失败，错误会通过 delegate 方法处理
            // 但为了更好的错误处理，我们也可以在这里添加超时检查
        }
    }
    
    // MARK: - ApplePayContextDelegate
    
    func applePayContext(
        _ context: STPApplePayContext,
        didCreatePaymentMethod paymentMethod: StripeAPI.PaymentMethod,
        paymentInformation: PKPayment
    ) async throws -> String {
        let deviceType = UIDevice.current.userInterfaceIdiom == .pad ? "iPad" : "iPhone"
        Logger.debug("Apple Pay 支付方法已创建 - 设备类型: \(deviceType)", category: .api)
        
        guard let clientSecret = activeClientSecret else {
            let errorMsg = "无法获取支付信息 - 设备类型: \(deviceType)"
            Logger.error(errorMsg, category: .api)
            throw NSError(
                domain: "ApplePayError",
                code: -1,
                userInfo: [
                    NSLocalizedDescriptionKey: "无法获取支付信息",
                    "device_type": deviceType
                ]
            )
        }
        
        Logger.debug("返回 client_secret 用于确认支付 - 设备类型: \(deviceType)", category: .api)
        return clientSecret
    }
    
    func applePayContext(
        _ context: STPApplePayContext,
        didCompleteWith status: STPApplePayContext.PaymentStatus,
        error: Error?
    ) {
        let deviceType = UIDevice.current.userInterfaceIdiom == .pad ? "iPad" : "iPhone"
        
        switch status {
        case .success:
            Logger.info("Apple Pay 支付成功 - 设备类型: \(deviceType)", category: .api)
            paymentSuccess = true
            errorMessage = nil
            // 清除支付缓存，因为有了新的支付记录
            CacheManager.shared.invalidatePaymentCache()
        case .error:
            if let error = error {
                let errorDescription = error.localizedDescription
                let errorDetails = "Apple Pay 支付失败 - 设备类型: \(deviceType), 错误: \(errorDescription)"
                Logger.error(errorDetails, category: .api)
                
                // 记录错误的详细信息
                if let nsError = error as NSError? {
                    Logger.error("错误详情 - 域: \(nsError.domain), 代码: \(nsError.code), 用户信息: \(nsError.userInfo)", category: .api)
                }
                
                // 提供更友好的错误消息
                if errorDescription.contains("cancelled") || errorDescription.contains("canceled") {
                    // 用户取消，不显示错误
                    Logger.debug("用户取消了 Apple Pay 支付", category: .api)
                } else {
                    errorMessage = formatPaymentError(error)
                }
            } else {
                let errorMsg = "Apple Pay 支付失败（未知错误） - 设备类型: \(deviceType)"
                Logger.error(errorMsg, category: .api)
                errorMessage = "支付失败，请重试或使用其他支付方式"
            }
        case .userCancellation:
            Logger.debug("用户取消 Apple Pay 支付 - 设备类型: \(deviceType)", category: .api)
            // 用户取消，不显示错误消息
            break
        @unknown default:
            let errorMsg = "Apple Pay 支付未知状态 - 设备类型: \(deviceType)"
            Logger.warning(errorMsg, category: .api)
            errorMessage = "支付过程中出现未知错误，请重试"
        }
    }
    
    // MARK: - 微信支付
    
    /// 使用微信支付（通过 WebView 显示 Stripe Checkout 二维码）
    /// 
    /// 重要：Stripe iOS PaymentSheet 不支持微信支付（官方文档确认）
    /// 解决方案：创建 Stripe Checkout Session，在 WebView 中加载支付页面让用户扫码
    func confirmWeChatPayment() {
        Logger.debug("开始微信支付流程（WebView Checkout）", category: .api)
        
        guard activeFinalAmountPence > 0 else {
            Logger.info("最终支付金额为 0，无需支付", category: .api)
            paymentSuccess = true
            return
        }
        
        // 调用后端 API 创建微信支付 Checkout Session
        createWeChatCheckoutSession()
    }
    
    /// 创建微信支付 Checkout Session
    private func createWeChatCheckoutSession() {
        guard !isCreatingWeChatCheckout else {
            Logger.debug("微信支付 Checkout Session 创建中，跳过重复请求", category: .network)
            return
        }
        
        isCreatingWeChatCheckout = true
        errorMessage = nil
        
        // 构建请求参数
        var requestBody: [String: Any] = [:]
        
        // 如果有选择的优惠券，传递优惠券信息
        if let coupon = selectedCoupon {
            if !coupon.coupon.code.isEmpty {
                requestBody["coupon_code"] = coupon.coupon.code.uppercased()
            } else {
                requestBody["user_coupon_id"] = coupon.id
            }
        }
        
        Logger.debug("创建微信支付 Checkout Session - taskId: \(taskId)", category: .api)
        
        // 调用后端 API
        apiService.request(
            WeChatCheckoutResponse.self,
            APIEndpoints.Payment.createWeChatCheckout(taskId),
            method: "POST",
            body: requestBody.isEmpty ? nil : requestBody
        )
        .receive(on: DispatchQueue.main)
        .sink(
            receiveCompletion: { [weak self] completion in
                self?.isCreatingWeChatCheckout = false
                if case .failure(let error) = completion {
                    Logger.error("创建微信支付 Checkout Session 失败: \(error.localizedDescription)", category: .api)
                    self?.errorMessage = error.userFriendlyMessage
                }
            },
            receiveValue: { [weak self] response in
                self?.isCreatingWeChatCheckout = false
                self?.handleWeChatCheckoutResponse(response)
            }
        )
        .store(in: &cancellables)
    }
    
    /// 处理微信支付 Checkout Session 响应
    private func handleWeChatCheckoutResponse(_ response: WeChatCheckoutResponse) {
        // 如果优惠券全额抵扣，直接成功
        if response.couponFullDiscount == true {
            Logger.info("微信支付：优惠券全额抵扣，支付成功", category: .api)
            paymentSuccess = true
            return
        }
        
        // 检查是否有 checkout URL
        guard let checkoutURL = response.checkoutURL, !checkoutURL.isEmpty else {
            Logger.error("微信支付 Checkout URL 为空", category: .api)
            errorMessage = "无法创建微信支付页面，请稍后重试"
            return
        }
        
        Logger.info("微信支付 Checkout Session 创建成功，URL: \(checkoutURL.prefix(50))...", category: .api)
        
        // 保存 URL 并显示 WebView
        wechatPayCheckoutURL = checkoutURL
        showWeChatPayWebView = true
    }
    
    /// 微信支付 WebView 成功回调
    func handleWeChatPaymentSuccess() {
        Logger.info("微信支付 WebView 回调：支付成功", category: .api)
        showWeChatPayWebView = false
        wechatPayCheckoutURL = nil
        paymentSuccess = true
    }
    
    /// 微信支付 WebView 取消回调
    func handleWeChatPaymentCancel() {
        Logger.info("微信支付 WebView 回调：用户取消", category: .api)
        showWeChatPayWebView = false
        wechatPayCheckoutURL = nil
        // 不显示错误消息，用户主动取消
    }
    
    /// 微信支付 WebView 错误回调
    func handleWeChatPaymentError(_ error: String) {
        Logger.error("微信支付 WebView 回调：错误 - \(error)", category: .api)
        showWeChatPayWebView = false
        wechatPayCheckoutURL = nil
        errorMessage = error
    }
    
    /// 使用支付宝（通过 PaymentSheet，与微信一致）
    /// 后端已创建仅含 alipay 的 PI，Sheet 只显示支付宝入口并由 SDK 统一处理跳转与回调，避免 STPPaymentHandler 直接 confirm 导致的闪退
    func confirmAlipayPaymentViaPaymentSheet() {
        Logger.debug("开始支付宝支付流程（PaymentSheet）", category: .api)
        
        guard let clientSecret = activeClientSecret else {
            errorMessage = "支付信息未准备好，请稍后再试"
            Logger.warning("缺少 client_secret，无法使用支付宝支付", category: .api)
            createPaymentIntent()
            return
        }
        
        guard clientSecret.contains("_secret_") else {
            errorMessage = "支付信息无效，请刷新页面重试"
            Logger.error("支付宝 clientSecret 格式无效: \(clientSecret.prefix(30))...", category: .api)
            return
        }
        
        guard activeFinalAmountPence > 0 else {
            Logger.info("最终支付金额为 0，无需支付", category: .api)
            paymentSuccess = true
            return
        }
        
        Logger.debug("支付宝 PaymentSheet 参数 - clientSecret: \(clientSecret.prefix(20))..., 金额: \(activeFinalAmountPence) 便士", category: .api)
        
        if let paymentSheet = paymentSheet {
            presentPaymentSheet(from: paymentSheet)
        } else {
            errorMessage = "支付表单未准备好，请稍后重试"
            Logger.warning("支付宝 PaymentSheet 为 nil，尝试重新创建", category: .api)
            ensurePaymentSheetReady()
        }
    }
    
    /// 弹出 PaymentSheet（银行卡 / 微信 / 支付宝共用）
    private func presentPaymentSheet(from sheet: PaymentSheet) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            errorMessage = "无法打开支付界面，请重试"
            Logger.error("无法获取顶层视图控制器", category: .api)
            return
        }
        var topViewController = rootViewController
        while let presented = topViewController.presentedViewController {
            topViewController = presented
        }
        Logger.debug("准备弹出 PaymentSheet", category: .api)
        startPollingPaymentStatus()
        sheet.present(from: topViewController) { [weak self] result in
            Logger.debug("PaymentSheet 结果: \(result)", category: .api)
            self?.stopPollingPaymentStatus()
            self?.handlePaymentResult(result)
        }
    }

    /// 开始轮询任务支付状态（银行卡/支付宝等延迟方式：Stripe 确认后 1～2 秒内即可发现成功，与 Flutter 一致）
    private func startPollingPaymentStatus() {
        stopPollingPaymentStatus()
        paymentStatusPollCount = 0
        paymentStatusPollTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
            guard let viewModel = self else { return }
            DispatchQueue.main.async {
                viewModel.firePaymentStatusPoll()
            }
        }
        RunLoop.main.add(paymentStatusPollTimer!, forMode: .common)
    }

    private func firePaymentStatusPoll() {
        guard paymentStatusPollTimer != nil else { return }
        paymentStatusPollCount += 1
        if paymentStatusPollCount > 90 {
            stopPollingPaymentStatus()
            return
        }
        checkPaymentStatus { [weak self] alreadyPaid in
            guard let viewModel = self else { return }
            DispatchQueue.main.async {
                if alreadyPaid {
                    Logger.info("✅ 轮询检测到支付已完成", category: .api)
                    viewModel.stopPollingPaymentStatus()
                    viewModel.paymentSuccess = true
                    viewModel.errorMessage = nil
                    CacheManager.shared.invalidatePaymentCache()
                    viewModel.dismissTopPresentedIfNeeded()
                    return
                }
                let interval: TimeInterval = viewModel.paymentStatusPollCount <= 30 ? 1.0 : 2.0
                viewModel.paymentStatusPollTimer?.invalidate()
                viewModel.paymentStatusPollTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
                    guard let vm = self else { return }
                    DispatchQueue.main.async {
                        vm.firePaymentStatusPoll()
                    }
                }
                RunLoop.main.add(viewModel.paymentStatusPollTimer!, forMode: .common)
            }
        }
    }

    private func stopPollingPaymentStatus() {
        paymentStatusPollTimer?.invalidate()
        paymentStatusPollTimer = nil
        paymentStatusPollCount = 0
    }

    /// 轮询发现支付成功时，关闭可能仍盖在前面的 PaymentSheet，以便用户看到成功页
    private func dismissTopPresentedIfNeeded() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let root = windowScene.windows.first?.rootViewController else { return }
        var top = root
        while let presented = top.presentedViewController {
            top = presented
        }
        if top !== root {
            top.dismiss(animated: true)
        }
    }

    /// 处理直接支付结果（支付宝/微信）
    private func handleDirectPaymentResult(status: STPPaymentHandlerActionStatus, error: Error?, paymentMethod: String) {
        Logger.debug("\(paymentMethod)支付结果处理 - 状态: \(status.rawValue)", category: .api)
        
        switch status {
        case .succeeded:
            Logger.info("\(paymentMethod)支付成功", category: .api)
            paymentSuccess = true
            errorMessage = nil
            // 清除支付缓存，因为有了新的支付记录
            CacheManager.shared.invalidatePaymentCache()
            
        case .canceled:
            Logger.debug("用户取消\(paymentMethod)支付", category: .api)
            // 用户取消，不显示错误消息
            
        case .failed:
            if let error = error {
                let errorDescription = error.localizedDescription
                Logger.error("\(paymentMethod)支付失败: \(errorDescription)", category: .api)
                
                // 记录错误的详细信息
                let nsError = error as NSError
                Logger.error("错误详情 - 域: \(nsError.domain), 代码: \(nsError.code)", category: .api)
                Logger.error("错误 userInfo: \(nsError.userInfo)", category: .api)
                
                // 检查是否有嵌套的底层错误
                if let underlyingError = nsError.userInfo[NSUnderlyingErrorKey] as? NSError {
                    Logger.error("底层错误 - 域: \(underlyingError.domain), 代码: \(underlyingError.code), 描述: \(underlyingError.localizedDescription)", category: .api)
                }
                
                errorMessage = formatPaymentError(error)
            } else {
                Logger.error("\(paymentMethod)支付失败（未知错误，error 为 nil）", category: .api)
                errorMessage = "支付失败，请重试或使用其他支付方式"
            }
            
        @unknown default:
            Logger.warning("\(paymentMethod)支付未知状态: \(status.rawValue)", category: .api)
            errorMessage = "支付过程中出现未知错误，请重试"
        }
    }
    
    /// 执行支付（根据选择的支付方式）
    func performPayment() {
        Logger.debug("执行支付 - 支付方式: \(selectedPaymentMethod.rawValue)", category: .api)
        
        // 微信支付使用 Checkout Session，不需要 clientSecret
        // 其他支付方式（银行卡、Apple Pay、支付宝）需要 clientSecret
        if selectedPaymentMethod == .wechatPay {
            // 微信支付：直接调用创建 Checkout Session，无需 clientSecret
            Logger.debug("使用微信支付（WebView Checkout），无需 clientSecret", category: .api)
            confirmWeChatPayment()
            return
        }
        
        // 非微信支付：必须有 client_secret 才能发起支付
        guard let clientSecret = activeClientSecret else {
            errorMessage = "支付信息未准备好，正在加载..."
            Logger.warning("缺少 client_secret，重新创建支付意图", category: .api)
            createPaymentIntent()
            return
        }
        
        // 验证 clientSecret 格式（Stripe clientSecret 格式: pi_xxx_secret_xxx）
        guard clientSecret.contains("_secret_") else {
            errorMessage = "支付信息无效，请刷新页面重试"
            Logger.error("clientSecret 格式无效: \(clientSecret.prefix(30))...", category: .api)
            return
        }

        // 检查最终支付金额
        guard activeFinalAmountPence > 0 else {
            Logger.info("最终支付金额为 0，无需支付", category: .api)
            paymentSuccess = true
            return
        }
        
        Logger.debug("支付参数验证通过 - clientSecret: \(clientSecret.prefix(20))..., 金额: \(activeFinalAmountPence) 便士", category: .api)
        
        switch selectedPaymentMethod {
        case .card:
            // 银行卡：使用 PaymentSheet
            if let paymentSheet = paymentSheet {
                presentPaymentSheet(from: paymentSheet)
            } else {
                errorMessage = "支付表单未准备好，请稍后重试"
                Logger.warning("PaymentSheet 为 nil，尝试重新创建", category: .api)
                ensurePaymentSheetReady()
            }
        case .applePay:
            Logger.debug("使用 Apple Pay 原生实现支付", category: .api)
            payWithApplePay()
        case .wechatPay:
            // 已在上方处理，不应到达此处
            break
        case .alipayPay:
            // 支付宝：改用 PaymentSheet 统一处理（与微信一致），避免 STPPaymentHandler 直接跳转导致的闪退
            Logger.debug("使用支付宝（PaymentSheet）", category: .api)
            confirmAlipayPaymentViaPaymentSheet()
        }
    }
    
    // MARK: - 支付状态检查
    
    /// 检查任务支付状态（用于检测支付是否已在后台完成，例如闪退后重新打开）
    /// - Parameter completion: 完成回调，参数为是否已支付成功
    func checkPaymentStatus(completion: ((Bool) -> Void)? = nil) {
        Logger.debug("检查任务支付状态: taskId=\(taskId)", category: .api)
        
        apiService.request(
            TaskPaymentStatusResponse.self,
            APIEndpoints.Payment.getTaskPaymentStatus(taskId),
            method: "GET"
        )
        .sink(
            receiveCompletion: { result in
                if case .failure(let error) = result {
                    Logger.warning("检查支付状态失败: \(error.localizedDescription)", category: .api)
                    completion?(false)
                }
            },
            receiveValue: { [weak self] response in
                Logger.debug("支付状态响应: is_paid=\(response.isPaid), status=\(response.status)", category: .api)
                
                // 检查 Stripe PaymentIntent 状态
                if let paymentDetails = response.paymentDetails {
                    Logger.debug("PaymentIntent 状态: \(paymentDetails.status)", category: .api)
                    
                    // 如果 PaymentIntent 状态是 succeeded，说明支付已完成
                    if paymentDetails.status == "succeeded" {
                        Logger.info("✅ 检测到支付已完成（PaymentIntent succeeded），更新状态", category: .api)
                        self?.paymentSuccess = true
                        self?.errorMessage = nil
                        CacheManager.shared.invalidatePaymentCache()
                        completion?(true)
                        return
                    }
                }
                
                // 检查任务是否已支付
                if response.isPaid {
                    Logger.info("✅ 检测到任务已支付（is_paid=true），更新状态", category: .api)
                    self?.paymentSuccess = true
                    self?.errorMessage = nil
                    CacheManager.shared.invalidatePaymentCache()
                    completion?(true)
                    return
                }
                
                completion?(false)
            }
        )
        .store(in: &cancellables)
    }
}

// MARK: - Task Payment Status Response Model
/// 任务支付状态响应（只读查询）
struct TaskPaymentStatusResponse: Codable {
    let taskId: Int
    let isPaid: Bool
    let paymentIntentId: String?
    let taskAmount: Double
    let escrowAmount: Double?
    let status: String
    let currency: String
    let paymentExpiresAt: String?
    let paymentDetails: PaymentIntentDetails?
    
    enum CodingKeys: String, CodingKey {
        case taskId = "task_id"
        case isPaid = "is_paid"
        case paymentIntentId = "payment_intent_id"
        case taskAmount = "task_amount"
        case escrowAmount = "escrow_amount"
        case status
        case currency
        case paymentExpiresAt = "payment_expires_at"
        case paymentDetails = "payment_details"
    }
}

/// PaymentIntent 详情
struct PaymentIntentDetails: Codable {
    let paymentIntentId: String
    let status: String  // succeeded, processing, requires_payment_method, etc.
    let amount: Int
    let amountDisplay: String
    let currency: String
    let created: Int
    let charges: [ChargeInfo]?
    
    enum CodingKeys: String, CodingKey {
        case paymentIntentId = "payment_intent_id"
        case status
        case amount
        case amountDisplay = "amount_display"
        case currency
        case created
        case charges
    }
}

/// Charge 信息
struct ChargeInfo: Codable {
    let chargeId: String
    let status: String
    let amount: Int
    let receiptUrl: String?
    
    enum CodingKeys: String, CodingKey {
        case chargeId = "charge_id"
        case status
        case amount
        case receiptUrl = "receipt_url"
    }
}

// MARK: - Payment Response Model
// 计算步骤模型
struct CalculationStep: Codable {
    let label: String
    let amount: Int
    let amountDisplay: String
    let type: String  // original, discount, final
    
    enum CodingKeys: String, CodingKey {
        case label
        case amount
        case amountDisplay = "amount_display"
        case type
    }
    
    // 显式实现解码，确保 CodingKeys 生效
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        label = try container.decode(String.self, forKey: .label)
        amount = try container.decode(Int.self, forKey: .amount)
        amountDisplay = try container.decode(String.self, forKey: .amountDisplay)
        type = try container.decode(String.self, forKey: .type)
    }
    
    // 显式实现编码
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(label, forKey: .label)
        try container.encode(amount, forKey: .amount)
        try container.encode(amountDisplay, forKey: .amountDisplay)
        try container.encode(type, forKey: .type)
    }
}

struct PaymentResponse: Codable {
    let paymentId: Int?
    let feeType: String
    // 新的支付计算详情
    let originalAmount: Int
    let originalAmountDisplay: String
    let couponDiscount: Int?
    let couponDiscountDisplay: String?
    let couponName: String?
    let couponType: String?
    let couponDescription: String?
    let currency: String
    let finalAmount: Int
    let finalAmountDisplay: String
    let clientSecret: String?
    let paymentIntentId: String?
    let customerId: String?
    let ephemeralKeySecret: String?
    let calculationSteps: [CalculationStep]?
    let note: String
    
    // 兼容旧字段（用于向后兼容）
    var totalAmount: Int { originalAmount }
    var totalAmountDisplay: String { originalAmountDisplay }
    var pointsUsed: Int? { nil }  // 不再使用积分支付
    var pointsUsedDisplay: String? { nil }
    var stripeAmount: Int? { finalAmount }
    var stripeAmountDisplay: String? { finalAmountDisplay }
    var checkoutUrl: String? { nil }
    
    enum CodingKeys: String, CodingKey {
        case paymentId = "payment_id"
        case feeType = "fee_type"
        case originalAmount = "original_amount"
        case originalAmountDisplay = "original_amount_display"
        case couponDiscount = "coupon_discount"
        case couponDiscountDisplay = "coupon_discount_display"
        case couponName = "coupon_name"
        case couponType = "coupon_type"
        case couponDescription = "coupon_description"
        case currency
        case finalAmount = "final_amount"
        case finalAmountDisplay = "final_amount_display"
        case clientSecret = "client_secret"
        case paymentIntentId = "payment_intent_id"
        case customerId = "customer_id"
        case ephemeralKeySecret = "ephemeral_key_secret"
        case calculationSteps = "calculation_steps"
        case note
    }
}

/// 微信支付 Checkout Session 响应
/// 用于 iOS 微信支付，因为 PaymentSheet 不支持微信支付
struct WeChatCheckoutResponse: Codable {
    /// Stripe Checkout Session URL（用户在 WebView 中打开此 URL 扫码支付）
    let checkoutURL: String?
    /// Checkout Session ID（用于查询状态）
    let sessionId: String?
    /// 是否优惠券全额抵扣（如果是，则不需要支付）
    let couponFullDiscount: Bool?
    /// 支付成功消息（优惠券全额抵扣时返回）
    let message: String?
    /// 最终支付金额（便士）
    let finalAmount: Int?
    /// 最终支付金额显示
    let finalAmountDisplay: String?
    /// 货币
    let currency: String?
    /// Checkout Session 过期时间（Unix 时间戳）
    let expiresAt: Int?
    
    enum CodingKeys: String, CodingKey {
        case checkoutURL = "checkout_url"
        case sessionId = "session_id"
        case couponFullDiscount = "coupon_full_discount"
        case message
        case finalAmount = "final_amount"
        case finalAmountDisplay = "final_amount_display"
        case currency
        case expiresAt = "expires_at"
    }
}
