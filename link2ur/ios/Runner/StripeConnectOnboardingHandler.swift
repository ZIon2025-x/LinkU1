import Foundation
import Flutter
import UIKit
@_spi(PrivateBetaConnect) import StripeConnect

@available(iOS 15, *)
class StripeConnectOnboardingHandler: NSObject, StripeConnect.AccountOnboardingControllerDelegate {

    private var result: FlutterResult?
    private var embeddedComponentManager: StripeConnect.EmbeddedComponentManager?
    private var onboardingController: StripeConnect.AccountOnboardingController?

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

    // MARK: - AccountOnboardingControllerDelegate（当前 SDK 仅提供这两个回调）

    func accountOnboardingDidExit(_ accountOnboarding: StripeConnect.AccountOnboardingController) {
        result?(["status": "completed"])
        cleanup()
    }

    func accountOnboarding(_ accountOnboarding: StripeConnect.AccountOnboardingController, didFailLoadWithError error: Error) {
        result?(FlutterError(code: "LOAD_FAILED", message: error.localizedDescription, details: nil))
        cleanup()
    }

    private func cleanup() {
        onboardingController = nil
        embeddedComponentManager = nil
        result = nil
    }
}
