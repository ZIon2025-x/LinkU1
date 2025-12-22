import Foundation
import Combine

/// 搜索结果类型
enum SearchResultType: String, CaseIterable {
    case all = "全部"
    case task = "任务"
    case expert = "达人"
    case fleaMarket = "二手"
    case forum = "论坛"
}

/// 综合搜索结果项
struct SearchResultItem: Identifiable {
    let id: String
    let type: SearchResultType
    let title: String
    let subtitle: String
    let imageUrl: String?
    let destinationId: Int?
    let destinationStringId: String?
}

/// 搜索历史记录
struct SearchHistory: Codable {
    var keywords: [String]
    
    static let maxCount = 10
    static let storageKey = "search_history"
    
    mutating func add(_ keyword: String) {
        // 移除重复
        keywords.removeAll { $0 == keyword }
        // 添加到开头
        keywords.insert(keyword, at: 0)
        // 保持最大数量
        if keywords.count > SearchHistory.maxCount {
            keywords = Array(keywords.prefix(SearchHistory.maxCount))
        }
    }
    
    mutating func remove(_ keyword: String) {
        keywords.removeAll { $0 == keyword }
    }
    
    mutating func clear() {
        keywords.removeAll()
    }
}

@MainActor
class SearchViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var searchText = ""
    @Published var selectedType: SearchResultType = .all
    @Published var isLoading = false
    @Published var error: String?
    
    // 搜索结果
    @Published var taskResults: [Task] = []
    @Published var expertResults: [TaskExpert] = []
    @Published var fleaMarketResults: [FleaMarketItem] = []
    @Published var forumResults: [ForumPost] = []
    
    // 搜索历史
    @Published var searchHistory: SearchHistory = SearchHistory(keywords: [])
    
    // 热门搜索词
    @Published var hotKeywords: [String] = [
        "代购", "跑腿", "家教", "翻译", "设计",
        "搬家", "维修", "清洁", "摄影", "陪练"
    ]
    
    // 是否有搜索结果
    var hasResults: Bool {
        !taskResults.isEmpty || !expertResults.isEmpty || 
        !fleaMarketResults.isEmpty || !forumResults.isEmpty
    }
    
    deinit {
        // SearchViewModel 使用 async/await，不需要清理 cancellables
    }
    
    // 总结果数
    var totalResultCount: Int {
        taskResults.count + expertResults.count + 
        fleaMarketResults.count + forumResults.count
    }
    
    // 筛选后的结果
    var filteredTaskResults: [Task] {
        selectedType == .all || selectedType == .task ? taskResults : []
    }
    
    var filteredExpertResults: [TaskExpert] {
        selectedType == .all || selectedType == .expert ? expertResults : []
    }
    
    var filteredFleaMarketResults: [FleaMarketItem] {
        selectedType == .all || selectedType == .fleaMarket ? fleaMarketResults : []
    }
    
    var filteredForumResults: [ForumPost] {
        selectedType == .all || selectedType == .forum ? forumResults : []
    }
    
    private var cancellables = Set<AnyCancellable>()
    private let apiService = APIService.shared
    
    init() {
        loadSearchHistory()
    }
    
    // MARK: - Search Methods
    
    /// 执行综合搜索
    func search() {
        let keyword = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !keyword.isEmpty else { return }
        
        // 保存到搜索历史
        saveToHistory(keyword)
        
        isLoading = true
        error = nil
        
        // 并行搜索各个模块
        _Concurrency.Task {
            await withTaskGroup(of: Void.self) { group in
                group.addTask { await self.searchTasks(keyword: keyword) }
                group.addTask { await self.searchExperts(keyword: keyword) }
                group.addTask { await self.searchFleaMarket(keyword: keyword) }
                group.addTask { await self.searchForum(keyword: keyword) }
            }
            
            isLoading = false
        }
    }
    
    /// 搜索任务
    private func searchTasks(keyword: String) async {
        do {
            let response: SearchTaskListResponse = try await apiService.request(
                "/api/tasks",
                method: .get,
                queryParams: ["keyword": keyword, "status": "open", "limit": "20"]
            )
            self.taskResults = response.tasks
        } catch {
            Logger.error("搜索任务失败: \(error)", category: .api)
            self.taskResults = []
        }
    }
    
    /// 搜索达人
    private func searchExperts(keyword: String) async {
        do {
            let response: SearchTaskExpertListResponse = try await apiService.request(
                "/api/task-experts",
                method: .get,
                queryParams: ["keyword": keyword, "limit": "20"]
            )
            self.expertResults = response.taskExperts
        } catch {
            Logger.error("搜索达人失败: \(error)", category: .api)
            self.expertResults = []
        }
    }
    
    /// 搜索跳蚤市场
    private func searchFleaMarket(keyword: String) async {
        do {
            let response: SearchFleaMarketListResponse = try await apiService.request(
                "/api/flea-market/items",
                method: .get,
                queryParams: ["keyword": keyword, "page_size": "20"]
            )
            self.fleaMarketResults = response.items
        } catch {
            Logger.error("搜索跳蚤市场失败: \(error)", category: .api)
            self.fleaMarketResults = []
        }
    }
    
    /// 搜索论坛
    private func searchForum(keyword: String) async {
        do {
            let response: SearchForumSearchResponse = try await apiService.request(
                "/api/forum/search",
                method: .get,
                queryParams: ["q": keyword, "page_size": "20"]
            )
            // 将搜索结果转换为 ForumPost 类型
            self.forumResults = response.posts.map { item in
                ForumPost(
                    id: item.id,
                    title: item.title,
                    content: nil,
                    contentPreview: item.contentPreview,
                    category: item.category,
                    author: item.author,
                    viewCount: item.viewCount ?? 0,
                    replyCount: item.replyCount ?? 0,
                    likeCount: item.likeCount ?? 0,
                    favoriteCount: 0,
                    isPinned: item.isPinned ?? false,
                    isFeatured: item.isFeatured ?? false,
                    isLocked: item.isLocked ?? false,
                    createdAt: item.createdAt ?? "",
                    lastReplyAt: item.lastReplyAt
                )
            }
        } catch {
            Logger.error("搜索论坛失败: \(error)", category: .api)
            self.forumResults = []
        }
    }
    
    /// 清空搜索结果
    func clearResults() {
        taskResults = []
        expertResults = []
        fleaMarketResults = []
        forumResults = []
        error = nil
    }
    
    // MARK: - Search History
    
    private func loadSearchHistory() {
        if let data = UserDefaults.standard.data(forKey: SearchHistory.storageKey),
           let history = try? JSONDecoder().decode(SearchHistory.self, from: data) {
            searchHistory = history
        }
    }
    
    private func saveSearchHistory() {
        if let data = try? JSONEncoder().encode(searchHistory) {
            UserDefaults.standard.set(data, forKey: SearchHistory.storageKey)
        }
    }
    
    func saveToHistory(_ keyword: String) {
        searchHistory.add(keyword)
        saveSearchHistory()
    }
    
    func removeFromHistory(_ keyword: String) {
        searchHistory.remove(keyword)
        saveSearchHistory()
    }
    
    func clearHistory() {
        searchHistory.clear()
        saveSearchHistory()
    }
    
    /// 使用历史记录或热门词搜索
    func searchWithKeyword(_ keyword: String) {
        searchText = keyword
        search()
    }
}

