import Foundation
import SwiftUI
import Combine

// 动态类型枚举
enum ActivityType: String {
    case forumPost = "forum_post"
    case fleaMarketItem = "flea_market_item"
    case leaderboardCreated = "leaderboard_created"  // 发起排行榜
}

// 统一动态数据模型
struct RecentActivity: Identifiable {
    let id: String
    let type: ActivityType
    let title: String
    let description: String?
    let author: User?
    let createdAt: String
    let icon: String
    let iconColor: [Color]
    let actionText: String
    
    // 论坛帖子
    init(forumPost: ForumPost) {
        self.id = "forum_\(forumPost.id)"
        self.type = .forumPost
        self.title = forumPost.title
        self.description = forumPost.contentPreview
        self.author = forumPost.author
        self.createdAt = forumPost.createdAt
        self.icon = "bubble.left.and.bubble.right.fill"
        self.iconColor = AppColors.gradientPrimary
        self.actionText = "发布了新帖子"
    }
    
    // 跳蚤市场商品
    init(fleaMarketItem: FleaMarketItem) {
        self.id = "flea_\(fleaMarketItem.id)"
        self.type = .fleaMarketItem
        self.title = fleaMarketItem.title
        self.description = fleaMarketItem.description
        self.author = fleaMarketItem.seller
        self.createdAt = fleaMarketItem.createdAt
        self.icon = "tag.fill"
        self.iconColor = AppColors.gradientWarning
        self.actionText = "发布了新商品"
    }
    
    // 发起排行榜
    init(leaderboard: CustomLeaderboard) {
        self.id = "leaderboard_\(leaderboard.id)"
        self.type = .leaderboardCreated
        self.title = leaderboard.name
        self.description = leaderboard.description
        self.author = leaderboard.applicant
        self.createdAt = leaderboard.createdAt
        self.icon = "trophy.fill"
        self.iconColor = AppColors.gradientSuccess
        self.actionText = "发起了排行榜"
    }
}

class RecentActivityViewModel: ObservableObject {
    @Published var activities: [RecentActivity] = []
    @Published var isLoading = false
    @Published var isLoadingMore = false  // 是否正在加载更多
    @Published var hasMore = true  // 是否还有更多数据
    @Published var errorMessage: String?
    
    // 使用依赖注入获取服务
    private let apiService: APIService
    private var cancellables = Set<AnyCancellable>()
    private var visibleCategoryIds: Set<Int> = [] // 用户可见的板块ID集合
    
    // 分页状态 - 每种数据源独立分页
    private var forumPage = 1
    private var fleaMarketPage = 1
    private var leaderboardPage = 1
    private let pageSize = 10  // 每页获取数量
    private var displayedCount = 0  // 已显示的数量
    private let batchSize = 5  // 每次显示的数量
    
    // 各数据源是否还有更多
    private var hasMoreForum = true
    private var hasMoreFleaMarket = true
    private var hasMoreLeaderboard = true
    
    init(apiService: APIService? = nil) {
        self.apiService = apiService ?? APIService.shared
    }
    
