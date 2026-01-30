import SwiftUI

struct MyPostsView: View {
    @StateObject private var viewModel = MyPostsViewModel()
    @EnvironmentObject var appState: AppState
    @State private var showCreateItem = false
    @State private var hasLoadedOnce = false // 跟踪是否已经首次加载过
    @State private var isViewVisible = false // 跟踪视图是否真正可见（在导航栈顶部）
    
    var body: some View {
        ZStack {
            AppColors.background
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 分段选择器
                CategorySegmentControl(selectedCategory: $viewModel.selectedCategory)
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.top, AppSpacing.sm)
                    .padding(.bottom, AppSpacing.md)
                
                // 内容区域 - 使用TabView支持手势滑动
                TabView(selection: Binding(
                    get: { viewModel.selectedCategory.rawValue },
                    set: { newValue in
                        if let category = MyItemsCategory(rawValue: newValue) {
                            // 使用触觉反馈
                            HapticFeedback.selection()
                            // 不使用动画，让TabView自然滑动
                            viewModel.selectedCategory = category
                        }
                    }
                )) {
                    ForEach(MyItemsCategory.allCases, id: \.self) { category in
                        CategoryContentView(
                            viewModel: viewModel,
                            category: category,
                            appState: appState
                        )
                        .tag(category.rawValue)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .onChange(of: viewModel.selectedCategory) { _ in }
            }
        }
        .navigationTitle(LocalizationKey.myPostsTitle.localized)
        .navigationBarTitleDisplayMode(.inline)
        .enableSwipeBack()
        .toolbarBackground(AppColors.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    HapticFeedback.light()
                    showCreateItem = true
                }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(AppColors.primary)
                }
            }
        }
        .sheet(isPresented: $showCreateItem) {
            NavigationStack {
                CreateFleaMarketItemView()
            }
        }
        .refreshable {
            // 下拉刷新时加载数据（只在视图可见时刷新）
            if isViewVisible, let userId = appState.currentUser?.id {
                viewModel.loadAllCategories(userId: String(userId), forceRefresh: true)
            }
        }
        .onAppear {
            isViewVisible = true
            if let userId = appState.currentUser?.id {
                viewModel.loadAllCategoriesFromCache(userId: String(userId))
            }
            let hasData = !viewModel.sellingItems.isEmpty ||
                         !viewModel.purchasedItems.isEmpty ||
                         !viewModel.favoriteItems.isEmpty ||
                         !viewModel.soldItems.isEmpty
            if hasData {
                hasLoadedOnce = true
                return
            }
            if hasLoadedOnce { return }
            guard let userId = appState.currentUser?.id else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                guard self.isViewVisible else { return }
                let stillHasNoData = self.viewModel.sellingItems.isEmpty &&
                                   self.viewModel.purchasedItems.isEmpty &&
                                   self.viewModel.favoriteItems.isEmpty &&
                                   self.viewModel.soldItems.isEmpty
                if stillHasNoData && !self.hasLoadedOnce {
                    self.hasLoadedOnce = true
                    self.viewModel.loadAllCategories(userId: String(userId), forceRefresh: false)
                }
            }
        }
        .onDisappear {
            isViewVisible = false
        }
    }
}

// MARK: - 分段选择器

struct CategorySegmentControl: View {
    @Binding var selectedCategory: MyItemsCategory
    @Namespace private var animation
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(MyItemsCategory.allCases, id: \.self) { category in
                CategoryTab(
                    category: category,
                    isSelected: selectedCategory == category,
                    animation: animation
                ) {
                    // 优化：使用更高效的动画配置
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                        HapticFeedback.selection()
                        selectedCategory = category
                    }
                }
            }
        }
        .padding(4)
        .background(AppColors.cardBackground)
        .cornerRadius(AppCornerRadius.large)
    }
}

struct CategoryTab: View {
    let category: MyItemsCategory
    let isSelected: Bool
    var animation: Namespace.ID
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: category.icon)
                    .font(.system(size: 12, weight: .medium))
                Text(category.title)
                    .font(.system(size: 11, weight: isSelected ? .semibold : .medium))
            }
            .foregroundColor(isSelected ? .white : AppColors.textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: AppCornerRadius.medium)
                        .fill(AppColors.primary)
                        .matchedGeometryEffect(id: "tab", in: animation)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - 分类内容视图

struct CategoryContentView: View {
    @ObservedObject var viewModel: MyPostsViewModel
    let category: MyItemsCategory
    let appState: AppState
    
