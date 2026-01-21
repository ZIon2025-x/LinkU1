import SwiftUI
import Foundation
import Combine

struct MyServiceApplicationsView: View {
    @StateObject private var viewModel = MyActivitiesViewModel()
    @State private var selectedTab: ActivityTab = .all
    
    enum ActivityTab: String, CaseIterable {
        case all = "activity.tab.all"
        case applied = "activity.tab.applied"
        case favorited = "activity.tab.favorited"
        
        var localized: String {
            return LocalizationKey(rawValue: self.rawValue)?.localized ?? self.rawValue
        }
    }
    
    var body: some View {
        ZStack {
            AppColors.background
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 标签页选择器 - 固定在顶部
                HStack(spacing: 0) {
                    ForEach(ActivityTab.allCases, id: \.self) { tab in
                        Button(action: {
                            HapticFeedback.selection()
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                selectedTab = tab
                            }
                        }) {
                            VStack(spacing: 4) {
                                Text(tab.localized)
                                    .font(AppTypography.body)
                                    .fontWeight(selectedTab == tab ? .semibold : .regular)
                                    .foregroundColor(selectedTab == tab ? AppColors.primary : AppColors.textSecondary)
                                    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: selectedTab)
                                
                                Rectangle()
                                    .fill(selectedTab == tab ? AppColors.primary : Color.clear)
                                    .frame(height: 2)
                                    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: selectedTab)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                }
                .padding(.horizontal, AppSpacing.md)
                .padding(.vertical, AppSpacing.sm)
                .background(AppColors.cardBackground)
                
                // 内容区域 - 使用 TabView 避免布局变化
                TabView(selection: $selectedTab) {
                    ActivityListViewContent(
                        viewModel: viewModel,
                        type: .all
                    )
                    .tag(ActivityTab.all)
                    
                    ActivityListViewContent(
                        viewModel: viewModel,
                        type: .applied
                    )
                    .tag(ActivityTab.applied)
                    
                    ActivityListViewContent(
                        viewModel: viewModel,
                        type: .favorited
                    )
                    .tag(ActivityTab.favorited)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.interactiveSpring(response: 0.4, dampingFraction: 0.9), value: selectedTab)
            }
        }
        .navigationTitle(LocalizationKey.profileMyApplications.localized)
        .navigationBarTitleDisplayMode(.inline)
        .enableSwipeBack()
        .toolbarBackground(AppColors.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .onAppear {
            // 初始加载全部数据
            viewModel.loadAllActivities()
        }
        .onChange(of: selectedTab) { _ in
            // 切换标签时不需要重新加载，数据已经从 allActivities 中过滤显示
            // 下拉刷新时会重新加载对应类型的数据
        }
    }
}

// 活动列表内容视图 - 独立组件，避免条件渲染
struct ActivityListViewContent: View {
    @ObservedObject var viewModel: MyActivitiesViewModel
    let type: MyServiceApplicationsView.ActivityTab
    
    // 从 ViewModel 获取当前类型的数据（从缓存中过滤）
    // 直接依赖 allActivities 确保视图能响应数据变化
    private var filteredActivities: [ActivityWithType] {
        // 优先从缓存获取
        let typeString: String
        switch type {
        case .all: typeString = "all"
        case .applied: typeString = "applied"
        case .favorited: typeString = "favorited"
        }
        
        // 如果已加载过该类型，从缓存返回
        if let cached = viewModel.cachedActivities[typeString] {
            return cached
        }
        
        // 如果加载过全部数据，从全部数据中过滤
        if !viewModel.allActivities.isEmpty && typeString != "all" {
            return filterActivities(viewModel.allActivities, type: typeString)
        }
        
        return []
    }
    
    // 过滤活动数据
    private func filterActivities(_ activities: [ActivityWithType], type: String) -> [ActivityWithType] {
        switch type {
        case "applied":
            return activities.filter { $0.type == "applied" || $0.type == "both" }
        case "favorited":
            return activities.filter { $0.type == "favorited" || $0.type == "both" }
        default:
            return activities
        }
    }
    
    // 判断是否正在加载（只在初始加载且没有数据时显示）
    private var showLoading: Bool {
        viewModel.isLoading && filteredActivities.isEmpty && viewModel.loadedTypes.isEmpty
    }
    
