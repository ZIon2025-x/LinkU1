import SwiftUI
import UIKit

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
    @State private var websiteURL: URL?
    @State private var showCopySuccess = false
    @State private var copiedText = ""
    
    var body: some View {
        ZStack(alignment: .bottom) {
            Color(UIColor.systemBackground)
                .ignoresSafeArea()
            
            if viewModel.isLoading && viewModel.item == nil {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text(LocalizationKey.leaderboardLoading.localized)
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textTertiary)
                }
            } else if let item = viewModel.item {
                ScrollView {
                    VStack(spacing: 0) {
                        // 1. 沉浸式图片区域
                        LeaderboardItemImageSection(images: item.images ?? [], selectedIndex: $selectedImageIndex)
                        
                        // 2. 内容区域
                        VStack(spacing: 24) {
                            // 核心信息卡片 - 浮动圆角样式
                            mainInfoCard(item: item)
                                .padding(.top, -40) // 向上移动覆盖图片更多
                            
                            // 详情卡片
                            descriptionCard(item: item)
                            
                            // 联系信息卡片 (如果有)
                            if hasContactInfo(item: item) {
                                contactCard(item: item)
                            }
                            
                            // 统计数据展示
                            statsSection(item: item)
                            
                            // 留言列表标题
                            commentListHeader()
                            
                            // 留言列表内容
                            commentListContent()
                            
                            // 底部安全区域
                            Spacer().frame(height: 140)
                        }
                    }
                }
                .ignoresSafeArea(edges: .top)
                .scrollIndicators(.hidden)
                
                // 3. 固定底部操作栏
                bottomVoteBar(item: item)
            } else {
                // 如果 item 为 nil 且不在加载中，显示错误状态（不应该发生，但作为保护）
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 48))
                        .foregroundColor(AppColors.textTertiary)
                    Text(LocalizationKey.leaderboardItemLoadFailed.localized)
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
                ShareLink(item: "看看这个竞品: \(viewModel.item?.name ?? "")") {
                    Circle()
                        .fill(Color.black.opacity(0.3))
                        .frame(width: 36, height: 36)
                        .overlay(
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                        )
                }
            }
        }
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
                            viewModel.loadItem(itemId: itemId, preserveItem: true)
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
        .sheet(item: $websiteURL) { url in
            ExternalWebView(url: url, title: LocalizationKey.leaderboardItemWebsite.localized)
        }
        .alert(LocalizationKey.commonCopy.localized, isPresented: $showCopySuccess) {
            Button(LocalizationKey.commonOk.localized, role: .cancel) {
                showCopySuccess = false
            }
        } message: {
            if !copiedText.isEmpty {
                Text(String(format: LocalizationKey.commonCopied.localized, copiedText))
            }
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
            // 已经投过相同的票，打开留言弹窗允许添加或修改留言
            currentVoteType = type
            // 如果已有留言，预填充
            if let item = viewModel.item, let existingComment = item.userVoteComment {
                voteComment = existingComment
            } else {
                voteComment = ""
            }
            // 如果已有匿名设置，预填充
            if let item = viewModel.item, let existingIsAnonymous = item.userVoteIsAnonymous {
                isAnonymous = existingIsAnonymous
            } else {
                isAnonymous = false
            }
            showVoteModal = true
            HapticFeedback.selection()
        } else {
            // 弹出留言弹窗
            currentVoteType = type
            voteComment = ""
            isAnonymous = false
            showVoteModal = true
            HapticFeedback.selection()
        }
    }
    
    private func hasContactInfo(item: LeaderboardItem) -> Bool {
        return (item.address?.isEmpty == false) || (item.phone?.isEmpty == false) || (item.website?.isEmpty == false)
    }
    
    // MARK: - Sub Components
    
    @ViewBuilder
    private func mainInfoCard(item: LeaderboardItem) -> some View {
        VStack(spacing: 16) {
            Text(item.name)
                .font(.system(size: 26, weight: .bold))
                .foregroundColor(AppColors.textPrimary)
                .multilineTextAlignment(.center)
            
            if let submitter = item.submitter {
                NavigationLink(destination: userProfileDestination(user: submitter)) {
                    HStack(spacing: 8) {
                        AvatarView(
                            urlString: submitter.avatar,
                            size: 24,
                            placeholder: Image(systemName: "person.circle.fill")
                        )
                        .clipShape(Circle())
                        
                        Text(String(format: LocalizationKey.leaderboardSubmittedBy.localized, submitter.name))
                            .font(.system(size: 13))
                            .foregroundColor(AppColors.textSecondary)
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10))
                            .foregroundColor(AppColors.textQuaternary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(12)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color(UIColor.systemBackground))
                .shadow(color: Color.black.opacity(0.12), radius: 20, x: 0, y: 8)
        )
        .padding(.horizontal, 20)
    }
    
    @ViewBuilder
    private func descriptionCard(item: LeaderboardItem) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                RoundedRectangle(cornerRadius: 2)
                    .fill(AppColors.primary)
                    .frame(width: 4, height: 16)
                Text(LocalizationKey.leaderboardItemDetail.localized)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppColors.textPrimary)
            }
            
            if let description = item.description, !description.isEmpty {
                Text(description)
                    .font(.system(size: 15))
                    .foregroundColor(AppColors.textSecondary)
                    .lineSpacing(6)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text(LocalizationKey.leaderboardNoDescription.localized)
                    .font(.system(size: 14))
                    .foregroundColor(AppColors.textTertiary)
                    .italic()
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(UIColor.systemBackground))
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 4)
        .padding(.horizontal, 20)
    }
    
    @ViewBuilder
    private func contactCard(item: LeaderboardItem) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                RoundedRectangle(cornerRadius: 2)
                    .fill(AppColors.primary)
                    .frame(width: 4, height: 16)
                Text(LocalizationKey.leaderboardContactLocation.localized)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppColors.textPrimary)
            }
            
            VStack(spacing: 12) {
                if let address = item.address, !address.isEmpty {
                    clickableContactRow(
                        icon: "mappin.circle.fill",
                        text: address,
                        color: .red,
                        onTap: {
                            openInGoogleMaps(address: address)
                        },
                        onLongPress: {
                            Clipboard.copy(address)
                            copiedText = address
                            showCopySuccess = true
                            HapticFeedback.success()
                        }
                    )
                }
                if let phone = item.phone, !phone.isEmpty {
                    clickableContactRow(
                        icon: "phone.circle.fill",
                        text: phone,
                        color: .green,
                        onTap: {
                            openPhoneCall(phone: phone)
                        },
                        onLongPress: {
                            Clipboard.copy(phone)
                            copiedText = phone
                            showCopySuccess = true
                            HapticFeedback.success()
                        }
                    )
                }
                if let website = item.website, !website.isEmpty {
                    if let url = website.safeURL {
                        clickableContactRow(
                            icon: "globe",
                            text: website,
                            color: .blue,
                            onTap: {
                                websiteURL = url
                            },
                            onLongPress: {
                                Clipboard.copy(website)
                                copiedText = website
                                showCopySuccess = true
                                HapticFeedback.success()
                            }
                        )
                    } else {
                        // 如果无法解析为 URL，仍然可以复制
                        clickableContactRow(
                            icon: "globe",
                            text: website,
                            color: .blue,
                            onTap: nil,
                            onLongPress: {
                                Clipboard.copy(website)
                                copiedText = website
                                showCopySuccess = true
                                HapticFeedback.success()
                            }
                        )
                    }
                }
            }
        }
        .padding(20)
        .background(Color(UIColor.systemBackground))
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 4)
        .padding(.horizontal, 20)
    }
    
    @ViewBuilder
    private func contactRow(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(color)
            Text(text)
                .font(.system(size: 14))
                .foregroundColor(AppColors.textSecondary)
                .lineLimit(2)
            Spacer()
        }
    }
    
    /// 可点击的联系信息行 - 支持点击和长按复制
    @ViewBuilder
    private func clickableContactRow(
        icon: String,
        text: String,
        color: Color,
        onTap: (() -> Void)?,
        onLongPress: @escaping () -> Void
    ) -> some View {
        Button(action: {
            onTap?()
        }) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(color)
                    .frame(width: 28, height: 28)
                    .background(color.opacity(0.15))
                    .clipShape(Circle())
                
                Text(text)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                Spacer()
                
                // 显示操作提示图标（无文字）
                HStack(spacing: 8) {
                    if onTap != nil {
                        Image(systemName: "arrow.up.right.square.fill")
                            .font(.system(size: 14))
                            .foregroundColor(AppColors.primary)
                    }
                    Image(systemName: "doc.on.doc.fill")
                        .font(.system(size: 13))
                        .foregroundColor(AppColors.textSecondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(AppColors.primary.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(AppColors.primary.opacity(0.4), lineWidth: 1.5)
                    )
            )
            .shadow(color: AppColors.primary.opacity(0.1), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.5)
                .onEnded { _ in
                    onLongPress()
                }
        )
    }
    
    // MARK: - Contact Actions
    
    /// 在 Google 地图中打开地址导航
    private func openInGoogleMaps(address: String) {
        // 对地址进行 URL 编码
        guard let encodedAddress = address.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return
        }
        
        // Google Maps URL Scheme: comgooglemaps://
        // 如果安装了 Google Maps，使用 URL Scheme
        let urlString = "comgooglemaps://?q=\(encodedAddress)&directionsmode=driving"
        if let url = URL(string: urlString),
           UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        } else {
            // 如果没有安装 Google Maps，使用网页版
            let webUrlString = "https://www.google.com/maps/search/?api=1&query=\(encodedAddress)"
            if let url = URL(string: webUrlString) {
                UIApplication.shared.open(url)
            }
        }
    }
    
    /// 拨打电话
    private func openPhoneCall(phone: String) {
        // 清理电话号码，移除空格和特殊字符
        let cleanedPhone = phone.replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: "(", with: "")
            .replacingOccurrences(of: ")", with: "")
        
        // 使用 tel: URL Scheme 拨打电话
        if let phoneURL = URL(string: "tel://\(cleanedPhone)") {
            if UIApplication.shared.canOpenURL(phoneURL) {
                UIApplication.shared.open(phoneURL)
            }
        }
    }
    
    @ViewBuilder
    private func statsSection(item: LeaderboardItem) -> some View {
        HStack {
            Spacer()
            VStack(spacing: 4) {
                Text("\(netVotes)")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(netVotes >= 0 ? AppColors.success : AppColors.error)
                Text(LocalizationKey.leaderboardCurrentScore.localized)
                    .font(.system(size: 12))
                    .foregroundColor(AppColors.textTertiary)
            }
            Spacer()
            Divider().frame(height: 30)
            Spacer()
            VStack(spacing: 4) {
                Text("\(upvotes + downvotes)")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(AppColors.textPrimary)
                Text(LocalizationKey.leaderboardTotalVotesCount.localized)
                    .font(.system(size: 12))
                    .foregroundColor(AppColors.textTertiary)
            }
            Spacer()
        }
        .padding(.vertical, 16)
    }
    
    @ViewBuilder
    private func commentListHeader() -> some View {
        HStack {
            Image(systemName: "bubble.left.and.bubble.right.fill")
                .foregroundColor(AppColors.primary)
            Text(LocalizationKey.leaderboardFeaturedComments.localized)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(AppColors.textPrimary)
            
            Spacer()
            
            Text("\(viewModel.comments.count)")
                .font(.system(size: 13))
                .foregroundColor(AppColors.textTertiary)
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
    }
    
    @ViewBuilder
    private func commentListContent() -> some View {
        if viewModel.comments.isEmpty {
            VStack(spacing: 16) {
                Image(systemName: "quote.bubble")
                    .font(.system(size: 48, weight: .light))
                    .foregroundColor(AppColors.textQuaternary)
                Text(LocalizationKey.leaderboardNoComments.localized)
                    .font(.system(size: 14))
                    .foregroundColor(AppColors.textTertiary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 60)
            .background(Color(UIColor.secondarySystemBackground).opacity(0.5))
            .cornerRadius(24)
            .padding(.horizontal, 20)
        } else {
            VStack(spacing: 16) {
                ForEach(viewModel.comments) { comment in
                    LeaderboardCommentCard(comment: comment, viewModel: viewModel)
                        .environmentObject(appState)
                }
            }
            .padding(.horizontal, 20)
        }
    }
    
    @ViewBuilder
    private func bottomVoteBar(item: LeaderboardItem) -> some View {
        HStack(spacing: 12) {
            // 反对按钮
            Button(action: { handleVoteAction(type: "downvote") }) {
                HStack(spacing: 8) {
                    Image(systemName: voteType == "downvote" ? "hand.thumbsdown.fill" : "hand.thumbsdown")
                    Text(LocalizationKey.leaderboardOppose.localized)
                        .fontWeight(.semibold)
                    if downvotes > 0 {
                        Text("\(downvotes)")
                            .font(.system(size: 12, design: .rounded))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.white.opacity(0.2))
                            .cornerRadius(8)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(voteType == "downvote" ? AppColors.error : AppColors.error.opacity(0.1))
                .foregroundColor(voteType == "downvote" ? .white : AppColors.error)
                .cornerRadius(25)
            }
            
            // 支持按钮
            Button(action: { handleVoteAction(type: "upvote") }) {
                HStack(spacing: 8) {
                    Image(systemName: voteType == "upvote" ? "hand.thumbsup.fill" : "hand.thumbsup")
                    Text(LocalizationKey.leaderboardSupport.localized)
                        .fontWeight(.semibold)
                    if upvotes > 0 {
                        Text("\(upvotes)")
                            .font(.system(size: 12, design: .rounded))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.white.opacity(0.2))
                            .cornerRadius(8)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(voteType == "upvote" ? AppColors.success : AppColors.success.opacity(0.1))
                .foregroundColor(voteType == "upvote" ? .white : AppColors.success)
                .cornerRadius(25)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 24)
        .background(
            Rectangle()
                .fill(.ultraThinMaterial)
                .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: -5)
                .ignoresSafeArea(edges: .bottom)
        )
    }
}

// MARK: - Image Section

struct LeaderboardItemImageSection: View {
    let images: [String]
    @Binding var selectedIndex: Int
    
    var body: some View {
        let screenWidth = UIScreen.main.bounds.width
        let imageHeight: CGFloat = screenWidth * 0.85
        
        if !images.isEmpty {
            ZStack(alignment: .bottom) {
                TabView(selection: $selectedIndex) {
                    ForEach(Array(images.enumerated()), id: \.offset) { index, imageUrl in
                        AsyncImageView(urlString: imageUrl, placeholder: Image(systemName: "photo.fill"))
                            .aspectRatio(contentMode: .fill)
                            .frame(width: screenWidth, height: imageHeight)
                            .clipped()
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(height: imageHeight)
                
                // 自定义指示器
                if images.count > 1 {
                    HStack(spacing: 6) {
                        ForEach(0..<images.count, id: \.self) { index in
                            Circle()
                                .fill(selectedIndex == index ? Color.white : Color.white.opacity(0.4))
                                .frame(width: selectedIndex == index ? 8 : 6, height: selectedIndex == index ? 8 : 6)
                                .animation(.easeInOut(duration: 0.2), value: selectedIndex)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color.black.opacity(0.3)))
                    .padding(.bottom, 50) // 避开卡片覆盖
                }
            }
        } else {
            ZStack {
                LinearGradient(
                    colors: [AppColors.primaryLight, AppColors.primaryLight.opacity(0.5)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                VStack(spacing: 12) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 40))
                        .foregroundColor(AppColors.primary.opacity(0.3))
                    Text(LocalizationKey.leaderboardNoImages.localized)
                        .font(.system(size: 12))
                        .foregroundColor(AppColors.primary.opacity(0.4))
                }
            }
            .frame(width: screenWidth, height: 200)
        }
    }
}

// MARK: - Comment Card

struct LeaderboardCommentCard: View {
    let comment: LeaderboardItemComment
    let viewModel: LeaderboardItemDetailViewModel
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                AvatarView(
                    urlString: comment.isAnonymous == true ? nil : comment.author?.avatar,
                    size: 40,
                    avatarType: comment.isAnonymous == true ? .anonymous : nil
                )
                .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(displayName)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(AppColors.textPrimary)
                        
                        if let voteType = comment.voteType {
                            Label {
                                Text(voteType == "upvote" ? LocalizationKey.leaderboardSupport.localized : LocalizationKey.leaderboardOppose.localized)
                                    .font(.system(size: 10, weight: .bold))
                            } icon: {
                                Image(systemName: voteType == "upvote" ? "hand.thumbsup.fill" : "hand.thumbsdown.fill")
                                    .font(.system(size: 10))
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background((voteType == "upvote" ? AppColors.success : AppColors.error).opacity(0.1))
                            .foregroundColor(voteType == "upvote" ? AppColors.success : AppColors.error)
                            .cornerRadius(4)
                        }
                    }
                    
                    Text(DateFormatterHelper.shared.formatTime(comment.createdAt))
                        .font(.system(size: 11))
                        .foregroundColor(AppColors.textQuaternary)
                }
                
                Spacer()
                
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
                        Image(systemName: comment.userLiked == true ? "hand.thumbsup.fill" : "hand.thumbsup")
                            .font(.system(size: 12))
                        Text((comment.likeCount ?? 0).formatCount())
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                    }
                    .foregroundColor(comment.userLiked == true ? AppColors.primary : AppColors.textTertiary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(comment.userLiked == true ? AppColors.primary.opacity(0.1) : Color.clear)
                    .cornerRadius(8)
                }
            }
            
            if let content = comment.content, !content.isEmpty {
                Text(content)
                    .font(.system(size: 15))
                    .foregroundColor(AppColors.textPrimary)
                    .lineSpacing(4)
                    .padding(.leading, 52)
            }
        }
        .padding(16)
        .background(Color(UIColor.secondarySystemBackground).opacity(0.3))
        .cornerRadius(20)
    }
    
    private var displayName: String {
        if comment.isAnonymous == true { return LocalizationKey.leaderboardAnonymousUser.localized }
        return comment.author?.name ?? LocalizationKey.leaderboardUser.localized
    }
}

