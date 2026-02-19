import Foundation
import Combine
import CoreLocation

class LeaderboardViewModel: ObservableObject {
    private let performanceMonitor = PerformanceMonitor.shared
    @Published var leaderboards: [CustomLeaderboard] = []
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var hasMore = true
    @Published var errorMessage: String?
    
    private let pageSize = 20
    private var currentOffset = 0
    
    // 使用依赖注入获取服务
    private let apiService: APIService
    private let locationService: LocationService
    private var cancellables = Set<AnyCancellable>()
    private var isRequesting = false // 防止重复请求
    
    init(apiService: APIService? = nil, locationService: LocationService? = nil) {
        self.apiService = apiService ?? APIService.shared
        self.locationService = locationService ?? LocationService.shared
    }
    
    deinit {
        cancellables.removeAll()
    }
    
    private var rawLeaderboards: [CustomLeaderboard] = [] // 保存原始数据，用于重新排序
    private var currentSort: String = "latest" // 保存当前排序方式
    
    func loadLeaderboards(location: String? = nil, sort: String = "latest", forceRefresh: Bool = false) {
        currentOffset = 0
        hasMore = true
        performFetch(location: location, sort: sort, forceRefresh: forceRefresh, isLoadMore: false)
    }
    
    func loadMore(location: String? = nil, sort: String = "latest") {
        guard hasMore, !isLoadingMore, !isLoading else { return }
        performFetch(location: location, sort: sort, forceRefresh: false, isLoadMore: true)
    }
    
