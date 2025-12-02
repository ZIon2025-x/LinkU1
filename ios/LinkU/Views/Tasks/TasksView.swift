import SwiftUI

struct TasksView: View {
    @StateObject private var viewModel = TasksViewModel()
    @State private var searchText = ""
    @State private var showFilter = false
    @State private var selectedCategory: String?
    @State private var selectedStatus: String?
    
    var body: some View {
        NavigationView {
            ZStack {
                AppColors.background
                    .ignoresSafeArea()
                
                if viewModel.isLoading && viewModel.tasks.isEmpty {
                    ProgressView()
                } else if let error = viewModel.errorMessage, viewModel.tasks.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 50))
                            .foregroundColor(AppColors.textSecondary)
                        Text(error)
                            .foregroundColor(AppColors.textSecondary)
                            .multilineTextAlignment(.center)
                        Button("重试") {
                            viewModel.loadTasks()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                } else if viewModel.tasks.isEmpty {
                    EmptyStateView(
                        icon: "doc.text.magnifyingglass",
                        title: "暂无任务",
                        message: "还没有任务发布，快来发布第一个任务吧！"
                    )
                } else {
                    ScrollView {
                        LazyVStack(spacing: AppSpacing.md) {
                            ForEach(viewModel.tasks) { task in
                                NavigationLink(destination: TaskDetailView(taskId: task.id)) {
                                    TaskCard(task: task)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(.horizontal, AppSpacing.md)
                        .padding(.vertical, AppSpacing.sm)
                    }
                }
            }
            .navigationTitle("任务大厅")
            .searchable(text: $searchText, prompt: "搜索任务")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showFilter = true
                    }) {
                        Image(systemName: "slider.horizontal.3")
                            .foregroundColor(AppColors.primary)
                    }
                }
            }
            .sheet(isPresented: $showFilter) {
                TaskFilterView(selectedCategory: $selectedCategory, selectedStatus: $selectedStatus)
            }
            .onChange(of: selectedCategory) { _ in
                applyFilters()
            }
            .onChange(of: selectedStatus) { _ in
                applyFilters()
            }
            .refreshable {
                viewModel.loadTasks()
            }
            .onAppear {
                if viewModel.tasks.isEmpty {
                    viewModel.loadTasks()
                }
            }
        }
    }
    
    private func applyFilters() {
        // 重新加载任务，应用筛选条件
        viewModel.loadTasks(category: selectedCategory, status: selectedStatus)
    }
}

// 任务卡片组件
struct TaskCard: View {
    let task: Task
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 标题和价格
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(task.title)
                        .font(.headline)
                        .foregroundColor(AppColors.textPrimary)
                        .lineLimit(2)
                    
                    Text(task.description)
                        .font(.subheadline)
                        .foregroundColor(AppColors.textSecondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                if let price = task.price {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("¥")
                            .font(.caption)
                            .foregroundColor(AppColors.error)
                        Text(String(format: "%.0f", price))
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(AppColors.error)
                    }
                }
            }
            
            // 标签和位置
            HStack(spacing: 8) {
                // 状态标签
                StatusBadge(status: task.status)
                
                // 分类标签
                Text(task.category)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(AppColors.primaryLight)
                    .foregroundColor(AppColors.primary)
                    .cornerRadius(AppCornerRadius.small)
                
                Spacer()
                
                // 位置
                HStack(spacing: 4) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.caption)
                    Text(task.city)
                        .font(.caption)
                }
                .foregroundColor(AppColors.textSecondary)
            }
            
            // 时间
            HStack {
                Image(systemName: "clock")
                    .font(.caption2)
                Text(formatTime(task.createdAt))
                    .font(.caption2)
            }
            .foregroundColor(AppColors.textSecondary)
        }
        .padding(AppSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.cardBackground)
        .cornerRadius(AppCornerRadius.medium)
        .shadow(color: AppShadow.small.color, radius: AppShadow.small.radius, x: AppShadow.small.x, y: AppShadow.small.y)
    }
    
    private func formatTime(_ timeString: String) -> String {
        return DateFormatterHelper.shared.formatTime(timeString)
    }
}

// 状态标签组件
struct StatusBadge: View {
    let status: TaskStatus
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(statusColor)
                .frame(width: 6, height: 6)
            Text(status.displayText)
                .font(.caption)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(statusColor.opacity(0.15))
        .foregroundColor(statusColor)
        .cornerRadius(AppCornerRadius.small)
    }
    
    private var statusColor: Color {
        switch status {
        case .open: return AppColors.success
        case .inProgress: return AppColors.primary
        case .completed: return AppColors.textSecondary
        case .cancelled: return AppColors.error
        }
    }
}

// 空状态视图
struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 60))
                .foregroundColor(AppColors.textSecondary.opacity(0.5))
            
            Text(title)
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(AppColors.textPrimary)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppSpacing.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
