import SwiftUI
import UIKit

/// 启用滑动返回手势的 View 扩展
/// 解决 `.navigationBarBackButtonHidden(true)` 禁用滑动返回的问题
/// 现在默认自动应用到所有视图，也可以手动调用
extension View {
    /// 手动启用滑动返回手势（推荐使用，在所有导航视图上调用）
    /// 用法：在 navigationTitle 或 toolbar 后面添加 .enableSwipeBack()
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
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        // 每次更新时也确保手势已启用
        if let navigationController = uiViewController.navigationController {
            navigationController.interactivePopGestureRecognizer?.isEnabled = true
            navigationController.interactivePopGestureRecognizer?.delegate = uiViewController as? SwipeBackViewController
        }
    }
}

/// 自定义 UIViewController，启用滑动返回手势
class SwipeBackViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        enableSwipeBackGesture()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        enableSwipeBackGesture()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        enableSwipeBackGesture()
    }
    
    private func enableSwipeBackGesture() {
        // 获取导航控制器并启用交互式返回手势
        if let navigationController = self.navigationController {
            // 确保手势已启用
            navigationController.interactivePopGestureRecognizer?.isEnabled = true
            navigationController.interactivePopGestureRecognizer?.delegate = self
            
            // 确保手势不被其他手势阻止
            if let gesture = navigationController.interactivePopGestureRecognizer {
                gesture.cancelsTouchesInView = false
            }
        }
    }
}

extension SwipeBackViewController: UIGestureRecognizerDelegate {
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        // 只有当有多于一个视图控制器时才启用返回手势
        guard let navigationController = navigationController else { return false }
        return navigationController.viewControllers.count > 1
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        // 允许与其他手势同时识别，避免冲突
        // 但优先处理返回手势
        if gestureRecognizer is UIScreenEdgePanGestureRecognizer {
            return true
        }
        return false
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRequireFailureOf otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        // 确保返回手势优先于 ScrollView 的滑动手势
        if gestureRecognizer is UIScreenEdgePanGestureRecognizer {
            // 返回手势不需要等待其他手势失败
            return false
        }
        return false
    }
}

