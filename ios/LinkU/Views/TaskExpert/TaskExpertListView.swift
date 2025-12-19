import SwiftUI

struct TaskExpertListView: View {
    @StateObject private var viewModel = TaskExpertViewModel()
    @State private var searchText = ""
    
    var body: some View {
        NavigationView {
            ZStack {
                AppColors.background
                    .ignoresSafeArea()
                
                if viewModel.isLoading && viewModel.experts.isEmpty {
                    ProgressView()
                } else if viewModel.experts.isEmpty {
                    EmptyStateView(
                        icon: "person.3.fill",
                        title: "暂无任务达人",
                        message: "还没有任务达人，敬请期待..."
                    )
                } else {
                    ScrollView {
                        LazyVStack(spacing: AppSpacing.md) {
                            ForEach(viewModel.experts) { expert in
                                NavigationLink(destination: TaskExpertDetailView(expertId: expert.id)) {
                                    ExpertCard(expert: expert)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(.horizontal, AppSpacing.md)
                        .padding(.vertical, AppSpacing.sm)
                    }
                }
            }
            .navigationTitle("任务达人")
            .searchable(text: $searchText, prompt: "搜索任务达人")
            .refreshable {
                viewModel.loadExperts()
            }
            .onAppear {
                if viewModel.experts.isEmpty {
                    viewModel.loadExperts()
                }
            }
        }
    }
}

// 任务达人卡片
struct ExpertCard: View {
    let expert: TaskExpert
    
    var body: some View {
        HStack(spacing: AppSpacing.md) {
            // 头像
            AsyncImage(url: URL(string: expert.avatar ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                ZStack {
                    Circle()
                        .fill(AppColors.primaryLight)
                    Image(systemName: "person.fill")
                        .foregroundColor(AppColors.primary)
                }
            }
            .frame(width: 60, height: 60)
            .clipShape(Circle())
            
            // 信息
            VStack(alignment: .leading, spacing: 4) {
                Text(expert.name)
                    .font(.headline)
                    .foregroundColor(AppColors.textPrimary)
                
                if let bio = expert.bio {
                    Text(bio)
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)
                        .lineLimit(2)
                }
                
                HStack(spacing: 16) {
                    if let rating = expert.avgRating {
                        Label(String(format: "%.1f", rating), systemImage: "star.fill")
                            .font(.caption)
                            .foregroundColor(AppColors.warning)
                    }
                    
                    if let completed = expert.completedTasks {
                        Label("\(completed)单", systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(AppColors.textSecondary)
                    }
                    
                    if let rate = expert.completionRate {
                        Label("\(String(format: "%.0f", rate))%", systemImage: "percent")
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
}

