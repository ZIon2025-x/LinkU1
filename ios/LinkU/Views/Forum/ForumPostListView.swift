import SwiftUI

struct ForumPostListView: View {
    let category: ForumCategory?
    @StateObject private var viewModel = ForumViewModel()
    @State private var searchText = ""
    
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
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.vertical, AppSpacing.sm)
                }
            }
        }
        .navigationTitle(category?.name ?? "全部帖子")
        .searchable(text: $searchText, prompt: "搜索帖子")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    NavigationLink(destination: CreatePostView()) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(AppColors.primary)
                    }
                }) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(AppColors.primary)
                }
            }
        }
        .refreshable {
            viewModel.loadPosts(categoryId: category?.id)
        }
        .onAppear {
            viewModel.loadPosts(categoryId: category?.id)
        }
    }
}

// 帖子卡片
struct PostCard: View {
    let post: ForumPost
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 标题和标签
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        if post.isPinned {
                            Label("置顶", systemImage: "pin.fill")
                                .font(.caption)
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(AppColors.error)
                                .cornerRadius(4)
                        }
                        
                        if post.isFeatured {
                            Label("精华", systemImage: "star.fill")
                                .font(.caption)
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(AppColors.warning)
                                .cornerRadius(4)
                        }
                        
                        if post.isLocked {
                            Image(systemName: "lock.fill")
                                .font(.caption)
                                .foregroundColor(AppColors.textSecondary)
                        }
                    }
                    
                    Text(post.displayTitle)
                        .font(.headline)
                        .foregroundColor(AppColors.textPrimary)
                        .lineLimit(2)
                }
                
                Spacer()
            }
            
            // 内容预览
            if let preview = post.displayContentPreview {
                Text(preview)
                    .font(.subheadline)
                    .foregroundColor(AppColors.textSecondary)
                    .lineLimit(2)
            }
            
            // 作者和统计
            HStack {
                if let author = post.author {
                    HStack(spacing: 4) {
                        AsyncImage(url: URL(string: author.avatar ?? "")) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Image(systemName: "person.circle.fill")
                                .foregroundColor(AppColors.textSecondary)
                        }
                        .frame(width: 20, height: 20)
                        .clipShape(Circle())
                        
                        Text(author.username ?? "匿名")
                            .font(.caption)
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
                
                Spacer()
                
                HStack(spacing: 16) {
                    Label("\(post.viewCount)", systemImage: "eye")
                    Label("\(post.replyCount)", systemImage: "bubble.right")
                    Label("\(post.likeCount)", systemImage: "heart")
                }
                .font(.caption)
                .foregroundColor(AppColors.textSecondary)
            }
        }
        .padding(AppSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.cardBackground)
        .cornerRadius(AppCornerRadius.medium)
        .shadow(color: AppShadow.small.color, radius: AppShadow.small.radius, x: AppShadow.small.x, y: AppShadow.small.y)
    }
}

