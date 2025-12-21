import SwiftUI
import Combine

struct ActivityDetailView: View {
    let activityId: Int
    @StateObject private var viewModel = ActivityViewModel()
    @State private var showingApplySheet = false
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @State private var showLogin = false
    @State private var currentImageIndex = 0
    @State private var isHeaderVisible = false
    
    var body: some View {
        ZStack {
            AppColors.background
                .ignoresSafeArea()
            
            if let activity = viewModel.selectedActivity {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        // 1. Hero Section & Image Carousel
                        ActivityImageCarousel(activity: activity, currentIndex: $currentImageIndex)
                            .frame(height: 240)
                        
                        VStack(alignment: .leading, spacing: AppSpacing.lg) {
                            // 2. Title & Basic Info Card
                            ActivityHeaderCard(activity: activity)
                                .offset(y: -30)
                                .padding(.horizontal, AppSpacing.md)
                            
                            // 3. Stats Bar
                            ActivityStatsBar(activity: activity)
                                .padding(.horizontal, AppSpacing.md)
                            
                            // 4. Description Card
                            if !activity.description.isEmpty {
                                ActivityDescriptionCard(description: activity.description)
                                    .padding(.horizontal, AppSpacing.md)
                            }
                            
                            // 5. Detailed Info Card
                            ActivityInfoGrid(activity: activity)
                                .padding(.horizontal, AppSpacing.md)
                            
                            // 6. Poster Info
                            PosterInfoRow(expertId: activity.expertId)
                                .padding(.horizontal, AppSpacing.md)
                            
                            Spacer(minLength: 120) // Bottom spacing for buttons
                        }
                    }
                }
                
                // 7. Bottom Action Bar
                ActivityBottomBar(
                    activity: activity,
                    onApply: {
                        if appState.isAuthenticated {
                            showingApplySheet = true
                            HapticFeedback.selection()
                        } else {
                            showLogin = true
                        }
                    }
                )
            } else if viewModel.isLoading {
                LoadingView()
            } else {
                ErrorStateView(title: "加载失败", message: viewModel.errorMessage ?? "请重试") {
                    viewModel.loadActivityDetail(activityId: activityId)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(AppColors.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { /* Share action */ }) {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundColor(AppColors.textPrimary)
                }
            }
        }
        .onAppear {
            viewModel.loadActivityDetail(activityId: activityId)
            // 隐藏 TabBar
            appState.hideTabBar = true
        }
        .onDisappear {
            // 恢复 TabBar
            appState.hideTabBar = false
        }
        .sheet(isPresented: $showingApplySheet) {
            ActivityApplyView(activityId: activityId, viewModel: viewModel)
        }
        .sheet(isPresented: $showLogin) {
            LoginView()
        }
    }
}

// MARK: - Subviews

struct ActivityImageCarousel: View {
    let activity: Activity
    @Binding var currentIndex: Int
    
    var body: some View {
        ZStack(alignment: .bottom) {
            if let images = activity.images, !images.isEmpty {
                TabView(selection: $currentIndex) {
                    ForEach(0..<images.count, id: \.self) { index in
                        GeometryReader { geo in
                            AsyncImage(url: images[index].toImageURL()) { phase in
                                switch phase {
                                case .success(let image):
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: geo.size.width, height: geo.size.height)
                                        .clipped()
                                case .failure(_), .empty:
                                    placeholderBackground
                                @unknown default:
                                    placeholderBackground
                                }
                            }
                        }
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                
                // Indicators
                if images.count > 1 {
                    HStack(spacing: 6) {
                        ForEach(0..<images.count, id: \.self) { index in
                            Capsule()
                                .fill(currentIndex == index ? Color.white : Color.white.opacity(0.4))
                                .frame(width: currentIndex == index ? 16 : 6, height: 6)
                                .animation(.spring(), value: currentIndex)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .padding(.bottom, 45)
                }
            } else {
                placeholderBackground
            }
            
            // Bottom Gradient Overlay
            LinearGradient(
                gradient: Gradient(colors: [.clear, AppColors.background]),
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 80)
        }
    }
    
    private var placeholderBackground: some View {
        ZStack {
            AppColors.primary.opacity(0.1)
            IconStyle.icon("calendar.badge.plus", size: 60)
                .foregroundColor(AppColors.primary.opacity(0.3))
        }
    }
}

struct ActivityHeaderCard: View {
    let activity: Activity
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack(alignment: .firstTextBaseline) {
                Text(activity.title)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(AppColors.textPrimary)
                
                Spacer()
                
                PriceView(
                    price: activity.discountedPricePerParticipant ?? activity.originalPricePerParticipant,
                    currency: activity.currency,
                    originalPrice: activity.discountedPricePerParticipant != nil ? activity.originalPricePerParticipant : nil
                )
            }
            
            HStack(spacing: AppSpacing.sm) {
                BadgeView(text: activity.taskType, icon: "tag.fill", color: .blue)
                if activity.hasTimeSlots {
                    BadgeView(text: "预约制", icon: "clock.fill", color: .orange)
                }
                BadgeView(text: activity.location, icon: "mappin.circle.fill", color: .red)
            }
        }
        .padding(AppSpacing.lg)
        .background(AppColors.cardBackground)
        .cornerRadius(AppCornerRadius.xlarge)
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
    }
}

struct PriceView: View {
    let price: Double
    let currency: String
    var originalPrice: Double? = nil
    
