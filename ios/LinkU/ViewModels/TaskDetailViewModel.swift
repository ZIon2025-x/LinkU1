import Foundation
import Combine

class TaskDetailViewModel: ObservableObject {
    @Published var task: Task?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let apiService = APIService.shared
    private var cancellables = Set<AnyCancellable>()
    
    func loadTask(taskId: Int) {
        isLoading = true
        apiService.request(Task.self, "/api/tasks/\(taskId)", method: "GET")
            .sink(receiveCompletion: { [weak self] result in
                self?.isLoading = false
                if case .failure(let error) = result {
                    self?.errorMessage = error.localizedDescription
                }
            }, receiveValue: { [weak self] task in
                self?.task = task
            })
            .store(in: &cancellables)
    }
    
    func applyTask(taskId: Int, message: String?, completion: @escaping (Bool) -> Void) {
        var body: [String: Any] = [:]
        if let message = message {
            body["message"] = message
        }
        
        apiService.request(EmptyResponse.self, "/api/tasks/\(taskId)/accept", method: "POST", body: body)
            .sink(receiveCompletion: { result in
                if case .failure = result {
                    completion(false)
                }
            }, receiveValue: { _ in
                completion(true)
            })
            .store(in: &cancellables)
    }
}

