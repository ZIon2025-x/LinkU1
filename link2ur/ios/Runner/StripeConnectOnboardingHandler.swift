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

    func openOnboarding(
        publishableKey: String,
        clientSecret: String,
        from viewController: UIViewController,
        result: @escaping FlutterResult
    ) {
        self.result = result

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
    }

    /// 打开账户管理嵌入式组件（用于已完成 onboarding 的 V2 账户更新收款信息）
    func openAccountManagement(
        publishableKey: String,
        clientSecret: String,
        from viewController: UIViewController,
        result: @escaping FlutterResult
    ) {
        self.result = result

        STPAPIClient.shared.publishableKey = publishableKey

        let secret = clientSecret
        embeddedComponentManager = StripeConnect.EmbeddedComponentManager(
            fetchClientSecret: { () async -> String? in secret }
        )

        let vc = embeddedComponentManager!.createAccountManagementViewController()

        vc.delegate = self
        self.managementViewController = vc

        vc.modalPresentationStyle = .fullScreen
        viewController.present(vc, animated: true)
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
        result = nil
    }
}
