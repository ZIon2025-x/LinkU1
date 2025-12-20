import SwiftUI

struct ForumPostDetailView: View {
    let postId: Int
    @StateObject private var viewModel = ForumPostDetailViewModel()
    @EnvironmentObject var appState: AppState
    @State private var isLiked = false
    @State private var isFavorited = false
    @State private var likeCount = 0
    @State private var favoriteCount = 0
    @State private var showLogin = false
    
    var body: some View {
        ZStack {
            AppColors.background
                .ignoresSafeArea()
            
            if viewModel.isLoading && viewModel.post == nil {
                ProgressView()
            } else if let post = viewModel.post {
                KeyboardAvoidingScrollView(extraPadding: 20) {
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
                                NavigationLink(destination: UserProfileView(userId: author.id)) {
                                    HStack(spacing: 12) {
                                        AvatarView(
                                            urlString: author.avatar,
                                            size: 40,
                                            placeholder: Image(systemName: "person.circle.fill")
                                        )
                                        
                                        VStack(alignment: .leading, spacing: 2) {
                                            HStack(spacing: 6) {
                                                Text(author.name)
                                                    .font(.subheadline)
                                                    .fontWeight(.medium)
                                                    .foregroundColor(AppColors.textPrimary)
                                                
                                                // 官方标识（参考前端：蓝色 Tag）
                                                if author.isAdmin == true {
                                                    Text(LocalizationKey.forumOfficial.localized)
                                                        .font(.system(size: 11, weight: .semibold))
                                                        .foregroundColor(.white)
                                                        .padding(.horizontal, 6)
                                                        .padding(.vertical, 2)
                                                        .background(AppColors.primary)
                                                        .cornerRadius(4)
                                                }
                                            }
                                            
                                            Text(formatTime(post.createdAt))
                                                .font(.caption)
                                                .foregroundColor(AppColors.textSecondary)
                                        }
                                        
                                        Spacer()
                                    }
                                }
                                .buttonStyle(PlainButtonStyle())
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
                            HStack(spacing: 20) {
                                HStack(spacing: 4) {
                                    Image(systemName: "eye")
                                        .font(.system(size: 14))
                                    Text(post.viewCount.formatCount())
                                        .font(AppTypography.subheadline)
                                }
                                .foregroundColor(AppColors.textSecondary)
                                
                                HStack(spacing: 4) {
                                    Image(systemName: "bubble.right")
                                        .font(.system(size: 14))
                                    Text(post.replyCount.formatCount())
                                        .font(AppTypography.subheadline)
                                }
                                .foregroundColor(AppColors.textSecondary)
                                
                                HStack(spacing: 4) {
                                    Image(systemName: isLiked ? "heart.fill" : "heart")
                                        .font(.system(size: 14))
                                    Text(likeCount.formatCount())
                                        .font(AppTypography.subheadline)
                                }
                                .foregroundColor(isLiked ? AppColors.error : AppColors.textSecondary)
                                
                                HStack(spacing: 4) {
                                    Image(systemName: isFavorited ? "star.fill" : "star")
                                        .font(.system(size: 14))
                                    Text(post.favoriteCount.formatCount())
                                        .font(AppTypography.subheadline)
                                }
                                .foregroundColor(isFavorited ? AppColors.warning : AppColors.textSecondary)
                            }
                        }
                        .padding(AppSpacing.md)
                        .background(AppColors.cardBackground)
                        .cornerRadius(AppCornerRadius.medium)
                        .shadow(color: AppShadow.small.color, radius: AppShadow.small.radius, x: AppShadow.small.x, y: AppShadow.small.y)
                        
                        // 操作按钮
                        HStack(spacing: AppSpacing.md) {
                            Button(action: {
                                if appState.isAuthenticated {
                                    viewModel.toggleLike(targetType: "post", targetId: post.id) { liked, count in
                                        isLiked = liked
                                        likeCount = count
                                    }
                                } else {
                                    showLogin = true
                                }
                            }) {
                                HStack {
                                    Image(systemName: isLiked ? "heart.fill" : "heart")
                                    Text(likeCount.formatCount())
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(isLiked ? AppColors.error.opacity(0.1) : AppColors.primaryLight)
                                .foregroundColor(isLiked ? AppColors.error : AppColors.primary)
                                .cornerRadius(AppCornerRadius.medium)
                            }
                            
                            Button(action: {
                                if appState.isAuthenticated {
                                    viewModel.toggleFavorite(postId: post.id) { favorited in
                                        isFavorited = favorited
                                        // 更新收藏数
                                        if favorited {
                                            favoriteCount += 1
                                        } else {
                                            favoriteCount = max(0, favoriteCount - 1)
                                        }
                                    }
                                } else {
                                    showLogin = true
                                }
                            }) {
                                HStack {
                                    Image(systemName: isFavorited ? "star.fill" : "star")
                                    Text(favoriteCount.formatCount())
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
                            Text(LocalizationKey.forumReplies.localized(argument: post.replyCount.formatCount()))
                                .font(.headline)
                                .padding(.horizontal, AppSpacing.md)
                            
                            if let errorMessage = viewModel.errorMessage {
                                Text("加载回复失败: \(errorMessage)")
                                    .font(.subheadline)
                                    .foregroundColor(AppColors.error)
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .padding(.vertical, AppSpacing.md)
                            } else if viewModel.replies.isEmpty {
                                Text(LocalizationKey.forumNoReplies.localized)
                                    .font(.subheadline)
                                    .foregroundColor(AppColors.textSecondary)
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .padding(.vertical, AppSpacing.xl)
                            } else {
                                ForEach(viewModel.replies) { reply in
                                    ReplyCard(reply: reply, postId: postId, viewModel: viewModel)
                                        .environmentObject(appState)
                                }
                            }
                        }
                        .padding(.top, AppSpacing.md)
                        
                        // 回复输入框
                        ReplyInputView(postId: postId, viewModel: viewModel)
                            .environmentObject(appState)
                            .padding(.horizontal, AppSpacing.md)
                            .padding(.top, AppSpacing.md)
                    }
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.vertical, AppSpacing.sm)
                    .padding(.bottom, 20)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        // 确保边缘滑动手势正常工作（NavigationStack 默认支持，但显式启用以确保兼容性）
        .sheet(isPresented: $showLogin) {
            LoginView()
        }
        .onAppear {
            viewModel.loadPost(postId: postId)
            viewModel.loadReplies(postId: postId)
        }
        .onChange(of: viewModel.post?.id) { _ in
            if let post = viewModel.post {
                likeCount = post.likeCount
                favoriteCount = post.favoriteCount
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
    let viewModel: ForumPostDetailViewModel
    @EnvironmentObject var appState: AppState
    @State private var isLiked = false
    @State private var likeCount: Int
    @State private var showReplySheet = false
    @State private var showLogin = false
    @State private var replyContent = ""
    
    init(reply: ForumReply, postId: Int, viewModel: ForumPostDetailViewModel) {
        self.reply = reply
        self.postId = postId
        self.viewModel = viewModel
        _likeCount = State(initialValue: reply.likeCount)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 作者信息
            if let author = reply.author {
                NavigationLink(destination: UserProfileView(userId: author.id)) {
                    HStack(spacing: 8) {
                        AvatarView(
                            urlString: author.avatar,
                            size: 32,
                            placeholder: Image(systemName: "person.circle.fill")
                        )
                        
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text(author.name)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(AppColors.textPrimary)
                                
                                // 官方标识（参考前端：蓝色 Tag，fontSize: 11）
                                if author.isAdmin == true {
                                    Text("官方")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(AppColors.primary)
                                        .cornerRadius(4)
                                }
                            }
                            
                            Text(formatTime(reply.createdAt))
                                .font(.caption)
                                .foregroundColor(AppColors.textSecondary)
                        }
                        
                        Spacer()
                    }
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            // 回复内容
            Text(reply.content)
                .font(.body)
                .foregroundColor(AppColors.textPrimary)
            
            // 操作按钮
            HStack {
                Button(action: {
                    if appState.isAuthenticated {
                        viewModel.likeReply(replyId: reply.id) { liked, count in
                            isLiked = liked
                            likeCount = count
                        }
                    } else {
                        showLogin = true
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: isLiked ? "heart.fill" : "heart")
                        Text(likeCount.formatCount())
                    }
                    .font(.caption)
                    .foregroundColor(isLiked ? AppColors.error : AppColors.textSecondary)
                }
                
                Button(action: {
                    if appState.isAuthenticated {
                        showReplySheet = true
                    } else {
                        showLogin = true
                    }
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
                        ReplyCard(reply: subReply, postId: postId, viewModel: viewModel)
                            .environmentObject(appState)
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
        .sheet(isPresented: $showLogin) {
            LoginView()
        }
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

// 回复输入框
struct ReplyInputView: View {
    let postId: Int
    let viewModel: ForumPostDetailViewModel
    @EnvironmentObject var appState: AppState
    @State private var replyContent = ""
    @State private var showLogin = false
    @FocusState private var isInputFocused: Bool
    
    var body: some View {
        VStack(spacing: AppSpacing.sm) {
            HStack(spacing: AppSpacing.sm) {
                TextField("写回复...", text: $replyContent, axis: .vertical)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .lineLimit(1...4)
                    .focused($isInputFocused)
                
                Button(action: {
                    guard !replyContent.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                    if appState.isAuthenticated {
                        let content = replyContent
                        replyContent = ""
                        viewModel.replyToPost(postId: postId, content: content) { success in
                            if success {
                                viewModel.loadReplies(postId: postId)
                            }
                        }
                    } else {
                        showLogin = true
                    }
                }) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundColor(replyContent.trimmingCharacters(in: .whitespaces).isEmpty ? AppColors.textSecondary : AppColors.primary)
                }
                .disabled(replyContent.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(AppSpacing.md)
        .background(AppColors.cardBackground)
        .cornerRadius(AppCornerRadius.medium)
        .shadow(color: AppShadow.small.color, radius: AppShadow.small.radius, x: AppShadow.small.x, y: AppShadow.small.y)
        .sheet(isPresented: $showLogin) {
            LoginView()
        }
    }
}

