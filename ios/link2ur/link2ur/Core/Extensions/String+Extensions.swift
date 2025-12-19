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
        return self.md5Hash
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
}


extension String {
    /// MD5 哈希（使用 CommonCrypto）
    var md5Hash: String {
        guard let data = self.data(using: .utf8) else { return self }
        var digest = [UInt8](repeating: 0, count: Int(CC_MD5_DIGEST_LENGTH))
        _ = data.withUnsafeBytes {
            CC_MD5($0.baseAddress, CC_LONG(data.count), &digest)
        }
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

