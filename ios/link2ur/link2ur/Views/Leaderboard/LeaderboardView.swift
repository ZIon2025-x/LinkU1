import SwiftUI

struct LeaderboardView: View {
    @StateObject private var viewModel = LeaderboardViewModel()
    @EnvironmentObject var appState: AppState
    @State private var selectedSort = "latest"
    @State private var showApplyLeaderboard = false
    @State private var showLogin = false
    
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
                        title: "暂无排行榜",
                        message: "还没有排行榜，快来申请创建第一个吧！"
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
                        ForEach(viewModel.leaderboards) { leaderboard in
                            NavigationLink(destination: LeaderboardDetailView(leaderboardId: leaderboard.id)) {
                                LeaderboardCard(leaderboard: leaderboard)
                            }
                            .buttonStyle(ScaleButtonStyle())
                        }
                    }
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.vertical, AppSpacing.sm)
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
                        Button("最新") { selectedSort = "latest"; viewModel.loadLeaderboards(sort: selectedSort) }
                        Button("热门") { selectedSort = "hot"; viewModel.loadLeaderboards(sort: selectedSort) }
                        Button("投票数") { selectedSort = "votes"; viewModel.loadLeaderboards(sort: selectedSort) }
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .font(.system(size: 20))
                            .foregroundColor(AppColors.primary)
                    }
                }
            }
        }
        .refreshable {
            viewModel.loadLeaderboards(sort: selectedSort)
        }
        .onAppear {
            if viewModel.leaderboards.isEmpty {
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
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            // 封面和标题
            HStack(spacing: AppSpacing.md) {
                // 封面图片
                if let coverImage = leaderboard.coverImage, !coverImage.isEmpty {
                    AsyncImageView(
                        urlString: coverImage,
                        placeholder: Image(systemName: "photo.fill")
                    )
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 100, height: 100)
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
                            .frame(width: 100, height: 100)
                        
                        IconStyle.icon("trophy.fill", size: 40)
                            .foregroundColor(.white)
                    }
                }
                
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    Text(leaderboard.name)
                        .font(AppTypography.title3)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.textPrimary)
                        .lineLimit(2)
                    
                    if let description = leaderboard.description {
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
            HStack(spacing: 24) {
                CompactStatItem(icon: "square.grid.2x2.fill", count: leaderboard.itemCount)
                CompactStatItem(icon: "hand.thumbsup.fill", count: leaderboard.voteCount)
                CompactStatItem(icon: "eye.fill", count: leaderboard.viewCount)
            }
        }
        .padding(AppSpacing.md)
        .background(AppColors.cardBackground)
        .cornerRadius(AppCornerRadius.large)
        .shadow(color: AppShadow.small.color, radius: AppShadow.small.radius, x: AppShadow.small.x, y: AppShadow.small.y)
    }
}

