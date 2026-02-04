import SwiftUI

/// 用于处理需要设置收款账户的通用 ViewModifier
/// 当 shouldPromptStripeSetup 为 true 时，显示提示 Alert 并提供跳转到设置页的选项
struct StripeSetupAlertModifier: ViewModifier {
    @Binding var shouldPromptStripeSetup: Bool
    @State private var showAlert = false
    @State private var showStripeOnboarding = false
    
    func body(content: Content) -> some View {
        content
            .onChange(of: shouldPromptStripeSetup) { newValue in
                // 兼容 iOS 16 及以下版本的 onChange API
                if newValue {
                    showAlert = true
                }
            }
            .alert(
                LocalizationKey.paymentPleaseSetupFirst.localized,
                isPresented: $showAlert
            ) {
                Button(LocalizationKey.commonGoSetup.localized) {
                    showStripeOnboarding = true
                    shouldPromptStripeSetup = false
                }
                Button(LocalizationKey.commonCancel.localized, role: .cancel) {
                    shouldPromptStripeSetup = false
                }
            } message: {
                Text(LocalizationKey.paymentPleaseSetupMessage.localized)
            }
            .sheet(isPresented: $showStripeOnboarding) {
                NavigationView {
                    StripeConnectOnboardingView()
                        .toolbar {
                            ToolbarItem(placement: .navigationBarLeading) {
                                Button(action: {
                                    showStripeOnboarding = false
                                }) {
                                    Image(systemName: "xmark")
                                        .foregroundColor(AppColors.textPrimary)
                                }
                            }
                        }
                }
            }
    }
}

extension View {
    /// 添加收款账户设置提示
    /// - Parameter shouldPromptStripeSetup: 当设置为 true 时触发提示
    /// - Returns: 带有收款账户提示功能的视图
    func stripeSetupAlert(shouldPromptStripeSetup: Binding<Bool>) -> some View {
        modifier(StripeSetupAlertModifier(shouldPromptStripeSetup: shouldPromptStripeSetup))
    }
}
