import SwiftUI
import Combine

struct ActivityListView: View {
    @StateObject private var viewModel = ActivityViewModel()
    @State private var selectedExpertId: String?
    @State private var filterOption: ActivityFilterOption = .all
    
    enum ActivityFilterOption: String, CaseIterable {
        case all = "全部"
        case active = "进行中"
        case ended = "已结束"
        
        var status: String? {
            switch self {
            case .all:
                return nil
            case .active:
                return "open"
            case .ended:
                // 后端会将已结束的活动状态更新为 "completed"
                return "completed"
            }
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                AppColors.background
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // 筛选器
                    Picker("筛选", selection: $filterOption) {
                        ForEach(ActivityFilterOption.allCases, id: \.self) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.vertical, AppSpacing.sm)
                    .onChange(of: filterOption) { _ in
                        viewModel.loadActivities(
                            expertId: selectedExpertId,
                            status: filterOption.status,
                            includeEnded: filterOption == .all
                        )
                    }
                    
                    // 活动列表
                    if viewModel.isLoading && viewModel.activities.isEmpty {
                        ProgressView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if viewModel.activities.isEmpty {
                        EmptyStateView(
                            icon: "calendar.badge.plus",
                            title: filterOption == .ended ? "暂无已结束的活动" : "暂无活动",
                            message: filterOption == .ended ? "没有已结束的活动记录" : "目前还没有活动，敬请期待..."
                        )
                    } else {
                        ScrollView {
                            LazyVStack(spacing: AppSpacing.md) {
                                ForEach(viewModel.activities) { activity in
                                    NavigationLink(destination: ActivityDetailView(activityId: activity.id)) {
                                        ActivityCardView(activity: activity, showEndedBadge: filterOption == .all)
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
            .navigationTitle("活动")
            .navigationBarTitleDisplayMode(.large)
            .refreshable {
                viewModel.loadActivities(
                    expertId: selectedExpertId,
                    status: filterOption.status,
                    includeEnded: filterOption == .all,
                    forceRefresh: true
                )
            }
            .onAppear {
                if viewModel.activities.isEmpty {
                    viewModel.loadActivities(
                        expertId: selectedExpertId,
                        status: filterOption.status,
                        includeEnded: filterOption == .all
                    )
                }
            }
            .alert("错误", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("确定", role: .cancel) {
                    viewModel.errorMessage = nil
                }
            } message: {
                if let error = viewModel.errorMessage {
                    Text(error)
                }
            }
        }
    }
}

struct ActivityCardView: View {
    let activity: Activity
    var showEndedBadge: Bool = false
    
    private var isEnded: Bool {
        // 检查活动是否已结束
        if activity.status == "closed" || activity.status == "completed" || activity.status == "cancelled" {
            return true
        }
        
        // 检查截止日期（数据库存储的是 UTC 时间）
        if let deadline = activity.deadline {
            let formatter = ISO8601DateFormatter()
            formatter.timeZone = TimeZone(identifier: "UTC") ?? TimeZone(secondsFromGMT: 0)!
            if let deadlineDate = formatter.date(from: deadline) {
                return deadlineDate < Date()
            }
        }
        
        // 检查活动结束日期（数据库存储的是 UTC 时间）
        if let endDate = activity.activityEndDate {
            let formatter = ISO8601DateFormatter()
            formatter.timeZone = TimeZone(identifier: "UTC") ?? TimeZone(secondsFromGMT: 0)!
            if let endDateDate = formatter.date(from: endDate) {
                return endDateDate < Date()
            }
        }
        
        return false
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 图片区域（如果有图片）
            if let images = activity.images, let firstImage = images.first, !firstImage.isEmpty {
                AsyncImageView(
                    urlString: firstImage,
                    placeholder: Image(systemName: "photo.fill")
                )
                .aspectRatio(contentMode: .fill)
                .frame(height: 180)
                .frame(maxWidth: .infinity)
                .clipped()
                .id(firstImage)
            } else {
                placeholderBackground()
            }
            
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                // 内容头部
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    HStack(alignment: .top) {
                        Text(activity.title)
                            .font(AppTypography.title3)
                            .fontWeight(.bold)
                            .foregroundColor(isEnded ? AppColors.textSecondary : AppColors.textPrimary)
                            .lineLimit(2)
                        
                        Spacer()
                        
                        if showEndedBadge && isEnded {
                            Text("已结束")
                                .font(AppTypography.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(AppColors.textSecondary)
                                .clipShape(Capsule())
                        } else {
                            // 价格标签
                            HStack(alignment: .firstTextBaseline, spacing: 2) {
                                Text(activity.currency == "GBP" ? "£" : "¥")
                                    .font(AppTypography.caption)
                                    .fontWeight(.bold)
                                Text(String(format: "%.0f", activity.discountedPricePerParticipant ?? activity.originalPricePerParticipant))
                                    .font(AppTypography.title3)
                                    .fontWeight(.bold)
                            }
                            .foregroundColor(AppColors.primary)
                        }
                    }
                    
                    if !activity.description.isEmpty {
                        Text(activity.description)
                            .font(AppTypography.subheadline)
                            .foregroundColor(AppColors.textSecondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                }
                
                Divider().background(AppColors.divider)
                
                // 底部信息栏
                HStack(spacing: 16) {
                    // 参与人数
                    HStack(spacing: 4) {
                        IconStyle.icon("person.2.fill", size: 12)
                        Text("\(activity.currentParticipants)/\(activity.maxParticipants)")
                            .font(AppTypography.caption)
                    }
                    
                    // 地点
                    HStack(spacing: 4) {
                        IconStyle.icon("mappin.circle.fill", size: 12)
                        Text(activity.location)
                            .font(AppTypography.caption)
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    // 标签
                    if activity.hasTimeSlots {
                        Text("预约制")
                            .font(AppTypography.caption2)
                            .fontWeight(.bold)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(AppColors.warning.opacity(0.12))
                            .foregroundColor(AppColors.warning)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                }
                .foregroundColor(AppColors.textSecondary)
            }
            .padding(AppSpacing.md)
        }
        .background(AppColors.cardBackground)
        .cornerRadius(AppCornerRadius.large)
        .shadow(color: AppShadow.small.color, radius: AppShadow.small.radius, x: AppShadow.small.x, y: AppShadow.small.y)
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
                .frame(height: 180)
            
            IconStyle.icon("calendar.badge.plus", size: 40)
                .foregroundColor(AppColors.primary.opacity(0.3))
        }
    }
}

struct ActivityDetailView: View {
    let activityId: Int
    @StateObject private var viewModel = ActivityViewModel()
    @State private var showingApplySheet = false
    @EnvironmentObject var appState: AppState
    @State private var showLogin = false
    
    var body: some View {
        ZStack {
            AppColors.background
                .ignoresSafeArea()
            
            if let activity = viewModel.selectedActivity {
                ScrollView {
                    VStack(alignment: .leading, spacing: AppSpacing.lg) {
                        // 图片区域（如果有图片）
                        if let images = activity.images, !images.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: AppSpacing.sm) {
                                    ForEach(images, id: \.self) { imageUrl in
                                        AsyncImage(url: imageUrl.toImageURL()) { phase in
                                            switch phase {
                                            case .success(let image):
                                                image
                                                    .resizable()
                                                    .aspectRatio(contentMode: .fill)
                                            case .failure(_), .empty:
                                                RoundedRectangle(cornerRadius: AppCornerRadius.medium)
                                                    .fill(AppColors.primary.opacity(0.1))
                                            @unknown default:
                                                RoundedRectangle(cornerRadius: AppCornerRadius.medium)
                                                    .fill(AppColors.primary.opacity(0.1))
                                            }
                                        }
                                        .frame(width: 300, height: 200)
                                        .clipShape(RoundedRectangle(cornerRadius: AppCornerRadius.medium))
                                    }
                                }
                                .padding(.horizontal, AppSpacing.md)
                            }
                        }
                        
                        // Hero Section
                        VStack(alignment: .leading, spacing: AppSpacing.md) {
                            Text(activity.title)
                                .font(AppTypography.largeTitle)
                                .foregroundColor(AppColors.textPrimary)
                            
                            if !activity.description.isEmpty {
                                Text(activity.description)
                                    .font(AppTypography.body)
                                    .foregroundColor(AppColors.textSecondary)
                                    .lineSpacing(4)
                            }
                        }
                        .padding(.horizontal, AppSpacing.md)
                        .padding(.top, AppSpacing.sm)
                        
                        // Info Cards
                        VStack(spacing: AppSpacing.md) {
                            InfoCardRow(
                                icon: "mappin.circle.fill",
                                label: "地点",
                                value: activity.location,
                                color: .red
                            )
                            
                            InfoCardRow(
                                icon: "tag.fill",
                                label: "任务类型",
                                value: activity.taskType,
                                color: .blue
                            )
                            
                            InfoCardRow(
                                icon: "person.2.fill",
                                label: "参与者",
                                value: "\(activity.currentParticipants)/\(activity.maxParticipants)",
                                color: .green
                            )
                            
                            InfoCardRow(
                                icon: "dollarsign.circle.fill",
                                label: "价格",
                                value: formatPrice(
                                    activity.discountedPricePerParticipant ?? activity.originalPricePerParticipant,
                                    currency: activity.currency
                                ),
                                color: .purple
                            )
                            
                            if let discount = activity.discountPercentage {
                                InfoCardRow(
                                    icon: "percent",
                                    label: "折扣",
                                    value: "\(Int(discount))%",
                                    color: .orange
                                )
                            }
                            
                            // 时间段活动显示提示，非时间段活动显示截止日期
                            if activity.hasTimeSlots {
                                InfoCardRow(
                                    icon: "clock.fill",
                                    label: "活动时间",
                                    value: "多个时间段可选",
                                    color: .blue
                                )
                            } else if let deadline = activity.deadline {
                                InfoCardRow(
                                    icon: "calendar",
                                    label: "截止日期",
                                    value: deadline,
                                    color: .blue
                                )
                            }
                        }
                        .padding(.horizontal, AppSpacing.md)
                        
                        // Apply Button
                        Button(action: {
                            if appState.isAuthenticated {
                                showingApplySheet = true
                            } else {
                                showLogin = true
                            }
                        }) {
                            HStack {
                                Spacer()
                                Text(activity.currentParticipants >= activity.maxParticipants ? "已满员" : "申请参加")
                                    .font(AppTypography.bodyBold)
                                    .foregroundColor(.white)
                                Spacer()
                            }
                            .padding(.vertical, AppSpacing.md)
                            .background(
                                activity.currentParticipants >= activity.maxParticipants
                                    ? AppColors.textSecondary
                                    : AppColors.primary
                            )
                            .cornerRadius(AppCornerRadius.large)
                        }
                        .disabled(activity.currentParticipants >= activity.maxParticipants)
                        .padding(.horizontal, AppSpacing.md)
                        .padding(.bottom, AppSpacing.xl)
                    }
                    .padding(.top, AppSpacing.sm)
                }
            } else if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle("活动详情")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.loadActivityDetail(activityId: activityId)
        }
        .sheet(isPresented: $showingApplySheet) {
            ActivityApplyView(activityId: activityId, viewModel: viewModel)
        }
        .sheet(isPresented: $showLogin) {
            LoginView()
        }
    }
    
    private func formatPrice(_ price: Double, currency: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: price)) ?? "\(currency) \(Int(price))"
    }
}

struct InfoCardRow: View {
    let icon: String
    let label: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack(spacing: AppSpacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: AppCornerRadius.small)
                    .fill(color.opacity(0.15))
                    .frame(width: 40, height: 40)
                