    var body: some View {
        ZStack {
            AppColors.background
                .ignoresSafeArea()
            
            if showLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if filteredActivities.isEmpty {
                EmptyStateView(
                    icon: "calendar",
                    title: type == .favorited ? LocalizationKey.taskExpertNoFavorites.localized : LocalizationKey.taskExpertNoActivities.localized,
                    message: type == .favorited ? LocalizationKey.taskExpertNoFavoritesMessage.localized : (type == .applied ? LocalizationKey.taskExpertNoAppliedMessage.localized : LocalizationKey.taskExpertNoActivitiesMessage.localized)
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: AppSpacing.md) {
                        ForEach(filteredActivities) { activity in
                            NavigationLink(destination: ActivityDetailView(activityId: activity.id)) {
                                ActivityCard(activity: activity)
                            }
                            .buttonStyle(ScaleButtonStyle())
                        }
                    }
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.vertical, AppSpacing.sm)
                }
            }
        }
        .refreshable {
            let typeString: String
            switch type {
            case .all: typeString = "all"
            case .applied: typeString = "applied"
            case .favorited: typeString = "favorited"
            }
            viewModel.loadActivities(type: typeString, forceRefresh: true)
        }
    }
}

// 活动卡片
struct ActivityCard: View {
    let activity: ActivityWithType
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 图片区域
            ZStack(alignment: .topTrailing) {
                if let images = activity.images, let firstImage = images.first, !firstImage.isEmpty {
                    AsyncImageView(
                        urlString: firstImage,
                        placeholder: Image(systemName: "photo.fill")
                    )
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 160)
                    .frame(maxWidth: .infinity)
                    .clipped()
                } else {
                    placeholderBackground()
                }
                
                // 类型标签
                HStack(spacing: 4) {
                    if activity.type == "applied" || activity.type == "both" {
                        Text(LocalizationKey.taskExpertApplied.localized)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(AppColors.success)
                            .clipShape(Capsule())
                    }
                    if activity.type == "favorited" || activity.type == "both" {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.white)
                            .padding(4)
                            .background(Color.red)
                            .clipShape(Circle())
                    }
                }
                .padding(AppSpacing.sm)
            }
            
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Text(activity.title)
                    .font(AppTypography.bodyBold)
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(2)
                
                HStack {
                    // 价格
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text(activity.currency == "GBP" ? "£" : "¥")
                            .font(.system(size: 12, weight: .bold))
                        Text(String(format: "%.0f", activity.discountedPricePerParticipant ?? activity.originalPricePerParticipant))
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                    }
                    .foregroundColor(AppColors.primary)
                    
                    Spacer()
                    
                    // 参与人数进度
                    HStack(spacing: 4) {
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 10))
                        Text("\(activity.currentParticipants)/\(activity.maxParticipants)")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(AppColors.textSecondary)
                }
                
                HStack {
                    Label(activity.location, systemImage: "mappin.circle.fill")
                        .font(.system(size: 11))
                        .foregroundColor(AppColors.textTertiary)
                    
                    Spacer()
                    
                    if activity.hasTimeSlots {
                        Text(LocalizationKey.taskExpertByAppointment.localized)
                            .font(.system(size: 10, weight: .bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(AppColors.warning.opacity(0.1))
                            .foregroundColor(AppColors.warning)
                            .cornerRadius(4)
                    }
                }
            }
            .padding(AppSpacing.md)
        }
        .background(AppColors.cardBackground)
        .cornerRadius(AppCornerRadius.large)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
    }
    
    private func placeholderBackground() -> some View {
        ZStack {
            Rectangle()
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            AppColors.primary.opacity(0.1),
                            AppColors.primary.opacity(0.05)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(height: 160)
            
            IconStyle.icon("calendar.badge.plus", size: 40)
                .foregroundColor(AppColors.primary.opacity(0.3))
        }
    }
}

// 活动模型（带类型信息）
struct ActivityWithType: Codable, Identifiable {
    let id: Int
    let title: String
    let description: String
    let expertId: String
    let expertServiceId: Int?
    let location: String
    let taskType: String
    let rewardType: String
    let originalPricePerParticipant: Double
    let discountPercentage: Double?
    let discountedPricePerParticipant: Double?
    let currency: String
    let pointsReward: Int?
    let maxParticipants: Int
    let minParticipants: Int
    let currentParticipants: Int
    let status: String
    let isPublic: Bool
    let deadline: String?
    let activityEndDate: String?
    let images: [String]?
    let hasTimeSlots: Bool
    let type: String // "applied", "favorited", "both"
    let participantStatus: String? // 参与状态（如果已申请）
    
    enum CodingKeys: String, CodingKey {
        case id, title, description
        case expertId = "expert_id"
        case expertServiceId = "expert_service_id"
        case location
        case taskType = "task_type"
        case rewardType = "reward_type"
        case originalPricePerParticipant = "original_price_per_participant"
        case discountPercentage = "discount_percentage"
        case discountedPricePerParticipant = "discounted_price_per_participant"
        case currency
        case pointsReward = "points_reward"
        case maxParticipants = "max_participants"
        case minParticipants = "min_participants"
        case currentParticipants = "current_participants"
        case status
        case isPublic = "is_public"
        case deadline
        case activityEndDate = "activity_end_date"
        case images
        case hasTimeSlots = "has_time_slots"
        case type
        case participantStatus = "participant_status"
    }
    
