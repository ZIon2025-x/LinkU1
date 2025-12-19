import SwiftUI

struct LeaderboardItemDetailView: View {
    let itemId: Int
    let leaderboardId: Int
    @StateObject private var viewModel = LeaderboardItemDetailViewModel()
    @EnvironmentObject var appState: AppState
    @State private var voteType: String?
    @State private var upvotes: Int = 0
    @State private var downvotes: Int = 0
    @State private var netVotes: Int = 0
    @State private var showLogin = false
    @State private var showVoteModal = false
    @State private var currentVoteType: String?
    @State private var voteComment: String = ""
    @State private var isAnonymous: Bool = false
    
    var body: some View {
        ZStack {
            AppColors.background
                .ignoresSafeArea()
            
            if viewModel.isLoading && viewModel.item == nil {
                ProgressView()
            } else if let item = viewModel.item {
                KeyboardAvoidingScrollView(extraPadding: 20) {
                    VStack(alignment: .leading, spacing: AppSpacing.lg) {
                        // 竞品信息卡片
                        VStack(alignment: .leading, spacing: AppSpacing.md) {
                            // 图片轮播
                            if let images = item.images, !images.isEmpty {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: AppSpacing.sm) {
                                        ForEach(Array(images.enumerated()), id: \.offset) { index, imageUrl in
                                            AsyncImage(url: imageUrl.toImageURL()) { phase in
                                                switch phase {
                                                case .success(let image):
                                                    image
                                                        .resizable()
                                                        .aspectRatio(contentMode: .fill)
                                                case .failure(_), .empty:
                                                    RoundedRectangle(cornerRadius: AppCornerRadius.medium)
                                                        .fill(AppColors.primaryLight)
                                                @unknown default:
                                                    RoundedRectangle(cornerRadius: AppCornerRadius.medium)
                                                        .fill(AppColors.primaryLight)
                                                }
                                            }
                                            .frame(width: UIScreen.main.bounds.width - 64, height: 250)
                                            .clipShape(RoundedRectangle(cornerRadius: AppCornerRadius.medium))
                                        }
                                    }
                                    .padding(.horizontal, AppSpacing.md)
                                }
                            }
                            
                            // 名称
                            Text(item.name)
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(AppColors.textPrimary)
                            
                            // 提交者信息
                            if let submitter = item.submitter {
                                NavigationLink(destination: UserProfileView(userId: submitter.id)) {
                                    HStack(spacing: 8) {
                                        AvatarView(
                                            urlString: submitter.avatar,
                                            size: 32,
                                            placeholder: Image(systemName: "person.circle.fill")
                                        )
                                        
                                        Text("由 \(submitter.name) 提交")
                                            .font(.subheadline)
                                            .foregroundColor(AppColors.textSecondary)
                                    }
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                            
                            Divider()
                            
                            // 描述
                            if let description = item.description {
                                Text(description)
                                    .font(.body)
                                    .foregroundColor(AppColors.textPrimary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            
                            // 联系信息
                            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                                if let address = item.address, !address.isEmpty {
                                    HStack(spacing: 8) {
                                        Image(systemName: "mappin.circle.fill")
                                            .foregroundColor(AppColors.primary)
                                        Text(address)
                                            .font(.subheadline)
                                            .foregroundColor(AppColors.textPrimary)
                                    }
                                }
                                
                                if let phone = item.phone, !phone.isEmpty {
                                    HStack(spacing: 8) {
                                        Image(systemName: "phone.circle.fill")
                                            .foregroundColor(AppColors.primary)
                                        Text(phone)
                                            .font(.subheadline)
                                            .foregroundColor(AppColors.textPrimary)
                                    }
                                }
                                
                                if let website = item.website, !website.isEmpty {
                                    HStack(spacing: 8) {
                                        Image(systemName: "globe")
                                            .foregroundColor(AppColors.primary)
                                        Link(website, destination: URL(string: website) ?? URL(string: "https://")!)
                                            .font(.subheadline)
                                            .foregroundColor(AppColors.primary)
                                    }
                                }
                            }
                            .padding(.top, AppSpacing.sm)
                            
                            // 投票统计
                            HStack(spacing: 20) {
                                HStack(spacing: 4) {
                                    Image(systemName: "hand.thumbsup.fill")
                                        .font(.system(size: 14))
                                    Text(upvotes.formatCount())
                                        .font(AppTypography.subheadline)
                                }
                                .foregroundColor(AppColors.textSecondary)
                                
                                HStack(spacing: 4) {
                                    Image(systemName: "hand.thumbsdown.fill")
                                        .font(.system(size: 14))
                                    Text(downvotes.formatCount())
                                        .font(AppTypography.subheadline)
                                }
                                .foregroundColor(AppColors.textSecondary)
                                
                                HStack(spacing: 4) {
                                    Image(systemName: "chart.bar.fill")
                                        .font(.system(size: 14))
                                    Text("净投票: \(netVotes.formatCount())")
                                        .font(AppTypography.subheadline)
                                }
                                .foregroundColor(AppColors.textSecondary)
                            }
                            .padding(.top, AppSpacing.sm)
                        }
                        .padding(AppSpacing.md)
                        .background(AppColors.cardBackground)
                        .cornerRadius(AppCornerRadius.medium)
                        .shadow(color: AppShadow.small.color, radius: AppShadow.small.radius, x: AppShadow.small.x, y: AppShadow.small.y)
                        
                        // 投票按钮
                        HStack(spacing: AppSpacing.md) {
                            Button(action: {
                                if appState.isAuthenticated {
                                    // 如果已经点赞，取消投票
                                    if voteType == "upvote" {
                                        viewModel.voteItem(itemId: itemId, voteType: "remove", comment: nil, isAnonymous: false) { success, up, down, net in
                                            if success {
                                                voteType = nil
                                                upvotes = up
                                                downvotes = down
                                                netVotes = net
                                                // 重新加载 item 以获取最新的 userVote 状态
                                                viewModel.loadItem(itemId: itemId)
                                                viewModel.loadComments(itemId: itemId)
                                            }
                                        }
                                    } else {
                                        // 弹出投票留言弹窗
                                        currentVoteType = "upvote"
                                        voteComment = ""
                                        isAnonymous = false
                                        showVoteModal = true
                                    }
                                } else {
                                    showLogin = true
                                }
                            }) {
                                HStack {
                                    Image(systemName: voteType == "upvote" ? "hand.thumbsup.fill" : "hand.thumbsup")
                                    Text("支持")
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(voteType == "upvote" ? AppColors.success.opacity(0.1) : AppColors.primaryLight)
                                .foregroundColor(voteType == "upvote" ? AppColors.success : AppColors.primary)
                                .cornerRadius(AppCornerRadius.medium)
                            }
                            
                            Button(action: {
                                if appState.isAuthenticated {
                                    // 如果已经点踩，取消投票
                                    if voteType == "downvote" {
                                        viewModel.voteItem(itemId: itemId, voteType: "remove", comment: nil, isAnonymous: false) { success, up, down, net in
                                            if success {
                                                voteType = nil
                                                upvotes = up
                                                downvotes = down
                                                netVotes = net
                                                // 重新加载 item 以获取最新的 userVote 状态
                                                viewModel.loadItem(itemId: itemId)
                                                viewModel.loadComments(itemId: itemId)
                                            }
                                        }
                                    } else {
                                        // 弹出投票留言弹窗
                                        currentVoteType = "downvote"
                                        voteComment = ""
                                        isAnonymous = false
                                        showVoteModal = true
                                    }
                                } else {
                                    showLogin = true
                                }
                            }) {
                                HStack {
                                    Image(systemName: voteType == "downvote" ? "hand.thumbsdown.fill" : "hand.thumbsdown")
                                    Text("反对")
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(voteType == "downvote" ? AppColors.error.opacity(0.1) : AppColors.primaryLight)
                                .foregroundColor(voteType == "downvote" ? AppColors.error : AppColors.primary)
                                .cornerRadius(AppCornerRadius.medium)
                            }
                        }
                        .padding(.horizontal, AppSpacing.md)
                        
                        // 留言列表（后端只返回有留言的投票，参考后端：comment.isnot(None) && comment != ''）
                        VStack(alignment: .leading, spacing: AppSpacing.md) {
                            Text("留言 (\(viewModel.comments.count.formatCount()))")
                                .font(.headline)
                                .padding(.horizontal, AppSpacing.md)
                            
                            if viewModel.comments.isEmpty {
                                Text("暂无留言")
                                    .font(.subheadline)
                                    .foregroundColor(AppColors.textSecondary)
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .padding(.vertical, AppSpacing.xl)
                            } else {
                                ForEach(viewModel.comments) { comment in
                                    CommentCard(comment: comment, viewModel: viewModel)
                                        .environmentObject(appState)
                                }
                            }
                        }
                        .padding(.top, AppSpacing.md)
                        
                    }
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.vertical, AppSpacing.sm)
                    .padding(.bottom, 20)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showLogin) {
            LoginView()
        }
        .sheet(isPresented: $showVoteModal) {
            VoteCommentModal(
                voteType: currentVoteType ?? "",
                comment: $voteComment,
                isAnonymous: $isAnonymous,
                onConfirm: {
                    guard let voteType = currentVoteType else { return }
                    let comment = voteComment.trimmingCharacters(in: .whitespaces).isEmpty ? nil : voteComment.trimmingCharacters(in: .whitespaces)
                    viewModel.voteItem(itemId: itemId, voteType: voteType, comment: comment, isAnonymous: isAnonymous) { success, up, down, net in
                        if success {
                            // 更新本地状态
                            self.upvotes = up
                            self.downvotes = down
                            self.netVotes = net
                            self.voteType = voteType // 设置投票类型
                            self.showVoteModal = false
                            self.voteComment = ""
                            self.isAnonymous = false
                            // 重新加载 item 以获取最新的 userVote 状态（确保刷新后也能正确显示）
                            viewModel.loadItem(itemId: itemId)
                            viewModel.loadComments(itemId: itemId)
                        }
                    }
                },
                onCancel: {
                    showVoteModal = false
                    voteComment = ""
                    isAnonymous = false
                }
            )
        }
        .onAppear {
            viewModel.loadItem(itemId: itemId)
            // loadComments 会在 loadItem 完成后自动调用，避免重复加载
            // 但为了确保即使 loadItem 失败也能加载留言，这里也调用一次
            viewModel.loadComments(itemId: itemId)
            // 如果 item 已经存在（例如从列表页传入），立即更新状态
            if let item = viewModel.item {
                updateVoteState(from: item)
            }
        }
        // 监听 item.id 的变化，确保数据加载完成后更新投票状态
        .onChange(of: viewModel.item?.id) { newId in
            if let item = viewModel.item, let newId = newId, newId == itemId {
                updateVoteState(from: item)
            }
        }
    }
    
    /// 从 item 更新投票状态
    private func updateVoteState(from item: LeaderboardItem) {
        upvotes = item.upvotes
        downvotes = item.downvotes
        netVotes = item.netVotes
        // 确保从后端返回的 userVote 正确显示
        // userVote 可能是 "upvote", "downvote", 或 nil
        voteType = item.userVote
    }
}

// 留言卡片
struct CommentCard: View {
    let comment: LeaderboardItemComment
    let viewModel: LeaderboardItemDetailViewModel
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 作者信息
            HStack {
                // 头像（匿名用户使用灰色，普通用户使用蓝色）
                AvatarView(
                    urlString: comment.isAnonymous == true ? nil : comment.author?.avatar,
                    size: 32,
                    avatarType: comment.isAnonymous == true ? .anonymous : nil
                )
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        // 投票类型图标
                        if let voteType = comment.voteType {
                            Image(systemName: voteType == "upvote" ? "hand.thumbsup.fill" : "hand.thumbsdown.fill")
                                .font(.system(size: 12))
                                .foregroundColor(voteType == "upvote" ? AppColors.success : AppColors.error)
                        }
                        
                        // 用户名（匿名用户显示"匿名用户 #序号"）
                        if comment.isAnonymous == true {
                            Text("匿名用户")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        } else if let author = comment.author {
                            Text(author.name)
                                .font(.subheadline)
                                .fontWeight(.medium)
                        } else if let userId = comment.userId {
                            Text("用户 \(userId)")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        } else {
                            Text("未知用户")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        
                        // 匿名标签
                        if comment.isAnonymous == true {
                            Text("匿名")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(AppColors.textSecondary)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(AppColors.cardBackground)
                                .cornerRadius(4)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 4)
                                        .stroke(AppColors.separator, lineWidth: 1)
                                )
                        }
                    }
                    
                    Text(formatTime(comment.createdAt))
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)
                }
                
                Spacer()
            }
            
