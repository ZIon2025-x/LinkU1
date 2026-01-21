import SwiftUI

enum MyForumPostsTab: String, CaseIterable {
    case posted = "forum.my_posts.posted"
    case favorited = "forum.my_posts.favorited"
    case liked = "forum.my_posts.liked"
    
    var localizedTitle: String {
        switch self {
        case .posted: return LocalizationKey.forumMyPostsPosted.localized
        case .favorited: return LocalizationKey.forumMyPostsFavorited.localized
        case .liked: return LocalizationKey.forumMyPostsLiked.localized
        }
    }
    
    var icon: String {
        switch self {
        case .posted: return "doc.text.fill"
        case .favorited: return "star.fill"
        case .liked: return "heart.fill"
        }
    }
}

struct MyForumPostsView: View {
    @StateObject private var viewModel = ForumViewModel()
    @EnvironmentObject var appState: AppState
    @State private var selectedTab: MyForumPostsTab = .posted
    @State private var hasLoadedOnce = false
    
    var body: some View {
        ZStack {
            AppColors.background
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 标签选择器
                ForumPostsTabSelector(selectedTab: $selectedTab)
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.top, AppSpacing.sm)
                    .padding(.bottom, AppSpacing.md)
                
                // 内容区域 - 使用 TabView 支持滑动切换
                TabView(selection: $selectedTab) {
                    // 我发布的
                    postsContent(
                        posts: viewModel.myPosts,
                        isLoading: viewModel.isLoadingMyPosts,
                        errorMessage: viewModel.errorMessageMyPosts,
                        emptyMessage: LocalizationKey.forumMyPostsEmptyPosted.localized,
                        emptyIcon: "doc.text.fill"
                    )
                    .tag(MyForumPostsTab.posted)
                    
                    // 我收藏的
                    postsContent(
                        posts: viewModel.favoritedPosts,
                        isLoading: viewModel.isLoadingFavoritedPosts,
                        errorMessage: viewModel.errorMessageFavoritedPosts,
                        emptyMessage: LocalizationKey.forumMyPostsEmptyFavorited.localized,
                        emptyIcon: "star.fill"
                    )
                    .tag(MyForumPostsTab.favorited)
                    
                    // 我喜欢的
                    postsContent(
                        posts: viewModel.likedPosts,
                        isLoading: viewModel.isLoadingLikedPosts,
                        errorMessage: viewModel.errorMessageLikedPosts,
                        emptyMessage: LocalizationKey.forumMyPostsEmptyLiked.localized,
                        emptyIcon: "heart.fill"
                    )
                    .tag(MyForumPostsTab.liked)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: selectedTab)
                .onChange(of: selectedTab) { newTab in
                    // TabView 滑动时会触发此回调，确保数据已加载
                    if !hasDataForTab(newTab) {
                        loadDataForTab(newTab)
                    }
                }
            }
        }
        .navigationTitle(LocalizationKey.forumMyPosts.localized)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(AppColors.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .enableSwipeBack()
        .task {
            if !hasLoadedOnce {
                loadDataForCurrentTab()
                // 预加载相邻标签的数据
                preloadAdjacentTabs()
                hasLoadedOnce = true
            }
        }
        .onChange(of: selectedTab) { newTab in
            // 当切换标签时，加载当前标签数据并预加载相邻标签
            loadDataForTab(newTab)
            preloadAdjacentTabs(for: newTab)
            HapticFeedback.selection()
        }
        .refreshable {
            await loadDataForCurrentTabAsync(forceRefresh: true)
        }
        .onAppear {
            // 首次加载时已经通过task处理，这里只处理从详情页返回的情况
            // 如果数据为空，则加载
            let currentPosts = getCurrentPosts()
            if currentPosts.isEmpty && !hasLoadedOnce {
                loadDataForCurrentTab()
                preloadAdjacentTabs()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .forumPostUpdated)) { _ in
            // 当帖子状态更新时（喜欢/收藏），刷新当前标签页
            loadDataForCurrentTab(forceRefresh: true)
        }
    }
    
    @ViewBuilder
    private func postsContent(
        posts: [ForumPost],
        isLoading: Bool,
        errorMessage: String?,
        emptyMessage: String,
        emptyIcon: String
    ) -> some View {
        if let error = errorMessage, posts.isEmpty {
            // 错误状态
            VStack(spacing: AppSpacing.md) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 48))
                    .foregroundColor(AppColors.error.opacity(0.6))
                
                Text(LocalizationKey.forumLoadFailed.localized)
                    .font(AppTypography.title3)
                    .foregroundColor(AppColors.textPrimary)
                
                Text(error)
                    .font(AppTypography.body)
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacing.xl)
                
                Button(LocalizationKey.forumRetry.localized) {
                    loadDataForCurrentTab(forceRefresh: true)
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.top, AppSpacing.sm)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if isLoading && posts.isEmpty {
            // 使用列表骨架屏
            ScrollView {
                ListSkeleton(itemCount: 5, itemHeight: 100)
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.vertical, AppSpacing.sm)
            }
        } else if posts.isEmpty {
            EmptyStateView(
                icon: emptyIcon,
                title: LocalizationKey.forumNoPosts.localized,
                message: emptyMessage
            )
        } else {
            ScrollView {
                LazyVStack(spacing: AppSpacing.md) {
                    ForEach(Array(posts.enumerated()), id: \.element.id) { index, post in
                        NavigationLink(destination: ForumPostDetailView(postId: post.id)) {
                            PostCard(post: post)
                        }
                        .buttonStyle(ScaleButtonStyle())
                        .listItemAppear(index: index, totalItems: posts.count) // 添加错落入场动画
                    }
                }
                .padding(.horizontal, AppSpacing.md)
                .padding(.vertical, AppSpacing.sm)
            }
            .scrollIndicators(.hidden)
        }
    }
    
    private func loadDataForCurrentTab(forceRefresh: Bool = false) {
        loadDataForTab(selectedTab, forceRefresh: forceRefresh)
    }
    
    private func loadDataForTab(_ tab: MyForumPostsTab, forceRefresh: Bool = false) {
        // 如果数据已存在且不是强制刷新，则跳过加载
        switch tab {
        case .posted:
            if forceRefresh || (viewModel.myPosts.isEmpty && !viewModel.isLoadingMyPosts) {
                viewModel.loadMyPosts()
            }
        case .favorited:
            if forceRefresh || (viewModel.favoritedPosts.isEmpty && !viewModel.isLoadingFavoritedPosts) {
                viewModel.loadFavoritedPosts()
            }
        case .liked:
            if forceRefresh || (viewModel.likedPosts.isEmpty && !viewModel.isLoadingLikedPosts) {
                viewModel.loadLikedPosts()
            }
        }
    }
    
    private func hasDataForTab(_ tab: MyForumPostsTab) -> Bool {
        switch tab {
        case .posted:
            return !viewModel.myPosts.isEmpty
        case .favorited:
            return !viewModel.favoritedPosts.isEmpty
        case .liked:
            return !viewModel.likedPosts.isEmpty
        }
    }
    
    @MainActor
    private func loadDataForCurrentTabAsync(forceRefresh: Bool = false) async {
        switch selectedTab {
        case .posted:
            await viewModel.loadMyPostsAsync()
        case .favorited:
            await viewModel.loadFavoritedPostsAsync()
        case .liked:
            await viewModel.loadLikedPostsAsync()
        }
    }
    
    private func getCurrentPosts() -> [ForumPost] {
        switch selectedTab {
        case .posted:
            return viewModel.myPosts
        case .favorited:
            return viewModel.favoritedPosts
        case .liked:
            return viewModel.likedPosts
        }
    }
    
    // 预加载相邻标签的数据，提升用户体验
    private func preloadAdjacentTabs(for tab: MyForumPostsTab? = nil) {
        let currentTab = tab ?? selectedTab
        let allTabs = MyForumPostsTab.allCases
        guard let currentIndex = allTabs.firstIndex(of: currentTab) else { return }
        
        // 预加载下一个标签的数据
        if currentIndex < allTabs.count - 1 {
            let nextTab = allTabs[currentIndex + 1]
            preloadTabData(for: nextTab)
        }
        
        // 预加载上一个标签的数据
        if currentIndex > 0 {
            let previousTab = allTabs[currentIndex - 1]
            preloadTabData(for: previousTab)
        }
    }
    
    // 预加载指定标签的数据（如果尚未加载）
    private func preloadTabData(for tab: MyForumPostsTab) {
        switch tab {
        case .posted:
            if viewModel.myPosts.isEmpty && !viewModel.isLoadingMyPosts {
                viewModel.loadMyPosts()
            }
        case .favorited:
            if viewModel.favoritedPosts.isEmpty && !viewModel.isLoadingFavoritedPosts {
                viewModel.loadFavoritedPosts()
            }
        case .liked:
            if viewModel.likedPosts.isEmpty && !viewModel.isLoadingLikedPosts {
                viewModel.loadLikedPosts()
            }
        }
    }
}

// MARK: - 标签选择器

struct ForumPostsTabSelector: View {
    @Binding var selectedTab: MyForumPostsTab
    @Namespace private var animation
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(MyForumPostsTab.allCases, id: \.self) { tab in
                ForumPostsTabButton(
                    tab: tab,
                    isSelected: selectedTab == tab,
                    animation: animation
                ) {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                        HapticFeedback.selection()
                        selectedTab = tab
                    }
                }
            }
        }
        .padding(4)
        .background(AppColors.cardBackground)
        .cornerRadius(AppCornerRadius.large)
        .animation(.spring(response: 0.25, dampingFraction: 0.8), value: selectedTab)
    }
}

struct ForumPostsTabButton: View {
    let tab: MyForumPostsTab
    let isSelected: Bool
    var animation: Namespace.ID
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: tab.icon)
                    .font(.system(size: 12, weight: .medium))
                Text(tab.localizedTitle)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
            }
            .foregroundColor(isSelected ? .white : AppColors.textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: AppCornerRadius.medium)
                        .fill(AppColors.primary)
                        .matchedGeometryEffect(id: "tab", in: animation)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}