    var body: some View {
        VStack(alignment: .trailing, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(currency == "GBP" ? "£" : "¥")
                    .font(.system(size: 14, weight: .bold))
                Text(String(format: "%.0f", price))
                    .font(.system(size: 28, weight: .bold, design: .rounded))
            }
            .foregroundColor(AppColors.primary)
            
            if let original = originalPrice {
                Text("£\(Int(original))")
                    .font(.system(size: 14))
                    .strikethrough()
                    .foregroundColor(AppColors.textQuaternary)
            }
        }
    }
}

struct ActivityStatsBar: View {
    let activity: Activity
    
    var body: some View {
        HStack {
            StatItem(
                label: "参与者",
                value: "\(activity.currentParticipants)/\(activity.maxParticipants)",
                color: .blue
            )
            
            Divider().frame(height: 30)
            
            StatItem(
                label: "剩余名额",
                value: "\(activity.maxParticipants - activity.currentParticipants)",
                color: .green
            )
            
            Divider().frame(height: 30)
            
            StatItem(
                label: "状态",
                value: activity.isEnded ? "已结束" : (activity.isFull ? "已满" : "热招中"),
                color: activity.isEnded ? .secondary : (activity.isFull ? .red : .orange)
            )
        }
        .padding(.vertical, AppSpacing.md)
        .background(AppColors.cardBackground)
        .cornerRadius(AppCornerRadius.large)
        .shadow(color: Color.black.opacity(0.03), radius: 5, x: 0, y: 2)
    }
}

struct ActivityDescriptionCard: View {
    let description: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            SectionHeader(title: "活动描述", icon: "doc.text.fill")
            
            Text(description)
                .font(AppTypography.body)
                .foregroundColor(AppColors.textSecondary)
                .lineSpacing(6)
        }
        .padding(AppSpacing.md)
        .cardStyle(useMaterial: true)
    }
}

struct ActivityInfoGrid: View {
    let activity: Activity
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            SectionHeader(title: "详细信息", icon: "info.circle.fill")
            
            VStack(spacing: AppSpacing.sm) {
                InfoRow(icon: "mappin.and.ellipse", label: "具体地点", value: activity.location)
                InfoRow(icon: "tag", label: "活动类型", value: activity.taskType)
                
                if activity.hasTimeSlots {
                    InfoRow(icon: "calendar.badge.clock", label: "时间安排", value: "支持多个时间段预约")
                } else if let deadline = activity.deadline {
                    InfoRow(icon: "calendar", label: "截止日期", value: formatDateString(deadline))
                }
                
                if let discount = activity.discountPercentage {
                    InfoRow(icon: "gift", label: "专享折扣", value: "\(Int(discount))% OFF")
                }
            }
        }
        .padding(AppSpacing.md)
        .cardStyle()
    }
    
    private func formatDateString(_ dateString: String) -> String {
        let parser = ISO8601DateFormatter()
        parser.timeZone = TimeZone(identifier: "UTC")
        
        let fallback = DateFormatter()
        fallback.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        
        if let date = parser.date(from: dateString) ?? fallback.date(from: dateString) {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy年MM月dd日"
            return formatter.string(from: date)
        }
        return dateString
    }
}

struct InfoRow: View {
    let icon: String
    let label: String
    let value: String
    
