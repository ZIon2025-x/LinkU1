import Foundation
import StoreKit
import Combine

/// IAP错误类型
enum IAPError: Error, LocalizedError {
    case userCancelled
    case pending
    case failedVerification
    case unknown
    case productNotFound
    case networkError
    
    var errorDescription: String? {
        switch self {
        case .userCancelled:
            return "购买已取消"
        case .pending:
            return "购买正在处理中"
        case .failedVerification:
            return "购买验证失败"
        case .productNotFound:
            return "产品未找到"
        case .networkError:
            return "网络错误"
        case .unknown:
            return "未知错误"
        }
    }
}

/// IAP服务类 - 使用StoreKit 2
@MainActor
class IAPService: ObservableObject {
    static let shared = IAPService()
    
    // VIP 产品ID（需要在 App Store Connect 中创建）
    private let vipMonthlyProductID = "com.link2ur.vip.monthly"
    private let vipYearlyProductID = "com.link2ur.vip.yearly"
    
    @Published var products: [Product] = []
    @Published var purchasedProducts: Set<String> = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private var updateListenerTask: Task<Void, Error>?
    
    private init() {
        // 监听交易更新
        updateListenerTask = listenForTransactions()
        
        // 加载产品
        Task {
            await loadProducts()
            await updatePurchasedProducts()
        }
    }
    
    deinit {
        updateListenerTask?.cancel()
    }
    
    // MARK: - 产品加载
    
    /// 加载产品列表
    func loadProducts() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let productIDs = [vipMonthlyProductID, vipYearlyProductID]
            products = try await Product.products(for: productIDs)
            
            if products.isEmpty {
                errorMessage = "未找到可用的VIP产品"
            }
        } catch {
            print("加载产品失败: \(error)")
            errorMessage = "加载产品失败: \(error.localizedDescription)"
        }
    }
    
    // MARK: - 购买
    
    /// 购买产品
    func purchase(_ product: Product) async throws -> Transaction? {
        let result = try await product.purchase()
        
        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            
            // 通知后端更新用户VIP状态
            await updateVIPStatus(productID: product.id, transaction: transaction)
            
            // 完成交易
            await transaction.finish()
            
            // 更新已购买产品列表
            await updatePurchasedProducts()
            
            return transaction
        case .userCancelled:
            throw IAPError.userCancelled
        case .pending:
            throw IAPError.pending
        @unknown default:
            throw IAPError.unknown
        }
    }
    
    // MARK: - 交易验证
    
    /// 验证交易
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw IAPError.failedVerification
        case .verified(let safe):
            return safe
        }
    }
    
    // MARK: - 监听交易更新
    
    /// 监听交易更新（用于处理后台购买、续费等）
    private func listenForTransactions() -> Task<Void, Error> {
        return Task.detached { [weak self] in
            for await result in Transaction.updates {
                do {
                    let transaction = try await self?.checkVerified(result)
                    
                    // 通知后端更新VIP状态
                    if let transaction = transaction {
                        await self?.updateVIPStatus(
                            productID: transaction.productID,
                            transaction: transaction
                        )
                        await transaction.finish()
                    }
                } catch {
                    print("交易验证失败: \(error)")
                }
            }
        }
    }
    
    // MARK: - 更新已购买产品
    
    /// 更新已购买的产品列表
    func updatePurchasedProducts() async {
        var purchased: Set<String> = []
        
        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                
                // 检查产品ID是否匹配VIP产品
                if transaction.productID == vipMonthlyProductID || transaction.productID == vipYearlyProductID {
                    purchased.insert(transaction.productID)
                }
            } catch {
                print("验证交易失败: \(error)")
            }
        }
        
        purchasedProducts = purchased
    }
    
    // MARK: - 后端同步
    
    /// 验证收据并更新VIP状态
    private func updateVIPStatus(productID: String, transaction: Transaction) async {
        do {
            // 获取交易JWS表示（用于后端验证）
            let transactionJWS = transaction.jwsRepresentation
            
            // 调用后端API激活VIP
            try await APIService.shared.activateVIP(
                productID: productID,
                transactionID: String(transaction.id),
                transactionJWS: transactionJWS
            )
            
            print("VIP激活成功: \(productID)")
        } catch {
            print("激活VIP失败: \(error)")
            // 注意：即使后端激活失败，交易已经完成，用户已经付费
            // 这里应该记录错误，并可能需要手动处理
        }
    }
    
    // MARK: - 恢复购买
    
    /// 恢复购买
    func restorePurchases() async throws {
        try await AppStore.sync()
        await updatePurchasedProducts()
    }
    
    // MARK: - 检查VIP状态
    
    /// 检查用户是否有有效的VIP订阅
    func hasActiveVIPSubscription() -> Bool {
        return !purchasedProducts.isEmpty
    }
}
