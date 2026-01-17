import SwiftUI
import Combine
import UIKit
import LinkPresentation

struct ActivityDetailView: View {
    let activityId: Int
    @StateObject private var viewModel = ActivityViewModel()
    @State private var showingApplySheet = false
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @State private var showLogin = false
    @State private var currentImageIndex = 0
    @State private var isHeaderVisible = false
    @State private var showShareSheet = false
    @State private var shareImage: UIImage?
    @State private var shareImageCancellable: AnyCancellable?
    @State private var isShareImageLoading = false // 分享图片加载状态
    
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
                            PosterInfoRow(expertId: activity.expertId, expert: viewModel.expert)
                                .padding(.horizontal, AppSpacing.md)
                            
                            Spacer(minLength: 120) // Bottom spacing for buttons
                        }
                    }
                }
                
                // 7. Bottom Action Bar
                ActivityBottomBar(
                    activity: activity,
                    isFavorited: viewModel.isFavorited,
                    isTogglingFavorite: viewModel.isTogglingFavorite,
                    onFavorite: {
                        if appState.isAuthenticated {
                            viewModel.toggleFavorite(activityId: activityId) { success in
                                if success {
                                    HapticFeedback.success()
                                }
                            }
                        } else {
                            showLogin = true
                        }
                    },
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
                ErrorStateView(title: LocalizationKey.activityLoadFailed.localized, message: viewModel.errorMessage ?? LocalizationKey.activityPleaseRetry.localized) {
                    viewModel.loadActivityDetail(activityId: activityId)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .enableSwipeBack()
        .toolbarBackground(AppColors.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 16) {
                    // 分享按钮
                    Button {
                        showShareSheet = true
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(AppColors.textPrimary)
                    }
                    
                    // 达人头像按钮
                    if let activity = viewModel.selectedActivity {
                        NavigationLink(destination: TaskExpertDetailView(expertId: activity.expertId)) {
                            if let expert = viewModel.expert, let avatarUrl = expert.avatar, !avatarUrl.isEmpty {
                                // 显示真实头像
                                AvatarView(
                                    urlString: avatarUrl,
                                    size: 32,
                                    placeholder: Image(systemName: "person.fill")
                                )
                                .clipShape(Circle())
                                .overlay(
                                    Circle()
                                        .stroke(AppColors.primary.opacity(0.3), lineWidth: 1.5)
                                )
                            } else {
                                // 占位符
                                Circle()
                                    .fill(AppColors.primary.opacity(0.15))
                                    .frame(width: 32, height: 32)
                                    .overlay(
                                        Image(systemName: "person.fill")
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(AppColors.primary)
                                    )
                            }
                        }
                    }
                }
            }
        }
        .toolbar(.hidden, for: .tabBar)
        .onAppear {
            viewModel.loadActivityDetail(activityId: activityId)
        }
        .sheet(isPresented: $showingApplySheet) {
            ActivityApplyView(activityId: activityId, viewModel: viewModel)
        }
        .sheet(isPresented: $showShareSheet) {
            if let activity = viewModel.selectedActivity, !activity.title.isEmpty {
                // 确保活动数据完整后再显示分享视图
                ActivityShareSheet(
                    activity: activity,
                    activityId: activityId,
                    shareImage: shareImage,
                    isShareImageLoading: isShareImageLoading
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .onAppear {
                    // 当分享面板出现时，开始加载图片（如果还没有加载）
                    if shareImage == nil && !isShareImageLoading {
                        loadShareImage()
                    }
                }
            } else {
                // 如果活动数据未就绪，显示加载状态
                VStack(spacing: AppSpacing.lg) {
                    CompactLoadingView()
                    Text(LocalizationKey.commonLoading.localized)
                        .font(AppTypography.body)
                        .foregroundColor(AppColors.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .presentationDetents([.medium])
            }
        }
        .sheet(isPresented: $showLogin) {
            LoginView()
        }
        .onAppear {
            viewModel.loadActivityDetail(activityId: activityId)
        }
        .onChange(of: viewModel.selectedActivity?.id) { newActivityId in
            guard let newActivityId = newActivityId, newActivityId == activityId else { return }
            // 优化：不在活动加载时立即加载分享图片，延迟到用户点击分享时再加载
            // loadShareImage() // 延迟加载
        }
    }
    
    // 优化：延迟加载分享图片，只在需要时加载
    private func loadShareImage() {
        guard let activity = viewModel.selectedActivity,
              let images = activity.images,
              let firstImage = images.first,
              !firstImage.isEmpty else {
            shareImage = nil
            isShareImageLoading = false
            return
        }
        
        // 如果图片已经加载，不需要重新加载
        if shareImage != nil {
            return
        }
        
        // 取消之前的加载
        shareImageCancellable?.cancel()
        isShareImageLoading = true
        
        // 使用 ImageCache 加载图片，支持缓存和优化
        shareImageCancellable = ImageCache.shared.loadImage(from: firstImage)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    self.isShareImageLoading = false
                    if case .failure = completion {
                        // 图片加载失败，不影响分享功能
                        self.shareImage = nil
                    }
                },
                receiveValue: { image in
                    self.shareImage = image
                    self.isShareImageLoading = false
                }
            )
    }
}