    var body: some View {
        HStack(spacing: AppSpacing.md) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(AppColors.primary)
                .frame(width: 24)
            
            Text(label)
                .font(AppTypography.subheadline)
                .foregroundColor(AppColors.textSecondary)
            
            Spacer()
            
            Text(value)
                .font(AppTypography.subheadline)
                .fontWeight(.medium)
                .foregroundColor(AppColors.textPrimary)
        }
        .padding(.vertical, 4)
    }
}

struct PosterInfoRow: View {
    let expertId: String
    // In a real app, you'd load the expert info here or pass it in
    
    var body: some View {
        HStack {
            Circle()
                .fill(AppColors.primary.opacity(0.1))
                .frame(width: 44, height: 44)
                .overlay(IconStyle.icon("person.fill", size: 20).foregroundColor(AppColors.primary))
            
            VStack(alignment: .leading, spacing: 2) {
                Text("活动发布者")
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textSecondary)
                Text("查看达人主页")
                    .font(AppTypography.bodyBold)
                    .foregroundColor(AppColors.textPrimary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(AppColors.textQuaternary)
        }
        .padding(AppSpacing.md)
        .background(AppColors.cardBackground)
        .cornerRadius(AppCornerRadius.large)
    }
}

struct ActivityBottomBar: View {
    let activity: Activity
    let onApply: () -> Void
    
    var body: some View {
        VStack {
            Spacer()
            
            VStack(spacing: 0) {
                Divider()
                
                HStack(spacing: AppSpacing.md) {
                    // Favorite Button
                    Button(action: { /* Favorite toggle */ }) {
                        VStack(spacing: 4) {
                            Image(systemName: "heart")
                                .font(.system(size: 20))
                            Text("收藏")
                                .font(.system(size: 10))
                        }
                        .foregroundColor(AppColors.textSecondary)
                        .frame(width: 50)
                    }
                    
                    if activity.isEnded {
                        Text("activity.ended")
                            .font(AppTypography.bodyBold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(AppColors.textQuaternary)
                            .cornerRadius(AppCornerRadius.medium)
                    } else {
                        Button(action: onApply) {
                            Text(activity.isFull ? "activity.full" : "activity.apply")
                                .font(AppTypography.bodyBold)
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(activity.isFull)
                    }
                }
                .padding(.horizontal, AppSpacing.md)
                .padding(.vertical, AppSpacing.sm)
                .background(AppColors.cardBackground)
            }
        }
    }
}

// MARK: - Activity Apply View (Refined)

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
            KeyboardAvoidingScrollView {
                VStack(spacing: AppSpacing.lg) {
                    if hasTimeSlots {
                        VStack(alignment: .leading, spacing: AppSpacing.md) {
                            SectionHeader(title: "选择时间段", icon: "clock.fill")
                            
                            if viewModel.isLoadingTimeSlots {
                                HStack {
                                    Spacer()
                                    ProgressView()
                                    Spacer()
                                }
                                .padding(.vertical, 40)
                            } else if viewModel.timeSlots.isEmpty {
                                EmptyStateView(icon: "calendar.badge.exclamationmark", title: "暂无可用时间", message: "目前没有可选的时间段")
                            } else {
                                ForEach(groupedTimeSlots.keys.sorted(), id: \.self) { date in
                                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                                        Text(formatDate(date))
                                            .font(AppTypography.subheadline)
                                            .fontWeight(.bold)
                                            .padding(.leading, 4)
                                        
                                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: AppSpacing.sm) {
                                            ForEach(groupedTimeSlots[date] ?? []) { slot in
                                                ActivityTimeSlotCard(
                                                    slot: slot,
                                                    isSelected: selectedTimeSlotId == slot.id,
                                                    onSelect: {
                                                        if canSelectSlot(slot) {
                                                            selectedTimeSlotId = slot.id
                                                            HapticFeedback.selection()
                                                        }
                                                    }
                                                )
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        .cardStyle(useMaterial: true)
                    } else {
                        VStack(alignment: .leading, spacing: AppSpacing.md) {
                            SectionHeader(title: "参与时间", icon: "calendar")
                            
                            Toggle(isOn: $isFlexibleTime) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("时间灵活")
                                        .font(AppTypography.bodyBold)
                                    Text("如果您在近期任何时间都方便参加")
                                        .font(AppTypography.caption)
                                        .foregroundColor(AppColors.textSecondary)
                                }
                            }
                            .tint(AppColors.primary)
                            
                            if !isFlexibleTime {
                                Divider()
                                DatePicker("期望参加日期", selection: $preferredDeadline, displayedComponents: .date)
                                    .font(AppTypography.body)
                            }
                        }
                        .cardStyle(useMaterial: true)
                    }
                    
                    if let error = applyError {
                        HStack {
                            Image(systemName: "exclamationmark.circle.fill")
                            Text(error)
                        }
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.error)
                        .padding()
                        .background(AppColors.error.opacity(0.1))
                        .cornerRadius(AppCornerRadius.medium)
                    }
                    
                    Button(action: apply) {
                        HStack {
                            if isApplying {
                                ProgressView().tint(.white)
                            } else {
                                Image(systemName: "paperplane.fill")
                                Text("确认申请参与")
                            }
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(isApplying || (hasTimeSlots && selectedTimeSlotId == nil))
                    .opacity((hasTimeSlots && selectedTimeSlotId == nil) ? 0.6 : 1.0)
                }
                .padding(AppSpacing.md)
            }
            .background(AppColors.background)
            .navigationTitle("申请参加活动")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") { dismiss() }
                }
            }
            .onAppear {
                if hasTimeSlots, let serviceId = activity?.expertServiceId {
                    viewModel.loadTimeSlots(serviceId: serviceId, activityId: activityId)
                }
            }
        }
    }
    
