import SwiftUI
import CoreLocation
import Combine

struct HomeView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var deepLinkHandler = DeepLinkHandler.shared
    @State private var selectedTab = 1 // 0: 达人, 1: 推荐, 2: 附近
    @State private var showMenu = false
    @State private var showSearch = false
    @State private var navigationPath = NavigationPath() // 使用 NavigationPath 管理导航状态
    @State private var navigateToActivityId: Int? = nil // 用于深度链接导航到活动详情
    @State private var showActivityDetail = false // 控制是否显示活动详情页
    @State private var navigateToTaskId: Int? = nil // 用于深度链接导航到任务详情
    @State private var showTaskDetail = false // 控制是否显示任务详情页
    @State private var navigateToPostId: Int? = nil // 用于深度链接导航到帖子详情
    @State private var showPostDetail = false // 控制是否显示帖子详情页
    @State private var navigateToFleaMarketItemId: String? = nil // 用于深度链接导航到商品详情
    @State private var showFleaMarketItemDetail = false // 控制是否显示商品详情页
    
    // 监听重置通知
    private let resetNotification = NotificationCenter.default.publisher(for: .resetHomeView)
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                AppColors.background
                    .ignoresSafeArea()
                
                // 装饰性背景：增加品牌氛围
                ZStack {
                    Circle()
                        .fill(AppColors.primary.opacity(0.12))
                        .frame(width: 300, height: 300)
                        .blur(radius: 60)
                        .offset(x: 180, y: -100)
                    
                    Circle()
                        .fill(AppColors.accentPink.opacity(0.08))
                        .frame(width: 250, height: 250)
                        .blur(radius: 50)
                        .offset(x: -150, y: 100)
                }
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
                        
                        // 中间三个标签（符合 HIG 间距）+ 丝滑切换动画
                        HStack(spacing: 0) {
                            TabButton(title: LocalizationKey.homeExperts.localized, isSelected: selectedTab == 0) {
                                if selectedTab != 0 {
                                    HapticFeedback.tabSwitch()
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.75, blendDuration: 0)) {
                                        selectedTab = 0
                                    }
                                }
                            }
                            
                            TabButton(title: LocalizationKey.homeRecommended.localized, isSelected: selectedTab == 1) {
                                if selectedTab != 1 {
                                    HapticFeedback.tabSwitch()
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.75, blendDuration: 0)) {
                                        selectedTab = 1
                                    }
                                }
                            }
                            
                            TabButton(title: LocalizationKey.homeNearby.localized, isSelected: selectedTab == 2) {
                                if selectedTab != 2 {
                                    HapticFeedback.tabSwitch()
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.75, blendDuration: 0)) {
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
            // 点击空白区域关闭键盘
            .keyboardDismissable()
            .onReceive(resetNotification) { _ in
            }
            .onChange(of: appState.shouldResetHomeView) { shouldReset in
                if shouldReset {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        appState.shouldResetHomeView = false
                    }
                }
            }
            .onChange(of: navigationPath.count) { _ in
            }
            .onChange(of: deepLinkHandler.currentLink) { link in
                // 处理深度链接
                if let link = link {
                    handleDeepLink(link)
                }
            }
            .navigationDestination(isPresented: $showActivityDetail) {
                if let activityId = navigateToActivityId {
                    ActivityDetailView(activityId: activityId)
                }
            }
            .navigationDestination(isPresented: $showTaskDetail) {
                if let taskId = navigateToTaskId {
                    TaskDetailView(taskId: taskId)
                }
            }
            .navigationDestination(isPresented: $showPostDetail) {
                if let postId = navigateToPostId {
                    ForumPostDetailView(postId: postId)
                }
            }
            .navigationDestination(isPresented: $showFleaMarketItemDetail) {
                if let itemId = navigateToFleaMarketItemId {
                    FleaMarketDetailView(itemId: itemId)
                }
            }
        }
    }
    
    /// 处理深度链接
    private func handleDeepLink(_ link: DeepLinkHandler.DeepLink) {
        switch link {
        case .activity(let id):
            navigateToActivityId = id
            showActivityDetail = true
        case .task(let id):
            navigateToTaskId = id
            showTaskDetail = true
        case .post(let id):
            navigateToPostId = id
            showPostDetail = true
        case .fleaMarketItem(let id):
            navigateToFleaMarketItemId = id
            showFleaMarketItemDetail = true
        default:
            break
        }
        
        // 处理完后清空链接，避免重复处理
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            deepLinkHandler.currentLink = nil
        }
    }
}

// 标签按钮组件（符合 Apple HIG + 丝滑动画）
struct TabButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Text(title)
                    .font(AppTypography.body)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundColor(isSelected ? AppColors.textPrimary : AppColors.textSecondary)
                    .scaleEffect(isSelected ? 1.05 : 1.0)
                    // 丝滑的文字变换动画
                    .animation(.spring(response: 0.25, dampingFraction: 0.75, blendDuration: 0), value: isSelected)
                
                // 选中时的下划线（符合 HIG）- 更丝滑的动画
                ZStack {
                    Capsule()
                        .fill(isSelected ? AppColors.primary : Color.clear)
                        .frame(height: 3)
                        .frame(width: isSelected ? 28 : 0)
                        .shadow(color: isSelected ? AppColors.primary.opacity(0.3) : .clear, radius: 4, x: 0, y: 2)
                }
                .frame(height: 3)
                // 使用更丝滑的弹性动画
                .animation(.spring(response: 0.28, dampingFraction: 0.7, blendDuration: 0), value: isSelected)
            }
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .buttonStyle(LightTouchButtonStyle())
    }
}

