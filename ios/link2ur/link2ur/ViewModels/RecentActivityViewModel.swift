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
    private var currentPage = 1  // 当前页码
    private let pageSize = 5  // 每页数量（每次加载5条）
    private let initialLimit = 5  // 初始加载数量
    
    init(apiService: APIService? = nil) {
        self.apiService = apiService ?? APIService.shared
    }
    
    func loadRecentActivities(limit: Int? = nil, loadMore: Bool = false) {
        // 如果正在加载或没有更多数据，不执行加载
        if isLoading || isLoadingMore || (!loadMore && !activities.isEmpty) {
            return
        }
        
        // 如果没有更多数据，不执行加载
        if loadMore && !hasMore {
            return
        }
        
        let loadLimit = limit ?? (loadMore ? pageSize : initialLimit)
        
        if loadMore {
            isLoadingMore = true
            currentPage += 1
        } else {
            isLoading = true
            currentPage = 1
            activities = []
            hasMore = true
        }
        errorMessage = nil
        
        // 首先获取用户可见的板块列表（用于过滤帖子）
        let visibleCategories = apiService.getForumCategories(includeAll: false, viewAs: nil, includeLatestPost: false)
        
        // 并行获取三种类型的数据（获取更多数据，因为可能被过滤）
        let forumPosts = apiService.getForumPosts(page: currentPage, pageSize: loadLimit * 3, sort: "latest") // 获取更多帖子，因为可能被过滤
        let fleaMarketItems = apiService.getFleaMarketItems(page: currentPage, pageSize: loadLimit)
        let leaderboards = apiService.getCustomLeaderboards(page: currentPage, limit: loadLimit * 2) // 获取更多排行榜，只显示已审核通过的
        
        // 使用嵌套 Zip 组合四个发布者
        Publishers.Zip(
            visibleCategories,
            Publishers.Zip3(forumPosts, fleaMarketItems, leaderboards)
        )
            .flatMap { [weak self] (categoriesResponse, otherData) -> AnyPublisher<([RecentActivity], Bool), APIError> in
                guard let self = self else {
                    return Just(([], false)).setFailureType(to: APIError.self).eraseToAnyPublisher()
                }
                
                let (postsResponse, itemsResponse, leaderboardsResponse) = otherData
                
                // 保存用户可见的板块ID集合
                self.visibleCategoryIds = Set(categoriesResponse.categories.map { $0.id })
                
                var allActivities: [RecentActivity] = []
                
                // 添加论坛帖子（只添加用户有权限看到的）
                // 如果可见板块列表为空，说明可能是未登录用户，后端应该已经做了权限过滤，允许显示所有帖子
                let hasVisibleCategories = !self.visibleCategoryIds.isEmpty
                
                for post in postsResponse.posts {
                    // 检查帖子所属板块是否在可见板块列表中
                    var shouldInclude = false
                    
                    if hasVisibleCategories {
                        // 如果有可见板块列表，需要检查权限
                        if let category = post.category {
                            // 如果帖子有板块信息，检查是否在可见板块列表中
                            if self.visibleCategoryIds.contains(category.id) {
                                shouldInclude = true
                            }
                        } else {
                            // 如果帖子没有板块信息，可能是旧数据
                            // 为了安全，跳过（无法验证权限）
                            continue
                        }
                    } else {
                        // 如果没有可见板块列表（未登录用户），后端应该已经做了权限过滤
                        // 允许显示所有帖子
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
                
                // 添加发起排行榜的活动（只显示已审核通过的排行榜，status="active"）
                for leaderboard in leaderboardsResponse.items {
                    // 只显示已审核通过的排行榜
                    if leaderboard.status == "active" {
                        allActivities.append(RecentActivity(leaderboard: leaderboard))
                    }
                }
                
                // 按时间排序
                allActivities.sort { activity1, activity2 in
                    activity1.createdAt > activity2.createdAt
                }
                
                // 限制返回数量
                let limitedActivities = Array(allActivities.prefix(loadLimit))
                
                // 检查是否还有更多数据（如果合并后的数据量达到限制，可能还有更多）
                let hasMoreData = allActivities.count >= loadLimit
                
                return Just((limitedActivities, hasMoreData))
                    .setFailureType(to: APIError.self)
                    .eraseToAnyPublisher()
            }
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] result in
                guard let self = self else { return }
                self.isLoading = false
                self.isLoadingMore = false
                if case .failure(let error) = result {
                    // 使用 ErrorHandler 统一处理错误
                    ErrorHandler.shared.handle(error, context: "加载最近活动")
                    self.errorMessage = error.userFriendlyMessage
                    // 加载失败时，回退页码
                    if loadMore {
                        self.currentPage -= 1
                    }
                }
            }, receiveValue: { [weak self] (newActivities, hasMoreData) in
                guard let self = self else { return }
                if loadMore {
                    // 追加数据，但要去重（基于 ID）
                    let existingIds = Set(self.activities.map { $0.id })
                    let uniqueNewActivities = newActivities.filter { !existingIds.contains($0.id) }
                    self.activities.append(contentsOf: uniqueNewActivities)
                } else {
                    // 替换数据，也要去重（防止后端返回重复数据）
                    var seenIds = Set<String>()
                    self.activities = newActivities.filter { activity in
                        if seenIds.contains(activity.id) {
                            return false
                        }
                        seenIds.insert(activity.id)
                        return true
                    }
                }
                self.hasMore = hasMoreData
            })
            .store(in: &cancellables)
    }
    
    /// 加载更多数据
    func loadMoreActivities() {
        loadRecentActivities(loadMore: true)
    }
}