    var isEnded: Bool {
        let endedStatuses = ["ended", "cancelled", "completed", "closed"]
        if endedStatuses.contains(status.lowercased()) {
            return true
        }
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let now = Date()
        if let endDateStr = activityEndDate,
           let endDate = dateFormatter.date(from: endDateStr) ?? parseDate(endDateStr) {
            if endDate < now {
                return true
            }
        }
        if let deadlineStr = deadline,
           let deadlineDate = dateFormatter.date(from: deadlineStr) ?? parseDate(deadlineStr) {
            if deadlineDate < now {
                return true
            }
        }
        return false
    }
    
    var isFull: Bool {
        currentParticipants >= maxParticipants
    }
    
    private func parseDate(_ dateStr: String) -> Date? {
        let formats = [
            "yyyy-MM-dd'T'HH:mm:ss.SSSSSSZ",
            "yyyy-MM-dd'T'HH:mm:ssZ",
            "yyyy-MM-dd'T'HH:mm:ss",
            "yyyy-MM-dd HH:mm:ss",
            "yyyy-MM-dd"
        ]
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        for format in formats {
            formatter.dateFormat = format
            if let date = formatter.date(from: dateStr) {
                return date
            }
        }
        return nil
    }
}

// 我的活动ViewModel
class MyActivitiesViewModel: ObservableObject {
    @Published var allActivities: [ActivityWithType] = [] // 全部活动（用于缓存和过滤）
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // 缓存已加载的数据（公开访问，用于视图过滤）
    var cachedActivities: [String: [ActivityWithType]] = [:]
    var loadedTypes: Set<String> = []
    
    private let apiService = APIService.shared
    private var cancellables = Set<AnyCancellable>()
    
    // 根据类型获取活动列表（从缓存中过滤）
    func getActivities(for type: MyServiceApplicationsView.ActivityTab) -> [ActivityWithType] {
        let typeString: String
        switch type {
        case .all: typeString = "all"
        case .applied: typeString = "applied"
        case .favorited: typeString = "favorited"
        }
        
        // 如果已加载过该类型，直接返回缓存
        if let cached = cachedActivities[typeString] {
            return cached
        }
        
        // 如果加载过全部数据，从全部数据中过滤
        if !allActivities.isEmpty && typeString != "all" {
            let filtered = filterActivities(allActivities, type: typeString)
            // 缓存过滤后的结果，避免重复过滤
            cachedActivities[typeString] = filtered
            return filtered
        }
        
        return []
    }
    
    // 过滤活动数据
    private func filterActivities(_ activities: [ActivityWithType], type: String) -> [ActivityWithType] {
        switch type {
        case "applied":
            return activities.filter { $0.type == "applied" || $0.type == "both" }
        case "favorited":
            return activities.filter { $0.type == "favorited" || $0.type == "both" }
        default:
            return activities
        }
    }
    
    // 加载活动数据
    func loadActivities(type: String = "all", forceRefresh: Bool = false) {
        // 如果已加载过且不强制刷新，直接返回
        if !forceRefresh && loadedTypes.contains(type) {
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        let endpoint = "/api/my/activities?type=\(type)&limit=50&offset=0"
        
        apiService.request(MyActivitiesFullResponse.self, endpoint, method: "GET")
            .sink(
                receiveCompletion: { [weak self] result in
                    DispatchQueue.main.async {
                        self?.isLoading = false
                        if case .failure(let error) = result {
                            ErrorHandler.shared.handle(error, context: LocalizationKey.activityLoadFailed.localized)
                            self?.errorMessage = error.userFriendlyMessage
                        }
                    }
                },
                receiveValue: { [weak self] response in
                    DispatchQueue.main.async {
                        self?.isLoading = false
                        if response.success {
                            // 缓存数据
                            self?.cachedActivities[type] = response.data.activities
                            self?.loadedTypes.insert(type)
                            
                            // 如果是加载全部，更新 allActivities（触发视图更新）
                            if type == "all" {
                                self?.allActivities = response.data.activities
                            }
                        } else {
                            self?.errorMessage = LocalizationKey.errorDecodingError.localized
                        }
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    // 加载所有类型的数据（用于初始加载）
    func loadAllActivities() {
        // 如果已经加载过全部，就不重复加载
        if loadedTypes.contains("all") {
            return
        }
        loadActivities(type: "all")
    }
}
