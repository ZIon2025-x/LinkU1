import SwiftUI

struct FleaMarketDetailView: View {
    let itemId: String
    @StateObject private var viewModel = FleaMarketDetailViewModel()
    @EnvironmentObject var appState: AppState
    @State private var showPurchaseSheet = false
    @State private var purchaseType: PurchaseType = .direct
    @State private var proposedPrice: Double?
    @State private var purchaseMessage = ""
    @State private var showLogin = false
    @State private var currentImageIndex = 0
    
    enum PurchaseType {
        case direct
        case negotiate
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // 背景色
            Color(UIColor.systemBackground)
                .ignoresSafeArea()
            
            if viewModel.isLoading && viewModel.item == nil {
                VStack(spacing: 16) {
                ProgressView()
                        .scaleEffect(1.2)
                    Text("加载中...")
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textTertiary)
                }
            } else if let item = viewModel.item {
                ScrollView {
                    VStack(spacing: 0) {
                        // 图片区域
                        imageGallery(item: item)
                        
                        // 内容区域 - 带圆角遮盖图片底部
                        VStack(spacing: 20) {
                            // 价格标题卡片
                            priceAndTitleCard(item: item)
                            
                            // 商品详情卡片
                            detailsCard(item: item)
                            
                            // 卖家信息卡片
                            sellerCard(item: item)
                            
                            // 底部安全区域
                            Spacer().frame(height: 100)
                        }
                        .padding(.top, -20) // 让内容区域覆盖图片底部
                        .background(
                            RoundedRectangle(cornerRadius: 24)
                                .fill(Color(UIColor.systemBackground))
                                .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: -5)
                        )
                    }
                }
                .ignoresSafeArea(edges: .top)
                .scrollIndicators(.hidden)
                
