import UIKit
import SwiftUI

/// 分享平台枚举
public enum SharePlatform: String, CaseIterable {
    case wechat = "wechat"           // 微信好友
    case wechatMoments = "wechatMoments" // 微信朋友圈
    case qq = "qq"                   // QQ好友
    case qzone = "qzone"             // QQ空间
    case instagram = "instagram"     // Instagram
    case facebook = "facebook"        // Facebook
    case twitter = "twitter"          // X (formerly Twitter)
    case weibo = "weibo"             // 微博
    case sms = "sms"                 // 短信
    case copyLink = "copyLink"       // 复制链接
    case generateImage = "generateImage" // 生成分享图
    case more = "more"               // 更多（系统分享）
    
    var displayName: String {
        switch self {
        case .wechat: return LocalizationKey.shareWechat.localized
        case .wechatMoments: return LocalizationKey.shareWechatMoments.localized
        case .qq: return LocalizationKey.shareQQ.localized
        case .qzone: return LocalizationKey.shareQZone.localized
        case .instagram: return "Instagram"
        case .facebook: return "Facebook"
        case .twitter: return "X"
        case .weibo: return LocalizationKey.shareWeibo.localized
        case .sms: return LocalizationKey.shareSMS.localized
        case .copyLink: return LocalizationKey.shareCopyLink.localized
        case .generateImage: return LocalizationKey.shareGenerateImage.localized
        case .more: return LocalizationKey.commonMore.localized
        }
    }
    
    var iconName: String {
        switch self {
        case .wechat: return "wechat"
        case .wechatMoments: return "wechat.moments"
        case .qq: return "qq"
        case .qzone: return "qzone"
        case .instagram: return "instagram"
        case .facebook: return "facebook"
        case .twitter: return "twitter"
        case .weibo: return "weibo"
        case .sms: return "message"
        case .copyLink: return "link"
        case .generateImage: return "photo"
        case .more: return "square.and.arrow.up"
        }
    }
    
    var color: Color {
        switch self {
        case .wechat, .wechatMoments: return Color(red: 0.2, green: 0.8, blue: 0.2) // 微信绿
        case .qq, .qzone: return Color(red: 0.0, green: 0.6, blue: 1.0) // QQ蓝
        case .instagram: return Color(red: 0.8, green: 0.2, blue: 0.6) // Instagram紫
        case .facebook: return Color(red: 0.2, green: 0.4, blue: 0.8) // Facebook蓝
        case .twitter: return Color(red: 0.2, green: 0.6, blue: 1.0) // Twitter蓝
        case .weibo: return Color(red: 1.0, green: 0.3, blue: 0.2) // 微博红
        case .sms: return Color(red: 0.0, green: 0.7, blue: 0.3) // 短信绿
        case .copyLink: return Color.gray
        case .generateImage: return Color(red: 0.9, green: 0.5, blue: 0.1) // 橙色
        case .more: return Color.blue
        }
    }
}

/// 自定义分享助手
public class CustomShareHelper {
    
    /// 检测应用是否已安装
    public static func isAppInstalled(_ platform: SharePlatform) -> Bool {
        // 对于系统功能（短信、复制链接、生成图片、更多），总是返回 true
        if platform == .sms || platform == .copyLink || platform == .generateImage || platform == .more {
            return true
        }
        
        guard let urlScheme = getURLScheme(for: platform) else {
            return false
        }
        
        guard let url = URL(string: urlScheme) else {
            return false
        }
        
        // 注意：如果 Info.plist 中没有配置 LSApplicationQueriesSchemes，
        // canOpenURL 可能会返回 false，即使应用已安装
        // 所以这里即使返回 false，我们也会显示该平台，只是标记为未安装状态
        return UIApplication.shared.canOpenURL(url)
    }
    
    /// 获取 URL Scheme
    private static func getURLScheme(for platform: SharePlatform) -> String? {
        switch platform {
        case .wechat:
            return "weixin://"
        case .wechatMoments:
            return "weixin://"
        case .qq:
            return "mqqapi://"
        case .qzone:
            return "mqqapi://"
        case .instagram:
            return "instagram://"
        case .facebook:
            return "fb://"
        case .twitter:
            return "twitter://"
        case .weibo:
            return "weibosdk://"
        case .sms:
            return "sms://"
        case .copyLink, .generateImage, .more:
            return nil
        }
    }
    
