import Foundation
import Combine
import SwiftUI
import UIKit
import StripePaymentSheet
import StripeCore

@MainActor
class PaymentViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var paymentSheet: PaymentSheet?
    @Published var errorMessage: String?
    @Published var paymentSuccess = false
    @Published var paymentResponse: PaymentResponse?
    @Published var availableCoupons: [UserCoupon] = []
    @Published var isLoadingCoupons = false
    @Published var selectedCoupon: UserCoupon?
    
    private let apiService: APIService
    private let taskId: Int
    private let amount: Double
    private var cancellables = Set<AnyCancellable>()
    
    private var initialClientSecret: String?
    private var isCreatingPaymentIntent = false // 防止重复创建支付意图
    
    init(taskId: Int, amount: Double, clientSecret: String? = nil, apiService: APIService? = nil) {
        self.taskId = taskId
        self.amount = amount
        self.initialClientSecret = clientSecret
        self.apiService = apiService ?? APIService.shared
        
        // 初始化 Stripe
        StripeAPI.defaultPublishableKey = Constants.Stripe.publishableKey
        
        // 如果提供了 client_secret，直接创建 Payment Sheet
        if let clientSecret = clientSecret {
            setupPaymentElement(with: clientSecret)
        }
        
        // 加载可用优惠券
        loadAvailableCoupons()
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
    
    private func setupPaymentElement(with clientSecret: String) {
        // 配置 Payment Sheet
        var configuration = PaymentSheet.Configuration()
        configuration.merchantDisplayName = "LinkU"
        configuration.allowsDelayedPaymentMethods = true
        
        // 配置 Apple Pay（如果 Merchant ID 已配置）
        if let merchantId = Constants.Stripe.applePayMerchantIdentifier {
            configuration.applePay = .init(
                merchantId: merchantId,
                merchantCountryCode: "GB" // 英国，根据你的业务所在国家修改
            )
        }
        
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
        
        // 如果纯积分支付，直接成功
        if response.finalAmount == 0 {
            paymentSuccess = true
            return
        }
        
        // 如果有 client_secret，创建 Payment Sheet
        guard let clientSecret = response.clientSecret else {
            errorMessage = "无法创建支付表单"
            return
        }
        
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
            paymentSuccess = true
        case .failed(let error):
            errorMessage = error.localizedDescription
        case .canceled:
            // 用户取消，不显示错误
            break
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
        case note
    }
}
