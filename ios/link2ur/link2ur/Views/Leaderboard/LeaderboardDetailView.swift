import SwiftUI
import Combine

struct LeaderboardDetailView: View {
    let leaderboardId: Int
    @StateObject private var viewModel = LeaderboardDetailViewModel()
    @EnvironmentObject var appState: AppState
    @State private var selectedSort = "vote_score"
    @State private var showLogin = false
    @State private var showSubmitItem = false
    @State private var showShareSheet = false
    @State private var isTogglingFavorite = false
    
    var body: some View {
        ZStack {
            AppColors.background
                .ignoresSafeArea()
            
            if viewModel.isLoading && viewModel.leaderboard == nil {
                LoadingView(message: LocalizationKey.commonLoading.localized)
            } else if let leaderboard = viewModel.leaderboard {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        // 1. 顶部 Hero 区域 (封面图)
                        LeaderboardHeroSection(leaderboard: leaderboard)
                        
                        VStack(alignment: .leading, spacing: AppSpacing.lg) {
                            // 2. 描述内容
                            if let description = leaderboard.displayDescription, !description.isEmpty {
                                Text(description)
                                    .font(AppTypography.body)
                                    .foregroundColor(AppColors.textSecondary)
                                    .lineSpacing(4)
                                    .padding(.horizontal, AppSpacing.md)
                                    .padding(.top, AppSpacing.md)
                            }
                            
                            // 3. 统计数据栏
                            LeaderboardStatsBar(leaderboard: leaderboard)
                                .padding(.horizontal, AppSpacing.md)
                            
                            // 4. 排序过滤器
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: AppSpacing.sm) {
                                    SortButton(title: LocalizationKey.leaderboardSortComprehensive.localized, isSelected: selectedSort == "vote_score") {
                                        selectedSort = "vote_score"
                                        viewModel.loadItems(leaderboardId: leaderboardId, sort: selectedSort)
                                        HapticFeedback.selection()
                                    }
                                    SortButton(title: LocalizationKey.leaderboardSortNetVotes.localized, isSelected: selectedSort == "net_votes") {
                                        selectedSort = "net_votes"
                                        viewModel.loadItems(leaderboardId: leaderboardId, sort: selectedSort)
                                        HapticFeedback.selection()
                                    }
                                    SortButton(title: LocalizationKey.leaderboardSortUpvotes.localized, isSelected: selectedSort == "upvotes") {
                                        selectedSort = "upvotes"
                                        viewModel.loadItems(leaderboardId: leaderboardId, sort: selectedSort)
                                        HapticFeedback.selection()
                                    }
                                    SortButton(title: LocalizationKey.leaderboardSortLatest.localized, isSelected: selectedSort == "created_at") {
                                        selectedSort = "created_at"
                                        viewModel.loadItems(leaderboardId: leaderboardId, sort: selectedSort)
                                        HapticFeedback.selection()
                                    }
                                }
                                .padding(.horizontal, AppSpacing.md)
                            }
                            
                            // 5. 竞品列表
                            if viewModel.isLoading {
                                // 使用列表骨架屏
                                ListSkeleton(itemCount: 5, itemHeight: 120)
                                    .padding(.horizontal, AppSpacing.md)
                                    .padding(.top, AppSpacing.xl)
                            } else if viewModel.items.isEmpty {
                                EmptyStateView(icon: "tray", title: LocalizationKey.leaderboardNoItems.localized, message: LocalizationKey.leaderboardNoItemsMessage.localized)
                                    .frame(height: 300)
                            } else {
                                VStack(alignment: .leading, spacing: AppSpacing.md) {
                                    ForEach(Array(viewModel.items.enumerated()), id: \.element.id) { index, item in
                                        NavigationLink(destination: LeaderboardItemDetailView(itemId: item.id, leaderboardId: leaderboardId)) {
                                            LeaderboardItemCard(
                                                item: item,
                                                rank: index + 1,
                                                viewModel: viewModel
                                            )
                                        }
                                        .buttonStyle(ScaleButtonStyle())
                                        .environmentObject(appState)
                                        .listItemAppear(index: index, totalItems: viewModel.items.count) // 添加错落入场动画
                                    }
                                }
                                .padding(.horizontal, AppSpacing.md)
                            }
                        }
                        .padding(.bottom, AppSpacing.xxl)
                    }
                }
                .refreshable {
                    viewModel.loadLeaderboard(leaderboardId: leaderboardId, preserveLeaderboard: true)
                    viewModel.loadItems(leaderboardId: leaderboardId, sort: selectedSort)
                }
            } else {
                // 如果 leaderboard 为 nil 且不在加载中，显示错误状态（不应该发生，但作为保护）
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 48))
                        .foregroundColor(AppColors.textTertiary)
                    Text(LocalizationKey.leaderboardLoadFailed.localized)
                        .font(AppTypography.body)
                        .foregroundColor(AppColors.textSecondary)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .enableSwipeBack()
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    // 收藏/取消收藏（仅登录用户显示）
                    if appState.isAuthenticated {
                        Button(action: {
                            handleToggleFavorite()
                        }) {
                            Label(
                                (viewModel.leaderboard?.isFavorited ?? false) ? "取消收藏" : "收藏",
                                systemImage: (viewModel.leaderboard?.isFavorited ?? false) ? "star.fill" : "star"
                            )
                        }
                        .disabled(isTogglingFavorite)
                    }
                    
                    // 添加竞品
                    Button(action: {
                        if appState.isAuthenticated {
                            showSubmitItem = true
                            HapticFeedback.light()
                        } else {
                            showLogin = true
                        }
                    }) {
                        Label("添加竞品", systemImage: "plus.circle")
                    }
                    
                    // 分享
                    Button(action: {
                        showShareSheet = true
                        HapticFeedback.light()
                    }) {
                        Label("分享", systemImage: "square.and.arrow.up")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 20))
                        .foregroundColor(AppColors.textPrimary)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
            }
        }
        .sheet(isPresented: $showShareSheet) {
            if let leaderboard = viewModel.leaderboard {
                LeaderboardShareView(leaderboard: leaderboard, leaderboardId: leaderboardId)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
        }
        .sheet(isPresented: $showLogin) {
            LoginView()
        }
        .sheet(isPresented: $showSubmitItem) {
            SubmitLeaderboardItemView(leaderboardId: leaderboardId)
                .environmentObject(appState)
        }
        .onAppear {
            viewModel.loadLeaderboard(leaderboardId: leaderboardId)
            viewModel.loadItems(leaderboardId: leaderboardId, sort: selectedSort)
        }
    }
    
    private func handleToggleFavorite() {
        guard !isTogglingFavorite else { return }
        
        isTogglingFavorite = true
        HapticFeedback.light()
        
        viewModel.toggleLeaderboardFavorite(leaderboardId: leaderboardId) { success in
            DispatchQueue.main.async {
                isTogglingFavorite = false
                if success {
                    HapticFeedback.success()
                }
            }
        }
    }
}

