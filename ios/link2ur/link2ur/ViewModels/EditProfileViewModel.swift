import Foundation
import Combine

@MainActor
class EditProfileViewModel: ObservableObject {
    @Published var name: String = ""
    @Published var email: String = ""
    @Published var phone: String = ""
    @Published var avatar: String = ""
    
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showSuccessAlert = false
    
    // 邮箱和手机号更新相关
    @Published var emailVerificationCode: String = ""
    @Published var phoneVerificationCode: String = ""
    @Published var isSendingEmailCode = false
    @Published var isSendingPhoneCode = false
    @Published var emailCountdown = 0
    @Published var phoneCountdown = 0
    @Published var showEmailCodeField = false
    @Published var showPhoneCodeField = false
    
    private let apiService = APIService.shared
    private var cancellables = Set<AnyCancellable>()
    private var emailTimer: Timer?
    private var phoneTimer: Timer?
    
    @Published var currentUser: User?
    
    init(currentUser: User?) {
        self.currentUser = currentUser
        loadCurrentProfile()
    }
    
    deinit {
        cancellables.removeAll()
        emailTimer?.invalidate()
        phoneTimer?.invalidate()
    }
    
    func loadCurrentProfile() {
        if let user = currentUser {
            name = user.name
            email = user.email ?? ""
            phone = user.phone ?? ""
            avatar = user.avatar ?? ""
        }
    }
    
    func sendEmailUpdateCode() {
        guard !email.isEmpty, email != (currentUser?.email ?? "") else { return }
        
        isSendingEmailCode = true
        apiService.sendEmailUpdateCode(newEmail: email)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isSendingEmailCode = false
                    if case .failure(let error) = completion {
                        self?.errorMessage = error.userFriendlyMessage
                    }
                },
                receiveValue: { [weak self] _ in
                    self?.isSendingEmailCode = false
                    self?.errorMessage = nil
                    self?.startEmailCountdown()
                }
            )
            .store(in: &cancellables)
    }
    
    func sendPhoneUpdateCode() {
        guard !phone.isEmpty, phone != (currentUser?.phone ?? "") else { return }
        
        isSendingPhoneCode = true
        apiService.sendPhoneUpdateCode(newPhone: phone)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isSendingPhoneCode = false
                    if case .failure(let error) = completion {
                        self?.errorMessage = error.userFriendlyMessage
                    }
                },
                receiveValue: { [weak self] _ in
                    self?.isSendingPhoneCode = false
                    self?.errorMessage = nil
                    self?.startPhoneCountdown()
                }
            )
            .store(in: &cancellables)
    }
    
    private func startEmailCountdown() {
        emailCountdown = 60
        emailTimer?.invalidate()
        emailTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            if self.emailCountdown > 0 {
                self.emailCountdown -= 1
            } else {
                timer.invalidate()
            }
        }
    }
    
    private func startPhoneCountdown() {
        phoneCountdown = 60
        phoneTimer?.invalidate()
        phoneTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            if self.phoneCountdown > 0 {
                self.phoneCountdown -= 1
            } else {
                timer.invalidate()
            }
        }
    }
    
    func saveProfile(completion: @escaping (User?) -> Void) {
        isLoading = true
        errorMessage = nil
        
        var body: [String: Any] = [:]
        if name != (currentUser?.name ?? "") {
            body["name"] = name
        }
        let currentEmail = currentUser?.email ?? ""
        if email != currentEmail {
            if !email.isEmpty {
                body["email"] = email
                if !emailVerificationCode.isEmpty {
                    body["email_verification_code"] = emailVerificationCode
                }
            } else if !currentEmail.isEmpty {
                // 清空邮箱（解绑）
                body["email"] = ""
            }
        }
        let currentPhone = currentUser?.phone ?? ""
        if phone != currentPhone {
            if !phone.isEmpty {
                body["phone"] = phone
                if !phoneVerificationCode.isEmpty {
                    body["phone_verification_code"] = phoneVerificationCode
                }
            } else if !currentPhone.isEmpty {
                // 清空手机号（解绑）
                body["phone"] = ""
            }
        }
        
        apiService.request(User.self, "/api/users/profile", method: "PATCH", body: body)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] result in
                    self?.isLoading = false
                    if case .failure(let error) = result {
                        if let apiError = error as? APIError {
                            self?.errorMessage = apiError.userFriendlyMessage
                        } else {
                            self?.errorMessage = error.localizedDescription
                        }
                        completion(nil)
                    }
                },
                receiveValue: { [weak self] updatedUser in
                    self?.isLoading = false
                    self?.showSuccessAlert = true
                    completion(updatedUser)
                }
            )
            .store(in: &cancellables)
    }
}