            // 留言内容（如果有）
            if let content = comment.content, !content.isEmpty {
                Text(content)
                    .font(.body)
                    .foregroundColor(AppColors.textPrimary)
            }
            
            // 点赞按钮
            HStack {
                Spacer()
                Button(action: {
                    if appState.isAuthenticated {
                        viewModel.likeComment(voteId: comment.id) { success, likeCount, liked in
                            if success {
                                // 更新本地状态（通过重新加载实现）
                                viewModel.loadComments(itemId: comment.itemId ?? 0)
                            }
                        }
                    } else {
                        // 显示登录提示
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: comment.userLiked == true ? "hand.thumbsup.fill" : "hand.thumbsup")
                            .font(.system(size: 14))
                        Text("\(comment.likeCount ?? 0)")
                            .font(.caption)
                    }
                    .foregroundColor(comment.userLiked == true ? AppColors.primary : AppColors.textSecondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(comment.userLiked == true ? AppColors.primary.opacity(0.1) : AppColors.cardBackground)
                    .cornerRadius(AppCornerRadius.small)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.top, AppSpacing.xs)
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

// 投票留言弹窗
struct VoteCommentModal: View {
    let voteType: String
    @Binding var comment: String
    @Binding var isAnonymous: Bool
    let onConfirm: () -> Void
    let onCancel: () -> Void
    @FocusState private var isInputFocused: Bool
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    // 留言输入框（可选）
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        Text("留言（可选）")
                            .font(.subheadline)
                            .foregroundColor(AppColors.textSecondary)
                            .padding(.horizontal, AppSpacing.md)
                        
                        EnhancedTextEditor(
                            title: nil,
                            placeholder: voteType == "upvote" ? "说说你为什么支持..." : "说说你为什么反对...",
                            text: $comment,
                            characterLimit: 500
                        )
                        .frame(height: 120)
                        .padding(.horizontal, AppSpacing.md)
                    }
                    .padding(.top, AppSpacing.md)
                    
                    // 匿名选项
                    Toggle(isOn: $isAnonymous) {
                        Text("匿名投票")
                            .font(.subheadline)
                            .foregroundColor(AppColors.textPrimary)
                    }
                    .padding(.horizontal, AppSpacing.md)
                    
                    // 按钮
                    HStack(spacing: AppSpacing.md) {
                        Button(action: onCancel) {
                            Text("取消")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(AppColors.cardBackground)
                                .foregroundColor(AppColors.textPrimary)
                                .cornerRadius(AppCornerRadius.medium)
                                .overlay(
                                    RoundedRectangle(cornerRadius: AppCornerRadius.medium)
                                        .stroke(AppColors.separator, lineWidth: 1)
                                )
                        }
                        
                        Button(action: onConfirm) {
                            Text("确认")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(AppColors.primary)
                                .foregroundColor(.white)
                                .cornerRadius(AppCornerRadius.medium)
                        }
                    }
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.top, AppSpacing.lg)
                    .padding(.bottom, AppSpacing.md)
                }
            }
            .background(AppColors.background)
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle(voteType == "upvote" ? "支持并留言" : "反对并留言")
        }
        // 让系统自动处理键盘避让，避免约束冲突
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }
}
