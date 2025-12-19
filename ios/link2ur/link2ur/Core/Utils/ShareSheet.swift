import SwiftUI
import UIKit

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

/// 分享辅助工具
public struct ShareHelper {
    
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

