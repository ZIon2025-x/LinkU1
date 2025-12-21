import SwiftUI
import CoreLocation
import Combine

struct HomeView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedTab = 1 // 0: 达人, 1: 推荐, 2: 附近
    @State private var showMenu = false
    @State private var showSearch = false
    
    // 监听重置通知
    private let resetNotification = NotificationCenter.default.publisher(for: .resetHomeView)
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.background
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // 自定义顶部导航栏（符合 Apple HIG，使用系统背景和间距）
                    HStack(spacing: 0) {
                        // 左侧汉堡菜单（使用 SF Symbols）
                        Button(action: {
                            showMenu = true
                        }) {
                            IconStyle.icon("line.3.horizontal", size: IconStyle.medium)
                                .foregroundColor(AppColors.textPrimary)
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
                        }
                        
                        Spacer()
                        
                        // 中间三个标签（符合 HIG 间距）
                        HStack(spacing: 0) {
                            TabButton(title: LocalizationKey.homeExperts.localized, isSelected: selectedTab == 0) {
                                if selectedTab != 0 {
                                    HapticFeedback.selection()
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        selectedTab = 0
                                    }
                                }
                            }
                            
                            TabButton(title: LocalizationKey.homeRecommended.localized, isSelected: selectedTab == 1) {
                                if selectedTab != 1 {
                                    HapticFeedback.selection()
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        selectedTab = 1
                                    }
                                }
                            }
                            
                            TabButton(title: LocalizationKey.homeNearby.localized, isSelected: selectedTab == 2) {
                                if selectedTab != 2 {
                                    HapticFeedback.selection()
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        selectedTab = 2
                                    }
                                }
                            }
                        }
                        .frame(maxWidth: 240)
                        
                        Spacer()
                        
                        // 右侧搜索图标（使用 SF Symbols）
                        Button(action: {
                            showSearch = true
                        }) {
                            IconStyle.icon("magnifyingglass", size: IconStyle.medium)
                                .foregroundColor(AppColors.textPrimary)
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
                        }
                    }
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.vertical, AppSpacing.sm)
                    .background(AppColors.background) // 使用系统背景
                    
                    // 内容区域
                    TabView(selection: $selectedTab) {
                        // 达人视图
                        TaskExpertListContentView()
                            .tag(0)
                        
                        // 推荐视图（原来的首页内容）
                        RecommendedContentView()
                            .tag(1)
                        
                        // 附近视图
                        NearbyTasksView()
                            .tag(2)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showMenu) {
                MenuView()
            }
            .sheet(isPresented: $showSearch) {
                SearchView()
            }
            .onReceive(resetNotification) { _ in
                // 重置到默认状态（推荐页面）
                withAnimation(.easeInOut(duration: 0.2)) {
                    selectedTab = 1
                }
            }
            .onChange(of: appState.shouldResetHomeView) { shouldReset in
                if shouldReset {
                    // 重置到默认状态（推荐页面）
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = 1
                    }
                    // 重置标志
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        appState.shouldResetHomeView = false
                    }
                }
            }
        }
    }
}

// 标签按钮组件（符合 Apple HIG）
struct TabButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Text(title)
                    .font(AppTypography.body) // 使用 body
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundColor(isSelected ? AppColors.textPrimary : AppColors.textSecondary)
                    .scaleEffect(isSelected ? 1.05 : 1.0)
                
                // 选中时的下划线（符合 HIG）
                ZStack {
                    Capsule()
                        .fill(isSelected ? AppColors.primary : Color.clear)
                        .frame(height: 3)
                        .frame(width: isSelected ? 28 : 0)
                }
                .frame(height: 3)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
            }
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .buttonStyle(PlainButtonStyle())
    }
}

// 推荐内容视图（原来的首页内容）
struct RecommendedContentView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.lg) {
                // 顶部欢迎区域（符合 Apple HIG，使用系统字体和间距）
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    HStack(alignment: .top, spacing: AppSpacing.md) {
                        VStack(alignment: .leading, spacing: AppSpacing.xs) {
                            Text(String(format: LocalizationKey.homeGreeting.localized, appState.currentUser?.name ?? LocalizationKey.appUser.localized))
                                .font(AppTypography.title2) // 使用 title2
                                .foregroundColor(AppColors.textPrimary)
                            
                            Text(LocalizationKey.homeWhatToDo.localized)
                                .font(AppTypography.body) // 使用 body
                                .foregroundColor(AppColors.textSecondary)
                        }
                        
                        Spacer()
                        
                        // 装饰性图标（使用 SF Symbols）
                        IconStyle.icon("sparkles", size: IconStyle.large)
                            .foregroundColor(AppColors.primary)
                            .frame(width: 48, height: 48)
                            .background(AppColors.primaryLight)
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, AppSpacing.md)
                .padding(.top, AppSpacing.lg)
                .padding(.bottom, AppSpacing.md)
                
                // 广告轮播
                BannerCarouselSection()
                    .id("BannerCarouselSection") // 添加 ID 以便调试
                
                // 推荐任务
                RecommendedTasksSection()
                
                // 热门活动
                PopularActivitiesSection()
                
                // 最新动态
                RecentActivitiesSection()
                .padding(.bottom, AppSpacing.xl)
            }
        }
    }
}

// 附近任务视图
struct NearbyTasksView: View {
    @StateObject private var viewModel = TasksViewModel()
    @StateObject private var locationService = LocationService.shared
    
