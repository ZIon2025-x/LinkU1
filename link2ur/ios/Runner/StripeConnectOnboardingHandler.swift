import Foundation
import Flutter
import UIKit
import StripeConnect

class StripeConnectOnboardingHandler: NSObject, AccountOnboardingControllerDelegate {
    
    private var result: FlutterResult?
    private var embeddedComponentManager: EmbeddedComponentManager?
    private var onboardingController: AccountOnboardingController?
    
    // Hardcoded URLs matching the iOS native project (or can be passed from Flutter)
    // In a real app, these should probably come from Flutter/AppConfig
    private let termsURL = URL(string: "https://link2ur.com/terms")!
    private let privacyURL = URL(string: "https://link2ur.com/privacy")!
    
    func openOnboarding(
        publishableKey: String,
        clientSecret: String,
        from viewController: UIViewController,
        result: @escaping FlutterResult
    ) {
        self.result = result
        
        // Initialize Stripe Client
        STPAPIClient.shared.publishableKey = publishableKey
        
        // Initialize EmbeddedComponentManager
        embeddedComponentManager = EmbeddedComponentManager(
            fetchClientSecret: {
                return clientSecret
            }
        )
        
        // 与 iOS 原生项目一致的 collectionOptions（收集 eventuallyDue + 包含 futureRequirements）
        var collectionOptions = AccountCollectionOptions()
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
        
        // Present
        controller.present(from: viewController)
    }
    
    // MARK: - AccountOnboardingControllerDelegate
    
    func accountOnboardingController(_ controller: AccountOnboardingController, didCompleteWith account: Account) {
        // Onboarding completed
        result?(["status": "completed"])
        cleanup()
    }
    
    func accountOnboardingController(_ controller: AccountOnboardingController, didCancelWith account: Account) {
        // User cancelled
        result?(["status": "cancelled"])
        cleanup()
    }
    
    func accountOnboardingController(_ controller: AccountOnboardingController, didFailWith error: Error) {
        // Error occurred
        result?(FlutterError(code: "ONBOARDING_FAILED", message: error.localizedDescription, details: nil))
        cleanup()
    }
    
    func accountOnboardingController(_ controller: AccountOnboardingController, didFailLoadWithError error: Error) {
        // Load error
        result?(FlutterError(code: "LOAD_FAILED", message: error.localizedDescription, details: nil))
        cleanup()
    }
    
    private func cleanup() {
        onboardingController = nil
        embeddedComponentManager = nil
        result = nil
    }
}
