import Foundation
import Combine

class AuthViewModel: ObservableObject {
    private let performanceMonitor = PerformanceMonitor.shared
    @Published var email = ""
    @Published var password = ""
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // 登录方式：true为手机验证码登录，false为邮箱密码登录
    @Published var isPhoneLogin = false
    
    // 手机验证码登录相关
    @Published var countryCode = "+44"  // 默认英国区号
    @Published var phone = ""  // 手机号（不含区号）
    @Published var verificationCode = ""
    @Published var isSendingCode = false
    @Published var countdownSeconds = 0
    @Published var canResendCode = true
    
    // CAPTCHA相关
    @Published var captchaToken: String? = nil
    @Published var captchaEnabled = false
    @Published var captchaSiteKey: String? = nil
    @Published var captchaType: String? = nil  // "recaptcha" 或 "hcaptcha"
    
    // 支持的区号列表（目前只支持英国）
    let supportedCountryCodes = [
        ("🇬🇧", "+44", "UK")
    ]
    
    /// 获取完整的手机号（区号+号码）
    var fullPhoneNumber: String {
        return countryCode + phone
    }
    
    // 注册相关
    @Published var registerName = ""
    @Published var registerEmail = ""
    @Published var registerPassword = ""
    @Published var registerPhone = ""
    @Published var registerVerificationCode = ""
    
    // 使用依赖注入获取服务（通过协议类型，但实际使用具体类型以支持扩展方法）
    private let apiService: APIService
    private var cancellables = Set<AnyCancellable>()
    private var countdownTimer: Timer?
    
    // 支持依赖注入的初始化方法
    init(apiService: APIService? = nil) {
        // 使用依赖注入或回退到默认实现
        // 注意：由于 APIService 有很多扩展方法，我们使用具体类型而不是协议
        // 但通过 DependencyContainer 获取，保持可测试性
        if let injected = apiService {
            self.apiService = injected
        } else if let resolved = DependencyContainer.shared.resolveOptional(APIServiceProtocol.self) as? APIService {
            self.apiService = resolved
        } else {
            self.apiService = APIService.shared
        }
        // 检查CAPTCHA配置
        checkCaptchaConfig()
    }
    
    /// 检查CAPTCHA配置
    func checkCaptchaConfig() {
        apiService.getCaptchaSiteKey()
            .sink(receiveCompletion: { result in
                if case .failure(let error) = result {
                    Logger.warning("获取CAPTCHA配置失败: \(error.localizedDescription)", category: .api)
                }
            }, receiveValue: { [weak self] config in
                DispatchQueue.main.async {
                    self?.captchaEnabled = config.enabled
                    self?.captchaSiteKey = config.siteKey
                    self?.captchaType = config.type
                    Logger.success("CAPTCHA配置: enabled=\(config.enabled), type=\(config.type ?? "none"), siteKey=\(config.siteKey?.prefix(10) ?? "none")", category: .api)
                }
            })
            .store(in: &cancellables)
    }
    