    var body: some View {
        ZStack {
            AppColors.background
                .ignoresSafeArea()
            
            if viewModel.isLoading && viewModel.tasks.isEmpty {
                ProgressView()
            } else if viewModel.tasks.isEmpty {
                EmptyStateView(
                    icon: "mappin.circle.fill",
                    title: LocalizationKey.homeNoNearbyTasks.localized,
                    message: LocalizationKey.homeNoNearbyTasksMessage.localized
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: AppSpacing.md) {
                        ForEach(viewModel.tasks) { task in
                            NavigationLink(destination: TaskDetailView(taskId: task.id)) {
                                TaskCard(task: task)
                            }
                            .buttonStyle(ScaleButtonStyle())
                            .onAppear {
                                // 当显示最后一个任务时，加载更多
                                if task.id == viewModel.tasks.last?.id {
                                    viewModel.loadMoreTasks()
                                }
                            }
                        }
                        
                        // 加载更多指示器
                        if viewModel.isLoadingMore {
                            HStack {
                                Spacer()
                                ProgressView()
                                    .padding()
                                Spacer()
                            }
                        }
                    }
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.vertical, AppSpacing.sm)
                }
            }
        }
        .onAppear {
            print("🏠 [NearbyTasksView] onAppear - 开始初始化")
            print("🏠 [NearbyTasksView] 位置服务状态:")
            print("  - 授权状态: \(locationService.authorizationStatus.rawValue)")
            print("  - 是否已授权: \(locationService.isAuthorized)")
            print("  - 当前位置: \(locationService.currentLocation != nil ? "已获取" : "未获取")")
            
            // 请求位置权限（用于距离排序）
            if !locationService.isAuthorized {
                print("🏠 [NearbyTasksView] 请求位置权限...")
                locationService.requestAuthorization()
            } else {
                print("🏠 [NearbyTasksView] 位置权限已授权，开始更新位置...")
                locationService.startUpdatingLocation()
                // 也主动请求一次位置（如果还没有）
                if locationService.currentLocation == nil {
                    print("🏠 [NearbyTasksView] 主动请求位置...")
                    locationService.requestLocation()
                }
            }
            
            // 如果有位置，立即加载任务；否则等待位置更新
            if let _ = locationService.currentLocation {
                if viewModel.tasks.isEmpty {
                    print("🏠 [NearbyTasksView] 位置已可用，加载任务列表...")
                    viewModel.loadTasks(status: "open", sortBy: "distance")
                } else {
                    print("🏠 [NearbyTasksView] 任务列表已存在，共\(viewModel.tasks.count)条")
                }
            } else {
                print("🏠 [NearbyTasksView] 等待位置获取...")
            }
        }
        .onChange(of: locationService.currentLocation) { newLocation in
            // 当位置更新时，如果任务列表为空，自动加载任务
            if let _ = newLocation, viewModel.tasks.isEmpty {
                print("🏠 [NearbyTasksView] 位置已更新，加载任务列表...")
                viewModel.loadTasks(status: "open", sortBy: "distance")
            }
        }
        .refreshable {
            print("🔄 [NearbyTasksView] 下拉刷新")
            // 刷新位置
            if locationService.isAuthorized {
                print("🔄 [NearbyTasksView] 刷新位置...")
                locationService.requestLocation()
            }
            // 只加载开放中的任务（不指定城市，使用距离排序）
            viewModel.loadTasks(status: "open", sortBy: "distance", forceRefresh: true)
        }
    }
}

// 菜单视图
struct MenuView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appState: AppState
    @State private var showLogin = false
    @State private var navigateToCouponPoints = false
    @State private var navigateToStudentVerification = false
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink(destination: ProfileView()) {
                        Label(LocalizationKey.menuMy.localized, systemImage: "person.fill")
                    }
                    
                    NavigationLink(destination: TasksView()) {
                        Label(LocalizationKey.menuTaskHall.localized, systemImage: "list.bullet")
                    }
                    
                    NavigationLink(destination: TaskExpertListView()) {
                        Label(LocalizationKey.menuTaskExperts.localized, systemImage: "star.fill")
                    }
                    
                    NavigationLink(destination: ForumView()) {
                        Label(LocalizationKey.menuForum.localized, systemImage: "bubble.left.and.bubble.right.fill")
                    }
                    
                    NavigationLink(destination: LeaderboardView()) {
                        Label(LocalizationKey.menuLeaderboard.localized, systemImage: "trophy.fill")
                    }
                    
                    NavigationLink(destination: FleaMarketView()) {
                        Label(LocalizationKey.menuFleaMarket.localized, systemImage: "cart.fill")
                    }
                    
                    NavigationLink(destination: ActivityListView()) {
                        Label(LocalizationKey.menuActivity.localized, systemImage: "calendar.badge.plus")
                    }
                    
                    // 积分优惠券 - 需要登录
                    Button(action: {
                        if appState.isAuthenticated {
                            navigateToCouponPoints = true
                        } else {
                            showLogin = true
                        }
                    }) {
                        HStack {
                            Label(LocalizationKey.menuPointsCoupons.localized, systemImage: "star.fill")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(AppColors.textTertiary)
                        }
                    }
                    .foregroundColor(AppColors.textPrimary)
                    
                    // 学生认证 - 需要登录
                    Button(action: {
                        if appState.isAuthenticated {
                            navigateToStudentVerification = true
                        } else {
                            showLogin = true
                        }
                    }) {
                        HStack {
                            Label(LocalizationKey.menuStudentVerification.localized, systemImage: "person.badge.shield.checkmark.fill")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(AppColors.textTertiary)
                        }
                    }
                    .foregroundColor(AppColors.textPrimary)
                }
                
                Section {
                    NavigationLink(destination: SettingsView()) {
                        Label(LocalizationKey.menuSettings.localized, systemImage: "gearshape.fill")
                    }
                }
            }
            .navigationTitle(LocalizationKey.menuMenu.localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(LocalizationKey.menuClose.localized) {
                        dismiss()
                    }
                }
            }
            .navigationDestination(isPresented: $navigateToCouponPoints) {
                CouponPointsView()
            }
            .navigationDestination(isPresented: $navigateToStudentVerification) {
                StudentVerificationView()
            }
            .sheet(isPresented: $showLogin) {
                LoginView()
            }
        }
    }
}