// MARK: - Hero Section
struct LeaderboardHeroSection: View {
    let leaderboard: CustomLeaderboard
    
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // 背景图 - 使用 maxWidth 替代 UIScreen.main.bounds，避免弹窗出现时右侧和底部被裁切
            if let coverImage = leaderboard.coverImage, !coverImage.isEmpty {
                AsyncImageView(
                    urlString: coverImage,
                    placeholder: Image(systemName: "photo.fill")
                )
                .aspectRatio(contentMode: .fill)
                .frame(maxWidth: .infinity)
                .frame(height: 240)
                .clipped()
            } else {
                Rectangle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [AppColors.primary.opacity(0.8), AppColors.primary]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(maxWidth: .infinity)
                    .frame(height: 240)
            }
            
            // 渐变蒙层
            LinearGradient(
                gradient: Gradient(colors: [Color.black.opacity(0.6), Color.clear]),
                startPoint: .bottom,
                endPoint: .center
            )
            .frame(maxWidth: .infinity)
            .frame(height: 240)
            
            // 标题
            VStack(alignment: .leading, spacing: 4) {
                Text(leaderboard.displayName)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                    .shadow(color: Color.black.opacity(0.3), radius: 4, x: 0, y: 2)
            }
            .padding(AppSpacing.md)
            .padding(.bottom, 8) // 稍微上移一点，避免离底部太近
        }
        .frame(maxWidth: .infinity)
        .frame(height: 240)
    }
}

// MARK: - Stats Bar
struct LeaderboardStatsBar: View {
    let leaderboard: CustomLeaderboard
    
