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
                                    Text(appState.currentUser?.name ?? LocalizationKey.profileUser.localized)
                                        .font(AppTypography.title2)
                                        .foregroundColor(AppColors.textPrimary)
                                    
                                    if let email = appState.currentUser?.email, !email.isEmpty {
                                        Text(email)
                                            .font(AppTypography.subheadline)
                                            .foregroundColor(AppColors.textSecondary)
                                    } else if let phone = appState.currentUser?.phone, !phone.isEmpty {
                                        Text(phone)
                                            .font(AppTypography.subheadline)
                                            .foregroundColor(AppColors.textSecondary)
                                    }
                                    
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
                                            title: LocalizationKey.profileMyTasks.localized,
                                            subtitle: LocalizationKey.profileMyTasksSubtitle.localized,
                                            color: AppColors.primary
                                        )
                                    }
                                    .buttonStyle(ScaleButtonStyle())
                                    .cardStyle()
                                    
                                    NavigationLink(destination: MyPostsView()) {
                                        ProfileRow(
                                            icon: "cart.fill",
                                            title: LocalizationKey.profileMyPosts.localized,
                                            subtitle: LocalizationKey.profileMyPostsSubtitle.localized,
                                            color: AppColors.warning
                                        )
                                    }
                                    .buttonStyle(ScaleButtonStyle())
                                    .cardStyle()
                                    
                                    NavigationLink(destination: WalletView()) {
                                        ProfileRow(
                                            icon: "wallet.pass.fill",
                                            title: LocalizationKey.profileMyWallet.localized,
                                            subtitle: LocalizationKey.profileMyWalletSubtitle.localized,
                                            color: AppColors.success
                                        )
                                    }
                                    .buttonStyle(ScaleButtonStyle())
                                    .cardStyle()
                                    
                                    NavigationLink(destination: MyServiceApplicationsView()) {
                                        ProfileRow(
                                            icon: "hand.raised.fill",
                                            title: LocalizationKey.profileMyApplications.localized,
                                            subtitle: LocalizationKey.profileMyApplicationsSubtitle.localized,
                                            color: Color.purple
                                        )
                                    }
                                    .buttonStyle(ScaleButtonStyle())
                                    .cardStyle()
                                    
                                    NavigationLink(destination: CouponPointsView()) {
                                        ProfileRow(
                                            icon: "star.fill",
                                            title: LocalizationKey.profilePointsCoupons.localized,
                                            subtitle: LocalizationKey.profilePointsCouponsSubtitle.localized,
                                            color: Color.orange
                                        )
                                    }
                                    .buttonStyle(ScaleButtonStyle())
                                    .cardStyle()
                                    
                                    NavigationLink(destination: StudentVerificationView()) {
                                        ProfileRow(
                                            icon: "person.badge.shield.checkmark.fill",
                                            title: LocalizationKey.profileStudentVerification.localized,
                                            subtitle: LocalizationKey.profileStudentVerificationSubtitle.localized,
                                            color: Color.blue
                                        )
                                    }
                                    .buttonStyle(ScaleButtonStyle())
                                    .cardStyle()
                                    
                                    NavigationLink(destination: ActivityListView()) {
                                        ProfileRow(
                                            icon: "calendar.badge.plus",
                                            title: LocalizationKey.profileActivity.localized,
                                            subtitle: LocalizationKey.profileActivitySubtitle.localized,
                                            color: Color.green
                                        )
                                    }
                                    .buttonStyle(ScaleButtonStyle())
                                    .cardStyle()
                                    
                                    NavigationLink(destination: SettingsView()) {
                                        ProfileRow(
                                            icon: "gearshape.fill",
                                            title: LocalizationKey.profileSettings.localized,
                                            subtitle: LocalizationKey.profileSettingsSubtitle.localized,
                                            color: AppColors.textSecondary
                                        )
                                    }
                                    .buttonStyle(ScaleButtonStyle())
                                    .cardStyle()
                                }
                            }
                            .padding(.horizontal, AppSpacing.md)
                            .padding(.vertical, AppSpacing.md)
                            
                            // 退出登录按钮 - 现代化破坏性操作设计
                            Button(action: {
                                HapticFeedback.warning()
                                showLogoutAlert = true
                            }) {
                                HStack(spacing: 8) {
                                    IconStyle.icon("rectangle.portrait.and.arrow.right", size: 18, weight: .semibold)
                                    Text(LocalizationKey.profileLogout.localized)
                                        .font(AppTypography.bodyBold)
                                }
                                .foregroundColor(AppColors.error)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(AppColors.error.opacity(0.08))
                                .cornerRadius(AppCornerRadius.large)
                                .overlay(
                                    RoundedRectangle(cornerRadius: AppCornerRadius.large)
                                        .stroke(AppColors.error.opacity(0.15), lineWidth: 1)
                                )
                            }
                            .buttonStyle(ScaleButtonStyle())
                            .padding(.top, AppSpacing.xl)
                            .padding(.horizontal, AppSpacing.md)
                            .padding(.bottom, AppSpacing.xxl)
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
                            Text(LocalizationKey.profileWelcome.localized)
                                .font(AppTypography.title2)
                                .foregroundColor(AppColors.textPrimary)
                            
                            Text(LocalizationKey.profileLoginPrompt.localized)
                                .font(AppTypography.subheadline)
                                .foregroundColor(AppColors.textSecondary)
                        }
                        
                        Spacer()
                        
                        // 登录按钮 - 渐变设计
                        Button(action: {
                            showLogin = true
                        }) {
                            HStack(spacing: AppSpacing.sm) {
                                Text(LocalizationKey.authLogin.localized)
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
            .navigationTitle(LocalizationKey.tabsProfile.localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppColors.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                if appState.isAuthenticated {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        NavigationLink(destination: EditProfileView(viewModel: EditProfileViewModel(currentUser: appState.currentUser))) {
                            Image(systemName: "pencil")
                                .foregroundColor(AppColors.primary)
                        }
                    }
                }
            }
            .sheet(isPresented: $showLogin) {
                LoginView()
            }
            .alert(LocalizationKey.profileConfirmLogout.localized, isPresented: $showLogoutAlert) {
                Button(LocalizationKey.commonCancel.localized, role: .cancel) {}
                Button(LocalizationKey.profileLogout.localized, role: .destructive) {
                    appState.logout()
                }
            } message: {
                Text(LocalizationKey.profileLogoutMessage.localized)
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
