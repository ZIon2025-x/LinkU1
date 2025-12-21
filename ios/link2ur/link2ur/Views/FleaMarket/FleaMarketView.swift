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
                    title: LocalizationKey.fleaMarketNoItems.localized,
                    message: LocalizationKey.fleaMarketNoItemsMessage.localized
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
                                .buttonStyle(ScaleButtonStyle())
                            }
                        }
                        .padding(.horizontal, AppSpacing.md)
                        .padding(.vertical, AppSpacing.sm)
                    }
                }
            }
            .navigationTitle(LocalizationKey.fleaMarketFleaMarket.localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppColors.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
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
            }
            .onChange(of: searchText) { newValue in
                if !newValue.isEmpty {
                    viewModel.loadItems(category: selectedCategory, keyword: newValue)
                }
            }
        }
    }
}

// 商品卡片 - Web风格（图片占满，信息叠加）
struct ItemCard: View {
    let item: FleaMarketItem
    
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = width // 正方形卡片
            
            ZStack(alignment: .bottom) {
                // 商品图片 - 占满整个卡片
                if let images = item.images, let firstImage = images.first, !firstImage.isEmpty {
                    AsyncImage(url: firstImage.toImageURL()) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: width, height: height)
                                .clipped()
                        case .failure(_), .empty:
                            ZStack {
                                Rectangle()
                                    .fill(
                                        LinearGradient(
                                            gradient: Gradient(colors: [
                                                Color(red: 0.063, green: 0.725, blue: 0.451).opacity(0.2),
                                                Color(red: 0.063, green: 0.725, blue: 0.451).opacity(0.1)
                                            ]),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                Text("🛍️")
                                    .font(.system(size: 48))
                                    .opacity(0.6)
                            }
                            .frame(width: width, height: height)
                        @unknown default:
                            Rectangle()
                                .fill(AppColors.cardBackground)
                                .frame(width: width, height: height)
                        }
                    }
                } else {
                    // 无图片时显示占位符
                    ZStack {
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color(red: 0.063, green: 0.725, blue: 0.451).opacity(0.2),
                                        Color(red: 0.063, green: 0.725, blue: 0.451).opacity(0.1)
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        Text("🛍️")
                            .font(.system(size: 48))
                            .opacity(0.6)
                    }
                    .frame(width: width, height: height)
                }
                
                // 渐变遮罩层 - 底部用于文字可读性
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.black.opacity(0.7),
                        Color.black.opacity(0.3),
                        Color.clear
                    ]),
                    startPoint: .bottom,
                    endPoint: .top
                )
                .frame(width: width, height: height * 0.5)
                .offset(y: height * 0.5)
                
                // 价格标签 - 右上角
                VStack {
                    HStack {
                        Spacer()
                        Text("£\(String(format: "%.2f", item.price))")
                            .font(AppTypography.bodyBold)
                            .foregroundColor(.white)
                            .padding(.horizontal, AppSpacing.md)
                            .padding(.vertical, AppSpacing.sm)
                            .background(
                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            gradient: Gradient(colors: [
                                                Color(red: 0.063, green: 0.725, blue: 0.451),
                                                Color(red: 0.020, green: 0.392, blue: 0.412)
                                            ]),
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                            )
                            .shadow(color: Color(red: 0.063, green: 0.725, blue: 0.451).opacity(0.4), radius: 6, x: 0, y: 3)
                            .padding(.top, 12)
                            .padding(.trailing, 12)
                    }
                    Spacer()
                }
                
                // 商品信息 - 底部叠加显示
                VStack(alignment: .leading, spacing: 6) {
                    Text(item.title)
                        .font(AppTypography.bodyBold)
                        .foregroundColor(.white)
                        .lineLimit(2)
                        .shadow(color: Color.black.opacity(0.5), radius: 4, x: 0, y: 2)
                    
                    if let location = item.location, !location.isEmpty {
                        HStack(spacing: 4) {
                            IconStyle.icon(location.lowercased() == "online" ? "globe" : "mappin.circle.fill", size: 12)
                            Text(location.obfuscatedLocation)
                                .font(AppTypography.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.white.opacity(0.9))
                        }
                        .shadow(color: Color.black.opacity(0.5), radius: 2, x: 0, y: 1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
            .background(AppColors.cardBackground)
            .cornerRadius(AppCornerRadius.large)
            .overlay(
                RoundedRectangle(cornerRadius: AppCornerRadius.large)
                    .stroke(Color(red: 0.063, green: 0.725, blue: 0.451).opacity(0.1), lineWidth: 1)
            )
            .shadow(color: AppShadow.medium.color, radius: AppShadow.medium.radius, x: AppShadow.medium.x, y: AppShadow.medium.y)
        }
        .aspectRatio(1, contentMode: .fit) // 强制正方形
    }
}
