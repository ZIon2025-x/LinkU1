import SwiftUI

enum MyForumPostsTab: String, CaseIterable {
    case posted = "我发布的"
    case favorited = "我收藏的"
    case liked = "我喜欢的"
    
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
                
                // 内容区域
                Group {
                    switch selectedTab {
                    case .posted:
                        postsContent(
                            posts: viewModel.myPosts,
                            isLoading: viewModel.isLoadingMyPosts,
                            errorMessage: viewModel.errorMessageMyPosts,
                            emptyMessage: "您还没有发布过帖子",
                            emptyIcon: "doc.text.fill"
                        )
                    case .favorited:
                        postsContent(
                            posts: viewModel.favoritedPosts,
                            isLoading: viewModel.isLoadingFavoritedPosts,
                            errorMessage: viewModel.errorMessageFavoritedPosts,
                            emptyMessage: "您还没有收藏过帖子",
                            emptyIcon: "star.fill"
                        )
                    case .liked:
                        postsContent(
                            posts: viewModel.likedPosts,
                            isLoading: viewModel.isLoadingLikedPosts,
                            errorMessage: viewModel.errorMessageLikedPosts,
                            emptyMessage: "您还没有喜欢过帖子",
                            emptyIcon: "heart.fill"
                        )
                    }
                }
            }
        }
        .navigationTitle("我的帖子")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(AppColors.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .enableSwipeBack()
        .task {
            if !hasLoadedOnce {
                loadDataForCurrentTab()
                hasLoadedOnce = true
            }
        }
        .onChange(of: selectedTab) { _ in
            loadDataForCurrentTab()
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
                
                Text("加载失败")
                    .font(AppTypography.title3)
                    .foregroundColor(AppColors.textPrimary)
                
                Text(error)
                    .font(AppTypography.body)
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacing.xl)
                
                Button("重试") {
                    loadDataForCurrentTab(forceRefresh: true)
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.top, AppSpacing.sm)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if isLoading && posts.isEmpty {
            LoadingView(message: LocalizationKey.commonLoading.localized)
        } else if posts.isEmpty {
            EmptyStateView(
                icon: emptyIcon,
                title: LocalizationKey.forumNoPosts.localized,
                message: emptyMessage
            )
        } else {
            ScrollView {
                LazyVStack(spacing: AppSpacing.md) {
                    ForEach(posts) { post in
                        NavigationLink(destination: ForumPostDetailView(postId: post.id)) {
                            PostCard(post: post)
                        }
                        .buttonStyle(ScaleButtonStyle())
                    }
                }
                .padding(.horizontal, AppSpacing.md)
                .padding(.vertical, AppSpacing.sm)
            }
        }
    }
    
    private func loadDataForCurrentTab(forceRefresh: Bool = false) {
        switch selectedTab {
        case .posted:
            if forceRefresh || viewModel.myPosts.isEmpty {
                viewModel.loadMyPosts()
            }
        case .favorited:
            if forceRefresh || viewModel.favoritedPosts.isEmpty {
                viewModel.loadFavoritedPosts()
            }
        case .liked:
            if forceRefresh || viewModel.likedPosts.isEmpty {
                viewModel.loadLikedPosts()
            }
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
                Text(tab.rawValue)
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
