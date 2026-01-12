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
    
    /// 显示分享面板（统一方法）- 优化版本
    /// - Parameters:
    ///   - items: 分享项目数组
    ///   - excludedTypes: 排除的分享类型（默认排除联系人、阅读列表、iBooks）
    ///   - completion: 分享完成回调（可选）
    public static func presentShareSheet(
        items: [Any],
        excludedTypes: [UIActivity.ActivityType]? = defaultExcludedTypes,
        completion: ShareCompletionHandler? = nil
    ) {
        // 优化：在主线程创建分享控制器，避免延迟
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
                        Logger.warning("分享失败: \(error.localizedDescription)", category: .ui)
                    }
                }
            }
        }
        
        // 确保在主线程执行
        if Thread.isMainThread {
            presentShareSheetOnMainThread(activityVC)
        } else {
            DispatchQueue.main.async {
                presentShareSheetOnMainThread(activityVC)
            }
        }
    }
    
    /// 在主线程显示分享面板（优化版本）
    private static func presentShareSheetOnMainThread(_ activityVC: UIActivityViewController, retryCount: Int = 0) {
        // 限制重试次数，避免无限循环
        guard retryCount < 3 else {
            Logger.error("分享面板显示失败：超过最大重试次数", category: .ui)
            return
        }
        
        // 使用RunLoop确保在下一个循环显示，更可靠
        DispatchQueue.main.async {
            // 获取当前的 UIViewController - 使用更可靠的方法
            guard let windowScene = UIApplication.shared.connectedScenes
                    .compactMap({ $0 as? UIWindowScene })
                    .first(where: { $0.activationState == .foregroundActive }),
                  let window = windowScene.windows.first(where: { $0.isKeyWindow && $0.isHidden == false }),
                  let rootVC = window.rootViewController else {
                // 如果获取失败，延迟重试
                if retryCount < 2 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        presentShareSheetOnMainThread(activityVC, retryCount: retryCount + 1)
                    }
                }
                return
            }
            
            // 找到最顶层的视图控制器
            var topVC = rootVC
            while let presented = topVC.presentedViewController {
                topVC = presented
            }
            
            // 检查视图是否在窗口层次结构中且可见
            guard topVC.view.window != nil,
                  topVC.view.superview != nil,
                  !topVC.isBeingDismissed,
                  !topVC.isBeingPresented else {
                // 视图还没准备好，延迟重试
                if retryCount < 2 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        presentShareSheetOnMainThread(activityVC, retryCount: retryCount + 1)
                    }
                }
                return
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
            
            // 显示分享面板
            topVC.present(activityVC, animated: true, completion: nil)
        }
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