// 任务达人列表内容视图（不带NavigationView）
struct TaskExpertListContentView: View {
    @StateObject private var viewModel = TaskExpertViewModel()
    @StateObject private var locationService = LocationService.shared
    @State private var selectedCategory: String? = nil
    @State private var selectedCity: String? = nil
    @State private var showFilter = false
    @State private var showSearch = false
    
    // 任务达人分类映射（根据后端 models.py 中的 category 字段）
    let categories: [(name: String, value: String)] = [
        ("全部", ""),
        ("编程", "programming"),
        ("翻译", "translation"),
        ("辅导", "tutoring"),
        ("食品", "food"),
        ("饮料", "beverage"),
        ("蛋糕", "cake"),
        ("跑腿/交通", "errand_transport"),
        ("社交/娱乐", "social_entertainment"),
        ("美容/护肤", "beauty_skincare"),
        ("手工艺", "handicraft")
    ]
    
    // 城市列表
    let cities = ["全部", "Online", "London", "Edinburgh", "Manchester", "Birmingham", "Glasgow", "Bristol", "Sheffield", "Leeds", "Nottingham", "Newcastle", "Southampton", "Liverpool", "Cardiff", "Coventry", "Exeter", "Leicester", "York", "Aberdeen", "Bath", "Dundee", "Reading", "St Andrews", "Belfast", "Brighton", "Durham", "Norwich", "Swansea", "Loughborough", "Lancaster", "Warwick", "Cambridge", "Oxford", "Other"]
    
    var body: some View {
        ZStack {
            AppColors.background
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 搜索和筛选栏
                HStack(spacing: AppSpacing.sm) {
                    // 搜索按钮
                    Button(action: {
                        showSearch = true
                    }) {
                        HStack {
                            Image(systemName: "magnifyingglass")
                            Text(LocalizationKey.homeSearchExperts.localized)
                                .font(AppTypography.subheadline)
                        }
                        .foregroundColor(AppColors.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AppSpacing.sm)
                        .background(AppColors.cardBackground)
                        .cornerRadius(AppCornerRadius.medium)
                    }
                    
                    // 筛选按钮
                    Button(action: {
                        showFilter = true
                    }) {
                        IconStyle.icon("line.3.horizontal.decrease.circle", size: 20)
                            .foregroundColor(selectedCategory != nil || selectedCity != nil ? AppColors.primary : AppColors.textSecondary)
                            .padding(AppSpacing.sm)
                            .background(AppColors.cardBackground)
                            .cornerRadius(AppCornerRadius.medium)
                    }
                }
                .padding(.horizontal, AppSpacing.md)
                .padding(.vertical, AppSpacing.sm)
                
                // 筛选标签
                if selectedCategory != nil || selectedCity != nil {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: AppSpacing.sm) {
                            if let category = selectedCategory, !category.isEmpty {
                                FilterChip(
                                    text: categories.first(where: { $0.value == category })?.name ?? category,
                                    onRemove: {
                                        selectedCategory = nil
                                        applyFilters()
                                    }
                                )
                            }
                            
                            if let city = selectedCity, !city.isEmpty, city != "全部" {
                                FilterChip(
                                    text: city,
                                    onRemove: {
                                        selectedCity = nil
                                        applyFilters()
                                    }
                                )
                            }
                        }
                        .padding(.horizontal, AppSpacing.md)
                    }
                    .padding(.vertical, AppSpacing.xs)
                }
                
                // 内容区域
                Group {
                    if viewModel.isLoading && viewModel.experts.isEmpty {
                        VStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                    } else if viewModel.experts.isEmpty {
                        VStack {
                            Spacer()
                            EmptyStateView(
                                icon: "person.3.fill",
                                title: LocalizationKey.homeNoExperts.localized,
                                message: LocalizationKey.homeNoExpertsMessage.localized
                            )
                            Spacer()
                        }
                    } else {
                        ScrollView {
                            LazyVStack(spacing: AppSpacing.md) {
                                ForEach(viewModel.experts) { expert in
                                    NavigationLink(destination: TaskExpertDetailView(expertId: expert.id)) {
                                        ExpertCard(expert: expert)
                                    }
                                    .buttonStyle(ScaleButtonStyle())
                                }
                            }
                            .padding(.horizontal, AppSpacing.md)
                            .padding(.vertical, AppSpacing.sm)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(AppColors.background)
            }
        }
        .sheet(isPresented: $showSearch) {
            NavigationView {
                TaskExpertSearchView()
            }
        }
        .sheet(isPresented: $showFilter) {
            TaskExpertFilterView(
                selectedCategory: $selectedCategory,
                selectedCity: $selectedCity,
                categories: categories,
                cities: cities,
                onApply: {
                    applyFilters()
                }
            )
        }
        .onAppear {
            print("🏠 [TaskExpertListContentView] onAppear - 开始初始化")
            print("🏠 [TaskExpertListContentView] 位置服务状态:")
            print("  - 授权状态: \(locationService.authorizationStatus.rawValue)")
            print("  - 是否已授权: \(locationService.isAuthorized)")
            print("  - 当前位置: \(locationService.currentLocation != nil ? "已获取" : "未获取")")
            
            // 请求位置权限（用于距离排序）
            if !locationService.isAuthorized {
                print("🏠 [TaskExpertListContentView] 请求位置权限...")
                locationService.requestAuthorization()
            } else {
                print("🏠 [TaskExpertListContentView] 位置权限已授权，开始更新位置...")
                locationService.startUpdatingLocation()
                // 也主动请求一次位置（如果还没有）
                if locationService.currentLocation == nil {
                    print("🏠 [TaskExpertListContentView] 主动请求位置...")
                    locationService.requestLocation()
                }
            }
            
            if viewModel.experts.isEmpty {
                print("🏠 [TaskExpertListContentView] 加载达人列表...")
                applyFilters()
            } else {
                print("🏠 [TaskExpertListContentView] 达人列表已存在，共\(viewModel.experts.count)条")
                // 即使已有数据，也尝试重新排序（如果位置已更新）
                if locationService.currentLocation != nil {
                    print("🏠 [TaskExpertListContentView] 位置已可用，触发重新排序...")
                }
            }
        }
        .refreshable {
            // 刷新位置
            if locationService.isAuthorized {
                locationService.requestLocation()
            }
            applyFilters()
        }
    }
    
