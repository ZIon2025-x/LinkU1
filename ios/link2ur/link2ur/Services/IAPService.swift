import Foundation
import StoreKit
import Combine

// Wrapper class to create detached task, avoiding conflict with custom Task struct
fileprivate class TaskWrapper: Cancellable {
    private var task: _Concurrency.Task<Void, Never>?
    
    init(operation: @escaping @Sendable () async -> Void) {
        // Create Swift's concurrency Task using detached
        // Use a closure that captures the operation to avoid signature mismatch
        let op: @Sendable () async -> Void = operation
        self.task = _Concurrency.Task.detached {
            await op()
        }
    }
    
    func cancel() {
        task?.cancel()
        task = nil
    }
}

fileprivate func createDetachedTask(operation: @escaping @Sendable () async -> Void) -> Cancellable {
    return TaskWrapper(operation: operation)
}

/// 产品ID枚举（Apple推荐的最佳实践）
enum ProductID: String, CaseIterable {
    case vipMonthly = "com.link2ur.vip.monthly"
    case vipYearly = "com.link2ur.vip.yearly"
    
    static var all: [String] {
        ProductID.allCases.map { $0.rawValue }
    }
}

/// IAP错误类型
enum IAPError: Error, LocalizedError {
    case userCancelled
    case pending
    case failedVerification
    case unknown
    case productNotFound
    case networkError
    case subscriptionExpired
    case subscriptionCancelled
    case upgradeFailed
    
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
        case .subscriptionExpired:
            return "订阅已过期"
        case .subscriptionCancelled:
            return "订阅已取消"
        case .upgradeFailed:
            return "订阅升级/降级失败"
        case .unknown:
            return "未知错误"
        }
    }
}

/// 订阅状态信息
struct SubscriptionStatusInfo {
    let productID: String
    let status: Product.SubscriptionInfo.Status
    let renewalInfo: Product.SubscriptionInfo.RenewalInfo?
    let transaction: Transaction?
    let expirationDate: Date?
    let isActive: Bool
    let willAutoRenew: Bool
}

/// IAP服务类 - 使用StoreKit 2（完整实现）
@MainActor
class IAPService: ObservableObject {
    static let shared = IAPService()
    
    @Published var products: [Product] = []
    @Published var purchasedProducts: Set<String> = []
    @Published var subscriptionStatuses: [String: SubscriptionStatusInfo] = [:]
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // Store as Cancellable to avoid Task name conflict
    private var updateListenerTask: Cancellable?
    private var statusListenerTask: Cancellable?
    private var unfinishedTask: Cancellable?
    private var entitlementsTask: Cancellable?
    
    private init() {
        // 处理未完成的交易（Apple推荐的最佳实践）
        // 确保应用启动时完成之前未完成的交易
        unfinishedTask = createDetachedTask { [weak self] in
            for await verificationResult in Transaction.unfinished {
                await self?.handle(updatedTransaction: verificationResult)
            }
        }
        
        // 获取当前权益（应用启动时）
        entitlementsTask = createDetachedTask { [weak self] in
            for await verificationResult in Transaction.currentEntitlements {
                await self?.handle(updatedTransaction: verificationResult)
            }
        }
        
        // 监听交易更新
        updateListenerTask = listenForTransactions()
        
        // 监听订阅状态变化
        statusListenerTask = listenForSubscriptionStatusChanges()
        
        // 加载产品 - use helper function to avoid conflict with custom Task struct
        _ = createDetachedTask { [weak self] in
            await self?.loadProducts()
            await self?.updatePurchasedProducts()
            await self?.updateSubscriptionStatuses()
        }
    }
    
    deinit {
        updateListenerTask?.cancel()
        statusListenerTask?.cancel()
        unfinishedTask?.cancel()
        entitlementsTask?.cancel()
    }
    
    // MARK: - 产品加载
    
    /// 加载产品列表
    func loadProducts() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let productIDs = ProductID.all
            products = try await Product.products(for: productIDs)
            