    // 使用计算属性，确保视图能响应数据变化
    private var items: [FleaMarketItem] {
        switch category {
        case .selling: return viewModel.sellingItems
        case .purchased: return viewModel.purchasedItems
        case .favorites: return viewModel.favoriteItems
        case .sold: return viewModel.soldItems
        }
    }
    
    private var isLoading: Bool {
        switch category {
        case .selling: return viewModel.isLoadingSelling
        case .purchased: return viewModel.isLoadingPurchased
        case .favorites: return viewModel.isLoadingFavorites
        case .sold: return viewModel.isLoadingSold
        }
    }
    
    var body: some View {
        Group {
            if isLoading && items.isEmpty {
                // 使用列表骨架屏
                ScrollView {
                    ListSkeleton(itemCount: 5, itemHeight: 150)
                        .padding(.horizontal, AppSpacing.md)
                        .padding(.vertical, AppSpacing.sm)
                }
            } else if items.isEmpty {
                EmptyStateView(
                    icon: category.icon,
                    title: category.emptyTitle,
                    message: category.emptyMessage
                )
            } else {
                ScrollView {
                    // 改为单列显示，卡片更大
                    LazyVStack(spacing: AppSpacing.md) {
                        ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                            NavigationLink(destination: FleaMarketDetailView(itemId: item.id)) {
                                MyItemCard(item: item, category: category)
                                    .drawingGroup() // 优化复杂卡片渲染性能
                            }
                            .buttonStyle(ScaleButtonStyle()) // 使用ScaleButtonStyle提供更好的交互反馈
                            .id(item.id) // 确保稳定的id，优化视图复用
                            .listItemAppear(index: index, totalItems: items.count) // 添加错落入场动画
                        }
                    }
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.vertical, AppSpacing.sm)
                    .padding(.bottom, 20)
                }
            }
        }
    }
}

// MARK: - 商品卡片

struct MyItemCard: View {
    let item: FleaMarketItem
    let category: MyItemsCategory
    
    // 缓存计算属性，避免重复计算
    private var priceText: String {
        "£\(String(format: "%.2f", item.price))"
    }
    
    private var firstImage: String? {
        item.images?.first
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 图片 - 增大尺寸
            ZStack(alignment: .topTrailing) {
                if let firstImage = firstImage {
                    AsyncImageView(
                        urlString: firstImage,
                        placeholder: Image(systemName: "photo"),
                        height: 200,
                        contentMode: .fill,
                        cornerRadius: AppCornerRadius.medium
                    )
                    .frame(height: 200)
                    .clipped()
                    .cornerRadius(AppCornerRadius.medium)
                } else {
                    Rectangle()
                        .fill(AppColors.textQuaternary.opacity(0.3))
                        .frame(height: 200)
                        .overlay(
                            Image(systemName: "photo")
                                .font(.system(size: 32))
                                .foregroundColor(AppColors.textQuaternary)
                        )
                        .cornerRadius(AppCornerRadius.medium)
                }
                
                // 状态标签
                MyItemStatusBadge(category: category, status: item.status)
                    .padding(8)
            }
            
            // 标题 - 增大字体
            Text(item.title)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(AppColors.textPrimary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            
            // 价格和信息
            VStack(alignment: .leading, spacing: 8) {
                // 价格 - 增大字体
                Text(priceText)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(AppColors.primary)
                
                // 收藏数和浏览量
                HStack(spacing: 16) {
                    // 收藏数
                    HStack(spacing: 4) {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 12))
                        Text("\(item.favoriteCount)")
                            .font(.system(size: 12))
                    }
                    .foregroundColor(AppColors.textTertiary)
                    
                    // 浏览量
                    HStack(spacing: 4) {
                        Image(systemName: "eye")
                            .font(.system(size: 12))
                        Text("\(item.viewCount)")
                            .font(.system(size: 12))
                    }
                    .foregroundColor(AppColors.textTertiary)
                    
                    Spacer()
                }
            }
        }
        .padding(16)
        .background(AppColors.cardBackground)
        .cornerRadius(AppCornerRadius.large)
        .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 3)
    }
}

// MARK: - 状态标签

struct MyItemStatusBadge: View {
    let category: MyItemsCategory
    let status: String
    
    var badgeInfo: (text: String, color: Color)? {
        switch category {
        case .selling:
            return (LocalizationKey.myItemsStatusSelling.localized, AppColors.success)
        case .purchased:
            return (LocalizationKey.myItemsStatusPurchased.localized, AppColors.primary)
        case .favorites:
            return nil
        case .sold:
            return (LocalizationKey.myItemsStatusSold.localized, AppColors.textTertiary)
        }
    }
    
    var body: some View {
        if let info = badgeInfo {
            Text(info.text)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(info.color)
                .cornerRadius(4)
        }
    }
}
