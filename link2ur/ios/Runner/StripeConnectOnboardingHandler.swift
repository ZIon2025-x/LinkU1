import Foundation
import Flutter
import UIKit
@_spi(PrivateBetaConnect) import StripeConnect

@available(iOS 15, *)
class StripeConnectOnboardingHandler: NSObject, StripeConnect.AccountOnboardingControllerDelegate, StripeConnect.AccountManagementControllerDelegate {

    private var result: FlutterResult?
    private var embeddedComponentManager: StripeConnect.EmbeddedComponentManager?
    private var onboardingController: StripeConnect.AccountOnboardingController?
    private var managementController: StripeConnect.AccountManagementController?

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

        let controller = embeddedComponentManager!.createAccountManagementController()

        controller.delegate = self
        self.managementController = controller

        controller.present(from: viewController)
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

    // MARK: - AccountManagementControllerDelegate

    func accountManagementDidExit(_ accountManagement: StripeConnect.AccountManagementController) {
        result?(["status": "completed"])
        cleanup()
    }

    func accountManagement(_ accountManagement: StripeConnect.AccountManagementController, didFailLoadWithError error: Error) {
        result?(FlutterError(code: "LOAD_FAILED", message: error.localizedDescription, details: nil))
        cleanup()
    }

    private func cleanup() {
        onboardingController = nil
        managementController = nil
        embeddedComponentManager = nil
        result = nil
    }
}