    /// 分享到指定平台
    /// - Parameters:
    ///   - platform: 分享平台
    ///   - title: 标题
    ///   - description: 描述
    ///   - url: 分享链接
    ///   - image: 分享图片（可选）
    public static func shareToPlatform(
        _ platform: SharePlatform,
        title: String,
        description: String,
        url: URL,
        image: UIImage? = nil
    ) {
        switch platform {
        case .wechat, .wechatMoments:
            shareToWeChat(platform: platform, title: title, description: description, url: url, image: image)
        case .qq, .qzone:
            shareToQQ(platform: platform, title: title, description: description, url: url, image: image)
        case .instagram:
            shareToInstagram(image: image, caption: "\(title)\n\n\(description)\n\n\(url.absoluteString)")
        case .facebook:
            shareToFacebook(title: title, description: description, url: url)
        case .twitter:
            shareToTwitter(text: "\(title)\n\n\(description)", url: url)
        case .weibo:
            shareToWeibo(title: title, description: description, url: url, image: image)
        case .sms:
            shareToSMS(title: title, description: description, url: url)
        case .copyLink:
            copyToClipboard(title: title, description: description, url: url)
        case .generateImage:
            // 生成分享图功能在 CustomSharePanel 中处理
            break
        case .more:
            // 使用系统分享面板
            shareWithSystemSheet(title: title, description: description, url: url, image: image)
        }
    }
    
    // MARK: - 微信分享
    
    private static func shareToWeChat(
        platform: SharePlatform,
        title: String,
        description: String,
        url: URL,
        image: UIImage?
    ) {
        // 微信分享：由于微信 SDK 需要注册 AppID，这里使用系统分享面板
        // 系统分享面板会自动识别微信，并提供微信和朋友圈选项
        // 这是最可靠的方式，确保分享内容正确显示
        
        // 构建分享内容
        var shareItems: [Any] = []
        
        // 1. 图片（如果有）
        if let image = image {
            shareItems.append(image)
        }
        
        // 2. URL（微信会抓取网页的 meta 标签）
        shareItems.append(url)
        
        // 3. 文本（作为后备）
        let shareText = "\(title)\n\n\(description)\n\n\(url.absoluteString)"
        shareItems.append(shareText)
        
        // 使用系统分享面板，微信会自动出现在选项中
        ShareHelper.presentShareSheet(items: shareItems)
    }
    
    // MARK: - QQ分享
    
    private static func shareToQQ(
        platform: SharePlatform,
        title: String,
        description: String,
        url: URL,
        image: UIImage?
    ) {
        // QQ分享 URL Scheme
        // 格式：mqqapi://share/to_fri?file_type=news&title={title}&description={description}&url={url}
        
        var components = URLComponents()
        components.scheme = "mqqapi"
        
        if platform == .qzone {
            // QQ空间
            components.host = "share"
            components.path = "/to_qzone"
        } else {
            // QQ好友
            components.host = "share"
            components.path = "/to_fri"
        }
        
        components.queryItems = [
            URLQueryItem(name: "file_type", value: "news"),
            URLQueryItem(name: "title", value: title),
            URLQueryItem(name: "description", value: description),
            URLQueryItem(name: "url", value: url.absoluteString)
        ]
        
        if let shareURL = components.url {
            if UIApplication.shared.canOpenURL(shareURL) {
                UIApplication.shared.open(shareURL) { success in
                    if success {
                        HapticFeedback.success()
                    } else {
                        HapticFeedback.error()
                    }
                }
            } else {
                // QQ未安装，使用系统分享
                shareWithSystemSheet(title: title, description: description, url: url, image: image)
            }
        }
    }
    
    // MARK: - Instagram分享
    
    private static func shareToInstagram(image: UIImage?, caption: String) {
        // Instagram 分享图片需要使用特定的 URL Scheme
        // 格式：instagram://library?LocalIdentifier={identifier}
        // 但这种方式需要先将图片保存到相册
        
        if let image = image {
            // 保存图片到相册
            UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
            
            // 打开 Instagram
            if let instagramURL = URL(string: "instagram://library") {
                if UIApplication.shared.canOpenURL(instagramURL) {
                    UIApplication.shared.open(instagramURL) { success in
                        if success {
                            HapticFeedback.success()
                        } else {
                            HapticFeedback.error()
                        }
                    }
                } else {
                    // Instagram 未安装，提示用户
                    HapticFeedback.error()
                }
            }
        } else {
            // 没有图片，使用网页分享
            if let webURL = URL(string: "https://www.instagram.com") {
                UIApplication.shared.open(webURL)
            }
        }
    }
    
    // MARK: - Facebook分享
    
