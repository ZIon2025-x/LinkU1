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
                        // 任务达人信息
                        VStack(spacing: AppSpacing.md) {
                            // 头像
                            AvatarView(
                                urlString: expert.avatar,
                                size: 100,
                                placeholder: Image(systemName: "person.fill")
                            )
                            
                            // 名称
                            Text(expert.name)
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(AppColors.textPrimary)
                            
                            // 简介
                            if let bio = expert.bio {
                                Text(bio)
                                    .font(.body)
                                    .foregroundColor(AppColors.textSecondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, AppSpacing.md)
                            }
                            
                            // 统计信息
                            HStack(spacing: 32) {
                                if let rating = expert.avgRating {
                                    VStack {
                                        Text(String(format: "%.1f", rating))
                                            .font(.title2)
                                            .fontWeight(.bold)
                                            .foregroundColor(AppColors.warning)
                                        Text("评分")
                                            .font(.caption)
                                            .foregroundColor(AppColors.textSecondary)
                                    }
                                }
                                
                                if let completed = expert.completedTasks {
                                    VStack {
                                        Text("\(completed)")
                                            .font(.title2)
                                            .fontWeight(.bold)
                                            .foregroundColor(AppColors.primary)
                                        Text("已完成")
                                            .font(.caption)
                                            .foregroundColor(AppColors.textSecondary)
                                    }
                                }
                                
                                if let rate = expert.completionRate {
                                    VStack {
                                        Text("\(String(format: "%.0f", rate))%")
                                            .font(.title2)
                                            .fontWeight(.bold)
                                            .foregroundColor(AppColors.success)
                                        Text("完成率")
                                            .font(.caption)
                                            .foregroundColor(AppColors.textSecondary)
                                    }
                                }
                            }
                            .padding(.top, AppSpacing.sm)
                        }
                        .padding(AppSpacing.md)
                        .frame(maxWidth: .infinity)
                        .background(AppColors.cardBackground)
                        .cornerRadius(AppCornerRadius.medium)
                        .shadow(color: AppShadow.small.color, radius: AppShadow.small.radius, x: AppShadow.small.x, y: AppShadow.small.y)
                        
                        // 服务列表
                        VStack(alignment: .leading, spacing: AppSpacing.md) {
                            Text("服务菜单")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(AppColors.textPrimary)
                                .padding(.horizontal, AppSpacing.md)
                            
                            if viewModel.services.isEmpty {
                                Text("暂无服务")
                                    .font(.subheadline)
                                    .foregroundColor(AppColors.textSecondary)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                            } else {
                                ForEach(viewModel.services) { service in
                                    NavigationLink(destination: ServiceDetailView(serviceId: service.id)) {
                                        ServiceCard(service: service)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                        }
                        .padding(.top, AppSpacing.md)
                    }
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.vertical, AppSpacing.sm)
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

// 服务卡片
struct ServiceCard: View {
    let service: TaskExpertService
    
    var body: some View {
        HStack(spacing: AppSpacing.md) {
            // 服务图片
            if let images = service.images, let firstImage = images.first {
                AsyncImage(url: firstImage.toImageURL()) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    RoundedRectangle(cornerRadius: AppCornerRadius.small)
                        .fill(AppColors.primaryLight)
                }
                .frame(width: 80, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: AppCornerRadius.small))
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: AppCornerRadius.small)
                        .fill(AppColors.primaryLight)
                        .frame(width: 80, height: 80)
                    Image(systemName: "photo.fill")
                        .foregroundColor(AppColors.primary)
                }
            }
            
            // 服务信息
            VStack(alignment: .leading, spacing: 4) {
                Text(service.serviceName)
                    .font(.headline)
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(1)
                
                if let description = service.description {
                    Text(description)
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)
                        .lineLimit(2)
                }
                
                HStack {
                    Text("¥ \(String(format: "%.2f", service.basePrice))")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.error)
                    
                    if service.hasTimeSlots == true {
                        Label("时间段", systemImage: "clock.fill")
                            .font(.caption)
                            .foregroundColor(AppColors.primary)
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
        .padding(.horizontal, AppSpacing.md)
    }
}

