import SwiftUI

struct TaskExpertDetailView: View {
    let expertId: String
    @StateObject private var viewModel = TaskExpertDetailViewModel()
    
    var body: some View {
        ZStack {
            AppColors.background
                .ignoresSafeArea()
            
            if viewModel.isLoading && viewModel.expert == nil {
                ProgressView()
            } else if let expert = viewModel.expert {
                ScrollView {
                    VStack(alignment: .leading, spacing: AppSpacing.lg) {
                        // 任务达人信息 - 升级为更现代的卡片
                        VStack(spacing: AppSpacing.md) {
                            // 头像 - 带精致边框
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            gradient: Gradient(colors: AppColors.gradientPrimary),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 108, height: 108)
                                
                                AvatarView(
                                    urlString: expert.avatar,
                                    size: 100,
                                    placeholder: Image(systemName: "person.fill")
                                )
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color.white, lineWidth: 3))
                            }
                            .shadow(color: AppColors.primary.opacity(0.2), radius: 10, x: 0, y: 5)
                            
                            // 名称
                            HStack(spacing: 6) {
                                Text(expert.name)
                                    .font(AppTypography.title)
                                    .fontWeight(.bold)
                                    .foregroundColor(AppColors.textPrimary)
                                
                                IconStyle.icon("checkmark.seal.fill", size: 20)
                                    .foregroundColor(AppColors.primary)
                            }
                            
                            // 简介
                            if let bio = expert.bio {
                                Text(bio)
                                    .font(AppTypography.body)
                                    .foregroundColor(AppColors.textSecondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, AppSpacing.md)
                            }
                            
                            // 统计信息 - 现代网格布局
                            HStack(spacing: 0) {
                                ExpertStatItem(value: String(format: "%.1f", expert.avgRating ?? 0), label: "评分", color: AppColors.warning)
                                Divider().frame(height: 30).padding(.horizontal, AppSpacing.md)
                                ExpertStatItem(value: "\(expert.completedTasks ?? 0)", label: "已完成", color: AppColors.primary)
                                Divider().frame(height: 30).padding(.horizontal, AppSpacing.md)
                                ExpertStatItem(value: "\(String(format: "%.0f", expert.completionRate ?? 0))%", label: "完成率", color: AppColors.success)
                            }
                            .padding(.top, AppSpacing.sm)
                        }
                        .padding(.vertical, AppSpacing.xl)
                        .frame(maxWidth: .infinity)
                        .background(
                            AppColors.cardBackground
                                .overlay(
                                    LinearGradient(
                                        gradient: Gradient(colors: [AppColors.primary.opacity(0.05), Color.clear]),
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                        )
                        .cornerRadius(AppCornerRadius.xlarge)
                        .shadow(color: AppShadow.medium.color, radius: AppShadow.medium.radius, x: AppShadow.medium.x, y: AppShadow.medium.y)
                        
                        // 服务列表
                        VStack(alignment: .leading, spacing: AppSpacing.md) {
                            Text("服务菜单")
                                .font(AppTypography.title2)
                                .fontWeight(.bold)
                                .foregroundColor(AppColors.textPrimary)
                            
                            if viewModel.services.isEmpty {
                                EmptyStateView(icon: "bag.badge.questionmark", title: "暂无服务", message: "该达人暂时没有上架服务")
                                    .frame(height: 200)
                            } else {
                                ForEach(viewModel.services) { service in
                                    NavigationLink(destination: ServiceDetailView(serviceId: service.id)) {
                                        ServiceCard(service: service)
                                    }
                                    .buttonStyle(ScaleButtonStyle())
                                }
                            }
                        }
                    }
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.vertical, AppSpacing.md)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.loadExpert(expertId: expertId)
            viewModel.loadServices(expertId: expertId)
        }
    }
}

// 统计项组件
struct ExpertStatItem: View {
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(AppTypography.title3)
                .fontWeight(.bold)
                .foregroundColor(color)
            Text(label)
                .font(AppTypography.caption)
                .foregroundColor(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// 服务卡片
struct ServiceCard: View {
    let service: TaskExpertService
    
    var body: some View {
        HStack(spacing: AppSpacing.md) {
            // 服务图片
            ZStack {
                if let images = service.images, let firstImage = images.first {
                    AsyncImageView(
                        urlString: firstImage,
                        placeholder: Image(systemName: "photo.fill")
                    )
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 90, height: 90)
                    .clipped()
                } else {
                    Rectangle()
                        .fill(AppColors.primaryLight)
                        .frame(width: 90, height: 90)
                    IconStyle.icon("photo.fill", size: 24)
                        .foregroundColor(AppColors.primary.opacity(0.3))
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: AppCornerRadius.medium, style: .continuous))
            
            // 服务信息
            VStack(alignment: .leading, spacing: 6) {
                Text(service.serviceName)
                    .font(AppTypography.bodyBold)
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(1)
                
                if let description = service.description {
                    Text(description)
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textSecondary)
                        .lineLimit(2)
                }
                
                Spacer(minLength: 0)
                
                HStack(alignment: .bottom) {
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text("£")
                            .font(AppTypography.caption)
                            .fontWeight(.bold)
                        Text(String(format: "%.2f", service.basePrice))
                            .font(AppTypography.title3)
                            .fontWeight(.bold)
                    }
                    .foregroundColor(AppColors.error)
                    
                    Spacer()
                    
                    if service.hasTimeSlots == true {
                        Label("可约", systemImage: "calendar")
                            .font(AppTypography.caption2)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(AppColors.primaryLight)
                            .foregroundColor(AppColors.primary)
                            .clipShape(Capsule())
                    }
                }
            }
            .padding(.vertical, 4)
        }
        .padding(AppSpacing.sm)
        .background(AppColors.cardBackground)
        .cornerRadius(AppCornerRadius.large)
        .shadow(color: AppShadow.small.color, radius: AppShadow.small.radius, x: AppShadow.small.x, y: AppShadow.small.y)
    }
}
