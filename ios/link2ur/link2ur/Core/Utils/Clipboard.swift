import UIKit

/// 剪贴板工具 - 企业级剪贴板管理
public struct Clipboard {
    
    /// 复制文本到剪贴板
    public static func copy(_ text: String) {
        UIPasteboard.general.string = text
    }
    
    /// 从剪贴板读取文本
    public static func paste() -> String? {
        return UIPasteboard.general.string
    }
    
    /// 复制图片到剪贴板
    public static func copyImage(_ image: UIImage) {
        UIPasteboard.general.image = image
    }
    
    /// 从剪贴板读取图片
    public static func pasteImage() -> UIImage? {
        return UIPasteboard.general.image
    }
    
    /// 复制 URL 到剪贴板
    public static func copyURL(_ url: URL) {
        UIPasteboard.general.url = url
    }
    
    /// 从剪贴板读取 URL
    public static func pasteURL() -> URL? {
        return UIPasteboard.general.url
    }
    
    /// 清空剪贴板
    public static func clear() {
        UIPasteboard.general.string = ""
    }
    
    /// 检查剪贴板是否有内容
    public static var hasContent: Bool {
        return UIPasteboard.general.hasStrings || 
               UIPasteboard.general.hasImages || 
               UIPasteboard.general.hasURLs
    }
}

