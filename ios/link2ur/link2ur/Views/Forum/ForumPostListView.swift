import SwiftUI

struct ForumPostListView: View {
    let category: ForumCategory?
    @StateObject private var viewModel = ForumViewModel()
    @EnvironmentObject var appState: AppState
    @State private var searchText = ""
    @State private var showCreatePost = false
    @State private var showLogin = false
    @State private var searchTask: DispatchWorkItem?
    @State private var isFavorited: Bool?
    @State private var isTogglingFavorite = false
    
    var body: some View {
        ZStack {
            AppColors.background
                .ignoresSafeArea()
            
            if viewModel.isLoading && viewModel.posts.isEmpty {
                // 使用列表骨架屏
                ScrollView {
                    ListSkeleton(itemCount: 5, itemHeight: 100)
                        .padding(.horizontal, AppSpacing.md)
                        .padding(.vertical, AppSpacing.sm)
                }
            } else if viewModel.posts.isEmpty {
                EmptyStateView(
                    icon: "doc.text.magnifyingglass",
                    title: LocalizationKey.forumNoPosts.localized,
                    message: LocalizationKey.forumNoPostsMessage.localized
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: AppSpacing.md) {
                        ForEach(Array(viewModel.posts.enumerated()), id: \.element.id) { index, post in
                            NavigationLink(destination: ForumPostDetailView(postId: post.id)) {
                                PostCard(post: post)
                            }
                            .buttonStyle(ScaleButtonStyle())
                            .listItemAppear(index: index, totalItems: viewModel.posts.count) // 添加错落入场动画
                        }
                    }
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.vertical, AppSpacing.sm)
                }
                .scrollContentBackground(.hidden)
            }
        }
        .navigationTitle(category?.displayName ?? LocalizationKey.forumAllPosts.localized)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(AppColors.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .enableSwipeBack()
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: LocalizationKey.forumSearchPosts.localized)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 12) {
                    // 收藏按钮（仅登录用户显示，且必须有category）
                    if appState.isAuthenticated, category?.id != nil {
                        Button(action: {
                            handleToggleFavorite()
                        }) {
                            Image(systemName: (isFavorited ?? category?.isFavorited ?? false) ? "star.fill" : "star")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor((isFavorited ?? category?.isFavorited ?? false) ? .yellow : AppColors.textTertiary)
                        }
                        .disabled(isTogglingFavorite)
                        .opacity(isTogglingFavorite ? 0.6 : 1.0)
                    }
                    
                    // 加号按钮
                    Button(action: {
                        if appState.isAuthenticated {
                            showCreatePost = true
                        } else {
                            showLogin = true
                        }
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(AppColors.primary)
                    }
                }
            }
        }
        .sheet(isPresented: $showCreatePost) {
            CreatePostView()
        }
        .sheet(isPresented: $showLogin) {
            LoginView()
        }
        .refreshable {
            let keyword = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            // 确保始终传递 categoryId，限制在当前板块
            viewModel.loadPosts(
                categoryId: category?.id,
                keyword: keyword.isEmpty ? nil : keyword,
                forceRefresh: true
            )
        }
        .task {
            // 使用 task 替代 onAppear，避免重复加载
            if viewModel.posts.isEmpty && !viewModel.isLoading {
                // 确保传递 categoryId，限制在当前板块
                viewModel.loadPosts(categoryId: category?.id)
            }
        }
        .onChange(of: searchText) { newValue in
            // 取消之前的搜索任务
            searchTask?.cancel()
            
            // 创建新的搜索任务（防抖）
            let keyword = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            let workItem = DispatchWorkItem {
                // 确保始终传递 categoryId，即使搜索也要限制在当前板块
                // 这样搜索时只会搜索当前板块的帖子，不会搜索所有板块
                viewModel.loadPosts(
                    categoryId: category?.id,  // 始终传递 categoryId，限制在当前板块
                    keyword: keyword.isEmpty ? nil : keyword,
                    forceRefresh: true
                )
            }
            searchTask = workItem
            
            // 延迟500ms执行搜索
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: workItem)
        }
        .onAppear {
            // 初始化收藏状态
            if let category = category {
                isFavorited = category.isFavorited
            }
        }
    }
    
    private func handleToggleFavorite() {
        guard let categoryId = category?.id, !isTogglingFavorite else { return }
        
        isTogglingFavorite = true
        HapticFeedback.light()
        
        viewModel.toggleCategoryFavorite(categoryId: categoryId) { success in
            DispatchQueue.main.async {
                isTogglingFavorite = false
                if success {
                    // 切换收藏状态
                    isFavorited = !(isFavorited ?? category?.isFavorited ?? false)
                    HapticFeedback.success()
                }
            }
        }
    }
}