                IconStyle.icon(icon, size: IconStyle.medium)
                    .foregroundColor(color)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textSecondary)
                
                Text(value)
                    .font(AppTypography.body)
                    .fontWeight(.medium)
                    .foregroundColor(AppColors.textPrimary)
            }
            
            Spacer()
        }
        .padding(AppSpacing.md)
        .cardStyle()
    }
}

struct BadgeView: View {
    let text: String
    let icon: String?
    let color: Color
    
    init(text: String, icon: String? = nil, color: Color) {
        self.text = text
        self.icon = icon
        self.color = color
    }
    
    var body: some View {
        HStack(spacing: icon != nil ? 3 : 0) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: 9, weight: .semibold))
            }
            Text(text)
                .font(icon != nil ? .system(size: 10, weight: .semibold) : AppTypography.caption2)
                .fontWeight(icon != nil ? .semibold : .medium)
        }
        .foregroundColor(icon != nil ? .white : color)
        .padding(.horizontal, icon != nil ? 6 : AppSpacing.sm)
        .padding(.vertical, icon != nil ? 3 : AppSpacing.xs)
        .background(icon != nil ? color : color.opacity(0.15))
        .cornerRadius(icon != nil ? AppCornerRadius.tiny : AppCornerRadius.small)
    }
}