// MARK: - Response Models
// 注意：这些响应模型专门用于搜索，需要手动定义 CodingKeys 处理 snake_case

/// 搜索任务响应（pageSize 可选，因为某些 API 不返回）
struct SearchTaskListResponse: Codable {
    let tasks: [Task]
    let total: Int
    let page: Int?
    let pageSize: Int?
    
    enum CodingKeys: String, CodingKey {
        case tasks, total, page
        case pageSize = "page_size"
    }
}

/// 搜索达人响应（后端返回 task_experts）
struct SearchTaskExpertListResponse: Codable {
    let taskExperts: [TaskExpert]
    let total: Int?
    
    enum CodingKeys: String, CodingKey {
        case taskExperts = "task_experts"
        case total
    }
}

/// 搜索跳蚤市场响应
struct SearchFleaMarketListResponse: Codable {
    let items: [FleaMarketItem]
    let total: Int?
}

/// 搜索论坛帖子项（简化版，只包含列表必需字段）
struct SearchForumPostItem: Codable, Identifiable {
    let id: Int
    let title: String
    let contentPreview: String?
    let category: ForumCategory?
    let author: User?
    let viewCount: Int?
    let replyCount: Int?
    let likeCount: Int?
    let isPinned: Bool?
    let isFeatured: Bool?
    let isLocked: Bool?
    let createdAt: String?
    let lastReplyAt: String?
    
    enum CodingKeys: String, CodingKey {
        case id, title, category, author
        case contentPreview = "content_preview"
        case viewCount = "view_count"
        case replyCount = "reply_count"
        case likeCount = "like_count"
        case isPinned = "is_pinned"
        case isFeatured = "is_featured"
        case isLocked = "is_locked"
        case createdAt = "created_at"
        case lastReplyAt = "last_reply_at"
    }
}

/// 搜索论坛响应
struct SearchForumSearchResponse: Codable {
    let posts: [SearchForumPostItem]
    let total: Int?
    let page: Int?
    let pageSize: Int?
    
    enum CodingKeys: String, CodingKey {
        case posts, total, page
        case pageSize = "page_size"
    }
}