    private func performFetch(location: String? = nil, sort: String = "latest", forceRefresh: Bool = false, isLoadMore: Bool = false) {
        let startTime = Date()
        
        guard !isRequesting else {
            Logger.warning("排行榜请求已在进行中，跳过重复请求", category: .api)
            return
        }
        
        isRequesting = true
        if isLoadMore {
            isLoadingMore = true
        } else {
            let hasExistingData = !leaderboards.isEmpty
            if !hasExistingData { isLoading = true }
        }
        if !isLoadMore { errorMessage = nil }
        
        if !isLoadMore && location == nil && sort == "latest" && !forceRefresh {
            if let cachedLeaderboards = CacheManager.shared.loadLeaderboards(location: nil, sort: "latest") {
                self.leaderboards = cachedLeaderboards
                self.rawLeaderboards = cachedLeaderboards
                Logger.success("从缓存加载了 \(self.leaderboards.count) 个排行榜", category: .cache)
                isLoading = false
            }
        }
        
        var queryParams: [String] = [
            "status=active",
            "sort=\(sort.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? sort)",
            "limit=\(pageSize)",
            "offset=\(isLoadMore ? currentOffset : 0)"
        ]
        if let location = location, !location.isEmpty {
            let encodedLocation = location.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? location
            queryParams.append("location=\(encodedLocation)")
        }
        
        let endpoint = "/api/custom-leaderboards?\(queryParams.joined(separator: "&"))"
        
        // 后端返回格式：{"items": [...]}
        apiService.request(CustomLeaderboardListResponse.self, endpoint, method: "GET")
            .sink(receiveCompletion: { [weak self] result in
                let duration = Date().timeIntervalSince(startTime)
                self?.isLoading = false
                self?.isLoadingMore = false
                self?.isRequesting = false
                if case .failure(let error) = result {
                    // 使用 ErrorHandler 统一处理错误
                    ErrorHandler.shared.handle(error, context: "加载排行榜")
                    // 记录性能指标
                    self?.performanceMonitor.recordNetworkRequest(
                        endpoint: endpoint,
                        method: "GET",
                        duration: duration,
                        error: error
                    )
                    self?.errorMessage = error.userFriendlyMessage
                    Logger.error("排行榜加载失败: \(error)", category: .api)
                    Logger.debug("请求URL: \(endpoint)", category: .api)
                } else {
                    // 记录成功请求的性能指标
                    self?.performanceMonitor.recordNetworkRequest(
                        endpoint: endpoint,
                        method: "GET",
                        duration: duration,
                        statusCode: 200
                    )
                }
            }, receiveValue: { [weak self] response in
                guard let self = self else { return }
                
                let fetchedItems = response.items
                self.hasMore = response.hasMore ?? (fetchedItems.count >= self.pageSize)
                if isLoadMore {
                    self.currentOffset += fetchedItems.count
                }
                
                var items: [CustomLeaderboard]
                if isLoadMore {
                    items = self.rawLeaderboards + fetchedItems
                } else {
                    items = fetchedItems
                }
                
                // 批量获取收藏状态（如果用户已登录）
                if !fetchedItems.isEmpty {
                    let leaderboardIds = items.map { $0.id }
                    self.apiService.getLeaderboardFavoritesBatch(leaderboardIds: leaderboardIds)
                        .sink(receiveCompletion: { result in
                            if case .failure(let error) = result {
                                Logger.warning("批量获取排行榜收藏状态失败: \(error.localizedDescription)", category: .api)
                            }
                        }, receiveValue: { favoriteResponse in
                            // 更新收藏状态
                            for i in 0..<items.count {
                                let leaderboardId = items[i].id
                                items[i].isFavorited = favoriteResponse.favorites[leaderboardId] ?? false
                            }
                            self.rawLeaderboards = items
                            self.currentSort = sort
                            
                            if sort == "latest" {
                                self.sortLeaderboardsByDistance(sort: sort, location: location)
                            } else {
                                DispatchQueue.main.async {
                                    self.leaderboards = items
                                    self.isLoading = false
                                    self.isLoadingMore = false
                                }
                            }
                            
                            self.isRequesting = false
                            Logger.success("排行榜加载成功，共\(self.leaderboards.count)条（已更新收藏状态）", category: .api)
                            
                            // 保存到缓存（仅在没有筛选条件时）
                            if location == nil && sort == "latest" {
                                CacheManager.shared.saveLeaderboards(self.leaderboards, location: nil, sort: "latest")
                            }
                        })
                        .store(in: &self.cancellables)
                } else {
                    // items为空的情况
                    self.rawLeaderboards = items
                    self.currentSort = sort
                    
                    // 只在默认状态（latest）时应用距离+浏览量排序
                    if sort == "latest" {
                        self.sortLeaderboardsByDistance(sort: sort, location: location)
                            } else {
                                DispatchQueue.main.async {
                                    self.leaderboards = items
                                    self.isLoading = false
                                    self.isLoadingMore = false
                                }
                            }
                    
                    self.isRequesting = false
                    Logger.success("排行榜加载成功，共\(self.leaderboards.count)条", category: .api)
                    
                    // 保存到缓存（仅在没有筛选条件时）
                    if location == nil && sort == "latest" {
                        CacheManager.shared.saveLeaderboards(self.leaderboards, location: nil, sort: "latest")
                    }
                    
                    // 如果是默认状态（latest），监听位置更新以重新排序
                    if sort == "latest" {
                        self.locationService.$currentLocation
                            .dropFirst() // 跳过初始值
                            .sink { [weak self] _ in
                                if self?.currentSort == "latest" {
                                    self?.sortLeaderboardsByDistance(sort: "latest", location: location)
                                }
                            }
                            .store(in: &self.cancellables)
                    }
                }
            })
            .store(in: &cancellables)
    }
    