    var body: some View {
        HStack(spacing: 0) {
            LeaderboardStatItem(value: leaderboard.itemCount.formatCount(), label: LocalizationKey.leaderboardItemCount.localized, icon: "square.grid.2x2.fill", color: AppColors.primary)
            Divider().frame(height: 30).padding(.horizontal, AppSpacing.sm)
            LeaderboardStatItem(value: leaderboard.voteCount.formatCount(), label: LocalizationKey.leaderboardTotalVotes.localized, icon: "hand.thumbsup.fill", color: AppColors.warning)
            Divider().frame(height: 30).padding(.horizontal, AppSpacing.sm)
            LeaderboardStatItem(value: leaderboard.viewCount.formatCount(), label: LocalizationKey.leaderboardViewCount.localized, icon: "eye.fill", color: AppColors.textSecondary)
        }
        .padding(.vertical, AppSpacing.md)
        .background(AppColors.cardBackground)
        .cornerRadius(AppCornerRadius.large)
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)
    }
}

struct LeaderboardStatItem: View {
    let value: String
    let label: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                IconStyle.icon(icon, size: 12)
                    .foregroundColor(color)
                Text(value)
                    .font(AppTypography.bodyBold)
                    .foregroundColor(AppColors.textPrimary)
            }
            Text(label)
                .font(AppTypography.caption2)
                .foregroundColor(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
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
                .font(AppTypography.subheadline)
                .fontWeight(isSelected ? .bold : .medium)
                .foregroundColor(isSelected ? .white : AppColors.textPrimary)
                .padding(.horizontal, 18)
                .padding(.vertical, 8)
                .background(isSelected ? AppColors.primary : AppColors.cardBackground)
                .clipShape(Capsule())
                .shadow(color: isSelected ? AppColors.primary.opacity(0.3) : Color.clear, radius: 6, x: 0, y: 3)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// 竞品卡片
struct LeaderboardItemCard: View {
    let item: LeaderboardItem
    let rank: Int
    let viewModel: LeaderboardDetailViewModel
    @EnvironmentObject var appState: AppState
    @State private var voteType: String?
    @State private var upvotes: Int
    @State private var downvotes: Int
    @State private var netVotes: Int
    @State private var showLogin = false
    
    init(item: LeaderboardItem, rank: Int, viewModel: LeaderboardDetailViewModel) {
        self.item = item
        self.rank = rank
        self.viewModel = viewModel
        _upvotes = State(initialValue: item.upvotes)
        _downvotes = State(initialValue: item.downvotes)
        _netVotes = State(initialValue: item.netVotes)
        _voteType = State(initialValue: item.userVote)
    }
    
    var body: some View {
        HStack(spacing: AppSpacing.md) {
            // 1. 排名指示器
            ZStack {
                if rank <= 3 {
                    Circle()
                        .fill(rankColor(for: rank))
                        .frame(width: 36, height: 36)
                        .shadow(color: rankColor(for: rank).opacity(0.4), radius: 4, x: 0, y: 2)
                } else {
                    Circle()
                        .fill(AppColors.background)
                        .frame(width: 32, height: 32)
                }
                
                Text("\(rank)")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(rank <= 3 ? .white : AppColors.textSecondary)
            }
            
            // 2. 图片展示
            ZStack {
                if let image = item.images?.first, !image.isEmpty {
                    AsyncImageView(
                        urlString: image,
                        placeholder: Image(systemName: "photo.fill")
                    )
                    .frame(width: 64, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: AppCornerRadius.medium))
                } else {
                    RoundedRectangle(cornerRadius: AppCornerRadius.medium)
                        .fill(AppColors.primaryLight)
                        .frame(width: 64, height: 64)
                        .overlay(
                            IconStyle.icon("photo.fill", size: 24)
                                .foregroundColor(AppColors.primary.opacity(0.3))
                        )
                }
            }
            
            // 3. 详细内容
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(AppTypography.bodyBold)
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(1)
                
                if let description = item.description, !description.isEmpty {
                    Text(description)
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textSecondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                
                // 投票数据统计
                HStack(spacing: 12) {
                    HStack(spacing: 3) {
                        IconStyle.icon("hand.thumbsup.fill", size: 10)
                        Text("\(upvotes)")
                    }
                    .foregroundColor(voteType == "upvote" ? AppColors.success : AppColors.textTertiary)
                    
                    HStack(spacing: 3) {
                        IconStyle.icon("hand.thumbsdown.fill", size: 10)
                        Text("\(downvotes)")
                    }
                    .foregroundColor(voteType == "downvote" ? AppColors.error : AppColors.textTertiary)
                    
                    Text("·")
                        .foregroundColor(AppColors.textQuaternary)
                    
                    Text("\(netVotes) \(LocalizationKey.leaderboardNetScore.localized)")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(AppColors.textSecondary)
                }
                .font(.system(size: 11))
            }
            
            Spacer()
            
            // 4. 投票交互区
            VStack(spacing: 6) {
                VoteButton(
                    type: .upvote,
                    isSelected: voteType == "upvote",
                    action: { handleVote(newType: "upvote") }
                )
                
                VoteButton(
                    type: .downvote,
                    isSelected: voteType == "downvote",
                    action: { handleVote(newType: "downvote") }
                )
            }
        }
        .padding(AppSpacing.md)
        .background(AppColors.cardBackground)
        .cornerRadius(AppCornerRadius.large)
        .shadow(color: Color.black.opacity(0.03), radius: 8, x: 0, y: 4)
        .sheet(isPresented: $showLogin) {
            LoginView()
        }
    }
    
    private func rankColor(for rank: Int) -> Color {
        switch rank {
        case 1: return Color(red: 0.98, green: 0.78, blue: 0.25) // 金
        case 2: return Color(red: 0.75, green: 0.75, blue: 0.75) // 银
        case 3: return Color(red: 0.82, green: 0.53, blue: 0.35) // 铜
        default: return AppColors.textSecondary
        }
    }
    
    private func handleVote(newType: String) {
        if !appState.isAuthenticated {
            showLogin = true
            return
        }
        
        let typeToPost = voteType == newType ? "remove" : newType
        
        // 触发触感反馈
        if typeToPost == "remove" {
            HapticFeedback.light()
        } else {
            HapticFeedback.success()
        }
        
        viewModel.voteItem(itemId: item.id, voteType: typeToPost) { success, up, down, net in
            if success {
                voteType = typeToPost == "remove" ? nil : newType
                upvotes = up
                downvotes = down
                netVotes = net
            }
        }
    }
}