    private func applyFilters() {
        let category = selectedCategory?.isEmpty == true ? nil : selectedCategory
        let city = selectedCity == "全部" ? nil : selectedCity
        viewModel.loadExperts(category: category, location: city, keyword: nil)
    }
}

// 搜索视图
struct SearchView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel = SearchViewModel()
    @FocusState private var isSearchFocused: Bool
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 搜索框
                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(AppColors.textSecondary)
                        .font(.system(size: 16, weight: .medium))
                    
                    TextField("搜索任务、达人、商品...", text: $viewModel.searchText)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.search)
                        .font(AppTypography.body)
                        .focused($isSearchFocused)
                        .onSubmit {
                            viewModel.search()
                        }
                    
                    if !viewModel.searchText.isEmpty {
                        Button(action: {
                            viewModel.searchText = ""
                            viewModel.clearResults()
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(AppColors.textSecondary)
                        }
                    }
                }
                .padding(.horizontal, AppSpacing.md)
                .padding(.vertical, 12)
                .background(AppColors.cardBackground)
                .cornerRadius(AppCornerRadius.large)
                .overlay(
                    RoundedRectangle(cornerRadius: AppCornerRadius.large)
                        .stroke(AppColors.separator.opacity(0.3), lineWidth: 1)
                )
                .padding(.horizontal, AppSpacing.md)
                .padding(.top, AppSpacing.sm)
                
                // 类型筛选标签
                if viewModel.hasResults {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: AppSpacing.sm) {
                            ForEach(SearchResultType.allCases, id: \.self) { type in
                                SearchTypeTag(
                                    type: type,
                                    isSelected: viewModel.selectedType == type,
                                    count: countForType(type)
                                ) {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        viewModel.selectedType = type
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, AppSpacing.md)
                        .padding(.vertical, AppSpacing.sm)
                    }
                }
                
                // 主内容区
                if viewModel.isLoading {
                    Spacer()
                    ProgressView()
                        .scaleEffect(1.2)
                    Spacer()
                } else if viewModel.hasResults {
                    // 搜索结果
                    SearchResultsView(viewModel: viewModel)
                } else if !viewModel.searchText.isEmpty && !viewModel.isLoading {
                    // 无搜索结果
                    Spacer()
                    VStack(spacing: AppSpacing.md) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 50))
                            .foregroundColor(AppColors.textSecondary.opacity(0.5))
                        Text("没有找到相关结果")
                            .font(AppTypography.body)
                            .foregroundColor(AppColors.textSecondary)
                        Text("试试其他关键词")
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.textTertiary)
                    }
                    Spacer()
                } else {
                    // 搜索首页：历史记录和热门搜索
                    SearchHomePage(viewModel: viewModel)
                }
            }
            .background(AppColors.background)
            .navigationTitle("搜索")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") {
                        dismiss()
                    }
                    .foregroundColor(AppColors.primary)
                }
            }
        }
        .onAppear {
            isSearchFocused = true
        }
    }
    
    private func countForType(_ type: SearchResultType) -> Int {
        switch type {
        case .all:
            return viewModel.totalResultCount
        case .task:
            return viewModel.taskResults.count
        case .expert:
            return viewModel.expertResults.count
        case .fleaMarket:
            return viewModel.fleaMarketResults.count
        case .forum:
            return viewModel.forumResults.count
        }
    }
}

// MARK: - 搜索类型标签
struct SearchTypeTag: View {
    let type: SearchResultType
    let isSelected: Bool
    let count: Int
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(type.rawValue)
                if count > 0 {
                    Text("(\(count))")
                        .font(AppTypography.caption2)
                }
            }
            .font(AppTypography.caption)
            .fontWeight(isSelected ? .semibold : .regular)
            .foregroundColor(isSelected ? .white : AppColors.textSecondary)
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.xs)
            .background(isSelected ? AppColors.primary : AppColors.cardBackground)
            .cornerRadius(AppCornerRadius.pill)
        }
    }
}

// MARK: - 搜索首页（历史记录和热门搜索）
struct SearchHomePage: View {
    @ObservedObject var viewModel: SearchViewModel
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                // 搜索历史
                if !viewModel.searchHistory.keywords.isEmpty {
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        HStack {
                            Text("搜索历史")
                                .font(AppTypography.bodyBold)
                                .foregroundColor(AppColors.textPrimary)
                            Spacer()
                            Button("清空") {
                                viewModel.clearHistory()
                            }
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.textSecondary)
                        }
                        