// 推荐内容视图（原来的首页内容）
struct RecommendedContentView: View {
    @EnvironmentObject var appState: AppState
    @State private var hasAppeared = false
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: AppSpacing.lg) {
                // 优化：确保LazyVStack不会裁剪子视图
                // 顶部欢迎区域（符合 Apple HIG，使用系统字体和间距）
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    HStack(alignment: .center, spacing: AppSpacing.md) {
                        VStack(alignment: .leading, spacing: AppSpacing.xs) {
                            Text(String(format: LocalizationKey.homeGreeting.localized, appState.currentUser?.name ?? LocalizationKey.appUser.localized))
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundColor(AppColors.textPrimary)
                            
                            Text(LocalizationKey.homeWhatToDo.localized)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(AppColors.textSecondary)
                        }
                        
                        Spacer()
                        
                        // 装饰性图标（使用 SF Symbols）
                        Image(systemName: "sparkles")
                            .font(.title2)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(AppColors.primary)
                            .frame(width: 48, height: 48)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                            .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                    }
                }
                .padding(.horizontal, AppSpacing.md)
                .padding(.top, AppSpacing.lg)
                .padding(.bottom, AppSpacing.md)
                
                // 广告轮播（优先加载）
                BannerCarouselSection()
                    .id("BannerCarouselSection")
                    .padding(.top, -AppSpacing.md) // 减少与上方内容的间距
                
                // 推荐任务（优先加载）
                RecommendedTasksSection()
                
                // 热门活动（立即加载，数据已预加载）
                PopularActivitiesSection()
                    .opacity(hasAppeared ? 1.0 : 0.0)
                    .animation(.easeInOut(duration: 0.15), value: hasAppeared) // 更快的淡入动画
                
                // 最新动态（延迟加载，优化首次加载性能）
                if hasAppeared {
                    RecentActivitiesSection()
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                } else {
                    // 占位符，保持布局稳定
                    Color.clear
                        .frame(height: 150)
                }
                
                Spacer()
                    .frame(height: AppSpacing.xl)
            }
        }
        // 优化：禁用ScrollView的裁剪，允许contextMenu超出边界显示
        .scrollContentBackground(.hidden)
        .refreshable {
            // 手动下拉刷新首页所有内容（推荐任务、热门活动、最新动态）
            NotificationCenter.default.post(name: .refreshHomeContent, object: nil)
            // 等待一小段时间，确保刷新完成
            try? await _Concurrency.Task.sleep(nanoseconds: 500_000_000) // 0.5秒
        }
        .onAppear {
            // 立即显示所有内容，数据已预加载
            // 使用平滑的淡入动画，避免闪烁（优化：减少延迟提升响应速度）
            if !hasAppeared {
                // 立即显示，减少延迟（数据已预加载）
                withAnimation(.easeInOut(duration: 0.2)) {
                    hasAppeared = true
                }
            }
        }
    }
}

// 附近任务视图
struct NearbyTasksView: View {
    @StateObject private var viewModel = TasksViewModel()
    @ObservedObject private var locationService = LocationService.shared
    
