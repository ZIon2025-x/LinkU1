import Foundation
import Combine
import StripePaymentSheet
import StripeCore

@MainActor
class PaymentViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var paymentSheet: PaymentSheet?
    @Published var errorMessage: String?
    @Published var paymentSuccess = false
    
    private let apiService: APIService
    private let taskId: Int
    private let amount: Double
    private var cancellables = Set<AnyCancellable>()
    
    init(taskId: Int, amount: Double, apiService: APIService? = nil) {
        self.taskId = taskId
        self.amount = amount
        self.apiService = apiService ?? APIService.shared
        
        // 初始化 Stripe
        StripeAPI.defaultPublishableKey = Constants.Stripe.publishableKey
    }
    
    func createPaymentIntent(paymentMethod: String = "stripe", pointsAmount: Double? = nil, couponCode: String? = nil) {
        isLoading = true
        errorMessage = nil
        
        var requestBody: [String: Any] = [
            "payment_method": paymentMethod
        ]
        
        if let pointsAmount = pointsAmount {
            requestBody["points_amount"] = Int(pointsAmount * 100) // 转换为便士
        }
        
        if let couponCode = couponCode {
            requestBody["coupon_code"] = couponCode.uppercased()
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
                self?.isLoading = false
                if case .failure(let error) = completion {
                    self?.errorMessage = error.userFriendlyMessage
                }
            },
            receiveValue: { [weak self] response in
                self?.handlePaymentResponse(response)
            }
        )
        .store(in: &cancellables)
    }
    
    private func handlePaymentResponse(_ response: PaymentResponse) {
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
        
        // 配置 Payment Sheet
        var configuration = PaymentSheet.Configuration()
        configuration.merchantDisplayName = "LinkU"
        configuration.allowsDelayedPaymentMethods = true
        
        // 创建 Payment Sheet
        paymentSheet = PaymentSheet(
            paymentIntentClientSecret: clientSecret,
            configuration: configuration
        )
    }
    
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

