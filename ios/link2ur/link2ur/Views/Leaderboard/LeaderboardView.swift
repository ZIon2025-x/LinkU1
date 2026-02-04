import SwiftUI
import Combine
import Foundation

struct LeaderboardView: View {
    @StateObject private var viewModel = LeaderboardViewModel()
    @EnvironmentObject var appState: AppState
    @State private var selectedSort = "latest"
    @State private var showApplyLeaderboard = false
    @State private var showLogin = false
    
    // 优先显示收藏的排行榜
    private var sortedLeaderboards: [CustomLeaderboard] {
        let favorited = viewModel.leaderboards.filter { $0.isFavorited == true }
        let notFavorited = viewModel.leaderboards.filter { $0.isFavorited != true }
        return favorited + notFavorited
    }
    
    var body: some View {
        ZStack {
            AppColors.background
                .ignoresSafeArea()
            
            if viewModel.isLoading && viewModel.leaderboards.isEmpty {
                ProgressView()
            } else if viewModel.leaderboards.isEmpty {
                VStack(spacing: AppSpacing.xl) {
                    EmptyStateView(
                        icon: "trophy.fill",
                        title: LocalizationKey.leaderboardEmptyTitle.localized,
                        message: LocalizationKey.leaderboardEmptyMessage.localized
                    )
                    
                    Button(action: {
                        if appState.isAuthenticated {
                            showApplyLeaderboard = true
                        } else {
                            showLogin = true
                        }
                    }) {
                        HStack {
                            IconStyle.icon("plus.circle.fill", size: 18)
                            Text(LocalizationKey.leaderboardApplyNew.localized)
                        }
                        .font(AppTypography.bodyBold)
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .frame(width: 200)
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: DeviceInfo.isPad ? AppSpacing.lg : AppSpacing.md) {
                        ForEach(sortedLeaderboards) { leaderboard in
                            NavigationLink(destination: LeaderboardDetailView(leaderboardId: leaderboard.id)) {
                                LeaderboardCard(leaderboard: leaderboard)
                                    .environmentObject(appState)
                            }
                            .buttonStyle(ScaleButtonStyle())
                        }
                    }
                    .padding(.horizontal, DeviceInfo.isPad ? AppSpacing.xl : AppSpacing.md)
                    .padding(.vertical, DeviceInfo.isPad ? AppSpacing.md : AppSpacing.sm)
                    .frame(maxWidth: DeviceInfo.isPad ? 900 : .infinity) // iPad上限制最大宽度
                    .frame(maxWidth: .infinity, alignment: .center) // 确保在iPad上居中
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: AppSpacing.sm) {
                    // 申请按钮
                    Button {
                        if appState.isAuthenticated {
                            showApplyLeaderboard = true
                        } else {
                            showLogin = true
                        }
                    } label: {
                        IconStyle.icon("plus.circle.fill", size: 22)
                            .foregroundColor(AppColors.primary)
                    }
                    
                    // 排序菜单
                    Menu {
                        Button(LocalizationKey.leaderboardSortLatest.localized) { selectedSort = "latest"; viewModel.loadLeaderboards(sort: selectedSort) }
                        Button(LocalizationKey.leaderboardSortHot.localized) { selectedSort = "hot"; viewModel.loadLeaderboards(sort: selectedSort) }
                        Button(LocalizationKey.leaderboardSortVotes.localized) { selectedSort = "votes"; viewModel.loadLeaderboards(sort: selectedSort) }
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .font(.system(size: 20))
                            .foregroundColor(AppColors.primary)
                    }
                }
            }
        }
        .refreshable {
            viewModel.loadLeaderboards(sort: selectedSort, forceRefresh: true)
        }
        .task {
            // 优化：先从缓存加载，避免初次进入时显示空状态
            // 排行榜肯定不是空的，应该先从缓存加载
            if viewModel.leaderboards.isEmpty {
                // loadLeaderboards 内部已经会从缓存加载，但这里确保先显示缓存数据
                if let cachedLeaderboards = CacheManager.shared.loadLeaderboards(location: nil, sort: selectedSort) {
                    viewModel.leaderboards = cachedLeaderboards
                    Logger.success("从缓存加载了 \(cachedLeaderboards.count) 个排行榜", category: .cache)
                }
            }
        }
        .onAppear {
            // 优化：只在缓存也为空时才加载，避免不必要的网络请求
            if viewModel.leaderboards.isEmpty && !viewModel.isLoading {
                viewModel.loadLeaderboards(sort: selectedSort)
            }
        }
        .sheet(isPresented: $showApplyLeaderboard) {
            ApplyLeaderboardView()
        }
        .sheet(isPresented: $showLogin) {
            LoginView()
        }
    }
}

