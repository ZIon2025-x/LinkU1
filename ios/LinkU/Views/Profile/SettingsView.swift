import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    @AppStorage("darkModeEnabled") private var darkModeEnabled = false
    
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
                    Toggle("深色模式", isOn: $darkModeEnabled)
                }
                
                // 关于
                Section("关于") {
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
                            Text(String(user.id))
                                .foregroundColor(AppColors.textSecondary)
                        }
                        
                        HStack {
                            Text("邮箱")
                            Spacer()
                            Text(user.email)
                                .foregroundColor(AppColors.textSecondary)
                        }
                    }
                }
            }
            .listStyle(InsetGroupedListStyle())
        }
        .navigationTitle("设置")
    }
}