struct ActivityApplyView: View {
    let activityId: Int
    @ObservedObject var viewModel: ActivityViewModel
    @Environment(\.dismiss) var dismiss
    
    @State private var selectedTimeSlotId: Int?
    @State private var preferredDeadline: Date = Date()
    @State private var isFlexibleTime = false
    @State private var isApplying = false
    @State private var applyError: String?
    @State private var cancellables = Set<AnyCancellable>()
    
    private var activity: Activity? {
        viewModel.selectedActivity
    }
    
    private var hasTimeSlots: Bool {
        activity?.hasTimeSlots ?? false
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                AppColors.background
                    .ignoresSafeArea()
                
                Form {
                    if hasTimeSlots {
                        // 时间段选择（参考 frontend）
                        Section {
                            if viewModel.isLoadingTimeSlots {
                                HStack {
                                    Spacer()
                                    ProgressView()
                                    Text("加载时间段中...")
                                        .font(AppTypography.caption)
                                        .foregroundColor(AppColors.textSecondary)
                                        .padding(.leading, AppSpacing.sm)
                                    Spacer()
                                }
                                .padding(.vertical, AppSpacing.md)
                            } else if viewModel.timeSlots.isEmpty {
                                Text("暂无可用时间段")
                                    .font(AppTypography.caption)
                                    .foregroundColor(AppColors.textSecondary)
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .padding(.vertical, AppSpacing.md)
                            } else {
                                // 按日期分组显示时间段
                                ForEach(groupedTimeSlots.keys.sorted(), id: \.self) { date in
                                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                                        Text(formatDate(date))
                                            .font(AppTypography.caption)
                                            .fontWeight(.semibold)
                                            .foregroundColor(AppColors.textPrimary)
                                            .padding(.bottom, AppSpacing.xs)
                                        
                                        LazyVGrid(columns: [
                                            GridItem(.flexible()),
                                            GridItem(.flexible())
                                        ], spacing: AppSpacing.sm) {
                                            ForEach(groupedTimeSlots[date] ?? []) { slot in
                                                TimeSlotSelectionCard(
                                                    slot: slot,
                                                    isSelected: selectedTimeSlotId == slot.id,
                                                    onSelect: {
                                                        if canSelectSlot(slot) {
                                                            selectedTimeSlotId = slot.id
                                                        }
                                                    }
                                                )
                                            }
                                        }
                                    }
                                    .padding(.vertical, AppSpacing.xs)
                                }
                            }
                        } header: {
                            HStack {
                                Text("⏰")
                                Text("可选时间段")
                            }
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.textSecondary)
                        }
                    } else {
                        // 非时间段活动：显示截止日期选择
                        Section {
                            Toggle("时间灵活", isOn: $isFlexibleTime)
                                .font(AppTypography.body)
                        } header: {
                            Text("时间设置")
                                .font(AppTypography.caption)
                                .foregroundColor(AppColors.textSecondary)
                        }
                        
                        if !isFlexibleTime {
                            Section {
                                DatePicker("期望截止日期", selection: $preferredDeadline, displayedComponents: .date)
                                    .font(AppTypography.body)
                            } header: {
                                Text("截止日期")
                                    .font(AppTypography.caption)
                                    .foregroundColor(AppColors.textSecondary)
                            }
                        }
                    }
                    