    /// 按距离排序排行榜（距离相同时按浏览量排序）
    private func sortLeaderboardsByDistance(sort: String, location: String?) {
        guard !rawLeaderboards.isEmpty else {
            DispatchQueue.main.async {
                self.isLoading = false
                self.isLoadingMore = false
            }
            return
        }
        
        var leaderboards = rawLeaderboards
        
        // 始终尝试按距离排序（如果用户位置可用）
        if let userLocation = locationService.currentLocation {
            let userCoordinate = CLLocationCoordinate2D(
                latitude: userLocation.latitude,
                longitude: userLocation.longitude
            )
            
            Logger.debug("开始按距离排序排行榜，用户位置: \(userLocation.latitude), \(userLocation.longitude)", category: .general)
            
            // 计算每个排行榜的距离
            leaderboards = leaderboards.map { leaderboard in
                var leaderboard = leaderboard
                let distance = DistanceCalculator.distanceToCity(
                    from: userCoordinate,
                    to: leaderboard.location
                )
                leaderboard.distance = distance
                return leaderboard
            }
            
            // 排序：先按距离（由近到远），距离相同时按浏览量（由高到低）
            leaderboards.sort { board1, board2 in
                let distance1 = board1.distance ?? Double.infinity
                let distance2 = board2.distance ?? Double.infinity
                
                // 如果距离相同（差异小于 0.01km），按浏览量排序（由高到低）
                if abs(distance1 - distance2) < 0.01 {
                    return board1.viewCount > board2.viewCount
                }
                
                // 否则按距离排序（由近到远）
                return distance1 < distance2
            }
            
            Logger.success("已按距离和浏览量排序排行榜（共\(leaderboards.count)条）", category: .general)
        } else {
            // 如果用户位置不可用，只按浏览量排序（由高到低）
            Logger.warning("用户位置不可用，按浏览量排序", category: .general)
            leaderboards.sort { board1, board2 in
                return board1.viewCount > board2.viewCount
            }
        }
        
        // 更新到主线程
        DispatchQueue.main.async { [weak self] in
            self?.leaderboards = leaderboards
            self?.isLoading = false
            self?.isLoadingMore = false
        }
    }
    
    /// 申请创建新排行榜
    func applyLeaderboard(name: String, location: String, description: String?, applicationReason: String?, coverImage: String?, completion: @escaping (Bool, String?) -> Void) {
        isLoading = true
        errorMessage = nil
        
        var body: [String: Any] = [
            "name": name,
            "location": location
        ]
        
        if let description = description {
            body["description"] = description
        }
        if let applicationReason = applicationReason {
            body["application_reason"] = applicationReason
        }
        if let coverImage = coverImage {
            body["cover_image"] = coverImage
        }
        
        apiService.request(CustomLeaderboard.self, "/api/custom-leaderboards/apply", method: "POST", body: body)
            .sink(receiveCompletion: { [weak self] result in
                self?.isLoading = false
                if case .failure(let error) = result {
                    ErrorHandler.shared.handle(error, context: "申请排行榜")
                    completion(false, error.userFriendlyMessage)
                }
            }, receiveValue: { leaderboard in
                completion(true, nil)
            })
            .store(in: &cancellables)
    }
    
}

class LeaderboardDetailViewModel: ObservableObject {
    @Published var leaderboard: CustomLeaderboard?
    @Published var items: [LeaderboardItem] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // 使用依赖注入获取服务
    private let apiService: APIService
    private let locationService = LocationService.shared
    private var cancellables = Set<AnyCancellable>()
    private var currentSort: String = "vote_score" // 保存当前排序方式
    
    init(apiService: APIService? = nil) {
        self.apiService = apiService ?? APIService.shared
    }
    
    deinit {
        cancellables.removeAll()
    }
    
    /// 收藏/取消收藏排行榜
    func toggleLeaderboardFavorite(leaderboardId: Int, completion: @escaping (Bool) -> Void) {
        apiService.toggleLeaderboardFavorite(leaderboardId: leaderboardId)
            .sink(receiveCompletion: { result in
                if case .failure(let error) = result {
                    ErrorHandler.shared.handle(error, context: "收藏操作")
                    completion(false)
                }
            }, receiveValue: { [weak self] response in
                // 更新本地状态
                DispatchQueue.main.async {
                    if var leaderboard = self?.leaderboard {
                        leaderboard.isFavorited = response.favorited
                        self?.leaderboard = leaderboard
                    }
                    completion(true)
                }
            })
            .store(in: &cancellables)
    }
    
