import Foundation

struct Constants {
    struct API {
        // 基础 URL，建议使用 https
        #if DEBUG
        static let baseURL = "http://localhost:8000" // 本地调试地址
        static let wsURL = "ws://localhost:8000"
        #else
        static let baseURL = "https://api.link2ur.com" // 生产环境地址
        static let wsURL = "wss://api.link2ur.com"
        #endif
        
        static let timeoutInterval: TimeInterval = 30.0
    }
    
    struct Keychain {
        static let service = "com.linku.app"
        static let accessTokenKey = "accessToken"
        static let refreshTokenKey = "refreshToken"
    }
    
    struct UI {
        static let cornerRadius: CGFloat = 12.0
        static let padding: CGFloat = 16.0
    }
}