    func loadRecentActivities(loadMore: Bool = false) {
        // 如果正在加载，不执行
        if isLoading || isLoadingMore {
            return
        }
        
        // 如果没有更多数据，不执行加载
        if loadMore && !hasMore {
            return
        }
        
        if loadMore {
            isLoadingMore = true
        } else {
            isLoading = true
            // 重置分页状态
            forumPage = 1
            fleaMarketPage = 1
            leaderboardPage = 1
            displayedCount = 0
            hasMoreForum = true
            hasMoreFleaMarket = true
            hasMoreLeaderboard = true
            activities = []
            hasMore = true
        }
        errorMessage = nil
        
        // 首先获取用户可见的板块列表（用于过滤帖子）
        let visibleCategories = apiService.getForumCategories(includeAll: false, viewAs: nil, includeLatestPost: false)
        
        // 并行获取三种类型的数据
        let forumPosts = apiService.getForumPosts(page: forumPage, pageSize: pageSize, sort: "latest")
        let fleaMarketItems = apiService.getFleaMarketItems(page: fleaMarketPage, pageSize: pageSize)
        let leaderboards = apiService.getCustomLeaderboards(page: leaderboardPage, limit: pageSize)
        
        // 使用嵌套 Zip 组合四个发布者
        Publishers.Zip(
            visibleCategories,
            Publishers.Zip3(forumPosts, fleaMarketItems, leaderboards)
        )
            .flatMap { [weak self] (categoriesResponse, otherData) -> AnyPublisher<[RecentActivity], APIError> in
                guard let self = self else {
                    return Just([]).setFailureType(to: APIError.self).eraseToAnyPublisher()
                }
                
                let (postsResponse, itemsResponse, leaderboardsResponse) = otherData
                
                // 更新各数据源的分页状态
                self.hasMoreForum = postsResponse.posts.count >= self.pageSize
                self.hasMoreFleaMarket = itemsResponse.items.count >= self.pageSize
                self.hasMoreLeaderboard = leaderboardsResponse.items.count >= self.pageSize
                
                // 保存用户可见的板块ID集合
                self.visibleCategoryIds = Set(categoriesResponse.categories.map { $0.id })
                
                var allActivities: [RecentActivity] = []
                
                // 添加论坛帖子（只添加用户有权限看到的）
                let hasVisibleCategories = !self.visibleCategoryIds.isEmpty
                
                for post in postsResponse.posts {
                    var shouldInclude = false
                    
                    if hasVisibleCategories {
                        if let category = post.category {
                            if self.visibleCategoryIds.contains(category.id) {
                                shouldInclude = true
                            }
                        } else {
                            continue
                        }
                    } else {
                        shouldInclude = true
                    }
                    
                    if shouldInclude {
                        allActivities.append(RecentActivity(forumPost: post))
                    }
                }
                
                // 添加跳蚤市场商品（只显示活跃状态的商品）
                for item in itemsResponse.items {
                    if item.status == "active" {
                        allActivities.append(RecentActivity(fleaMarketItem: item))
                    }
                }
                
                // 添加发起排行榜的活动（只显示已审核通过的排行榜）
                for leaderboard in leaderboardsResponse.items {
                    if leaderboard.status == "active" {
                        allActivities.append(RecentActivity(leaderboard: leaderboard))
                    }
                }
                
                // 按时间排序
                allActivities.sort { activity1, activity2 in
                    activity1.createdAt > activity2.createdAt
                }
                
                return Just(allActivities)
                    .setFailureType(to: APIError.self)
                    .eraseToAnyPublisher()
            }
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] result in
                guard let self = self else { return }
                self.isLoading = false
                self.isLoadingMore = false
                if case .failure(let error) = result {
                    ErrorHandler.shared.handle(error, context: "加载最近活动")
                    self.errorMessage = error.userFriendlyMessage
                }
            }, receiveValue: { [weak self] newActivities in
                guard let self = self else { return }
                
                if loadMore {
                    // 加载更多：追加数据，去重
                    let existingIds = Set(self.activities.map { $0.id })
                    let uniqueNewActivities = newActivities.filter { !existingIds.contains($0.id) }
                    self.activities.append(contentsOf: uniqueNewActivities)
                    
                    // 增加各数据源的页码
                    self.forumPage += 1
                    self.fleaMarketPage += 1
                    self.leaderboardPage += 1
                } else {
                    // 首次加载：替换数据，去重
                    var seenIds = Set<String>()
                    self.activities = newActivities.filter { activity in
                        if seenIds.contains(activity.id) {
                            return false
                        }
                        seenIds.insert(activity.id)
                        return true
                    }
                }
                
                // 检查是否还有更多数据
                self.hasMore = self.hasMoreForum || self.hasMoreFleaMarket || self.hasMoreLeaderboard
            })
            .store(in: &cancellables)
    }
    
    /// 加载更多数据
    func loadMoreActivities() {
        loadRecentActivities(loadMore: true)
    }
    
    /// 刷新数据（强制重新加载）
    func refresh() {
        loadRecentActivities(loadMore: false)
    }
}