struct VoteButton: View {
    enum VoteType {
        case upvote, downvote
    }
    
    let type: VoteType
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(isSelected ? (type == .upvote ? AppColors.success.opacity(0.15) : AppColors.error.opacity(0.15)) : AppColors.background)
                    .frame(width: 32, height: 32)
                
                IconStyle.icon(
                    type == .upvote ? (isSelected ? "hand.thumbsup.fill" : "hand.thumbsup") : (isSelected ? "hand.thumbsdown.fill" : "hand.thumbsdown"),
                    size: 14
                )
                .foregroundColor(isSelected ? (type == .upvote ? AppColors.success : AppColors.error) : AppColors.textSecondary)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - 排行榜分享视图
struct LeaderboardShareView: View {
    let leaderboard: CustomLeaderboard
    let leaderboardId: Int
    @Environment(\.dismiss) var dismiss
    @State private var shareImage: UIImage?
    @State private var isLoadingImage = false
    @State private var imageCancellable: AnyCancellable?
    
    // 使用前端网页 URL，确保微信能抓取到正确的 meta 标签
    private var shareUrl: URL {
        let urlString = "https://www.link2ur.com/zh/leaderboard/custom/\(leaderboardId)?v=2"
        if let url = URL(string: urlString) {
            return url
        }
        return URL(string: "https://www.link2ur.com")!
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
                } else if isLoadingImage {
                    RoundedRectangle(cornerRadius: AppCornerRadius.medium)
                        .fill(AppColors.background)
                        .frame(height: 150)
                        .overlay(ProgressView())
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
                            IconStyle.icon("trophy.fill", size: 40)
                                .foregroundColor(.white.opacity(0.8))
                        )
                }
                
                // 标题和描述
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text(leaderboard.displayName)
                        .font(AppTypography.bodyBold)
                        .foregroundColor(AppColors.textPrimary)
                        .lineLimit(2)
                    
