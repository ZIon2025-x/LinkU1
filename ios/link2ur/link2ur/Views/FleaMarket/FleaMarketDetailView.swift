import SwiftUI

struct FleaMarketDetailView: View {
    let itemId: String
    @StateObject private var viewModel = FleaMarketDetailViewModel()
    @EnvironmentObject var appState: AppState
    @State private var showPurchaseSheet = false
    @State private var showLogin = false
    @State private var currentImageIndex = 0
    @State private var isRefreshing = false
    @State private var showRefreshSuccess = false
    @State private var showPaymentView = false
    @State private var paymentTaskId: Int?
    @State private var paymentClientSecret: String?
    @State private var paymentAmount: Double = 0
    @State private var paymentCustomerId: String?
    @State private var paymentEphemeralKeySecret: String?
    @State private var paymentExpiresAt: String?
    @State private var isPreparingPayment = false
    @State private var showNegotiateSuccess = false
    @State private var isProcessingPurchase = false  // 购买处理中状态
    @State private var pendingShowPaymentView = false  // 等待显示支付视图的标志
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // 背景色
            Color(UIColor.systemBackground)
                .ignoresSafeArea()
            
            if viewModel.isLoading && viewModel.item == nil {
                VStack(spacing: 16) {
                ProgressView()
                        .scaleEffect(1.2)
                    Text(LocalizationKey.fleaMarketLoading.localized)
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textTertiary)
                }
            } else if let item = viewModel.item {
                // 显示商品内容
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
                            
                            // 购买申请列表（仅商品所有者可见）
                            if isSeller && item.status == "active" {
                                purchaseRequestsCard(item: item)
                            }
                            
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
            } else {
                // 如果 item 为 nil 且不在加载中，显示错误状态（不应该发生，但作为保护）
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 48))
                        .foregroundColor(AppColors.textTertiary)
                    Text(LocalizationKey.fleaMarketLoadFailed.localized)
                        .font(AppTypography.body)
                        .foregroundColor(AppColors.textSecondary)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 16) {
                    ShareLink(item: "\(LocalizationKey.fleaMarketViewItem.localized): \(viewModel.item?.title ?? "")") {
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
        .sheet(isPresented: $showPurchaseSheet, onDismiss: {
            // 当购买确认页面完全关闭后，检查是否需要显示支付页面
            if pendingShowPaymentView {
                pendingShowPaymentView = false
                isProcessingPurchase = false
                // 使用短暂延迟确保 sheet dismiss 完全完成
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    showPaymentView = true
                }
            }
        }) {
            if let item = viewModel.item {
                PurchaseDetailView(
                    item: item,
                    itemId: itemId,
                    viewModel: viewModel,
                    onPurchaseComplete: { purchaseData in
                        // 如果返回了支付信息，先设置支付参数，然后关闭购买页面
                        if let data = purchaseData,
                           data.taskStatus == "pending_payment",
                           let clientSecret = data.clientSecret {
                            // 转换 taskId（支持字符串和数字格式）
                            let taskIdInt: Int?
                            if let taskIdValue = Int(data.taskId) {
                                taskIdInt = taskIdValue
                            } else {
                                Logger.error("无法转换 taskId 为 Int: \(data.taskId)", category: .network)
                                taskIdInt = nil
                            }
                            
                            guard let taskId = taskIdInt else {
                                Logger.error("taskId 转换失败，无法显示支付页面", category: .network)
                                isProcessingPurchase = false
                                showPurchaseSheet = false
                                return
                            }
                            
                            // 先设置支付参数（在关闭购买页面前）
                            paymentTaskId = taskId
                            paymentClientSecret = clientSecret
                            // 计算支付金额（amount 是分为单位，需要转换为元）
                            if let amount = data.amount {
                                paymentAmount = Double(amount) / 100.0
                            } else if let amountDisplay = data.amountDisplay, let amountValue = Double(amountDisplay) {
                                paymentAmount = amountValue
                            } else {
                                paymentAmount = 0.0
                            }
                            paymentCustomerId = data.customerId
                            paymentEphemeralKeySecret = data.ephemeralKeySecret
                            paymentExpiresAt = data.paymentExpiresAt
                            
                            // 标记需要在 sheet 关闭后显示支付页面
                            pendingShowPaymentView = true
                            isProcessingPurchase = true
                            
                            // 关闭购买页面（支付页面将在 onDismiss 回调中显示）
                            showPurchaseSheet = false
                        } else if purchaseData != nil {
                            // 如果没有支付信息，可能是直接购买成功（不需要支付）
                            Logger.debug("直接购买成功，无需支付", category: .network)
                            isProcessingPurchase = false
                            showPurchaseSheet = false
                            // 刷新商品信息
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                CacheManager.shared.invalidateFleaMarketCache()
                                viewModel.loadItem(itemId: itemId, preserveItem: true)
                            }
                        } else {
                            // 购买失败，关闭购买页面
                            isProcessingPurchase = false
                            showPurchaseSheet = false
                        }
                    },
                    onNegotiateComplete: {
                        showPurchaseSheet = false
                        // 议价请求已发送，显示成功提示
                        HapticFeedback.success()
                        showNegotiateSuccess = true
                    }
                )
            }
        }
        .alert(LocalizationKey.successRefreshSuccess.localized, isPresented: $showRefreshSuccess) {
            Button(LocalizationKey.commonOk.localized, role: .cancel) { }
        } message: {
            Text(LocalizationKey.successRefreshSuccessMessage.localized)
        }
        .alert(LocalizationKey.fleaMarketNegotiateRequestSent.localized, isPresented: $showNegotiateSuccess) {
            Button(LocalizationKey.commonOk.localized, role: .cancel) { }
        } message: {
            Text(LocalizationKey.fleaMarketNegotiateRequestSentMessage.localized)
        }
        .sheet(isPresented: $showPaymentView) {
            if let taskId = paymentTaskId, let clientSecret = paymentClientSecret {
                StripePaymentView(
                    taskId: taskId,
                    amount: paymentAmount,
                    clientSecret: clientSecret,
                    customerId: paymentCustomerId,
                    ephemeralKeySecret: paymentEphemeralKeySecret,
                    taskTitle: viewModel.item?.title,
                    paymentExpiresAt: paymentExpiresAt ?? nil,  // 使用从商品详情或购买响应中获取的过期时间
                    onPaymentSuccess: {
                        showPaymentView = false
                        // 支付成功后，清除缓存并刷新商品信息
                        // 使用重试机制确保状态正确更新
                        refreshItemAfterPayment(attempt: 1, maxAttempts: 5)
                    }
                )
            }
        }
        .task(id: itemId) {
            print("🔍 [FleaMarketDetailView] task 开始 - itemId: \(itemId), 时间: \(Date())")
            // 使用 .task(id:) 确保只在 itemId 变化时重新加载
            // 添加延迟，避免与导航动画冲突
            // 使用 _Concurrency.Task 明确指定 Swift 并发框架的 Task（因为项目中存在 Task 模型）
            try? await _Concurrency.Task.sleep(nanoseconds: 100_000_000) // 0.1秒延迟
            // 只有在 item 为空或 itemId 变化时才加载
            if viewModel.item == nil || viewModel.item?.id != itemId {
                print("🔍 [FleaMarketDetailView] 开始加载商品: \(itemId)")
                viewModel.loadItem(itemId: itemId)
            } else {
                print("🔍 [FleaMarketDetailView] 商品已存在，跳过加载: \(itemId)")
            }
        }
        .onAppear {
            print("🔍 [FleaMarketDetailView] onAppear - itemId: \(itemId), 时间: \(Date())")
            print("🔍 [FleaMarketDetailView] 当前导航栈状态 - appState.shouldResetHomeView: \(appState.shouldResetHomeView)")
            print("🔍 [FleaMarketDetailView] viewModel.item: \(viewModel.item?.id ?? "nil")")
        }
        .onDisappear {
            print("🔍 [FleaMarketDetailView] onDisappear - itemId: \(itemId), 时间: \(Date())")
            print("🔍 [FleaMarketDetailView] 视图消失原因追踪")
            // 视图消失时清理，释放内存
            // 注意：不要清空 item，因为返回时可能需要显示
        }
        .onChange(of: appState.shouldResetHomeView) { shouldReset in
            print("🔍 [FleaMarketDetailView] appState.shouldResetHomeView 变化: \(shouldReset), 时间: \(Date())")
        }
        .onChange(of: appState.isAuthenticated) { isAuthenticated in
            print("🔍 [FleaMarketDetailView] appState.isAuthenticated 变化: \(isAuthenticated), 时间: \(Date())")
        }
        .onChange(of: appState.currentUser?.id) { userId in
            print("🔍 [FleaMarketDetailView] appState.currentUser?.id 变化: \(userId ?? "nil"), 时间: \(Date())")
        }
        .onChange(of: viewModel.item?.id) { itemId in
            print("🔍 [FleaMarketDetailView] viewModel.item?.id 变化: \(itemId ?? "nil"), 时间: \(Date())")
        }
    }
    
    // MARK: - 距离自动下架天数视图
    
    @ViewBuilder
    private func daysUntilExpiryView(daysRemaining: Int?) -> some View {
        if let daysRemaining = daysRemaining {
            let (backgroundColor, textColor, borderColor): (Color, Color, Color) = {
                if daysRemaining <= 3 {
                    return (Color.red.opacity(0.1), Color.red, Color.red.opacity(0.3))
                } else if daysRemaining <= 7 {
                    return (Color.orange.opacity(0.1), Color.orange, Color.orange.opacity(0.3))
                } else {
                    return (Color.blue.opacity(0.1), Color.blue, Color.blue.opacity(0.3))
                }
            }()
            
            HStack(spacing: 8) {
                Image(systemName: daysRemaining <= 3 ? "exclamationmark.triangle.fill" : "clock.fill")
                    .font(.system(size: 14))
                    .foregroundColor(textColor)
                
                if daysRemaining > 0 {
                    Text(String(format: LocalizationKey.fleaMarketAutoRemovalDays.localized, daysRemaining))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(textColor)
                } else {
                    Text(LocalizationKey.fleaMarketAutoRemovalSoon.localized)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(textColor)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(backgroundColor)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(borderColor, lineWidth: 1)
            )
            .cornerRadius(8)
            .padding(.top, 8)
        }
    }
    
    
    // MARK: - 图片画廊
    
    @ViewBuilder
    private func imageGallery(item: FleaMarketItem) -> some View {
        if let images = item.images, !images.isEmpty {
            // 使用 maxWidth + aspectRatio 替代 UIScreen.main.bounds，避免弹窗出现时图片右侧和底部被裁切
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
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipped()
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(maxWidth: .infinity)
                .aspectRatio(10 / 9, contentMode: .fit)
                
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
                
            }
            .frame(maxWidth: .infinity)
            .aspectRatio(10 / 9, contentMode: .fit)
            .overlay(alignment: .topTrailing) {
                Text("\(currentImageIndex + 1)/\(images.count)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Color.black.opacity(0.4)))
                    .padding(24)
            }
        } else {
            placeholderImage
                .frame(maxWidth: .infinity)
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
                Text(LocalizationKey.fleaMarketNoImage.localized)
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
                        .fill(itemStatusColor(item.status))
                        .frame(width: 6, height: 6)
                    Text(itemStatusText(item.status))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(itemStatusColor(item.status))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(itemStatusColor(item.status).opacity(0.1))
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
                
                // 收藏数
                Label("\(item.favoriteCount)", systemImage: "heart.fill")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(AppColors.textSecondary)
                
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
            
            // 卖家视角：显示距离自动下架还有多少天（从后端获取）
            if isSeller {
                daysUntilExpiryView(daysRemaining: item.daysUntilAutoDelist)
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
                
                Text(LocalizationKey.fleaMarketProductDetail.localized)
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
                    Text(LocalizationKey.fleaMarketNoDescription.localized)
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
                            Text(LocalizationKey.fleaMarketActiveSeller.localized)
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
                            Text(LocalizationKey.fleaMarketContactSeller.localized)
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
    
    // MARK: - 支付成功后刷新商品状态
    
    /// 支付成功后刷新商品信息（带重试机制）
    private func refreshItemAfterPayment(attempt: Int, maxAttempts: Int) {
        guard attempt <= maxAttempts else {
            Logger.warning("支付成功后刷新商品状态失败，已达到最大重试次数", category: .network)
            return
        }
        
        // 延迟刷新，等待后端 webhook 处理完成
        let delay = min(Double(attempt * attempt), 5.0) // 指数退避，最大5秒
        
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            // 清除跳蚤市场缓存，确保获取最新状态
            CacheManager.shared.invalidateFleaMarketCache()
            
            // 重新加载商品信息
            self.viewModel.loadItem(itemId: self.itemId, preserveItem: true)
            
            // 检查商品状态是否已更新
            if let item = self.viewModel.item {
                // 如果状态已更新为 sold 或 delisted，说明支付成功
                if item.status == "sold" || item.status == "delisted" {
                    Logger.success("商品状态已更新: \(item.status)", category: .network)
                    HapticFeedback.success()
                    return
                }
            }
            
            // 如果状态还未更新，继续重试
            if attempt < maxAttempts {
                self.refreshItemAfterPayment(attempt: attempt + 1, maxAttempts: maxAttempts)
            } else {
                Logger.warning("支付成功后商品状态未更新，可能后端处理延迟", category: .network)
            }
        }
    }
    
    // MARK: - 购买申请列表卡片
    
    @ViewBuilder
    private func purchaseRequestsCard(item: FleaMarketItem) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack {
                IconStyle.icon("person.2.fill", size: 18)
                    .foregroundColor(AppColors.primary)
                Text("购买申请 (\(viewModel.purchaseRequests.count))")
                    .font(AppTypography.title3)
                    .foregroundColor(AppColors.textPrimary)
            }
            
            if viewModel.isLoadingPurchaseRequests {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(AppSpacing.xl)
            } else if viewModel.purchaseRequests.isEmpty {
                VStack(spacing: AppSpacing.sm) {
                    IconStyle.icon("tray", size: 40)
                        .foregroundColor(AppColors.textQuaternary)
                    Text("暂无购买申请")
                        .font(AppTypography.body)
                        .foregroundColor(AppColors.textTertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(AppSpacing.xl)
                .background(AppColors.background.opacity(0.5))
                .cornerRadius(AppCornerRadius.medium)
            } else {
                VStack(spacing: AppSpacing.md) {
                    ForEach(viewModel.purchaseRequests) { request in
                        PurchaseRequestCard(
                            request: request,
                            itemId: itemId,
                            onApprove: {
                                viewModel.approvePurchaseRequest(requestId: request.id) { data in
                                    if data != nil {
                                        // 同意成功，刷新列表
                                        viewModel.loadPurchaseRequests(itemId: itemId)
                                        // 如果返回了支付信息，可以在这里处理支付跳转
                                        // 目前由推送通知处理跳转
                                    }
                                }
                            },
                            onReject: {
                                viewModel.rejectPurchaseRequest(itemId: itemId, requestId: request.id) { success in
                                    if success {
                                        // 拒绝成功，刷新列表
                                        viewModel.loadPurchaseRequests(itemId: itemId)
                                    }
                                }
                            }
                        )
                    }
                }
            }
        }
        .padding(20)
        .background(Color(UIColor.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 4)
        .padding(.horizontal, 16)
        .onAppear {
            // 首次加载时获取购买申请列表
            if viewModel.purchaseRequests.isEmpty {
                viewModel.loadPurchaseRequests(itemId: itemId)
            }
        }
    }
    
    // MARK: - 底部操作栏
    
    private var isSeller: Bool {
        guard let item = viewModel.item,
              let currentUserId = appState.currentUser?.id else {
            return false
        }
        return item.sellerId == currentUserId
    }
    
    // 商品状态颜色（辅助函数）
    private func itemStatusColor(_ status: String) -> Color {
        switch status {
        case "active":
            return .green
        case "sold":
            return .blue
        case "delisted":
            return .gray
        default:
            return .gray
        }
    }
    
    // 商品状态文本（辅助函数）
    private func itemStatusText(_ status: String) -> String {
        switch status {
        case "active":
            return LocalizationKey.fleaMarketStatusActive.localized
        case "sold":
            return LocalizationKey.myItemsStatusSold.localized
        case "delisted":
            return LocalizationKey.fleaMarketStatusDelisted.localized
        default:
            return LocalizationKey.fleaMarketStatusDelisted.localized
        }
    }
    
    @ViewBuilder
    private func bottomBar(item: FleaMarketItem) -> some View {
        // 只有商品状态为 active 时才显示购买按钮
        if item.status == "active" {
            HStack(spacing: 12) {
                // 如果是卖家，显示编辑和刷新按钮
                if isSeller {
                    // 刷新按钮 - 使用更紧凑的布局
                    Button(action: {
                        isRefreshing = true
                        viewModel.refreshItem(itemId: itemId) { success in
                            DispatchQueue.main.async {
                                isRefreshing = false
                                if success {
                                    showRefreshSuccess = true
                                    HapticFeedback.success()
                                }
                            }
                        }
                    }) {
                        HStack(spacing: 6) {
                            if isRefreshing {
                                ProgressView()
                                    .tint(.white)
                                    .scaleEffect(0.7)
                            } else {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 15, weight: .semibold))
                            }
                            Text(isRefreshing ? LocalizationKey.fleaMarketRefreshing.localized : LocalizationKey.fleaMarketRefresh.localized)
                                .font(.system(size: 15, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(minWidth: 100)
                        .frame(height: 50)
                        .padding(.horizontal, 16)
                        .background(
                            LinearGradient(
                                colors: [Color.orange, Color.orange.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 25))
                        .shadow(color: Color.orange.opacity(0.4), radius: 8, x: 0, y: 4)
                    }
                    .disabled(isRefreshing)
                    
                    // 编辑按钮
                    NavigationLink(destination: EditFleaMarketItemView(itemId: itemId, item: item)) {
                        HStack(spacing: 8) {
                            Image(systemName: "pencil")
                                .font(.system(size: 16, weight: .semibold))
                            Text(LocalizationKey.fleaMarketEditItemTitle.localized)
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            LinearGradient(
                                colors: [AppColors.primary, AppColors.primary.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 25))
                        .shadow(color: AppColors.primary.opacity(0.4), radius: 8, x: 0, y: 4)
                    }
                } else {
                    // 检查是否有未付款的购买
                    if let pendingTaskId = item.pendingPaymentTaskId,
                       let clientSecret = item.pendingPaymentClientSecret {
                        // 有未付款的购买，显示继续支付按钮
                        Button(action: {
                            if appState.isAuthenticated {
                                // 立即显示加载状态，提升用户体验
                                isPreparingPayment = true
                                
                                // 在后台线程准备支付参数，避免阻塞主线程
                                // 使用 [weak viewModel] 避免页面已退出时更新 @State 导致闪退
                                DispatchQueue.main.async { [weak viewModel] in
                                    guard viewModel != nil else { return }
                                    // 设置支付参数
                                    paymentTaskId = pendingTaskId
                                    paymentClientSecret = clientSecret
                                    // 计算支付金额
                                    if let amount = item.pendingPaymentAmount {
                                        paymentAmount = Double(amount) / 100.0
                                    } else if let amountDisplay = item.pendingPaymentAmountDisplay, let amountValue = Double(amountDisplay) {
                                        paymentAmount = amountValue
                                    } else {
                                        paymentAmount = item.price
                                    }
                                    paymentCustomerId = item.pendingPaymentCustomerId
                                    paymentEphemeralKeySecret = item.pendingPaymentEphemeralKeySecret
                                    paymentExpiresAt = item.pendingPaymentExpiresAt
                                    
                                    // 短暂延迟后显示支付页面，让加载状态可见
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak viewModel] in
                                        guard viewModel != nil else { return }
                                        isPreparingPayment = false
                                        showPaymentView = true
                                    }
                                }
                            } else {
                                showLogin = true
                            }
                        }) {
                            HStack(spacing: 8) {
                                if isPreparingPayment {
                                    ProgressView()
                                        .tint(.white)
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "creditcard.fill")
                                        .font(.system(size: 16, weight: .semibold))
                                }
                                Text(isPreparingPayment ? "准备中..." : "继续支付")
                                    .font(.system(size: 16, weight: .semibold))
                            }
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
                        .disabled(isPreparingPayment)
                    } else {
                        // 没有未付款的购买，显示统一的购买按钮
                        Button(action: {
                            if appState.isAuthenticated {
                                showPurchaseSheet = true
                            } else {
                                showLogin = true
                            }
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "cart.fill")
                                    .font(.system(size: 16, weight: .semibold))
                                Text(LocalizationKey.fleaMarketBuyNow.localized)
                                    .font(.system(size: 16, weight: .semibold))
                            }
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
                    }
                }
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

// MARK: - 购买详情页

struct PurchaseDetailView: View {
    let item: FleaMarketItem
    let itemId: String
    let viewModel: FleaMarketDetailViewModel
    let onPurchaseComplete: (DirectPurchaseResponse.DirectPurchaseData?) -> Void
    let onNegotiateComplete: () -> Void
    
    @Environment(\.dismiss) var dismiss
    @State private var wantsNegotiate = false
    @State private var proposedPrice: Double?
    @State private var message = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var infoMessage: String? // 信息提示（非错误）
    
    var body: some View {
        NavigationView {
            ZStack {
                KeyboardAvoidingScrollView(extraPadding: 20) {
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
                    
                    // 我要议价复选框
                    VStack(alignment: .leading, spacing: 12) {
                        // 检查用户是否已有待处理的议价请求
                        if let requestStatus = item.userPurchaseRequestStatus,
                           (requestStatus == "pending" || requestStatus == "seller_negotiating") {
                            // 显示等待卖家确认的状态
                            HStack(spacing: 8) {
                                Image(systemName: "clock.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(AppColors.primary)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("等待卖家确认")
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundColor(AppColors.textPrimary)
                                    
                                    if let proposedPrice = item.userPurchaseRequestProposedPrice {
                                        Text("议价金额：£\(String(format: "%.2f", proposedPrice))")
                                            .font(.system(size: 13))
                                            .foregroundColor(AppColors.textSecondary)
                                    }
                                }
                                
                                Spacer()
                            }
                            .padding(12)
                            .background(AppColors.primary.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        } else {
                            // 正常的议价复选框
                            Toggle(isOn: $wantsNegotiate) {
                                HStack(spacing: 8) {
                                    Image(systemName: "hand.raised.fill")
                                        .font(.system(size: 16))
                                        .foregroundColor(AppColors.primary)
                                    Text(LocalizationKey.taskApplicationIWantToNegotiatePrice.localized)
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundColor(AppColors.textPrimary)
                                }
                            }
                            .toggleStyle(SwitchToggleStyle(tint: AppColors.primary))
                        }
                        
                        if wantsNegotiate {
                            // 议价金额输入
                            VStack(alignment: .leading, spacing: 10) {
                                Text(LocalizationKey.fleaMarketYourBid.localized)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(AppColors.textSecondary)
                                
                                HStack {
                                    Text("£")
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundColor(AppColors.textSecondary)
                                    
                                    TextField(LocalizationKey.fleaMarketEnterAmount.localized, value: $proposedPrice, format: .number)
                                        .keyboardType(.decimalPad)
                                        .font(.system(size: 24, weight: .bold, design: .rounded))
                                        .onChange(of: proposedPrice) { _ in
                                            // 用户开始输入时清除错误和信息提示
                                            errorMessage = nil
                                            infoMessage = nil
                                        }
                                }
                                .padding(16)
                                .background(Color(UIColor.secondarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                    .padding(16)
                    .background(Color(UIColor.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .animation(.easeInOut(duration: 0.2), value: wantsNegotiate)
                    
                    // 留言输入
                    VStack(alignment: .leading, spacing: 10) {
                        Text(LocalizationKey.fleaMarketMessageToSeller.localized)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(AppColors.textSecondary)
                        
                        TextEditor(text: $message)
                            .frame(height: 100)
                            .padding(12)
                            .scrollContentBackground(.hidden)
                            .background(Color(UIColor.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .onChange(of: message) { _ in
                                // 用户开始输入时清除错误和信息提示
                                errorMessage = nil
                                infoMessage = nil
                            }
                            .overlay(
                                Group {
                                    if message.isEmpty {
                                        Text(LocalizationKey.fleaMarketMessagePlaceholder.localized)
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
                    
                    // 信息提示（非错误）
                    if let infoMessage = infoMessage {
                        HStack(spacing: 8) {
                            Image(systemName: "info.circle.fill")
                                .foregroundColor(AppColors.primary)
                            Text(infoMessage)
                                .font(.system(size: 14))
                                .foregroundColor(AppColors.textPrimary)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(AppColors.primary.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    
                    // 错误提示
                    if let errorMessage = errorMessage {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(AppColors.error)
                            Text(errorMessage)
                                .font(.system(size: 14))
                                .foregroundColor(AppColors.error)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(AppColors.error.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    
                    Spacer(minLength: 40)
                    }
                    .padding(20)
                }
                .scrollDismissesKeyboard(.interactively)
                .background(Color(UIColor.systemBackground))
                .navigationTitle(LocalizationKey.fleaMarketConfirmPurchase.localized)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button(LocalizationKey.commonCancel.localized) { dismiss() }
                            .disabled(isSubmitting)
                    }
                    
                    ToolbarItem(placement: .navigationBarTrailing) {
                        // 检查用户是否已有待处理的议价请求
                        let hasPendingRequest = item.userPurchaseRequestStatus != nil && 
                                               (item.userPurchaseRequestStatus == "pending" || item.userPurchaseRequestStatus == "seller_negotiating")
                        
                        Button(action: submitPurchase) {
                            if isSubmitting {
                                ProgressView()
                                    .tint(.white)
                                    .scaleEffect(0.8)
                            } else {
                                Text(LocalizationKey.fleaMarketConfirm.localized)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background((isSubmitting || hasPendingRequest) ? Color.gray : AppColors.primary)
                        .clipShape(Capsule())
                        .disabled(isSubmitting || hasPendingRequest)
                    }
                }
                
                // 购买处理中的加载指示器（覆盖整个购买页面）
                if isSubmitting {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(.white)
                        Text(wantsNegotiate ? "正在发送议价请求..." : "正在处理购买...")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                    }
                    .padding(24)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.black.opacity(0.7))
                    )
                }
            }
            .enableSwipeBack()
        }
    }
    
    private func submitPurchase() {
        // 验证议价金额
        if wantsNegotiate {
            guard let price = proposedPrice, price > 0 else {
                errorMessage = LocalizationKey.fleaMarketNegotiatePriceInvalid.localized
                return
            }
            if price >= item.price {
                errorMessage = LocalizationKey.fleaMarketNegotiatePriceTooHigh.localized
                return
            }
        }
        
        isSubmitting = true
        errorMessage = nil
        infoMessage = nil
        
        if wantsNegotiate {
            // 发送议价请求
            viewModel.requestPurchase(
                itemId: itemId,
                proposedPrice: proposedPrice,
                message: message.isEmpty ? nil : message
            ) { [self] success, errorMsg in
                DispatchQueue.main.async {
                    isSubmitting = false
                    if success {
                        onNegotiateComplete()
                    } else {
                        // 检查是否是409冲突错误（重复提交）
                        if let errorMsg = errorMsg,
                           errorMsg.contains("您已提交购买申请") || errorMsg.contains("请等待卖家处理") {
                            // 这是信息提示，不是错误
                            infoMessage = errorMsg
                            // 延迟关闭页面，让用户看到提示
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                                dismiss()
                            }
                        } else {
                            // 显示详细的错误消息，如果没有则使用默认消息
                            errorMessage = errorMsg ?? LocalizationKey.fleaMarketNegotiateRequestFailed.localized
                        }
                    }
                }
            }
        } else {
            // 直接购买
            viewModel.directPurchase(itemId: itemId, completion: { [self] purchaseData in
                DispatchQueue.main.async {
                    isSubmitting = false
                    if purchaseData != nil {
                        onPurchaseComplete(purchaseData)
                    }
                    // 如果 purchaseData 为 nil，说明购买失败，错误信息已通过 onError 回调设置
                }
            }, onError: { [self] errorMsg in
                DispatchQueue.main.async {
                    isSubmitting = false
                    // 检查是否是409冲突错误（重复提交）
                    if let errorMsg = errorMsg,
                       errorMsg.contains("您已提交购买申请") || errorMsg.contains("请等待卖家处理") {
                        // 这是信息提示，不是错误
                        infoMessage = errorMsg
                        // 延迟关闭页面，让用户看到提示
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            dismiss()
                        }
                    } else {
                        errorMessage = errorMsg
                    }
                }
            })
        }
    }
}

// MARK: - 购买申请卡片组件

struct PurchaseRequestCard: View {
    let request: PurchaseRequest
    let itemId: String
    let onApprove: () -> Void
    let onReject: () -> Void
    @State private var showRejectConfirm = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack {
                AvatarView(
                    urlString: nil,
                    size: 40,
                    placeholder: Image(systemName: "person.fill")
                )
                .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(request.buyerName)
                        .font(AppTypography.bodyBold)
                        .foregroundColor(AppColors.textPrimary)
                    
                    Text(DateFormatterHelper.shared.formatTime(request.createdAt))
                        .font(AppTypography.caption2)
                        .foregroundColor(AppColors.textTertiary)
                }
                
                Spacer()
                
                // 状态标签
                Text(statusText)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(statusColor)
                    .clipShape(Capsule())
            }
            
            // 议价信息
            if let proposedPrice = request.proposedPrice {
                HStack(spacing: 4) {
                    Text("议价金额:")
                        .font(AppTypography.subheadline)
                        .foregroundColor(AppColors.textSecondary)
                    Text("£\(String(format: "%.2f", proposedPrice))")
                        .font(AppTypography.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.primary)
                }
            }
            
            // 卖家议价
            if let sellerCounterPrice = request.sellerCounterPrice {
                HStack(spacing: 4) {
                    Text("卖家议价:")
                        .font(AppTypography.subheadline)
                        .foregroundColor(AppColors.textSecondary)
                    Text("£\(String(format: "%.2f", sellerCounterPrice))")
                        .font(AppTypography.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.success)
                }
            }
            
            // 留言
            if let message = request.message, !message.isEmpty {
                Text(message)
                    .font(AppTypography.subheadline)
                    .foregroundColor(AppColors.textSecondary)
                    .padding(AppSpacing.sm)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppColors.background)
                    .cornerRadius(AppCornerRadius.small)
            }
            
            // 操作按钮（仅pending状态显示）
            if request.status == "pending" {
                HStack(spacing: AppSpacing.md) {
                    // 批准按钮 - 图标样式（与任务申请者列表一致）
                    Button(action: {
                        HapticFeedback.success()
                        onApprove()
                    }) {
                        IconStyle.icon("checkmark.circle.fill", size: 24)
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(
                                LinearGradient(
                                    gradient: Gradient(colors: [AppColors.success, AppColors.success.opacity(0.8)]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .clipShape(Circle())
                            .shadow(color: AppColors.success.opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                    .buttonStyle(ScaleButtonStyle())
                    
                    // 增加间距，防止误触
                    Spacer()
                        .frame(width: 16)
                    
                    // 拒绝按钮 - 图标样式（与任务申请者列表一致）
                    Button(action: {
                        HapticFeedback.warning()
                        showRejectConfirm = true
                    }) {
                        IconStyle.icon("xmark.circle.fill", size: 24)
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(
                                LinearGradient(
                                    gradient: Gradient(colors: [AppColors.error, AppColors.error.opacity(0.8)]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .clipShape(Circle())
                            .shadow(color: AppColors.error.opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                    .buttonStyle(ScaleButtonStyle())
                    
                    Spacer()
                }
                .padding(.top, AppSpacing.xs)
            }
        }
        .padding(AppSpacing.md)
        .background(AppColors.cardBackground)
        .cornerRadius(AppCornerRadius.medium)
        .shadow(color: Color.black.opacity(0.03), radius: 5, x: 0, y: 2)
        .alert("拒绝购买申请", isPresented: $showRejectConfirm) {
            Button("取消", role: .cancel) {
                showRejectConfirm = false
            }
            Button("确认", role: .destructive) {
                onReject()
            }
        } message: {
            Text("确定要拒绝这个购买申请吗？")
        }
    }
    
    private var statusColor: Color {
        switch request.status {
        case "pending": return AppColors.warning
        case "seller_negotiating": return AppColors.primary
        case "accepted": return AppColors.success
        case "rejected": return AppColors.error
        default: return AppColors.textSecondary
        }
    }
    
    private var statusText: String {
        switch request.status {
        case "pending": return "待处理"
        case "seller_negotiating": return "卖家已议价"
        case "accepted": return "已接受"
        case "rejected": return "已拒绝"
        default: return request.status
        }
    }
}