                    Section {
                        Button(action: apply) {
                            if isApplying {
                                ProgressView()
                                    .frame(maxWidth: .infinity)
                            } else {
                                Text(hasTimeSlots 
                                    ? (selectedTimeSlotId != nil ? "立即申请参与" : "请先选择一个时间段")
                                    : "提交申请")
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .disabled(isApplying || (hasTimeSlots && selectedTimeSlotId == nil))
                        .buttonStyle(PrimaryButtonStyle())
                        .opacity((hasTimeSlots && selectedTimeSlotId == nil) ? 0.6 : 1.0)
                    }
                }
            }
            .navigationTitle("申请参加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                // 如果是时间段活动，加载时间段列表
                if hasTimeSlots, let serviceId = activity?.expertServiceId {
                    viewModel.loadTimeSlots(serviceId: serviceId, activityId: activityId)
                }
            }
            .alert("错误", isPresented: .constant(applyError != nil)) {
                Button("确定", role: .cancel) {
                    applyError = nil
                }
            } message: {
                if let error = applyError {
                    Text(error)
                }
            }
        }
    }
    
    // 按日期分组时间段
    private var groupedTimeSlots: [String: [ServiceTimeSlot]] {
        var grouped: [String: [ServiceTimeSlot]] = [:]
        
        for slot in viewModel.timeSlots {
            let dateKey = extractDate(from: slot.slotStartDatetime)
            if grouped[dateKey] == nil {
                grouped[dateKey] = []
            }
            grouped[dateKey]?.append(slot)
        }
        
        // 对每个日期的时间段进行排序
        for key in grouped.keys {
            grouped[key]?.sort { slot1, slot2 in
                slot1.slotStartDatetime < slot2.slotStartDatetime
            }
        }
        
        return grouped
    }
    
    private func extractDate(from dateString: String) -> String {
        // 从 ISO8601 格式中提取日期部分（数据库存储的是 UTC 时间）
        let parser = ISO8601DateFormatter()
        parser.timeZone = TimeZone(identifier: "UTC") ?? TimeZone(secondsFromGMT: 0)!
        if let date = parser.date(from: dateString) {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            formatter.timeZone = TimeZone.current // 显示时使用本地时区
            return formatter.string(from: date)
        }
        return dateString.components(separatedBy: "T").first ?? dateString
    }
    
    private func formatDate(_ dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        
        if let date = formatter.date(from: dateString) {
            formatter.dateFormat = "yyyy年MM月dd日 EEE"
            formatter.locale = Locale(identifier: "zh_CN")
            return formatter.string(from: date)
        }
        return dateString
    }
    
    private func canSelectSlot(_ slot: ServiceTimeSlot) -> Bool {
        // 检查时间段是否可用（未过期且未满员）
        let isFull = slot.currentParticipants >= slot.maxParticipants
        let isExpired = slot.isExpired == true || !slot.isAvailable
        return !isExpired && !isFull
    }
    
    private func apply() {
        // 如果是时间段活动，验证选中的时间段
        if hasTimeSlots {
            guard let selectedId = selectedTimeSlotId else {
                applyError = "请先选择一个时间段"
                return
            }
            
            // 验证选中的时间段是否仍然可用
            guard let selectedSlot = viewModel.timeSlots.first(where: { $0.id == selectedId }) else {
                applyError = "选中的时间段不存在"
                return
            }
            
            if !canSelectSlot(selectedSlot) {
                applyError = "选中的时间段已不可用，请重新选择"
                selectedTimeSlotId = nil
                return
            }
        }
        
        isApplying = true
        applyError = nil
        
        // 格式化截止日期为 UTC 时间发送给后端
        let deadlineFormatter = ISO8601DateFormatter()
        deadlineFormatter.timeZone = TimeZone(identifier: "UTC") ?? TimeZone(secondsFromGMT: 0)!
        let deadlineString = hasTimeSlots ? nil : (isFlexibleTime ? nil : deadlineFormatter.string(from: preferredDeadline))
        
        viewModel.applyToActivity(
            activityId: activityId,
            timeSlotId: hasTimeSlots ? selectedTimeSlotId : nil,
            preferredDeadline: deadlineString,
            isFlexibleTime: hasTimeSlots ? false : isFlexibleTime
        )
        .receive(on: DispatchQueue.main)
        .sink(
            receiveCompletion: { completion in
                isApplying = false
                if case .failure(let error) = completion {
                    applyError = error.localizedDescription
                } else {
                    dismiss()
                }
            },
            receiveValue: { _ in
                dismiss()
            }
        )
        .store(in: &cancellables)
    }
}