    func login(completion: @escaping (Bool) -> Void) {
        // 使用 ValidationHelper 验证邮箱
        guard !email.isEmpty else {
            errorMessage = "请输入邮箱"
            return
        }
        
        guard ValidationHelper.isValidEmail(email) else {
            errorMessage = "请输入有效的邮箱地址"
            return
        }
        
        guard !password.isEmpty else {
            errorMessage = "请输入密码"
            return
        }
        
        let startTime = Date()
        let endpoint = "/api/secure-auth/login"
        
        isLoading = true
        errorMessage = nil
        
        // 后端接受 JSON 格式，字段名为 email 和 password
        let body: [String: Any] = [
            "email": email,
            "password": password
        ]
        
        apiService.request(LoginResponse.self, endpoint, method: "POST", body: body)
            .sink(receiveCompletion: { [weak self] completion in
                let duration = Date().timeIntervalSince(startTime)
                self?.isLoading = false
                if case .failure(let error) = completion {
                    // 使用 ErrorHandler 统一处理错误
                    ErrorHandler.shared.handle(error, context: "用户登录")
                    // 记录性能指标
                    self?.performanceMonitor.recordNetworkRequest(
                        endpoint: endpoint,
                        method: "POST",
                        duration: duration,
                        error: error
                    )
                    // 同时保留 errorMessage 用于 UI 显示
                    if let apiError = error as? APIError {
                        self?.errorMessage = apiError.userFriendlyMessage
                    } else {
                        self?.errorMessage = error.localizedDescription
                    }
                } else {
                    // 记录成功请求的性能指标
                    self?.performanceMonitor.recordNetworkRequest(
                        endpoint: endpoint,
                        method: "POST",
                        duration: duration,
                        statusCode: 200
                    )
                }
            }, receiveValue: { response in
                // 后端使用 session-based 认证，保存 session_id
                // 优先从 authHeaders 中获取，如果没有则从顶层获取
                let sessionId = response.authHeaders?.sessionId ?? response.sessionId
                if let sessionId = sessionId, !sessionId.isEmpty {
                    KeychainHelper.shared.save(sessionId, service: Constants.Keychain.service, account: Constants.Keychain.accessTokenKey)
                    Logger.success("Session ID 已保存: \(sessionId.prefix(20))...", category: .auth)
                } else {
                    Logger.warning("警告: 登录响应中未找到 Session ID", category: .auth)
                }
                
                // 将 LoginUser 转换为 User（登录响应只包含部分字段，需要获取完整用户信息）
                let loginUser = response.user
                let user = User(
                    id: loginUser.id,
                    name: loginUser.name,
                    email: loginUser.email,
                    phone: nil,
                    isVerified: loginUser.isVerified,
                    userLevel: loginUser.userLevel,
                    avatar: nil,
                    createdAt: nil,
                    userType: nil,
                    taskCount: nil,
                    completedTaskCount: nil,
                    avgRating: nil,
                    residenceCity: nil,
                    languagePreference: nil
                )
                
                // 保存用户信息到 AppState
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .userDidLogin, object: user)
                    
                    // 登录成功后，发送设备Token到后端（如果存在）
                    if let deviceToken = UserDefaults.standard.string(forKey: "device_token") {
                        APIService.shared.registerDeviceToken(deviceToken) { success in
                            if success {
                                Logger.debug("Device token sent after login", category: .auth)
                            }
                        }
                    }
                }
                completion(true)
            })
            .store(in: &cancellables)
    }
    
    /// 清理和格式化手机号
    /// 处理包含区号的输入（如 +4407700123456）和英国手机号的前导0
    private func cleanAndFormatPhoneNumber(_ input: String) -> (countryCode: String, phoneNumber: String)? {
        // 清理输入（去除空格和特殊字符，但保留+号）
        let cleaned = input.replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: "(", with: "")
            .replacingOccurrences(of: ")", with: "")
        
        // 检查是否包含区号（以+开头）
        if cleaned.hasPrefix("+") {
            // 提取区号（+44）
            if cleaned.hasPrefix("+44") {
                let phonePart = String(cleaned.dropFirst(3)) // 去掉 +44
                // 如果手机号以0开头（英国国内格式），去掉前导0
                let formattedPhone = phonePart.hasPrefix("0") ? String(phonePart.dropFirst()) : phonePart
                // 验证手机号格式（英国手机号去掉前导0后应该是10位）
                if formattedPhone.count >= 7 && formattedPhone.count <= 15 && formattedPhone.allSatisfy({ $0.isNumber }) {
                    return ("+44", formattedPhone)
                }
            } else {
                // 其他区号暂不支持，返回nil
                return nil
            }
        }
        
        // 如果没有+号，使用当前选择的区号
        // 如果是英国区号且手机号以0开头，去掉前导0
        var formattedPhone = cleaned
        if countryCode == "+44" && formattedPhone.hasPrefix("0") {
            formattedPhone = String(formattedPhone.dropFirst())
        }
        
        // 使用 ValidationHelper 验证手机号格式
        let fullPhoneNumber = countryCode + formattedPhone
        if ValidationHelper.isValidUKPhone(fullPhoneNumber) || ValidationHelper.isValidInternationalPhone(fullPhoneNumber) {
            return (countryCode, formattedPhone)
        }
        
        // 如果 ValidationHelper 验证失败，回退到基本验证
        if formattedPhone.count >= 7 && formattedPhone.count <= 15 && formattedPhone.allSatisfy({ $0.isNumber }) {
            return (countryCode, formattedPhone)
        }
        
        return nil
    }
    
    /// 发送手机验证码
    func sendPhoneCode(completion: @escaping (Bool, String?) -> Void) {
        guard !phone.isEmpty else {
            errorMessage = "请输入手机号"
            completion(false, errorMessage)
            return
        }
        
        // 清理和格式化手机号
        guard let (finalCountryCode, cleanedPhoneNumber) = cleanAndFormatPhoneNumber(phone) else {
            errorMessage = "请输入有效的手机号（7-15位数字）"
            completion(false, errorMessage)
            return
        }
        
        isSendingCode = true
        errorMessage = nil
        
        // 组合区号和手机号
        let fullPhone = finalCountryCode + cleanedPhoneNumber
        
        // 如果CAPTCHA启用但还没有token，需要先完成验证
        // 注意：这里暂时允许没有token（如果CAPTCHA未启用）
        // 实际使用时，如果CAPTCHA启用，应该在UI中先完成验证再调用此方法
        
        // 检查CAPTCHA要求
        if captchaEnabled && captchaToken == nil {
            errorMessage = "请先完成人机验证"
            isSendingCode = false
            completion(false, "请先完成人机验证")
            return
        }
        
        print("📱 发送验证码: phone=\(fullPhone), captchaToken=\(captchaToken != nil ? "已设置" : "未设置"), captchaEnabled=\(captchaEnabled)")
        
        let startTime = Date()
        let endpoint = "/api/secure-auth/send-phone-code"
        
        apiService.sendPhoneCode(phone: fullPhone, captchaToken: captchaToken)
            .sink(receiveCompletion: { [weak self] result in
                let duration = Date().timeIntervalSince(startTime)
                self?.isSendingCode = false
                if case .failure(let error) = result {
                    // 使用 ErrorHandler 统一处理错误
                    ErrorHandler.shared.handle(error, context: "发送验证码")
                    // 记录性能指标
                    self?.performanceMonitor.recordNetworkRequest(
                        endpoint: endpoint,
                        method: "POST",
                        duration: duration,
                        error: error
                    )
                    let errorMsg: String
                    if let apiError = error as? APIError {
                        errorMsg = apiError.userFriendlyMessage
                    } else {
                        errorMsg = error.localizedDescription
                    }
                    Logger.error("发送验证码失败: \(errorMsg)", category: .auth)
                    self?.errorMessage = errorMsg
                    completion(false, errorMsg)
                } else {
                    // 记录成功请求的性能指标
                    self?.performanceMonitor.recordNetworkRequest(
                        endpoint: endpoint,
                        method: "POST",
                        duration: duration,
                        statusCode: 200
                    )
                }
            }, receiveValue: { [weak self] _ in
                // 验证码发送成功，开始倒计时
                // 注意：发送验证码成功后，清除CAPTCHA token（因为token只能使用一次）
                // 下次发送验证码时需要重新验证
                Logger.success("验证码发送成功", category: .auth)
                self?.captchaToken = nil
                self?.startCountdown()
                completion(true, nil)
            })
            .store(in: &cancellables)
    }
    
    /// 手机验证码登录
    func loginWithPhone(completion: @escaping (Bool) -> Void) {
        guard !phone.isEmpty, !verificationCode.isEmpty else {
            errorMessage = "请输入手机号和验证码"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        // 清理和格式化手机号
        guard let (finalCountryCode, cleanedPhoneNumber) = cleanAndFormatPhoneNumber(phone) else {
            errorMessage = "请输入有效的手机号（7-15位数字）"
            isLoading = false
            return
        }
        
        // 组合区号和手机号
        let fullPhone = finalCountryCode + cleanedPhoneNumber
        
        let startTime = Date()
        let endpoint = "/api/secure-auth/login-phone"
        
        // 登录时不需要CAPTCHA（发送验证码时已经验证过了，后端也不要求登录时验证）
        // 清除captchaToken，因为token只能使用一次，且登录时不需要
        apiService.loginWithPhone(phone: fullPhone, code: verificationCode, captchaToken: nil)
            .sink(receiveCompletion: { [weak self] result in
                let duration = Date().timeIntervalSince(startTime)
                self?.isLoading = false
                if case .failure(let error) = result {
                    // 使用 ErrorHandler 统一处理错误
                    ErrorHandler.shared.handle(error, context: "手机验证码登录")
                    // 记录性能指标
                    self?.performanceMonitor.recordNetworkRequest(
                        endpoint: endpoint,
                        method: "POST",
                        duration: duration,
                        error: error
                    )
                    if let apiError = error as? APIError {
                        self?.errorMessage = apiError.userFriendlyMessage
                    } else {
                        self?.errorMessage = error.localizedDescription
                    }
                } else {
                    // 记录成功请求的性能指标
                    self?.performanceMonitor.recordNetworkRequest(
                        endpoint: endpoint,
                        method: "POST",
                        duration: duration,
                        statusCode: 200
                    )
                }
            }, receiveValue: { [weak self] response in
                guard let self = self else { return }
                
                // 后端使用 session-based 认证，保存 session_id
                let sessionId = response.authHeaders?.sessionId ?? response.sessionId
                if let sessionId = sessionId, !sessionId.isEmpty {
                    KeychainHelper.shared.save(sessionId, service: Constants.Keychain.service, account: Constants.Keychain.accessTokenKey)
                    Logger.success("Session ID 已保存: \(sessionId.prefix(20))...", category: .auth)
                } else {
                    Logger.warning("警告: 登录响应中未找到 Session ID", category: .auth)
                }
                
                // 将 LoginUser 转换为 User
                let loginUser = response.user
                // 使用格式化后的手机号
                let (finalCountryCode, cleanedPhoneNumber) = self.cleanAndFormatPhoneNumber(self.phone) ?? (self.countryCode, self.phone)
                let userPhone = self.phone.isEmpty ? nil : (finalCountryCode + cleanedPhoneNumber)  // 使用完整手机号（区号+号码）
                let user = User(
                    id: loginUser.id,
                    name: loginUser.name,
                    email: loginUser.email,
                    phone: userPhone,
                    isVerified: loginUser.isVerified,
                    userLevel: loginUser.userLevel,
                    avatar: nil,
                    createdAt: nil,
                    userType: nil,
                    taskCount: nil,
                    completedTaskCount: nil,
                    avgRating: nil,
                    residenceCity: nil,
                    languagePreference: nil
                )
                
                // 保存用户信息到 AppState
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .userDidLogin, object: user)
                    
                    // 登录成功后，发送设备Token到后端（如果存在）
                    if let deviceToken = UserDefaults.standard.string(forKey: "device_token") {
                        APIService.shared.registerDeviceToken(deviceToken) { success in
                            if success {
                                Logger.debug("Device token sent after login", category: .auth)
                            }
                        }
                    }
                }
                completion(true)
            })
            .store(in: &cancellables)
    }
    
    /// 开始倒计时
    private func startCountdown() {
        countdownSeconds = 60
        canResendCode = false
        
        countdownTimer?.invalidate()
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            
            if self.countdownSeconds > 0 {
                self.countdownSeconds -= 1
            } else {
                self.canResendCode = true
                timer.invalidate()
                self.countdownTimer = nil
                // 倒计时结束后，清除CAPTCHA token（下次发送需要重新验证）
                self.captchaToken = nil
            }
        }
    }
    
    deinit {
        countdownTimer?.invalidate()
    }
    
    func register(completion: @escaping (Bool, String?) -> Void) {
        // 使用 ValidationHelper 验证输入
        guard !registerName.isEmpty else {
            errorMessage = "请输入姓名"
            completion(false, errorMessage)
            return
        }
        
        guard !registerEmail.isEmpty else {
            errorMessage = "请输入邮箱"
            completion(false, errorMessage)
            return
        }
        
        guard ValidationHelper.isValidEmail(registerEmail) else {
            errorMessage = "请输入有效的邮箱地址"
            completion(false, errorMessage)
            return
        }
        
        guard !registerPassword.isEmpty else {
            errorMessage = "请输入密码"
            completion(false, errorMessage)
            return
        }
        
        // 验证密码强度
        let passwordResult = ValidationHelper.validatePassword(
            registerPassword,
            minLength: 8,
            requireUppercase: true,
            requireDigit: true
        )
        
        if !passwordResult.isValid {
            errorMessage = passwordResult.errorMessage
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
                    // 使用 ErrorHandler 统一处理错误
                    ErrorHandler.shared.handle(error, context: "用户注册")
                    let errorMsg: String
                    if let apiError = error as? APIError {
                        errorMsg = apiError.userFriendlyMessage
                    } else {
                        errorMsg = error.localizedDescription
                    }
                    self?.errorMessage = errorMsg
                    completion(false, errorMsg)
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