// MARK: - Subviews

struct ActivityImageCarousel: View {
    let activity: Activity
    @Binding var currentIndex: Int
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // 占位背景（避免闪烁）
            Rectangle()
                .fill(AppColors.cardBackground)
                .frame(height: 300)
            
            if let images = activity.images, !images.isEmpty {
                TabView(selection: $currentIndex) {
                    ForEach(0..<images.count, id: \.self) { index in
                        GeometryReader { geo in
                            // 性能优化：使用 AsyncImageView 优化图片加载和缓存
                            AsyncImageView(
                                urlString: images[index],
                                placeholder: Image(systemName: "photo"),
                                width: geo.size.width,
                                height: geo.size.height,
                                contentMode: .fill,
                                cornerRadius: 0
                            )
                            .frame(width: geo.size.width, height: geo.size.height)
                            .clipped()
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
                TranslatableText(
                    activity.title,
                    font: .system(size: 24, weight: .bold),
                    foregroundColor: AppColors.textPrimary
                )
                
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
                    BadgeView(text: LocalizationKey.activityByAppointment.localized, icon: "clock.fill", color: .orange)
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
                label: LocalizationKey.activityParticipants.localized,
                value: "\(activity.currentParticipants)/\(activity.maxParticipants)",
                color: .blue
            )
            
            Divider().frame(height: 30)
            
            StatItem(
                label: LocalizationKey.activityRemainingSlots.localized,
                value: "\(activity.maxParticipants - activity.currentParticipants)",
                color: .green
            )
            
            Divider().frame(height: 30)
            
            StatItem(
                label: LocalizationKey.activityStatus.localized,
                value: activity.isEnded ? LocalizationKey.activityEnded.localized : (activity.isFull ? LocalizationKey.activityFull.localized : LocalizationKey.activityHotRecruiting.localized),
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
            SectionHeader(title: LocalizationKey.activityDescription.localized, icon: "doc.text.fill")
            
            TranslatableText(
                description,
                font: AppTypography.body,
                foregroundColor: AppColors.textSecondary,
                lineSpacing: 6
            )
        }
        .padding(AppSpacing.md)
        .cardStyle(useMaterial: true)
    }
}

struct ActivityInfoGrid: View {
    let activity: Activity
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            SectionHeader(title: LocalizationKey.activityDetails.localized, icon: "info.circle.fill")
            
            VStack(spacing: AppSpacing.sm) {
                InfoRow(icon: "mappin.and.ellipse", label: LocalizationKey.activityLocation.localized, value: activity.location)
                InfoRow(icon: "tag", label: LocalizationKey.activityType.localized, value: activity.taskType)
                
                if activity.hasTimeSlots {
                    InfoRow(icon: "calendar.badge.clock", label: LocalizationKey.activityTimeArrangement.localized, value: LocalizationKey.activityMultipleTimeSlots.localized)
                } else if let deadline = activity.deadline {
                    InfoRow(icon: "calendar", label: LocalizationKey.activityDeadline.localized, value: formatDateString(deadline))
                }
                
                if let discount = activity.discountPercentage {
                    InfoRow(icon: "gift", label: LocalizationKey.activityExclusiveDiscount.localized, value: "\(Int(discount))% OFF")
                }
            }
        }
        .padding(AppSpacing.md)
        .cardStyle()
    }
    