                // 底部操作栏
                bottomBar(item: item)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 16) {
                    ShareLink(item: "查看这个商品: \(viewModel.item?.title ?? "")") {
                        Circle()
                            .fill(Color.black.opacity(0.3))
                            .frame(width: 36, height: 36)
                            .overlay(
                                Image(systemName: "square.and.arrow.up")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.white)
                            )
                    }
                    
                                Button(action: {
                                    if appState.isAuthenticated {
                            viewModel.toggleFavorite(itemId: itemId) { success in
                                if success { HapticFeedback.success() }
                            }
                                    } else {
                                        showLogin = true
                                    }
                                }) {
                        Circle()
                            .fill(Color.black.opacity(0.3))
                            .frame(width: 36, height: 36)
                            .overlay(
                                Group {
                                    if viewModel.isTogglingFavorite {
                                        ProgressView()
                                            .scaleEffect(0.6)
                                            .tint(.white)
                                    } else {
                                        Image(systemName: viewModel.isFavorited ? "heart.fill" : "heart")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(viewModel.isFavorited ? .red : .white)
                                    }
                                }
                            )
                    }
                    .disabled(viewModel.isTogglingFavorite)
                }
            }
        }
        .sheet(isPresented: $showLogin) {
            LoginView()
        }
        .sheet(isPresented: $showPurchaseSheet) {
            if let item = viewModel.item {
            PurchaseSheet(
                    item: item,
                purchaseType: purchaseType,
                proposedPrice: $proposedPrice,
                message: $purchaseMessage,
                onPurchase: {
                    if purchaseType == .direct {
                        viewModel.directPurchase(itemId: itemId) { success in
                                if success { showPurchaseSheet = false }
                        }
                    } else {
                        viewModel.requestPurchase(itemId: itemId, proposedPrice: proposedPrice, message: purchaseMessage.isEmpty ? nil : purchaseMessage) { success in
                            if success {
                                showPurchaseSheet = false
                                proposedPrice = nil
                                purchaseMessage = ""
                            }
                        }
                    }
                }
            )
            }
        }
        .onAppear {
            viewModel.loadItem(itemId: itemId)
        }
    }
    
    // MARK: - 图片画廊
    
    @ViewBuilder
    private func imageGallery(item: FleaMarketItem) -> some View {
        let screenWidth = UIScreen.main.bounds.width
        let imageHeight: CGFloat = screenWidth * 0.9
        
        if let images = item.images, !images.isEmpty {
            ZStack(alignment: .bottom) {
                TabView(selection: $currentImageIndex) {
                    ForEach(Array(images.enumerated()), id: \.offset) { index, imageUrl in
                        AsyncImage(url: imageUrl.toImageURL()) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            case .failure:
                                placeholderImage
                            case .empty:
                                ZStack {
                                    Color(UIColor.secondarySystemBackground)
                                    ProgressView()
                                }
                            @unknown default:
                                placeholderImage
                            }
                        }
                        .frame(width: screenWidth, height: imageHeight)
                        .clipped()
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(height: imageHeight)
                
                // 自定义页面指示器
                if images.count > 1 {
                    HStack(spacing: 6) {
                        ForEach(0..<images.count, id: \.self) { index in
                            Circle()
                                .fill(index == currentImageIndex ? Color.white : Color.white.opacity(0.4))
                                .frame(width: index == currentImageIndex ? 8 : 6, height: index == currentImageIndex ? 8 : 6)
                                .animation(.easeInOut(duration: 0.2), value: currentImageIndex)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Color.black.opacity(0.3)))
                    .padding(.bottom, 40)
                }
                
                // 图片计数
                Text("\(currentImageIndex + 1)/\(images.count)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Color.black.opacity(0.4)))
                    .position(x: screenWidth - 40, y: 60)
            }
        } else {
            placeholderImage
                .frame(height: 280)
        }
    }
    
    private var placeholderImage: some View {
        ZStack {
            LinearGradient(
                colors: [Color(UIColor.secondarySystemBackground), Color(UIColor.tertiarySystemBackground)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            VStack(spacing: 12) {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 48, weight: .light))
                    .foregroundColor(AppColors.textTertiary)
                Text("暂无图片")
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textTertiary)
            }
        }
    }
    
    // MARK: - 价格标题卡片
    
    @ViewBuilder
    private func priceAndTitleCard(item: FleaMarketItem) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // 价格行
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("£")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(Color(red: 0.9, green: 0.3, blue: 0.2))
                
                Text(String(format: "%.2f", item.price))
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(Color(red: 0.9, green: 0.3, blue: 0.2))
                
                Spacer()
                
                // 状态标签
                HStack(spacing: 4) {
                    Circle()
                        .fill(item.status == "active" ? Color.green : Color.gray)
                        .frame(width: 6, height: 6)
                    Text(item.status == "active" ? "在售" : "已下架")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(item.status == "active" ? .green : .gray)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(item.status == "active" ? Color.green.opacity(0.1) : Color.gray.opacity(0.1))
                )
            }
            
            // 标题
            Text(item.title)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(AppColors.textPrimary)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
            
            // 标签行
            HStack(spacing: 8) {
                // 分类标签
                Label(item.category, systemImage: "tag.fill")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(AppColors.primary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(AppColors.primaryLight)
                    .clipShape(Capsule())
                
                // 浏览量
                Label(item.viewCount.formatCount(), systemImage: "eye")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(AppColors.textSecondary)
                
                Spacer()
                
                // 发布时间
                Text(item.createdAt.toDisplayDate())
                    .font(.system(size: 12))
                    .foregroundColor(AppColors.textTertiary)
            }
        }
        .padding(20)
        .background(Color(UIColor.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 4)
        .padding(.horizontal, 16)
    }
    
    // MARK: - 商品详情卡片
    
    @ViewBuilder
    private func detailsCard(item: FleaMarketItem) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // 标题
            HStack {
                RoundedRectangle(cornerRadius: 2)
                    .fill(AppColors.primary)
                    .frame(width: 4, height: 18)
                
                Text("商品详情")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppColors.textPrimary)
            }
            
            // 描述内容
            if let description = item.description, !description.isEmpty {
                Text(description)
                    .font(.system(size: 15))
                    .foregroundColor(AppColors.textSecondary)
                    .lineSpacing(6)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "text.quote")
                        .foregroundColor(AppColors.textTertiary)
                    Text("卖家很懒，什么都没写~")
                        .font(.system(size: 14))
                        .foregroundColor(AppColors.textTertiary)
                        .italic()
                }
                .padding(.vertical, 8)
            }
            
            // 位置信息
            if let location = item.location, !location.isEmpty {
                Divider()
                    .padding(.vertical, 4)
                
                HStack(spacing: 8) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(AppColors.primary)
                    
                    Text(location)
                        .font(.system(size: 14))
                        .foregroundColor(AppColors.textSecondary)
                    
                    Spacer()
                }
            }
        }
        .padding(20)
        .background(Color(UIColor.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 4)
        .padding(.horizontal, 16)
    }
    
    // MARK: - 卖家信息卡片
    
    @ViewBuilder
    private func sellerCard(item: FleaMarketItem) -> some View {
        if let seller = item.seller {
            VStack(spacing: 16) {
                HStack(spacing: 14) {
                    // 卖家头像
                    AvatarView(
                        urlString: seller.avatar,
                        size: 56,
                        placeholder: Image(systemName: "person.circle.fill")
                    )
                    .overlay(
                        Circle()
                            .stroke(Color.white, lineWidth: 3)
                            .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                    )
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(seller.name)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(AppColors.textPrimary)
                        
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.green)
                            Text("活跃卖家")
                                .font(.system(size: 12))
                                .foregroundColor(AppColors.textSecondary)
                        }
                    }
                    
                    Spacer()
                    
                    // 联系卖家按钮
                    Button(action: { /* 联系卖家 */ }) {
                        HStack(spacing: 6) {
                            Image(systemName: "bubble.left.fill")
                                .font(.system(size: 12))
                            Text("联系")
                                .font(.system(size: 14, weight: .medium))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            LinearGradient(
                                colors: [AppColors.primary, AppColors.primary.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(Capsule())
                    }
                }
            }
            .padding(20)
            .background(Color(UIColor.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 4)
            .padding(.horizontal, 16)
        }
    }
    
    // MARK: - 底部操作栏
    
    @ViewBuilder
    private func bottomBar(item: FleaMarketItem) -> some View {
        if item.status == "active" {
            HStack(spacing: 12) {
                // 收藏按钮
                Button(action: {
                    if appState.isAuthenticated {
                        viewModel.toggleFavorite(itemId: itemId) { success in
                            if success { HapticFeedback.success() }
                        }
                    } else {
                        showLogin = true
                    }
                }) {
                    VStack(spacing: 4) {
                        ZStack {
                            if viewModel.isTogglingFavorite {
                                ProgressView()
                                    .scaleEffect(0.7)
                            } else {
                                Image(systemName: viewModel.isFavorited ? "heart.fill" : "heart")
                                    .font(.system(size: 22))
                                    .foregroundColor(viewModel.isFavorited ? .red : AppColors.textSecondary)
                                    .scaleEffect(viewModel.isFavorited ? 1.1 : 1.0)
                                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: viewModel.isFavorited)
                            }
                        }
                        .frame(height: 24)
                        
                        Text("收藏")
                            .font(.system(size: 10))
                            .foregroundColor(viewModel.isFavorited ? .red : AppColors.textTertiary)
                    }
                    .frame(width: 50)
                }
                .disabled(viewModel.isTogglingFavorite)
                
                // 议价按钮
                Button(action: {
                    if appState.isAuthenticated {
                        purchaseType = .negotiate
                        showPurchaseSheet = true
                    } else {
                        showLogin = true
                    }
                }) {
                    Text("议价")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(AppColors.primary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            RoundedRectangle(cornerRadius: 25)
                                .stroke(AppColors.primary, lineWidth: 1.5)
                        )
                }
                
                // 立即购买按钮
                Button(action: {
                    if appState.isAuthenticated {
                        purchaseType = .direct
                        showPurchaseSheet = true
                    } else {
                        showLogin = true
                    }
                }) {
                    Text("立即购买")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.9, green: 0.3, blue: 0.2),
                                    Color(red: 0.95, green: 0.4, blue: 0.3)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 25))
                        .shadow(color: Color(red: 0.9, green: 0.3, blue: 0.2).opacity(0.4), radius: 8, x: 0, y: 4)
                }
                .layoutPriority(1)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 24)
            .background(
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: -5)
                    .ignoresSafeArea(edges: .bottom)
            )
        }
    }
}

