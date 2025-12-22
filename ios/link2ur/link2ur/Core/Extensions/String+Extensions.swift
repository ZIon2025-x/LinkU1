import Foundation
#if canImport(CryptoKit)
import CryptoKit
#endif
import CommonCrypto

/// String 扩展 - 提供企业级字符串处理工具

extension String {
    
    // MARK: - 验证
    
    /// 验证邮箱格式
    var isValidEmail: Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: self)
    }
    
    /// 验证手机号格式（英国）
    var isValidUKPhone: Bool {
        let phoneRegex = "^\\+44[0-9]{10}$|^0[0-9]{10}$"
        let phonePredicate = NSPredicate(format: "SELF MATCHES %@", phoneRegex)
        return phonePredicate.evaluate(with: self)
    }
    
    /// 验证密码强度（至少8位，包含字母和数字）
    var isValidPassword: Bool {
        return count >= 8 && 
               rangeOfCharacter(from: CharacterSet.letters) != nil &&
               rangeOfCharacter(from: CharacterSet.decimalDigits) != nil
    }
    
    /// 是否为空或仅包含空白字符
    var isBlank: Bool {
        return trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    /// 是否不为空
    var isNotBlank: Bool {
        return !isBlank
    }
    
    // MARK: - 转换
    
    /// 转换为 URL（安全）
    var safeURL: URL? {
        // 处理相对路径
        if hasPrefix("/") {
            return URL(string: self)
        }
        // 处理完整 URL
        if contains("://") {
            return URL(string: self)
        }
        // 尝试添加 https://
        return URL(string: "https://\(self)")
    }
    
    /// 转换为 Int（安全）
    var safeInt: Int? {
        return Int(self)
    }
    
    /// 转换为 Double（安全）
    var safeDouble: Double? {
        return Double(self)
    }
    
    /// 转换为 Bool（安全）
    var safeBool: Bool? {
        let lowercased = lowercased()
        if lowercased == "true" || lowercased == "1" || lowercased == "yes" {
            return true
        }
        if lowercased == "false" || lowercased == "0" || lowercased == "no" {
            return false
        }
        return nil
    }
    
    // MARK: - 格式化
    
    /// 截断到指定长度
    func truncated(to length: Int, trailing: String = "...") -> String {
        guard count > length else { return self }
        return String(prefix(length)) + trailing
    }
    
    /// 移除 HTML 标签
    var removingHTMLTags: String {
        return self.replacingOccurrences(
            of: "<[^>]+>",
            with: "",
            options: .regularExpression,
            range: nil
        )
    }
    
    /// 移除空白字符
    var removingWhitespace: String {
        return components(separatedBy: .whitespacesAndNewlines)
            .joined()
    }
    
    /// 首字母大写
    var capitalizedFirst: String {
        guard !isEmpty else { return self }
        return prefix(1).uppercased() + dropFirst()
    }
    
    /// 每个单词首字母大写
    var capitalizedWords: String {
        return components(separatedBy: " ")
            .map { $0.capitalizedFirst }
            .joined(separator: " ")
    }
    
    // MARK: - 加密/哈希
    
    /// SHA256 哈希
    var sha256: String {
        guard let data = self.data(using: .utf8) else { return self }
        #if canImport(CryptoKit)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
        #else
        // 如果没有 CryptoKit，使用 CommonCrypto 的 SHA256
        var digest = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        _ = data.withUnsafeBytes {
            CC_SHA256($0.baseAddress, CC_LONG(data.count), &digest)
        }
        return digest.map { String(format: "%02x", $0) }.joined()
        #endif
    }
    
    // MARK: - 本地化
    
    /// 本地化字符串
    var localized: String {
        return NSLocalizedString(self, comment: "")
    }
    
    /// 本地化字符串（带参数）
    func localized(with arguments: CVarArg...) -> String {
        return String(format: self.localized, arguments: arguments)
    }
    
    // MARK: - 正则表达式
    
    /// 匹配正则表达式
    func matches(_ pattern: String) -> Bool {
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return false
        }
        let range = NSRange(location: 0, length: self.utf16.count)
        return regex.firstMatch(in: self, options: [], range: range) != nil
    }
    
    /// 提取匹配的字符串
    func extractMatches(_ pattern: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return []
        }
        let range = NSRange(location: 0, length: self.utf16.count)
        let matches = regex.matches(in: self, options: [], range: range)
        return matches.compactMap { match in
            guard let range = Range(match.range, in: self) else { return nil }
            return String(self[range])
        }
    }
    
    // MARK: - 位置处理
    
    /// 获取模糊化的位置信息（只显示城市名称，保护用户隐私）
    /// 例如："B16 9NS, Birmingham, UK" -> "Birmingham, UK"
    /// 例如："123 Main Street, London, UK" -> "London, UK"
    var obfuscatedLocation: String {
        // 如果是 "Online" 或为空，直接返回
        let trimmed = self.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || trimmed.lowercased() == "online" {
            return trimmed
        }
        
        // 按逗号分隔
        let components = trimmed.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        
        // 如果只有一个部分，直接返回
        if components.count <= 1 {
            return trimmed
        }
        
        // 邮编格式检测（英国邮编格式：字母数字混合，如 B16 9NS, SW1A 1AA, B15 3EN）
        let postcodePattern = "^[A-Z]{1,2}[0-9][0-9A-Z]?\\s*[0-9][A-Z]{2}$"
        let usPostcodePattern = "^[0-9]{5}(-[0-9]{4})?$"
        let isPostcode: (String) -> Bool = { component in
            component.matches(postcodePattern) || component.matches(usPostcodePattern)
        }
        
        // 检测第一个部分是否包含门牌号（以数字开头）
        let firstComponent = components[0]
        let hasStreetNumber = firstComponent.matches("^[0-9]+\\s")
        
        // 过滤掉邮编和街道地址，只保留城市相关的部分
        var filteredComponents = components
        
        // 移除第一个部分（如果是街道地址）
        if hasStreetNumber && filteredComponents.count > 1 {
            filteredComponents.removeFirst()
        }
        
        // 移除所有邮编
        filteredComponents = filteredComponents.filter { !isPostcode($0) }
        
        // 返回最后两个部分（通常是城市和国家，或区域和城市）
        if filteredComponents.count >= 2 {
            let lastTwo = Array(filteredComponents.suffix(2))
            return lastTwo.joined(separator: ", ")
        } else if filteredComponents.count == 1 {
            // 只有一个部分，直接返回
            return filteredComponents[0]
        }
        
        // 如果过滤后没有内容，返回原始内容的最后两个非邮编部分
        var validComponents: [String] = []
        for component in components.reversed() {
            if !isPostcode(component) && !component.matches("^[0-9]+\\s") {
                validComponents.insert(component, at: 0)
                if validComponents.count >= 2 {
                    break
                }
            }
        }
        
        if validComponents.count >= 2 {
            return validComponents.suffix(2).joined(separator: ", ")
        } else if validComponents.count == 1 {
            return validComponents[0]
        }
        
        // 最后的回退：返回原始内容的最后两个部分
        if components.count >= 2 {
            return components.suffix(2).joined(separator: ", ")
        }
        
        return trimmed
    }
}


extension String {
    /// MD5 哈希（已弃用，使用 SHA256 替代）
    /// 注意：此方法仅用于非安全用途（如缓存文件名）
    /// 为了保持向后兼容，此方法现在使用 SHA256 实现
    var md5Hash: String {
        // 使用 SHA256 替代 MD5（对于缓存文件名等非安全用途，SHA256 同样适用）
        guard let data = self.data(using: .utf8) else { return self }
        #if canImport(CryptoKit)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
        #else
        // 如果没有 CryptoKit，使用 CommonCrypto 的 SHA256
        var digest = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        _ = data.withUnsafeBytes {
            CC_SHA256($0.baseAddress, CC_LONG(data.count), &digest)
        }
        return digest.map { String(format: "%02x", $0) }.joined()
        #endif
    }
}