    private func formatDateString(_ dateString: String) -> String {
        let parser = ISO8601DateFormatter()
        parser.timeZone = TimeZone(identifier: "UTC") // 解析时使用 UTC（数据库存储的是 UTC）
        
        let fallback = DateFormatter()
        fallback.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        fallback.timeZone = TimeZone(identifier: "UTC")
        
        if let date = parser.date(from: dateString) ?? fallback.date(from: dateString) {
            let formatter = DateFormatter()
            formatter.locale = Locale.current // 使用用户系统 locale
            formatter.timeZone = TimeZone.current // 使用用户本地时区
            // 根据 locale 选择合适的格式
            if Locale.current.identifier.hasPrefix("zh") {
                formatter.dateFormat = "yyyy年MM月dd日"
            } else {
                formatter.dateStyle = .long
                formatter.timeStyle = .none
            }
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
    let expert: TaskExpert?
    
    var body: some View {
        NavigationLink(destination: TaskExpertDetailView(expertId: expertId)) {
            HStack(spacing: AppSpacing.md) {
                // 达人头像
                if let expert = expert, let avatarUrl = expert.avatar, !avatarUrl.isEmpty {
                    AvatarView(
                        urlString: avatarUrl,
                        size: 52,
                        placeholder: Image(systemName: "person.fill")
                    )
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(
                                LinearGradient(
                                    gradient: Gradient(colors: AppColors.gradientPrimary),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2
                            )
                    )
                    .shadow(color: AppColors.primary.opacity(0.2), radius: 4, x: 0, y: 2)
                } else {
                    Circle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: AppColors.gradientPrimary),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 52, height: 52)
                        .overlay(
                            Image(systemName: "person.fill")
                                .font(.system(size: 22, weight: .medium))
                                .foregroundColor(.white)
                        )
                        .shadow(color: AppColors.primary.opacity(0.3), radius: 4, x: 0, y: 2)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(LocalizationKey.activityPoster.localized)
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textSecondary)
                    
                    if let expert = expert {
                        Text(expert.name)
                            .font(AppTypography.bodyBold)
                            .foregroundColor(AppColors.textPrimary)
                    } else {
                        Text(LocalizationKey.activityViewExpertProfile.localized)
                            .font(AppTypography.bodyBold)
                            .foregroundColor(AppColors.textPrimary)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppColors.textQuaternary)
                    .padding(8)
                    .background(AppColors.background)
                    .clipShape(Circle())
            }
            .padding(AppSpacing.md)
            .background(AppColors.cardBackground)
            .cornerRadius(AppCornerRadius.large)
            .shadow(color: Color.black.opacity(0.03), radius: 5, x: 0, y: 2)
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

struct ActivityBottomBar: View {
    let activity: Activity
    let isFavorited: Bool
    let isTogglingFavorite: Bool
    let onFavorite: () -> Void
    let onApply: () -> Void
    
    var body: some View {
        VStack {
            Spacer()
            
            VStack(spacing: 0) {
                Divider()
                
                HStack(spacing: AppSpacing.md) {
                    // Favorite Button
                    Button(action: onFavorite) {
                        VStack(spacing: 4) {
                            ZStack {
                                if isTogglingFavorite {
                                    ProgressView()
                                        .scaleEffect(0.7)
                                } else {
                                    Image(systemName: isFavorited ? "heart.fill" : "heart")
                                        .font(.system(size: 20))
                                        .foregroundColor(isFavorited ? .red : AppColors.textSecondary)
                                        .scaleEffect(isFavorited ? 1.1 : 1.0)
                                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isFavorited)
                                }
                            }
                            .frame(height: 24)
                            
                            Text(LocalizationKey.activityFavorite.localized)
                                .font(.system(size: 10))
                                .foregroundColor(isFavorited ? .red : AppColors.textTertiary)
                        }
                        .frame(width: 50)
                    }
                    .disabled(isTogglingFavorite)
                    
                    if activity.isEnded {
                        Text(LocalizationKey.activityEnded.localized)
                            .font(AppTypography.bodyBold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(AppColors.textQuaternary)
                            .cornerRadius(AppCornerRadius.medium)
                    } else {
                        Button(action: onApply) {
                            Text(activity.isFull ? LocalizationKey.activityFull.localized : LocalizationKey.activityApply.localized)
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
                        timeSlotSelectionView
                    } else {
                        flexibleTimeSelectionView
                    }
                    
                    if let error = applyError {
                        errorView(error)
                    }
                    
                    applyButton
                }
                .padding(AppSpacing.md)
            }
            .background(AppColors.background)
            .navigationTitle(LocalizationKey.activityApplyToJoin.localized)
            .navigationBarTitleDisplayMode(.inline)
            .enableSwipeBack()
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(LocalizationKey.commonCancel.localized) { dismiss() }
                }
            }
            .enableSwipeBack()
            .onAppear {
                if hasTimeSlots, let serviceId = activity?.expertServiceId {
                    viewModel.loadTimeSlots(serviceId: serviceId, activityId: activityId)
                }
            }
        }
    }
    
    // MARK: - Subviews
    
    private var timeSlotSelectionView: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            SectionHeader(title: LocalizationKey.activitySelectTimeSlot.localized, icon: "clock.fill")
            
            if viewModel.isLoadingTimeSlots {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .padding(.vertical, 40)
            } else if viewModel.timeSlots.isEmpty {
                EmptyStateView(
                    icon: "calendar.badge.exclamationmark",
                    title: LocalizationKey.activityNoAvailableTime.localized,
                    message: LocalizationKey.activityNoAvailableTimeMessage.localized
                )
            } else {
                timeSlotsList
            }
        }
        .cardStyle(useMaterial: true)
    }
    
