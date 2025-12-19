import SwiftUI

struct LeaderboardDetailView: View {
    let leaderboardId: Int
    @StateObject private var viewModel = LeaderboardDetailViewModel()
    @State private var selectedSort = "vote_score"
    
    var body: some View {
        ZStack {
            AppColors.background
                .ignoresSafeArea()
            
            if viewModel.isLoading && viewModel.leaderboard == nil {
                ProgressView()
            } else if let leaderboard = viewModel.leaderboard {
                ScrollView {
                    VStack(alignment: .leading, spacing: AppSpacing.lg) {
                        // 排行榜信息
                        VStack(alignment: .leading, spacing: AppSpacing.md) {
                            if let coverImage = leaderboard.coverImage, !coverImage.isEmpty {
                                AsyncImage(url: URL(string: coverImage)) { image in
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                } placeholder: {
                                    RoundedRectangle(cornerRadius: AppCornerRadius.medium)
                                        .fill(AppColors.primaryLight)
                                }
                                .frame(height: 200)
                                .clipShape(RoundedRectangle(cornerRadius: AppCornerRadius.medium))
                            }
                            
                            Text(leaderboard.name)
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(AppColors.textPrimary)
                            
                            if let description = leaderboard.description {
                                Text(description)
                                    .font(.body)
                                    .foregroundColor(AppColors.textSecondary)
                            }
                            
                            // 统计信息
                            HStack(spacing: 32) {
                                VStack {
                                    Text("\(leaderboard.itemCount)")
                                        .font(.title2)
                                        .fontWeight(.bold)
                                        .foregroundColor(AppColors.primary)
                                    Text("竞品数")
                                        .font(.caption)
                                        .foregroundColor(AppColors.textSecondary)
                                }
                                
                                VStack {
                                    Text("\(leaderboard.voteCount)")
                                        .font(.title2)
                                        .fontWeight(.bold)
                                        .foregroundColor(AppColors.warning)
                                    Text("总投票")
                                        .font(.caption)
                                        .foregroundColor(AppColors.textSecondary)
                                }
                                
                                VStack {
                                    Text("\(leaderboard.viewCount)")
                                        .font(.title2)
                                        .fontWeight(.bold)
                                        .foregroundColor(AppColors.textSecondary)
                                    Text("浏览量")
                                        .font(.caption)
                                        .foregroundColor(AppColors.textSecondary)
                                }
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .padding(AppSpacing.md)
                        .background(AppColors.cardBackground)
                        .cornerRadius(AppCornerRadius.medium)
                        .shadow(color: AppShadow.small.color, radius: AppShadow.small.radius, x: AppShadow.small.x, y: AppShadow.small.y)
                        
                        // 排序选择
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: AppSpacing.sm) {
                                SortButton(title: "综合", isSelected: selectedSort == "vote_score") {
                                    selectedSort = "vote_score"
                                    viewModel.loadItems(leaderboardId: leaderboardId, sort: selectedSort)
                                }
                                SortButton(title: "净投票", isSelected: selectedSort == "net_votes") {
                                    selectedSort = "net_votes"
                                    viewModel.loadItems(leaderboardId: leaderboardId, sort: selectedSort)
                                }
                                SortButton(title: "支持数", isSelected: selectedSort == "upvotes") {
                                    selectedSort = "upvotes"
                                    viewModel.loadItems(leaderboardId: leaderboardId, sort: selectedSort)
                                }
                                SortButton(title: "最新", isSelected: selectedSort == "created_at") {
                                    selectedSort = "created_at"
                                    viewModel.loadItems(leaderboardId: leaderboardId, sort: selectedSort)
                                }
                            }
                            .padding(.horizontal, AppSpacing.md)
                        }
                        
                        // 竞品列表
                        VStack(alignment: .leading, spacing: AppSpacing.md) {
                            ForEach(Array(viewModel.items.enumerated()), id: \.element.id) { index, item in
                                LeaderboardItemCard(
                                    item: item,
                                    rank: index + 1,
                                    viewModel: viewModel
                                )
                            }
                        }
                    }
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.vertical, AppSpacing.sm)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                NavigationLink(destination: SubmitLeaderboardItemView(leaderboardId: leaderboardId)) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(AppColors.primary)
                }
            }
        }
        .onAppear {
            viewModel.loadLeaderboard(leaderboardId: leaderboardId)
            viewModel.loadItems(leaderboardId: leaderboardId, sort: selectedSort)
        }
    }
}

