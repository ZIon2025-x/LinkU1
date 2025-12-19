import SwiftUI
import UIKit

// TabBar 点击检测器 - 使用 UITabBarControllerDelegate
struct TabBarTapDetector: UIViewControllerRepresentable {
    let onHomeTabTapped: () -> Void
    
    func makeUIViewController(context: Context) -> UIViewController {
        let controller = UIViewController()
        controller.view.backgroundColor = .clear
        
        // 延迟执行，确保 TabBarController 已经创建
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            setupTabBarDelegate(onHomeTabTapped: onHomeTabTapped)
        }
        
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        // 每次更新时重新设置
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            setupTabBarDelegate(onHomeTabTapped: onHomeTabTapped)
        }
    }
    
    private func setupTabBarDelegate(onHomeTabTapped: @escaping () -> Void) {
        // 查找 TabBarController
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let tabBarController = findTabBarController(in: window.rootViewController) else {
            return
        }
        
        // 设置代理（如果还没有设置）
        if tabBarController.delegate == nil || !(tabBarController.delegate is TabBarDelegate) {
            let delegate = TabBarDelegate()
            delegate.onHomeTabTapped = onHomeTabTapped
            tabBarController.delegate = delegate
            // 保存引用，防止被释放
            objc_setAssociatedObject(tabBarController, "TabBarDelegate", delegate, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        } else if let delegate = tabBarController.delegate as? TabBarDelegate {
            delegate.onHomeTabTapped = onHomeTabTapped
        }
    }
    
    private func findTabBarController(in viewController: UIViewController?) -> UITabBarController? {
        if let tabBarController = viewController as? UITabBarController {
            return tabBarController
        }
        for child in viewController?.children ?? [] {
            if let tabBarController = findTabBarController(in: child) {
                return tabBarController
            }
        }
        return nil
    }
}

// TabBar 代理 - 使用 shouldSelect 方法，即使 tab 已选中也会被调用
class TabBarDelegate: NSObject, UITabBarControllerDelegate {
    var onHomeTabTapped: (() -> Void)?
    
    func tabBarController(_ tabBarController: UITabBarController, shouldSelect viewController: UIViewController) -> Bool {
        // 获取要选择的 tab 索引
        if let index = tabBarController.viewControllers?.firstIndex(of: viewController),
           index == 0 { // 首页是第一个
            // 如果首页已经被选中，触发重置
            if tabBarController.selectedIndex == 0 {
                onHomeTabTapped?()
            }
        }
        return true
    }
}
