import UIKit
import SwiftUI
import LinkPresentation

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
        
        // 优先使用SDK检测（如果已集成）
        #if canImport(WechatOpenSDK)
        if platform == .wechat || platform == .wechatMoments {
            return WeChatShareManager.isWeChatInstalled()
        }
        #endif
        
        #if canImport(TencentOpenAPI)
        if platform == .qq || platform == .qzone {
            return QQShareManager.isQQInstalled()
        }
        #endif
        
        // 降级使用URL Scheme检测
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
        // 优先使用微信SDK进行分享（如果已集成）
        // 如果SDK未集成或分享失败，降级使用系统分享面板
        
        #if canImport(WechatOpenSDK)
        // 使用微信SDK分享
        let completion: (Bool, String?) -> Void = { success, error in
            if success {
                HapticFeedback.success()
            } else {
                // SDK分享失败，降级使用系统分享面板
                fallbackToSystemShare(title: title, description: description, url: url, image: image)
            }
        }
        
        if platform == .wechatMoments {
            // 分享到朋友圈
            WeChatShareManager.shareToMoments(
                title: title,
                description: description,
                url: url,
                image: image,
                completion: completion
            )
        } else {
            // 分享到微信好友
            WeChatShareManager.shareToFriend(
                title: title,
                description: description,
                url: url,
                image: image,
                completion: completion
            )
        }
        #else
        // SDK未集成，使用系统分享面板
        fallbackToSystemShare(title: title, description: description, url: url, image: image)
        #endif
    }
    
    /// 降级到系统分享面板（优化版本）
    private static func fallbackToSystemShare(
        title: String,
        description: String,
        url: URL,
        image: UIImage?
    ) {
        // 添加调试日志
        Logger.debug("降级到系统分享面板 - Title: \(title), Description: \(description.prefix(50))...", category: .ui)
        
        // 优化：在后台线程准备分享项，避免阻塞主线程
        DispatchQueue.global(qos: .userInitiated).async {
            var shareItems: [Any] = []
            
            // 1. 使用自定义的 UIActivityItemSource 提供正确的标题和描述
            // 这样微信等应用可以从 LPLinkMetadata 获取正确的标题和描述
            let shareItem = ShareItemSource(
                url: url,
                title: title,
                description: description,
                image: image
            )
            shareItems.append(shareItem)
            
            // 2. URL（作为后备，某些应用可能需要直接URL）
            shareItems.append(url)
            
            // 3. 文本（作为后备，用于复制链接等）
            let shareText = "\(title)\n\n\(description)\n\n\(url.absoluteString)"
            shareItems.append(shareText)
            
            // 4. 图片（压缩后添加）- 在后台线程压缩
            if let image = image {
                let compressedImage = compressImageForSharing(image, maxWidth: 800)
                shareItems.append(compressedImage)
            }
            
            // 回到主线程显示分享面板
            DispatchQueue.main.async {
                ShareHelper.presentShareSheet(items: shareItems)
            }
        }
    }
    
    // MARK: - QQ分享
    
    private static func shareToQQ(
        platform: SharePlatform,
        title: String,
        description: String,
        url: URL,
        image: UIImage?
    ) {
        // 优先使用QQ SDK进行分享（如果已集成）
        // 如果SDK未集成或分享失败，降级使用系统分享面板
        
        #if canImport(TencentOpenAPI)
        // 使用QQ SDK分享
        let completion: (Bool, String?) -> Void = { success, error in
            if success {
                HapticFeedback.success()
            } else {
                // SDK分享失败，降级使用系统分享面板
                fallbackToSystemShare(title: title, description: description, url: url, image: image)
            }
        }
        
        if platform == .qzone {
            // 分享到QQ空间
            QQShareManager.shareToQZone(
                title: title,
                description: description,
                url: url,
                image: image,
                completion: completion
            )
        } else {
            // 分享到QQ好友
            QQShareManager.shareToFriend(
                title: title,
                description: description,
                url: url,
                image: image,
                completion: completion
            )
        }
        #else
        // SDK未集成，使用系统分享面板
        fallbackToSystemShare(title: title, description: description, url: url, image: image)
        #endif
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
        // Facebook 分享：先尝试使用 App，如果失败则使用网页
        
        let shareText = "\(title) - \(description)"
        let encodedText = shareText.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let encodedURL = url.absoluteString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        
        // 先尝试使用 Facebook App
        // Facebook App 的 URL Scheme: fb://share?href={url}&quote={text}
        if let fbAppURL = URL(string: "fb://share?href=\(encodedURL)&quote=\(encodedText)") {
            if UIApplication.shared.canOpenURL(fbAppURL) {
                UIApplication.shared.open(fbAppURL) { success in
                    if success {
                        HapticFeedback.success()
                        return
                    }
                }
            }
        }
        
        // 如果 Facebook App 未安装或打开失败，使用网页分享
        if let facebookWebURL = URL(string: "https://www.facebook.com/sharer/sharer.php?u=\(encodedURL)&quote=\(encodedText)") {
            UIApplication.shared.open(facebookWebURL) { success in
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
        // 优化：优先使用URL，系统会自动抓取网页的meta标签
        // 这样可以避免处理大图片导致的延迟
        var shareItems: [Any] = []
        
        // 1. URL（最重要，系统会异步加载预览）
        shareItems.append(url)
        
        // 2. 文本（作为后备，如果URL无法访问时使用）
        let shareText = "\(title)\n\n\(description)\n\n\(url.absoluteString)"
        shareItems.append(shareText)
        
        // 3. 图片（可选，如果图片太大可能会影响性能）
        // 优化：压缩图片以减少处理时间
        if let image = image {
            // 压缩图片到合理大小（最大宽度800px）
            let compressedImage = compressImageForSharing(image, maxWidth: 800)
            shareItems.append(compressedImage)
        }
        
        // 异步显示分享面板，避免阻塞主线程
        DispatchQueue.main.async {
            ShareHelper.presentShareSheet(items: shareItems)
        }
    }
    
    /// 压缩图片用于分享（优化性能）
    private static func compressImageForSharing(_ image: UIImage, maxWidth: CGFloat) -> UIImage {
        // 如果图片已经足够小，直接返回
        if image.size.width <= maxWidth {
            return image
        }
        
        // 计算新尺寸，保持宽高比
        let aspectRatio = image.size.height / image.size.width
        let newSize = CGSize(width: maxWidth, height: maxWidth * aspectRatio)
        
        // 使用更高效的图片渲染方法（UIGraphicsImageRenderer）
        let renderer = UIGraphicsImageRenderer(size: newSize)
        let compressedImage = renderer.image { context in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
        
        return compressedImage
    }
    
    /// 获取可用的分享平台列表（显示所有平台，未安装的会显示为半透明）
    public static func getAvailablePlatforms() -> [SharePlatform] {
        var platforms: [SharePlatform] = []
        
        // 暂时隐藏微信和QQ相关平台（需要付费认证）
        // platforms.append(.wechat)
        // platforms.append(.wechatMoments)
        // platforms.append(.qq)
        // platforms.append(.qzone)
        
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

// MARK: - 分享项源（用于系统分享面板，提供正确的标题和描述）

/// 自定义分享项源，确保微信等应用能获取正确的标题和描述
class ShareItemSource: NSObject, UIActivityItemSource {
    let url: URL
    let title: String
    let description: String
    let image: UIImage?
    
    init(url: URL, title: String, description: String, image: UIImage?) {
        self.url = url
        self.title = title
        self.description = description
        self.image = image
        super.init()
    }
    
    // 占位符
    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        return url
    }
    
    // 实际分享的内容
    func activityViewController(_ activityViewController: UIActivityViewController, itemForActivityType activityType: UIActivity.ActivityType?) -> Any? {
        // 检测是否是微信分享
        if ShareHelper.isWeChatShare(activityType) {
            // 微信分享：返回URL，让微信自动抓取网页的 weixin:title, weixin:description, weixin:image 等标签
            // 注意：如果网页的meta标签是默认值，微信会显示默认值
            // 这是微信的限制，无法通过iOS端直接传递描述
            Logger.debug("微信分享 - 返回URL，微信将从网页meta标签抓取: \(url.absoluteString)", category: .ui)
            return url
        }
        
        // 对于邮件应用，返回 URL 以便显示为链接
        if activityType == .mail {
            return url
        }
        
        // 对于其他支持 LPLinkMetadata 的应用（如 iMessage），返回 URL
        if activityType == nil {
            return url
        }
        
        // 对于复制链接、短信等，返回包含完整信息的文本
        if activityType == .copyToPasteboard || activityType == .message {
            return "\(title)\n\n\(description)\n\n\(url.absoluteString)"
        }
        
        return url
    }
    
    // 提供富链接预览元数据（用于 iMessage 等原生 App）
    func activityViewControllerLinkMetadata(_ activityViewController: UIActivityViewController) -> LPLinkMetadata? {
        let metadata = LPLinkMetadata()
        
        // 设置标题（会显示在链接预览中）
        metadata.title = title
        
        // 注意：LPLinkMetadata 没有直接的 description 属性
        // 微信不支持 LPLinkMetadata，会直接从 URL 抓取 meta 标签
        // 对于支持 LPLinkMetadata 的应用（如 iMessage、邮件等），会使用我们提供的标题和图片
        
        // 如果有图片，设置为预览图
        if let image = image {
            metadata.imageProvider = NSItemProvider(object: image)
            metadata.iconProvider = NSItemProvider(object: image)
        }
        
        // 重要：不设置 url 或 originalURL，避免系统尝试自动获取元数据
        // 系统会自动从 activityViewController 返回的 URL 中识别链接信息
        // 我们只提供手动设置的元数据（title 和 image），避免网络请求
        
        // 添加调试日志
        Logger.debug("ShareItemSource - 提供元数据: Title=\(title), Description=\(description.prefix(50))...", category: .ui)
        
        return metadata
    }
    
    // 分享主题
    func activityViewController(_ activityViewController: UIActivityViewController, subjectForActivityType activityType: UIActivity.ActivityType?) -> String {
        return title
    }
}