    // Helper methods for date/time formatting (same as before but integrated)
    private var groupedTimeSlots: [String: [ServiceTimeSlot]] {
        var grouped: [String: [ServiceTimeSlot]] = [:]
        for slot in viewModel.timeSlots {
            let parser = ISO8601DateFormatter()
            parser.timeZone = TimeZone(identifier: "UTC")
            if let date = parser.date(from: slot.slotStartDatetime) {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd"
                let key = formatter.string(from: date)
                if grouped[key] == nil { grouped[key] = [] }
                grouped[key]?.append(slot)
            }
        }
        return grouped
    }
    
    private func formatDate(_ dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        if let date = formatter.date(from: dateString) {
            formatter.dateFormat = "MM月dd日 EEE"
            formatter.locale = Locale(identifier: "zh_CN")
            return formatter.string(from: date)
        }
        return dateString
    }
    
    private func canSelectSlot(_ slot: ServiceTimeSlot) -> Bool {
        return (slot.isExpired != true) && (slot.currentParticipants < slot.maxParticipants) && slot.isAvailable
    }
    
    private func apply() {
        isApplying = true
        applyError = nil
        
        let deadlineFormatter = ISO8601DateFormatter()
        deadlineFormatter.timeZone = TimeZone(identifier: "UTC")
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
                    HapticFeedback.success()
                    dismiss()
                }
            },
            receiveValue: { _ in }
        )
        .store(in: &cancellables)
    }
}

struct ActivityTimeSlotCard: View {
    let slot: ServiceTimeSlot
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 4) {
                Text(formatTimeRange(slot.slotStartDatetime, end: slot.slotEndDatetime))
                    .font(.system(size: 14, weight: .bold))
                
                Text("\(slot.currentParticipants)/\(slot.maxParticipants) 人")
                    .font(.system(size: 11))
                
                if let price = slot.activityPrice ?? slot.pricePerParticipant {
                    Text("£\(Int(price))")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(AppColors.primary)
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? AppColors.primary.opacity(0.1) : AppColors.cardBackground)
            .cornerRadius(AppCornerRadius.medium)
            .overlay(
                RoundedRectangle(cornerRadius: AppCornerRadius.medium)
                    .stroke(isSelected ? AppColors.primary : AppColors.separator.opacity(0.3), lineWidth: isSelected ? 2 : 1)
            )
        }
        .foregroundColor(isSelected ? AppColors.primary : AppColors.textPrimary)
        .disabled(slot.isExpired == true || slot.currentParticipants >= slot.maxParticipants)
        .opacity((slot.isExpired == true || slot.currentParticipants >= slot.maxParticipants) ? 0.5 : 1.0)
    }
    
    private func formatTimeRange(_ start: String, end: String) -> String {
        let parser = ISO8601DateFormatter()
        parser.timeZone = TimeZone(identifier: "UTC")
        guard let sDate = parser.date(from: start), let eDate = parser.date(from: end) else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return "\(formatter.string(from: sDate))-\(formatter.string(from: eDate))"
    }
}


