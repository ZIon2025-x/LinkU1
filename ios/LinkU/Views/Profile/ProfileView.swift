import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var appState: AppState
    @State private var showLogoutAlert = false
    
    var body: some View {
        NavigationView {
            ZStack {
                AppColors.background
                    .ignoresSafeArea()
                
                // 背景装饰
                VStack {
                    LinearGradient(colors: [AppColors.primary.opacity(0.15), .clear], startPoint: .top, endPoint: .bottom)
                        .frame(height: 300)
                    Spacer()
                }
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // 用户信息：现代简约风
                        VStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(.white)
                                    .frame(width: 94, height: 94)
                                    .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 5)
                                
                                if let user = appState.currentUser, let avatar = user.avatar, !avatar.isEmpty {
                                    AsyncImage(url: URL(string: avatar)) { image in
                                        image
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                    } placeholder: {
                                        Image(systemName: "person.crop.circle.fill")
                                            .resizable()
                                            .foregroundStyle(AppColors.primary.opacity(0.1))
                                    }
                                    .frame(width: 86, height: 86)
                                    .clipShape(Circle())
                                } else {
                                    Circle()
                                        .fill(AppColors.primaryGradient)
                                        .frame(width: 86, height: 86)
                                        .overlay(
                                            Image(systemName: "person.fill")
                                                .font(.system(size: 40))
                                                .foregroundColor(.white)
                                        )
                                }
                            }
                            
                            VStack(spacing: 6) {
                                Text(appState.currentUser?.username ?? "Link²U 用户")
                                    .font(.system(size: 24, weight: .bold, design: .rounded))
                                    .foregroundColor(AppColors.textPrimary)
                                
                                Text(appState.currentUser?.email ?? "未绑定邮箱")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(AppColors.textSecondary)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 4)
                                    .background(.ultraThinMaterial)
                                    .cornerRadius(20)
                            }
                        }
                        .padding(.top, 40)
                        
                        // 数据概览（新增，提升设计感）
                        HStack(spacing: 0) {
                            StatItem(title: "进行中", value: "3")
                            Divider().frame(height: 30)
                            StatItem(title: "已完成", value: "12")
                            Divider().frame(height: 30)
                            StatItem(title: "信用分", value: "98")
                        }
                        .padding(.vertical, 16)
                        .background(AppColors.cardBackground)
                        .cornerRadius(AppCornerRadius.large)
                        .padding(.horizontal, AppSpacing.md)
                        .shadow(color: Color.black.opacity(0.03), radius: 10, x: 0, y: 5)
                        
                        // 功能模块：分段式设计
                        VStack(alignment: .leading, spacing: 12) {
                            Text("我的内容")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(AppColors.textPrimary)
                                .padding(.horizontal, AppSpacing.sm)
                            
                            VStack(spacing: 0) {
                                NavigationLink(destination: MyTasksView()) {
                                    ProfileRow(icon: "list.bullet.rectangle.fill", title: "我的任务", color: AppColors.primary)
                                }
                                Divider().padding(.leading, 56)
                                NavigationLink(destination: MyPostsView()) {
                                    ProfileRow(icon: "shippingbox.fill", title: "我的发布", color: Color(hex: "FF6B6B"))
                                }
                                Divider().padding(.leading, 56)
                                NavigationLink(destination: WalletView()) {
                                    ProfileRow(icon: "creditcard.fill", title: "我的钱包", color: AppColors.success)
                                }
                            }
                            .background(AppColors.cardBackground)
                            .cornerRadius(AppCornerRadius.large)
                            .shadow(color: Color.black.opacity(0.03), radius: 10, x: 0, y: 5)
                        }
                        .padding(.horizontal, AppSpacing.md)
                        
                        VStack(alignment: .leading, spacing: 12) {
                            Text("系统设置")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(AppColors.textPrimary)
                                .padding(.horizontal, AppSpacing.sm)
                            
                            VStack(spacing: 0) {
                                NavigationLink(destination: MyServiceApplicationsView()) {
                                    ProfileRow(icon: "bolt.shield.fill", title: "达人申请", color: Color.purple)
                                }
                                Divider().padding(.leading, 56)
                                NavigationLink(destination: SettingsView()) {
                                    ProfileRow(icon: "gearshape.fill", title: "设置中心", color: Color.gray)
                                }
                            }
                            .background(AppColors.cardBackground)
                            .cornerRadius(AppCornerRadius.large)
                            .shadow(color: Color.black.opacity(0.03), radius: 10, x: 0, y: 5)
                        }
                        .padding(.horizontal, AppSpacing.md)
                        
                        // 退出按钮：醒目的卡片
                        Button(action: { showLogoutAlert = true }) {
                            HStack {
                                Image(systemName: "power")
                                    .fontWeight(.bold)
                                Text("退出当前账号")
                                    .fontWeight(.bold)
                            }
                            .foregroundColor(AppColors.error)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(AppColors.error.opacity(0.08))
                            .cornerRadius(AppCornerRadius.large)
                            .overlay(
                                RoundedRectangle(cornerRadius: AppCornerRadius.large)
                                    .strokeBorder(AppColors.error.opacity(0.2), lineWidth: 1)
                            )
                        }
                        .padding(.horizontal, AppSpacing.md)
                        .padding(.top, 8)
                        .padding(.bottom, 40)
                    }
                }
            }
            .navigationBarHidden(true)
            .alert("退出确认", isPresented: $showLogoutAlert) {
                Button("取消", role: .cancel) {}
                Button("确定退出", role: .destructive) { appState.logout() }
            } message: {
                Text("您确定要退出当前登录的账号吗？")
            }
        }
    }
}

// 数据统计项组件
struct StatItem: View {
    let title: String
    let value: String
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(AppColors.textPrimary)
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// 个人中心行组件：优化图标容器和间距
struct ProfileRow: View {
    let icon: String
    let title: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(color.opacity(0.12))
                    .frame(width: 38, height: 38)
                
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.system(size: 16, weight: .bold))
            }
            
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(AppColors.textPrimary)
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(AppColors.textTertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}
