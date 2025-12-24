import SwiftUI
import Foundation
import Combine

struct MyServiceApplicationsView: View {
    @StateObject private var viewModel = MyActivitiesViewModel()
    @State private var selectedTab: ActivityTab = .all
    
    enum ActivityTab: String, CaseIterable {
        case all = "全部"
        case applied = "申请过的"
        case favorited = "收藏的"
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                AppColors.background
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // 标签页选择器
                    HStack(spacing: 0) {
                        ForEach(ActivityTab.allCases, id: \.self) { tab in
                            Button(action: {
                                selectedTab = tab
                                viewModel.loadActivities(type: tab.rawValue == "全部" ? "all" : (tab.rawValue == "申请过的" ? "applied" : "favorited"))
                            }) {
                                VStack(spacing: 4) {
                                    Text(tab.rawValue)
                                        .font(AppTypography.body)
                                        .fontWeight(selectedTab == tab ? .semibold : .regular)
                                        .foregroundColor(selectedTab == tab ? AppColors.primary : AppColors.textSecondary)
                                    
                                    if selectedTab == tab {
                                        Rectangle()
                                            .fill(AppColors.primary)
                                            .frame(height: 2)
                                    } else {
                                        Rectangle()
                                            .fill(Color.clear)
                                            .frame(height: 2)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                            }
                        }
                    }
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.vertical, AppSpacing.sm)
                    .background(AppColors.cardBackground)
                    
                    // 活动列表
                    if viewModel.isLoading && viewModel.activities.isEmpty {
                        ProgressView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if viewModel.activities.isEmpty {
                        EmptyStateView(
                            icon: "calendar",
                            title: selectedTab == .favorited ? "暂无收藏" : "暂无活动",
                            message: selectedTab == .favorited ? "您还没有收藏任何活动" : (selectedTab == .applied ? "您还没有申请过任何活动" : "您还没有申请或收藏任何活动")
                        )
                    } else {
                        ScrollView {
                            LazyVStack(spacing: AppSpacing.md) {
                                ForEach(viewModel.activities) { activity in
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
            }
            .navigationTitle("我的活动")
            .navigationBarTitleDisplayMode(.inline)
            .enableSwipeBack()
            .toolbarBackground(AppColors.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .refreshable {
                viewModel.loadActivities(type: selectedTab.rawValue == "全部" ? "all" : (selectedTab.rawValue == "申请过的" ? "applied" : "favorited"))
            }
            .onAppear {
                if viewModel.activities.isEmpty {
                    viewModel.loadActivities(type: "all")
                }
            }
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
                        Text("已申请")
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
                        Text("预约制")
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
    @Published var activities: [ActivityWithType] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let apiService = APIService.shared
    private var cancellables = Set<AnyCancellable>()
    
    func loadActivities(type: String = "all") {
        isLoading = true
        errorMessage = nil
        
        var endpoint = "/api/my/activities?type=\(type)&limit=50&offset=0"
        
        apiService.request([String: Any].self, endpoint, method: "GET")
            .sink(
                receiveCompletion: { [weak self] result in
                    self?.isLoading = false
                    if case .failure(let error) = result {
                        ErrorHandler.shared.handle(error, context: "加载我的活动")
                        self?.errorMessage = error.userFriendlyMessage
                    }
                },
                receiveValue: { [weak self] response in
                    self?.isLoading = false
                    if let data = response["data"] as? [String: Any],
                       let activitiesArray = data["activities"] as? [[String: Any]] {
                        do {
                            let jsonData = try JSONSerialization.data(withJSONObject: activitiesArray)
                            let decoder = JSONDecoder()
                            self?.activities = try decoder.decode([ActivityWithType].self, from: jsonData)
                        } catch {
                            Logger.error("解析活动数据失败: \(error.localizedDescription)", category: .api)
                            self?.errorMessage = "数据解析失败"
                        }
                    }
                }
            )
            .store(in: &cancellables)
    }
}

// 申请卡片（保留用于向后兼容，但不再使用）
struct ApplicationCard: View {
    let application: ServiceApplication
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 服务名称和状态
            HStack {
                Text(application.serviceName ?? "服务")
                    .font(.headline)
                    .foregroundColor(AppColors.textPrimary)
                
                Spacer()
                
                ApplicationStatusBadge(status: application.status)
            }
            
            // 任务达人
            if let expertName = application.expertName {
                HStack {
                    Image(systemName: "person.fill")
                        .foregroundColor(AppColors.textSecondary)
                    Text(expertName)
                        .font(.subheadline)
                        .foregroundColor(AppColors.textSecondary)
                }
            }
            
            // 申请留言
            if let message = application.applicationMessage {
                Text(message)
                    .font(.subheadline)
                    .foregroundColor(AppColors.textPrimary)
                    .padding(AppSpacing.sm)
                    .background(AppColors.primaryLight)
                    .cornerRadius(AppCornerRadius.small)
            }
            
            // 议价信息
            if application.status == "negotiating", let counterPrice = application.counterPrice {
                VStack(alignment: .leading, spacing: 8) {
                    Text(LocalizationKey.taskExpertExpertNegotiatePrice.localized)
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)
                    Text("¥ \(String(format: "%.2f", counterPrice))")
                        .font(.headline)
                        .foregroundColor(AppColors.error)
                }
                .padding(AppSpacing.sm)
                .background(AppColors.warning.opacity(0.1))
                .cornerRadius(AppCornerRadius.small)
            }
            
            // 关联任务
            if let taskId = application.taskId {
                NavigationLink(destination: Text("任务详情: \(taskId)")) {
                    HStack {
                        Text(LocalizationKey.taskExpertViewTask.localized)
                            .font(.subheadline)
                            .foregroundColor(AppColors.primary)
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(AppColors.primary)
                    }
                }
            }
            
            // 时间
            Text(formatTime(application.createdAt))
                .font(.caption)
                .foregroundColor(AppColors.textSecondary)
        }
        .padding(AppSpacing.md)
        .background(AppColors.cardBackground)
        .cornerRadius(AppCornerRadius.medium)
        .shadow(color: AppShadow.small.color, radius: AppShadow.small.radius, x: AppShadow.small.x, y: AppShadow.small.y)
    }
    
    private func formatTime(_ timeString: String) -> String {
        return DateFormatterHelper.shared.formatTime(timeString)
    }
}

// 申请状态标签
struct ApplicationStatusBadge: View {
    let status: String
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(statusColor)
                .frame(width: 6, height: 6)
            Text(statusText)
                .font(.caption)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(statusColor.opacity(0.15))
        .foregroundColor(statusColor)
        .cornerRadius(AppCornerRadius.small)
    }
    
    private var statusColor: Color {
        switch status {
        case "pending": return AppColors.warning
        case "negotiating": return AppColors.primary
        case "price_agreed": return AppColors.success
        case "approved": return AppColors.success
        case "rejected": return AppColors.error
        default: return AppColors.textSecondary
        }
    }
    
    private var statusText: String {
        switch status {
        case "pending": return "待处理"
        case "negotiating": return "议价中"
        case "price_agreed": return "价格已达成"
        case "approved": return "已同意"
        case "rejected": return "已拒绝"
        default: return status
        }
    }
}