// 时间段选择卡片（参考 frontend）
struct TimeSlotSelectionCard: View {
    let slot: ServiceTimeSlot
    let isSelected: Bool
    let onSelect: () -> Void
    
    private var isFull: Bool {
        slot.currentParticipants >= slot.maxParticipants
    }
    
    private var isExpired: Bool {
        slot.isExpired == true || !slot.isAvailable
    }
    
    private var isClickable: Bool {
        !isExpired && !isFull
    }
    
    private var availableSpots: Int {
        slot.maxParticipants - slot.currentParticipants
    }
    
    var body: some View {
        Button(action: {
            if isClickable {
                onSelect()
            }
        }) {
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                HStack {
                    Text(formatTimeRange(slot.slotStartDatetime, end: slot.slotEndDatetime))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(isExpired ? AppColors.textTertiary : (isSelected ? AppColors.primary : AppColors.textPrimary))
                    
                    Spacer()
                    
                    if isSelected {
                        Text("✓ 已选择")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(AppColors.primary)
                    }
                    
                    if isExpired {
                        Text("(已过期)")
                            .font(.system(size: 11))
                            .foregroundColor(AppColors.error)
                    }
                }
                
                if let price = slot.activityPrice ?? slot.pricePerParticipant {
                    Text("£\(String(format: "%.2f", price)) / 人")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(AppColors.success)
                }
                
                Text(isFull 
                    ? "已满 (\(slot.currentParticipants)/\(slot.maxParticipants))"
                    : "\(slot.currentParticipants)/\(slot.maxParticipants) 人 (\(availableSpots) 个空位)")
                    .font(.system(size: 11))
                    .foregroundColor(isFull ? AppColors.error : AppColors.success)
            }
            .padding(AppSpacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? AppColors.primaryLight : (isExpired || isFull ? AppColors.cardBackground : AppColors.surface))
            .cornerRadius(AppCornerRadius.small)
            .overlay(
                RoundedRectangle(cornerRadius: AppCornerRadius.small)
                    .stroke(
                        isSelected ? AppColors.primary : (isExpired || isFull ? AppColors.separator : AppColors.separator),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
            .opacity(isExpired || isFull ? 0.7 : 1.0)
        }
        .disabled(!isClickable)
    }
    
    private func formatTimeRange(_ start: String, end: String) -> String {
        // 解析时使用 UTC 时区（数据库存储的是 UTC）
        let utcTimeZone = TimeZone(identifier: "UTC") ?? TimeZone(secondsFromGMT: 0)!
        let parserFormatter = ISO8601DateFormatter()
        parserFormatter.timeZone = utcTimeZone
        
        // 备用解析器（用于非标准格式）
        let fallbackFormatter = DateFormatter()
        fallbackFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        fallbackFormatter.timeZone = utcTimeZone
        fallbackFormatter.locale = Locale(identifier: "en_US_POSIX")
        
        guard let startDate = parserFormatter.date(from: start) ?? fallbackFormatter.date(from: start),
              let endDate = parserFormatter.date(from: end) ?? fallbackFormatter.date(from: end) else {
            return "\(start) - \(end)"
        }
        
        // 格式化时使用用户本地时区
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"
        timeFormatter.timeZone = TimeZone.current // 使用用户本地时区
        
        let startTime = timeFormatter.string(from: startDate)
        let endTime = timeFormatter.string(from: endDate)
        return "\(startTime) - \(endTime)"
    }
}

#Preview {
    ActivityListView()
}