// MARK: - Vote Modal

struct VoteCommentModal: View {
    let voteType: String
    @Binding var comment: String
    @Binding var isAnonymous: Bool
    let onConfirm: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        NavigationView {
            KeyboardAvoidingScrollView(extraPadding: 20) {
                VStack(spacing: 24) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(voteType == "upvote" ? LocalizationKey.leaderboardSupportReason.localized : LocalizationKey.leaderboardOpposeReason.localized)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(AppColors.textSecondary)
                        
                        TextEditor(text: $comment)
                            .frame(height: 150)
                            .padding(12)
                            .scrollContentBackground(.hidden)
                            .background(Color(UIColor.secondarySystemBackground))
                            .cornerRadius(12)
                            .overlay(
                                Group {
                                    if comment.isEmpty {
                                        Text(LocalizationKey.leaderboardWriteReason.localized)
                                            .font(.system(size: 14))
                                            .foregroundColor(AppColors.textTertiary)
                                            .padding(.leading, 16)
                                            .padding(.top, 20)
                                            .allowsHitTesting(false)
                                    }
                                },
                                alignment: .topLeading
                            )
                    }
                    
                    Toggle(isOn: $isAnonymous) {
                        HStack {
                            Image(systemName: isAnonymous ? "eye.slash.fill" : "eye.fill")
                            Text(LocalizationKey.leaderboardAnonymousVote.localized)
                                .font(.system(size: 15))
                        }
                    }
                    .tint(AppColors.primary)
                    .padding(.horizontal, 4)
                    
                    Spacer(minLength: 40)
                    
                    Button(action: onConfirm) {
                        Text(LocalizationKey.leaderboardSubmitVote.localized)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(voteType == "upvote" ? AppColors.success : AppColors.error)
                            .cornerRadius(27)
                            .shadow(color: (voteType == "upvote" ? AppColors.success : AppColors.error).opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                }
                .padding(24)
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(voteType == "upvote" ? LocalizationKey.leaderboardSupport.localized : LocalizationKey.leaderboardOppose.localized)
            .navigationBarTitleDisplayMode(.inline)
            .enableSwipeBack()
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消", action: onCancel)
                }
            }
        }
    }
}
