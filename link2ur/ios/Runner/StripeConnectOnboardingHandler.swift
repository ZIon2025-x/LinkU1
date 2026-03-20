import Foundation
import Flutter
import UIKit
@_spi(PrivateBetaConnect) @_spi(DashboardOnly) import StripeConnect

@available(iOS 15, *)
class StripeConnectOnboardingHandler: NSObject, StripeConnect.AccountOnboardingControllerDelegate, StripeConnect.AccountManagementViewControllerDelegate {

    private var result: FlutterResult?
    private var embeddedComponentManager: StripeConnect.EmbeddedComponentManager?
    private var onboardingController: StripeConnect.AccountOnboardingController?
    private var managementViewController: StripeConnect.AccountManagementViewController?

    private let termsURL = URL(string: "https://www.link2ur.com/terms")!
    private let privacyURL = URL(string: "https://www.link2ur.com/privacy")!

    /// 保存 presenting VC 引用，用于手动关闭
    private weak var presentingVC: UIViewController?

    func openOnboarding(
        publishableKey: String,
        clientSecret: String,
        from viewController: UIViewController,
        result: @escaping FlutterResult
    ) {
        self.result = result
        self.presentingVC = viewController

        STPAPIClient.shared.publishableKey = publishableKey

        let secret = clientSecret
        embeddedComponentManager = StripeConnect.EmbeddedComponentManager(
            fetchClientSecret: { () async -> String? in secret }
        )

        var collectionOptions = StripeConnect.AccountCollectionOptions()
        collectionOptions.fields = .eventuallyDue
        collectionOptions.futureRequirements = .include

        let controller = embeddedComponentManager!.createAccountOnboardingController(
            fullTermsOfServiceUrl: termsURL,
            recipientTermsOfServiceUrl: termsURL,
            privacyPolicyUrl: privacyURL,
            collectionOptions: collectionOptions
        )

        controller.delegate = self
        self.onboardingController = controller

        controller.present(from: viewController)

        // Stripe SDK present 后，在顶部叠加关闭按钮
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.addCloseButtonToPresented(from: viewController)
        }
    }

    /// 在 Stripe SDK 呈现的页面顶部叠加关闭按钮
    private func addCloseButtonToPresented(from viewController: UIViewController) {
        // 找到 Stripe 呈现的最顶层 VC
        var topVC = viewController.presentedViewController
        while let next = topVC?.presentedViewController {
            topVC = next
        }
        guard let stripeVC = topVC else { return }

        let closeButton = UIButton(type: .system)
        closeButton.setImage(
            UIImage(systemName: "xmark.circle.fill"),
            for: .normal
        )
        closeButton.tintColor = .secondaryLabel
        closeButton.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.9)
        closeButton.layer.cornerRadius = 18
        closeButton.clipsToBounds = true
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)

        stripeVC.view.addSubview(closeButton)
        NSLayoutConstraint.activate([
            closeButton.widthAnchor.constraint(equalToConstant: 36),
            closeButton.heightAnchor.constraint(equalToConstant: 36),
            closeButton.leadingAnchor.constraint(equalTo: stripeVC.view.safeAreaLayoutGuide.leadingAnchor, constant: 12),
            closeButton.topAnchor.constraint(equalTo: stripeVC.view.safeAreaLayoutGuide.topAnchor, constant: 8),
        ])
    }

    @objc private func closeTapped() {
        // 先关闭 Stripe 呈现的页面
        if let presenting = presentingVC {
            presenting.dismiss(animated: true) { [weak self] in
                self?.result?(["status": "cancelled"])
                self?.cleanup()
            }
        } else {
            result?(["status": "cancelled"])
            cleanup()
        }
    }

    /// 打开账户管理嵌入式组件（用于已完成 onboarding 的 V2 账户更新收款信息）
    func openAccountManagement(
        publishableKey: String,
        clientSecret: String,
        from viewController: UIViewController,
        result: @escaping FlutterResult
    ) {
        self.result = result
        self.presentingVC = viewController

        STPAPIClient.shared.publishableKey = publishableKey

        let secret = clientSecret
        embeddedComponentManager = StripeConnect.EmbeddedComponentManager(
            fetchClientSecret: { () async -> String? in secret }
        )

        let vc = embeddedComponentManager!.createAccountManagementViewController()

        vc.delegate = self
        self.managementViewController = vc

        // 用 UINavigationController 包裹，提供关闭按钮
        let nav = UINavigationController(rootViewController: vc)
        nav.modalPresentationStyle = .fullScreen
        vc.navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .close,
            target: self,
            action: #selector(managementCloseTapped)
        )
        vc.navigationItem.title = "Account Management"

        viewController.present(nav, animated: true)
    }

    @objc private func managementCloseTapped() {
        dismissManagement()
    }

    // MARK: - AccountOnboardingControllerDelegate

    func accountOnboardingDidExit(_ accountOnboarding: StripeConnect.AccountOnboardingController) {
        result?(["status": "completed"])
        cleanup()
    }

    func accountOnboarding(_ accountOnboarding: StripeConnect.AccountOnboardingController, didFailLoadWithError error: Error) {
        result?(FlutterError(code: "LOAD_FAILED", message: error.localizedDescription, details: nil))
        cleanup()
    }

    // MARK: - AccountManagementViewControllerDelegate

    func accountManagement(_ accountManagement: StripeConnect.AccountManagementViewController, didFailLoadWithError error: Error) {
        result?(FlutterError(code: "LOAD_FAILED", message: error.localizedDescription, details: nil))
        dismissManagement()
    }

    private func dismissManagement() {
        managementViewController?.dismiss(animated: true) { [weak self] in
            self?.result?(["status": "completed"])
            self?.cleanup()
        }
    }

    private func cleanup() {
        onboardingController = nil
        managementViewController = nil
        embeddedComponentManager = nil
        presentingVC = nil
        result = nil
    }
}
