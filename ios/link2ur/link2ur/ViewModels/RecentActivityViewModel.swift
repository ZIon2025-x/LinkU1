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
    @Published var activities: [RecentActivity] = []  // 当前显示的动态
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var hasMore = true
    @Published var errorMessage: String?
    
    private let apiService: APIService
    private var cancellables = Set<AnyCancellable>()
    private var visibleCategoryIds: Set<Int> = []
    
    // 缓存所有加载的动态
    private var allLoadedActivities: [RecentActivity] = []
    private var displayedCount = 0
    private let batchSize = 5  // 每次显示5条
    
    // 分页状态
    private var forumPage = 1
    private var fleaMarketPage = 1
    private var leaderboardPage = 1
    private let fetchSize = 20  // 每次从后端获取的数量
    
    // 各数据源是否还有更多
    private var hasMoreFromServer = true
    
    init(apiService: APIService? = nil) {
        self.apiService = apiService ?? APIService.shared
    }
    
    /// 首次加载数据
    func loadRecentActivities() {
        guard !isLoading else { return }
        
        isLoading = true
        errorMessage = nil
        
        // 重置状态
        allLoadedActivities = []
        activities = []
        displayedCount = 0
        forumPage = 1
        fleaMarketPage = 1
        leaderboardPage = 1
        hasMoreFromServer = true
        hasMore = true
        
        fetchFromServer { [weak self] in
            self?.isLoading = false
            self?.showMoreItems()
        }
    }
    
    /// 加载更多（显示更多已缓存的数据，或从服务器获取更多）
    func loadMoreActivities() {
        guard !isLoading && !isLoadingMore && hasMore else { return }
        
        // 如果缓存中还有未显示的数据，直接显示
        if displayedCount < allLoadedActivities.count {
            showMoreItems()
            return
        }
        
        // 如果服务器还有更多数据，获取更多
        if hasMoreFromServer {
            isLoadingMore = true
            fetchFromServer { [weak self] in
                self?.isLoadingMore = false
                self?.showMoreItems()
            }
        } else {
            hasMore = false
        }
    }
    
    /// 从服务器获取数据
    private func fetchFromServer(completion: @escaping () -> Void) {
        let visibleCategories = apiService.getForumCategories(includeAll: false, viewAs: nil, includeLatestPost: false)
        let forumPosts = apiService.getForumPosts(page: forumPage, pageSize: fetchSize, sort: "latest")
        let fleaMarketItems = apiService.getFleaMarketItems(page: fleaMarketPage, pageSize: fetchSize)
        let leaderboards = apiService.getCustomLeaderboards(page: leaderboardPage, limit: fetchSize)
        
        Publishers.Zip(
            visibleCategories,
            Publishers.Zip3(forumPosts, fleaMarketItems, leaderboards)
        )
        .receive(on: DispatchQueue.main)
        .sink(receiveCompletion: { [weak self] result in
            if case .failure(let error) = result {
                ErrorHandler.shared.handle(error, context: "加载最近活动")
                self?.errorMessage = error.userFriendlyMessage
                completion()
            }
        }, receiveValue: { [weak self] (categoriesResponse, otherData) in
            guard let self = self else { 
                completion()
                return 
            }
            
            let (postsResponse, itemsResponse, leaderboardsResponse) = otherData
            
            // 检查是否还有更多数据
            let hasMoreForum = postsResponse.posts.count >= self.fetchSize
            let hasMoreFlea = itemsResponse.items.count >= self.fetchSize
            let hasMoreLeaderboard = leaderboardsResponse.items.count >= self.fetchSize
            self.hasMoreFromServer = hasMoreForum || hasMoreFlea || hasMoreLeaderboard
            
            // 增加页码
            self.forumPage += 1
            self.fleaMarketPage += 1
            self.leaderboardPage += 1
            
            // 保存可见板块
            self.visibleCategoryIds = Set(categoriesResponse.categories.map { $0.id })
            let hasVisibleCategories = !self.visibleCategoryIds.isEmpty
            
            var newActivities: [RecentActivity] = []
            
            // 处理论坛帖子
            for post in postsResponse.posts {
                if hasVisibleCategories {
                    if let category = post.category, self.visibleCategoryIds.contains(category.id) {
                        newActivities.append(RecentActivity(forumPost: post))
                    }
                } else {
                    newActivities.append(RecentActivity(forumPost: post))
                }
            }
            
            // 处理跳蚤市场
            for item in itemsResponse.items where item.status == "active" {
                newActivities.append(RecentActivity(fleaMarketItem: item))
            }
            
            // 处理排行榜
            for leaderboard in leaderboardsResponse.items where leaderboard.status == "active" {
                newActivities.append(RecentActivity(leaderboard: leaderboard))
            }
            
            // 去重并添加到缓存
            let existingIds = Set(self.allLoadedActivities.map { $0.id })
            let uniqueNew = newActivities.filter { !existingIds.contains($0.id) }
            self.allLoadedActivities.append(contentsOf: uniqueNew)
            
            // 按时间排序
            self.allLoadedActivities.sort { $0.createdAt > $1.createdAt }
            
            // 数据处理完成后调用 completion
            completion()
        })
        .store(in: &cancellables)
    }
    
    /// 显示更多条目
    private func showMoreItems() {
        let startIndex = displayedCount
        let endIndex = min(displayedCount + batchSize, allLoadedActivities.count)
        
        if startIndex < endIndex {
            let newItems = Array(allLoadedActivities[startIndex..<endIndex])
            activities.append(contentsOf: newItems)
            displayedCount = endIndex
        }
        
        // 更新 hasMore 状态
        hasMore = displayedCount < allLoadedActivities.count || hasMoreFromServer
    }
    
    /// 刷新数据
    func refresh() {
        loadRecentActivities()
    }
}
