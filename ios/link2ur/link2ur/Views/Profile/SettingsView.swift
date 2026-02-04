import SwiftUI
import Combine

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject private var appTheme = AppTheme.shared
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    @AppStorage("success_sound_enabled") private var successSoundEnabled = true
    @State private var showDeleteAccountAlert = false
    @State private var isDeletingAccount = false
    @State private var cancellables = Set<AnyCancellable>()
    
    var body: some View {
        ZStack {
            AppColors.background
                .ignoresSafeArea()
            
            List {
                // 通知设置
                Section(LocalizationKey.settingsNotifications.localized) {
                    Toggle(LocalizationKey.settingsAllowNotifications.localized, isOn: $notificationsEnabled)
                }

                // 声音与反馈（与 SoundFeedback 共用 UserDefaults key "success_sound_enabled"）
                Section {
                    Toggle(LocalizationKey.settingsSuccessSound.localized, isOn: $successSoundEnabled)
                } footer: {
                    Text(LocalizationKey.settingsSuccessSoundDescription.localized)
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
                            Image(systemName: "checkmark.shield.fill")
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
                
                // 危险操作
                Section {
                    Button(action: {
                        showDeleteAccountAlert = true
                    }) {
                        HStack {
                            if isDeletingAccount {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "trash.fill")
                                    .foregroundColor(.red)
                            }
                            Text(LocalizationKey.settingsDeleteAccount.localized)
                                .foregroundColor(.red)
                        }
                    }
                    .disabled(isDeletingAccount)
                }
            }
            .listStyle(InsetGroupedListStyle())
            .alert(LocalizationKey.settingsDeleteAccount.localized, isPresented: $showDeleteAccountAlert) {
                Button(LocalizationKey.commonCancel.localized, role: .cancel) {}
                Button(LocalizationKey.settingsDeleteAccount.localized, role: .destructive) {
                    deleteAccount()
                }
            } message: {
                Text(LocalizationKey.settingsDeleteAccountMessage.localized)
            }
            .navigationTitle(LocalizationKey.profileSettings.localized)
            .navigationBarTitleDisplayMode(.inline)
            .enableSwipeBack()
            .toolbarBackground(AppColors.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
    }
    
    private func deleteAccount() {
        isDeletingAccount = true
        
        APIService.shared.deleteAccount()
            .sink(
                receiveCompletion: { result in
                    isDeletingAccount = false
                    if case .failure(let error) = result {
                        // 删除失败，显示错误
                        Logger.error("删除账户失败: \(error)", category: .api)
                    }
                    // 注意：成功时不在这里调用 logout，由 receiveValue 处理
                },
                receiveValue: { [weak appState] _ in
                    // 删除成功，登出并返回登录页面
                    appState?.logout()
                }
            )
            .store(in: &cancellables)
    }
}

