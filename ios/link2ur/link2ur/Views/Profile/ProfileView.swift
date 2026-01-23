import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var tasksViewModel = MyTasksViewModel()
    @State private var showLogoutAlert = false
    @State private var showLogin = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                backgroundView
                
                if appState.isAuthenticated {
                    authenticatedContent
                } else {
                    unauthenticatedContent
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
    
    // MARK: - 子视图
    
    private var backgroundView: some View {
        ZStack {
            AppColors.background
                .ignoresSafeArea()
            
            VStack {
                LinearGradient(colors: [AppColors.primary.opacity(0.15), .clear], startPoint: .top, endPoint: .bottom)
                    .frame(height: 300)
                Spacer()
            }
            .ignoresSafeArea()
        }
    }
    
    private var authenticatedContent: some View {
        ScrollView {
            VStack(spacing: 24) {
                userInfoSection
                statsSection
                myContentSection
                systemSection
                logoutButton
            }
            .padding(.bottom, 20)
        }
    }
    
    private var userInfoSection: some View {
        VStack(spacing: AppSpacing.lg) {
            ZStack {
                Circle()
                    .fill(.white)
                    .frame(width: 104, height: 104)
                    .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 5)
                
                AvatarView(
                    urlString: appState.currentUser?.avatar,
                    size: 96,
                    placeholder: Image(systemName: "person.crop.circle.fill")
                )
                .clipShape(Circle())
            }
            
            VStack(spacing: 6) {
                HStack(spacing: 8) {
                    Text(appState.currentUser?.name ?? LocalizationKey.profileUser.localized)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(AppColors.textPrimary)
                    
                    if let isVerified = appState.currentUser?.isVerified, isVerified == 1 {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(.blue)
                            .font(.system(size: 18))
                    }
                }
                
                Text(appState.currentUser?.email ?? appState.currentUser?.phone ?? LocalizationKey.profileNoContactInfo.localized)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppColors.textSecondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(AppColors.primary.opacity(0.05))
                    .cornerRadius(20)
            }
        }
        .padding(.top, 40)
        .padding(.horizontal, AppSpacing.md)
        .frame(maxWidth: .infinity)
    }
    
    private var statsSection: some View {
        HStack(spacing: 0) {
            NavigationLink(destination: MyTasksView(initialTab: .inProgress)) {
                StatItem(label: LocalizationKey.profileInProgress.localized, value: "\(tasksViewModel.inProgressTasksCount)", color: AppColors.primary)
            }
            .buttonStyle(PlainButtonStyle())
            Divider().frame(height: 30)
            NavigationLink(destination: MyTasksView(initialTab: .completed)) {
                StatItem(label: LocalizationKey.profileCompleted.localized, value: "\(tasksViewModel.completedTasksCount)", color: AppColors.success)
            }
            .buttonStyle(PlainButtonStyle())
            Divider().frame(height: 30)
            StatItem(
                label: LocalizationKey.profileCreditScore.localized,
                value: creditScoreDisplay,
                color: AppColors.warning
            )
        }
        .padding(.vertical, 16)
        .background(AppColors.cardBackground)
        .cornerRadius(AppCornerRadius.large)
        .padding(.horizontal, AppSpacing.md)
        .shadow(color: Color.black.opacity(0.03), radius: 10, x: 0, y: 5)
        .onAppear {
            // 当视图出现时，加载任务数据以获取准确的统计
            if let userId = appState.currentUser?.id {
                tasksViewModel.currentUserId = String(userId)
                tasksViewModel.loadTasks(forceRefresh: false)
            }
        }
        .onChange(of: appState.currentUser?.id) { newUserId in
            // 当用户ID变化时更新
            if let userId = newUserId {
                tasksViewModel.currentUserId = String(userId)
                tasksViewModel.loadTasks(forceRefresh: false)
            }
        }
    }
    
    private var myContentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(LocalizationKey.profileMyContent.localized)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(AppColors.textPrimary)
                .padding(.horizontal, AppSpacing.sm)
            
            VStack(spacing: 0) {
                NavigationLink(destination: MyTasksView()) {
                    ProfileRow(icon: "list.bullet.rectangle.fill", title: LocalizationKey.profileMyTasks.localized, subtitle: LocalizationKey.profileMyTasksSubtitleText.localized, color: AppColors.primary)
                }
                Divider().padding(.leading, 56)
                
                NavigationLink(destination: MyPostsView()) {
                    ProfileRow(icon: "shippingbox.fill", title: LocalizationKey.profileMyPosts.localized, subtitle: LocalizationKey.profileMyPostsSubtitleText.localized, color: Color.orange)
                }
                Divider().padding(.leading, 56)
                
                NavigationLink(destination: MyForumPostsView()) {
                    ProfileRow(icon: "doc.text.fill", title: LocalizationKey.profileMyForumPosts.localized, subtitle: LocalizationKey.profileMyForumPostsSubtitle.localized, color: Color.blue)
                }
                Divider().padding(.leading, 56)
                
                NavigationLink(destination: WalletView()) {
                    ProfileRow(icon: "creditcard.fill", title: LocalizationKey.profileMyWallet.localized, subtitle: LocalizationKey.profileMyWalletSubtitleText.localized, color: AppColors.success)
                }
                Divider().padding(.leading, 56)
                
                NavigationLink(destination: MyServiceApplicationsView()) {
                    ProfileRow(icon: "bolt.shield.fill", title: LocalizationKey.profileMyApplications.localized, subtitle: LocalizationKey.profileMyApplicationsSubtitleText.localized, color: Color.purple)
                }
            }
            .background(AppColors.cardBackground)
            .cornerRadius(AppCornerRadius.large)
            .shadow(color: Color.black.opacity(0.03), radius: 10, x: 0, y: 5)
        }
        .padding(.horizontal, AppSpacing.md)
    }
    
    private var systemSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(LocalizationKey.profileSystemAndVerification.localized)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(AppColors.textPrimary)
                .padding(.horizontal, AppSpacing.sm)
            
            VStack(spacing: 0) {
                NavigationLink(destination: StudentVerificationView()) {
                    ProfileRow(icon: "graduationcap.fill", title: LocalizationKey.profileStudentVerification.localized, subtitle: LocalizationKey.profileStudentVerificationSubtitleText.localized, color: Color.indigo)
                }
                Divider().padding(.leading, 56)
                
                NavigationLink(destination: ActivityListView()) {
                    ProfileRow(icon: "calendar.badge.clock", title: LocalizationKey.profileActivity.localized, subtitle: LocalizationKey.profileActivitySubtitleText.localized, color: Color.orange)
                }
                Divider().padding(.leading, 56)
                
                NavigationLink(destination: TaskPreferencesView()) {
                    ProfileRow(icon: "heart.text.square.fill", title: LocalizationKey.profileTaskPreferences.localized, subtitle: LocalizationKey.profileTaskPreferencesSubtitle.localized, color: Color.red)
                }
                Divider().padding(.leading, 56)
                
                NavigationLink(destination: CouponPointsView()) {
                    ProfileRow(icon: "ticket.fill", title: LocalizationKey.profilePointsCoupons.localized, subtitle: LocalizationKey.profilePointsCouponsSubtitleText.localized, color: Color.pink)
                }
                Divider().padding(.leading, 56)
                
                NavigationLink(destination: SettingsView()) {
                    ProfileRow(icon: "gearshape.fill", title: LocalizationKey.profileSettings.localized, subtitle: LocalizationKey.profileSettingsSubtitleText.localized, color: Color.gray)
                }
            }
            .background(AppColors.cardBackground)
            .cornerRadius(AppCornerRadius.large)
            .shadow(color: Color.black.opacity(0.03), radius: 10, x: 0, y: 5)
        }
        .padding(.horizontal, AppSpacing.md)
    }
    
    /// 信用分显示值（百分制）
    /// 直接使用平均评分转换为百分制，后续由后端计算
    private var creditScoreDisplay: String {
        guard let avgRating = appState.currentUser?.avgRating, avgRating > 0 else {
            return "--"
        }
        
        // 将 0-5 分制的平均评分转换为 0-100 分制
        // 例如：5.0 分 = 100 分，4.0 分 = 80 分，3.0 分 = 60 分
        let creditScore = (avgRating / 5.0) * 100.0
        
        return "\(Int(creditScore))"
    }
    
    private var logoutButton: some View {
        Button(action: {
            HapticFeedback.warning()
            showLogoutAlert = true
        }) {
            HStack(spacing: 8) {
                Image(systemName: "power")
                    .fontWeight(.bold)
                Text(LocalizationKey.profileLogout.localized)
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
        .buttonStyle(ScaleButtonStyle())
        .padding(.top, 8)
        .padding(.horizontal, AppSpacing.md)
        .padding(.bottom, 40)
    }
    
    private var unauthenticatedContent: some View {
        VStack(spacing: AppSpacing.xl) {
            Spacer()
            
            Image("Logo")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 120, height: 120)
                .padding(.bottom, AppSpacing.lg)
            
            VStack(spacing: AppSpacing.sm) {
                Text(LocalizationKey.profileWelcome.localized)
                    .font(AppTypography.title2)
                    .foregroundColor(AppColors.textPrimary)
                
                Text(LocalizationKey.profileLoginPrompt.localized)
                    .font(AppTypography.subheadline)
                    .foregroundColor(AppColors.textSecondary)
            }
            
            Spacer()
            
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

// 个人中心行组件 - 更现代的设计
struct ProfileRow: View {
    let icon: String
    let title: String
    let subtitle: String?
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

