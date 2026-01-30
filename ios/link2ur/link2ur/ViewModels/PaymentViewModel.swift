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
            case .card, .wechatPay, .alipayPay:
                // 银行卡 / 微信 / 支付宝 用 PaymentSheet，且每种方式对应单独 PI，直接进该方式不弹选择窗
                // 切换时废弃旧 PI、重建，避免复用「多方式」PI 导致再弹选择窗
                self.clearPaymentSheetAndSecretForMethodSwitch()
                self.createPaymentIntent()
            case .applePay:
                // Apple Pay 用原生流程，不弹 PaymentSheet；无 preferred_payment_method，可复用已有 PI
                if self.activeClientSecret == nil {
                    self.createPaymentIntent()
                }
            }
        }
    }
    
    /// 切换银行卡/微信/支付宝时清空 PI 与 PaymentSheet，后续 create 会按当前选中方式建单方式 PI
    private func clearPaymentSheetAndSecretForMethodSwitch() {
        paymentResponse = nil
        initialClientSecret = nil
        paymentSheet = nil
        paymentSheetClientSecret = nil
    }
    
    func createPaymentIntent(couponCode: String? = nil, userCouponId: Int? = nil) {
        // 防止重复请求
        guard !isCreatingPaymentIntent else {
            Logger.debug("支付意图创建中，跳过重复请求", category: .network)
            return
        }
        
        isCreatingPaymentIntent = true
        isLoading = true
        errorMessage = nil
        
        var requestBody: [String: Any] = [
            "payment_method": "stripe"  // 只支持 Stripe 支付
        ]
        
        // 传首选支付方式，后端创建仅含该方式的 PI，PaymentSheet 直接进对应流程不弹选择窗
        if let preferred = preferredPaymentMethodForAPI {
            requestBody["preferred_payment_method"] = preferred
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
        guard activeClientSecret != nil else {
            errorMessage = "支付信息未准备好，请稍后再试"
            Logger.warning("缺少 client_secret，无法使用 Apple Pay，尝试创建支付意图 - 设备类型: \(deviceType)", category: .api)
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
                ensurePaymentSheetReady()
            }
        case .alipayPay:
            // 使用 PaymentSheet 支付（支付宝通过 PaymentSheet 处理，会跳转支付宝 App/网页后通过 returnURL 返回）
            if let paymentSheet = paymentSheet {
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let rootViewController = windowScene.windows.first?.rootViewController {
                    var topViewController = rootViewController
                    while let presented = topViewController.presentedViewController {
                        topViewController = presented
                    }
                    Logger.debug("准备弹出 PaymentSheet（支付宝）", category: .api)
                    paymentSheet.present(from: topViewController) { [weak self] result in
                        Logger.debug("PaymentSheet 结果（支付宝）: \(result)", category: .api)
                        self?.handlePaymentResult(result)
                    }
                } else {
                    errorMessage = "无法打开支付界面，请重试"
                    Logger.error("无法获取顶层视图控制器", category: .api)
                }
            } else {
                errorMessage = "支付表单未准备好，请稍后重试"
                Logger.warning("PaymentSheet 为 nil，尝试重新创建", category: .api)
                ensurePaymentSheetReady()
            }
        }
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
