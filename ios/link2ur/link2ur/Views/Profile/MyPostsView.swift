import SwiftUI

struct MyPostsView: View {
    @StateObject private var viewModel = MyPostsViewModel()
    @EnvironmentObject var appState: AppState
    @State private var showCreateItem = false
    
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
                
                // 内容区域
                TabView(selection: $viewModel.selectedCategory) {
                    ForEach(MyItemsCategory.allCases, id: \.self) { category in
                        CategoryContentView(
                            viewModel: viewModel,
                            category: category,
                            appState: appState
                        )
                        .tag(category)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
        }
        .navigationTitle("我的闲置")
        .navigationBarTitleDisplayMode(.inline)
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
            if let userId = appState.currentUser?.id {
                viewModel.loadAllCategories(userId: String(userId))
            }
        }
        .task {
            // 使用 .task 而不是 .onAppear，避免从详情页返回时重复加载
            if let userId = appState.currentUser?.id {
                // 只在数据为空时才加载，避免重复加载
                if viewModel.sellingItems.isEmpty && 
                   viewModel.purchasedItems.isEmpty && 
                   viewModel.favoriteItems.isEmpty && 
                   viewModel.soldItems.isEmpty {
                    viewModel.loadAllCategories(userId: String(userId))
                }
            }
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
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
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
                VStack {
                    Spacer()
                    ProgressView()
                        .scaleEffect(1.2)
                    Spacer()
                }
            } else if items.isEmpty {
                EmptyStateView(
                    icon: category.icon,
                    title: category.emptyTitle,
                    message: category.emptyMessage
                )
            } else {
                ScrollView {
                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: AppSpacing.sm),
                        GridItem(.flexible(), spacing: AppSpacing.sm)
                    ], spacing: AppSpacing.md) {
                        ForEach(items) { item in
                            NavigationLink(destination: FleaMarketDetailView(itemId: item.id)) {
                                MyItemCard(item: item, category: category)
                            }
                            .buttonStyle(PlainButtonStyle())
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
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 图片
            ZStack(alignment: .topTrailing) {
                if let images = item.images, let firstImage = images.first {
                    AsyncImageView(
                        urlString: firstImage,
                        placeholder: Image(systemName: "photo"),
                        height: 130,
                        contentMode: .fill,
                        cornerRadius: AppCornerRadius.medium
                    )
                    .frame(height: 130)
                    .clipped()
                    .cornerRadius(AppCornerRadius.medium)
                } else {
                    Rectangle()
                        .fill(AppColors.textQuaternary.opacity(0.3))
                        .frame(height: 130)
                        .overlay(
                            Image(systemName: "photo")
                                .font(.system(size: 24))
                                .foregroundColor(AppColors.textQuaternary)
                        )
                        .cornerRadius(AppCornerRadius.medium)
                }
                
                // 状态标签
                MyItemStatusBadge(category: category, status: item.status)
                    .padding(6)
            }
            
            // 标题
            Text(item.title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(AppColors.textPrimary)
                .lineLimit(2)
            
            // 价格
            HStack {
                Text("£\(String(format: "%.2f", item.price))")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(AppColors.primary)
                
                Spacer()
                
                // 浏览量
                HStack(spacing: 2) {
                    Image(systemName: "eye")
                        .font(.system(size: 10))
                    Text("\(item.viewCount)")
                        .font(.system(size: 10))
                }
                .foregroundColor(AppColors.textTertiary)
            }
        }
        .padding(10)
        .background(AppColors.cardBackground)
        .cornerRadius(AppCornerRadius.large)
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
}

// MARK: - 状态标签

struct MyItemStatusBadge: View {
    let category: MyItemsCategory
    let status: String
    
    var badgeInfo: (text: String, color: Color)? {
        switch category {
        case .selling:
            return ("在售", AppColors.success)
        case .purchased:
            return ("已购", AppColors.primary)
        case .favorites:
            return nil
        case .sold:
            return ("已售", AppColors.textTertiary)
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