            if products.isEmpty {
                errorMessage = "未找到可用的VIP产品"
                Logger.warning("未找到可用的VIP产品", category: .iap)
            } else {
                Logger.info("成功加载 \(products.count) 个产品", category: .iap)
            }
        } catch {
            Logger.error("加载产品失败: \(error.localizedDescription)", category: .iap)
            errorMessage = "加载产品失败: \(error.localizedDescription)"
        }
    }
    
    // MARK: - 购买
    
    /// 购买产品（支持升级/降级）
    func purchase(_ product: Product) async throws -> Transaction? {
        // 检查是否有现有订阅，如果有则处理升级/降级
        if let existingSubscription = await getCurrentActiveSubscription() {
            return try await purchaseWithUpgrade(newProduct: product, existingProductID: existingSubscription.productID)
        }
        
        // 普通购买流程
        let result = try await product.purchase()
        
        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            
            // 获取交易的JWS表示（用于服务器端验证）
            let transactionJWS = verification.jwsRepresentation
            
            Logger.info("购买成功: \(product.id), 交易ID: \(transaction.id)", category: .iap)
            
            // 通知后端更新用户VIP状态
            await updateVIPStatus(productID: product.id, transaction: transaction, transactionJWS: transactionJWS)
            
            // 完成交易
            await transaction.finish()
            
            // 更新状态
            await updatePurchasedProducts()
            await updateSubscriptionStatuses()
            
            return transaction
        case .userCancelled:
            Logger.info("用户取消购买", category: .iap)
            throw IAPError.userCancelled
        case .pending:
            Logger.info("购买处理中", category: .iap)
            throw IAPError.pending
        @unknown default:
            Logger.error("未知购买结果", category: .iap)
            throw IAPError.unknown
        }
    }
    
    /// 购买并处理升级/降级
    private func purchaseWithUpgrade(newProduct: Product, existingProductID: String) async throws -> Transaction? {
        guard let existingProduct = products.first(where: { $0.id == existingProductID }) else {
            Logger.error("未找到现有订阅产品: \(existingProductID)", category: .iap)
            throw IAPError.productNotFound
        }
        
        // 检查是否是同一订阅组
        guard let existingSubscription = existingProduct.subscription,
              let newSubscription = newProduct.subscription,
              existingSubscription.subscriptionGroupID == newSubscription.subscriptionGroupID else {
            // 不同订阅组，直接购买
            return try await purchase(newProduct)
        }
        
        // 同一订阅组，处理升级/降级
        Logger.info("处理订阅升级/降级: \(existingProductID) -> \(newProduct.id)", category: .iap)
        
        let result = try await newProduct.purchase()
        
        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            let transactionJWS = verification.jwsRepresentation
            
            Logger.info("订阅升级/降级成功: \(newProduct.id)", category: .iap)
            
            // 通知后端更新VIP状态
            await updateVIPStatus(productID: newProduct.id, transaction: transaction, transactionJWS: transactionJWS)
            
            // 完成交易
            await transaction.finish()
            
            // 更新状态
            await updatePurchasedProducts()
            await updateSubscriptionStatuses()
            
            return transaction
        case .userCancelled:
            throw IAPError.userCancelled
        case .pending:
            throw IAPError.pending
        @unknown default:
            throw IAPError.upgradeFailed
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
    
    // MARK: - 交易处理
    
    /// 统一的交易处理方法（处理撤销、过期等情况）
    private func handle(updatedTransaction verificationResult: VerificationResult<Transaction>) async {
        guard case .verified(let transaction) = verificationResult else {
            Logger.warning("交易验证失败", category: .iap)
            return
        }
        
        // 检查是否是VIP产品
        guard ProductID(rawValue: transaction.productID) != nil else {
            Logger.warning("未知产品ID: \(transaction.productID)", category: .iap)
            await transaction.finish()
            return
        }
        
        // 处理撤销
        if let revocationDate = transaction.revocationDate {
            Logger.warning("订阅已撤销: \(transaction.productID), 撤销时间: \(revocationDate)", category: .iap)
            await handleRevocation(productID: transaction.productID)
            await transaction.finish()
            await updatePurchasedProducts()
            await updateSubscriptionStatuses()
            return
        }
        
        // 处理过期
        if let expirationDate = transaction.expirationDate, expirationDate < Date() {
            Logger.warning("订阅已过期: \(transaction.productID), 过期时间: \(expirationDate)", category: .iap)
            await handleExpiration(productID: transaction.productID)
            await updatePurchasedProducts()
            await updateSubscriptionStatuses()
            return
        }
        
        // 提供访问权限
        Logger.info("处理交易: \(transaction.productID), 交易ID: \(transaction.id)", category: .iap)
        
        // 获取交易的JWS表示（用于服务器端验证）
        let transactionJWS = verificationResult.jwsRepresentation
        
        // 通知后端更新VIP状态
        await updateVIPStatus(productID: transaction.productID, transaction: transaction, transactionJWS: transactionJWS)
        
        // 完成交易
        await transaction.finish()
        
        // 更新状态
        await updatePurchasedProducts()
        await updateSubscriptionStatuses()
    }
    
    /// 处理订阅撤销
    private func handleRevocation(productID: String) async {
        // 这里可以调用后端API移除VIP权限
        Logger.info("处理订阅撤销: \(productID)", category: .iap)
        // TODO: 调用后端API移除VIP权限
    }
    
    /// 处理订阅过期
    private func handleExpiration(productID: String) async {
        // 这里可以调用后端API更新VIP状态
        Logger.info("处理订阅过期: \(productID)", category: .iap)
        // TODO: 调用后端API更新VIP状态
    }
    
    // MARK: - 监听交易更新
    
    /// 监听交易更新（用于处理后台购买、续费等）
    private func listenForTransactions() -> Cancellable {
        return createDetachedTask { [weak self] in
            for await result in Transaction.updates {
                await self?.handle(updatedTransaction: result)
            }
        }
    }
    
    // MARK: - 监听订阅状态变化
    
    /// 监听订阅状态变化（通过定期检查订阅状态）
    private func listenForSubscriptionStatusChanges() -> Cancellable {
        return createDetachedTask { [weak self] in
            // 定期检查订阅状态变化（每30秒检查一次）
            while true {
                do {
                    try await _Concurrency.Task.sleep(nanoseconds: 30_000_000_000) // 30秒
                    
                    // 更新订阅状态
                    await self?.updateSubscriptionStatuses()
                    
                    // 检查状态变化并处理
                    await self?.checkAndHandleSubscriptionStatusChanges()
                } catch {
                    // Task被取消
                    break
                }
            }
        }
    }
    
    /// 检查并处理订阅状态变化
    private func checkAndHandleSubscriptionStatusChanges() async {
        for product in products {
            guard ProductID(rawValue: product.id) != nil,
                  let subscription = product.subscription else {
                continue
            }
            
            do {
                let statuses = try await subscription.status
                guard let status = statuses.first else { continue }
                
                // 获取之前的状态
                let previousState = subscriptionStatuses[product.id]?.status.state
                
                // 如果状态发生变化，记录并处理
                if previousState != status.state {
                    Logger.info("订阅状态变化: \(product.id), 从 \(String(describing: previousState)) 到 \(status.state)", category: .iap)
                    
                    switch status.state {
                    case .subscribed:
                        Logger.info("订阅激活: \(product.id)", category: .iap)
                    case .expired:
                        Logger.warning("订阅已过期: \(product.id)", category: .iap)
                        await updatePurchasedProducts()
                    case .revoked:
                        Logger.warning("订阅已撤销: \(product.id)", category: .iap)
                        await updatePurchasedProducts()
                    case .inGracePeriod:
                        Logger.info("订阅宽限期: \(product.id)", category: .iap)
                    case .inBillingRetryPeriod:
                        Logger.info("订阅计费重试期: \(product.id)", category: .iap)
                    default:
                        Logger.warning("未知订阅状态: \(product.id), 状态: \(String(describing: status.state))", category: .iap)
                    }
                }
            } catch {
                Logger.error("检查订阅状态失败 \(product.id): \(error.localizedDescription)", category: .iap)
            }
        }
    }
    
    // MARK: - 更新已购买产品
    
    /// 更新已购买的产品列表（检查是否过期）
    func updatePurchasedProducts() async {
        var purchased: Set<String> = []
        let now = Date()
        
        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                
                // 检查产品ID是否匹配VIP产品
                if ProductID(rawValue: transaction.productID) != nil {
                    // 检查是否过期
                    if let expirationDate = transaction.expirationDate {
                        if expirationDate > now {
                            purchased.insert(transaction.productID)
                        } else {
                            Logger.warning("订阅已过期: \(transaction.productID), 过期时间: \(expirationDate)", category: .iap)
                        }
                    } else {
                        // 没有过期时间，认为是有效的
                        purchased.insert(transaction.productID)
                    }
                }
            } catch {
                Logger.error("验证交易失败: \(error.localizedDescription)", category: .iap)
            }
        }
        
        purchasedProducts = purchased
    }
    
    // MARK: - 订阅状态管理
    
    /// 更新订阅状态信息（使用SubscriptionStatus API）
    func updateSubscriptionStatuses() async {
        var statuses: [String: SubscriptionStatusInfo] = [:]
        
        for product in products {
            guard let subscription = product.subscription,
                  ProductID(rawValue: product.id) != nil else {
                continue
            }
            
            do {
                // 获取订阅状态
                let subscriptionStatuses = try await subscription.status
                
                for status in subscriptionStatuses {
                    // 获取续费信息（需要验证）
                    var verifiedRenewalInfo: Product.SubscriptionInfo.RenewalInfo?
                    var willAutoRenew = false
                    
                    do {
                        verifiedRenewalInfo = try checkVerified(status.renewalInfo)
                        // RenewalInfo 有 willAutoRenew 属性
                        willAutoRenew = verifiedRenewalInfo?.willAutoRenew ?? false
                    } catch {
                        Logger.warning("验证续费信息失败: \(error.localizedDescription)", category: .iap)
                        // 如果验证失败，默认认为不会自动续费
                        willAutoRenew = false
                    }
                    
                    // 获取最新的交易（通过 Transaction.currentEntitlements）
                    var latestTransaction: Transaction?
                    for await result in Transaction.currentEntitlements {
                        if let transaction = try? checkVerified(result),
                           transaction.productID == product.id {
                            latestTransaction = transaction
                            break
                        }
                    }
                    
                    // 计算过期时间
                    var expirationDate: Date?
                    if let transaction = latestTransaction {
                        expirationDate = transaction.expirationDate
                    }
                    
                    // 判断是否激活
                    let isActive = status.state == .subscribed || 
                                  status.state == .inGracePeriod ||
                                  status.state == .inBillingRetryPeriod
                    
                    let statusInfo = SubscriptionStatusInfo(
                        productID: product.id,
                        status: status,
                        renewalInfo: verifiedRenewalInfo,
                        transaction: latestTransaction,
                        expirationDate: expirationDate,
                        isActive: isActive,
                        willAutoRenew: willAutoRenew
                    )
                    
                    statuses[product.id] = statusInfo
                    
                    Logger.info("订阅状态更新: \(product.id), 状态: \(status.state), 自动续费: \(willAutoRenew)", category: .iap)
                }
            } catch {
                Logger.error("获取订阅状态失败 \(product.id): \(error.localizedDescription)", category: .iap)
            }
        }
        
        subscriptionStatuses = statuses
    }
    
    /// 获取当前激活的订阅
    func getCurrentActiveSubscription() async -> SubscriptionStatusInfo? {
        await updateSubscriptionStatuses()
        
        // 返回第一个激活的订阅
        for (_, statusInfo) in subscriptionStatuses {
            if statusInfo.isActive {
                return statusInfo
            }
        }
        
        return nil
    }
    
    /// 获取续费信息
    func getRenewalInfo(for productID: String) async -> Product.SubscriptionInfo.RenewalInfo? {
        await updateSubscriptionStatuses()
        return subscriptionStatuses[productID]?.renewalInfo
    }
    
    /// 验证续费信息
    private func checkRenewalInfo(_ renewalInfo: VerificationResult<Product.SubscriptionInfo.RenewalInfo>) throws -> Product.SubscriptionInfo.RenewalInfo {
        switch renewalInfo {
        case .unverified:
            throw IAPError.failedVerification
        case .verified(let safe):
            return safe
        }
    }
    
    // MARK: - 后端同步
    
    /// 验证收据并更新VIP状态
    private func updateVIPStatus(productID: String, transaction: Transaction, transactionJWS: String) async {
        do {
            // 调用后端API激活VIP
            try await APIService.shared.activateVIP(
                productID: productID,
                transactionID: String(transaction.id),
                transactionJWS: transactionJWS
            )
            
            Logger.info("VIP激活成功: \(productID), 交易ID: \(transaction.id)", category: .iap)
        } catch {
            Logger.error("激活VIP失败: \(error.localizedDescription)", category: .iap)
            // 注意：即使后端激活失败，交易已经完成，用户已经付费
            // 这里应该记录错误，并可能需要手动处理
            // 可以考虑实现重试机制或后台任务处理
        }
    }
    
    // MARK: - 恢复购买
    
    /// 恢复购买
    func restorePurchases() async throws {
        Logger.info("开始恢复购买", category: .iap)
        
        do {
            try await AppStore.sync()
            await updatePurchasedProducts()
            await updateSubscriptionStatuses()
            
            Logger.info("恢复购买完成", category: .iap)
        } catch {
            Logger.error("恢复购买失败: \(error.localizedDescription)", category: .iap)
            throw error
        }
    }
    
    // MARK: - 检查VIP状态
    
    /// 检查用户是否有有效的VIP订阅（改进版：检查过期时间）
    func hasActiveVIPSubscription() async -> Bool {
        await updatePurchasedProducts()
        await updateSubscriptionStatuses()
        
        // 检查是否有激活的订阅
        for (_, statusInfo) in subscriptionStatuses {
            if statusInfo.isActive {
                return true
            }
        }
        
        // 回退到检查purchasedProducts
        return !purchasedProducts.isEmpty
    }
    
    /// 同步检查VIP状态（不使用async，用于快速检查）
    func hasActiveVIPSubscriptionSync() -> Bool {
        // 快速检查purchasedProducts
        if !purchasedProducts.isEmpty {
            return true
        }
        
        // 检查订阅状态
        for (_, statusInfo) in subscriptionStatuses {
            if statusInfo.isActive {
                return true
            }
        }
        
        return false
    }
    
    /// 获取订阅到期时间
    func getSubscriptionExpirationDate(for productID: String) async -> Date? {
        await updateSubscriptionStatuses()
        return subscriptionStatuses[productID]?.expirationDate
    }
    
    /// 检查订阅是否会自动续费
    func willAutoRenew(for productID: String) async -> Bool {
        await updateSubscriptionStatuses()
        return subscriptionStatuses[productID]?.willAutoRenew ?? false
    }
}
