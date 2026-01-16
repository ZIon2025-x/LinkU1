import SwiftUI
import UserNotifications

/// 引导教程页面
struct OnboardingView: View {
    @Binding var isPresented: Bool
    @State private var currentPage = 0
    @State private var selectedCity: String = ""
    @State private var selectedTaskTypes: Set<String> = []
    @State private var notificationEnabled = false
    
    // 引导页面数据（使用本地化字符串）
    private var pages: [OnboardingPage] {
        [
            OnboardingPage(
                title: LocalizationKey.onboardingWelcomeTitle.localized,
                subtitle: LocalizationKey.onboardingWelcomeSubtitle.localized,
                description: LocalizationKey.onboardingWelcomeDescription.localized,
                imageName: "house.fill",
                color: AppColors.primary
            ),
            OnboardingPage(
                title: LocalizationKey.onboardingPublishTaskTitle.localized,
                subtitle: LocalizationKey.onboardingPublishTaskSubtitle.localized,
                description: LocalizationKey.onboardingPublishTaskDescription.localized,
                imageName: "plus.circle.fill",
                color: AppColors.success
            ),
            OnboardingPage(
                title: LocalizationKey.onboardingAcceptTaskTitle.localized,
                subtitle: LocalizationKey.onboardingAcceptTaskSubtitle.localized,
                description: LocalizationKey.onboardingAcceptTaskDescription.localized,
                imageName: "checkmark.circle.fill",
                color: AppColors.warning
            ),
            OnboardingPage(
                title: LocalizationKey.onboardingSecurePaymentTitle.localized,
                subtitle: LocalizationKey.onboardingSecurePaymentSubtitle.localized,
                description: LocalizationKey.onboardingSecurePaymentDescription.localized,
                imageName: "lock.shield.fill",
                color: AppColors.error
            ),
            OnboardingPage(
                title: LocalizationKey.onboardingCommunityTitle.localized,
                subtitle: LocalizationKey.onboardingCommunitySubtitle.localized,
                description: LocalizationKey.onboardingCommunityDescription.localized,
                imageName: "person.3.fill",
                color: AppColors.primary
            )
        ]
    }
    
    // 常用城市列表
    private let popularCities = [
        "London", "Birmingham", "Manchester", "Edinburgh", 
        "Glasgow", "Liverpool", "Bristol", "Leeds"
    ]
    
    // 任务类型列表（使用本地化的任务类型）
    private var taskTypes: [String] {
        [
            LocalizationKey.taskCategoryErrandRunning.localized,
            LocalizationKey.taskCategorySkillService.localized,
            LocalizationKey.taskCategoryHousekeeping.localized,
            LocalizationKey.taskCategoryTransportation.localized,
            LocalizationKey.taskCategorySocialHelp.localized,
            LocalizationKey.taskCategoryCampusLife.localized,
            LocalizationKey.taskCategorySecondhandRental.localized,
            LocalizationKey.taskCategoryPetCare.localized,
            LocalizationKey.taskCategoryLifeConvenience.localized,
            LocalizationKey.taskCategoryOther.localized
        ]
    }
    
