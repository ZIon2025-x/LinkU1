import SwiftUI

struct ForumPostDetailView: View {
    let postId: Int
    @StateObject private var viewModel = ForumPostDetailViewModel()
    @State private var isLiked = false
    @State private var isFavorited = false
    @State private var likeCount = 0
    
    var body: some View {
        ZStack {
            AppColors.background
                .ignoresSafeArea()
            
            if viewModel.isLoading && viewModel.post == nil {
                ProgressView()
            } else if let post = viewModel.post {
                ScrollView {
                    VStack(alignment: .leading, spacing: AppSpacing.lg) {
                        // 帖子内容
                        VStack(alignment: .leading, spacing: AppSpacing.md) {
                            // 标题和标签
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 8) {
                                    if post.isPinned {
                                        Label("置顶", systemImage: "pin.fill")
                                            .font(.caption)
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(AppColors.error)
                                            .cornerRadius(6)
                                    }
                                    
                                    if post.isFeatured {
                                        Label("精华", systemImage: "star.fill")
                                            .font(.caption)
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(AppColors.warning)
                                            .cornerRadius(6)
                                    }
                                }
                                
                                Text(post.title)
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(AppColors.textPrimary)
                            }
                            
                            // 作者信息
                            if let author = post.author {
                                HStack(spacing: 12) {
                                    AsyncImage(url: URL(string: author.avatar ?? "")) { image in
                                        image
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                    } placeholder: {
                                        Image(systemName: "person.circle.fill")
                                            .foregroundColor(AppColors.textSecondary)
                                    }
                                    .frame(width: 40, height: 40)
                                    .clipShape(Circle())
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(author.username ?? "匿名")
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                        Text(formatTime(post.createdAt))
                                            .font(.caption)
                                            .foregroundColor(AppColors.textSecondary)
                                    }
                                    
                                    Spacer()
                                }
                            }
                            
                            Divider()
                            
                            // 内容
                            if let content = post.content {
                                Text(content)
                                    .font(.body)
                                    .foregroundColor(AppColors.textPrimary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            
                            // 统计信息
                            HStack(spacing: 24) {
                                Label("\(post.viewCount)", systemImage: "eye")
                                Label("\(post.replyCount)", systemImage: "bubble.right")
                                Label("\(likeCount)", systemImage: isLiked ? "heart.fill" : "heart")
                                    .foregroundColor(isLiked ? AppColors.error : AppColors.textSecondary)
                            }
                            .font(.subheadline)
                            .foregroundColor(AppColors.textSecondary)
                        }
                        .padding(AppSpacing.md)
                        .background(AppColors.cardBackground)
                        .cornerRadius(AppCornerRadius.medium)
                        .shadow(color: AppShadow.small.color, radius: AppShadow.small.radius, x: AppShadow.small.x, y: AppShadow.small.y)
                        
                        // 操作按钮
                        HStack(spacing: AppSpacing.md) {
                            Button(action: {
                                viewModel.toggleLike(targetType: "post", targetId: post.id) { liked, count in
                                    isLiked = liked
                                    likeCount = count
                                }
                            }) {
                                HStack {
                                    Image(systemName: isLiked ? "heart.fill" : "heart")
                                    Text("\(likeCount)")
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(isLiked ? AppColors.error.opacity(0.1) : AppColors.primaryLight)
                                .foregroundColor(isLiked ? AppColors.error : AppColors.primary)
                                .cornerRadius(AppCornerRadius.medium)
                            }
                            
                            Button(action: {
                                viewModel.toggleFavorite(postId: post.id) { favorited in
                                    isFavorited = favorited
                                }
                            }) {
                                HStack {
                                    Image(systemName: isFavorited ? "star.fill" : "star")
                                    Text("收藏")
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(isFavorited ? AppColors.warning.opacity(0.1) : AppColors.primaryLight)
                                .foregroundColor(isFavorited ? AppColors.warning : AppColors.primary)
                                .cornerRadius(AppCornerRadius.medium)
                            }
                        }
                        .padding(.horizontal, AppSpacing.md)
                        
                        // 回复列表
                        VStack(alignment: .leading, spacing: AppSpacing.md) {
                            Text("回复 (\(post.replyCount))")
                                .font(.headline)
                                .padding(.horizontal, AppSpacing.md)
                            
                            ForEach(viewModel.replies) { reply in
                                ReplyCard(reply: reply, postId: postId)
                            }
                        }
                        .padding(.top, AppSpacing.md)
                    }
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.vertical, AppSpacing.sm)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.loadPost(postId: postId)
            viewModel.loadReplies(postId: postId)
            if let post = viewModel.post {
                likeCount = post.likeCount
            }
        }
    }
    
    private func formatTime(_ timeString: String) -> String {
        return DateFormatterHelper.shared.formatTime(timeString)
    }
}

// 回复卡片
struct ReplyCard: View {
    let reply: ForumReply
    let postId: Int
    @StateObject private var viewModel = ForumPostDetailViewModel()
    @State private var isLiked = false
    @State private var likeCount: Int
    @State private var showReplySheet = false
    @State private var replyContent = ""
    
    init(reply: ForumReply, postId: Int) {
        self.reply = reply
        self.postId = postId
        _likeCount = State(initialValue: reply.likeCount)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 作者信息
            if let author = reply.author {
                HStack {
                    AsyncImage(url: URL(string: author.avatar ?? "")) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Image(systemName: "person.circle.fill")
                            .foregroundColor(AppColors.textSecondary)
                    }
                    .frame(width: 32, height: 32)
                    .clipShape(Circle())
                    
                    Text(author.username ?? "匿名")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    Text(formatTime(reply.createdAt))
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)
                }
            }
            
            // 回复内容
            Text(reply.content)
                .font(.body)
                .foregroundColor(AppColors.textPrimary)
            
            // 操作按钮
            HStack {
                Button(action: {
                    viewModel.likeReply(replyId: reply.id) { liked, count in
                        isLiked = liked
                        likeCount = count
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: isLiked ? "heart.fill" : "heart")
                        Text("\(likeCount)")
                    }
                    .font(.caption)
                    .foregroundColor(isLiked ? AppColors.error : AppColors.textSecondary)
                }
                
                Button(action: {
                    showReplySheet = true
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrowshape.turn.up.left")
                        Text("回复")
                    }
                    .font(.caption)
                    .foregroundColor(AppColors.primary)
                }
            }
            .sheet(isPresented: $showReplySheet) {
                ReplySheet(
                    content: $replyContent,
                    onReply: {
                        viewModel.replyToPost(postId: postId, content: replyContent, parentReplyId: reply.id) { success in
                            if success {
                                showReplySheet = false
                                replyContent = ""
                            }
                        }
                    }
                )
            }
            
            // 子回复
            if let replies = reply.replies, !replies.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(replies) { subReply in
                        ReplyCard(reply: subReply, postId: postId)
                            .padding(.leading, AppSpacing.md)
                    }
                }
                .padding(.leading, AppSpacing.md)
                .padding(.top, AppSpacing.sm)
            }
        }
        .padding(AppSpacing.md)
        .background(AppColors.cardBackground)
        .cornerRadius(AppCornerRadius.medium)
        .padding(.horizontal, AppSpacing.md)
    }
    
    private func formatTime(_ timeString: String) -> String {
        return DateFormatterHelper.shared.formatTime(timeString)
    }
}

// 回复弹窗
struct ReplySheet: View {
    @Binding var content: String
    let onReply: () -> Void
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: AppSpacing.lg) {
                TextEditor(text: $content)
                    .frame(height: 150)
                    .padding(8)
                    .background(AppColors.cardBackground)
                    .cornerRadius(AppCornerRadius.medium)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppCornerRadius.medium)
                            .stroke(AppColors.primary.opacity(0.2), lineWidth: 1)
                    )
                
                Button(action: {
                    onReply()
                }) {
                    Text("发布回复")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .foregroundColor(.white)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [AppColors.primary, AppColors.primary.opacity(0.8)]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(AppCornerRadius.medium)
                }
                .disabled(content.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(AppSpacing.md)
            .navigationTitle("回复")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
        }
    }
}