    private var timeSlotsList: some View {
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
    
    private var flexibleTimeSelectionView: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            SectionHeader(title: LocalizationKey.activityParticipateTime.localized, icon: "calendar")
            
            Toggle(isOn: $isFlexibleTime) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(LocalizationKey.activityTimeFlexible.localized)
                        .font(AppTypography.bodyBold)
                    Text(LocalizationKey.activityTimeFlexibleMessage.localized)
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textSecondary)
                }
            }
            .tint(AppColors.primary)
            
            if !isFlexibleTime {
                Divider()
                DatePicker(LocalizationKey.activityPreferredDate.localized, selection: $preferredDeadline, displayedComponents: .date)
                    .font(AppTypography.body)
            }
        }
        .cardStyle(useMaterial: true)
    }
    
    private func errorView(_ error: String) -> some View {
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
    
    private var applyButton: some View {
        Button(action: apply) {
            HStack {
                if isApplying {
                    ProgressView().tint(.white)
                } else {
                    Image(systemName: "paperplane.fill")
                    Text(LocalizationKey.activityConfirmApply.localized)
                }
            }
        }
        .buttonStyle(PrimaryButtonStyle())
        .disabled(isApplying || (hasTimeSlots && selectedTimeSlotId == nil))
        .opacity((hasTimeSlots && selectedTimeSlotId == nil) ? 0.6 : 1.0)
    }
    
    // Helper methods for date/time formatting (same as before but integrated)
    private var groupedTimeSlots: [String: [ServiceTimeSlot]] {
        var grouped: [String: [ServiceTimeSlot]] = [:]
        for slot in viewModel.timeSlots {
            let parser = ISO8601DateFormatter()
            parser.timeZone = TimeZone(identifier: "UTC") // 解析时使用 UTC（数据库存储的是 UTC）
            if let date = parser.date(from: slot.slotStartDatetime) {
                let formatter = DateFormatter()
                formatter.locale = Locale.current // 使用用户系统 locale
                formatter.timeZone = TimeZone.current // 使用用户本地时区
                formatter.dateFormat = "yyyy-MM-dd"
                let key = formatter.string(from: date)
                if grouped[key] == nil { grouped[key] = [] }
                grouped[key]?.append(slot)
            }
        }
        return grouped
    }
    
    private func formatDate(_ dateString: String) -> String {
        let parser = DateFormatter()
        parser.dateFormat = "yyyy-MM-dd"
        parser.timeZone = TimeZone(identifier: "UTC") // 解析时使用 UTC（数据库存储的是 UTC）
        if let date = parser.date(from: dateString) {
            let formatter = DateFormatter()
            formatter.locale = Locale.current // 使用用户系统 locale
            formatter.timeZone = TimeZone.current // 使用用户本地时区
            // 根据 locale 选择合适的格式
            if Locale.current.identifier.hasPrefix("zh") {
                formatter.dateFormat = "MM月dd日 EEE"
            } else {
                formatter.dateFormat = "MMM dd, EEE"
            }
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
                
                Text("\(slot.currentParticipants)/\(slot.maxParticipants) \(LocalizationKey.activityPerson.localized)")
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
        parser.timeZone = TimeZone(identifier: "UTC") // 解析时使用 UTC（数据库存储的是 UTC）
        guard let sDate = parser.date(from: start), let eDate = parser.date(from: end) else { return "" }
        let formatter = DateFormatter()
        formatter.locale = Locale.current // 使用用户系统 locale
        formatter.timeZone = TimeZone.current // 使用用户本地时区
        formatter.dateFormat = "HH:mm"
        return "\(formatter.string(from: sDate))-\(formatter.string(from: eDate))"
    }
}

// MARK: - 活动分享视图
struct ActivityShareSheet: View {
    let activity: Activity
    let activityId: Int
    let shareImage: UIImage?
    let isShareImageLoading: Bool
    @Environment(\.dismiss) var dismiss
    
    // 使用 @State 确保标题和描述在视图更新时正确传递
    @State private var shareTitle: String = ""
    @State private var shareDescription: String = ""
    
    // 使用前端网页 URL，确保微信能抓取到正确的 meta 标签（weixin:title, weixin:description, weixin:image）
    // 前端页面已经设置了这些标签，微信会直接抓取
    private var shareUrl: URL {
        // 确保使用正确的activity ID（优先使用activity.id，如果匹配则使用activityId）
        let idToUse = (activity.id == activityId) ? activity.id : activityId
        // 使用前端域名，确保微信能抓取到正确的 meta 标签
        // 使用固定版本号而不是时间戳，避免每次分享都生成新URL导致系统多次尝试获取元数据
        let urlString = "https://www.link2ur.com/zh/activities/\(idToUse)?v=2"
        if let url = URL(string: urlString) {
            return url
        }
        // 如果URL构建失败，返回默认URL
        return URL(string: "https://www.link2ur.com")!
    }
    
    // 计算属性：确保标题始终是最新的
    private var currentTitle: String {
        return shareTitle.isEmpty ? getShareTitle(for: activity) : shareTitle
    }
    
    // 计算属性：确保描述始终是最新的
    private var currentDescription: String {
        return shareDescription.isEmpty ? getShareDescription(for: activity) : shareDescription
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 顶部拖动指示器
            Capsule()
                .fill(AppColors.separator)
                .frame(width: 36, height: 5)
                .padding(.top, 8)
                .padding(.bottom, 16)
            
            // 预览卡片
            VStack(spacing: AppSpacing.md) {
                // 封面图
                if let image = shareImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 150)
                        .clipped()
                        .cornerRadius(AppCornerRadius.medium)
                } else if isShareImageLoading {
                    // 图片加载中
                    ZStack {
                        RoundedRectangle(cornerRadius: AppCornerRadius.medium)
                            .fill(AppColors.cardBackground)
                            .frame(height: 150)
                        
                        VStack(spacing: AppSpacing.sm) {
                            ProgressView()
                                .tint(AppColors.primary)
                            Text(LocalizationKey.commonLoadingImage.localized)
                                .font(AppTypography.caption)
                                .foregroundColor(AppColors.textSecondary)
                        }
                    }
                } else {
                    RoundedRectangle(cornerRadius: AppCornerRadius.medium)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [AppColors.primary.opacity(0.6), AppColors.primary]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(height: 150)
                        .overlay(
                            IconStyle.icon("calendar.badge.plus", size: 40)
                                .foregroundColor(.white.opacity(0.8))
                        )
                }
                
                // 标题和描述
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    TranslatableText(
                        currentTitle,
                        font: AppTypography.bodyBold,
                        foregroundColor: AppColors.textPrimary,
                        lineLimit: 2
                    )
                    
                    if !currentDescription.isEmpty {
                        TranslatableText(
                            currentDescription,
                            font: AppTypography.caption,
                            foregroundColor: AppColors.textSecondary,
                            lineLimit: 2
                        )
                    }
                    
                    // 活动信息
                    HStack(spacing: AppSpacing.md) {
                        Label("£\(String(format: "%.0f", activity.discountedPricePerParticipant ?? activity.originalPricePerParticipant))", systemImage: "sterlingsign.circle")
                        Label(activity.location, systemImage: "mappin.circle")
                    }
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textTertiary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(AppSpacing.md)
            .background(AppColors.cardBackground)
            .cornerRadius(AppCornerRadius.large)
            .padding(.horizontal, AppSpacing.md)
            
            // 自定义分享面板（类似小红书）
            CustomSharePanel(
                title: currentTitle,
                description: currentDescription,
                url: shareUrl,
                image: shareImage,
                taskType: nil,
                location: activity.location,
                reward: {
                    let price = activity.discountedPricePerParticipant ?? activity.originalPricePerParticipant
                    return "£\(String(format: "%.0f", price))"
                }(),
                onDismiss: {
                    dismiss()
                }
            )
            .padding(.top, AppSpacing.md)
        }
        .background(AppColors.background)
        .onAppear {
            // 确保在视图出现时更新标题和描述
            shareTitle = getShareTitle(for: activity)
            shareDescription = getShareDescription(for: activity)
            // 调试日志
            Logger.debug("分享活动 - ID: \(activity.id), Title: \(shareTitle), Description: \(shareDescription.prefix(50))...", category: .ui)
        }
        .onChange(of: activity.title) { newTitle in
            // 当活动标题更新时，同步更新分享标题
            shareTitle = getShareTitle(for: activity)
        }
        .onChange(of: activity.description) { newDescription in
            // 当活动描述更新时，同步更新分享描述
            shareDescription = getShareDescription(for: activity)
        }
    }
    
    /// 获取分享标题（如果title是默认值，使用其他信息构建）
    private func getShareTitle(for activity: Activity) -> String {
        // 验证activity ID是否匹配
        if activity.id != activityId {
            Logger.warning("Activity ID不匹配: activity.id=\(activity.id), activityId=\(activityId)", category: .ui)
        }
        
        // 检查是否是默认值或空值
        let defaultTitles = ["Activity Title", "活动标题", "活动", "Default Title"]
        let trimmedTitle = activity.title.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if defaultTitles.contains(trimmedTitle) || trimmedTitle.isEmpty {
            // 使用任务类型和位置构建标题
            let taskTypeText = activity.taskType
            let locationText = activity.location.lowercased() == "online" 
                ? (LocalizationHelper.currentLanguage.hasPrefix("zh") ? "线上" : "Online")
                : activity.location
            return "\(taskTypeText) - \(locationText)"
        }
        
        // 返回实际的标题
        return trimmedTitle
    }
    
    /// 获取分享描述（如果description是默认值，使用其他信息构建）
    private func getShareDescription(for activity: Activity) -> String {
        // 验证activity ID是否匹配
        if activity.id != activityId {
            Logger.warning("Activity ID不匹配: activity.id=\(activity.id), activityId=\(activityId)", category: .ui)
        }
        
        // 检查是否是默认值或空值
        let defaultDescriptions = ["Activity Description", "活动描述", "活动详情", "Default Description"]
        let trimmedDescription = activity.description.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if defaultDescriptions.contains(trimmedDescription) || trimmedDescription.isEmpty {
            // 使用活动信息构建描述
            let price = activity.discountedPricePerParticipant ?? activity.originalPricePerParticipant
            let currencySymbol = activity.currency == "GBP" ? "£" : "¥"
            let participants = "\(activity.currentParticipants)/\(activity.maxParticipants)"
            let locationText = activity.location.lowercased() == "online" 
                ? (LocalizationHelper.currentLanguage.hasPrefix("zh") ? "线上" : "Online")
                : activity.location
            
            if LocalizationHelper.currentLanguage.hasPrefix("zh") {
                return "\(activity.taskType) | \(locationText) | \(currencySymbol)\(String(format: "%.0f", price)) | 参与者: \(participants)"
            } else {
                return "\(activity.taskType) | \(locationText) | \(currencySymbol)\(String(format: "%.0f", price)) | Participants: \(participants)"
            }
        }
        
        // 返回实际的描述（限制长度，避免过长）
        let maxLength = 200
        if trimmedDescription.count > maxLength {
            return String(trimmedDescription.prefix(maxLength)) + "..."
        }
        return trimmedDescription
    }
    
}

