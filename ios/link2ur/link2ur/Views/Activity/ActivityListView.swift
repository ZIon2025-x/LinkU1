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

struct ActivityCardView: View {
    let activity: Activity
    var showEndedBadge: Bool = false
    
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
                
                // 状态标签
                if showEndedBadge && activity.isEnded {
                    Text("已结束")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.black.opacity(0.6))
                        .clipShape(Capsule())
                        .padding(AppSpacing.sm)
                } else if activity.isFull {
                    Text("已满员")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(AppColors.error)
                        .clipShape(Capsule())
                        .padding(AppSpacing.sm)
                }
            }
            
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Text(activity.title)
                    .font(AppTypography.bodyBold)
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(1)
                
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
                .frame(height: 180)
            
            IconStyle.icon("calendar.badge.plus", size: 40)
                .foregroundColor(AppColors.primary.opacity(0.3))
        }
    }
}

#Preview {
    ActivityListView()
}