    var body: some View {
        ZStack {
            // 背景渐变
            LinearGradient(
                gradient: Gradient(colors: [
                    AppColors.background,
                    AppColors.background.opacity(0.8)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 跳过按钮
                HStack {
                    Spacer()
                    Button(action: {
                        skipOnboarding()
                    }) {
                        Text(LocalizationKey.onboardingSkip.localized)
                            .font(AppTypography.body)
                            .foregroundColor(AppColors.textSecondary)
                            .padding(.horizontal, AppSpacing.md)
                            .padding(.vertical, AppSpacing.sm)
                    }
                }
                .padding(.top, AppSpacing.md)
                .padding(.trailing, AppSpacing.md)
                
                // 主要内容区域
                TabView(selection: $currentPage) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                        OnboardingPageView(page: page)
                            .tag(index)
                    }
                    
                    // 个性化设置页面
                    PersonalizationPageView(
                        selectedCity: $selectedCity,
                        selectedTaskTypes: $selectedTaskTypes,
                        notificationEnabled: $notificationEnabled,
                        popularCities: popularCities,
                        taskTypes: taskTypes
                    )
                    .tag(pages.count)
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .indexViewStyle(.page(backgroundDisplayMode: .always))
                
                // 底部按钮
                HStack(spacing: AppSpacing.md) {
                    if currentPage > 0 {
                        Button(action: {
                            withAnimation {
                                currentPage -= 1
                            }
                        }) {
                            HStack {
                                Image(systemName: "chevron.left")
                                Text(LocalizationKey.onboardingPrevious.localized)
                            }
                            .font(AppTypography.body)
                            .foregroundColor(AppColors.textPrimary)
                            .padding(.horizontal, AppSpacing.lg)
                            .padding(.vertical, AppSpacing.md)
                            .background(AppColors.background)
                            .cornerRadius(AppCornerRadius.medium)
                            .overlay(
                                RoundedRectangle(cornerRadius: AppCornerRadius.medium)
                                    .stroke(AppColors.separator, lineWidth: 1)
                            )
                        }
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        if currentPage < pages.count {
                            // 下一页
                            withAnimation {
                                currentPage += 1
                            }
                        } else {
                            // 完成
                            completeOnboarding()
                        }
                    }) {
                        HStack {
                            Text(currentPage < pages.count ? LocalizationKey.commonNext.localized : LocalizationKey.onboardingGetStarted.localized)
                            if currentPage < pages.count {
                                Image(systemName: "chevron.right")
                            }
                        }
                        .font(AppTypography.body)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, AppSpacing.lg)
                        .padding(.vertical, AppSpacing.md)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: AppColors.gradientPrimary),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(AppCornerRadius.medium)
                    }
                }
                .padding(.horizontal, AppSpacing.lg)
                .padding(.bottom, AppSpacing.xl)
            }
        }
        .onAppear {
            // 设置默认值
            if selectedCity.isEmpty {
                selectedCity = "London"
            }
        }
    }
    
    // 跳过引导
    private func skipOnboarding() {
        UserDefaults.standard.set(true, forKey: "has_seen_onboarding")
        isPresented = false
        HapticFeedback.selection()
    }
    
    // 完成引导
    private func completeOnboarding() {
        // 保存个性化设置
        UserDefaults.standard.set(selectedCity, forKey: "preferred_city")
        UserDefaults.standard.set(Array(selectedTaskTypes), forKey: "preferred_task_types")
        
        // 标记已看过引导
        UserDefaults.standard.set(true, forKey: "has_seen_onboarding")
        
        // 如果用户选择了启用通知，请求通知权限
        if notificationEnabled {
            requestNotificationPermission()
        }
        
        isPresented = false
        HapticFeedback.success()
    }
    
    // 请求通知权限
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            DispatchQueue.main.async {
                if granted {
                    UIApplication.shared.registerForRemoteNotifications()
                    print("✅ 通知权限已授予")
                } else {
                    print("⚠️ 通知权限被拒绝")
                }
            }
        }
    }
}

// MARK: - 引导页面数据模型

struct OnboardingPage {
    let title: String
    let subtitle: String
    let description: String
    let imageName: String
    let color: Color
}

// MARK: - 引导页面视图

struct OnboardingPageView: View {
    let page: OnboardingPage
    
    var body: some View {
        VStack(spacing: AppSpacing.xl) {
            Spacer()
            
            // 图标
            ZStack {
                Circle()
                    .fill(page.color.opacity(0.1))
                    .frame(width: 120, height: 120)
                
                Image(systemName: page.imageName)
                    .font(.system(size: 60))
                    .foregroundColor(page.color)
            }
            .padding(.bottom, AppSpacing.lg)
            
            // 标题
            VStack(spacing: AppSpacing.sm) {
                Text(page.title)
                    .font(AppTypography.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(AppColors.textPrimary)
                    .multilineTextAlignment(.center)
                
                Text(page.subtitle)
                    .font(AppTypography.title2)
                    .foregroundColor(page.color)
                    .multilineTextAlignment(.center)
            }
            
            // 描述
            Text(page.description)
                .font(AppTypography.body)
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppSpacing.xl)
                .lineSpacing(4)
            
            Spacer()
        }
        .padding(.horizontal, AppSpacing.lg)
    }
}