// MARK: - 活动分享内容提供者
class ActivityShareItem: NSObject, UIActivityItemSource {
    let url: URL
    let title: String
    let descriptionText: String
    let image: UIImage?
    
    init(url: URL, title: String, description: String, image: UIImage?) {
        self.url = url
        self.title = title
        self.descriptionText = description
        self.image = image
        super.init()
    }
    
    // 占位符 - 返回 URL，让系统知道这是链接分享
    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        return url
    }
    
    // 实际分享的内容 - 根据分享目标返回不同内容
    func activityViewController(_ activityViewController: UIActivityViewController, itemForActivityType activityType: UIActivity.ActivityType?) -> Any? {
        // 构建包含详情的分享文本（包含标题、描述和链接）
        let shareText = """
        \(title)
        
        \(descriptionText.prefix(200))\(descriptionText.count > 200 ? "..." : "")
        
        👉 查看详情: \(url.absoluteString)
        """
        
        // 对于支持 LPLinkMetadata 的应用（iMessage、邮件等），返回 URL
        // 这样系统会调用 activityViewControllerLinkMetadata 获取富媒体预览（包含图片和描述）
        if activityType == .mail || activityType == nil {
            // nil 通常表示 iMessage 等原生应用
            return url
        }
        
        // 对于不支持 LPLinkMetadata 的应用（微信、QQ、复制、短信等），返回包含详情的文本
        // 这样用户可以看到完整信息
        if activityType == .copyToPasteboard || 
           activityType == .message ||
           activityType == .postToWeibo ||
           activityType == .postToTencentWeibo {
            return shareText
        }
        
        // 其他情况也返回 URL，让系统尝试使用 LPLinkMetadata
        return url
    }
    
    // 提供富链接预览元数据（用于 iMessage 等原生 App）
    func activityViewControllerLinkMetadata(_ activityViewController: UIActivityViewController) -> LPLinkMetadata? {
        // 手动构建元数据，避免系统自动获取URL元数据导致的沙盒扩展错误
        let metadata = LPLinkMetadata()
        
        // 重要：不设置 url 或 originalURL，避免系统尝试自动获取元数据
        // 设置这些属性会导致系统尝试访问URL获取元数据，从而触发沙盒扩展错误
        // 系统会自动从 activityViewController 返回的 URL 中识别链接信息
        // 我们只提供手动设置的元数据（title 和 image），避免网络请求
        
        // 设置标题
        metadata.title = title
        
        // 如果有图片，设置为预览图（重要：这会让分享显示图片）
        if let image = image {
            let imageProvider = NSItemProvider(object: image)
            metadata.imageProvider = imageProvider
            metadata.iconProvider = imageProvider
        }
        
        return metadata
    }
    
    // 分享主题
    func activityViewController(_ activityViewController: UIActivityViewController, subjectForActivityType activityType: UIActivity.ActivityType?) -> String {
        return title
    }
}

// MARK: - 活动图片分享项（用于微信等需要图片的场景）
class ActivityImageShareItem: NSObject, UIActivityItemSource {
    let image: UIImage
    
    init(image: UIImage) {
        // 优化：压缩图片以减少内存占用和分享大小
        // 微信等平台对图片大小有限制，压缩后可以更快分享
        if let compressedImage = image.compressedForSharing() {
            self.image = compressedImage
        } else {
            self.image = image
        }
        super.init()
    }
    
    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        return image
    }
    
    func activityViewController(_ activityViewController: UIActivityViewController, itemForActivityType activityType: UIActivity.ActivityType?) -> Any? {
        return image
    }
}

