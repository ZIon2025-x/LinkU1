import SwiftUI

struct ForumView: View {
    @StateObject private var viewModel = ForumViewModel()
    
    var body: some View {
        NavigationView {
            ZStack {
                AppColors.background
                    .ignoresSafeArea()
                
                // 装饰背景
                VStack {
                    Circle()
                        .fill(AppColors.primary.opacity(0.05))
                        .frame(width: 300, height: 300)
                        .blur(radius: 50)
                        .offset(x: -150, y: -100)
                    Spacer()
                }
                .ignoresSafeArea()
                
                if viewModel.isLoading && viewModel.categories.isEmpty {
                    LoadingView()
                } else if viewModel.categories.isEmpty {
                    EmptyStateView(
                        icon: "bubble.left.and.bubble.right.fill",
                        title: "发现新世界",
                        message: "这里暂时还没有讨论，去其他地方看看吧"
                    )
                } else {
                    ScrollView {
                        LazyVStack(spacing: 20) {
                            // 热门话题 Banner
                            hotTopicBanner
                            
                            Text("讨论板块")
                                .font(.system(size: 20, weight: .black, design: .rounded))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, AppSpacing.sm)
                            
                            ForEach(viewModel.categories) { category in
                                NavigationLink(destination: ForumPostListView(category: category)) {
                                    CategoryCard(category: category)
                                }
                            }
                        }
                        .padding(.horizontal, AppSpacing.md)
                        .padding(.vertical, AppSpacing.md)
                    }
                }
            }
            .navigationTitle("社区论坛")
            .refreshable {
                viewModel.loadCategories()
            }
            .onAppear {
                if viewModel.categories.isEmpty {
                    viewModel.loadCategories()
                }
            }
        }
    }
    
    // 热门话题 Banner
    private var hotTopicBanner: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(AppColors.primaryGradient)
                .frame(height: 80)
            
            HStack(spacing: 12) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("热门话题")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                    Text("发现最新讨论")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.9))
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white.opacity(0.8))
            }
            .padding(.horizontal, 16)
        }
    }
}

// 板块卡片
struct CategoryCard: View {
    let category: ForumCategory
    
    var body: some View {
        HStack(spacing: 16) {
            // 图标容器：使用品牌色渐变背景
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(AppColors.primary.opacity(0.1))
                    .frame(width: 64, height: 64)
                
                if let icon = category.icon, !icon.isEmpty {
                    AsyncImage(url: URL(string: icon)) { image in
                        image.resizable().aspectRatio(contentMode: .fit)
                    } placeholder: {
                        Image(systemName: "bubbles.and.sparkles.fill")
                            .symbolRenderingMode(.hierarchical)
                            .foregroundColor(AppColors.primary)
                    }
                    .frame(width: 32, height: 32)
                } else {
                    Image(systemName: "quote.bubble.fill")
                        .font(.system(size: 24, weight: .bold))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundColor(AppColors.primary)
                }
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text(category.name)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(AppColors.textPrimary)
                
                if let description = category.description {
                    Text(description)
                        .font(.system(size: 13))
                        .foregroundColor(AppColors.textSecondary)
                        .lineLimit(1)
                }
                
                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Image(systemName: "text.bubble.fill")
                        Text("\(category.postCount) 帖子")
                    }
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(AppColors.primary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(AppColors.primary.opacity(0.08))
                    .cornerRadius(6)
                    
                    if let lastPostAt = category.lastPostAt {
                        Text("活跃于 \(formatTime(lastPostAt))")
                            .font(.system(size: 11))
                            .foregroundColor(AppColors.textTertiary)
                    }
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(AppColors.textTertiary)
        }
        .padding(16)
        .background(AppColors.cardBackground)
        .cornerRadius(AppCornerRadius.medium)
        .shadow(color: Color.black.opacity(0.03), radius: 10, x: 0, y: 5)
    }
    
    private func formatTime(_ timeString: String) -> String {
        return DateFormatterHelper.shared.formatTime(timeString)
    }
}

