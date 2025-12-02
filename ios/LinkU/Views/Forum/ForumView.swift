import SwiftUI

struct ForumView: View {
    @StateObject private var viewModel = ForumViewModel()
    
    var body: some View {
        NavigationView {
            ZStack {
                AppColors.background
                    .ignoresSafeArea()
                
                if viewModel.isLoading && viewModel.categories.isEmpty {
                    ProgressView()
                } else if viewModel.categories.isEmpty {
                    EmptyStateView(
                        icon: "bubble.left.and.bubble.right.fill",
                        title: "暂无板块",
                        message: "论坛板块加载中..."
                    )
                } else {
                    ScrollView {
                        LazyVStack(spacing: AppSpacing.md) {
                            ForEach(viewModel.categories) { category in
                                NavigationLink(destination: ForumPostListView(category: category)) {
                                    CategoryCard(category: category)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(.horizontal, AppSpacing.md)
                        .padding(.vertical, AppSpacing.sm)
                    }
                }
            }
            .navigationTitle("论坛")
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
}

// 板块卡片
struct CategoryCard: View {
    let category: ForumCategory
    
    var body: some View {
        HStack(spacing: AppSpacing.md) {
            // 图标
            ZStack {
                RoundedRectangle(cornerRadius: AppCornerRadius.medium)
                    .fill(AppColors.primaryLight)
                    .frame(width: 60, height: 60)
                
                if let icon = category.icon, !icon.isEmpty {
                    AsyncImage(url: URL(string: icon)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    } placeholder: {
                        Image(systemName: "folder.fill")
                            .foregroundColor(AppColors.primary)
                    }
                    .frame(width: 30, height: 30)
                } else {
                    Image(systemName: "folder.fill")
                        .foregroundColor(AppColors.primary)
                        .font(.title2)
                }
            }
            
            // 信息
            VStack(alignment: .leading, spacing: 4) {
                Text(category.name)
                    .font(.headline)
                    .foregroundColor(AppColors.textPrimary)
                
                if let description = category.description {
                    Text(description)
                        .font(.subheadline)
                        .foregroundColor(AppColors.textSecondary)
                        .lineLimit(2)
                }
                
                HStack(spacing: 16) {
                    Label("\(category.postCount)", systemImage: "doc.text")
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)
                    
                    if let lastPostAt = category.lastPostAt {
                        Text(formatTime(lastPostAt))
                            .font(.caption)
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(AppColors.textSecondary)
        }
        .padding(AppSpacing.md)
        .background(AppColors.cardBackground)
        .cornerRadius(AppCornerRadius.medium)
        .shadow(color: AppShadow.small.color, radius: AppShadow.small.radius, x: AppShadow.small.x, y: AppShadow.small.y)
    }
    
    private func formatTime(_ timeString: String) -> String {
        return DateFormatterHelper.shared.formatTime(timeString)
    }
}

