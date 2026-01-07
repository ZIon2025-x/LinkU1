import UIKit
import StripeCore

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    var window: UIWindow?
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        // 初始化 Stripe（可选，也可以在 ViewController 中初始化）
        // StripeAPI.defaultPublishableKey = "pk_test_..."
        
        // 创建窗口和根视图控制器
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = UINavigationController(rootViewController: CheckoutViewController())
        window?.makeKeyAndVisible()
        
        return true
    }
    
    // 处理 URL Scheme 回调（如果需要）
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        // Stripe 支付回调处理
        // 如果需要处理支付回调，可以在这里添加逻辑
        return true
    }
}