// 帖子卡片 - 现代简洁设计
struct PostCard: View {
    let post: ForumPost
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            // 顶部：标签和标题
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                // 标签行（更紧凑）
                HStack(spacing: AppSpacing.xs) {
                    if post.isPinned {
                        BadgeView(text: LocalizationKey.postPinned.localized, icon: "pin.fill", color: AppColors.error)
                    }
                    if post.isFeatured {
                        BadgeView(text: LocalizationKey.postFeatured.localized, icon: "star.fill", color: AppColors.warning)
                    }
                    if post.isLocked {
                        IconStyle.icon("lock.fill", size: 10, weight: .medium)
                            .foregroundColor(AppColors.textTertiary)
                    }
                }
                
                // 标题
                Text(post.displayTitle)
                    .font(AppTypography.bodyBold)
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            // 内容预览
            if let preview = post.displayContentPreview, !preview.isEmpty {
                Text(preview)
                    .font(AppTypography.subheadline)
                    .foregroundColor(AppColors.textSecondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            
            // 底部信息栏 - 更通透的排版
            HStack(spacing: 0) {
                // 作者信息
                if let author = post.author {
                    NavigationLink(destination: userProfileDestination(user: author)) {
                        HStack(spacing: 6) {
                            // 优化：官方账号使用 Logo 图片作为头像
                            if author.isAdmin == true {
                                Image("Logo")
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 20, height: 20)
                                    .clipShape(Circle())
                            } else {
                                AvatarView(
                                    urlString: author.avatar,
                                    size: 20,
                                    placeholder: Image(systemName: "person.circle.fill")
                                )
                                .clipShape(Circle())
                            }
                            
                            Text(author.name)
                                .font(AppTypography.caption)
                                .foregroundColor(AppColors.textSecondary)
                                .lineLimit(1)
                            
                            if author.isAdmin == true {
                                Text(LocalizationKey.postOfficial.localized)
                                    .font(AppTypography.caption2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(AppColors.primary)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                Spacer(minLength: 12)
                
                // 统计信息
                HStack(spacing: 12) {
                    CompactStatItem(icon: "eye", count: post.viewCount)
                    CompactStatItem(icon: "bubble.right", count: post.replyCount)
                    CompactStatItem(
                        icon: "heart",
                        count: post.likeCount,
                        isActive: post.isLiked ?? false,
                        activeColor: AppColors.error
                    )
                    if post.isFavorited == true {
                        CompactStatItem(
                            icon: "star",
                            count: post.favoriteCount,
                            isActive: true,
                            activeColor: AppColors.warning
                        )
                    }
                }
            }
            .padding(.top, 4)
        }
        .padding(AppSpacing.md)
        .background(AppColors.cardBackground)
        .cornerRadius(AppCornerRadius.large)
        .shadow(color: AppShadow.small.color, radius: AppShadow.small.radius, x: AppShadow.small.x, y: AppShadow.small.y)
    }
    
    private func formatTime(_ timeString: String) -> String {
        return DateFormatterHelper.shared.formatTime(timeString)
    }
}


