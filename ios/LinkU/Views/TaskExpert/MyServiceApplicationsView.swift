import SwiftUI

struct MyServiceApplicationsView: View {
    @StateObject private var viewModel = MyServiceApplicationsViewModel()
    
    var body: some View {
        NavigationView {
            ZStack {
                AppColors.background
                    .ignoresSafeArea()
                
                if viewModel.isLoading && viewModel.applications.isEmpty {
                    ProgressView()
                } else if viewModel.applications.isEmpty {
                    EmptyStateView(
                        icon: "doc.text.magnifyingglass",
                        title: "暂无申请",
                        message: "您还没有申请过任何服务"
                    )
                } else {
                    ScrollView {
                        LazyVStack(spacing: AppSpacing.md) {
                            ForEach(viewModel.applications) { application in
                                ApplicationCard(application: application)
                            }
                        }
                        .padding(.horizontal, AppSpacing.md)
                        .padding(.vertical, AppSpacing.sm)
                    }
                }
            }
            .navigationTitle("我的申请")
            .refreshable {
                viewModel.loadApplications()
            }
            .onAppear {
                viewModel.loadApplications()
            }
        }
    }
}

// 申请卡片
struct ApplicationCard: View {
    let application: ServiceApplication
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 服务名称和状态
            HStack {
                Text(application.serviceName ?? "服务")
                    .font(.headline)
                    .foregroundColor(AppColors.textPrimary)
                
                Spacer()
                
                ApplicationStatusBadge(status: application.status)
            }
            
            // 任务达人
            if let expertName = application.expertName {
                HStack {
                    Image(systemName: "person.fill")
                        .foregroundColor(AppColors.textSecondary)
                    Text(expertName)
                        .font(.subheadline)
                        .foregroundColor(AppColors.textSecondary)
                }
            }
            
            // 申请留言
            if let message = application.applicationMessage {
                Text(message)
                    .font(.subheadline)
                    .foregroundColor(AppColors.textPrimary)
                    .padding(AppSpacing.sm)
                    .background(AppColors.primaryLight)
                    .cornerRadius(AppCornerRadius.small)
            }
            
            // 议价信息
            if application.status == "negotiating", let counterPrice = application.counterPrice {
                VStack(alignment: .leading, spacing: 8) {
                    Text("任务达人提出议价：")
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)
                    Text("¥ \(String(format: "%.2f", counterPrice))")
                        .font(.headline)
                        .foregroundColor(AppColors.error)
                }
                .padding(AppSpacing.sm)
                .background(AppColors.warning.opacity(0.1))
                .cornerRadius(AppCornerRadius.small)
            }
            
            // 关联任务
            if let taskId = application.taskId {
                NavigationLink(destination: Text("任务详情: \(taskId)")) {
                    HStack {
                        Text("查看任务")
                            .font(.subheadline)
                            .foregroundColor(AppColors.primary)
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(AppColors.primary)
                    }
                }
            }
            
            // 时间
            Text(formatTime(application.createdAt))
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

// 申请状态标签
struct ApplicationStatusBadge: View {
    let status: String
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(statusColor)
                .frame(width: 6, height: 6)
            Text(statusText)
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
        case "pending": return AppColors.warning
        case "negotiating": return AppColors.primary
        case "price_agreed": return AppColors.success
        case "approved": return AppColors.success
        case "rejected": return AppColors.error
        default: return AppColors.textSecondary
        }
    }
    
    private var statusText: String {
        switch status {
        case "pending": return "待处理"
        case "negotiating": return "议价中"
        case "price_agreed": return "价格已达成"
        case "approved": return "已同意"
        case "rejected": return "已拒绝"
        default: return status
        }
    }
}

