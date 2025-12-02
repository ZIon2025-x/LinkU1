import SwiftUI

struct FleaMarketView: View {
    @StateObject private var viewModel = FleaMarketViewModel()
    @State private var searchText = ""
    @State private var selectedCategory: String?
    
    var body: some View {
        NavigationView {
            ZStack {
                AppColors.background
                    .ignoresSafeArea()
                
                if viewModel.isLoading && viewModel.items.isEmpty {
                    ProgressView()
                } else if viewModel.items.isEmpty {
                    EmptyStateView(
                        icon: "cart.fill",
                        title: "暂无商品",
                        message: "跳蚤市场还没有商品，快来发布第一个吧！"
                    )
                } else {
                    ScrollView {
                        LazyVGrid(columns: [
                            GridItem(.flexible(), spacing: AppSpacing.sm),
                            GridItem(.flexible(), spacing: AppSpacing.sm)
                        ], spacing: AppSpacing.md) {
                            ForEach(viewModel.items) { item in
                                NavigationLink(destination: FleaMarketDetailView(itemId: item.id)) {
                                    ItemCard(item: item)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(.horizontal, AppSpacing.md)
                        .padding(.vertical, AppSpacing.sm)
                    }
                }
            }
            .navigationTitle("跳蚤市场")
            .searchable(text: $searchText, prompt: "搜索商品")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("全部") {
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
                viewModel.loadItems(category: selectedCategory, keyword: searchText.isEmpty ? nil : searchText)
            }
            .onAppear {
                viewModel.loadCategories()
                if viewModel.items.isEmpty {
                    viewModel.loadItems()
                }
            }
            .onChange(of: searchText) { newValue in
                if !newValue.isEmpty {
                    viewModel.loadItems(category: selectedCategory, keyword: newValue)
                }
            }
        }
    }
}

// 商品卡片
struct ItemCard: View {
    let item: FleaMarketItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 商品图片
            if let images = item.images, let firstImage = images.first {
                AsyncImage(url: URL(string: firstImage)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    RoundedRectangle(cornerRadius: AppCornerRadius.small)
                        .fill(AppColors.primaryLight)
                }
                .frame(height: 150)
                .clipShape(RoundedRectangle(cornerRadius: AppCornerRadius.medium))
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: AppCornerRadius.medium)
                        .fill(AppColors.primaryLight)
                        .frame(height: 150)
                    Image(systemName: "photo.fill")
                        .foregroundColor(AppColors.primary)
                        .font(.title)
                }
            }
            
            // 商品信息
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.headline)
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(2)
                
                HStack {
                    Text("¥ \(String(format: "%.2f", item.price))")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.error)
                    
                    Spacer()
                    
                    Text(item.category)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(AppColors.primaryLight)
                        .foregroundColor(AppColors.primary)
                        .cornerRadius(4)
                }
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
        }
        .background(AppColors.cardBackground)
        .cornerRadius(AppCornerRadius.medium)
        .shadow(color: AppShadow.small.color, radius: AppShadow.small.radius, x: AppShadow.small.x, y: AppShadow.small.y)
    }
}
