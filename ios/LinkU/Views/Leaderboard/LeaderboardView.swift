import SwiftUI

struct LeaderboardView: View {
    @StateObject private var viewModel = LeaderboardViewModel()
    @State private var selectedSort = "latest"
    
    var body: some View {
        NavigationView {
            ZStack {
                AppColors.background
                    .ignoresSafeArea()
                
                // 顶部装饰：荣耀感光辉
                LinearGradient(colors: [Color.orange.opacity(0.1), .clear], startPoint: .top, endPoint: .bottom)
                    .frame(height: 200)
                    .ignoresSafeArea()
                
                if viewModel.isLoading && viewModel.leaderboards.isEmpty {
                    LoadingView()
                } else if viewModel.leaderboards.isEmpty {
                    EmptyStateView(
                        icon: "crown.fill",
                        title: "虚位以待",
                        message: "目前还没有排行榜，开启第一个传奇吧"
                    )
                } else {
                    ScrollView {
                        VStack(spacing: 24) {
                            // 冠亚季军特殊展示区域
                            topThreeSection
                            
                            // 普通列表
                            VStack(alignment: .leading, spacing: 16) {
                                Text("更多排行榜")
                                    .font(.system(size: 18, weight: .bold))
                                    .padding(.horizontal, AppSpacing.md)
                                
                                LazyVStack(spacing: AppSpacing.md) {
                                    ForEach(viewModel.leaderboards) { leaderboard in
                                        NavigationLink(destination: LeaderboardDetailView(leaderboardId: leaderboard.id)) {
                                            LeaderboardCard(leaderboard: leaderboard)
                                        }
                                    }
                                }
                                .padding(.horizontal, AppSpacing.md)
                            }
                        }
                        .padding(.vertical, AppSpacing.sm)
                    }
                }
            }
            .navigationTitle("荣誉排行榜")
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
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 16) {
                // 排名封面
                ZStack {
                    if let coverImage = leaderboard.coverImage, !coverImage.isEmpty {
                        AsyncImage(url: URL(string: coverImage)) { image in
                            image.resizable().aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Rectangle().fill(AppColors.primary.opacity(0.1))
                        }
                    } else {
                        Rectangle().fill(AppColors.primaryGradient)
                        Image(systemName: "crown.fill")
                            .foregroundColor(.white.opacity(0.8))
                            .font(.title2)
                    }
                }
                .frame(width: 70, height: 70)
                .cornerRadius(12)
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(leaderboard.name)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(AppColors.textPrimary)
                        .lineLimit(1)
                    
                    Text(leaderboard.description ?? "没有描述")
                        .font(.system(size: 13))
                        .foregroundColor(AppColors.textSecondary)
                        .lineLimit(1)
                    
                    HStack(spacing: 12) {
                        Label("\(leaderboard.voteCount)", systemImage: "flame.fill")
                            .foregroundColor(.orange)
                        Label("\(leaderboard.itemCount) 项", systemImage: "list.number")
                            .foregroundColor(AppColors.primary)
                    }
                    .font(.system(size: 11, weight: .bold))
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(AppColors.textTertiary)
            }
            .padding(16)
        }
        .background(AppColors.cardBackground)
        .cornerRadius(AppCornerRadius.medium)
        .shadow(color: Color.black.opacity(0.03), radius: 10, x: 0, y: 5)
    }
}

extension LeaderboardView {
    private var topThreeSection: some View {
        HStack(alignment: .bottom, spacing: 12) {
            // 第2名
            rankColumn(rank: 2, name: "热门任务", score: "2.3k", color: Color.gray.opacity(0.3))
            
            // 第1名
            rankColumn(rank: 1, name: "年度达人", score: "5.8k", color: .orange.opacity(0.3), height: 160)
            
            // 第3名
            rankColumn(rank: 3, name: "校园互助", score: "1.9k", color: .brown.opacity(0.3))
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.top, 20)
    }
    
    private func rankColumn(rank: Int, name: String, score: String, color: Color, height: CGFloat = 130) -> some View {
        VStack(spacing: 12) {
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 16)
                    .fill(color)
                    .frame(height: height)
                
                VStack(spacing: 8) {
                    Image(systemName: rank == 1 ? "crown.fill" : "medal.fill")
                        .font(.system(size: 24))
                        .foregroundColor(rank == 1 ? .orange : (rank == 2 ? .gray : .brown))
                    
                    Text(name)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(AppColors.textPrimary)
                        .lineLimit(1)
                    
                    Text(score)
                        .font(.system(size: 16, weight: .black, design: .rounded))
                        .foregroundColor(AppColors.primary)
                }
                .padding(.bottom, 20)
            }
            
            Text("NO.\(rank)")
                .font(.system(size: 11, weight: .black))
                .foregroundColor(AppColors.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }
}

