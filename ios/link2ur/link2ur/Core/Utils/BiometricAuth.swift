import Foundation
import LocalAuthentication
import Security

// 导入 Logger（如果存在）
#if canImport(Logger)
import Logger
#endif

/// 生物识别认证管理器（Face ID / Touch ID）
public class BiometricAuth {
    public static let shared = BiometricAuth()
    
    private init() {}
    
    /// 生物识别类型
    public enum BiometricType {
        case none
        case touchID
        case faceID
        case opticID  // iOS 17+
        
        var displayName: String {
            switch self {
            case .none:
                return "无"
            case .touchID:
                return "Touch ID"
            case .faceID:
                return "Face ID"
            case .opticID:
                return "Optic ID"
            }
        }
    }
    
    /// 检查设备是否支持生物识别
    public func canUseBiometric() -> Bool {
        let context = LAContext()
        var error: NSError?
        let canEvaluate = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
        return canEvaluate
    }
    
    /// 获取可用的生物识别类型
    public func availableBiometricType() -> BiometricType {
        let context = LAContext()
        var error: NSError?
        
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return .none
        }
        
        // 检查生物识别类型
        if #available(iOS 11.0, *) {
            switch context.biometryType {
            case .none:
                return .none
            case .touchID:
                return .touchID
            case .faceID:
                return .faceID
            case .opticID:
                if #available(iOS 17.0, *) {
                    return .opticID
                } else {
                    return .faceID
                }
            @unknown default:
                return .none
            }
        } else {
            // iOS 10 及以下，默认为 Touch ID
            return .touchID
        }
    }
    
    /// 使用生物识别进行认证
    /// - Parameters:
    ///   - reason: 认证原因说明
    ///   - completion: 认证结果回调
    public func authenticate(
        reason: String = "请使用 Face ID 或 Touch ID 登录",
        completion: @escaping (Bool, Error?) -> Void
    ) {
        let context = LAContext()
        var error: NSError?
        
        // 检查是否支持生物识别
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            if let error = error {
                completion(false, error)
            } else {
                completion(false, NSError(domain: "BiometricAuth", code: -1, userInfo: [NSLocalizedDescriptionKey: "设备不支持生物识别"]))
            }
            return
        }
        
        // 执行生物识别认证
        context.evaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            localizedReason: reason
        ) { success, error in
            DispatchQueue.main.async {
                completion(success, error)
            }
        }
    }
    
    /// 使用生物识别进行认证（Async/Await 版本）
    @available(iOS 13.0, *)
    public func authenticateAsync(reason: String = "请使用 Face ID 或 Touch ID 登录") async throws -> Bool {
        let context = LAContext()
        var error: NSError?
        
        // 检查是否支持生物识别
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            if let error = error {
                throw error
            } else {
                throw NSError(domain: "BiometricAuth", code: -1, userInfo: [NSLocalizedDescriptionKey: "设备不支持生物识别"])
            }
        }
        
        // 执行生物识别认证
        return try await context.evaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            localizedReason: reason
        )
    }
    
    /// 检查是否已启用生物识别登录
    public func isBiometricLoginEnabled() -> Bool {
        return UserDefaults.standard.bool(forKey: "biometric_login_enabled")
    }
    
    /// 启用/禁用生物识别登录
    public func setBiometricLoginEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: "biometric_login_enabled")
    }
    
    /// 保存用户凭据到 Keychain（使用生物识别保护）
    /// - Parameters:
    ///   - username: 用户名（手机号或邮箱）
    ///   - password: 密码（可选，用于密码登录）
    ///   - phone: 手机号（用于验证码登录）
    public func saveCredentials(
        username: String? = nil,
        password: String? = nil,
        phone: String? = nil
    ) -> Bool {
        // 使用 Keychain 保存凭据，并设置访问控制为生物识别
        let service = Constants.Keychain.service
        let account = "biometric_credentials"
        
        var credentials: [String: Any] = [:]
        if let username = username {
            credentials["username"] = username
        }
        if let password = password {
            credentials["password"] = password
        }
        if let phone = phone {
            credentials["phone"] = phone
        }
        
        guard let data = try? JSONSerialization.data(withJSONObject: credentials) else {
            return false
        }
        
        // 先删除旧数据（使用简单的查询，不包含访问控制）
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(deleteQuery as CFDictionary)
        
        // 检查设备是否支持生物识别
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            // 不支持生物识别，使用普通 Keychain 存储
            return KeychainHelper.shared.save(data, service: service, account: account)
        }
        
        // 使用 Keychain 的访问控制，要求生物识别
        // 使用 .biometryAny 支持 Face ID、Touch ID 或 Optic ID
        guard let accessControl = SecAccessControlCreateWithFlags(
            kCFAllocatorDefault,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            .biometryAny,
            nil
        ) else {
            // 如果创建访问控制失败，回退到普通存储
            print("⚠️ 无法创建生物识别访问控制，使用普通 Keychain 存储")
            return KeychainHelper.shared.save(data, service: service, account: account)
        }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessControl as String: accessControl,
            kSecUseAuthenticationContext as String: context  // 使用上下文
        ]
        
        // 添加新数据
        let status = SecItemAdd(query as CFDictionary, nil)
        
        if status != errSecSuccess {
            print("⚠️ Keychain 保存失败，状态码: \(status)")
            // 如果保存失败，尝试使用普通方式保存
            return KeychainHelper.shared.save(data, service: service, account: account)
        }
        
        return true
    }
    
    /// 从 Keychain 读取用户凭据（需要生物识别验证）
    /// 注意：由于 Keychain 项设置了 kSecAttrAccessControl 并要求生物识别，
    /// 读取时会自动触发生物识别验证弹窗
    /// 必须在主线程调用此方法
    public func loadCredentials() -> (username: String?, password: String?, phone: String?)? {
        // 确保在主线程执行
        guard Thread.isMainThread else {
            print("⚠️ loadCredentials 必须在主线程调用")
            return nil
        }
        
        let service = Constants.Keychain.service
        let account = "biometric_credentials"
        
        // 创建 LAContext 用于生物识别验证
        let context = LAContext()
        context.localizedFallbackTitle = ""  // 禁用备用选项
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecUseAuthenticationContext as String: context  // 使用上下文
        ]
        
        var result: AnyObject?
        var error: Unmanaged<CFError>?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        // 状态码说明：
        // errSecSuccess (0): 生物识别验证成功，数据已返回
        // errSecUserCancel (-128): 用户取消了生物识别验证
        // errSecAuthFailed (-25293): 生物识别验证失败
        // errSecItemNotFound (-25300): Keychain 中不存在该项
        // errSecInteractionNotAllowed (-25308): 需要用户交互但当前不允许
        guard status == errSecSuccess else {
            if status == -128 {  // errSecUserCancel
                print("⚠️ 用户取消了生物识别验证")
            } else if status == -25293 {  // errSecAuthFailed
                print("⚠️ 生物识别验证失败")
            } else if status == -25300 {  // errSecItemNotFound
                print("⚠️ Keychain 中未找到凭据")
            } else if status == -25308 {  // errSecInteractionNotAllowed
                print("⚠️ 需要用户交互但当前不允许")
            } else {
                print("⚠️ Keychain 读取失败，状态码: \(status)")
            }
            return nil
        }
        
        guard let data = result as? Data,
              let credentials = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            print("⚠️ 无法解析 Keychain 数据")
            return nil
        }
        
        return (
            username: credentials["username"] as? String,
            password: credentials["password"] as? String,
            phone: credentials["phone"] as? String
        )
    }
    
    /// 清除保存的凭据
    public func clearCredentials() -> Bool {
        let service = Constants.Keychain.service
        let account = "biometric_credentials"
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
}

