import SwiftUI

struct LeaderboardView: View {
    @StateObject private var viewModel = LeaderboardViewModel()
    @State private var selectedSort = "latest"
    
    var body: some View {
        NavigationView {
            ZStack {
                AppColors.background
                    .ignoresSafeArea()
                
                if viewModel.isLoading && viewModel.leaderboards.isEmpty {
                    ProgressView()
                } else if viewModel.leaderboards.isEmpty {
                    EmptyStateView(
                        icon: "trophy.fill",
                        title: "暂无排行榜",
                        message: "还没有排行榜，快来创建第一个吧！"
                    )
                } else {
                    ScrollView {
                        LazyVStack(spacing: AppSpacing.md) {
                            ForEach(viewModel.leaderboards) { leaderboard in
                                NavigationLink(destination: LeaderboardDetailView(leaderboardId: leaderboard.id)) {
                                    LeaderboardCard(leaderboard: leaderboard)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(.horizontal, AppSpacing.md)
                        .padding(.vertical, AppSpacing.sm)
                    }
                }
            }
            .navigationTitle("排行榜")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("最新") { selectedSort = "latest"; viewModel.loadLeaderboards(sort: selectedSort) }
                        Button("热门") { selectedSort = "hot"; viewModel.loadLeaderboards(sort: selectedSort) }
                        Button("投票数") { selectedSort = "votes"; viewModel.loadLeaderboards(sort: selectedSort) }
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .foregroundColor(AppColors.primary)
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
        }
    }
}

// 排行榜卡片
struct LeaderboardCard: View {
    let leaderboard: CustomLeaderboard
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 封面和标题
            HStack(spacing: AppSpacing.md) {
                if let coverImage = leaderboard.coverImage, !coverImage.isEmpty {
                    AsyncImage(url: URL(string: coverImage)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        RoundedRectangle(cornerRadius: AppCornerRadius.small)
                            .fill(AppColors.primaryLight)
                    }
                    .frame(width: 80, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: AppCornerRadius.medium))
                } else {
                    ZStack {
                        RoundedRectangle(cornerRadius: AppCornerRadius.medium)
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [AppColors.primary, AppColors.primary.opacity(0.7)]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 80, height: 80)
                        
                        Image(systemName: "trophy.fill")
                            .font(.title)
                            .foregroundColor(.white)
                    }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(leaderboard.name)
                        .font(.headline)
                        .foregroundColor(AppColors.textPrimary)
                        .lineLimit(2)
                    
                    if let description = leaderboard.description {
                        Text(description)
                            .font(.caption)
                            .foregroundColor(AppColors.textSecondary)
                            .lineLimit(2)
                    }
                    
                    if let location = leaderboard.location {
                        HStack(spacing: 4) {
                            Image(systemName: "mappin.circle.fill")
                                .font(.caption2)
                            Text(location)
                                .font(.caption)
                        }
                        .foregroundColor(AppColors.textSecondary)
                    }
                }
                
                Spacer()
            }
            
            Divider()
            
            // 统计信息
            HStack(spacing: 24) {
                Label("\(leaderboard.itemCount)", systemImage: "square.grid.2x2")
                Label("\(leaderboard.voteCount)", systemImage: "hand.thumbsup")
                Label("\(leaderboard.viewCount)", systemImage: "eye")
            }
            .font(.caption)
            .foregroundColor(AppColors.textSecondary)
        }
        .padding(AppSpacing.md)
        .background(AppColors.cardBackground)
        .cornerRadius(AppCornerRadius.medium)
        .shadow(color: AppShadow.small.color, radius: AppShadow.small.radius, x: AppShadow.small.x, y: AppShadow.small.y)
    }
}

