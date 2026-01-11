import Foundation
import SwiftUI
import Combine

/// 深度链接处理器 - 企业级深度链接管理
public class DeepLinkHandler: ObservableObject {
    public static let shared = DeepLinkHandler()
    
    @Published public var currentLink: DeepLink?
    
    public enum DeepLink: Equatable {
        case task(id: Int)
        case user(id: String)
        case post(id: Int)
        case expert(id: String)
        case forum(categoryId: Int?)
        case leaderboard(itemId: Int?)
        case activity(id: Int)  // 活动详情
        case unknown(String)
    }
    
    private init() {}
    
    /// 处理深度链接（支持自定义协议和HTTP/HTTPS Universal Links）
    public func handle(_ url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let scheme = components.scheme else {
            currentLink = .unknown(url.absoluteString)
            return
        }
        
        // 处理自定义协议（linku:// 或 link2ur://）
        if scheme == "linku" || scheme == "link2ur" {
            handleCustomScheme(components: components)
            return
        }
        
        // 处理HTTP/HTTPS Universal Links（www.link2ur.com）
        if scheme == "http" || scheme == "https" {
            handleUniversalLink(url: url, components: components)
            return
        }
        
        currentLink = .unknown(url.absoluteString)
    }
    
    /// 处理自定义协议链接
    private func handleCustomScheme(components: URLComponents) {
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
            
        case "/activity":
            if let idString = queryItems.first(where: { $0.name == "id" })?.value,
               let id = Int(idString) {
                currentLink = .activity(id: id)
            }
            
        default:
            currentLink = .unknown(path)
        }
    }
    
    /// 处理Universal Links（HTTP/HTTPS）
    private func handleUniversalLink(url: URL, components: URLComponents) {
        let host = components.host ?? ""
        let path = components.path
        
        // 只处理 link2ur.com 域名的链接
        guard host.contains("link2ur.com") else {
            currentLink = .unknown(url.absoluteString)
            return
        }
        
        // 解析路径：/zh/activities/{id} 或 /en/activities/{id} 等
        if path.contains("/activities/") {
            // 提取活动ID：/zh/activities/123 -> 123
            let pathComponents = path.components(separatedBy: "/")
            if let activitiesIndex = pathComponents.firstIndex(where: { $0 == "activities" }),
               activitiesIndex + 1 < pathComponents.count,
               let activityId = Int(pathComponents[activitiesIndex + 1]) {
                currentLink = .activity(id: activityId)
                return
            }
        }
        
        // 解析任务路径：/zh/tasks/{id} 或 /en/tasks/{id} 等
        if path.contains("/tasks/") {
            let pathComponents = path.components(separatedBy: "/")
            if let tasksIndex = pathComponents.firstIndex(where: { $0 == "tasks" }),
               tasksIndex + 1 < pathComponents.count,
               let taskId = Int(pathComponents[tasksIndex + 1]) {
                currentLink = .task(id: taskId)
                return
            }
        }
        
        // 解析论坛帖子路径：/zh/forum/post/{id} 或 /en/forum/post/{id} 等
        if path.contains("/forum/post/") {
            let pathComponents = path.components(separatedBy: "/")
            if let postIndex = pathComponents.firstIndex(where: { $0 == "post" }),
               postIndex + 1 < pathComponents.count,
               let postId = Int(pathComponents[postIndex + 1]) {
                currentLink = .post(id: postId)
                return
            }
        }
        
        currentLink = .unknown(path)
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
            
        case .activity(let id):
            components.path = "/activity"
            components.queryItems = [URLQueryItem(name: "id", value: "\(id)")]
            
        case .unknown:
            return nil
        }
        
        return components.url
    }
}

