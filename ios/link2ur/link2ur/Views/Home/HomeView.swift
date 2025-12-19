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
        NavigationView {
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
                            TabButton(title: "达人", isSelected: selectedTab == 0) {
                                if selectedTab != 0 {
                                    HapticFeedback.selection()
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        selectedTab = 0
                                    }
                                }
                            }
                            
                            TabButton(title: "推荐", isSelected: selectedTab == 1) {
                                if selectedTab != 1 {
                                    HapticFeedback.selection()
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        selectedTab = 1
                                    }
                                }
                            }
                            
                            TabButton(title: "附近", isSelected: selectedTab == 2) {
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
                            Text("你好，\(appState.currentUser?.name ?? "Link²Ur用户")")
                                .font(AppTypography.title2) // 使用 title2
                                .foregroundColor(AppColors.textPrimary)
                            
                            Text("今天想做点什么？")
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
                    title: "附近暂无任务",
                    message: "附近还没有任务发布，快来发布第一个任务吧！"
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
            
            if viewModel.tasks.isEmpty {
                print("🏠 [NearbyTasksView] 加载任务列表...")
                // 只加载开放中的任务（不指定城市，用于按距离排序）
                viewModel.loadTasks(status: "open")
            } else {
                print("🏠 [NearbyTasksView] 任务列表已存在，共\(viewModel.tasks.count)条")
                // 即使已有数据，也尝试重新排序（如果位置已更新）
                if locationService.currentLocation != nil {
                    print("🏠 [NearbyTasksView] 位置已可用，触发重新排序...")
                }
            }
        }
        .refreshable {
            print("🔄 [NearbyTasksView] 下拉刷新")
            // 刷新位置
            if locationService.isAuthorized {
                print("🔄 [NearbyTasksView] 刷新位置...")
                locationService.requestLocation()
            }
            // 只加载开放中的任务（不指定城市，用于按距离排序）
            viewModel.loadTasks(status: "open", forceRefresh: true)
        }
    }
}

// 菜单视图
struct MenuView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    NavigationLink(destination: ProfileView()) {
                        Label("我的", systemImage: "person.fill")
                    }
                    
                    NavigationLink(destination: TasksView()) {
                        Label("任务大厅", systemImage: "list.bullet")
                    }
                    
                    NavigationLink(destination: TaskExpertListView()) {
                        Label("任务达人", systemImage: "star.fill")
                    }
                    
                    NavigationLink(destination: ForumView()) {
                        Label("论坛", systemImage: "bubble.left.and.bubble.right.fill")
                    }
                    
                    NavigationLink(destination: LeaderboardView()) {
                        Label("排行榜", systemImage: "trophy.fill")
                    }
                    
                    NavigationLink(destination: FleaMarketView()) {
                        Label("跳蚤市场", systemImage: "cart.fill")
                    }
                    
                    NavigationLink(destination: ActivityListView()) {
                        Label("活动", systemImage: "calendar.badge.plus")
                    }
                    
                    NavigationLink(destination: CouponPointsView()) {
                        Label("积分与优惠券", systemImage: "star.fill")
                    }
                    
                    NavigationLink(destination: StudentVerificationView()) {
                        Label("学生认证", systemImage: "person.badge.shield.checkmark.fill")
                    }
                }
                
                Section {
                    NavigationLink(destination: SettingsView()) {
                        Label("设置", systemImage: "gearshape.fill")
                    }
                }
            }
            .navigationTitle("菜单")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") {
                        dismiss()
                    }
                }
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
                            Text("搜索达人")
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
                                title: "暂无任务达人",
                                message: "还没有任务达人，敬请期待..."
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
    @State private var searchText = ""
    
    var body: some View {
        NavigationView {
            VStack {
                // 搜索框
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(AppColors.textSecondary)
                    
                    TextField("搜索任务、达人、商品...", text: $searchText)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.search)
                        .font(.system(size: 16))
                }
                .padding()
                .background(AppColors.cardBackground)
                .cornerRadius(10)
                .padding()
                
                Spacer()
                
                // 搜索结果或提示
                if searchText.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 50))
                            .foregroundColor(AppColors.textSecondary.opacity(0.5))
                        Text("输入关键词搜索")
                            .foregroundColor(AppColors.textSecondary)
                    }
                } else {
                    Text("搜索结果：\(searchText)")
                        .foregroundColor(AppColors.textPrimary)
                }
                
                Spacer()
            }
            .navigationTitle("搜索")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") {
                        dismiss()
                    }
                }
            }
        }
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
                Text("推荐任务")
                    .font(AppTypography.title3) // 使用 title3
                    .foregroundColor(AppColors.textPrimary)
                
                Spacer()
                
                NavigationLink(destination: TasksView()) {
                    HStack(spacing: 4) {
                        Text("查看全部")
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
                    title: "暂无推荐任务",
                    message: "还没有推荐任务，快去任务大厅看看吧！"
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
            Text("最新动态")
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
                    title: "暂无动态",
                    message: "还没有最新动态"
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
                        Text("没有更多动态了")
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
                Text("热门活动")
                    .font(AppTypography.title3)
                    .foregroundColor(AppColors.textPrimary)
                
                Spacer()
                
                NavigationLink(destination: ActivityListView()) {
                    HStack(spacing: 4) {
                        Text("查看全部")
                            .font(AppTypography.body) // 使用 body
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
                    title: "暂无活动",
                    message: "目前还没有活动，敬请期待..."
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
                            Text("加载中...")
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
                    Text("查看活动")
                        .font(AppTypography.title3)
                        .foregroundColor(AppColors.textPrimary)
                        .lineLimit(2)
                    
                    Text("点击查看最新活动")
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
                    Text("多人")
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textSecondary)
                }
                
                Spacer()
                
                HStack(spacing: AppSpacing.xs) {
                    IconStyle.icon("arrow.right.circle.fill", size: IconStyle.small)
                        .foregroundColor(AppColors.primary)
                    Text("查看")
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
