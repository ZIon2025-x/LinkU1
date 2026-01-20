import Foundation
import Combine

class ForumViewModel: ObservableObject {
    @Published var categories: [ForumCategory] = []
    @Published var posts: [ForumPost] = []
    @Published var selectedCategory: ForumCategory?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let apiService = APIService.shared
    private var cancellables = Set<AnyCancellable>()
    
    func loadCategories() {
        isLoading = true
        apiService.request(ForumCategoryListResponse.self, "/api/forum/categories", method: "GET")
            .sink(receiveCompletion: { [weak self] result in
                self?.isLoading = false
                if case .failure(let error) = result {
                    self?.errorMessage = error.localizedDescription
                }
            }, receiveValue: { [weak self] response in
                print("📥 收到论坛板块列表: 共 \(response.categories.count) 个板块")
                for (index, category) in response.categories.prefix(3).enumerated() {
                    print("  板块[\(index)]: id=\(category.id), name=\(category.name), nameEn=\(category.nameEn ?? "nil"), nameZh=\(category.nameZh ?? "nil")")
                }
                self?.categories = response.categories
            })
            .store(in: &cancellables)
    }
    
    func loadPosts(categoryId: Int? = nil, page: Int = 1) {
        isLoading = true
        var endpoint = "/api/forum/posts?page=\(page)&page_size=20"
        if let categoryId = categoryId {
            endpoint += "&category_id=\(categoryId)"
        }
        
        apiService.request(ForumPostListResponse.self, endpoint, method: "GET")
            .sink(receiveCompletion: { [weak self] result in
                self?.isLoading = false
                if case .failure(let error) = result {
                    self?.errorMessage = error.localizedDescription
                }
            }, receiveValue: { [weak self] response in
                if page == 1 {
                    self?.posts = response.posts
                } else {
                    self?.posts.append(contentsOf: response.posts)
                }
            })
            .store(in: &cancellables)
    }
}

class ForumPostDetailViewModel: ObservableObject {
    @Published var post: ForumPost?
    @Published var replies: [ForumReply] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let apiService = APIService.shared
    private var cancellables = Set<AnyCancellable>()
    
    func loadPost(postId: Int) {
        isLoading = true
        apiService.request(ForumPost.self, "/api/forum/posts/\(postId)", method: "GET")
            .sink(receiveCompletion: { [weak self] result in
                self?.isLoading = false
                if case .failure(let error) = result {
                    self?.errorMessage = error.localizedDescription
                }
            }, receiveValue: { [weak self] post in
                self?.post = post
            })
            .store(in: &cancellables)
    }
    
    func loadReplies(postId: Int) {
        apiService.request(ForumReplyListResponse.self, "/api/forum/posts/\(postId)/replies", method: "GET")
            .sink(receiveCompletion: { [weak self] result in
                if case .failure(let error) = result {
                    self?.errorMessage = error.localizedDescription
                }
            }, receiveValue: { [weak self] response in
                self?.replies = response.replies
            })
            .store(in: &cancellables)
    }
    
    func toggleLike(targetType: String, targetId: Int, completion: @escaping (Bool, Int) -> Void) {
        let body = ["target_type": targetType, "target_id": targetId] as [String : Any] as [String : Any]
        apiService.request(ForumLikeResponse.self, "/api/forum/likes", method: "POST", body: body)
            .sink(receiveCompletion: { _ in }, receiveValue: { response in
                completion(response.liked, response.likeCount)
            })
            .store(in: &cancellables)
    }
    
    func toggleFavorite(postId: Int, completion: @escaping (Bool) -> Void) {
        let body = ["post_id": postId]
        apiService.request(ForumFavoriteResponse.self, "/api/forum/favorites", method: "POST", body: body)
            .sink(receiveCompletion: { _ in }, receiveValue: { response in
                completion(response.favorited)
            })
            .store(in: &cancellables)
    }
    
    func replyToPost(postId: Int, content: String, parentReplyId: Int? = nil, completion: @escaping (Bool) -> Void) {
        var body: [String: Any] = [
            "content": content
        ]
        
        if let parentId = parentReplyId {
            body["parent_reply_id"] = parentId
        }
        
        apiService.request(ForumReply.self, "/api/forum/posts/\(postId)/replies", method: "POST", body: body)
            .sink(receiveCompletion: { result in
                if case .failure = result {
                    completion(false)
                }
            }, receiveValue: { [weak self] _ in
                // 重新加载回复列表
                self?.loadReplies(postId: postId)
                completion(true)
            })
            .store(in: &cancellables)
    }
    
    func likeReply(replyId: Int, completion: @escaping (Bool, Int) -> Void) {
        let body: [String: Any] = [
            "target_type": "reply",
            "target_id": replyId
        ]
        
        apiService.request(ForumLikeResponse.self, "/api/forum/likes", method: "POST", body: body)
            .sink(receiveCompletion: { _ in }, receiveValue: { response in
                completion(response.liked, response.likeCount)
            })
            .store(in: &cancellables)
    }
}

