import SwiftUI

struct FleaMarketView: View {
    @StateObject private var viewModel = FleaMarketViewModel()
    @State private var searchText = ""
    @State private var selectedCategory: String?
    
    var body: some View {
        // 注意：不要使用 NavigationView，因为此视图可能已经被包含在 NavigationStack 中
        // 使用 NavigationView 会导致嵌套导航栏，引发崩溃
        ZStack {
            AppColors.background
                .ignoresSafeArea()
            
            if viewModel.isLoading && viewModel.items.isEmpty {
                ProgressView()
            } else if viewModel.items.isEmpty {
            EmptyStateView(
                icon: "cart.fill",
                title: LocalizationKey.fleaMarketNoItems.localized,
                message: LocalizationKey.fleaMarketNoItemsMessage.localized
            )
            } else {
                ScrollView {
                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: AppSpacing.sm),
                        GridItem(.flexible(), spacing: AppSpacing.sm)
                    ], spacing: AppSpacing.md) {
                        ForEach(viewModel.items, id: \.id) { item in
                            NavigationLink(destination: FleaMarketDetailView(itemId: item.id)) {
                                ItemCard(item: item, isFavorited: viewModel.favoritedItemIds.contains(item.id))
                            }
                            .buttonStyle(ScaleButtonStyle())
                            .id(item.id) // 确保稳定的id，优化视图复用
                        }
                    }
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.vertical, AppSpacing.sm)
                }
                // 注意：不能在 ScrollView 上使用 drawingGroup，会阻止点击事件
            }
        }
        .navigationTitle(LocalizationKey.fleaMarketFleaMarket.localized)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(AppColors.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .enableSwipeBack()
        .searchable(text: $searchText, prompt: LocalizationKey.fleaMarketSearchItems.localized)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(LocalizationKey.postAll.localized) {
                        selectedCategory = nil
                        viewModel.loadItems()
                    }
                    ForEach(viewModel.categories, id: \.id) { category in
                        Button(category.name) {
                            selectedCategory = category.id
                            viewModel.loadItems(category: category.id)
                        }
                    }
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                        .foregroundColor(AppColors.primary)
                }
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                NavigationLink(destination: CreateFleaMarketItemView()) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(AppColors.primary)
                }
            }
        }
        .refreshable {
            viewModel.loadItems(category: selectedCategory, keyword: searchText.isEmpty ? nil : searchText, forceRefresh: true)
        }
        .onAppear {
            viewModel.loadCategories()
            if viewModel.items.isEmpty {
                viewModel.loadItems()
            }
            // 加载收藏列表
            viewModel.loadFavoriteIds()
        }
        .onChange(of: searchText) { newValue in
            if !newValue.isEmpty {
                viewModel.loadItems(category: selectedCategory, keyword: newValue)
            }
        }
    }
}

// 商品卡片 - 现代卡片风格 (Xiaohongshu/Instagram 风格)
struct ItemCard: View {
    let item: FleaMarketItem
    var isFavorited: Bool = false // 是否已收藏
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 1. 商品图片 (正方形)
            ZStack(alignment: .topTrailing) {
                if let images = item.images, let firstImage = images.first, !firstImage.isEmpty {
                    AsyncImageView(
                        urlString: firstImage,
                        placeholder: Image(systemName: "bag.fill"),
                        width: nil, // 自动填满
                        height: nil,
                        contentMode: .fill,
                        cornerRadius: 0
                    )
                    .aspectRatio(1, contentMode: .fill)
                    .frame(maxWidth: .infinity)
                    .clipped()
                } else {
                    ZStack {
                        Rectangle()
                            .fill(AppColors.primaryLight.opacity(0.5))
                            .aspectRatio(1, contentMode: .fill)
                        
                        VStack(spacing: 8) {
                            Image(systemName: "photo.on.rectangle.angled")
                                .font(.system(size: 32))
                                .foregroundColor(AppColors.primary.opacity(0.3))
                            Text("暂无图片")
                                .font(.system(size: 10))
                                .foregroundColor(AppColors.primary.opacity(0.4))
                        }
                    }
                }
                
                // 右上角收藏红心图标
                if isFavorited {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(6)
                        .background(Color.red)
                        .clipShape(Circle())
                        .shadow(color: Color.black.opacity(0.3), radius: 3, x: 0, y: 2)
                        .padding(8)
                }
                
                // 分类角标（如果未收藏，放在右上角；如果已收藏，放在左上角）
                VStack(alignment: isFavorited ? .leading : .trailing, spacing: 4) {
                    Text(item.category)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.black.opacity(0.4))
                        .clipShape(Capsule())
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: isFavorited ? .topLeading : .topTrailing)
                .padding(8)
            }
            
            // 2. 商品信息区域
            VStack(alignment: .leading, spacing: 8) {
                // 标题
                Text(item.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(height: 40, alignment: .topLeading)
                
                // 价格与位置
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("£")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Color(red: 0.9, green: 0.3, blue: 0.2))
                    
                    Text(String(format: "%.2f", item.price))
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(Color(red: 0.9, green: 0.3, blue: 0.2))
                    
                    Spacer()
                    
                    if let location = item.location, !location.isEmpty {
                        HStack(spacing: 2) {
                            Image(systemName: "mappin.circle.fill")
                                .font(.system(size: 10))
                            Text(location.obfuscatedLocation)
                                .font(.system(size: 10))
                        }
                        .foregroundColor(AppColors.textTertiary)
                    }
                }
                
                // 分隔线
                Divider()
                    .padding(.vertical, 2)
                
                // 底部统计信息
                HStack {
                    if let seller = item.seller {
                        HStack(spacing: 4) {
                            AvatarView(urlString: seller.avatar, size: 18, placeholder: Image(systemName: "person.circle.fill"))
                                .clipShape(Circle())
                            Text(seller.name)
                                .font(.system(size: 10))
                                .foregroundColor(AppColors.textSecondary)
                                .lineLimit(1)
                        }
                    }
                    
                    Spacer()
                    
                    // 收藏数
                    HStack(spacing: 3) {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 10))
                        Text("\(item.favoriteCount)")
                            .font(.system(size: 10, design: .rounded))
                    }
                    .foregroundColor(AppColors.textQuaternary)
                    
                    // 浏览量
                    HStack(spacing: 3) {
                        Image(systemName: "eye")
                            .font(.system(size: 10))
                        Text(item.viewCount.formatCount())
                            .font(.system(size: 10, design: .rounded))
                    }
                    .foregroundColor(AppColors.textQuaternary)
                }
            }
            .padding(12)
        }
        .background(Color(UIColor.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
    }
}
