import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject private var appTheme = AppTheme.shared
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    
    var body: some View {
        ZStack {
            AppColors.background
                .ignoresSafeArea()
            
            List {
                // 通知设置
                Section(LocalizationKey.settingsNotifications.localized) {
                    Toggle(LocalizationKey.settingsAllowNotifications.localized, isOn: $notificationsEnabled)
                }
                
                // 外观设置
                Section(LocalizationKey.settingsAppearance.localized) {
                    Picker(LocalizationKey.settingsThemeMode.localized, selection: Binding(
                        get: { appTheme.themeMode },
                        set: { appTheme.setThemeMode($0) }
                    )) {
                        ForEach(ThemeMode.allCases, id: \.self) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                // 会员
                Section(LocalizationKey.settingsMembership.localized) {
                    NavigationLink(destination: VIPView()) {
                        HStack {
                            Image(systemName: "crown.fill")
                                .foregroundColor(.yellow)
                            Text(LocalizationKey.settingsVIPMembership.localized)
                        }
                    }
                }
                
                // 帮助与支持
                Section(LocalizationKey.settingsHelpSupport.localized) {
                    NavigationLink(destination: FAQView()) {
                        HStack {
                            Image(systemName: "questionmark.circle.fill")
                                .foregroundColor(AppColors.primary)
                            Text(LocalizationKey.settingsFAQ.localized)
                        }
                    }
                    
                    NavigationLink(destination: CustomerServiceView()) {
                        HStack {
                            Image(systemName: "headphones")
                                .foregroundColor(AppColors.primary)
                            Text(LocalizationKey.settingsContactSupport.localized)
                        }
                    }
                }
                
                // 法律信息
                Section(LocalizationKey.settingsLegal.localized) {
                    NavigationLink(destination: TermsView()) {
                        HStack {
                            Image(systemName: "doc.text.fill")
                                .foregroundColor(AppColors.primary)
                            Text(LocalizationKey.appTermsOfService.localized)
                        }
                    }
                    
                    NavigationLink(destination: PrivacyView()) {
                        HStack {
                            Image(systemName: "lock.shield.fill")
                                .foregroundColor(AppColors.primary)
                            Text(LocalizationKey.appPrivacyPolicy.localized)
                        }
                    }
                    
                    NavigationLink(destination: CookiePolicyView()) {
                        HStack {
                            Image(systemName: "cookie")
                                .foregroundColor(AppColors.primary)
                            Text("Cookie Policy")
                        }
                    }
                }
                
                // 关于
                Section(LocalizationKey.settingsAbout.localized) {
                    NavigationLink(destination: AboutView()) {
                        HStack {
                            Image(systemName: "info.circle.fill")
                                .foregroundColor(AppColors.primary)
                            Text(LocalizationKey.appAbout.localized)
                        }
                    }
                    
                    HStack {
                        Text(LocalizationKey.appVersion.localized)
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(AppColors.textSecondary)
                    }
                    
                    HStack {
                        Text(LocalizationKey.settingsAppName.localized)
                        Spacer()
                        Text("Link²Ur")
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
                
                // 收款账户
                Section(LocalizationKey.settingsPaymentAccount.localized) {
                    NavigationLink(destination: StripeConnectOnboardingView()) {
                        HStack {
                            Image(systemName: "creditcard.fill")
                                .foregroundColor(AppColors.primary)
                            Text(LocalizationKey.settingsSetupPaymentAccount.localized)
                        }
                    }
                    
                    NavigationLink(destination: StripeConnectPayoutsView()) {
                        HStack {
                            Image(systemName: "arrow.up.right.circle.fill")
                                .foregroundColor(AppColors.success)
                            Text(LocalizationKey.walletPayoutManagement.localized)
                        }
                    }
                    
                    NavigationLink(destination: StripeConnectPaymentsView()) {
                        HStack {
                            Image(systemName: "list.bullet.rectangle.fill")
                                .foregroundColor(.blue)
                            Text(LocalizationKey.walletPaymentRecords.localized)
                        }
                    }
                }
                
                // 账户信息
                Section(LocalizationKey.settingsAccount.localized) {
                    if let user = appState.currentUser {
                        HStack {
                            Text(LocalizationKey.settingsUserID.localized)
                            Spacer()
                            Text(user.id)
                                .foregroundColor(AppColors.textSecondary)
                        }
                        
                        HStack {
                            Text(LocalizationKey.profileEmail.localized)
                            Spacer()
                            Text(user.email ?? LocalizationKey.commonNotProvided.localized)
                                .foregroundColor(AppColors.textSecondary)
                        }
                    }
                }
            }
            .listStyle(InsetGroupedListStyle())
        }
        .navigationTitle(LocalizationKey.profileSettings.localized)
        .navigationBarTitleDisplayMode(.inline)
        .enableSwipeBack()
        .toolbarBackground(AppColors.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }
}