    var body: some View {
        ZStack {
            AppColors.background
                .ignoresSafeArea()
            
            if viewModel.isLoading && viewModel.tasks.isEmpty {
                // 使用列表骨架屏
                ScrollView {
                    ListSkeleton(itemCount: 5, itemHeight: 120)
                        .padding(.horizontal, AppSpacing.md)
                        .padding(.vertical, AppSpacing.sm)
                }
            } else if viewModel.tasks.isEmpty {
                EmptyStateView(
                    icon: "mappin.circle.fill",
                    title: LocalizationKey.homeNoNearbyTasks.localized,
                    message: LocalizationKey.homeNoNearbyTasksMessage.localized
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: AppSpacing.md) {
                        ForEach(Array(viewModel.tasks.enumerated()), id: \.element.id) { index, task in
                            NavigationLink(destination: TaskDetailView(taskId: task.id)) {
                                TaskCard(task: task)
                            }
                            .buttonStyle(ScaleButtonStyle())
                            .listItemAppear(index: index, totalItems: viewModel.tasks.count) // 添加错落入场动画
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
                                CompactLoadingView()
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
        .task {
            // 使用 task 替代 onAppear，避免重复加载
            initializeLocationService(
                locationService: locationService,
                viewName: "NearbyTasksView"
            ) {
                // 延迟加载任务，避免阻塞主线程
                if viewModel.tasks.isEmpty && !viewModel.isLoading {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        // 获取用户当前城市，显示所有同城任务，按距离排序
                        let city = locationService.currentCityName
                        viewModel.loadTasks(city: city, status: "open", sortBy: "distance")
                    }
                }
            }
        }
        .onChange(of: locationService.currentCityName) { cityName in
            if let cityName = cityName, !cityName.isEmpty {
                viewModel.loadTasks(city: cityName, status: "open", sortBy: "distance", forceRefresh: true)
            }
        }
        .onChange(of: locationService.currentLocation) { newLocation in
            if let _ = newLocation, let cityName = locationService.currentCityName, !cityName.isEmpty, viewModel.tasks.isEmpty {
                viewModel.loadTasks(city: cityName, status: "open", sortBy: "distance")
            }
        }
        .refreshable {
            if locationService.isAuthorized {
                locationService.requestLocation()
            }
            // 加载所有同城任务，按距离排序（强制刷新）
            let city = locationService.currentCityName
            viewModel.loadTasks(city: city, status: "open", sortBy: "distance", forceRefresh: true)
            // 等待一小段时间，确保刷新完成
            try? await _Concurrency.Task.sleep(nanoseconds: 500_000_000) // 0.5秒
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
    @ObservedObject private var locationService = LocationService.shared
    @State private var selectedCategory: String? = nil
    @State private var selectedCity: String? = nil
    @State private var showFilterPanel = false
    @State private var searchText = ""
    @State private var searchDebounceTask: DispatchWorkItem?
    @FocusState private var isSearchFocused: Bool
    
    // 任务达人分类映射（根据后端 models.py 中的 category 字段）
    let categories: [(name: String, value: String)] = [
        (LocalizationKey.commonAll.localized, ""),
        (LocalizationKey.expertCategoryProgramming.localized, "programming"),
        (LocalizationKey.expertCategoryTranslation.localized, "translation"),
        (LocalizationKey.expertCategoryTutoring.localized, "tutoring"),
        (LocalizationKey.expertCategoryFood.localized, "food"),
        (LocalizationKey.expertCategoryBeverage.localized, "beverage"),
        (LocalizationKey.expertCategoryCake.localized, "cake"),
        (LocalizationKey.expertCategoryErrandTransport.localized, "errand_transport"),
        (LocalizationKey.expertCategorySocialEntertainment.localized, "social_entertainment"),
        (LocalizationKey.expertCategoryBeautySkincare.localized, "beauty_skincare"),
        (LocalizationKey.expertCategoryHandicraft.localized, "handicraft")
    ]
    
    // 城市列表
    let cities: [String] = {
        let all = LocalizationKey.commonAll.localized
        return [all, "Online", "London", "Edinburgh", "Manchester", "Birmingham", "Glasgow", "Bristol", "Sheffield", "Leeds", "Nottingham", "Newcastle", "Southampton", "Liverpool", "Cardiff", "Coventry", "Exeter", "Leicester", "York", "Aberdeen", "Bath", "Dundee", "Reading", "St Andrews", "Belfast", "Brighton", "Durham", "Norwich", "Swansea", "Loughborough", "Lancaster", "Warwick", "Cambridge", "Oxford", "Other"]
    }()
    
    var body: some View {
        ZStack {
            AppColors.background
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 搜索和筛选栏
                HStack(spacing: AppSpacing.sm) {
                    // 搜索框
                    HStack(spacing: AppSpacing.sm) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(AppColors.textTertiary)
                            .font(.system(size: 16))
                        
                        TextField(LocalizationKey.homeSearchExperts.localized, text: $searchText)
                            .focused($isSearchFocused)
                            .font(AppTypography.subheadline)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .submitLabel(.search)
                            .onSubmit {
                                // 提交时立即搜索，取消防抖
                                searchDebounceTask?.cancel()
                                applyFilters()
                                isSearchFocused = false
                            }
                            .onChange(of: searchText) { newValue in
                                // 防抖搜索：延迟500ms后执行
                                searchDebounceTask?.cancel()
                                
                                let keyword = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                                let workItem = DispatchWorkItem {
                                    applyFilters()
                                }
                                searchDebounceTask = workItem
                                
                                // 如果输入为空，立即清除结果
                                if keyword.isEmpty {
                                    applyFilters()
                                } else {
                                    // 延迟500ms执行搜索
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: workItem)
                                }
                            }
                        
                        if !searchText.isEmpty {
                            Button(action: {
                                searchDebounceTask?.cancel()
                                searchText = ""
                                applyFilters()
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(AppColors.textTertiary)
                                    .font(.system(size: 16))
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppSpacing.sm)
                    .padding(.horizontal, AppSpacing.md)
                    .background(AppColors.cardBackground)
                    .cornerRadius(AppCornerRadius.medium)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppCornerRadius.medium)
                            .stroke(isSearchFocused ? AppColors.primary : AppColors.separator.opacity(0.3), lineWidth: isSearchFocused ? 2 : 1)
                    )
                    
                    // 筛选按钮
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            showFilterPanel.toggle()
                        }
                    }) {
                        IconStyle.icon("line.3.horizontal.decrease.circle", size: 20)
                            .foregroundColor(selectedCategory != nil || selectedCity != nil ? AppColors.primary : AppColors.textSecondary)
                            .rotationEffect(.degrees(showFilterPanel ? 180 : 0))
                            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: showFilterPanel)
                            .padding(AppSpacing.sm)
                        .cardBackground(cornerRadius: AppCornerRadius.medium)
                    }
                }
                .padding(.horizontal, AppSpacing.md)
                .padding(.vertical, AppSpacing.sm)
                
                // 筛选面板
                if showFilterPanel {
                    VStack(spacing: AppSpacing.md) {
                        // 分类筛选
                        VStack(alignment: .leading, spacing: AppSpacing.sm) {
                            Text(LocalizationKey.taskExpertType.localized)
                                .font(AppTypography.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(AppColors.textPrimary)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: AppSpacing.sm) {
                                    ForEach(categories, id: \.value) { category in
                                        FilterTag(
                                            title: category.name,
                                            isSelected: selectedCategory == category.value || (selectedCategory == nil && category.value.isEmpty),
                                            icon: "tag.fill"
                                        ) {
                                            selectedCategory = category.value.isEmpty ? nil : category.value
                                            applyFilters()
                                        }
                                    }
                                }
                            }
                        }
                        
                        // 城市筛选
                        VStack(alignment: .leading, spacing: AppSpacing.sm) {
                            Text(LocalizationKey.taskExpertLocation.localized)
                                .font(AppTypography.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(AppColors.textPrimary)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: AppSpacing.sm) {
                                    ForEach(cities, id: \.self) { city in
                                        FilterTag(
                                            title: city,
                                            isSelected: selectedCity == city || (selectedCity == nil && city == LocalizationKey.commonAll.localized),
                                            icon: "mappin.circle.fill"
                                        ) {
                                            selectedCity = city == LocalizationKey.commonAll.localized ? nil : city
                                            applyFilters()
                                        }
                                    }
                                }
                            }
                        }
                        
                        // 清除筛选按钮
                        if selectedCategory != nil || selectedCity != nil {
                            Button(action: {
                                selectedCategory = nil
                                selectedCity = nil
                                applyFilters()
                            }) {
                                HStack {
                                    Image(systemName: "xmark.circle.fill")
                                    Text(LocalizationKey.taskExpertClear.localized)
                                }
                                .font(AppTypography.subheadline)
                                .foregroundColor(AppColors.primary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, AppSpacing.sm)
                                .background(AppColors.primary.opacity(0.1))
                                .cornerRadius(AppCornerRadius.medium)
                            }
                        }
                    }
                    .padding(AppSpacing.md)
                    .background(AppColors.cardBackground)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
                
                // 筛选标签（已选择的筛选条件）
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
                            
                            if let city = selectedCity, !city.isEmpty, city != LocalizationKey.commonAll.localized {
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
                        LoadingView()
                    } else if viewModel.experts.isEmpty {
                        VStack {
                            Spacer()
                            EmptyStateView(
                                icon: searchText.isEmpty ? "person.3.fill" : "magnifyingglass",
                                title: searchText.isEmpty ? LocalizationKey.homeNoExperts.localized : LocalizationKey.taskExpertNoExpertsFound.localized,
                                message: searchText.isEmpty ? LocalizationKey.homeNoExpertsMessage.localized : String(format: LocalizationKey.taskExpertNoExpertsFoundWithQuery.localized, searchText)
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
        .task {
            // 使用 task 替代 onAppear，避免重复调用
            initializeLocationService(
                locationService: locationService,
                viewName: "TaskExpertListContentView"
            ) {
                if viewModel.experts.isEmpty {
                    applyFilters()
                } else {
                    Logger.debug("🏠 [TaskExpertListContentView] 达人列表已存在，共\(viewModel.experts.count)条", category: .ui)
                    // 即使已有数据，也尝试重新排序（如果位置已更新）
                    if locationService.currentLocation != nil {
                        Logger.debug("🏠 [TaskExpertListContentView] 位置已可用，触发重新排序...", category: .ui)
                    }
                }
            }
        }
        .refreshable {
            // 下拉刷新：刷新位置和达人列表
            searchDebounceTask?.cancel()
            if locationService.isAuthorized {
                locationService.requestLocation()
            }
            // 强制刷新达人列表
            applyFilters(forceRefresh: true)
            // 等待一小段时间，确保刷新完成
            try? await _Concurrency.Task.sleep(nanoseconds: 500_000_000) // 0.5秒
        }
        .onDisappear {
            // 页面消失时取消防抖任务
            searchDebounceTask?.cancel()
        }
    }
    
    private func applyFilters(forceRefresh: Bool = false) {
        let category = selectedCategory?.isEmpty == true ? nil : selectedCategory
        let city = selectedCity == LocalizationKey.commonAll.localized ? nil : selectedCity
        let keyword = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalKeyword = keyword.isEmpty ? nil : keyword
        viewModel.loadExperts(category: category, location: city, keyword: finalKeyword, forceRefresh: forceRefresh)
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
                    
                    TextField(LocalizationKey.searchPlaceholder.localized, text: $viewModel.searchText)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.search)
                        .font(AppTypography.body)
                        .focused($isSearchFocused)
                        .onSubmit {
                            viewModel.search()
                            // 用户体验优化：搜索后收起键盘
                            isSearchFocused = false
                        }
                    
                    if !viewModel.searchText.isEmpty {
                        Button(action: {
                            viewModel.searchText = ""
                            viewModel.clearResults()
                            // 用户体验优化：清空搜索时收起键盘
                            isSearchFocused = false
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
                    CompactLoadingView()
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
                        Text(LocalizationKey.searchNoResults.localized)
                            .font(AppTypography.body)
                            .foregroundColor(AppColors.textSecondary)
                        Text(LocalizationKey.searchTryOtherKeywords.localized)
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
            .navigationTitle(LocalizationKey.searchSearch.localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(LocalizationKey.commonClose.localized) {
                        dismiss()
                    }
                    .foregroundColor(AppColors.primary)
                }
            }
        }
        .onAppear {
            isSearchFocused = true
        }
        // 点击空白区域关闭键盘
        .keyboardDismissable()
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
                            Text(LocalizationKey.homeSearchHistory.localized)
                                .font(AppTypography.bodyBold)
                                .foregroundColor(AppColors.textPrimary)
                            Spacer()
                            Button(LocalizationKey.commonClear.localized) {
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
                    Text(LocalizationKey.homeHotSearches.localized)
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
            .shadow(color: Color.black.opacity(0.02), radius: 5, x: 0, y: 2)
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
                // 性能优化：使用 AsyncImageView 替代系统 AsyncImage
                AsyncImageView(
                    urlString: firstImage,
                    placeholder: Image(systemName: "doc.text.fill"),
                    width: 60,
                    height: 60,
                    contentMode: .fill,
                    cornerRadius: AppCornerRadius.small
                )
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
                Text(task.displayTitle)
                    .font(AppTypography.bodyBold)
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(1)
                
                Text(task.displayDescription)
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
        .background(AppColors.cardBackground) // 内容区域背景
        .background(
            RoundedRectangle(cornerRadius: AppCornerRadius.medium, style: .continuous)
                .fill(AppColors.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: AppCornerRadius.medium, style: .continuous)
                        .stroke(Color(UIColor.separator).opacity(0.3), lineWidth: 0.5)
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: AppCornerRadius.medium, style: .continuous)) // 优化：确保圆角边缘干净
        .compositingGroup() // 组合渲染，确保圆角边缘干净
    }
}

struct SearchExpertCard: View {
    let expert: TaskExpert
    
    var body: some View {
        HStack(spacing: AppSpacing.md) {
            // 头像 - 性能优化：使用 AvatarView 替代系统 AsyncImage
            AvatarView(
                urlString: expert.avatar,
                size: 50,
                placeholder: Image(systemName: "person.circle.fill")
            )
            
            // 信息
            VStack(alignment: .leading, spacing: 4) {
                Text(expert.name)
                    .font(AppTypography.bodyBold)
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(1)
                
                if let bio = expert.localizedBio {
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
        .background(AppColors.cardBackground) // 内容区域背景
        .background(
            RoundedRectangle(cornerRadius: AppCornerRadius.medium, style: .continuous)
                .fill(AppColors.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: AppCornerRadius.medium, style: .continuous)
                        .stroke(Color(UIColor.separator).opacity(0.3), lineWidth: 0.5)
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: AppCornerRadius.medium, style: .continuous)) // 优化：确保圆角边缘干净
        .compositingGroup() // 组合渲染，确保圆角边缘干净
    }
}

struct SearchFleaMarketCard: View {
    let item: FleaMarketItem
    
    var body: some View {
        HStack(spacing: AppSpacing.md) {
            // 图片 - 性能优化：使用 AsyncImageView 替代系统 AsyncImage
            if let images = item.images, let firstImage = images.first {
                AsyncImageView(
                    urlString: firstImage,
                    placeholder: Image(systemName: "bag.fill"),
                    width: 60,
                    height: 60,
                    contentMode: .fill,
                    cornerRadius: AppCornerRadius.small
                )
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
        .cardBackground(cornerRadius: AppCornerRadius.medium) // 使用优化后的 cardBackground modifier
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
                Text(post.displayTitle)
                    .font(AppTypography.bodyBold)
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(1)
                
                HStack(spacing: AppSpacing.sm) {
                    HStack(spacing: 2) {
                        Image(systemName: "eye")
                        Text(post.viewCount.formatCount())
                    }
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textTertiary)
                    
                    HStack(spacing: 2) {
                        Image(systemName: "heart")
                        Text(post.likeCount.formatCount())
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
        .cardBackground(cornerRadius: AppCornerRadius.medium)
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
    @StateObject private var viewModel: TasksViewModel = {
        let vm = TasksViewModel()
        // 初始化时立即从推荐任务缓存加载数据，避免视图渲染时显示加载状态
        if let cachedRecommendedTasks = CacheManager.shared.loadTasks(category: nil, city: nil, isRecommended: true) {
            if !cachedRecommendedTasks.isEmpty {
                vm.tasks = cachedRecommendedTasks
                Logger.success("从推荐任务缓存加载了 \(cachedRecommendedTasks.count) 个任务", category: .cache)
            }
        }
        return vm
    }()
    @EnvironmentObject var appState: AppState
    @State private var recordedViews: Set<Int> = []  // 已记录的查看交互（防重复）
    
    /// 加载推荐任务，如果失败或为空则回退到默认任务
    /// 优化：更智能的回退机制，避免不必要的默认任务加载
    private func loadRecommendedTasksWithFallback(forceRefresh: Bool = false) {
        guard appState.isAuthenticated else {
            // 未登录，直接加载默认任务
            if viewModel.tasks.isEmpty && !viewModel.isLoading {
                viewModel.loadTasks(status: "open", forceRefresh: forceRefresh)
            }
            return
        }
        
        // 已登录，先尝试加载推荐任务（增强：包含GPS位置）
        // 注意：loadRecommendedTasks 内部已经会获取GPS位置，这里不需要额外处理
        viewModel.loadRecommendedTasks(limit: 20, algorithm: "hybrid", forceRefresh: forceRefresh)
        
        // 优化：使用更简单的延迟检查机制，避免复杂的监听
        // 延迟检查，如果推荐任务为空或失败，回退到默认任务
        // 注意：RecommendedTasksSection 是 struct，不需要 weak 引用
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            // 如果推荐任务加载完成且为空，且有错误，回退到默认任务
            if !self.viewModel.isLoading && self.viewModel.tasks.isEmpty {
                if self.viewModel.errorMessage != nil {
                    Logger.info("推荐任务加载失败，回退到默认任务", category: .api)
                    self.viewModel.loadTasks(status: "open", forceRefresh: forceRefresh)
                } else {
                    // 没有错误但也没有任务，可能是真的没有推荐任务，不加载默认任务
                    Logger.info("推荐任务为空，但不加载默认任务（避免覆盖）", category: .api)
                }
            }
        }
    }
    
    /// 记录推荐任务的查看交互
    private func recordRecommendedTaskView(taskId: Int, position: Int) {
        // 防重复：同一个任务只记录一次查看
        guard !recordedViews.contains(taskId) else { return }
        recordedViews.insert(taskId)
        
        guard appState.isAuthenticated else { return }
        
        // 异步非阻塞方式记录交互
        // 注意：RecommendedTasksSection 是 struct，不需要 weak 引用
        DispatchQueue.global(qos: .utility).async {
            let deviceType = DeviceInfo.isPad ? "tablet" : "mobile"
            let metadata: [String: Any] = [
                "source": "home_recommended",
                "list_position": position
            ]
            
            // 使用局部变量保持 cancellable 活跃
            var cancellable: AnyCancellable?
            cancellable = APIService.shared.recordTaskInteraction(
                taskId: taskId,
                interactionType: "view",
                deviceType: deviceType,
                isRecommended: true,
                metadata: metadata
            )
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        Logger.warning("记录推荐任务查看失败: \(error.localizedDescription)", category: .api)
                    }
                    cancellable = nil
                },
                receiveValue: { _ in
                    Logger.debug("已记录推荐任务查看: taskId=\(taskId), position=\(position)", category: .api)
                }
            )
            _ = cancellable
        }
    }
    
    /// 增强：记录跳过任务（用于推荐系统负反馈）
    private func recordTaskSkip(taskId: Int) {
        guard appState.isAuthenticated else { return }
        
        // 异步非阻塞方式记录交互
        DispatchQueue.global(qos: .utility).async {
            let deviceType = DeviceInfo.isPad ? "tablet" : "mobile"
            let metadata: [String: Any] = [
                "source": "home_recommended",
                "action": "not_interested"
            ]
            
            var cancellable: AnyCancellable?
            cancellable = APIService.shared.recordTaskInteraction(
                taskId: taskId,
                interactionType: "skip",
                deviceType: deviceType,
                isRecommended: true,
                metadata: metadata
            )
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        Logger.warning("记录跳过任务失败: \(error.localizedDescription)", category: .api)
                    }
                    cancellable = nil
                },
                receiveValue: { _ in
                    Logger.debug("已记录跳过任务: taskId=\(taskId)", category: .api)
                }
            )
            _ = cancellable
        }
    }
    
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
                // 使用水平滚动骨架屏
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: AppSpacing.md) {
                        ForEach(0..<5, id: \.self) { index in
                            TaskCardSkeleton()
                                .frame(width: 200)
                                .listItemAppear(index: index, totalItems: 5)
                        }
                    }
                    .padding(.leading, AppSpacing.md)
                    .padding(.trailing, AppSpacing.lg)
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
                        // 性能优化：缓存 prefix 结果，避免重复计算，并确保稳定的 id
                        let displayedTasks = Array(viewModel.tasks.prefix(10))
                        ForEach(Array(displayedTasks.enumerated()), id: \.element.id) { index, task in
                            NavigationLink(destination: TaskDetailView(taskId: task.id)) {
                                TaskCard(
                                    task: task,
                                    isRecommended: task.isRecommended == true,
                                    onNotInterested: {
                                        // 增强：记录跳过任务（用于推荐系统负反馈）
                                        recordTaskSkip(taskId: task.id)
                                    },
                                    enableLongPress: false  // 首页暂时禁用长按功能
                                )
                                .frame(width: AdaptiveLayout.recommendedTaskCardWidth(screenWidth: UIScreen.main.bounds.width))
                            }
                            .buttonStyle(ScaleButtonStyle()) // 使用ScaleButtonStyle，提供丝滑按压反馈
                            .zIndex(100) // 优化：使用更高的zIndex，确保长按时卡片浮在最上层
                            .id(task.id) // 确保稳定的视图标识
                            .listItemAppear(index: index, totalItems: displayedTasks.count) // 添加错落入场动画
                            .onAppear {
                                // 记录推荐任务的查看交互（用于推荐系统优化）
                                if task.isRecommended == true {
                                    recordRecommendedTaskView(taskId: task.id, position: index)
                                }
                            }
                        }
                    }
                    // 优化：第一个任务对齐屏幕边缘，和banner、活动卡片一致
                    .padding(.leading, AppSpacing.md)  // 左侧只保留标准padding，和banner对齐
                    .padding(.trailing, AppSpacing.lg)  // 右侧保留额外padding，确保最后一个卡片长按时不被裁剪
                }
                // 优化：禁用ScrollView的裁剪，允许contextMenu超出边界显示
                .scrollContentBackground(.hidden)
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: viewModel.tasks.count) // 更流畅的弹簧动画
            }
        }
        // 优化：移除VStack的裁剪限制，允许子视图（特别是contextMenu）超出边界
        .fixedSize(horizontal: false, vertical: true) // 确保VStack不会裁剪子视图
        .task {
            // 优化：先从推荐任务缓存加载，立即显示内容，提升首次进入流畅度
            if viewModel.tasks.isEmpty && !viewModel.isLoading {
                // 先尝试从推荐任务缓存加载，避免显示空状态
                if let cachedRecommendedTasks = CacheManager.shared.loadTasks(category: nil, city: nil, isRecommended: true) {
                    if !cachedRecommendedTasks.isEmpty {
                        viewModel.tasks = cachedRecommendedTasks
                        Logger.success("从推荐任务缓存加载了 \(cachedRecommendedTasks.count) 个任务", category: .cache)
                    }
                }
                
                // 延迟加载网络数据，让视图先渲染完成
                try? await _Concurrency.Task.sleep(nanoseconds: 50_000_000) // 50ms
                
                if !appState.isAuthenticated {
                    // 未登录，加载默认任务
                    viewModel.loadTasks(status: "open")
                } else {
                    // 已登录，使用推荐 API 加载推荐任务
                    loadRecommendedTasksWithFallback()
                }
            }
        }
        // 移除自动刷新逻辑：不再监听任务更新通知，避免每次返回时都刷新
        // 用户可以通过下拉刷新手动更新推荐任务
        .onReceive(NotificationCenter.default.publisher(for: .refreshRecommendedTasks)) { _ in
            // 手动刷新推荐任务（用户下拉刷新时触发）
            if appState.isAuthenticated {
                loadRecommendedTasksWithFallback(forceRefresh: true)
            } else {
                viewModel.loadTasks(status: "open", forceRefresh: true)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .refreshHomeContent)) { _ in
            // 刷新推荐任务（首页下拉刷新时触发）
            if appState.isAuthenticated {
                loadRecommendedTasksWithFallback(forceRefresh: true)
            } else {
                viewModel.loadTasks(status: "open", forceRefresh: true)
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
                    CompactLoadingView()
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
                // 限制最多显示15条
                ForEach(Array(viewModel.activities.prefix(15).enumerated()), id: \.element.id) { index, activity in
                    ActivityRow(activity: activity)
                        .listItemAppear(index: index, totalItems: min(15, viewModel.activities.count)) // 添加错落入场动画
                        .onAppear {
                            // 当显示最后3个项目时，加载更多（但不超过15条）
                            let displayedCount = min(15, viewModel.activities.count)
                            let threshold = max(0, displayedCount - 3)
                            if index >= threshold && viewModel.hasMore && !viewModel.isLoadingMore && !viewModel.isLoading && viewModel.activities.count < 15 {
                                viewModel.loadMoreActivities()
                            }
                        }
                }
                
                // 加载更多指示器
                if viewModel.isLoadingMore {
                    HStack {
                        Spacer()
                        CompactLoadingView()
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
        .task {
            // 使用 task 替代 onAppear，避免重复加载
            // 延迟加载，避免启动时阻塞主线程
            if viewModel.activities.isEmpty && !viewModel.isLoading {
                // 延迟1秒加载，让关键内容先显示
                try? await _Concurrency.Task.sleep(nanoseconds: 1_000_000_000)
                if viewModel.activities.isEmpty && !viewModel.isLoading {
                    viewModel.loadRecentActivities()
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .refreshHomeContent)) { _ in
            // 刷新最新动态（首页下拉刷新时触发）
            viewModel.refresh()
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
                // 合并用户名和动作文本，确保单行显示
                (Text(activity.author?.name ?? LocalizationKey.appUser.localized)
                    .font(AppTypography.body)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.textPrimary) +
                 Text(" \(activity.actionText)")
                    .font(AppTypography.body)
                    .foregroundColor(AppColors.textSecondary))
                    .lineLimit(1)
                    .truncationMode(.tail)
                
                Text(activity.title)
                    .font(AppTypography.caption) // 使用 caption
                    .fontWeight(.medium)
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                
                if let description = activity.description, !description.isEmpty {
                    Text(description)
                        .font(AppTypography.caption) // 使用 caption
                        .foregroundColor(AppColors.textSecondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
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
        .cardBackground(cornerRadius: AppCornerRadius.large)
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
                // 使用水平滚动骨架屏
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: AppSpacing.md) {
                        ForEach(0..<3, id: \.self) { index in
                            ActivityCardSkeleton()
                                .frame(width: 280)
                                .listItemAppear(index: index, totalItems: 3)
                        }
                    }
                    .padding(.horizontal, AppSpacing.md)
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
                        // 性能优化：缓存 prefix 结果，避免重复计算，并确保稳定的 id
                        let displayedActivities = Array(viewModel.activities.prefix(10))
                        ForEach(Array(displayedActivities.enumerated()), id: \.element.id) { index, activity in
                            NavigationLink(destination: ActivityDetailView(activityId: activity.id)) {
                                ActivityCardView(
                                    activity: activity,
                                    showEndedBadge: false,
                                    isFavorited: viewModel.favoritedActivityIds.contains(activity.id)
                                )
                                .frame(width: 280)
                            }
                            .buttonStyle(ScaleButtonStyle())
                            .id(activity.id) // 确保稳定的视图标识
                            .listItemAppear(index: index, totalItems: displayedActivities.count) // 添加错落入场动画
                        }
                    }
                    .padding(.horizontal, AppSpacing.md)
                }
                .animation(.easeInOut(duration: 0.1), value: viewModel.activities.count) // 更快的过渡动画
            }
        }
        .task {
            // 使用 task 替代 onAppear，避免重复加载
            // 立即加载，优先从缓存读取（预加载的数据已经在缓存中）
            // 注意：由于 loadActivities 传入 status: "open"，不会从缓存加载
            // 但预加载的数据已经保存到缓存，这里立即加载可以快速显示
            if viewModel.activities.isEmpty && !viewModel.isLoading {
                viewModel.loadActivities(status: "open", includeEnded: false)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .refreshHomeContent)) { _ in
            // 刷新热门活动（首页下拉刷新时触发）
            viewModel.loadActivities(status: "open", includeEnded: false, forceRefresh: true)
        }
    }
}

