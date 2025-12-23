import Foundation
import LocalAuthentication

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
        
        // 使用 Keychain 的访问控制，要求生物识别
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessControl as String: SecAccessControlCreateWithFlags(
                kCFAllocatorDefault,
                kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
                .biometryAny,
                nil
            ) as Any
        ]
        
        // 删除旧数据
        SecItemDelete(query as CFDictionary)
        
        // 添加新数据
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    /// 从 Keychain 读取用户凭据（需要生物识别验证）
    /// 注意：由于 Keychain 项设置了 kSecAttrAccessControl 并要求生物识别，
    /// 读取时会自动触发生物识别验证弹窗
    public func loadCredentials() -> (username: String?, password: String?, phone: String?)? {
        let service = Constants.Keychain.service
        let account = "biometric_credentials"
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        // 状态码说明：
        // errSecSuccess: 生物识别验证成功，数据已返回
        // errSecUserCancel: 用户取消了生物识别验证
        // errSecAuthFailed: 生物识别验证失败
        // errSecItemNotFound: Keychain 中不存在该项
        guard status == errSecSuccess,
              let data = result as? Data,
              let credentials = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
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