    func loadLeaderboard(leaderboardId: Int, preserveLeaderboard: Bool = false) {
        // 防止重复请求
        guard !isLoading else {
            Logger.debug("排行榜详情请求已在进行中，跳过重复请求", category: .api)
            return
        }
        
        // 如果 preserveLeaderboard 为 true，在加载时保持现有 leaderboard，避免视图消失
        if !preserveLeaderboard {
            isLoading = true
        }
        apiService.request(CustomLeaderboard.self, "/api/custom-leaderboards/\(leaderboardId)", method: "GET")
            .sink(receiveCompletion: { [weak self] result in
                self?.isLoading = false
                if case .failure(let error) = result {
                    // 使用 ErrorHandler 统一处理错误
                    ErrorHandler.shared.handle(error, context: "加载排行榜详情")
                    self?.errorMessage = error.userFriendlyMessage
                }
            }, receiveValue: { [weak self] leaderboard in
                self?.leaderboard = leaderboard
            })
            .store(in: &cancellables)
    }
    
    func loadItems(leaderboardId: Int, sort: String = "vote_score") {
        isLoading = true
        currentSort = sort
        
        // 构建请求URL，确保sort参数正确编码
        let encodedSort = sort.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? sort
        let endpoint = "/api/custom-leaderboards/\(leaderboardId)/items?sort=\(encodedSort)&limit=50"
        
        apiService.request(LeaderboardItemListResponse.self, endpoint, method: "GET")
            .sink(receiveCompletion: { [weak self] result in
                self?.isLoading = false
                if case .failure(let error) = result {
                    // 使用 ErrorHandler 统一处理错误
                    ErrorHandler.shared.handle(error, context: "加载排行榜项目")
                    self?.errorMessage = error.userFriendlyMessage
                }
            }, receiveValue: { [weak self] response in
                guard let self = self else { return }
                
                // 只有在默认排序（vote_score）时才应用距离+浏览量排序
                // 其他排序方式直接使用后端返回的结果
                if sort == "vote_score" {
                    self.sortItemsByDistanceAndViewCount(items: response.items)
                } else {
                    // 直接使用后端返回的排序结果
                    DispatchQueue.main.async { [weak self] in
                        self?.items = response.items
                    }
                }
            })
            .store(in: &cancellables)
    }
    
    /// 按距离和浏览量排序项目（用于"综合"排序）
    /// 排序优先级：1. 得分（voteScore） 2. 距离 3. 浏览量
    private func sortItemsByDistanceAndViewCount(items: [LeaderboardItem]) {
        var sortedItems = items
        
        // 如果用户位置可用，计算距离
        if let userLocation = locationService.currentLocation {
            let userCoordinate = CLLocationCoordinate2D(
                latitude: userLocation.latitude,
                longitude: userLocation.longitude
            )
            
            // 计算每个项目的距离
            sortedItems = sortedItems.map { item in
                var item = item
                // 从 address 中提取城市名（假设地址格式包含城市名）
                // 如果 address 为空，则距离为 nil
                if let address = item.address {
                    // 尝试从地址中提取城市名（简单实现，可能需要更复杂的解析）
                    let cityName = extractCityFromAddress(address)
                    item.distance = DistanceCalculator.distanceToCity(
                        from: userCoordinate,
                        to: cityName
                    )
                } else {
                    item.distance = nil
                }
                return item
            }
        }
        
        // 排序优先级：1. 得分（voteScore，由高到低） 2. 距离（由近到远） 3. 浏览量（由高到低）
        sortedItems.sort { item1, item2 in
            // 首先按得分排序（由高到低）
            let score1 = item1.voteScore
            let score2 = item2.voteScore
            
            // 如果得分差异较大（> 0.01），按得分排序
            if abs(score1 - score2) > 0.01 {
                return score1 > score2
            }
            
            // 得分相同或非常接近时，按距离排序
            let distance1 = item1.distance ?? Double.infinity
            let distance2 = item2.distance ?? Double.infinity
            
            // 如果距离相同（差异小于 0.01km），按浏览量排序（由高到低）
            if abs(distance1 - distance2) < 0.01 {
                let viewCount1 = item1.viewCount ?? 0
                let viewCount2 = item2.viewCount ?? 0
                return viewCount1 > viewCount2
            }
            
            // 否则按距离排序（由近到远）
            return distance1 < distance2
        }
        
        DispatchQueue.main.async { [weak self] in
            self?.items = sortedItems
        }
    }
    
