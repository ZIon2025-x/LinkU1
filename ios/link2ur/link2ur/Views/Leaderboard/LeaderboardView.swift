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
                ListSkeleton(itemCount: 5, itemHeight: 90)
                    .padding(.horizontal, AppSpacing.md)
            } else if viewModel.errorMessage != nil && viewModel.leaderboards.isEmpty {
                ErrorStateView(
                    title: LocalizationKey.tasksLoadFailed.localized,
                    message: viewModel.errorMessage ?? "",
                    retryAction: { viewModel.loadLeaderboards(sort: selectedSort, forceRefresh: true) }
                )
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
                    LazyVStack(spacing: AppSpacing.md) {
                        ForEach(Array(sortedLeaderboards.enumerated()), id: \.element.id) { index, leaderboard in
                            NavigationLink(destination: LeaderboardDetailView(leaderboardId: leaderboard.id)) {
                                LeaderboardCard(leaderboard: leaderboard)
                                    .environmentObject(appState)
                            }
                            .buttonStyle(ScaleButtonStyle())
                            .onAppear {
                                if index >= sortedLeaderboards.count - 3 && viewModel.hasMore && !viewModel.isLoadingMore && !viewModel.isLoading {
                                    viewModel.loadMore(location: nil, sort: selectedSort)
                                }
                            }
                        }
                        if viewModel.isLoadingMore {
                            HStack {
                                Spacer()
                                ProgressView().padding()
                                Spacer()
                            }
                        } else if viewModel.hasMore && !viewModel.leaderboards.isEmpty {
                            Button(action: { viewModel.loadMore(location: nil, sort: selectedSort) }) {
                                Text(LocalizationKey.commonLoadMore.localized)
                                    .font(AppTypography.caption)
                                    .foregroundColor(AppColors.primary)
                            }
                            .padding(.vertical, 12)
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.horizontal, DeviceInfo.isPad ? AppSpacing.xl : AppSpacing.md)
                    .padding(.vertical, DeviceInfo.isPad ? AppSpacing.md : AppSpacing.sm)
                    .frame(maxWidth: DeviceInfo.isPad ? 900 : .infinity)
                    .frame(maxWidth: .infinity, alignment: .center)
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

// 排行榜卡片 - 与 Flutter _LeaderboardCard 一致：90x90 封面、每卡独立渐变
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
                // 封面图片 - Flutter 使用 90x90
                let coverSize: CGFloat = DeviceInfo.isPad ? 90 : 90
                let gradientColors = leaderboardGradient(for: leaderboard.id)
                if let coverImage = leaderboard.coverImage, !coverImage.isEmpty {
                    AsyncImageView(
                        urlString: coverImage,
                        placeholder: Image(systemName: "photo.fill")
                    )
                    .aspectRatio(contentMode: .fill)
                    .frame(width: coverSize, height: coverSize)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                } else {
                    ZStack {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: gradientColors),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: coverSize, height: coverSize)
                        
                        IconStyle.icon("trophy.fill", size: 36)
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
            .shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 4)
            .shadow(color: Color.black.opacity(0.02), radius: 2, x: 0, y: 1)
            
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
    
    private func leaderboardGradient(for id: Int) -> [Color] {
        let gradients: [[Color]] = [
            [Color(red: 1, green: 0.4, blue: 0.4), Color(red: 1, green: 0.6, blue: 0.5)],
            [Color(red: 0.6, green: 0.4, blue: 1), Color(red: 0.8, green: 0.6, blue: 1)],
            [Color(red: 0.2, green: 0.8, blue: 0.6), Color(red: 0.4, green: 0.9, blue: 0.7)],
            [Color(red: 1, green: 0.6, blue: 0.2), Color(red: 1, green: 0.8, blue: 0.4)],
            [Color(red: 0.4, green: 0.5, blue: 1), Color(red: 0.6, green: 0.7, blue: 1)]
        ]
        let idx = (id % gradients.count + gradients.count) % gradients.count
        return gradients[idx]
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

