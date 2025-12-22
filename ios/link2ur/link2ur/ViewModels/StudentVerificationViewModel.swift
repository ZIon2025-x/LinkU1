import Foundation
import Combine

@MainActor
class StudentVerificationViewModel: ObservableObject {
    @Published var verificationStatus: StudentVerificationStatusData?
    @Published var universities: [UniversityInfo] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private var cancellables = Set<AnyCancellable>()
    // 使用依赖注入获取服务
    private let apiService: APIService
    
    init(apiService: APIService? = nil) {
        self.apiService = apiService ?? APIService.shared
    }
    
    deinit {
        cancellables.removeAll()
    }
    
    // MARK: - Load Status
    
    func loadStatus() {
        isLoading = true
        errorMessage = nil
        
        apiService.getStudentVerificationStatus()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] (completion: Subscribers.Completion<APIError>) in
                    self?.isLoading = false
                    if case .failure(let error) = completion {
                        // 使用 ErrorHandler 统一处理错误
                        ErrorHandler.shared.handle(error, context: "加载学生认证状态")
                        if let apiError = error as? APIError {
                            self?.errorMessage = apiError.userFriendlyMessage
                        } else {
                            self?.errorMessage = error.localizedDescription
                        }
                    }
                },
                receiveValue: { [weak self] (response: StudentVerificationStatusResponse) in
                    self?.verificationStatus = response.data
                    self?.isLoading = false
                }
            )
            .store(in: &cancellables)
    }
    
    // MARK: - Submit Verification
    
    func submitVerification(email: String) -> AnyPublisher<Bool, Error> {
        return apiService.submitStudentVerification(email: email)
            .map { _ in true }
            .mapError { $0 as Error }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Renew Verification
    
    func renewVerification(email: String) -> AnyPublisher<Bool, Error> {
        return apiService.renewStudentVerification(email: email)
            .map { _ in true }
            .mapError { $0 as Error }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Change Email
    
    func changeEmail(newEmail: String) -> AnyPublisher<Bool, Error> {
        return apiService.changeStudentVerificationEmail(newEmail: newEmail)
            .map { _ in true }
            .mapError { $0 as Error }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Load Universities
    
    func loadUniversities(search: String? = nil) {
        isLoading = true
        
        apiService.getUniversities(page: 1, pageSize: 50, search: search)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] (completion: Subscribers.Completion<APIError>) in
                    self?.isLoading = false
                    if case .failure(let error) = completion {
                        // 使用 ErrorHandler 统一处理错误
                        ErrorHandler.shared.handle(error, context: "加载学生认证状态")
                        if let apiError = error as? APIError {
                            self?.errorMessage = apiError.userFriendlyMessage
                        } else {
                            self?.errorMessage = error.localizedDescription
                        }
                    }
                },
                receiveValue: { [weak self] (response: UniversityListResponse) in
                    self?.universities = response.data.items
                    self?.isLoading = false
                }
            )
            .store(in: &cancellables)
    }
}

