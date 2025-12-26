import Foundation
import Combine

@MainActor
class CouponPointsViewModel: ObservableObject {
    private let performanceMonitor = PerformanceMonitor.shared
    
    @Published var pointsAccount: PointsAccount?
    @Published var transactions: [PointsTransaction] = []
    @Published var availableCoupons: [Coupon] = []
    @Published var myCoupons: [UserCoupon] = []
    @Published var checkInStatus: CheckInStatus?
    @Published var checkInRewards: [CheckInRewardConfig] = []
    
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private var cancellables = Set<AnyCancellable>()
    // 使用依赖注入获取服务
    private let apiService: APIService
    
    init(apiService: APIService? = nil) {
        self.apiService = apiService ?? APIService.shared
    }
    
    deinit {
        cancellables.removeAll()
    }
    
    // MARK: - Points
    
    func loadPointsAccount() {
        let startTime = Date()
        let endpoint = "/api/users/points/account"
        
        isLoading = true
        errorMessage = nil
        
        apiService.getPointsAccount()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    let duration = Date().timeIntervalSince(startTime)
                    self?.isLoading = false
                    if case .failure(let error) = completion {
                        // 使用 ErrorHandler 统一处理错误
                        ErrorHandler.shared.handle(error, context: "加载积分账户")
                        // 记录性能指标
                        self?.performanceMonitor.recordNetworkRequest(
                            endpoint: endpoint,
                            method: "GET",
                            duration: duration,
                            error: error
                        )
                        self?.errorMessage = error.userFriendlyMessage
                    } else {
                        // 记录成功请求的性能指标
                        self?.performanceMonitor.recordNetworkRequest(
                            endpoint: endpoint,
                            method: "GET",
                            duration: duration,
                            statusCode: 200
                        )
                    }
                },
                receiveValue: { [weak self] account in
                    self?.pointsAccount = account
                    self?.isLoading = false
                }
            )
            .store(in: &cancellables)
    }
    
    func loadTransactions(page: Int = 1) {
        isLoading = true
        
        apiService.getPointsTransactions(page: page, limit: 20)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    if case .failure(let error) = completion {
                        // 使用 ErrorHandler 统一处理错误
                        ErrorHandler.shared.handle(error, context: "加载积分账户")
                        self?.errorMessage = error.userFriendlyMessage
                    }
                },
                receiveValue: { [weak self] response in
                    if page == 1 {
                        self?.transactions = response.data
                    } else {
                        self?.transactions.append(contentsOf: response.data)
                    }
                    self?.isLoading = false
                }
            )
            .store(in: &cancellables)
    }
    
    // MARK: - Coupons
    
    func loadAvailableCoupons() {
        isLoading = true
        
        apiService.getAvailableCoupons()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    if case .failure(let error) = completion {
                        // 使用 ErrorHandler 统一处理错误
                        ErrorHandler.shared.handle(error, context: "加载积分账户")
                        self?.errorMessage = error.userFriendlyMessage
                    }
                },
                receiveValue: { [weak self] response in
                    self?.availableCoupons = response.data
                    self?.isLoading = false
                }
            )
            .store(in: &cancellables)
    }
    
    func loadMyCoupons(status: String? = nil) {
        isLoading = true
        
        apiService.getMyCoupons(status: status, page: 1, limit: 50)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    if case .failure(let error) = completion {
                        // 使用 ErrorHandler 统一处理错误
                        ErrorHandler.shared.handle(error, context: "加载积分账户")
                        self?.errorMessage = error.userFriendlyMessage
                    }
                },
                receiveValue: { [weak self] response in
                    self?.myCoupons = response.data
                    self?.isLoading = false
                }
            )
            .store(in: &cancellables)
    }
    
    func claimCoupon(couponId: Int? = nil, promotionCode: String? = nil) -> AnyPublisher<Bool, Error> {
        return apiService.claimCoupon(couponId: couponId, promotionCode: promotionCode)
            .map { _ in true }
            .mapError { $0 as Error }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Check In
    
    func loadCheckInStatus() {
        isLoading = true
        
        apiService.getCheckInStatus()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    if case .failure(let error) = completion {
                        // 使用 ErrorHandler 统一处理错误
                        ErrorHandler.shared.handle(error, context: "加载积分账户")
                        self?.errorMessage = error.userFriendlyMessage
                    }
                },
                receiveValue: { [weak self] status in
                    self?.checkInStatus = status
                    self?.isLoading = false
                }
            )
            .store(in: &cancellables)
    }
    
    func performCheckIn() -> AnyPublisher<CheckInResponse, Error> {
        return apiService.checkIn()
            .mapError { $0 as Error }
            .eraseToAnyPublisher()
    }
    
    func loadCheckInRewards() {
        isLoading = true
        
        apiService.getCheckInRewards()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    if case .failure(let error) = completion {
                        // 使用 ErrorHandler 统一处理错误
                        ErrorHandler.shared.handle(error, context: "加载积分账户")
                        self?.errorMessage = error.userFriendlyMessage
                    }
                },
                receiveValue: { [weak self] response in
                    self?.checkInRewards = response.rewards
                    self?.isLoading = false
                }
            )
            .store(in: &cancellables)
    }
}

