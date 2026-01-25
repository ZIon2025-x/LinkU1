import Foundation
import Security
#if canImport(CryptoKit)
import CryptoKit
#endif

/// 企业级安全管理器
/// 提供数据加密、证书锁定、敏感数据保护等功能

public final class SecurityManager {
    public static let shared = SecurityManager()
    
    #if canImport(CryptoKit)
    private let encryptionKey: SymmetricKey
    
    private init() {
        // 从 Keychain 获取或生成加密密钥
        if let keyDataString = KeychainHelper.shared.read(
            service: Constants.Keychain.service,
            account: "encryption_key"
        ),
           let keyData = keyDataString.data(using: .utf8),
           let keyDataDecoded = Data(base64Encoded: keyData) {
            let key = SymmetricKey(data: keyDataDecoded)
            self.encryptionKey = key
        } else {
            // 生成新密钥
            let key = SymmetricKey(size: .bits256)
            let keyData = key.withUnsafeBytes { Data($0) }
            let keyDataBase64 = keyData.base64EncodedString()
            if let keyDataUTF8 = keyDataBase64.data(using: .utf8) {
                _ = KeychainHelper.shared.save(
                    keyDataUTF8,
                    service: Constants.Keychain.service,
                    account: "encryption_key"
                )
            }
            self.encryptionKey = key
        }
    }
    
    // MARK: - 数据加密/解密
    
    /// 加密敏感数据
    public func encrypt(_ data: Data) throws -> Data {
        #if canImport(CryptoKit)
        let sealedBox = try AES.GCM.seal(data, using: encryptionKey)
        guard let encrypted = sealedBox.combined else {
            throw SecurityError.encryptionFailed
        }
        return encrypted
        #else
        throw SecurityError.encryptionFailed
        #endif
    }
    
    /// 解密数据
    public func decrypt(_ encryptedData: Data) throws -> Data {
        #if canImport(CryptoKit)
        let sealedBox = try AES.GCM.SealedBox(combined: encryptedData)
        return try AES.GCM.open(sealedBox, using: encryptionKey)
        #else
        throw SecurityError.decryptionFailed
        #endif
    }
    
    /// 加密字符串
    public func encryptString(_ string: String) throws -> String {
        guard let data = string.data(using: .utf8) else {
            throw SecurityError.invalidData
        }
        let encrypted = try encrypt(data)
        return encrypted.base64EncodedString()
    }
    
    /// 解密字符串
    public func decryptString(_ encryptedString: String) throws -> String {
        guard let data = Data(base64Encoded: encryptedString) else {
            throw SecurityError.invalidData
        }
        let decrypted = try decrypt(data)
        guard let string = String(data: decrypted, encoding: .utf8) else {
            throw SecurityError.decryptionFailed
        }
        return string
    }
    #else
    private init() {}
    
    public func encrypt(_ data: Data) throws -> Data {
        throw SecurityError.encryptionFailed
    }
    
    public func decrypt(_ encryptedData: Data) throws -> Data {
        throw SecurityError.decryptionFailed
    }
    
    public func encryptString(_ string: String) throws -> String {
        throw SecurityError.encryptionFailed
    }
    
    public func decryptString(_ encryptedString: String) throws -> String {
        throw SecurityError.decryptionFailed
    }
    #endif
    
    // MARK: - 数据脱敏
    
    /// 脱敏显示（用于日志和调试）
    public static func maskSensitiveData(_ data: String) -> String {
        guard data.count > 4 else {
            return "****"
        }
        let prefix = String(data.prefix(2))
        let suffix = String(data.suffix(2))
        let middle = String(repeating: "*", count: min(data.count - 4, 8))
        return "\(prefix)\(middle)\(suffix)"
    }
    
    // MARK: - 证书锁定（可选，需要配置）
    
    /// 验证服务器证书（证书锁定）
    public func validateCertificate(_ challenge: URLAuthenticationChallenge) -> Bool {
        // 生产环境应实现证书锁定
        // 这里简化处理，实际应该验证证书指纹
        #if DEBUG
        return true // 开发环境允许所有证书
        #else
        // 生产环境验证逻辑
        guard challenge.protectionSpace.serverTrust != nil else {
            return false
        }
        
        // 这里应该验证证书是否匹配预期的证书
        // 示例：验证证书指纹
        return true // 简化实现
        #endif
    }
    
    // MARK: - 安全存储
    
    /// 安全存储敏感数据
    public func secureStore(_ value: String, forKey key: String) -> Bool {
        guard let encrypted = try? encryptString(value) else {
            return false
        }
        
        return KeychainHelper.shared.save(
            encrypted.data(using: .utf8) ?? Data(),
            service: Constants.Keychain.service,
            account: key
        )
    }
    
    /// 安全读取敏感数据
    public func secureRetrieve(forKey key: String) -> String? {
        guard let encrypted = KeychainHelper.shared.read(
            service: Constants.Keychain.service,
            account: key
        ) else {
            return nil
        }
        
        return try? decryptString(encrypted)
    }
}

// MARK: - 安全错误

enum SecurityError: LocalizedError {
    case encryptionFailed
    case decryptionFailed
    case invalidData
    case keyGenerationFailed
    
    var errorDescription: String? {
        switch self {
        case .encryptionFailed:
            return "数据加密失败"
        case .decryptionFailed:
            return "数据解密失败"
        case .invalidData:
            return "无效的数据格式"
        case .keyGenerationFailed:
            return "密钥生成失败"
        }
    }
}

// MARK: - KeychainHelper 扩展

extension KeychainHelper {
    func saveKeychainData(_ data: Data, service: String, account: String) -> Bool {
        let query = [
            kSecValueData: data,
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
        ] as CFDictionary
        
        SecItemDelete(query)
        
        let status = SecItemAdd(query, nil)
        return status == errSecSuccess
    }
}