    /// 从地址中提取城市名（简单实现）
    private func extractCityFromAddress(_ address: String) -> String? {
        // 简单的城市名提取逻辑
        // 假设地址格式可能是 "城市名, 国家" 或 "详细地址, 城市名"
        // 这里使用简单的逗号分割，取最后一个部分
        let components = address.components(separatedBy: ",")
        if let lastComponent = components.last {
            return lastComponent.trimmingCharacters(in: .whitespaces)
        }
        return address.trimmingCharacters(in: .whitespaces)
    }
    
    func voteItem(itemId: Int, voteType: String, completion: @escaping (Bool, Int, Int, Int) -> Void) {
        // 投票API使用query参数
        let endpoint = "/api/custom-leaderboards/items/\(itemId)/vote?vote_type=\(voteType)"
        apiService.request(VoteResponse.self, endpoint, method: "POST", body: [:])
            .sink(receiveCompletion: { _ in }, receiveValue: { response in
                completion(true, response.upvotes, response.downvotes, response.netVotes)
            })
            .store(in: &cancellables)
    }
    
    func submitItem(leaderboardId: Int, name: String, description: String?, address: String?, phone: String?, website: String?, images: [String]?, completion: @escaping (Bool) -> Void) {
        var body: [String: Any] = [
            "leaderboard_id": leaderboardId,
            "name": name
        ]
        
        if let description = description {
            body["description"] = description
        }
        if let address = address {
            body["address"] = address
        }
        if let phone = phone {
            body["phone"] = phone
        }
        if let website = website {
            body["website"] = website
        }
        if let images = images {
            body["images"] = images
        }
        
        apiService.request(LeaderboardItem.self, "/api/custom-leaderboards/items", method: "POST", body: body)
            .sink(receiveCompletion: { result in
                if case .failure = result {
                    completion(false)
                }
            }, receiveValue: { [weak self] item in
                // 重新加载列表
                self?.loadItems(leaderboardId: leaderboardId)
                completion(true)
            })
            .store(in: &cancellables)
    }
}

class LeaderboardItemDetailViewModel: ObservableObject {
    @Published var item: LeaderboardItem?
    @Published var comments: [LeaderboardItemComment] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // 使用依赖注入获取服务
    private let apiService: APIService
    private var cancellables = Set<AnyCancellable>()
    private var isLoadingComments = false // 防止重复加载留言
    
    init(apiService: APIService? = nil) {
        self.apiService = apiService ?? APIService.shared
    }
    
    deinit {
        cancellables.removeAll()
    }
    
    func loadItem(itemId: Int, preserveItem: Bool = false) {
        // 如果 preserveItem 为 true，在加载时保持现有 item，避免视图消失
        if !preserveItem {
            isLoading = true
        }
        Logger.debug("开始加载竞品详情，itemId: \(itemId)", category: .api)
        apiService.request(LeaderboardItem.self, "/api/custom-leaderboards/items/\(itemId)", method: "GET")
            .sink(receiveCompletion: { [weak self] result in
                self?.isLoading = false
                if case .failure(let error) = result {
                    // 使用 ErrorHandler 统一处理错误
                    ErrorHandler.shared.handle(error, context: "加载竞品详情")
                    Logger.error("加载竞品详情失败: \(error.localizedDescription)", category: .api)
                    self?.errorMessage = error.userFriendlyMessage
                }
            }, receiveValue: { [weak self] item in
                Logger.success("成功加载竞品详情: \(item.name)", category: .api)
                self?.item = item
                // 在item加载完成后也加载留言（确保留言能正确加载）
                self?.loadComments(itemId: itemId)
            })
            .store(in: &cancellables)
    }
    