                        FlowLayout(spacing: AppSpacing.sm) {
                            ForEach(viewModel.searchHistory.keywords, id: \.self) { keyword in
                                SearchKeywordTag(keyword: keyword, showDelete: true) {
                                    viewModel.searchWithKeyword(keyword)
                                } onDelete: {
                                    viewModel.removeFromHistory(keyword)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, AppSpacing.md)
                }
                
                // 热门搜索
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    Text("热门搜索")
                        .font(AppTypography.bodyBold)
                        .foregroundColor(AppColors.textPrimary)
                    
                    FlowLayout(spacing: AppSpacing.sm) {
                        ForEach(viewModel.hotKeywords, id: \.self) { keyword in
                            SearchKeywordTag(keyword: keyword, showDelete: false) {
                                viewModel.searchWithKeyword(keyword)
                            } onDelete: {}
                        }
                    }
                }
                .padding(.horizontal, AppSpacing.md)
            }
            .padding(.top, AppSpacing.md)
        }
    }
}

// MARK: - 搜索关键词标签
struct SearchKeywordTag: View {
    let keyword: String
    let showDelete: Bool
    let action: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(keyword)
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textSecondary)
                
                if showDelete {
                    Button(action: onDelete) {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(AppColors.textTertiary)
                    }
                }
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.xs)
            .background(AppColors.cardBackground)
            .cornerRadius(AppCornerRadius.pill)
        }
    }
}

// MARK: - 流式布局
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }
    
    private func arrangeSubviews(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var maxWidth: CGFloat = 0
        
        let containerWidth = proposal.width ?? .infinity
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            
            if currentX + size.width > containerWidth && currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            
            positions.append(CGPoint(x: currentX, y: currentY))
            currentX += size.width + spacing
            lineHeight = max(lineHeight, size.height)
            maxWidth = max(maxWidth, currentX)
        }
        
        return (CGSize(width: maxWidth, height: currentY + lineHeight), positions)
    }
}