// MARK: - 个性化设置页面

struct PersonalizationPageView: View {
    @Binding var selectedCity: String
    @Binding var selectedTaskTypes: Set<String>
    @Binding var notificationEnabled: Bool
    let popularCities: [String]
    let taskTypes: [String]
    
    @ObservedObject private var locationService = LocationService.shared
    @State private var isGettingLocation = false
    @State private var locationError: String?
    
    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.xl) {
                Spacer()
                    .frame(height: 40)
                
                // 标题
                VStack(spacing: AppSpacing.sm) {
                    Text(LocalizationKey.onboardingPersonalizationTitle.localized)
                        .font(AppTypography.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.textPrimary)
                    
                    Text(LocalizationKey.onboardingPersonalizationSubtitle.localized)
                        .font(AppTypography.body)
                        .foregroundColor(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.bottom, AppSpacing.lg)
                
                // 选择常用城市
                VStack(alignment: .leading, spacing: AppSpacing.md) {
                    HStack {
                        Text(LocalizationKey.onboardingPreferredCity.localized)
                            .font(AppTypography.title3)
                            .foregroundColor(AppColors.textPrimary)
                        
                        Spacer()
                        
                        // 获取当前位置按钮
                        Button(action: {
                            getCurrentLocation()
                        }) {
                            HStack(spacing: 4) {
                                if isGettingLocation {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                        .progressViewStyle(CircularProgressViewStyle(tint: AppColors.primary))
                                } else {
                                    Image(systemName: "location.fill")
                                        .font(.system(size: 12))
                                }
                                Text(LocalizationKey.onboardingUseCurrentLocation.localized)
                                    .font(AppTypography.caption)
                            }
                            .foregroundColor(AppColors.primary)
                            .padding(.horizontal, AppSpacing.sm)
                            .padding(.vertical, 6)
                            .background(AppColors.primary.opacity(0.1))
                            .cornerRadius(AppCornerRadius.small)
                        }
                        .disabled(isGettingLocation)
                    }
                    
                    // 错误提示
                    if let error = locationError {
                        Text(error)
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.error)
                            .padding(.top, 4)
                    }
                    
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: AppSpacing.sm) {
                        ForEach(popularCities, id: \.self) { city in
                            Button(action: {
                                selectedCity = city
                                locationError = nil // 清除错误提示
                                HapticFeedback.selection()
                            }) {
                                Text(city)
                                    .font(AppTypography.body)
                                    .foregroundColor(selectedCity == city ? .white : AppColors.textPrimary)
                                    .padding(.horizontal, AppSpacing.md)
                                    .padding(.vertical, AppSpacing.sm)
                                    .background(
                                        selectedCity == city ?
                                        LinearGradient(
                                            gradient: Gradient(colors: AppColors.gradientPrimary),
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        ) : nil
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: AppCornerRadius.small)
                                            .stroke(
                                                selectedCity == city ? Color.clear : AppColors.separator,
                                                lineWidth: 1
                                            )
                                    )
                                    .cornerRadius(AppCornerRadius.small)
                            }
                        }
                    }
                }
                .padding(.horizontal, AppSpacing.lg)
                .onChange(of: locationService.currentCityName) { cityName in
                    // 当获取到城市名称时，自动设置为选中城市
                    if isGettingLocation, let cityName = cityName, !cityName.isEmpty {
                        selectedCity = cityName
                        isGettingLocation = false
                        locationError = nil
                        HapticFeedback.success()
                    }
                }
                .onChange(of: locationService.authorizationStatus) { status in
                    // 当权限状态变化时，如果已授权且正在获取位置，则请求位置
                    if isGettingLocation && (status == .authorizedWhenInUse || status == .authorizedAlways) {
                        // 如果已经有当前城市名称，直接使用
                        if let currentCity = locationService.currentCityName, !currentCity.isEmpty {
                            selectedCity = currentCity
                            isGettingLocation = false
                            locationError = nil
                            HapticFeedback.success()
                        } else {
                            // 请求位置
                            locationService.requestLocation()
                        }
                    }
                }
                
                // 选择感兴趣的任务类型
                VStack(alignment: .leading, spacing: AppSpacing.md) {
                    Text(LocalizationKey.onboardingPreferredTaskTypesOptional.localized)
                        .font(AppTypography.title3)
                        .foregroundColor(AppColors.textPrimary)
                    
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: AppSpacing.sm) {
                        ForEach(taskTypes, id: \.self) { taskType in
                            Button(action: {
                                if selectedTaskTypes.contains(taskType) {
                                    selectedTaskTypes.remove(taskType)
                                } else {
                                    selectedTaskTypes.insert(taskType)
                                }
                                HapticFeedback.selection()
                            }) {
                                Text(taskType)
                                    .font(AppTypography.body)
                                    .foregroundColor(selectedTaskTypes.contains(taskType) ? .white : AppColors.textPrimary)
                                    .padding(.horizontal, AppSpacing.md)
                                    .padding(.vertical, AppSpacing.sm)
                                    .background(
                                        selectedTaskTypes.contains(taskType) ?
                                        LinearGradient(
                                            gradient: Gradient(colors: AppColors.gradientPrimary),
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        ) : nil
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: AppCornerRadius.small)
                                            .stroke(
                                                selectedTaskTypes.contains(taskType) ? Color.clear : AppColors.separator,
                                                lineWidth: 1
                                            )
                                    )
                                    .cornerRadius(AppCornerRadius.small)
                            }
                        }
                    }
                }
                .padding(.horizontal, AppSpacing.lg)
                
                // 通知权限
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    HStack {
                        VStack(alignment: .leading, spacing: AppSpacing.xs) {
                            Text(LocalizationKey.onboardingEnableNotifications.localized)
                                .font(AppTypography.title3)
                                .foregroundColor(AppColors.textPrimary)
                            
                            Text(LocalizationKey.onboardingEnableNotificationsDescription.localized)
                                .font(AppTypography.caption)
                                .foregroundColor(AppColors.textSecondary)
                        }
                        
                        Spacer()
                        
                        Toggle("", isOn: $notificationEnabled)
                            .labelsHidden()
                    }
                    .padding(.horizontal, AppSpacing.lg)
                    .padding(.vertical, AppSpacing.md)
                    .background(AppColors.background)
                    .cornerRadius(AppCornerRadius.medium)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppCornerRadius.medium)
                            .stroke(AppColors.separator, lineWidth: 1)
                    )
                }
                .padding(.horizontal, AppSpacing.lg)
                
                Spacer()
                    .frame(height: 100)
            }
        }
    }
    
    /// 获取当前位置
    private func getCurrentLocation() {
        isGettingLocation = true
        locationError = nil
        
        // 检查权限状态
        if !locationService.isAuthorized {
            // 请求位置权限
            locationService.requestAuthorization()
            
            // 设置超时，如果5秒后仍然没有权限，显示错误
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                if !locationService.isAuthorized && isGettingLocation {
                    isGettingLocation = false
                    locationError = "需要位置权限才能使用当前位置"
                }
            }
            return
        }
        
        // 如果已经有当前城市名称，直接使用
        if let currentCity = locationService.currentCityName, !currentCity.isEmpty {
            selectedCity = currentCity
            isGettingLocation = false
            locationError = nil
            HapticFeedback.success()
            return
        }
        
        // 请求位置
        locationService.requestLocation()
        
        // 设置超时，如果10秒后仍然没有获取到位置，显示错误
        DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) {
            if isGettingLocation {
                isGettingLocation = false
                if locationService.currentCityName == nil || locationService.currentCityName?.isEmpty == true {
                    locationError = "获取位置超时，请重试或手动选择城市"
                }
            }
        }
    }
}

// MARK: - 预览

struct OnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingView(isPresented: .constant(true))
    }
}
