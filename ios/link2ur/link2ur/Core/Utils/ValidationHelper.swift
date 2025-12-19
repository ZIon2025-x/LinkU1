import Foundation

/// 企业级验证工具
public struct ValidationHelper {
    
    // MARK: - 邮箱验证
    
    /// 验证邮箱格式
    public static func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }
    
    // MARK: - 手机号验证
    
    /// 验证英国手机号
    public static func isValidUKPhone(_ phone: String) -> Bool {
        let phoneRegex = "^\\+44[0-9]{10}$|^0[0-9]{10}$"
        let phonePredicate = NSPredicate(format: "SELF MATCHES %@", phoneRegex)
        return phonePredicate.evaluate(with: phone)
    }
    
    /// 验证国际手机号（通用格式）
    public static func isValidInternationalPhone(_ phone: String) -> Bool {
        let phoneRegex = "^\\+[1-9][0-9]{1,14}$"
        let phonePredicate = NSPredicate(format: "SELF MATCHES %@", phoneRegex)
        return phonePredicate.evaluate(with: phone)
    }
    
    // MARK: - 密码验证
    
    /// 验证密码强度
    public static func validatePassword(
        _ password: String,
        minLength: Int = 8,
        requireUppercase: Bool = true,
        requireLowercase: Bool = true,
        requireDigit: Bool = true,
        requireSpecialChar: Bool = false
    ) -> PasswordValidationResult {
        var errors: [PasswordError] = []
        
        if password.count < minLength {
            errors.append(.tooShort(minLength: minLength))
        }
        
        if requireUppercase && password.rangeOfCharacter(from: CharacterSet.uppercaseLetters) == nil {
            errors.append(.missingUppercase)
        }
        
        if requireLowercase && password.rangeOfCharacter(from: CharacterSet.lowercaseLetters) == nil {
            errors.append(.missingLowercase)
        }
        
        if requireDigit && password.rangeOfCharacter(from: CharacterSet.decimalDigits) == nil {
            errors.append(.missingDigit)
        }
        
        if requireSpecialChar && password.rangeOfCharacter(from: CharacterSet(charactersIn: "!@#$%^&*()_+-=[]{}|;:,.<>?")) == nil {
            errors.append(.missingSpecialChar)
        }
        
        return PasswordValidationResult(isValid: errors.isEmpty, errors: errors)
    }
    
    // MARK: - URL 验证
    
    /// 验证 URL 格式
    public static func isValidURL(_ urlString: String) -> Bool {
        guard let url = URL(string: urlString),
              let scheme = url.scheme,
              ["http", "https"].contains(scheme.lowercased()) else {
            return false
        }
        return true
    }
    
    // MARK: - 数字验证
    
    /// 验证是否为有效数字
    public static func isValidNumber(_ string: String) -> Bool {
        return Double(string) != nil
    }
    
    /// 验证是否为有效整数
    public static func isValidInteger(_ string: String) -> Bool {
        return Int(string) != nil
    }
    
    // MARK: - 日期验证
    
    /// 验证日期格式
    public static func isValidDate(_ dateString: String, format: String = "yyyy-MM-dd") -> Bool {
        let formatter = DateFormatter()
        formatter.dateFormat = format
        return formatter.date(from: dateString) != nil
    }
    
    /// 验证年龄范围
    public static func isValidAge(_ age: Int, min: Int = 0, max: Int = 150) -> Bool {
        return age >= min && age <= max
    }
}

// MARK: - 密码验证结果

public struct PasswordValidationResult {
    public let isValid: Bool
    public let errors: [PasswordError]
    
    public var errorMessage: String {
        return errors.map { $0.localizedDescription }.joined(separator: "\n")
    }
}

public enum PasswordError: LocalizedError {
    case tooShort(minLength: Int)
    case missingUppercase
    case missingLowercase
    case missingDigit
    case missingSpecialChar
    
    public var errorDescription: String? {
        switch self {
        case .tooShort(let minLength):
            return "密码长度至少需要 \(minLength) 个字符"
        case .missingUppercase:
            return "密码必须包含至少一个大写字母"
        case .missingLowercase:
            return "密码必须包含至少一个小写字母"
        case .missingDigit:
            return "密码必须包含至少一个数字"
        case .missingSpecialChar:
            return "密码必须包含至少一个特殊字符"
        }
    }
}

