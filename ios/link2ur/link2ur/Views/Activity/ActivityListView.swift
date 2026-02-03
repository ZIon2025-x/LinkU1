import SwiftUI
import Combine

struct ActivityListView: View {
    @StateObject private var viewModel = ActivityViewModel()
    @State private var selectedExpertId: String?
    @State private var filterOption: ActivityFilterOption = .single
    
    /// 活动大厅只展示未结束活动；标签为单人（非时间段） / 多人（时间段）
    enum ActivityFilterOption: String, CaseIterable {
        case single = "activity.single"
        case multi = "activity.multi"
        
        var localized: String {
            switch self {
            case .single: return LocalizationKey.activitySingle.localized
            case .multi: return LocalizationKey.activityMulti.localized
            }
        }
    }
    
    /// 当前标签下的列表：服务端已按 has_time_slots 筛选，直接取对应列表
    private var filteredActivities: [Activity] {
        switch filterOption {
        case .single: return viewModel.activitiesSingle
        case .multi: return viewModel.activitiesMulti
        }
    }
    
    var body: some View {
        ZStack {
            AppColors.background
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 筛选器：单人活动 / 多人活动
                Picker(LocalizationKey.activityFilter.localized, selection: $filterOption) {
                    ForEach(ActivityFilterOption.allCases, id: \.self) { option in
                        Text(option.localized).tag(option)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal, AppSpacing.md)
                .padding(.vertical, AppSpacing.sm)
                
                // 活动列表（仅未结束，服务端按单人/多人筛选）
                if viewModel.isLoading && viewModel.activitiesSingle.isEmpty && viewModel.activitiesMulti.isEmpty {
                    ScrollView {
                        ListSkeleton(itemCount: 5, itemHeight: 150)
                            .padding(.horizontal, AppSpacing.md)
                            .padding(.vertical, AppSpacing.sm)
                    }
                } else if filteredActivities.isEmpty {
                    EmptyStateView(
                        icon: "calendar.badge.plus",
                        title: LocalizationKey.activityNoActivities.localized,
                        message: LocalizationKey.activityNoActivitiesMessage.localized
                    )
                } else {
                    ScrollView {
                        LazyVStack(spacing: AppSpacing.md) {
                            ForEach(Array(filteredActivities.enumerated()), id: \.element.id) { index, activity in
                                NavigationLink(destination: ActivityDetailView(activityId: activity.id)) {
                                    ActivityCardView(
                                        activity: activity,
                                        showEndedBadge: false,
                                        isFavorited: viewModel.favoritedActivityIds.contains(activity.id)
                                    )
                                }
                                .buttonStyle(ScaleButtonStyle())
                                .listItemAppear(index: index, totalItems: filteredActivities.count)
                            }
                        }
                        .padding(.horizontal, AppSpacing.md)
                        .padding(.vertical, AppSpacing.sm)
                    }
                }
            }
        }
        .navigationTitle(LocalizationKey.activityActivities.localized)
        .navigationBarTitleDisplayMode(.large)
        .enableSwipeBack()
        .refreshable {
            viewModel.loadActivitiesForHall(forceRefresh: true)
        }
        .onAppear {
            if viewModel.activitiesSingle.isEmpty && viewModel.activitiesMulti.isEmpty {
                viewModel.loadActivitiesForHall()
            } else {
                viewModel.loadFavoriteActivityIds()
            }
        }
        .alert(LocalizationKey.errorError.localized, isPresented: .constant(viewModel.errorMessage != nil)) {
            Button(LocalizationKey.commonOk.localized, role: .cancel) {
                viewModel.errorMessage = nil
            }
        } message: {
            if let error = viewModel.errorMessage {
                Text(error)
            }
        }
    }
}

struct ActivityCardView: View {
    let activity: Activity
    var showEndedBadge: Bool = false
    var isFavorited: Bool = false // 是否已收藏
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 图片区域（使用 Color.clear + overlay 固定尺寸，避免宽图撑开布局）
            ZStack(alignment: .topTrailing) {
                if let images = activity.images, let firstImage = images.first, !firstImage.isEmpty {
                    Color.clear
                        .frame(maxWidth: .infinity)
                        .frame(height: 160)
                        .overlay(
                            AsyncImageView(
                                urlString: firstImage,
                                placeholder: Image(systemName: "photo.fill"),
                                contentMode: .fill
                            )
                        )
                        .clipped()
                } else {
                    placeholderBackground()
                }
                
                // 右上角收藏红心图标
                if isFavorited {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(6)
                        .background(Color.red)
                        .clipShape(Circle())
                        .shadow(color: Color.black.opacity(0.3), radius: 3, x: 0, y: 2)
                        .padding(8)
                }
                
                // 状态标签（如果已收藏，放在左上角；否则放在右上角）
                VStack(alignment: isFavorited ? .leading : .trailing, spacing: 4) {
                    if showEndedBadge && activity.isEnded {
                        Text(LocalizationKey.activityEnded.localized)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.black.opacity(0.6))
                            .clipShape(Capsule())
                    } else if activity.isFull {
                        Text(LocalizationKey.activityFullCapacity.localized)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(AppColors.error)
                            .clipShape(Capsule())
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: isFavorited ? .topLeading : .topTrailing)
                .padding(AppSpacing.sm)
            }
            
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                TranslatableText(
                    activity.title,
                    font: AppTypography.bodyBold,
                    foregroundColor: AppColors.textPrimary,
                    lineLimit: 1
                )
                
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
                        Text(LocalizationKey.activityByAppointment.localized)
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
            .background(AppColors.cardBackground) // 内容区域背景
        }
        .background(
            RoundedRectangle(cornerRadius: AppCornerRadius.large, style: .continuous)
                .fill(AppColors.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: AppCornerRadius.large, style: .continuous)
                        .stroke(Color(UIColor.separator).opacity(0.3), lineWidth: 0.5)
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: AppCornerRadius.large, style: .continuous)) // 优化：确保圆角边缘干净
        .compositingGroup() // 组合渲染，确保圆角边缘干净
        // 移除阴影，使用更轻量的视觉分隔
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

#Preview {
    ActivityListView()
}
