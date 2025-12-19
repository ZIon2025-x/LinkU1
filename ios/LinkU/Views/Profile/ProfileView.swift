import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var appState: AppState
    @State private var showLogoutAlert = false
    
    var body: some View {
        NavigationView {
            ZStack {
                AppColors.background
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 0) {
                        // 用户信息卡片
                        VStack(spacing: 16) {
                            // 头像
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            gradient: Gradient(colors: [AppColors.primary, AppColors.primary.opacity(0.7)]),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 80, height: 80)
                                
                                if let user = appState.currentUser, let avatar = user.avatar, !avatar.isEmpty {
                                    AsyncImage(url: URL(string: avatar)) { image in
                                        image
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                    } placeholder: {
                                        Image(systemName: "person.fill")
                                            .foregroundColor(.white)
                                    }
                                    .frame(width: 80, height: 80)
                                    .clipShape(Circle())
                                } else {
                                    Image(systemName: "person.fill")
                                        .font(.system(size: 40))
                                        .foregroundColor(.white)
                                }
                            }
                            
                            // 用户名和邮箱
                            VStack(spacing: 4) {
                                Text(appState.currentUser?.username ?? "用户")
                                    .font(.title2)
                                    .fontWeight(.semibold)
                                    .foregroundColor(AppColors.textPrimary)
                                
                                Text(appState.currentUser?.email ?? "")
                                    .font(.subheadline)
                                    .foregroundColor(AppColors.textSecondary)
                            }
                        }
                        .padding(.vertical, AppSpacing.xl)
                        .frame(maxWidth: .infinity)
                        .background(AppColors.cardBackground)
                        
                        // 功能列表
                        VStack(spacing: 0) {
                            NavigationLink(destination: MyTasksView()) {
                                ProfileRow(
                                    icon: "doc.text.fill",
                                    title: "我的任务",
                                    color: AppColors.primary
                                ) {}
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            Divider()
                                .padding(.leading, 60)
                            
                            NavigationLink(destination: MyPostsView()) {
                                ProfileRow(
                                    icon: "cart.fill",
                                    title: "我的发布",
                                    color: AppColors.warning
                                ) {}
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            Divider()
                                .padding(.leading, 60)
                            
                            NavigationLink(destination: WalletView()) {
                                ProfileRow(
                                    icon: "wallet.pass.fill",
                                    title: "我的钱包",
                                    color: AppColors.success
                                ) {}
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            Divider()
                                .padding(.leading, 60)
                            
                            NavigationLink(destination: MyServiceApplicationsView()) {
                                ProfileRow(
                                    icon: "hand.raised.fill",
                                    title: "我的申请",
                                    color: Color(red: 0.5, green: 0.3, blue: 0.8)
                                ) {}
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            Divider()
                                .padding(.leading, 60)
                            
                            NavigationLink(destination: SettingsView()) {
                                ProfileRow(
                                    icon: "gearshape.fill",
                                    title: "设置",
                                    color: AppColors.textSecondary
                                ) {}
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        .background(AppColors.cardBackground)
                        .cornerRadius(AppCornerRadius.medium)
                        .padding(.top, AppSpacing.md)
                        .padding(.horizontal, AppSpacing.md)
                        
                        // 退出登录按钮
                        Button(action: {
                            showLogoutAlert = true
                        }) {
                            HStack {
                                Spacer()
                                Text("退出登录")
                                    .fontWeight(.medium)
                                    .foregroundColor(AppColors.error)
                                Spacer()
                            }
                            .padding(.vertical, AppSpacing.md)
                            .background(AppColors.cardBackground)
                            .cornerRadius(AppCornerRadius.medium)
                        }
                        .padding(.top, AppSpacing.lg)
                        .padding(.horizontal, AppSpacing.md)
                        .padding(.bottom, AppSpacing.xl)
                    }
                }
            }
            .navigationTitle("我的")
            .alert("确认退出", isPresented: $showLogoutAlert) {
                Button("取消", role: .cancel) {}
                Button("退出", role: .destructive) {
                    appState.logout()
                }
            } message: {
                Text("确定要退出登录吗？")
            }
        }
    }
}

// 个人中心行组件
struct ProfileRow: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: AppCornerRadius.small)
                        .fill(color.opacity(0.15))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: icon)
                        .foregroundColor(color)
                        .font(.system(size: 18))
                }
                
                Text(title)
                    .font(.body)
                    .foregroundColor(AppColors.textPrimary)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.md)
        }
        .buttonStyle(PlainButtonStyle())
    }
}
