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
    @State private var showShareSheet = false
    @State private var isTogglingLike = false
    @State private var isTogglingFavorite = false
    
    var body: some View {
        ZStack(alignment: .bottom) {
            Color(UIColor.systemBackground)
                .ignoresSafeArea()
            
            if viewModel.isLoading && viewModel.post == nil {
                ProgressView()
                    .scaleEffect(1.2)
            } else if let post = viewModel.post {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        // 1. 作者与标题区域
                        postHeader(post: post)
                        
                        // 2. 帖子内容
                        postContent(post: post)
                        
                        // 3. 统计数据与操作 (点赞/收藏预览)
                        postStats(post: post)
                        
                        Divider()
                            .padding(.vertical, 8)
                        
                        // 4. 回复列表
                        replySection(post: post)
                        
                        // 底部留白，防止被回复框遮挡
                        Spacer().frame(height: 120)
                    }
                }
                .scrollIndicators(.hidden)
                
                // 5. 固定底部回复栏
                bottomReplyBar(post: post)
            } else {
                // 如果 post 为 nil 且不在加载中，显示错误状态（不应该发生，但作为保护）
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 48))
                        .foregroundColor(AppColors.textTertiary)
                    Text(LocalizationKey.forumPostLoadFailed.localized)
                        .font(AppTypography.body)
                        .foregroundColor(AppColors.textSecondary)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .enableSwipeBack()
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 16) {
                    // 分享按钮
                    Button(action: {
                        showShareSheet = true
                        HapticFeedback.light()
                    }) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(AppColors.textPrimary)
                    }
                    
                    // 收藏按钮
                    Button(action: {
                        if appState.isAuthenticated {
                            viewModel.toggleFavorite(postId: postId) { favorited in
                                isFavorited = favorited
                                if favorited {
                                    favoriteCount += 1
                                    HapticFeedback.success()
                                } else {
                                    favoriteCount = max(0, favoriteCount - 1)
                                    HapticFeedback.light()
                                }
                            }
                        } else {
                            showLogin = true
                        }
                    }) {
                        Image(systemName: isFavorited ? "star.fill" : "star")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(isFavorited ? AppColors.warning : AppColors.textPrimary)
                    }
                }
            }
        }
        .sheet(isPresented: $showShareSheet) {
            if let post = viewModel.post {
                ForumPostShareSheet(
                    post: post,
                    postId: postId
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
        }
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
                isLiked = post.isLiked ?? false
                isFavorited = post.isFavorited ?? false
            }
        }
    }
    
    // MARK: - Sub Views
    
    @ViewBuilder
    private func postHeader(post: ForumPost) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // 标题与标签
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    if post.isPinned {
                        tagLabel(text: "置顶", color: AppColors.error, icon: "pin.fill")
                    }
                    if post.isFeatured {
                        tagLabel(text: "精华", color: AppColors.warning, icon: "star.fill")
                    }
                    if let category = post.category {
                        Text(category.name)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(AppColors.primary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(AppColors.primaryLight)
                            .cornerRadius(4)
                    }
                }
                
                Text(post.title)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(AppColors.textPrimary)
                    .lineSpacing(4)
            }
            
            // 作者信息
            if let author = post.author {
                NavigationLink(destination: UserProfileView(userId: author.id)) {
                    HStack(spacing: 12) {
                        AvatarView(
                            urlString: author.avatar,
                            size: 44,
                            placeholder: Image(systemName: "person.circle.fill")
                        )
                        .clipShape(Circle())
                        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text(author.name)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(AppColors.textPrimary)
                                
                                if author.isAdmin == true {
                                    Text(LocalizationKey.forumOfficial.localized)
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 2)
                                        .background(AppColors.primary)
                                        .cornerRadius(3)
                                }
                            }
                            
                            Text(formatTime(post.createdAt))
                                .font(.system(size: 12))
                                .foregroundColor(AppColors.textQuaternary)
                        }
                        
                        Spacer()
                    }
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            Divider()
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }
    
    @ViewBuilder
    private func tagLabel(text: String, color: Color, icon: String) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 9))
            Text(text)
                .font(.system(size: 10, weight: .bold))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color)
        .cornerRadius(6)
    }
    
    @ViewBuilder
    private func postContent(post: ForumPost) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            if let content = post.content {
                Text(content)
                    .font(.system(size: 17))
                    .foregroundColor(AppColors.textPrimary)
                    .lineSpacing(8)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }
    
    @ViewBuilder
    private func postStats(post: ForumPost) -> some View {
        HStack(spacing: 24) {
            statItem(icon: "eye", count: post.viewCount, label: LocalizationKey.forumView.localized)
            
            // 喜欢按钮（可点击）
            Button(action: {
                guard !isTogglingLike else { return }
                if appState.isAuthenticated {
                    isTogglingLike = true
                    viewModel.toggleLike(targetType: "post", targetId: postId) { liked, newCount in
                        isLiked = liked
                        likeCount = newCount
                        isTogglingLike = false
                        if liked {
                            HapticFeedback.success()
                        } else {
                            HapticFeedback.light()
                        }
                        // 发送通知，更新列表
                        NotificationCenter.default.post(
                            name: .forumPostLiked,
                            object: nil,
                            userInfo: ["postId": postId, "liked": liked]
                        )
                        NotificationCenter.default.post(name: .forumPostUpdated)
                    }
                } else {
                    showLogin = true
                }
            }) {
                ZStack {
                    statItem(icon: "heart", count: likeCount, label: LocalizationKey.forumLike.localized, active: isLiked, activeColor: AppColors.error)
                    if isTogglingLike {
                        ProgressView()
                            .scaleEffect(0.7)
                    }
                }
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(isTogglingLike)
            
            // 收藏按钮（可点击）
            Button(action: {
                guard !isTogglingFavorite else { return }
                if appState.isAuthenticated {
                    isTogglingFavorite = true
                    viewModel.toggleFavorite(postId: postId) { favorited in
                        isFavorited = favorited
                        if favorited {
                            favoriteCount += 1
                            HapticFeedback.success()
                        } else {
                            favoriteCount = max(0, favoriteCount - 1)
                            HapticFeedback.light()
                        }
                        isTogglingFavorite = false
                        // 发送通知，更新列表
                        NotificationCenter.default.post(
                            name: .forumPostFavorited,
                            object: nil,
                            userInfo: ["postId": postId, "favorited": favorited]
                        )
                        NotificationCenter.default.post(name: .forumPostUpdated)
                    }
                } else {
                    showLogin = true
                }
            }) {
                ZStack {
                    statItem(icon: "star", count: favoriteCount, label: LocalizationKey.forumFavorite.localized, active: isFavorited, activeColor: AppColors.warning)
                    if isTogglingFavorite {
                        ProgressView()
                            .scaleEffect(0.7)
                    }
                }
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(isTogglingFavorite)
            
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
    }
    
    @ViewBuilder
    private func statItem(icon: String, count: Int, label: String, active: Bool = false, activeColor: Color = .primary) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: active ? "\(icon).fill" : icon)
                    .font(.system(size: 14))
                    .foregroundColor(active ? activeColor : AppColors.textSecondary)
                Text(count.formatCount())
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(active ? activeColor : AppColors.textPrimary)
            }
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(AppColors.textQuaternary)
        }
    }
    
    @ViewBuilder
    private func replySection(post: ForumPost) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text(LocalizationKey.forumAllReplies.localized)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(AppColors.textPrimary)
                
                Text("\(post.replyCount)")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(AppColors.textQuaternary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color(UIColor.secondarySystemBackground))
                    .clipShape(Capsule())
                
                Spacer()
            }
            .padding(.horizontal, 20)
            
            if viewModel.replies.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "bubble.left")
                        .font(.system(size: 40, weight: .light))
                        .foregroundColor(AppColors.textQuaternary)
                    Text(LocalizationKey.forumNoReplies.localized)
                        .font(.system(size: 14))
                        .foregroundColor(AppColors.textTertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 60)
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(viewModel.replies) { reply in
                        ReplyCard(reply: reply, postId: postId, viewModel: viewModel)
                            .environmentObject(appState)
                        Divider()
                            .padding(.horizontal, 20)
                    }
                }
            }
        }
        .padding(.top, 8)
    }
    
    @ViewBuilder
    private func bottomReplyBar(post: ForumPost) -> some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 12) {
                // 快捷操作：点赞
                Button(action: {
                    if appState.isAuthenticated {
                        viewModel.toggleLike(targetType: "post", targetId: post.id) { liked, count in
                            isLiked = liked
                            likeCount = count
                            if liked { HapticFeedback.success() }
                        }
                    } else {
                        showLogin = true
                    }
                }) {
                    Image(systemName: isLiked ? "heart.fill" : "heart")
                        .font(.system(size: 22))
                        .foregroundColor(isLiked ? AppColors.error : AppColors.textSecondary)
                        .frame(width: 44, height: 44)
                }
                
                // 回复输入框
                ReplyInputView(postId: postId, viewModel: viewModel)
                    .environmentObject(appState)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 24)
            .background(.ultraThinMaterial)
        }
        .ignoresSafeArea(edges: .bottom)
    }
    
    private func formatTime(_ timeString: String) -> String {
        return DateFormatterHelper.shared.formatTime(timeString)
    }
}