// MARK: - 搜索结果视图
struct SearchResultsView: View {
    @ObservedObject var viewModel: SearchViewModel
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: AppSpacing.md) {
                // 任务结果
                if !viewModel.filteredTaskResults.isEmpty {
                    SearchResultSection(title: LocalizationKey.tasksTasks.localized, count: viewModel.taskResults.count) {
                        ForEach(viewModel.filteredTaskResults) { task in
                            NavigationLink(destination: TaskDetailView(taskId: task.id)) {
                                SearchTaskCard(task: task)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
                
                // 达人结果
                if !viewModel.filteredExpertResults.isEmpty {
                    SearchResultSection(title: LocalizationKey.homeExperts.localized, count: viewModel.expertResults.count) {
                        ForEach(viewModel.filteredExpertResults) { expert in
                            NavigationLink(destination: TaskExpertDetailView(expertId: expert.id)) {
                                SearchExpertCard(expert: expert)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
                
                // 跳蚤市场结果
                if !viewModel.filteredFleaMarketResults.isEmpty {
                    SearchResultSection(title: LocalizationKey.fleaMarketItems.localized, count: viewModel.fleaMarketResults.count) {
                        ForEach(viewModel.filteredFleaMarketResults) { item in
                            NavigationLink(destination: FleaMarketDetailView(itemId: item.id)) {
                                SearchFleaMarketCard(item: item)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
                
                // 论坛结果
                if !viewModel.filteredForumResults.isEmpty {
                    SearchResultSection(title: LocalizationKey.forumPosts.localized, count: viewModel.forumResults.count) {
                        ForEach(viewModel.filteredForumResults) { post in
                            NavigationLink(destination: ForumPostDetailView(postId: post.id)) {
                                SearchForumCard(post: post)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.sm)
        }
    }
}

// MARK: - 搜索结果分区
struct SearchResultSection<Content: View>: View {
    let title: String
    let count: Int
    let content: () -> Content
    
    init(title: String, count: Int, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.count = count
        self.content = content
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack {
                Text(title)
                    .font(AppTypography.bodyBold)
                    .foregroundColor(AppColors.textPrimary)
                Text("(\(count))")
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textSecondary)
                Spacer()
            }
            
            content()
        }
    }
}

// MARK: - 搜索结果卡片
struct SearchTaskCard: View {
    let task: Task
    
    var body: some View {
        HStack(spacing: AppSpacing.md) {
            // 图片
            if let images = task.images, let firstImage = images.first, !firstImage.isEmpty {
                AsyncImage(url: URL(string: firstImage)) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    RoundedRectangle(cornerRadius: AppCornerRadius.small)
                        .fill(AppColors.cardBackground)
                }
                .frame(width: 60, height: 60)
                .cornerRadius(AppCornerRadius.small)
            } else {
                RoundedRectangle(cornerRadius: AppCornerRadius.small)
                    .fill(AppColors.primary.opacity(0.1))
                    .frame(width: 60, height: 60)
                    .overlay(
                        Image(systemName: "doc.text.fill")
                            .foregroundColor(AppColors.primary)
                    )
            }
            
            // 信息
            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .font(AppTypography.bodyBold)
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(1)
                
                Text(task.description)
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textSecondary)
                    .lineLimit(2)
                
                HStack {
                    Text("£\(String(format: "%.0f", task.reward))")
                        .font(AppTypography.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.primary)
                    
                    Text("·")
                        .foregroundColor(AppColors.textTertiary)
                    
                    // 位置（模糊显示）
                    HStack(spacing: 2) {
                        Image(systemName: task.isOnline ? "globe" : "mappin")
                            .font(.system(size: 10))
                        Text(task.location.obfuscatedLocation)
                            .font(AppTypography.caption)
                        
                        // 距离显示
                        if let distance = task.formattedDistanceFromUser, !task.isOnline {
                            Text("(\(distance))")
                                .font(AppTypography.caption)
                        }
                    }
                    .foregroundColor(AppColors.textTertiary)
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(AppColors.textTertiary)
        }
        .padding(AppSpacing.md)
        .background(AppColors.cardBackground)
        .cornerRadius(AppCornerRadius.medium)
    }
}

struct SearchExpertCard: View {
    let expert: TaskExpert
    
    var body: some View {
        HStack(spacing: AppSpacing.md) {
            // 头像
            AsyncImage(url: URL(string: expert.avatar ?? "")) { image in
                image.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                Circle()
                    .fill(AppColors.primary.opacity(0.1))
                    .overlay(
                        Text(String(expert.name.prefix(1)))
                            .font(AppTypography.bodyBold)
                            .foregroundColor(AppColors.primary)
                    )
            }
            .frame(width: 50, height: 50)
            .clipShape(Circle())
            
            // 信息
            VStack(alignment: .leading, spacing: 4) {
                Text(expert.name)
                    .font(AppTypography.bodyBold)
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(1)
                
                if let bio = expert.bio {
                    Text(bio)
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textSecondary)
                        .lineLimit(1)
                }
                
                HStack {
                    if let rating = expert.rating {
                        HStack(spacing: 2) {
                            Image(systemName: "star.fill")
                                .foregroundColor(.orange)
                            Text(String(format: "%.1f", rating))
                        }
                        .font(AppTypography.caption)
                    }
                    
                    if let location = expert.location {
                        Text("·")
                            .foregroundColor(AppColors.textTertiary)
                        Text(location)
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.textTertiary)
                    }
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(AppColors.textTertiary)
        }
        .padding(AppSpacing.md)
        .background(AppColors.cardBackground)
        .cornerRadius(AppCornerRadius.medium)
    }
}

struct SearchFleaMarketCard: View {
    let item: FleaMarketItem
    
    var body: some View {
        HStack(spacing: AppSpacing.md) {
            // 图片
            if let images = item.images, let firstImage = images.first {
                AsyncImage(url: URL(string: firstImage)) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    RoundedRectangle(cornerRadius: AppCornerRadius.small)
                        .fill(AppColors.cardBackground)
                }
                .frame(width: 60, height: 60)
                .cornerRadius(AppCornerRadius.small)
            } else {
                RoundedRectangle(cornerRadius: AppCornerRadius.small)
                    .fill(AppColors.warning.opacity(0.1))
                    .frame(width: 60, height: 60)
                    .overlay(
                        Image(systemName: "bag.fill")
                            .foregroundColor(AppColors.warning)
                    )
            }
            
            // 信息
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(AppTypography.bodyBold)
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(1)
                
                if let description = item.description {
                    Text(description)
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textSecondary)
                        .lineLimit(1)
                }
                
                Text("£\(String(format: "%.0f", item.price))")
                    .font(AppTypography.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.error)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(AppColors.textTertiary)
        }
        .padding(AppSpacing.md)
        .background(AppColors.cardBackground)
        .cornerRadius(AppCornerRadius.medium)
    }
}

struct SearchForumCard: View {
    let post: ForumPost
    
    var body: some View {
        HStack(spacing: AppSpacing.md) {
            // 图标
            RoundedRectangle(cornerRadius: AppCornerRadius.small)
                .fill(AppColors.success.opacity(0.1))
                .frame(width: 50, height: 50)
                .overlay(
                    Image(systemName: "text.bubble.fill")
                        .foregroundColor(AppColors.success)
                )
            
            // 信息
            VStack(alignment: .leading, spacing: 4) {
                Text(post.title)
                    .font(AppTypography.bodyBold)
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(1)
                
                HStack(spacing: AppSpacing.sm) {
                    HStack(spacing: 2) {
                        Image(systemName: "eye")
                        Text("\(post.viewCount)")
                    }
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textTertiary)
                    
                    HStack(spacing: 2) {
                        Image(systemName: "heart")
                        Text("\(post.likeCount)")
                    }
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textTertiary)
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(AppColors.textTertiary)
        }
        .padding(AppSpacing.md)
        .background(AppColors.cardBackground)
        .cornerRadius(AppCornerRadius.medium)
    }
}

// 快捷按钮内容组件（符合 Apple HIG，使用材质效果）
struct ShortcutButtonContent: View {
    let title: String
    let icon: String
    let gradient: [Color]
    
    var body: some View {
        VStack(spacing: AppSpacing.sm) {
            IconStyle.icon(icon, size: IconStyle.large)
                .foregroundColor(.white)
            
            Text(title)
                .font(AppTypography.body) // 使用 body
                .fontWeight(.semibold)
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 90)
        .background(
            LinearGradient(
                gradient: Gradient(colors: gradient),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: AppCornerRadius.medium, style: .continuous))
        .shadow(color: AppShadow.medium.color, radius: AppShadow.medium.radius, x: AppShadow.medium.x, y: AppShadow.medium.y)
    }
}

// 快捷按钮组件（用于需要action的情况）
struct ShortcutButton: View {
    let title: String
    let icon: String
    let gradient: [Color]
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ShortcutButtonContent(title: title, icon: icon, gradient: gradient)
        }
    }
}

// 推荐任务区域组件
struct RecommendedTasksSection: View {
    @StateObject private var viewModel = TasksViewModel()
    
    var body: some View {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack {
                Text(LocalizationKey.homeRecommendedTasks.localized)
                    .font(AppTypography.title3) // 使用 title3
                    .foregroundColor(AppColors.textPrimary)
                
                Spacer()
                
                NavigationLink(destination: TasksView()) {
                    HStack(spacing: 4) {
                        Text(LocalizationKey.commonViewAll.localized)
                            .font(AppTypography.body) // 使用 body
                        IconStyle.icon("chevron.right", size: IconStyle.small)
                    }
                    .foregroundColor(AppColors.primary)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, AppSpacing.md)
            
            if viewModel.isLoading && viewModel.tasks.isEmpty {
                HStack {
                    Spacer()
                    ProgressView()
                        .padding()
                    Spacer()
                }
            } else if viewModel.tasks.isEmpty {
                EmptyStateView(
                    icon: "doc.text.fill",
                    title: LocalizationKey.homeNoRecommendedTasks.localized,
                    message: LocalizationKey.homeNoRecommendedTasksMessage.localized
                )
                .padding(AppSpacing.md)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: AppSpacing.md) {
                        ForEach(Array(viewModel.tasks.prefix(10))) { task in
                            NavigationLink(destination: TaskDetailView(taskId: task.id)) {
                                TaskCard(task: task)
                                    .frame(width: 200)
                            }
                            .buttonStyle(ScaleButtonStyle())
                        }
                    }
                    .padding(.horizontal, AppSpacing.md)
                }
            }
        }
        .onAppear {
            if viewModel.tasks.isEmpty {
                // 只加载开放中的任务
                viewModel.loadTasks(status: "open")
            }
        }
    }
}

// 最新动态区域组件
struct RecentActivitiesSection: View {
    @StateObject private var viewModel = RecentActivityViewModel()
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text(LocalizationKey.homeLatestActivity.localized)
                .font(AppTypography.title3) // 使用 title3
                .foregroundColor(AppColors.textPrimary)
                .padding(.horizontal, AppSpacing.md)
            
            if viewModel.isLoading && viewModel.activities.isEmpty {
                HStack {
                    Spacer()
                    ProgressView()
                        .padding()
                    Spacer()
                }
            } else if viewModel.activities.isEmpty {
                EmptyStateView(
                    icon: "bell.fill",
                    title: LocalizationKey.homeNoActivity.localized,
                    message: LocalizationKey.homeNoActivityMessage.localized
                )
                .padding(AppSpacing.md)
            } else {
                ForEach(Array(viewModel.activities.enumerated()), id: \.element.id) { index, activity in
                    ActivityRow(activity: activity)
                        .onAppear {
                            // 当显示最后3个项目时，加载更多
                            let threshold = viewModel.activities.count - 3
                            if index >= threshold && viewModel.hasMore && !viewModel.isLoadingMore && !viewModel.isLoading {
                                viewModel.loadMoreActivities()
                            }
                        }
                }
                
                // 加载更多指示器
                if viewModel.isLoadingMore {
                    HStack {
                        Spacer()
                        ProgressView()
                            .padding()
                        Spacer()
                    }
                } else if !viewModel.hasMore && !viewModel.activities.isEmpty {
                    HStack {
                        Spacer()
                        Text(LocalizationKey.homeNoMoreActivity.localized)
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.textTertiary)
                            .padding()
                        Spacer()
                    }
                }
            }
        }
        .onAppear {
            if viewModel.activities.isEmpty {
                viewModel.loadRecentActivities()
            }
        }
    }
}

// 动态行组件 - 更现代的设计
struct ActivityRow: View {
    let activity: RecentActivity
    
    var body: some View {
        Group {
            switch activity.type {
            case .forumPost:
                if let postId = Int(activity.id.replacingOccurrences(of: "forum_", with: "")) {
                    NavigationLink(destination: ForumPostDetailView(postId: postId)) {
                        activityContent
                    }
                    .buttonStyle(PlainButtonStyle())
                } else {
                    activityContent
                }
            case .fleaMarketItem:
                NavigationLink(destination: FleaMarketDetailView(itemId: activity.id.replacingOccurrences(of: "flea_", with: ""))) {
                    activityContent
                }
                .buttonStyle(PlainButtonStyle())
            case .leaderboardCreated:
                if let leaderboardId = Int(activity.id.replacingOccurrences(of: "leaderboard_", with: "")) {
                    NavigationLink(destination: LeaderboardDetailView(leaderboardId: leaderboardId)) {
                        activityContent
                    }
                    .buttonStyle(PlainButtonStyle())
                } else {
                    activityContent
                }
            }
        }
    }
    
    private var activityContent: some View {
        HStack(spacing: AppSpacing.md) {
            // 图标（使用 SF Symbols，符合 HIG）
            IconStyle.icon(activity.icon, size: IconStyle.large)
                .foregroundColor(.white)
                .frame(width: 44, height: 44)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: activity.iconColor),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(Circle())
                .shadow(color: AppShadow.small.color, radius: AppShadow.small.radius, x: AppShadow.small.x, y: AppShadow.small.y)
            
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                HStack(spacing: 4) {
                    Text(activity.author?.name ?? "用户")
                        .font(AppTypography.body) // 使用 body
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.textPrimary)
                    
                    Text(activity.actionText)
                        .font(AppTypography.body) // 使用 body
                        .foregroundColor(AppColors.textSecondary)
                }
                
                Text(activity.title)
                    .font(AppTypography.caption) // 使用 caption
                    .fontWeight(.medium)
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(1)
                
                if let description = activity.description, !description.isEmpty {
                    Text(description)
                        .font(AppTypography.caption) // 使用 caption
                        .foregroundColor(AppColors.textSecondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            if activity.type != .leaderboardCreated {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(AppColors.textTertiary)
            }
        }
        .padding(AppSpacing.md)
        .background(AppColors.cardBackground)
        .cornerRadius(AppCornerRadius.large)
        .padding(.horizontal, AppSpacing.md)
        .shadow(color: AppShadow.small.color, radius: AppShadow.small.radius, x: AppShadow.small.x, y: AppShadow.small.y)
    }
}

// 热门活动区域组件（只显示开放中的活动）
struct PopularActivitiesSection: View {
    @StateObject private var viewModel = ActivityViewModel()
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack {
                Text(LocalizationKey.homeHotEvents.localized)
                    .font(AppTypography.title3)
                    .foregroundColor(AppColors.textPrimary)
                
                Spacer()
                
                NavigationLink(destination: ActivityListView()) {
                    HStack(spacing: 4) {
                        Text(LocalizationKey.commonViewAll.localized)
                            .font(AppTypography.body)
                        IconStyle.icon("chevron.right", size: IconStyle.small)
                    }
                    .foregroundColor(AppColors.primary)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, AppSpacing.md)
            
            if viewModel.isLoading && viewModel.activities.isEmpty {
                HStack {
                    Spacer()
                    ProgressView()
                        .padding()
                    Spacer()
                }
            } else if viewModel.activities.isEmpty {
                EmptyStateView(
                    icon: "calendar.badge.plus",
                    title: LocalizationKey.homeNoEvents.localized,
                    message: LocalizationKey.homeNoEventsMessage.localized
                )
                .padding()
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: AppSpacing.md) {
                        ForEach(Array(viewModel.activities.prefix(10))) { activity in
                            NavigationLink(destination: ActivityDetailView(activityId: activity.id)) {
                                ActivityCardView(activity: activity, showEndedBadge: false)
                                    .frame(width: 280)
                            }
                            .buttonStyle(ScaleButtonStyle())
                        }
                    }
                    .padding(.horizontal, AppSpacing.md)
                }
            }
        }
        .onAppear {
            // 只加载状态为 "open" 的活动（开放中的活动）
            if viewModel.activities.isEmpty {
                viewModel.loadActivities(status: "open", includeEnded: false)
            }
        }
    }
}

