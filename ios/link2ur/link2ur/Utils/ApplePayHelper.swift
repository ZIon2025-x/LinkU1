import Foundation
import PassKit
import StripeCore
import StripeApplePay

/// Apple Pay 辅助类
/// 提供设备支持检查、支付请求创建等功能
@MainActor
class ApplePayHelper {
    
    /// 检查设备是否支持 Apple Pay
    /// - Returns: 如果设备支持 Apple Pay 且用户已添加支付卡，返回 true
    static func isApplePaySupported() -> Bool {
        return StripeAPI.deviceSupportsApplePay()
    }
    
    /// 检查设备是否支持 Apple Pay（包括检查是否有可用的支付卡）
    /// - Returns: 如果设备支持且用户已添加支付卡，返回 true
    static func canMakePayments() -> Bool {
        return PKPaymentAuthorizationController.canMakePayments()
    }
    
    /// 检查设备是否支持 Apple Pay，但用户可能还没有添加支付卡
    /// - Returns: 如果设备支持 Apple Pay，返回 true
    static func canMakePaymentsUsingNetworks() -> Bool {
        return PKPaymentAuthorizationController.canMakePayments(usingNetworks: [.visa, .masterCard, .amex, .discover, .chinaUnionPay])
    }
    
    /// 创建 Apple Pay 支付请求
    /// - Parameters:
    ///   - merchantIdentifier: Apple Merchant ID
    ///   - countryCode: 国家代码（如 "US", "GB", "CN"）
    ///   - currency: 货币代码（如 "USD", "GBP", "CNY"）
    ///   - amount: 支付金额（以最小货币单位，如美分为单位）
    ///   - summaryItems: 支付摘要项列表（可选，如果提供则使用这些项，否则使用默认项）
    /// - Returns: 配置好的 PKPaymentRequest
    static func createPaymentRequest(
        merchantIdentifier: String,
        countryCode: String,
        currency: String,
        amount: Decimal,
        summaryItems: [PKPaymentSummaryItem]? = nil
    ) -> PKPaymentRequest {
        // 使用 Stripe 的辅助方法创建支付请求
        let paymentRequest = StripeAPI.paymentRequest(
            withMerchantIdentifier: merchantIdentifier,
            country: countryCode,
            currency: currency
        )
        
        // 如果提供了自定义摘要项，使用它们；否则创建默认项
        if let summaryItems = summaryItems {
            paymentRequest.paymentSummaryItems = summaryItems
        } else {
            // 创建默认摘要项
            let amountDecimal = NSDecimalNumber(decimal: amount)
            let totalItem = PKPaymentSummaryItem(
                label: "Link²Ur",
                amount: amountDecimal
            )
            paymentRequest.paymentSummaryItems = [totalItem]
        }
        
        // 配置支付请求
        paymentRequest.requiredShippingContactFields = []
        paymentRequest.requiredBillingContactFields = []
        
        return paymentRequest
    }
    
    /// 创建支付摘要项列表
    /// - Parameters:
    ///   - items: 商品项列表（标签和金额）
    ///   - tax: 税费（可选）
    ///   - total: 总金额
    ///   - merchantName: 商户名称（默认 "Link²Ur"）
    /// - Returns: 支付摘要项列表
    static func createSummaryItems(
        items: [(label: String, amount: Decimal)],
        tax: Decimal? = nil,
        total: Decimal,
        merchantName: String = "Link²Ur"
    ) -> [PKPaymentSummaryItem] {
        var summaryItems: [PKPaymentSummaryItem] = []
        
        // 添加商品项
        for item in items {
            let itemAmount = NSDecimalNumber(decimal: item.amount)
            let summaryItem = PKPaymentSummaryItem(
                label: item.label,
                amount: itemAmount
            )
            summaryItems.append(summaryItem)
        }
        
        // 添加税费（如果有）
        if let tax = tax {
            let taxAmount = NSDecimalNumber(decimal: tax)
            let taxItem = PKPaymentSummaryItem(
                label: "税费",
                amount: taxAmount
            )
            summaryItems.append(taxItem)
        }
        
        // 添加总金额（最后一项会显示为 "Pay [商户名称] [金额]"）
        let totalAmount = NSDecimalNumber(decimal: total)
        let totalItem = PKPaymentSummaryItem(
            label: merchantName,
            amount: totalAmount
        )
        summaryItems.append(totalItem)
        
        return summaryItems
    }
    
    /// 将金额转换为 Decimal（从最小货币单位，如美分）
    /// - Parameters:
    ///   - amountInSmallestUnit: 最小货币单位的金额（如美分）
    ///   - currency: 货币代码
    /// - Returns: Decimal 金额
    static func decimalAmount(from amountInSmallestUnit: Int, currency: String) -> Decimal {
        // 获取货币的小数位数
        let decimalPlaces = getDecimalPlaces(for: currency)
        let divisor = pow(10.0, Double(decimalPlaces))
        let amount = Double(amountInSmallestUnit) / divisor
        return Decimal(amount)
    }
    
    /// 获取货币的小数位数
    /// - Parameter currency: 货币代码
    /// - Returns: 小数位数（如 USD 为 2，JPY 为 0）
    static func getDecimalPlaces(for currency: String) -> Int {
        // 零小数位货币
        let zeroDecimalCurrencies = ["JPY", "KRW", "CLP", "VND", "XOF", "XAF", "XPF"]
        if zeroDecimalCurrencies.contains(currency.uppercased()) {
            return 0
        }
        // 默认 2 位小数
        return 2
    }
}