                    if let description = leaderboard.displayDescription, !description.isEmpty {
                        Text(description)
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.textSecondary)
                            .lineLimit(2)
                    }
                    
                    // 统计信息
                    HStack(spacing: AppSpacing.md) {
                        Label("\(leaderboard.itemCount) 竞品", systemImage: "square.grid.2x2")
                        Label("\(leaderboard.voteCount) 投票", systemImage: "hand.thumbsup")
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
            
            // 自定义分享面板
            CustomSharePanel(
                title: getShareTitle(for: leaderboard),
                description: getShareDescription(for: leaderboard),
                url: shareUrl,
                image: shareImage,
                taskType: nil,
                location: leaderboard.location,
                reward: nil,
                onDismiss: {
                    dismiss()
                }
            )
            .padding(.top, AppSpacing.md)
        }
        .background(AppColors.background)
        .onAppear {
            loadCoverImage()
        }
    }
    
    private func loadCoverImage() {
        guard let coverUrl = leaderboard.coverImage, !coverUrl.isEmpty else { return }
        
        // 取消之前的加载
        imageCancellable?.cancel()
        
        isLoadingImage = true
        
        // 使用 ImageCache 加载图片，支持缓存和优化
        imageCancellable = ImageCache.shared.loadImage(from: coverUrl)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { _ in
                    isLoadingImage = false
                },
                receiveValue: { image in
                    isLoadingImage = false
                    shareImage = image
                }
            )
    }
    
    /// 获取分享标题
    private func getShareTitle(for leaderboard: CustomLeaderboard) -> String {
        let trimmedName = leaderboard.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedName.isEmpty {
            return "排行榜"
        }
        return trimmedName
    }
    
    /// 获取分享描述
    private func getShareDescription(for leaderboard: CustomLeaderboard) -> String {
        if let description = leaderboard.displayDescription, !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            // 限制长度
            let maxLength = 200
            if description.count > maxLength {
                return String(description.prefix(maxLength)) + "..."
            }
            return description
        } else {
            // 如果没有描述，使用统计信息构建
            let statsText = "\(leaderboard.itemCount) 竞品 · \(leaderboard.voteCount) 投票"
            if let location = leaderboard.location, !location.isEmpty {
                return "\(location) | \(statsText)"
            }
            return "来 Link²Ur 看看这个排行榜 | \(statsText)"
        }
    }
}

// MARK: - 自定义分享内容提供者
import LinkPresentation

class LeaderboardShareItem: NSObject, UIActivityItemSource {
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
    
    // 占位符
    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        return url
    }
    
    // 实际分享的内容 - 根据不同的分享目标返回不同内容
    func activityViewController(_ activityViewController: UIActivityViewController, itemForActivityType activityType: UIActivity.ActivityType?) -> Any? {
        // 对于复制或短信等，返回包含链接的文本
        if activityType == .copyToPasteboard || activityType == .message {
            let shareText = """
            \(title)
            
            \(descriptionText.prefix(100))\(descriptionText.count > 100 ? "..." : "")
            
            👉 查看详情: \(url.absoluteString)
            """
            return shareText
        }
        
        // 其他情况返回 URL
        return url
    }
    
    // 提供富链接预览元数据（用于 iMessage 等原生 App）
    func activityViewControllerLinkMetadata(_ activityViewController: UIActivityViewController) -> LPLinkMetadata? {
        let metadata = LPLinkMetadata()
        
        // 重要：不设置 url 或 originalURL，避免系统尝试自动获取元数据
        // 设置这些属性会导致系统尝试访问URL获取元数据，从而触发沙盒扩展错误
        // 系统会自动从 activityViewController 返回的 URL 中识别链接信息
        // 我们只提供手动设置的元数据（title 和 image），避免网络请求
        
        // 设置标题
        metadata.title = title
        
        // 如果有图片，设置为预览图
        if let image = image {
            metadata.imageProvider = NSItemProvider(object: image)
            metadata.iconProvider = NSItemProvider(object: image)
        }
        
        return metadata
    }
    
    // 分享主题
    func activityViewController(_ activityViewController: UIActivityViewController, subjectForActivityType activityType: UIActivity.ActivityType?) -> String {
        return title
    }
}

// MARK: - 排行榜图片分享项（用于微信等需要图片的场景）
class LeaderboardImageShareItem: NSObject, UIActivityItemSource {
    let image: UIImage
    
    init(image: UIImage) {
        self.image = image
        super.init()
    }
    
    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        return image
    }
    
    func activityViewController(_ activityViewController: UIActivityViewController, itemForActivityType activityType: UIActivity.ActivityType?) -> Any? {
        return image
    }
}
