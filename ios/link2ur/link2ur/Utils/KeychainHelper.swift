import Foundation
import Security

public class KeychainHelper {
    public static let shared = KeychainHelper()
    
    private init() {}
    
    public func save(_ data: Data, service: String, account: String) -> Bool {
        // ⚠️ 修复：设置 Keychain accessibility 属性，确保数据在设备首次解锁后可以访问
        // 使用 kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly 确保：
        // 1. 设备首次解锁后可以访问（即使应用在后台）
        // 2. 仅限当前设备（不会同步到 iCloud Keychain）
        // 3. 构建/调试时数据不会丢失
        let query: [String: Any] = [
            kSecValueData as String: data,
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        
        // 先删除旧数据
        SecItemDelete(query as CFDictionary)
        
        // 添加新数据
        let status = SecItemAdd(query as CFDictionary, nil)
        
        if status != errSecSuccess {
            return false
        }
        return true
    }
    
    public func read(service: String, account: String) -> String? {
        let query = [
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecClass: kSecClassGenericPassword,
            kSecReturnData: true
        ] as CFDictionary
        
        var result: AnyObject?
        SecItemCopyMatching(query, &result)
        
        if let data = result as? Data {
            return String(data: data, encoding: .utf8)
        }
        
        return nil
    }
    
    public func delete(service: String, account: String) -> Bool {
        let query = [
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecClass: kSecClassGenericPassword,
        ] as CFDictionary
        
        let status = SecItemDelete(query)
        return status == errSecSuccess || status == errSecItemNotFound
    }
    
    // 辅助方法：直接保存字符串
    public func save(_ string: String, service: String, account: String) {
        if let data = string.data(using: .utf8) {
            _ = save(data, service: service, account: account)
        }
    }
}

