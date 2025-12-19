import Foundation
import Combine

class CreatePostViewModel: ObservableObject {
    @Published var title = ""
    @Published var content = ""
    @Published var selectedCategoryId: Int?
    @Published var categories: [ForumCategory] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let apiService = APIService.shared
    private var cancellables = Set<AnyCancellable>()
    
    func loadCategories() {
        apiService.request(ForumCategoryListResponse.self, "/api/forum/categories", method: "GET")
            .sink(receiveCompletion: { _ in }, receiveValue: { [weak self] response in
                self?.categories = response.categories
            })
            .store(in: &cancellables)
    }
    
    func createPost(completion: @escaping (Bool) -> Void) {
        guard !title.isEmpty, !content.isEmpty, let categoryId = selectedCategoryId else {
            errorMessage = "请填写所有必填项"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        let body: [String: Any] = [
            "title": title,
            "content": content,
            "category_id": categoryId
        ]
        
        apiService.request(ForumPost.self, "/api/forum/posts", method: "POST", body: body)
            .sink(receiveCompletion: { [weak self] result in
                self?.isLoading = false
                if case .failure(let error) = result {
                    self?.errorMessage = error.localizedDescription
                    completion(false)
                }
            }, receiveValue: { [weak self] _ in
                self?.reset()
                completion(true)
            })
            .store(in: &cancellables)
    }
    
    func reset() {
        title = ""
        content = ""
        selectedCategoryId = nil
        errorMessage = nil
    }
}