    func loadComments(itemId: Int, limit: Int = 50, offset: Int = 0) {
        // 防止重复加载
        guard !isLoadingComments else {
            Logger.debug("留言正在加载中，跳过重复请求", category: .api)
            return
        }
        
        isLoadingComments = true
        Logger.debug("开始加载留言，itemId: \(itemId), limit: \(limit), offset: \(offset)", category: .api)
        // 使用 /votes 端点（参考前端实现）
        let endpoint = "/api/custom-leaderboards/items/\(itemId)/votes?limit=\(limit)&offset=\(offset)"
        apiService.request(LeaderboardItemCommentListResponse.self, endpoint, method: "GET")
            .sink(receiveCompletion: { [weak self] result in
                self?.isLoadingComments = false
                if case .failure(let error) = result {
                    // 使用 ErrorHandler 统一处理错误
                    ErrorHandler.shared.handle(error, context: "加载留言")
                    Logger.error("加载留言失败: \(error.localizedDescription)", category: .api)
                    Logger.error("请求端点: \(endpoint)", category: .api)
                    self?.errorMessage = error.userFriendlyMessage
                    // 即使失败也清空comments，避免显示旧数据
                    self?.comments = []
                }
            }, receiveValue: { [weak self] response in
                Logger.success("成功加载 \(response.comments.count) 条留言", category: .api)
                Logger.debug("留言详情: \(response.comments.map { "id:\($0.id), content:\($0.content ?? "nil")" }.joined(separator: ", "))", category: .api)
                self?.comments = response.comments
            })
            .store(in: &cancellables)
    }
    
    func likeComment(voteId: Int, completion: @escaping (Bool, Int, Bool) -> Void) {
        // 参考前端实现：POST /api/custom-leaderboards/votes/{voteId}/like
        let endpoint = "/api/custom-leaderboards/votes/\(voteId)/like"
        apiService.request(LikeCommentResponse.self, endpoint, method: "POST", body: [:])
            .sink(receiveCompletion: { result in
                if case .failure(let error) = result {
                    Logger.error("点赞留言失败: \(error.localizedDescription)", category: .api)
                    completion(false, 0, false)
                }
            }, receiveValue: { [weak self] response in
                Logger.success("点赞留言成功", category: .api)
                // 更新本地留言列表中的点赞状态
                if self?.comments.contains(where: { $0.id == voteId }) == true {
                    // 由于 LeaderboardItemComment 是 struct，需要重新创建
                    // 这里暂时只更新点赞数，实际应该重新加载列表
                    self?.loadComments(itemId: self?.item?.id ?? 0)
                }
                completion(true, response.likeCount, response.liked)
            })
            .store(in: &cancellables)
    }
    
    
    func voteItem(itemId: Int, voteType: String, comment: String? = nil, isAnonymous: Bool = false, completion: @escaping (Bool, Int, Int, Int) -> Void) {
        // 后端期望 comment 和 is_anonymous 作为 Query 参数，而不是 body
        var queryParams: [String] = ["vote_type=\(voteType)"]
        
        if let comment = comment, !comment.isEmpty {
            // URL 编码留言内容
            if let encodedComment = comment.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
                queryParams.append("comment=\(encodedComment)")
            }
        }
        
        if isAnonymous {
            queryParams.append("is_anonymous=true")
        }
        
        let endpoint = "/api/custom-leaderboards/items/\(itemId)/vote?\(queryParams.joined(separator: "&"))"
        
        // 后端返回的是更新后的 LeaderboardItem，而不是 VoteResponse
        apiService.request(LeaderboardItem.self, endpoint, method: "POST", body: nil)
            .sink(receiveCompletion: { result in
                if case .failure(let error) = result {
                    Logger.error("投票失败: \(error.localizedDescription)", category: .api)
                    completion(false, 0, 0, 0)
                }
            }, receiveValue: { [weak self] updatedItem in
                Logger.success("投票成功", category: .api)
                // 更新本地 item 数据
                self?.item = updatedItem
                completion(true, updatedItem.upvotes, updatedItem.downvotes, updatedItem.netVotes)
            })
            .store(in: &cancellables)
    }
}

