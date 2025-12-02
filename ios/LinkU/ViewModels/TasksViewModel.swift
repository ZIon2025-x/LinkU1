import Foundation
import Combine

class TasksViewModel: ObservableObject {
    @Published var tasks: [Task] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let apiService = APIService.shared
    private var cancellables = Set<AnyCancellable>()
    
    func loadTasks(category: String? = nil, city: String? = nil, status: String? = nil) {
        isLoading = true
        errorMessage = nil
        
        var endpoint = "/api/tasks?"
        if let category = category {
            endpoint += "category=\(category)&"
        }
        if let city = city {
            endpoint += "city=\(city)&"
        }
        if let status = status {
            endpoint += "status=\(status)&"
        }
        
        apiService.request(TaskListResponse.self, endpoint, method: "GET")
            .sink(receiveCompletion: { [weak self] completion in
                self?.isLoading = false
                if case .failure(let error) = completion {
                    self?.errorMessage = error.localizedDescription
                }
            }, receiveValue: { [weak self] response in
                self?.tasks = response.tasks
            })
            .store(in: &cancellables)
    }
}

