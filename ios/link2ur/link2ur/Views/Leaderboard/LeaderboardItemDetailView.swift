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
    @State private var selectedImageIndex = 0
    
    var body: some View {
        ZStack {
            AppColors.background
                .ignoresSafeArea()
            
            if viewModel.isLoading && viewModel.item == nil {
                LoadingView(message: "加载详情中...")
            } else if let item = viewModel.item {
                ScrollView {
                    VStack(alignment: .leading, spacing: AppSpacing.lg) {
                        // 1. 图片展示区域
                        LeaderboardItemImageSection(images: item.images ?? [], selectedIndex: $selectedImageIndex)
                        
                        VStack(alignment: .leading, spacing: AppSpacing.xl) {
                            // 2. 核心信息卡片
                            VStack(alignment: .leading, spacing: AppSpacing.md) {
                                Text(item.name)
                                    .font(AppTypography.title)
                                    .foregroundColor(AppColors.textPrimary)
                                
                                if let submitter = item.submitter {
                                    NavigationLink(destination: UserProfileView(userId: submitter.id)) {
                                        HStack(spacing: 8) {
                                            AvatarView(
                                                urlString: submitter.avatar,
                                                size: 28,
                                                placeholder: Image(systemName: "person.circle.fill")
                                            )
                                            .clipShape(Circle())
                                            
                                            Text("由 \(submitter.name) 提交")
                                                .font(AppTypography.subheadline)
                                                .foregroundColor(AppColors.textSecondary)
                                            
                                            Spacer()
                                            
                                            IconStyle.icon("chevron.right", size: 12)
                                                .foregroundColor(AppColors.textQuaternary)
                                        }
                                        .padding(.vertical, 8)
                                        .padding(.horizontal, 12)
                                        .background(AppColors.background.opacity(0.5))
                                        .cornerRadius(AppCornerRadius.medium)
                                    }
                                    .buttonStyle(ScaleButtonStyle())
                                }
                                
                                Divider().background(AppColors.divider)
                                
                                if let description = item.description, !description.isEmpty {
                                    Text(description)
                                        .font(AppTypography.body)
                                        .foregroundColor(AppColors.textPrimary)
                                        .lineSpacing(6)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                
                                // 联系信息
                                LeaderboardItemContactView(item: item)
                            }
                            .padding(AppSpacing.lg)
                            .background(AppColors.cardBackground)
                            .cornerRadius(AppCornerRadius.large)
                            .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 4)
                            
                            // 3. 投票交互区
                            VStack(spacing: AppSpacing.md) {
                                HStack(spacing: AppSpacing.md) {
                                    VoteActionButton(
                                        title: "支持",
                                        icon: voteType == "upvote" ? "hand.thumbsup.fill" : "hand.thumbsup",
                                        isSelected: voteType == "upvote",
                                        color: AppColors.success,
                                        count: upvotes,
                                        action: { handleVoteAction(type: "upvote") }
                                    )
                                    
                                    VoteActionButton(
                                        title: "反对",
                                        icon: voteType == "downvote" ? "hand.thumbsdown.fill" : "hand.thumbsdown",
                                        isSelected: voteType == "downvote",
                                        color: AppColors.error,
                                        count: downvotes,
                                        action: { handleVoteAction(type: "downvote") }
                                    )
                                }
                                
                                if netVotes != 0 {
                                    HStack {
                                        Spacer()
                                        Text("当前净投票分: \(netVotes)")
                                            .font(AppTypography.caption)
                                            .foregroundColor(AppColors.textSecondary)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 4)
                                            .background(AppColors.background)
                                            .cornerRadius(AppCornerRadius.small)
                                        Spacer()
                                    }
                                }
                            }
                            
                            // 4. 留言列表
                            VStack(alignment: .leading, spacing: AppSpacing.md) {
                                HStack {
                                    IconStyle.icon("bubble.left.and.bubble.right.fill", size: 18)
                                        .foregroundColor(AppColors.primary)
                                    Text("留言 (\(viewModel.comments.count))")
                                        .font(AppTypography.title3)
                                        .foregroundColor(AppColors.textPrimary)
                                }
                                .padding(.horizontal, AppSpacing.sm)
                                
                                if viewModel.comments.isEmpty {
                                    VStack(spacing: AppSpacing.md) {
                                        IconStyle.icon("text.bubble", size: 40)
                                            .foregroundColor(AppColors.textQuaternary)
                                        Text("暂无留言，快来发表你的看法吧")
                                            .font(AppTypography.body)
                                            .foregroundColor(AppColors.textTertiary)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 40)
                                    .background(AppColors.cardBackground.opacity(0.5))
                                    .cornerRadius(AppCornerRadius.large)
                                } else {
                                    ForEach(viewModel.comments) { comment in
                                        LeaderboardCommentCard(comment: comment, viewModel: viewModel)
                                            .environmentObject(appState)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, AppSpacing.md)
                    }
                    .padding(.bottom, 40)
                }
                .refreshable {
                    viewModel.loadItem(itemId: itemId)
                    viewModel.loadComments(itemId: itemId)
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
                            HapticFeedback.success()
                            self.upvotes = up
                            self.downvotes = down
                            self.netVotes = net
                            self.voteType = voteType
                            self.showVoteModal = false
                            self.voteComment = ""
                            self.isAnonymous = false
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
            viewModel.loadComments(itemId: itemId)
            if let item = viewModel.item {
                updateVoteState(from: item)
            }
        }
        .onChange(of: viewModel.item?.id) { newId in
            if let item = viewModel.item, let newId = newId, newId == itemId {
                updateVoteState(from: item)
            }
        }
    }
    
    private func updateVoteState(from item: LeaderboardItem) {
        upvotes = item.upvotes
        downvotes = item.downvotes
        netVotes = item.netVotes
        voteType = item.userVote
    }
    
    private func handleVoteAction(type: String) {
        if !appState.isAuthenticated {
            showLogin = true
            return
        }
        
        if voteType == type {
            // 取消投票
            HapticFeedback.light()
            viewModel.voteItem(itemId: itemId, voteType: "remove", comment: nil, isAnonymous: false) { success, up, down, net in
                if success {
                    voteType = nil
                    upvotes = up
                    downvotes = down
                    netVotes = net
                    viewModel.loadItem(itemId: itemId)
                    viewModel.loadComments(itemId: itemId)
                }
            }
        } else {
            // 弹出留言弹窗
            currentVoteType = type
            voteComment = ""
            isAnonymous = false
            showVoteModal = true
            HapticFeedback.selection()
        }
    }
}

// MARK: - Subviews

struct LeaderboardItemImageSection: View {
    let images: [String]
    @Binding var selectedIndex: Int
    
    var body: some View {
        if !images.isEmpty {
            ZStack(alignment: .bottom) {
                TabView(selection: $selectedIndex) {
                    ForEach(Array(images.enumerated()), id: \.offset) { index, imageUrl in
                        AsyncImageView(urlString: imageUrl, placeholder: Image(systemName: "photo.fill"))
                            .aspectRatio(contentMode: .fill)
                            .frame(width: UIScreen.main.bounds.width, height: 280) // 显式限制宽度为屏幕宽度
                            .clipped()
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(height: 280)
                
                if images.count > 1 {
                    HStack(spacing: 6) {
                        ForEach(0..<images.count, id: \.self) { index in
                            Capsule()
                                .fill(selectedIndex == index ? Color.white : Color.white.opacity(0.4))
                                .frame(width: selectedIndex == index ? 16 : 6, height: 6)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .padding(.bottom, 12)
                }
            }
        } else {
            ZStack {
                Rectangle().fill(AppColors.primaryLight)
                IconStyle.icon("photo.on.rectangle.angled", size: 60).foregroundColor(AppColors.primary.opacity(0.3))
            }
            .frame(width: UIScreen.main.bounds.width, height: 200) // 显式限制宽度
        }
    }
}

struct LeaderboardItemContactView: View {
    let item: LeaderboardItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            if let address = item.address, !address.isEmpty {
                LeaderboardContactRow(icon: "mappin.circle.fill", text: address, color: .red)
            }
            if let phone = item.phone, !phone.isEmpty {
                LeaderboardContactRow(icon: "phone.circle.fill", text: phone, color: .green)
            }
            if let website = item.website, !website.isEmpty {
                if let url = URL(string: website) {
                    Link(destination: url) {
                        LeaderboardContactRow(icon: "globe", text: website, color: .blue)
                    }
                }
            }
        }
        .padding(.top, AppSpacing.sm)
    }
}

struct LeaderboardContactRow: View {
    let icon: String
    let text: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 10) {
            IconStyle.icon(icon, size: 16)
                .foregroundColor(color)
            Text(text)
                .font(AppTypography.subheadline)
                .foregroundColor(AppColors.textPrimary)
                .lineLimit(1)
        }
        .padding(.vertical, 4)
    }
}

struct VoteActionButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let color: Color
    let count: Int
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                HStack(spacing: 8) {
                    IconStyle.icon(icon, size: 18)
                    Text(title)
                        .fontWeight(.bold)
                }
                Text("\(count)")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(isSelected ? color.opacity(0.15) : AppColors.cardBackground)
            .foregroundColor(isSelected ? color : AppColors.textSecondary)
            .cornerRadius(AppCornerRadius.medium)
            .overlay(
                RoundedRectangle(cornerRadius: AppCornerRadius.medium)
                    .stroke(isSelected ? color.opacity(0.3) : AppColors.separator.opacity(0.5), lineWidth: 1)
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

struct LeaderboardCommentCard: View {
    let comment: LeaderboardItemComment
    let viewModel: LeaderboardItemDetailViewModel
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                AvatarView(
                    urlString: comment.isAnonymous == true ? nil : comment.author?.avatar,
                    size: 36,
                    avatarType: comment.isAnonymous == true ? .anonymous : nil
                )
                .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(displayName)
                            .font(AppTypography.bodyBold)
                            .foregroundColor(AppColors.textPrimary)
                        
                        if let voteType = comment.voteType {
                            IconStyle.icon(voteType == "upvote" ? "hand.thumbsup.fill" : "hand.thumbsdown.fill", size: 10)
                                .foregroundColor(voteType == "upvote" ? AppColors.success : AppColors.error)
                        }
                        
                        if comment.isAnonymous == true {
                            Text("匿名")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(AppColors.textTertiary)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(AppColors.background)
                                .cornerRadius(2)
                        }
                    }
                    
                    Text(DateFormatterHelper.shared.formatTime(comment.createdAt))
                        .font(AppTypography.caption2)
                        .foregroundColor(AppColors.textQuaternary)
                }
                
                Spacer()
                
                // 点赞评论按钮
                Button(action: {
                    if appState.isAuthenticated {
                        HapticFeedback.light()
                        viewModel.likeComment(voteId: comment.id) { success, _, _ in
                            if success {
                                viewModel.loadComments(itemId: comment.itemId ?? 0)
                            }
                        }
                    }
                }) {
                    HStack(spacing: 4) {
                        IconStyle.icon(comment.userLiked == true ? "hand.thumbsup.fill" : "hand.thumbsup", size: 12)
                        Text("\(comment.likeCount ?? 0)")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                    }
                    .foregroundColor(comment.userLiked == true ? AppColors.primary : AppColors.textTertiary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(comment.userLiked == true ? AppColors.primary.opacity(0.1) : Color.clear)
                    .cornerRadius(AppCornerRadius.small)
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            if let content = comment.content, !content.isEmpty {
                Text(content)
                    .font(AppTypography.body)
                    .foregroundColor(AppColors.textPrimary)
                    .lineSpacing(4)
                    .padding(.leading, 44)
            }
        }
        .padding(AppSpacing.md)
        .background(AppColors.cardBackground)
        .cornerRadius(AppCornerRadius.medium)
        .shadow(color: Color.black.opacity(0.02), radius: 4, x: 0, y: 2)
    }
    
    private var displayName: String {
        if comment.isAnonymous == true { return "匿名用户" }
        return comment.author?.name ?? "用户 \(comment.userId ?? "未知")"
    }
}

struct VoteCommentModal: View {
    let voteType: String
    @Binding var comment: String
    @Binding var isAnonymous: Bool
    let onConfirm: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        Text(voteType == "upvote" ? "支持理由" : "反对理由")
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.textSecondary)
                        
                        TextEditor(text: $comment)
                            .frame(minHeight: 120)
                            .padding(AppSpacing.xs)
                            .background(AppColors.background)
                            .cornerRadius(AppCornerRadius.small)
                    }
                    .padding(.vertical, AppSpacing.xs)
                } header: {
                    Text("发表看法")
                }
                
                Section {
                    Toggle("匿名投票", isOn: $isAnonymous)
                        .font(AppTypography.body)
                }
                
                Section {
                    Button(action: onConfirm) {
                        Text("提交投票")
                            .font(AppTypography.bodyBold)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .listRowInsets(EdgeInsets())
                }
            }
            .navigationTitle(voteType == "upvote" ? "支持竞品" : "反对竞品")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消", action: onCancel)
                }
            }
        }
    }
}
