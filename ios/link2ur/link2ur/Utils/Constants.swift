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
        public static let service = "com.link2ur.app"
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
        // publishable key 是公开的客户端密钥，可以安全地嵌入 app 中
        // 如需在开发时覆盖（例如使用测试密钥），可通过 Xcode Scheme 环境变量：
        //   Product → Scheme → Edit Scheme → Run → Environment Variables
        //   添加：STRIPE_PUBLISHABLE_KEY = pk_test_xxx
        //
        // ⚠️ 注意：ProcessInfo.processInfo.environment 仅在 Xcode 启动时生效，
        //    从设备主屏幕直接启动 app 时环境变量不可用，因此必须有正确的硬编码默认值！
        static let publishableKey: String = {
            // 开发时可通过 Xcode Scheme 环境变量覆盖
            if let key = ProcessInfo.processInfo.environment["STRIPE_PUBLISHABLE_KEY"], !key.isEmpty {
                return key
            }
            // 默认使用生产环境 publishable key（公开密钥，安全嵌入客户端）
            // 从 Stripe Dashboard → Developers → API keys 获取：https://dashboard.stripe.com/apikeys
            return "pk_live_51SePW15vvXfvzqMhSEXu7QnduEi7axoPiUMc9gNiV8KFAa82b6rFrrbOFW3gmTiaOETlI3gA0SsAz18SSokFKGLx00bALMvCAg"
        }()
        
        // Apple Pay Merchant ID
        //
        // 与 publishable key 同理，必须硬编码默认值，不能仅依赖环境变量
        // 开发时可通过 Xcode Scheme 环境变量 APPLE_PAY_MERCHANT_ID 覆盖
        static let applePayMerchantIdentifier: String? = {
            // 开发时可通过 Xcode Scheme 环境变量覆盖
            if let merchantId = ProcessInfo.processInfo.environment["APPLE_PAY_MERCHANT_ID"], !merchantId.isEmpty {
                return merchantId
            }
            // 默认使用生产环境 Merchant ID
            return "merchant.com.link2ur"
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
    /// 
    /// 支持以下格式：
    /// - 完整 URL（http:// 或 https://）：直接返回
    /// - R2 存储相对路径（public/...、flea_market/...）：转换为前端服务器 URL（Vercel 会代理到 R2）
    /// - 旧格式路径（images/...）：转换为 /uploads/public/images/...
    /// - 其他相对路径：使用前端服务器 URL
    func toImageURL() -> URL? {
        guard !self.isEmpty else {
            Logger.warning("图片 URL 为空", category: .network)
            return nil
        }
        
        // 如果已经是完整 URL，直接返回
        if self.hasPrefix("http://") || self.hasPrefix("https://") {
            if let url = URL(string: self) {
                return url
            } else {
                Logger.warning("无效的完整 URL: \(self)", category: .network)
                return nil
            }
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
        
        // 如果是后端存储相对路径（无前导 /），需补上 /uploads/ 前缀
        // 格式：public/images/...、flea_market/...
        // 注意：这些路径会通过前端服务器（Vercel）代理到后端/R2
        if self.hasPrefix("public/") || self.hasPrefix("flea_market/") {
            let fullURL = "\(Constants.Frontend.baseURL)/uploads/\(self)"
            if let url = URL(string: fullURL) {
                Logger.debug("转换相对路径为完整 URL: \(self) -> \(fullURL)", category: .network)
                return url
            } else {
                Logger.warning("无法构建 URL: \(fullURL)", category: .network)
                return nil
            }
        }
        
        // 旧格式 images/...（如 images/service_images/、images/leaderboard_covers/）
        // 实际文件在 public/images/ 下，需补为 /uploads/public/images/...
        if self.hasPrefix("images/") {
            let fullURL = "\(Constants.Frontend.baseURL)/uploads/public/\(self)"
            if let url = URL(string: fullURL) {
                Logger.debug("转换旧格式路径为完整 URL: \(self) -> \(fullURL)", category: .network)
                return url
            } else {
                Logger.warning("无法构建 URL: \(fullURL)", category: .network)
                return nil
            }
        }
        
        // 后端可能返回「主机 + 路径」无协议格式（如 cdn.link2ur.com/public/images/...）
        // 勿当作相对路径拼接 baseURL，否则会变成 https://www.link2ur.com/cdn.link2ur.com/...
        if self.contains("/"), !self.hasPrefix("/"), !self.hasPrefix(".") {
            let firstSegment = String(self.prefix(upTo: self.firstIndex(of: "/")!))
            if firstSegment.contains(".") {
                let fullURL = "https://\(self)"
                if let url = URL(string: fullURL) {
                    Logger.debug("转换相对路径为完整 URL: \(self) -> \(fullURL)", category: .network)
                    return url
                }
            }
        }
        
        // 如果是相对路径，使用前端服务器 URL（静态资源在前端 public/static 文件夹中）
        let baseURL = Constants.Frontend.baseURL
        let imagePath = self.hasPrefix("/") ? self : "/\(self)"
        let fullURL = "\(baseURL)\(imagePath)"
        
        if let url = URL(string: fullURL) {
            Logger.debug("转换相对路径为完整 URL: \(self) -> \(fullURL)", category: .network)
            return url
        } else {
            Logger.warning("无法构建 URL: \(fullURL)", category: .network)
            return nil
        }
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

