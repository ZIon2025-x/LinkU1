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
                Section("通知设置") {
                    Toggle("允许通知", isOn: $notificationsEnabled)
                }
                
                // 外观设置
                Section("外观") {
                    Picker("主题模式", selection: Binding(
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
                Section("会员") {
                    NavigationLink(destination: VIPView()) {
                        HStack {
                            Image(systemName: "crown.fill")
                                .foregroundColor(.yellow)
                            Text("VIP 会员")
                        }
                    }
                }
                
                // 帮助与支持
                Section("帮助与支持") {
                    NavigationLink(destination: FAQView()) {
                        HStack {
                            Image(systemName: "questionmark.circle.fill")
                                .foregroundColor(AppColors.primary)
                            Text("常见问题")
                        }
                    }
                    
                    NavigationLink(destination: CustomerServiceView()) {
                        HStack {
                            Image(systemName: "headphones")
                                .foregroundColor(AppColors.primary)
                            Text("联系客服")
                        }
                    }
                }
                
                // 法律信息
                Section("法律信息") {
                    NavigationLink(destination: TermsView()) {
                        HStack {
                            Image(systemName: "doc.text.fill")
                                .foregroundColor(AppColors.primary)
                            Text("服务条款")
                        }
                    }
                    
                    NavigationLink(destination: PrivacyView()) {
                        HStack {
                            Image(systemName: "lock.shield.fill")
                                .foregroundColor(AppColors.primary)
                            Text("隐私政策")
                        }
                    }
                }
                
                // 关于
                Section("关于") {
                    NavigationLink(destination: AboutView()) {
                        HStack {
                            Image(systemName: "info.circle.fill")
                                .foregroundColor(AppColors.primary)
                            Text("关于我们")
                        }
                    }
                    
                    HStack {
                        Text("版本")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(AppColors.textSecondary)
                    }
                    
                    HStack {
                        Text("应用名称")
                        Spacer()
                        Text("Link²Ur")
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
                
                // 账户信息
                Section("账户") {
                    if let user = appState.currentUser {
                        HStack {
                            Text("用户ID")
                            Spacer()
                            Text(user.id)
                                .foregroundColor(AppColors.textSecondary)
                        }
                        
                        HStack {
                            Text("邮箱")
                            Spacer()
                            Text(user.email ?? "未提供")
                                .foregroundColor(AppColors.textSecondary)
                        }
                    }
                }
            }
            .listStyle(InsetGroupedListStyle())
        }
        .navigationTitle("设置")
        .navigationBarTitleDisplayMode(.inline)
        .enableSwipeBack()
        .toolbarBackground(AppColors.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }
}