// MARK: - Reply Input View (Refactored)

struct ReplyInputView: View {
    let postId: Int
    let viewModel: ForumPostDetailViewModel
    @EnvironmentObject var appState: AppState
    @State private var replyContent = ""
    @State private var showLogin = false
    @FocusState private var isInputFocused: Bool
    
    var body: some View {
        HStack(spacing: 10) {
            TextField("写下你的回复...", text: $replyContent)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(22)
                .focused($isInputFocused)
            
            if !replyContent.trimmingCharacters(in: .whitespaces).isEmpty {
                Button(action: {
                    if appState.isAuthenticated {
                        let content = replyContent
                        replyContent = ""
                        isInputFocused = false
                        viewModel.replyToPost(postId: postId, content: content) { success in
                            if success {
                                HapticFeedback.success()
                                viewModel.loadReplies(postId: postId)
                            }
                        }
                    } else {
                        showLogin = true
                    }
                }) {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(AppColors.primary)
                        .frame(width: 40, height: 40)
                        .background(AppColors.primaryLight)
                        .clipShape(Circle())
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.spring(), value: replyContent.isEmpty)
        .sheet(isPresented: $showLogin) {
            LoginView()
        }
    }
}

// MARK: - Reply Card (Refactored)

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
        _isLiked = State(initialValue: reply.isLiked ?? false)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 作者信息
            if let author = reply.author {
                HStack(spacing: 10) {
                    AvatarView(
                        urlString: author.avatar,
                        size: 32,
                        placeholder: Image(systemName: "person.circle.fill")
                    )
                    .clipShape(Circle())
                    
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(author.name)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(AppColors.textPrimary)
                            
                            if author.isAdmin == true {
                                Text(LocalizationKey.forumOfficial.localized)
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 1)
                                    .background(AppColors.primary)
                                    .cornerRadius(2)
                            }
                        }
                        
                        Text(formatTime(reply.createdAt))
                            .font(.system(size: 11))
                            .foregroundColor(AppColors.textQuaternary)
                    }
                    
