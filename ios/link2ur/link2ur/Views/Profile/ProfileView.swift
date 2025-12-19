import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var appState: AppState
    @State private var showLogoutAlert = false
    @State private var showLogin = false
    
    var body: some View {
        NavigationView {
            ZStack {
                AppColors.background
                    .ignoresSafeArea()
                
                if appState.isAuthenticated {
                    // 已登录：显示用户信息和功能菜单
                    ScrollView {
                        VStack(spacing: 0) {
                            // 用户信息卡片（顶部大卡片）- 更现代的设计
                            VStack(spacing: AppSpacing.lg) {
                                // 头像 - 带渐变边框
                                ZStack {
                                    // 外层渐变圆圈
                                    Circle()
                                        .fill(
                                            LinearGradient(
                                                gradient: Gradient(colors: AppColors.gradientPrimary),
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .frame(width: 110, height: 110)
                                        .shadow(color: AppColors.primary.opacity(0.4), radius: 16, x: 0, y: 8)
                                    
                                    // 内层白色圆圈
                                    Circle()
                                        .fill(Color.white)
                                        .frame(width: 104, height: 104)
                                    
                                    AvatarView(
                                        urlString: appState.currentUser?.avatar,
                                        size: 100,
                                        placeholder: Image(systemName: "person.fill")
                                    )
                                }
                                
                                // 用户名和邮箱 - 符合 HIG
                                VStack(spacing: AppSpacing.sm) {
                                    Text(appState.currentUser?.name ?? "用户")
                                        .font(AppTypography.title2)
                                        .foregroundColor(AppColors.textPrimary)
                                    
                                    Text(appState.currentUser?.email ?? "")
                                        .font(AppTypography.subheadline)
                                        .foregroundColor(AppColors.textSecondary)
                                    
                                    // 用户等级标签 - 渐变设计
                                    if let userLevel = appState.currentUser?.userLevel {
                                        Text(userLevel.uppercased())
                                            .font(AppTypography.caption)
                                            .fontWeight(.bold)
                                            .foregroundColor(.white)
                                            .padding(.horizontal, AppSpacing.md)
                                            .padding(.vertical, 6)
                                            .background(
                                                Capsule()
                                                    .fill(
                                                        LinearGradient(
                                                            gradient: Gradient(colors: AppColors.gradientWarning),
                                                            startPoint: .leading,
                                                            endPoint: .trailing
                                                        )
                                                    )
                                            )
                                            .shadow(color: AppColors.warning.opacity(0.3), radius: 8, x: 0, y: 4)
                                    }
                                }
                            }
                            .padding(.vertical, AppSpacing.xl)
                            .padding(.horizontal, AppSpacing.md)
                            .frame(maxWidth: .infinity)
                            .background(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        AppColors.primary.opacity(0.12),
                                        AppColors.primary.opacity(0.06),
                                        AppColors.primary.opacity(0.02)
                                    ]),
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            
                            // 功能列表 - 符合 HIG
                            VStack(spacing: AppSpacing.sm) {
                                Group {
                                    NavigationLink(destination: MyTasksView()) {
                                        ProfileRow(
                                            icon: "doc.text.fill",
                                            title: "我的任务",
                                            subtitle: "查看我发布和接取的任务",
                                            color: AppColors.primary
                                        )
                                    }
                                    .buttonStyle(ScaleButtonStyle())
                                    .cardStyle()
                                    
                                    NavigationLink(destination: MyPostsView()) {
                                        ProfileRow(
                                            icon: "cart.fill",
                                            title: "我的发布",
                                            subtitle: "查看我发布的内容",
                                            color: AppColors.warning
                                        )
                                    }
                                    .buttonStyle(ScaleButtonStyle())
                                    .cardStyle()
                                    
                                    NavigationLink(destination: WalletView()) {
                                        ProfileRow(
                                            icon: "wallet.pass.fill",
                                            title: "我的钱包",
                                            subtitle: "查看余额和交易记录",
                                            color: AppColors.success
                                        )
                                    }
                                    .buttonStyle(ScaleButtonStyle())
                                    .cardStyle()
                                    
                                    NavigationLink(destination: MyServiceApplicationsView()) {
                                        ProfileRow(
                                            icon: "hand.raised.fill",
                                            title: "我的申请",
                                            subtitle: "查看服务申请记录",
                                            color: Color.purple
                                        )
                                    }
                                    .buttonStyle(ScaleButtonStyle())
                                    .cardStyle()
                                    
                                    NavigationLink(destination: CouponPointsView()) {
                                        ProfileRow(
                                            icon: "star.fill",
                                            title: "积分与优惠券",
                                            subtitle: "查看积分、优惠券和签到",
                                            color: Color.orange
                                        )
                                    }
                                    .buttonStyle(ScaleButtonStyle())
                                    .cardStyle()
                                    
                                    NavigationLink(destination: StudentVerificationView()) {
                                        ProfileRow(
                                            icon: "person.badge.shield.checkmark.fill",
                                            title: "学生认证",
                                            subtitle: "验证学生身份享受优惠",
                                            color: Color.blue
                                        )
                                    }
                                    .buttonStyle(ScaleButtonStyle())
                                    .cardStyle()
                                    
                                    NavigationLink(destination: ActivityListView()) {
                                        ProfileRow(
                                            icon: "calendar.badge.plus",
                                            title: "活动",
                                            subtitle: "查看和参加活动",
                                            color: Color.green
                                        )
                                    }
                                    .buttonStyle(ScaleButtonStyle())
                                    .cardStyle()
                                    
                                    NavigationLink(destination: SettingsView()) {
                                        ProfileRow(
                                            icon: "gearshape.fill",
                                            title: "设置",
                                            subtitle: "应用设置和偏好",
                                            color: AppColors.textSecondary
                                        )
                                    }
                                    .buttonStyle(ScaleButtonStyle())
                                    .cardStyle()
                                }
                            }
                            .padding(.horizontal, AppSpacing.md)
                            .padding(.vertical, AppSpacing.md)
                            
                            // 退出登录按钮 - 符合 HIG
                            Button(action: {
                                showLogoutAlert = true
                            }) {
                                HStack {
                                    Spacer()
                                    Text("退出登录")
                                        .font(AppTypography.body)
                                        .fontWeight(.medium)
                                        .foregroundColor(AppColors.error)
                                    Spacer()
                                }
                                .padding(.vertical, AppSpacing.md)
                                .background(AppColors.cardBackground)
                                .cornerRadius(AppCornerRadius.medium)
                            }
                            .buttonStyle(ScaleButtonStyle())
                            .padding(.top, AppSpacing.lg)
                            .padding(.horizontal, AppSpacing.md)
                            .padding(.bottom, AppSpacing.xl)
                        }
                    }
                } else {
                    // 未登录：显示登录界面
                    VStack(spacing: AppSpacing.xl) {
                        Spacer()
                        
                        // Logo
                        Image("Logo")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 120, height: 120)
                            .padding(.bottom, AppSpacing.lg)
                        
                        // 欢迎文字 - 符合 HIG
                        VStack(spacing: AppSpacing.sm) {
                            Text("欢迎使用 Link²Ur")
                                .font(AppTypography.title2)
                                .foregroundColor(AppColors.textPrimary)
                            
                            Text("登录后即可使用全部功能")
                                .font(AppTypography.subheadline)
                                .foregroundColor(AppColors.textSecondary)
                        }
                        
                        Spacer()
                        
                        // 登录按钮 - 渐变设计
                        Button(action: {
                            showLogin = true
                        }) {
                            HStack(spacing: AppSpacing.sm) {
                                Text("登录")
                                    .font(AppTypography.bodyBold)
                                
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(
                                LinearGradient(
                                    gradient: Gradient(colors: AppColors.gradientPrimary),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(AppCornerRadius.large)
                            .shadow(color: AppColors.primary.opacity(0.3), radius: 12, x: 0, y: 6)
                        }
                        .buttonStyle(PrimaryButtonStyle(cornerRadius: AppCornerRadius.large, useGradient: true))
                        .padding(.horizontal, AppSpacing.xl)
                        .padding(.bottom, AppSpacing.xl)
                    }
                }
            }
            .navigationTitle("我的")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppColors.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .sheet(isPresented: $showLogin) {
                LoginView()
            }
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

// 个人中心行组件 - 更现代的设计
struct ProfileRow: View {
    let icon: String
    let title: String
    let subtitle: String?
    let color: Color
    
    var body: some View {
        HStack(spacing: AppSpacing.md) {
            // 图标容器 - 渐变背景
            ZStack {
                RoundedRectangle(cornerRadius: AppCornerRadius.medium)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [color.opacity(0.2), color.opacity(0.1)]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 48, height: 48)
                
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(color)
            }
            
            // 文本内容
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text(title)
                    .font(AppTypography.body)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.textPrimary)
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textSecondary)
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(AppColors.textTertiary)
        }
        .padding(AppSpacing.md)
        .background(AppColors.cardBackground)
        .cornerRadius(AppCornerRadius.large)
        .contentShape(Rectangle())
    }
}