// 排行榜卡片 - 美化版
struct LeaderboardCard: View {
    let leaderboard: CustomLeaderboard
    @EnvironmentObject var appState: AppState
    @State private var isFavorited: Bool?
    @State private var isTogglingFavorite = false
    private let apiService = APIService.shared
    @State private var cancellables = Set<AnyCancellable>()
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                // 封面和标题
                HStack(spacing: DeviceInfo.isPad ? AppSpacing.lg : AppSpacing.md) {
                // 封面图片
                if let coverImage = leaderboard.coverImage, !coverImage.isEmpty {
                    AsyncImageView(
                        urlString: coverImage,
                        placeholder: Image(systemName: "photo.fill")
                    )
                    .aspectRatio(contentMode: .fill)
                    .frame(width: DeviceInfo.isPad ? 120 : 100, height: DeviceInfo.isPad ? 120 : 100)
                    .clipShape(RoundedRectangle(cornerRadius: AppCornerRadius.medium, style: .continuous))
                } else {
                    ZStack {
                        RoundedRectangle(cornerRadius: AppCornerRadius.medium, style: .continuous)
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: AppColors.gradientPrimary),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: DeviceInfo.isPad ? 120 : 100, height: DeviceInfo.isPad ? 120 : 100)
                        
                        IconStyle.icon("trophy.fill", size: DeviceInfo.isPad ? 50 : 40)
                            .foregroundColor(.white)
                    }
                }
                
                VStack(alignment: .leading, spacing: DeviceInfo.isPad ? AppSpacing.md : AppSpacing.sm) {
                    Text(leaderboard.displayName)
                        .font(AppTypography.title3)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.textPrimary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    
                    if let description = leaderboard.displayDescription {
                        Text(description)
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.textSecondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                    
                    if let location = leaderboard.location {
                        HStack(spacing: 4) {
                            IconStyle.icon("mappin.circle.fill", size: 12)
                            Text(location)
                                .font(AppTypography.caption2)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(AppColors.textSecondary)
                    }
                    }
                    
                    Spacer()
                }
                
                Divider().background(AppColors.divider)
                
                // 统计信息
                HStack(spacing: DeviceInfo.isPad ? 32 : 24) {
                    CompactStatItem(icon: "square.grid.2x2.fill", count: leaderboard.itemCount)
                    CompactStatItem(icon: "hand.thumbsup.fill", count: leaderboard.voteCount)
                    CompactStatItem(icon: "eye.fill", count: leaderboard.viewCount)
                }
            }
            .padding(DeviceInfo.isPad ? AppSpacing.lg : AppSpacing.md)
            .background(AppColors.cardBackground)
            .cornerRadius(AppCornerRadius.large)
            .shadow(color: AppShadow.small.color, radius: AppShadow.small.radius, x: AppShadow.small.x, y: AppShadow.small.y)
            
            // 收藏图标提示（仅在已收藏时显示）
            if (isFavorited ?? leaderboard.isFavorited ?? false) {
                Image(systemName: "star.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.yellow)
                    .padding(6)
                    .background(
                        Circle()
                            .fill(Color.white.opacity(0.9))
                            .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
                    )
                    .padding(8)
            }
        }
        .onAppear {
            // 初始化收藏状态
            isFavorited = leaderboard.isFavorited
        }
        .onChange(of: leaderboard.isFavorited) { newValue in
            isFavorited = newValue
        }
    }
    
    private func handleToggleFavorite() {
        guard !isTogglingFavorite else { return }
        isTogglingFavorite = true
        
        apiService.toggleLeaderboardFavorite(leaderboardId: leaderboard.id)
            .sink(receiveCompletion: { result in
                DispatchQueue.main.async {
                    isTogglingFavorite = false
                    if case .failure(let error) = result {
                        ErrorHandler.shared.handle(error, context: "收藏操作")
                    }
                }
            }, receiveValue: { response in
                DispatchQueue.main.async {
                    isFavorited = response.favorited
                }
            })
            .store(in: &cancellables)
    }
}

