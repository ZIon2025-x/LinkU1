import SwiftUI
import UIKit
import LinkPresentation

/// 分享工具 - 企业级分享功能
public struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    let excludedActivityTypes: [UIActivity.ActivityType]?
    
    public init(
        items: [Any],
        excludedActivityTypes: [UIActivity.ActivityType]? = nil
    ) {
        self.items = items
        self.excludedActivityTypes = excludedActivityTypes
    }
    
    public func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: items,
            applicationActivities: nil
        )
        controller.excludedActivityTypes = excludedActivityTypes
        return controller
    }
    
    public func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

/// 分享完成回调类型
public typealias ShareCompletionHandler = (UIActivity.ActivityType?, Bool, [Any]?, Error?) -> Void

/// 分享辅助工具 - 统一管理分享功能
public class ShareHelper {
    
    /// 默认排除的分享类型
    public static let defaultExcludedTypes: [UIActivity.ActivityType] = [
        .assignToContact,
        .addToReadingList,
        .openInIBooks
    ]
    
    /// 显示分享面板（统一方法）
    /// - Parameters:
    ///   - items: 分享项目数组
    ///   - excludedTypes: 排除的分享类型（默认排除联系人、阅读列表、iBooks）
    ///   - completion: 分享完成回调（可选）
    public static func presentShareSheet(
        items: [Any],
        excludedTypes: [UIActivity.ActivityType]? = defaultExcludedTypes,
        completion: ShareCompletionHandler? = nil
    ) {
        let activityVC = UIActivityViewController(
            activityItems: items,
            applicationActivities: nil
        )
        
        activityVC.excludedActivityTypes = excludedTypes
        
        // 添加分享完成回调
        if let completion = completion {
            activityVC.completionWithItemsHandler = { activityType, completed, returnedItems, error in
                DispatchQueue.main.async {
                    completion(activityType, completed, returnedItems, error)
                }
            }
        } else {
            // 默认回调：提供触觉反馈
            activityVC.completionWithItemsHandler = { activityType, completed, returnedItems, error in
                DispatchQueue.main.async {
                    if completed {
                        HapticFeedback.success()
                    } else if let error = error {
                        HapticFeedback.error()
                        print("分享失败: \(error.localizedDescription)")
                    }
                }
            }
        }
        
        // 获取当前的 UIViewController
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first?.rootViewController else {
            print("无法获取当前视图控制器")
            return
        }
        
        var topVC = rootVC
        while let presented = topVC.presentedViewController {
            topVC = presented
        }
        
        // iPad 支持：配置 popover
        if UIDevice.current.userInterfaceIdiom == .pad {
            activityVC.popoverPresentationController?.sourceView = topVC.view
            activityVC.popoverPresentationController?.sourceRect = CGRect(
                x: topVC.view.bounds.midX,
                y: topVC.view.bounds.midY,
                width: 0,
                height: 0
            )
            activityVC.popoverPresentationController?.permittedArrowDirections = []
        }
        
        topVC.present(activityVC, animated: true)
    }
    
    /// 分享文本
    public static func shareText(_ text: String) -> ShareSheet {
        return ShareSheet(items: [text])
    }
    
    /// 分享图片
    public static func shareImage(_ image: UIImage) -> ShareSheet {
        return ShareSheet(items: [image])
    }
    
    /// 分享 URL
    public static func shareURL(_ url: URL) -> ShareSheet {
        return ShareSheet(items: [url])
    }
    
    /// 分享多个项目
    public static func shareItems(_ items: [Any]) -> ShareSheet {
        return ShareSheet(items: items)
    }
    
    /// 检测是否是微信分享
    public static func isWeChatShare(_ activityType: UIActivity.ActivityType?) -> Bool {
        guard let activityType = activityType else { return false }
        let identifier = activityType.rawValue.lowercased()
        return identifier.contains("weixin") || 
               identifier.contains("tencent.xin") || 
               identifier.contains("wechat")
    }
}

// MARK: - View 扩展

extension View {
    /// 显示分享表单
    public func shareSheet(
        isPresented: Binding<Bool>,
        items: [Any],
        excludedActivityTypes: [UIActivity.ActivityType]? = nil
    ) -> some View {
        self.sheet(isPresented: isPresented) {
            ShareSheet(items: items, excludedActivityTypes: excludedActivityTypes)
        }
    }
}

