import SwiftUI

struct ForumPostListView: View {
    let category: ForumCategory?
    @StateObject private var viewModel = ForumViewModel()
    @EnvironmentObject var appState: AppState
    @State private var searchText = ""
    @State private var showCreatePost = false
    @State private var showLogin = false
    
    var body: some View {
        ZStack {
            AppColors.background
                .ignoresSafeArea()
            
            if viewModel.isLoading && viewModel.posts.isEmpty {
                ProgressView()
            } else if viewModel.posts.isEmpty {
                EmptyStateView(
                    icon: "doc.text.magnifyingglass",
                    title: "暂无帖子",
                    message: "这个板块还没有帖子，快来发布第一个吧！"
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: AppSpacing.md) {
                        ForEach(viewModel.posts) { post in
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
        .navigationTitle(category?.name ?? "全部帖子")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(AppColors.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        // 确保边缘滑动手势正常工作（NavigationStack 默认支持）
        .searchable(text: $searchText, prompt: "搜索帖子")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
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
        .sheet(isPresented: $showCreatePost) {
            CreatePostView()
        }
        .sheet(isPresented: $showLogin) {
            LoginView()
        }
        .refreshable {
            viewModel.loadPosts(categoryId: category?.id, forceRefresh: true)
        }
        .onAppear {
            viewModel.loadPosts(categoryId: category?.id)
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
                        BadgeView(text: "置顶", icon: "flame.fill", color: AppColors.error)
                    }
                    if post.isFeatured {
                        BadgeView(text: "精华", icon: "star.fill", color: AppColors.warning)
                    }
                    if post.isLocked {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(AppColors.textTertiary)
                    }
                }
                
                // 标题
                Text(post.title)
                    .font(AppTypography.body)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            // 内容预览
            if let preview = post.contentPreview, !preview.isEmpty {
                Text(preview)
                    .font(AppTypography.subheadline)
                    .foregroundColor(AppColors.textSecondary)
                    .lineLimit(2)
            }
            
            // 底部信息栏（更简洁）
            HStack(spacing: AppSpacing.sm) {
                // 作者信息（限制宽度，避免占用太多空间）
                if let author = post.author {
                    NavigationLink(destination: UserProfileView(userId: author.id)) {
                        HStack(spacing: AppSpacing.xs) {
                            AvatarView(
                                urlString: author.avatar,
                                size: 18,
                                placeholder: Image(systemName: "person.circle.fill")
                            )
                            
                            Text(author.name)
                                .font(AppTypography.caption)
                                .foregroundColor(AppColors.textSecondary)
                                .lineLimit(1)
                            
                            // 官方标识（参考前端：蓝色 Tag）
                            if author.isAdmin == true {
                                Text("官方")
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 2)
                                    .background(AppColors.primary)
                                    .cornerRadius(AppCornerRadius.tiny)
                            }
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    .layoutPriority(1) // 作者信息优先级较低
                }
                
                Spacer(minLength: 8) // 最小间距
                
                // 时间（限制最大宽度）
                Text(formatTime(post.lastReplyAt ?? post.createdAt))
                    .font(AppTypography.caption2)
                    .foregroundColor(AppColors.textTertiary)
                    .lineLimit(1)
                    .layoutPriority(2) // 时间优先级中等
                
                // 统计信息（紧凑布局，确保不被遮挡）
                HStack(spacing: AppSpacing.sm) {
                    CompactStatItem(icon: "eye", count: post.viewCount)
                    CompactStatItem(icon: "bubble.right", count: post.replyCount)
                    CompactStatItem(icon: "heart", count: post.likeCount)
                }
                .layoutPriority(3) // 统计信息优先级最高，确保不被遮挡
            }
        }
        .padding(AppSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.cardBackground)
        .cornerRadius(AppCornerRadius.medium)
        .overlay(
            RoundedRectangle(cornerRadius: AppCornerRadius.medium)
                .stroke(AppColors.divider, lineWidth: 0.5)
        )
    }
    
    private func formatTime(_ timeString: String) -> String {
        return DateFormatterHelper.shared.formatTime(timeString)
    }
}

// 紧凑统计项组件
struct CompactStatItem: View {
    let icon: String
    let count: Int
    
    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .medium))
                .frame(width: 12) // 固定图标宽度，避免布局抖动
            Text(count.formatCount())
                .font(.system(size: 11))
                .lineLimit(1) // 确保文本不换行
                .minimumScaleFactor(0.8) // 如果空间不足，稍微缩小字体
        }
        .foregroundColor(AppColors.textTertiary)
    }
}


