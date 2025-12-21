import SwiftUI
import UIKit

/// 启用滑动返回手势的 View 扩展
/// 解决 `.navigationBarBackButtonHidden(true)` 禁用滑动返回的问题
extension View {
    func enableSwipeBack() -> some View {
        self.background(SwipeBackGestureEnabler())
    }
}

/// UIKit 包装器，用于启用滑动返回手势
struct SwipeBackGestureEnabler: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController {
        let controller = SwipeBackViewController()
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}

/// 自定义 UIViewController，启用滑动返回手势
class SwipeBackViewController: UIViewController {
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // 获取导航控制器并启用交互式返回手势
        if let navigationController = self.navigationController {
            navigationController.interactivePopGestureRecognizer?.isEnabled = true
            navigationController.interactivePopGestureRecognizer?.delegate = self
        }
    }
}

extension SwipeBackViewController: UIGestureRecognizerDelegate {
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        // 只有当有多于一个视图控制器时才启用返回手势
        return navigationController?.viewControllers.count ?? 0 > 1
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
}