    private static func shareToFacebook(title: String, description: String, url: URL) {
        // Facebook 分享使用网页方式
        let shareText = "\(title) - \(description)"
        let encodedText = shareText.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let encodedURL = url.absoluteString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        
        if let facebookURL = URL(string: "https://www.facebook.com/sharer/sharer.php?u=\(encodedURL)&quote=\(encodedText)") {
            UIApplication.shared.open(facebookURL) { success in
                if success {
                    HapticFeedback.success()
                } else {
                    HapticFeedback.error()
                }
            }
        }
    }
    
    // MARK: - X分享（原 Twitter）
    
    private static func shareToTwitter(text: String, url: URL) {
        let encodedText = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let encodedURL = url.absoluteString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        
        // 先尝试使用 X App（X 应用可能仍支持 twitter:// URL scheme）
        if let twitterURL = URL(string: "twitter://post?message=\(encodedText)%20\(encodedURL)") {
            if UIApplication.shared.canOpenURL(twitterURL) {
                UIApplication.shared.open(twitterURL) { success in
                    if success {
                        HapticFeedback.success()
                        return
                    }
                }
            }
        }
        
        // 如果 X App 未安装，使用网页（X 支持 twitter.com 和 x.com）
        if let webURL = URL(string: "https://x.com/intent/tweet?text=\(encodedText)&url=\(encodedURL)") {
            UIApplication.shared.open(webURL) { success in
                if success {
                    HapticFeedback.success()
                } else {
                    HapticFeedback.error()
                }
            }
        }
    }
    
    // MARK: - 微博分享
    
    private static func shareToWeibo(title: String, description: String, url: URL, image: UIImage?) {
        let shareText = "\(title)\n\n\(description)\n\n\(url.absoluteString)"
        let encodedText = shareText.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        
        // 先尝试使用微博 App
        if let weiboURL = URL(string: "weibosdk://request?id=1&type=text&content=\(encodedText)") {
            if UIApplication.shared.canOpenURL(weiboURL) {
                UIApplication.shared.open(weiboURL) { success in
                    if success {
                        HapticFeedback.success()
                        return
                    }
                }
            }
        }
        
        // 如果微博 App 未安装，使用网页
        if let webURL = URL(string: "https://service.weibo.com/share/share.php?url=\(url.absoluteString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")&title=\(encodedText)") {
            UIApplication.shared.open(webURL) { success in
                if success {
                    HapticFeedback.success()
                } else {
                    HapticFeedback.error()
                }
            }
        }
    }
    
    // MARK: - 短信分享
    
    private static func shareToSMS(title: String, description: String, url: URL) {
        let shareText = "\(title)\n\n\(description)\n\n\(url.absoluteString)"
        
        // 使用系统短信分享
        if let smsURL = URL(string: "sms:&body=\(shareText.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")") {
            if UIApplication.shared.canOpenURL(smsURL) {
                UIApplication.shared.open(smsURL) { success in
                    if success {
                        HapticFeedback.success()
                    } else {
                        HapticFeedback.error()
                    }
                }
            } else {
                // 如果无法打开短信，使用系统分享面板
                shareWithSystemSheet(title: title, description: description, url: url, image: nil)
            }
        }
    }
    
    // MARK: - 复制链接
    
    private static func copyToClipboard(title: String, description: String, url: URL) {
        let shareText = "\(title)\n\n\(description)\n\n\(url.absoluteString)"
        UIPasteboard.general.string = shareText
        HapticFeedback.success()
    }
    
    // MARK: - 系统分享面板
    
    private static func shareWithSystemSheet(title: String, description: String, url: URL, image: UIImage?) {
        var shareItems: [Any] = []
        
        if let image = image {
            shareItems.append(image)
        }
        
        let shareText = "\(title)\n\n\(description)\n\n\(url.absoluteString)"
        shareItems.append(shareText)
        shareItems.append(url)
        
        ShareHelper.presentShareSheet(items: shareItems)
    }
    
    /// 获取可用的分享平台列表（显示所有平台，未安装的会显示为半透明）
    public static func getAvailablePlatforms() -> [SharePlatform] {
        var platforms: [SharePlatform] = []
        
        // 微信和朋友圈（总是显示，即使未安装也可以通过系统分享使用）
        platforms.append(.wechat)
        platforms.append(.wechatMoments)
        
        // QQ 和 QQ空间
        platforms.append(.qq)
        platforms.append(.qzone)
        
        // 其他社交平台
        platforms.append(.instagram)
        platforms.append(.facebook)
        platforms.append(.twitter)
        platforms.append(.weibo)
        
        // 系统功能（总是显示）
        platforms.append(.sms)
        platforms.append(.copyLink)
        platforms.append(.generateImage)
        platforms.append(.more)
        
        return platforms
    }
}
