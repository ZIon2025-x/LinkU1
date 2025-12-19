import Foundation
import Combine

class AuthViewModel: ObservableObject {
    @Published var email = ""
    @Published var password = ""
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // 注册相关
    @Published var registerName = ""
    @Published var registerEmail = ""
    @Published var registerPassword = ""
    @Published var registerPhone = ""
    @Published var registerVerificationCode = ""
    
    private let apiService = APIService.shared
    private var cancellables = Set<AnyCancellable>()
    
    func login(completion: @escaping (Bool) -> Void) {
        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = "请输入邮箱和密码"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        let body = ["username": email, "password": password] // 后端要求 username 字段 (OAuth2)
        
        // 注意：后端 /api/secure-auth/login 通常使用 OAuth2PasswordRequestForm，是 form-data 格式
        // 这里假设 APIService 能够处理 form-data 或者后端支持 JSON
        // 如果后端严格要求 form-data，APIService 需要调整。这里暂时按 JSON 处理。
        
        // 修改：假设后端接受 JSON
        apiService.request(LoginResponse.self, "/api/secure-auth/login", method: "POST", body: body)
            .sink(receiveCompletion: { [weak self] completion in
                self?.isLoading = false
                if case .failure(let error) = completion {
                    self?.errorMessage = error.localizedDescription
                }
            }, receiveValue: { [weak self] response in
                // 保存Token
                KeychainHelper.shared.save(response.accessToken, service: Constants.Keychain.service, account: Constants.Keychain.accessTokenKey)
                if let refreshToken = response.refreshToken {
                    KeychainHelper.shared.save(refreshToken, service: Constants.Keychain.service, account: Constants.Keychain.refreshTokenKey)
                }
                    // 保存用户信息到 AppState
                    DispatchQueue.main.async {
                        NotificationCenter.default.post(name: .userDidLogin, object: response.user)
                        
                        // 登录成功后，发送设备Token到后端（如果存在）
                        if let deviceToken = UserDefaults.standard.string(forKey: "device_token") {
                            APIService.shared.registerDeviceToken(deviceToken) { success in
                                if success {
                                    print("Device token sent after login")
                                }
                            }
                        }
                    }
                    completion(true)
            })
            .store(in: &cancellables)
    }
    
    func register(completion: @escaping (Bool, String?) -> Void) {
        guard !registerEmail.isEmpty, !registerPassword.isEmpty, !registerName.isEmpty else {
            errorMessage = "请填写所有必填项"
            completion(false, errorMessage)
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        var body: [String: Any] = [
            "email": registerEmail,
            "password": registerPassword,
            "name": registerName
        ]
        
        if !registerPhone.isEmpty {
            body["phone"] = registerPhone
        }
        
        apiService.request(RegisterResponse.self, "/api/users/register", method: "POST", body: body)
            .sink(receiveCompletion: { [weak self] result in
                self?.isLoading = false
                if case .failure(let error) = result {
                    self?.errorMessage = error.localizedDescription
                    completion(false, error.localizedDescription)
                }
            }, receiveValue: { [weak self] response in
                // 注册成功，可能需要邮箱验证
                if response.verificationRequired ?? false {
                    completion(true, response.message)
                } else {
                    // 如果不需要验证，直接登录
                    self?.email = self?.registerEmail ?? ""
                    self?.password = self?.registerPassword ?? ""
                    self?.login(completion: { success in
                        completion(success, success ? nil : "注册成功，但自动登录失败，请手动登录")
                    })
                }
            })
            .store(in: &cancellables)
    }
}

