import SwiftUI

struct LeaderboardView: View {
    @StateObject private var viewModel = LeaderboardViewModel()
    @State private var selectedSort = "latest"
    
    var body: some View {
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

// 排行榜卡片 - 美化版
struct LeaderboardCard: View {
    let leaderboard: CustomLeaderboard
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            // 封面和标题
            HStack(spacing: AppSpacing.md) {
                // 封面图片 - 更大更美观
                if let coverImage = leaderboard.coverImage, !coverImage.isEmpty {
                    AsyncImage(url: coverImage.toImageURL()) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        RoundedRectangle(cornerRadius: AppCornerRadius.medium)
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [AppColors.primary.opacity(0.2), AppColors.primary.opacity(0.1)]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                    .frame(width: 100, height: 100)
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
                            .frame(width: 100, height: 100)
                        
                        Image(systemName: "trophy.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.white)
                    }
                }
                
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    Text(leaderboard.name)
                        .font(AppTypography.title3)
                        .foregroundColor(AppColors.textPrimary)
                        .lineLimit(2)
                    
                    if let description = leaderboard.description {
                        Text(description)
                            .font(AppTypography.subheadline)
                            .foregroundColor(AppColors.textSecondary)
                            .lineLimit(2)
                    }
                    
                    if let location = leaderboard.location {
                        HStack(spacing: 4) {
                            Image(systemName: "mappin.circle.fill")
                                .font(.system(size: 12))
                            Text(location)
                                .font(AppTypography.caption)
                        }
                        .foregroundColor(AppColors.textSecondary)
                    }
                }
                
                Spacer()
            }
            
            Divider()
                .background(AppColors.separator)
            
            // 统计信息 - 更美观
            HStack(spacing: AppSpacing.xl) {
                HStack(spacing: AppSpacing.xs) {
                    Image(systemName: "square.grid.2x2.fill")
                        .font(.system(size: 14))
                    Text(leaderboard.itemCount.formatCount())
                        .font(AppTypography.caption)
                        .fontWeight(.medium)
                }
                .foregroundColor(AppColors.textSecondary)
                
                HStack(spacing: AppSpacing.xs) {
                    Image(systemName: "hand.thumbsup.fill")
                        .font(.system(size: 14))
                    Text(leaderboard.voteCount.formatCount())
                        .font(AppTypography.caption)
                        .fontWeight(.medium)
                }
                .foregroundColor(AppColors.textSecondary)
                
                HStack(spacing: AppSpacing.xs) {
                    Image(systemName: "eye.fill")
                        .font(.system(size: 14))
                    Text(leaderboard.viewCount.formatCount())
                        .font(AppTypography.caption)
                        .fontWeight(.medium)
                }
                .foregroundColor(AppColors.textSecondary)
            }
        }
        .padding(AppSpacing.md)
        .cardStyle()
    }
}