                    Spacer()
                    
                    // 点赞回复
                    Button(action: {
                        if appState.isAuthenticated {
                            viewModel.likeReply(replyId: reply.id) { liked, count in
                                isLiked = liked
                                likeCount = count
                                if liked { HapticFeedback.light() }
                            }
                        } else {
                            showLogin = true
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: isLiked ? "heart.fill" : "heart")
                                .font(.system(size: 12))
                            Text(likeCount.formatCount())
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                        }
                        .foregroundColor(isLiked ? AppColors.error : AppColors.textSecondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(isLiked ? AppColors.error.opacity(0.1) : Color.clear)
                        .cornerRadius(8)
                    }
                }
            }
            
            // 回复内容
            Text(reply.content)
                .font(.system(size: 15))
                .foregroundColor(AppColors.textPrimary)
                .lineSpacing(4)
                .padding(.leading, 42)
            
            // 子回复按钮
            Button(action: {
                if appState.isAuthenticated {
                    showReplySheet = true
                } else {
                    showLogin = true
                }
            }) {
                Text(LocalizationKey.forumReply.localized)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(AppColors.primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(AppColors.primaryLight)
                    .cornerRadius(12)
            }
            .padding(.leading, 42)
            
            // 子回复列表
            if let subReplies = reply.replies, !subReplies.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(subReplies) { subReply in
                        ReplyCard(reply: subReply, postId: postId, viewModel: viewModel)
                    }
                }
                .padding(.leading, 32)
                .padding(.top, 8)
            }
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 20)
        .sheet(isPresented: $showReplySheet) {
            ReplySheet(
                content: $replyContent,
                onReply: {
                    viewModel.replyToPost(postId: postId, content: replyContent, parentReplyId: reply.id) { success in
                        if success {
                            HapticFeedback.success()
                            showReplySheet = false
                            replyContent = ""
                            viewModel.loadReplies(postId: postId)
                        }
                    }
                }
            )
        }
        .sheet(isPresented: $showLogin) {
            LoginView()
        }
    }
    
    private func formatTime(_ timeString: String) -> String {
        return DateFormatterHelper.shared.formatTime(timeString)
    }
}