// MARK: - 购买弹窗

struct PurchaseSheet: View {
    let item: FleaMarketItem
    let purchaseType: FleaMarketDetailView.PurchaseType
    @Binding var proposedPrice: Double?
    @Binding var message: String
    let onPurchase: () -> Void
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // 商品预览卡片
                    HStack(spacing: 16) {
                    if let images = item.images, let firstImage = images.first {
                        AsyncImage(url: firstImage.toImageURL()) { image in
                                image.resizable().aspectRatio(contentMode: .fill)
                        } placeholder: {
                                Color(UIColor.secondarySystemBackground)
                            }
                            .frame(width: 90, height: 90)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text(item.title)
                                .font(.system(size: 15, weight: .medium))
                                .lineLimit(2)
                                .foregroundColor(AppColors.textPrimary)
                            
                            HStack(alignment: .firstTextBaseline, spacing: 2) {
                                Text("£")
                                    .font(.system(size: 14, weight: .bold))
                                Text(String(format: "%.2f", item.price))
                                    .font(.system(size: 22, weight: .bold, design: .rounded))
                            }
                            .foregroundColor(Color(red: 0.9, green: 0.3, blue: 0.2))
                        }
                        
                        Spacer()
                    }
                    .padding(16)
                    .background(Color(UIColor.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    
                    if purchaseType == .negotiate {
                        // 议价金额输入
                        VStack(alignment: .leading, spacing: 10) {
                            Text("您的出价")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(AppColors.textSecondary)
                            
                            HStack {
                                Text("£")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(AppColors.textSecondary)
                                
                                TextField("输入金额", value: $proposedPrice, format: .number)
                                    .keyboardType(.decimalPad)
                                    .font(.system(size: 24, weight: .bold, design: .rounded))
                            }
                            .padding(16)
                            .background(Color(UIColor.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                    
                    // 留言输入
                    VStack(alignment: .leading, spacing: 10) {
                        Text("给卖家留言（可选）")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(AppColors.textSecondary)
                        
                        TextEditor(text: $message)
                            .frame(height: 100)
                            .padding(12)
                            .scrollContentBackground(.hidden)
                            .background(Color(UIColor.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                Group {
                                    if message.isEmpty {
                                        Text("例如：希望面交、能否包邮等...")
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
                    
                    Spacer(minLength: 40)
                }
                .padding(20)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color(UIColor.systemBackground))
            .navigationTitle(purchaseType == .direct ? "确认购买" : "出价购买")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") { dismiss() }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: onPurchase) {
                        Text(purchaseType == .direct ? "确认" : "提交")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(AppColors.primary)
                            .clipShape(Capsule())
                    }
                }
            }
            .enableSwipeBack()
        }
    }
}
