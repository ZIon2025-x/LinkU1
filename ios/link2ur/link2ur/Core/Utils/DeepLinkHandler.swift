import Foundation
import SwiftUI
import Combine

/// 深度链接处理器 - 企业级深度链接管理
public class DeepLinkHandler: ObservableObject {
    public static let shared = DeepLinkHandler()
    
    @Published public var currentLink: DeepLink?
    
    public enum DeepLink {
        case task(id: Int)
        case user(id: String)
        case post(id: Int)
        case expert(id: String)
        case forum(categoryId: Int?)
        case leaderboard(itemId: Int?)
        case unknown(String)
    }
    
    private init() {}
    
    /// 处理深度链接
    public func handle(_ url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let scheme = components.scheme,
              scheme == "linku" || scheme == "link2ur" else {
            currentLink = .unknown(url.absoluteString)
            return
        }
        
        let path = components.path
        let queryItems = components.queryItems ?? []
        
        switch path {
        case "/task":
            if let idString = queryItems.first(where: { $0.name == "id" })?.value,
               let id = Int(idString) {
                currentLink = .task(id: id)
            }
            
        case "/user":
            if let id = queryItems.first(where: { $0.name == "id" })?.value {
                currentLink = .user(id: id)
            }
            
        case "/post":
            if let idString = queryItems.first(where: { $0.name == "id" })?.value,
               let id = Int(idString) {
                currentLink = .post(id: id)
            }
            
        case "/expert":
            if let id = queryItems.first(where: { $0.name == "id" })?.value {
                currentLink = .expert(id: id)
            }
            
        case "/forum":
            if let categoryIdString = queryItems.first(where: { $0.name == "categoryId" })?.value,
               let categoryId = Int(categoryIdString) {
                currentLink = .forum(categoryId: categoryId)
            } else {
                currentLink = .forum(categoryId: nil)
            }
            
        case "/leaderboard":
            if let itemIdString = queryItems.first(where: { $0.name == "itemId" })?.value,
               let itemId = Int(itemIdString) {
                currentLink = .leaderboard(itemId: itemId)
            } else {
                currentLink = .leaderboard(itemId: nil)
            }
            
        default:
            currentLink = .unknown(path)
        }
    }
    
    /// 生成深度链接 URL
    public static func generateURL(for link: DeepLink) -> URL? {
        var components = URLComponents()
        components.scheme = "linku"
        
        switch link {
        case .task(let id):
            components.path = "/task"
            components.queryItems = [URLQueryItem(name: "id", value: "\(id)")]
            
        case .user(let id):
            components.path = "/user"
            components.queryItems = [URLQueryItem(name: "id", value: id)]
            
        case .post(let id):
            components.path = "/post"
            components.queryItems = [URLQueryItem(name: "id", value: "\(id)")]
            
        case .expert(let id):
            components.path = "/expert"
            components.queryItems = [URLQueryItem(name: "id", value: id)]
            
        case .forum(let categoryId):
            components.path = "/forum"
            if let categoryId = categoryId {
                components.queryItems = [URLQueryItem(name: "categoryId", value: "\(categoryId)")]
            }
            
        case .leaderboard(let itemId):
            components.path = "/leaderboard"
            if let itemId = itemId {
                components.queryItems = [URLQueryItem(name: "itemId", value: "\(itemId)")]
            }
            
        case .unknown:
            return nil
        }
        
        return components.url
    }
}

