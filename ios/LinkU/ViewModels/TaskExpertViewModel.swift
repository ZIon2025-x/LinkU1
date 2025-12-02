import Foundation
import Combine

class TaskExpertViewModel: ObservableObject {
    @Published var experts: [TaskExpert] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let apiService = APIService.shared
    private var cancellables = Set<AnyCancellable>()
    
    func loadExperts(category: String? = nil) {
        isLoading = true
        var endpoint = "/api/task-experts?status=active&limit=50"
        if let category = category {
            endpoint += "&category=\(category)"
        }
        
        apiService.request([TaskExpert].self, endpoint, method: "GET")
            .sink(receiveCompletion: { [weak self] completion in
                self?.isLoading = false
                if case .failure(let error) = completion {
                    self?.errorMessage = error.localizedDescription
                }
            }, receiveValue: { [weak self] experts in
                self?.experts = experts
            })
            .store(in: &cancellables)
    }
}

class TaskExpertDetailViewModel: ObservableObject {
    @Published var expert: TaskExpert?
    @Published var services: [TaskExpertService] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let apiService = APIService.shared
    private var cancellables = Set<AnyCancellable>()
    
    func loadExpert(expertId: String) {
        isLoading = true
        apiService.request(TaskExpert.self, "/api/task-experts/\(expertId)", method: "GET")
            .sink(receiveCompletion: { [weak self] completion in
                self?.isLoading = false
                if case .failure(let error) = completion {
                    self?.errorMessage = error.localizedDescription
                }
            }, receiveValue: { [weak self] expert in
                self?.expert = expert
            })
            .store(in: &cancellables)
    }
    
    func loadServices(expertId: String) {
        apiService.request([TaskExpertService].self, "/api/task-experts/\(expertId)/services", method: "GET")
            .sink(receiveCompletion: { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.errorMessage = error.localizedDescription
                }
            }, receiveValue: { [weak self] services in
                self?.services = services.filter { $0.status == "active" }
            })
            .store(in: &cancellables)
    }
}

class ServiceDetailViewModel: ObservableObject {
    @Published var service: TaskExpertService?
    @Published var timeSlots: [ServiceTimeSlot] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let apiService = APIService.shared
    private var cancellables = Set<AnyCancellable>()
    
    func loadService(serviceId: Int) {
        isLoading = true
        apiService.request(TaskExpertService.self, "/api/task-experts/services/\(serviceId)", method: "GET")
            .sink(receiveCompletion: { [weak self] completion in
                self?.isLoading = false
                if case .failure(let error) = completion {
                    self?.errorMessage = error.localizedDescription
                }
            }, receiveValue: { [weak self] service in
                self?.service = service
            })
            .store(in: &cancellables)
    }
    
    func loadTimeSlots(serviceId: Int) {
        apiService.request([ServiceTimeSlot].self, "/api/task-experts/services/\(serviceId)/time-slots", method: "GET")
            .sink(receiveCompletion: { _ in }, receiveValue: { [weak self] slots in
                self?.timeSlots = slots.filter { $0.isAvailable }
            })
            .store(in: &cancellables)
    }
    
    func applyService(serviceId: Int, message: String?, counterPrice: Double?, completion: @escaping (Bool) -> Void) {
        var body: [String: Any] = [:]
        if let message = message {
            body["application_message"] = message
        }
        if let counterPrice = counterPrice {
            body["counter_price"] = counterPrice
        }
        
        apiService.request(ServiceApplication.self, "/api/task-experts/services/\(serviceId)/apply", method: "POST", body: body)
            .sink(receiveCompletion: { completion in
                if case .failure = completion {
                    completion(false)
                }
            }, receiveValue: { _ in
                completion(true)
            })
            .store(in: &cancellables)
    }
}

class MyServiceApplicationsViewModel: ObservableObject {
    @Published var applications: [ServiceApplication] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let apiService = APIService.shared
    private var cancellables = Set<AnyCancellable>()
    
    func loadApplications() {
        isLoading = true
        apiService.request(ServiceApplicationListResponse.self, "/api/users/me/service-applications", method: "GET")
            .sink(receiveCompletion: { [weak self] completion in
                self?.isLoading = false
                if case .failure(let error) = completion {
                    self?.errorMessage = error.localizedDescription
                }
            }, receiveValue: { [weak self] response in
                self?.applications = response.items
            })
            .store(in: &cancellables)
    }
}

class TaskExpertApplicationViewModel: ObservableObject {
    @Published var application: TaskExpertApplication?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let apiService = APIService.shared
    private var cancellables = Set<AnyCancellable>()
    
    func loadMyApplication() {
        isLoading = true
        apiService.request(TaskExpertApplication.self, "/api/task-experts/my-application", method: "GET")
            .sink(receiveCompletion: { [weak self] completion in
                self?.isLoading = false
                if case .failure(let error) = completion {
                    // 404 表示没有申请，这是正常的
                    if case APIError.httpError(404) = error {
                        self?.application = nil
                    } else {
                        self?.errorMessage = error.localizedDescription
                    }
                }
            }, receiveValue: { [weak self] application in
                self?.application = application
            })
            .store(in: &cancellables)
    }
    
    func apply(message: String, completion: @escaping (Bool) -> Void) {
        isLoading = true
        let body = ["application_message": message]
        apiService.request(TaskExpertApplication.self, "/api/task-experts/apply", method: "POST", body: body)
            .sink(receiveCompletion: { [weak self] completion in
                self?.isLoading = false
                if case .failure = completion {
                    completion(false)
                }
            }, receiveValue: { [weak self] application in
                self?.application = application
                completion(true)
            })
            .store(in: &cancellables)
    }
}