// 广告轮播区域组件
struct BannerCarouselSection: View {
    @StateObject private var viewModel = BannerCarouselViewModel()
    
    var body: some View {
        VStack(spacing: 0) {
            if viewModel.isLoading && viewModel.banners.isEmpty {
                // 加载中占位 - 更美观的设计
                RoundedRectangle(cornerRadius: AppCornerRadius.large, style: .continuous)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                AppColors.cardBackground,
                                AppColors.cardBackground.opacity(0.8)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(height: 180)
                    .padding(.horizontal, AppSpacing.md)
                    .overlay(
                        VStack(spacing: AppSpacing.sm) {
                            ProgressView()
                                .tint(AppColors.primary)
                            Text(LocalizationKey.commonLoading.localized)
                                .font(AppTypography.caption)
                                .foregroundColor(AppColors.textSecondary)
                        }
                    )
            } else if viewModel.banners.isEmpty {
                // 无广告时不显示
                Color.clear
                    .frame(height: 0)
            } else {
                BannerCarouselView(banners: viewModel.banners)
            }
        }
        .onAppear {
            viewModel.loadBanners()
        }
    }
}

// Banner 轮播 ViewModel
class BannerCarouselViewModel: ObservableObject {
    @Published var banners: [Banner] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let apiService = APIService.shared
    private var cancellables = Set<AnyCancellable>()
    