// 广告轮播区域组件
struct BannerCarouselSection: View {
    @StateObject private var viewModel = BannerCarouselViewModel()
    
    var body: some View {
        VStack(spacing: 0) {
            if viewModel.isLoading && viewModel.banners.isEmpty {
                // 使用骨架屏替代加载指示器
                BannerSkeleton()
            } else if viewModel.banners.isEmpty {
                // 无广告时不显示
                Color.clear
                    .frame(height: 0)
            } else {
                BannerCarouselView(banners: viewModel.banners)
            }
        }
        .task {
            // 使用 task 替代 onAppear，避免重复加载
            // 如果初始化时已从缓存加载了数据，只需要在后台刷新
            // 如果还没有数据，才需要加载
            if viewModel.banners.isEmpty && !viewModel.isLoading {
                viewModel.loadBanners()
            } else if !viewModel.banners.isEmpty {
                // 已经有缓存数据，在后台静默刷新
                viewModel.loadBanners()
            }
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
    
    // 硬编码的跳蚤市场Banner（始终显示在第一个位置）
    private var hardcodedFleaMarketBanner: Banner {
        Banner(
            id: -1, // 使用负数ID，避免与后端Banner冲突
            imageUrl: "local:FleaMarketBanner", // 使用本地Assets中的跳蚤市场图片
            title: LocalizationKey.fleaMarketFleaMarket.localized,
            subtitle: LocalizationKey.fleaMarketSubtitle.localized,
            linkUrl: "/flea-market",
            linkType: "internal",
            order: -999 // 确保始终是第一个
        )
    }
    
    // 硬编码的学生认证Banner（始终显示在第二个位置）
    private var hardcodedStudentVerificationBanner: Banner {
        Banner(
            id: -2, // 使用负数ID，避免与后端Banner冲突
            imageUrl: "local:StudentVerificationBanner", // 使用本地Assets中的学生认证图片
            title: LocalizationKey.studentVerificationVerification.localized,
            subtitle: LocalizationKey.studentVerificationDescription.localized,
            linkUrl: "/student-verification",
            linkType: "internal",
            order: -998 // 确保始终是第二个
        )
    }
    
    init() {
        // 初始化时立即从缓存加载数据，避免视图渲染时显示加载状态
        loadBannersFromCache()
    }
    
    /// 从缓存加载 Banner（优先内存缓存，快速响应）
    private func loadBannersFromCache() {
        // 先快速检查内存缓存（同步，很快）
        if let cachedBanners = CacheManager.shared.loadBanners(), !cachedBanners.isEmpty {
            var sortedBanners = cachedBanners.sorted { $0.order < $1.order }
            // 将硬编码的Banner添加到最前面（学生认证在第二个位置）
            sortedBanners.insert(self.hardcodedStudentVerificationBanner, at: 0)
            sortedBanners.insert(self.hardcodedFleaMarketBanner, at: 0)
            self.banners = sortedBanners
            Logger.success("初始化时从缓存加载了 \(cachedBanners.count) 个 Banner", category: .cache)
        }
    }
    
    func loadBanners() {
        guard !isLoading else { return }
        errorMessage = nil
        
        // 如果已经有缓存数据（初始化时已加载），不需要再次从缓存加载
        // 只需要在后台刷新数据
        if banners.isEmpty {
            // 没有缓存数据，需要显示加载状态
            isLoading = true
        }
        
        apiService.getBanners()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    guard let self = self else { return }
                    self.isLoading = false
                    if case .failure(let error) = completion {
                        self.errorMessage = error.localizedDescription
                        Logger.error("加载广告失败: \(error.localizedDescription)", category: .api)
                        // 如果之前没有缓存数据，显示硬编码的Banner
                        if self.banners.isEmpty {
                            self.banners = [self.hardcodedFleaMarketBanner, self.hardcodedStudentVerificationBanner]
                        }
                    }
                },
                receiveValue: { [weak self] response in
                    guard let self = self else { return }
                    // 将后端返回的Banner排序
                    var serverBanners = response.banners.sorted { $0.order < $1.order }
                    
                    // 将硬编码的Banner添加到最前面（学生认证在第二个位置）
                    serverBanners.insert(self.hardcodedStudentVerificationBanner, at: 0)
                    serverBanners.insert(self.hardcodedFleaMarketBanner, at: 0)
                    
                    // 保存到缓存
                    CacheManager.shared.saveBanners(response.banners)
                    
                    self.banners = serverBanners
                    self.isLoading = false
                    self.errorMessage = nil
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

// MARK: - Location Service Helper
/// 初始化位置服务（提取重复逻辑，添加防重复调用机制）
private var locationServiceInitialized = Set<String>()

fileprivate func initializeLocationService(
    locationService: LocationService,
    viewName: String,
    onLocationReady: @escaping () -> Void
) {
    // 防止重复初始化（同一视图多次调用）
    if locationServiceInitialized.contains(viewName) {
        Logger.debug("\(viewName) 位置服务已初始化，跳过重复调用", category: .ui)
        // 如果已有位置，立即执行回调
        if locationService.currentLocation != nil {
            onLocationReady()
        }
        return
    }
    
    locationServiceInitialized.insert(viewName)
    
    // 使用后台线程处理，避免阻塞主线程
    DispatchQueue.global(qos: .userInitiated).async {
        let isAuthorized = locationService.isAuthorized
        let hasLocation = locationService.currentLocation != nil
        
        DispatchQueue.main.async {
            // 请求位置权限（用于距离排序）
            if !isAuthorized {
                locationService.requestAuthorization()
            } else if !hasLocation {
                // 延迟请求位置，避免阻塞主线程
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    locationService.requestLocation()
                }
            }
            
            // 如果有位置，延迟执行回调，避免阻塞主线程
            if hasLocation {
                // 延迟执行，让视图先渲染完成
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    onLocationReady()
                }
            } else {
                // 延迟执行回调，避免阻塞主线程
                // 位置更新会通过 onChange 监听器触发
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    // 如果位置仍未获取，也执行回调（使用默认排序）
                    onLocationReady()
                }
            }
        }
    }
}

// MARK: - 筛选标签组件
struct FilterTag: View {
    let title: String
    let isSelected: Bool
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                Text(title)
            }
            .font(AppTypography.caption)
            .fontWeight(isSelected ? .semibold : .regular)
            .foregroundColor(isSelected ? .white : AppColors.textSecondary)
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.xs)
            .background(isSelected ? AppColors.primary : AppColors.cardBackground)
            .cornerRadius(AppCornerRadius.pill)
            .overlay(
                RoundedRectangle(cornerRadius: AppCornerRadius.pill)
                    .stroke(isSelected ? AppColors.primary : AppColors.separator.opacity(0.3), lineWidth: isSelected ? 0 : 1)
            )
        }
    }
}
