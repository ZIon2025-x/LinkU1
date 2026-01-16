import Foundation

// 类型别名以避免与 Task 模型冲突
public typealias AsyncTask = _Concurrency.Task

public struct Constants {
    struct API {
        // 基础 URL，建议使用 https
        #if DEBUG
        // DEBUG 模式：可以修改为实际的后端地址
        // 选项1: 使用生产环境（推荐用于真机测试）
        static let baseURL = "https://api.link2ur.com"
        static let wsURL = "wss://api.link2ur.com"
        
        // 选项2: 使用本地开发服务器（仅适用于模拟器或同一网络的设备）
        // 注意：真机测试时，将 localhost 替换为你的 Mac IP 地址，例如：
        // static let baseURL = "http://192.168.1.100:8000"
        // static let wsURL = "ws://192.168.1.100:8000"
        #else
        static let baseURL = "https://api.link2ur.com" // 生产环境地址
        static let wsURL = "wss://api.link2ur.com"
        #endif
        
        static let timeoutInterval: TimeInterval = 30.0
    }
    
    struct Frontend {
        // 前端服务器 URL（用于静态资源，如图片、logo 等）
        #if DEBUG
        static let baseURL = "https://www.link2ur.com"
        #else
        static let baseURL = "https://www.link2ur.com" // 生产环境地址
        #endif
    }
    
    public struct Keychain {
        public static let service = "com.linku.app"
        public static let accessTokenKey = "accessToken"
        public static let refreshTokenKey = "refreshToken"
    }
    
    struct UI {
        static let cornerRadius: CGFloat = 12.0
        static let padding: CGFloat = 16.0
    }
    
    struct Stripe {
        // Stripe Publishable Key
        // 
        // 配置方式（推荐顺序）：
        // 1. 通过 Xcode Scheme 配置（推荐）：
        //    - Product → Scheme → Edit Scheme...
        //    - Run → Arguments → Environment Variables
        //    - 添加：Name = STRIPE_PUBLISHABLE_KEY, Value = pk_test_...
        //
        // 2. 直接修改下面的默认值（快速测试，不推荐用于生产）
        //
        // 详细说明请查看：ios/配置Stripe密钥指南.md
        static let publishableKey: String = {
            // 优先从环境变量读取
            if let key = ProcessInfo.processInfo.environment["STRIPE_PUBLISHABLE_KEY"], !key.isEmpty {
                return key
            }
            
            // 如果没有环境变量，使用默认值
            // ⚠️ 请通过 Xcode Scheme 配置环境变量，或在这里填入你的密钥
            #if DEBUG
            return "pk_test_..." // 👈 测试环境：在这里填入你的测试密钥，或通过环境变量配置
            #else
            return "pk_live_..." // 👈 生产环境：在这里填入你的生产密钥，或通过环境变量配置
            #endif
        }()
        
        // Apple Pay Merchant ID
        // 
        // 配置方式（推荐顺序）：
        // 1. 通过 Xcode Scheme 配置（推荐）：
        //    - Product → Scheme → Edit Scheme...
        //    - Run → Arguments → Environment Variables
        //    - 添加：Name = APPLE_PAY_MERCHANT_ID, Value = merchant.com.link2ur
        //
        // 2. 直接修改下面的默认值（快速测试，不推荐用于生产）
        //
        // 详细说明请查看：stripe-sample-code/ios/APPLE_PAY_SETUP.md
        static let applePayMerchantIdentifier: String? = {
            // 优先从环境变量读取
            if let merchantId = ProcessInfo.processInfo.environment["APPLE_PAY_MERCHANT_ID"], !merchantId.isEmpty {
                return merchantId
            }
            
            // 如果没有环境变量，返回 nil（Apple Pay 将不可用）
            // ⚠️ 请通过 Xcode Scheme 配置环境变量，或在这里填入你的 Merchant ID
            #if DEBUG
            return nil // 👈 测试环境：在这里填入你的 Merchant ID，或通过环境变量配置
            #else
            return nil // 👈 生产环境：在这里填入你的 Merchant ID，或通过环境变量配置
            #endif
        }()
        
        // Stripe Connect Onboarding 自定义 URL
        // 用于在 Stripe Connect 账户入驻流程中显示自定义的服务条款和隐私政策
        struct ConnectOnboarding {
            // Full Terms of Service URL（完整服务条款）
            // 用于商户账户（Full service agreement）
            static let fullTermsOfServiceURL = URL(string: "\(Frontend.baseURL)/terms")!
            
            // Recipient Terms of Service URL（收款方服务条款）
            // 用于收款账户（Recipient service agreement）
            // 注意：如果平台没有单独的收款方条款，可以使用与 Full Terms 相同的 URL
            static let recipientTermsOfServiceURL = URL(string: "\(Frontend.baseURL)/terms")!
            
            // Privacy Policy URL（隐私政策）
            static let privacyPolicyURL = URL(string: "\(Frontend.baseURL)/privacy")!
        }
    }
}

// MARK: - URL 工具函数
extension String {
    /// 将相对路径转换为完整的图片 URL
    /// 静态资源（如头像、logo）应该通过前端服务器访问，而不是 API 服务器
    /// 注意：本地头像路径（如 /static/avatar*.png）应该使用 AvatarView 而不是此方法
    func toImageURL() -> URL? {
        // 如果已经是完整 URL，直接返回
        if self.hasPrefix("http://") || self.hasPrefix("https://") {
            return URL(string: self)
        }
        
        // 检查是否是本地头像路径（/static/avatar*.png），这些应该使用本地资源
        if self.hasPrefix("/static/") {
            let fileName = String(self.dropFirst(8)) // 去掉 "/static/" 前缀
            let nameWithoutExt = fileName.replacingOccurrences(of: ".png", with: "").replacingOccurrences(of: ".jpg", with: "")
            
            // 如果是本地头像（avatar1-5, any, service），返回 nil，表示应该使用本地资源
            if nameWithoutExt == "any" || nameWithoutExt == "service" {
                return nil
            } else if nameWithoutExt.hasPrefix("avatar") {
                let indexStr = String(nameWithoutExt.dropFirst(6)) // 去掉 "avatar" 前缀
                if let index = Int(indexStr), index >= 1 && index <= 5 {
                    return nil // 本地头像，返回 nil
                }
            }
        }
        
        // 如果是相对路径，使用前端服务器 URL（静态资源在前端 public/static 文件夹中）
        let baseURL = Constants.Frontend.baseURL
        let imagePath = self.hasPrefix("/") ? self : "/\(self)"
        let fullURL = "\(baseURL)\(imagePath)"
        
        return URL(string: fullURL)
    }
    
    /// 检查是否是有效的图片 URL
    var isValidImageURL: Bool {
        guard let url = toImageURL() else { return false }
        return url.scheme != nil && url.host != nil
    }
    
    /// 将日期字符串转换为友好显示格式（如：3分钟前，昨天，10月20日）
    func toDisplayDate() -> String {
        return DateFormatterHelper.shared.formatTime(self)
    }
    
    /// 将日期字符串转换为完整显示格式（如：2025-10-20 14:30）
    func toFullDate() -> String {
        return DateFormatterHelper.shared.formatFullTime(self)
    }
}