    func loadBanners() {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        
        apiService.getBanners()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    if case .failure(let error) = completion {
                        self?.errorMessage = error.localizedDescription
                        Logger.error("加载广告失败: \(error.localizedDescription)", category: .api)
                    }
                },
                receiveValue: { [weak self] response in
                    self?.banners = response.banners.sorted { $0.order < $1.order }
                    self?.isLoading = false
                    self?.errorMessage = nil
                }
            )
            .store(in: &cancellables)
    }
}

// 活动卡片占位符组件（保留用于其他场景）
struct ActivityCardPlaceholder: View {
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            // Header
            HStack(alignment: .top, spacing: AppSpacing.md) {
                // Icon
                ZStack {
                    RoundedRectangle(cornerRadius: AppCornerRadius.medium)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [AppColors.primary.opacity(0.2), AppColors.primary.opacity(0.1)]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 56, height: 56)
                    
                    IconStyle.icon("calendar.badge.plus", size: IconStyle.large)
                        .foregroundColor(AppColors.primary)
                }
                
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text(LocalizationKey.homeViewEvent.localized)
                        .font(AppTypography.title3)
                        .foregroundColor(AppColors.textPrimary)
                        .lineLimit(2)
                    
                    Text(LocalizationKey.homeTapToViewEvents.localized)
                        .font(AppTypography.subheadline)
                        .foregroundColor(AppColors.textSecondary)
                        .lineLimit(2)
                }
                
                Spacer()
            }
            
            Divider()
                .background(AppColors.separator)
            
            // Info Row
            HStack(spacing: AppSpacing.lg) {
                HStack(spacing: AppSpacing.xs) {
                    IconStyle.icon("person.2.fill", size: IconStyle.small)
                        .foregroundColor(AppColors.textSecondary)
                    Text(LocalizationKey.homeMultiplePeople.localized)
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textSecondary)
                }
                
                Spacer()
                
                HStack(spacing: AppSpacing.xs) {
                    IconStyle.icon("arrow.right.circle.fill", size: IconStyle.small)
                        .foregroundColor(AppColors.primary)
                    Text(LocalizationKey.homeView.localized)
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.primary)
                }
            }
        }
        .padding(AppSpacing.md)
        .frame(width: 280)
        .background(AppColors.cardBackground)
        .cornerRadius(AppCornerRadius.large)
        .shadow(color: AppShadow.medium.color, radius: AppShadow.medium.radius, x: AppShadow.medium.x, y: AppShadow.medium.y)
    }
}