// 排序按钮
struct SortButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundColor(isSelected ? .white : AppColors.textPrimary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? AppColors.primary : AppColors.cardBackground)
                .cornerRadius(AppCornerRadius.medium)
                .overlay(
                    RoundedRectangle(cornerRadius: AppCornerRadius.medium)
                        .stroke(isSelected ? Color.clear : AppColors.primary.opacity(0.3), lineWidth: 1)
                )
        }
    }
}

// 竞品卡片
struct LeaderboardItemCard: View {
    let item: LeaderboardItem
    let rank: Int
    let viewModel: LeaderboardDetailViewModel
    @State private var hasVoted = false
    @State private var voteType: String?
    @State private var upvotes: Int
    @State private var downvotes: Int
    @State private var netVotes: Int
    
    init(item: LeaderboardItem, rank: Int, viewModel: LeaderboardDetailViewModel) {
        self.item = item
        self.rank = rank
        self.viewModel = viewModel
        _upvotes = State(initialValue: item.upvotes)
        _downvotes = State(initialValue: item.downvotes)
        _netVotes = State(initialValue: item.netVotes)
    }
    
    var body: some View {
        HStack(spacing: AppSpacing.md) {
            // 排名
            ZStack {
                Circle()
                    .fill(
                        rank <= 3
                        ? LinearGradient(
                            gradient: Gradient(colors: [AppColors.warning, AppColors.warning.opacity(0.7)]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        : LinearGradient(
                            gradient: Gradient(colors: [AppColors.textSecondary.opacity(0.3), AppColors.textSecondary.opacity(0.1)]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 40, height: 40)
                
                Text("\(rank)")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(rank <= 3 ? .white : AppColors.textPrimary)
            }
            
            // 图片
            if let image = item.images?.first, !image.isEmpty {
                AsyncImage(url: URL(string: image)) { img in
                    img
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    RoundedRectangle(cornerRadius: AppCornerRadius.small)
                        .fill(AppColors.primaryLight)
                }
                .frame(width: 60, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: AppCornerRadius.small))
            }
            
            // 信息
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.headline)
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(1)
                
                if let description = item.description {
                    Text(description)
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)
                        .lineLimit(2)
                }
                
                HStack(spacing: 16) {
                    Label("👍 \(upvotes)", systemImage: "hand.thumbsup.fill")
                    Label("👎 \(downvotes)", systemImage: "hand.thumbsdown.fill")
                }
                .font(.caption)
                .foregroundColor(AppColors.textSecondary)
            }
            
            Spacer()
            
            // 投票按钮
            VStack(spacing: 8) {
                Button(action: {
                    let newVoteType = voteType == "upvote" ? "remove" : "upvote"
                    viewModel.voteItem(itemId: item.id, voteType: newVoteType) { success, up, down, net in
                        if success {
                            voteType = newVoteType == "remove" ? nil : "upvote"
                            upvotes = up
                            downvotes = down
                            netVotes = net
                        }
                    }
                }) {
                    Image(systemName: voteType == "upvote" ? "hand.thumbsup.fill" : "hand.thumbsup")
                        .foregroundColor(voteType == "upvote" ? AppColors.success : AppColors.textSecondary)
                }
                
                Button(action: {
                    let newVoteType = voteType == "downvote" ? "remove" : "downvote"
                    viewModel.voteItem(itemId: item.id, voteType: newVoteType) { success, up, down, net in
                        if success {
                            voteType = newVoteType == "remove" ? nil : "downvote"
                            upvotes = up
                            downvotes = down
                            netVotes = net
                        }
                    }
                }) {
                    Image(systemName: voteType == "downvote" ? "hand.thumbsdown.fill" : "hand.thumbsdown")
                        .foregroundColor(voteType == "downvote" ? AppColors.error : AppColors.textSecondary)
                }
            }
        }
        .padding(AppSpacing.md)
        .background(AppColors.cardBackground)
        .cornerRadius(AppCornerRadius.medium)
        .shadow(color: AppShadow.small.color, radius: AppShadow.small.radius, x: AppShadow.small.x, y: AppShadow.small.y)
    }
}