// MARK: - Reply Sheet
struct ReplySheet: View {
    @Binding var content: String
    let onReply: () -> Void
    @Environment(\.dismiss) var dismiss
    @FocusState private var isInputFocused: Bool
    
    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                TextEditor(text: $content)
                    .font(.system(size: 16))
                    .frame(minHeight: 150)
                    .padding(12)
                    .scrollContentBackground(.hidden)
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(12)
                    .focused($isInputFocused)
                    .overlay(
                        Group {
                            if content.isEmpty {
                                Text(LocalizationKey.forumWriteReply.localized)
                                    .font(.system(size: 16))
                                    .foregroundColor(AppColors.textTertiary)
                                    .padding(.leading, 16)
                                    .padding(.top, 20)
                                    .allowsHitTesting(false)
                            }
                        },
                        alignment: .topLeading
                    )
                
                Spacer()
            }
            .padding(20)
            .background(Color(UIColor.systemBackground))
            .navigationTitle(LocalizationKey.forumReply.localized)
            .navigationBarTitleDisplayMode(.inline)
            .enableSwipeBack()
            .scrollDismissesKeyboard(.interactively)
            .contentShape(Rectangle())
            .onTapGesture {
                isInputFocused = false
                hideKeyboard()
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: onReply) {
                        Text(LocalizationKey.forumSend.localized)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(content.trimmingCharacters(in: .whitespaces).isEmpty ? AppColors.textTertiary : AppColors.primary)
                            .clipShape(Capsule())
                    }
                    .disabled(content.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                isInputFocused = true
            }
        }
    }
    
    private func hideKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }
}

// MARK: - 帖子分享视图
struct ForumPostShareSheet: View {
    let post: ForumPost
    let postId: Int
    @Environment(\.dismiss) var dismiss
    
    // 使用前端网页 URL，确保微信能抓取到正确的 meta 标签
    private var shareUrl: URL {
        let urlString = "https://www.link2ur.com/zh/forum/posts/\(postId)?v=2"
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
                // 占位图
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
                        IconStyle.icon("doc.text.fill", size: 40)
                            .foregroundColor(.white.opacity(0.8))
                    )
                
                // 标题和描述
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text(post.title)
                        .font(AppTypography.bodyBold)
                        .foregroundColor(AppColors.textPrimary)
                        .lineLimit(2)
                    
                    if let content = post.content, !content.isEmpty {
                        Text(content)
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.textSecondary)
                            .lineLimit(2)
                    } else if let preview = post.contentPreview, !preview.isEmpty {
                        Text(preview)
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.textSecondary)
                            .lineLimit(2)
                    }
                    
                    // 帖子信息
                    HStack(spacing: AppSpacing.md) {
                        Label("\(post.viewCount) 浏览", systemImage: "eye")
                        Label("\(post.replyCount) 回复", systemImage: "bubble.left")
                        if let category = post.category {
                            Label(category.name, systemImage: "tag")
                        }
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
                title: getShareTitle(for: post),
                description: getShareDescription(for: post),
                url: shareUrl,
                image: nil,
                taskType: nil,
                location: nil,
                reward: nil,
                onDismiss: {
                    dismiss()
                }
            )
            .padding(.top, AppSpacing.md)
        }
        .background(AppColors.background)
    }
    
    /// 获取分享标题
    private func getShareTitle(for post: ForumPost) -> String {
        let trimmedTitle = post.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedTitle.isEmpty {
            return "看看这篇帖子"
        }
        return trimmedTitle
    }
    
    /// 获取分享描述
    private func getShareDescription(for post: ForumPost) -> String {
        // 优先使用content，如果没有则使用contentPreview
        let description: String
        if let content = post.content, !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            description = content
        } else if let preview = post.contentPreview, !preview.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            description = preview
        } else {
            // 如果没有内容，使用帖子信息构建描述
            let categoryText = post.category?.name ?? ""
            let statsText = "\(post.viewCount) 浏览 · \(post.replyCount) 回复"
            if !categoryText.isEmpty {
                return "\(categoryText) | \(statsText)"
            }
            return statsText
        }
        
        // 限制长度
        let maxLength = 200
        if description.count > maxLength {
            return String(description.prefix(maxLength)) + "..."
        }
        return description
    }
}
