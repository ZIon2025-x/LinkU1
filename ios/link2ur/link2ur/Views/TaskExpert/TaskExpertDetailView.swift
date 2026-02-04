import SwiftUI

struct TaskExpertDetailView: View {
    let expertId: String
    @StateObject private var viewModel = TaskExpertDetailViewModel()
    @EnvironmentObject var appState: AppState
    @State private var showLogin = false
    
    var body: some View {
        ZStack(alignment: .bottom) {
            AppColors.background
                .ignoresSafeArea()
            
            if viewModel.isLoading && viewModel.expert == nil {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text(LocalizationKey.taskExpertLoading.localized)
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textTertiary)
                }
            } else if let expert = viewModel.expert {
                ScrollView {
                    VStack(spacing: 0) {
                        // 1. 顶部装饰背景
                        topHeaderBackground()
                        
                        // 2. 个人信息卡片 (浮动效果)
                        expertProfileCard(expert: expert)
                            .padding(.top, -60)
                        
                        VStack(spacing: 24) {
                            // 3. 专业信息卡片（专业领域、特色技能、成就勋章）
                            expertInfoCard(expert: expert)
                                .padding(.top, 8)
                            
                            // 4. 评价卡片
                            if !viewModel.reviews.isEmpty || viewModel.isLoadingReviews {
                                reviewsCard(reviews: viewModel.reviews, isLoading: viewModel.isLoadingReviews)
                            }
                            
                            // 5. 服务菜单标题
                            HStack {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(AppColors.primary)
                                    .frame(width: 4, height: 18)
                                
                                Text(LocalizationKey.taskExpertServiceMenu.localized)
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(AppColors.textPrimary)
                                
                                Spacer()
                                
                                Text(String(format: LocalizationKey.taskExpertServicesCount.localized, viewModel.services.count))
                                    .font(.system(size: 13))
                                    .foregroundColor(AppColors.textTertiary)
                            }
                            .padding(.horizontal, 24)
                            .padding(.top, 8)
                            
                            // 6. 服务列表内容
                            if viewModel.services.isEmpty {
                                emptyServicesView()
                            } else {
                                LazyVStack(spacing: 16) {
                                    ForEach(viewModel.services) { service in
                                        NavigationLink(destination: ServiceDetailView(serviceId: service.id)) {
                                            ServiceCard(service: service)
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                    }
                                }
                                .padding(.horizontal, 16)
                            }
                            
                            // 底部间距
                            Spacer().frame(height: 40)
                        }
                        .padding(.top, 24)
                    }
                }
                .ignoresSafeArea(edges: .top)
                .scrollIndicators(.hidden)
            } else {
                // 如果 expert 为 nil 且不在加载中，显示错误状态（不应该发生，但作为保护）
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 48))
                        .foregroundColor(AppColors.textTertiary)
                    Text(LocalizationKey.taskExpertLoadFailed.localized)
                        .font(AppTypography.body)
                        .foregroundColor(AppColors.textSecondary)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .enableSwipeBack()
        .toolbar(.hidden, for: .tabBar)
        .sheet(isPresented: $showLogin) {
            LoginView()
        }
        .onAppear {
            viewModel.loadExpert(expertId: expertId)
            viewModel.loadServices(expertId: expertId)
            viewModel.loadReviews(expertId: expertId)
        }
    }
    
    // MARK: - Subviews
    
    @ViewBuilder
    private func topHeaderBackground() -> some View {
        ZStack {
            LinearGradient(
                colors: [AppColors.primary, AppColors.primary.opacity(0.6)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(height: 180)
            
            // 装饰圆点
            Circle()
                .fill(Color.white.opacity(0.1))
                .frame(width: 150, height: 150)
                .offset(x: 150, y: -50)
            
            Circle()
                .fill(Color.white.opacity(0.05))
                .frame(width: 200, height: 200)
                .offset(x: -120, y: 40)
        }
    }
    
    @ViewBuilder
    private func expertProfileCard(expert: TaskExpert) -> some View {
        VStack(spacing: 20) {
            // 头像
            AvatarView(
                urlString: expert.avatar,
                size: 90,
                placeholder: Image(systemName: "person.fill")
            )
            .clipShape(Circle())
            .overlay(Circle().stroke(Color.white, lineWidth: 4))
            .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
            
            // 名称与认证
            VStack(spacing: 8) {
                HStack(spacing: 6) {
                    Text(expert.name)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(AppColors.textPrimary)
                    
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 18))
                        .foregroundColor(AppColors.primary)
                }
                
                if let bio = expert.localizedBio {
                    Text(bio)
                        .font(.system(size: 14))
                        .foregroundColor(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                        .lineLimit(3)
                }
            }
            
            // 统计网格
            HStack(spacing: 0) {
                statItem(value: String(format: "%.1f", expert.avgRating ?? 0), label: LocalizationKey.taskExpertRating.localized, icon: "star.fill", color: .orange)
                divider()
                statItem(value: "\(expert.completedTasks ?? 0)", label: LocalizationKey.taskExpertCompleted.localized, icon: "checkmark.circle.fill", color: AppColors.primary)
                divider()
                statItem(value: "\(String(format: "%.0f", expert.completionRate ?? 0))%", label: LocalizationKey.taskExpertCompletionRate.localized, icon: "chart.bar.fill", color: .green)
            }
            .padding(.top, 8)
        }
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color(UIColor.systemBackground))
                .shadow(color: Color.black.opacity(0.08), radius: 20, x: 0, y: 10)
        )
        .padding(.horizontal, 16)
    }
    
    @ViewBuilder
    private func statItem(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                    .foregroundColor(color)
                Text(value)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(AppColors.textPrimary)
            }
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(AppColors.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }
    
    @ViewBuilder
    private func divider() -> some View {
        Rectangle()
            .fill(Color(UIColor.separator).opacity(0.5))
            .frame(width: 1, height: 24)
    }
    
    @ViewBuilder
    private func expertInfoCard(expert: TaskExpert) -> some View {
        let hasExpertiseAreas = expert.localizedExpertiseAreas?.isEmpty == false
        let hasFeaturedSkills = expert.localizedFeaturedSkills?.isEmpty == false
        let hasAchievements = expert.localizedAchievements?.isEmpty == false
        let hasResponseTime = expert.localizedResponseTime?.isEmpty == false
        let hasAnyInfo = hasExpertiseAreas || hasFeaturedSkills || hasAchievements || hasResponseTime
        
        if hasAnyInfo {
            VStack(spacing: 0) {
                // 响应时间（如果有）
                if hasResponseTime, let responseTime = expert.localizedResponseTime {
                    responseTimeSection(responseTime: responseTime)
                }
                
                // 专业领域
                if hasExpertiseAreas, let expertiseAreas = expert.localizedExpertiseAreas {
                    if hasResponseTime {
                        Divider()
                            .padding(.vertical, 8)
                    }
                    infoSection(
                        title: LocalizationKey.taskExpertExpertiseAreas.localized,
                        items: expertiseAreas
                    )
                }
                
                // 特色技能
                if hasFeaturedSkills, let featuredSkills = expert.localizedFeaturedSkills {
                    if hasResponseTime || hasExpertiseAreas {
                        Divider()
                            .padding(.vertical, 8)
                    }
                    infoSection(
                        title: LocalizationKey.taskExpertFeaturedSkills.localized,
                        items: featuredSkills
                    )
                }
                
                // 成就勋章
                if hasAchievements, let achievements = expert.localizedAchievements {
                    if hasResponseTime || hasExpertiseAreas || hasFeaturedSkills {
                        Divider()
                            .padding(.vertical, 8)
                    }
                    infoSection(
                        title: LocalizationKey.taskExpertAchievements.localized,
                        items: achievements
                    )
                }
            }
            .padding(.vertical, 20)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(UIColor.systemBackground))
                    .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 2)
            )
            .padding(.horizontal, 16)
        }
    }
    
    @ViewBuilder
    private func responseTimeSection(responseTime: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "clock.fill")
                .font(.system(size: 14))
                .foregroundColor(AppColors.primary)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(LocalizationKey.taskExpertResponseTime.localized)
                    .font(.system(size: 13))
                    .foregroundColor(AppColors.textTertiary)
                
                Text(responseTime)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(AppColors.textPrimary)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
    
    @ViewBuilder
    private func infoSection(title: String, items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(AppColors.primary)
                    .frame(width: 3, height: 16)
                
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppColors.textPrimary)
            }
            
            FlowLayout(spacing: 8) {
                ForEach(items, id: \.self) { item in
                    Text(item)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(AppColors.primary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 18)
                                .fill(AppColors.primary.opacity(0.12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 18)
                                        .stroke(AppColors.primary.opacity(0.2), lineWidth: 0.5)
                                )
                        )
                }
            }
        }
    }
    
    @ViewBuilder
    private func reviewsCard(reviews: [PublicReview], isLoading: Bool) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                RoundedRectangle(cornerRadius: 2)
                    .fill(AppColors.primary)
                    .frame(width: 4, height: 18)
                
                Text(LocalizationKey.taskExpertReviews.localized)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(AppColors.textPrimary)
                
                Spacer()
                
                if viewModel.reviewsTotal > 0 {
                    Text(String(format: LocalizationKey.taskExpertReviewsCount.localized, viewModel.reviewsTotal))
                        .font(.system(size: 13))
                        .foregroundColor(AppColors.textTertiary)
                }
            }
            
            if isLoading && reviews.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
            } else if reviews.isEmpty {
                Text(LocalizationKey.taskExpertNoReviews.localized)
                    .font(.system(size: 14))
                    .foregroundColor(AppColors.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                LazyVStack(spacing: 16) {
                    ForEach(reviews) { review in
                        reviewRow(review: review)
                    }
                    
                    // 加载更多按钮
                    if viewModel.hasMoreReviews {
                        Button(action: {
                            viewModel.loadMoreReviews(expertId: expertId)
                        }) {
                            HStack(spacing: 8) {
                                if viewModel.isLoadingMoreReviews {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "arrow.down.circle")
                                        .font(.system(size: 14))
                                }
                                Text(viewModel.isLoadingMoreReviews ? LocalizationKey.commonLoading.localized : LocalizationKey.commonLoadMore.localized)
                                    .font(.system(size: 13))
                            }
                            .foregroundColor(AppColors.textSecondary)
                            .padding(.vertical, 12)
                            .frame(maxWidth: .infinity)
                        }
                        .disabled(viewModel.isLoadingMoreReviews)
                    }
                }
            }
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(UIColor.systemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 2)
        )
        .padding(.horizontal, 16)
    }
    
    @ViewBuilder
    private func reviewRow(review: PublicReview) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                // 星级评分（支持0.5星）
                HStack(spacing: 2) {
                    ForEach(1...5, id: \.self) { star in
                        let fullStars = Int(review.rating)
                        let hasHalfStar = review.rating - Double(fullStars) >= 0.5
                        
                        if star <= fullStars {
                            Image(systemName: "star.fill")
                                .font(.system(size: 14))
                                .foregroundColor(AppColors.warning)
                        } else if star == fullStars + 1 && hasHalfStar {
                            Image(systemName: "star.lefthalf.fill")
                                .font(.system(size: 14))
                                .foregroundColor(AppColors.warning)
                        } else {
                            Image(systemName: "star")
                                .font(.system(size: 14))
                                .foregroundColor(AppColors.textTertiary)
                        }
                    }
                }
                
                Spacer()
                
                // 评价时间
                Text(DateFormatterHelper.shared.formatTime(review.createdAt))
                    .font(.system(size: 12))
                    .foregroundColor(AppColors.textTertiary)
            }
            
            if let comment = review.comment, !comment.isEmpty {
                // 注意：后端已经做了HTML转义，这里直接显示是安全的
                Text(comment)
                    .font(.system(size: 14))
                    .foregroundColor(AppColors.textPrimary)
                    .lineSpacing(4)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(AppColors.cardBackground)
        )
    }
    
    @ViewBuilder
    private func emptyServicesView() -> some View {
        VStack(spacing: 16) {
            Image(systemName: "bag.badge.questionmark")
                .font(.system(size: 48, weight: .light))
                .foregroundColor(AppColors.textQuaternary)
            Text(LocalizationKey.taskExpertNoServices.localized)
                .font(.system(size: 14))
                .foregroundColor(AppColors.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
        .background(Color(UIColor.secondarySystemBackground).opacity(0.5))
        .cornerRadius(20)
        .padding(.horizontal, 16)
    }
}

// MARK: - ServiceCard

struct ServiceCard: View {
    let service: TaskExpertService
    
    var body: some View {
        HStack(spacing: 16) {
            // 服务图片
            if let images = service.images, let firstImage = images.first {
                AsyncImageView(
                    urlString: firstImage,
                    placeholder: Image(systemName: "photo"),
                    width: 100,
                    height: 100,
                    contentMode: .fill,
                    cornerRadius: AppCornerRadius.medium
                )
                .frame(width: 100, height: 100)
                .clipped()
                .cornerRadius(AppCornerRadius.medium)
            } else {
                RoundedRectangle(cornerRadius: AppCornerRadius.medium)
                    .fill(AppColors.textQuaternary.opacity(0.2))
                    .frame(width: 100, height: 100)
                    .overlay(
                        Image(systemName: "photo")
                            .font(.system(size: 24))
                            .foregroundColor(AppColors.textQuaternary)
                    )
            }
            
            // 服务信息
            VStack(alignment: .leading, spacing: 8) {
                Text(service.serviceName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(2)
                
                if let description = service.description, !description.isEmpty {
                    Text(description)
                        .font(.system(size: 13))
                        .foregroundColor(AppColors.textSecondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                // 价格
                HStack {
                    Text("£\(String(format: "%.2f", service.basePrice))")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(AppColors.primary)
                    
                    Spacer()
                    
                    // 查看详情箭头
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(AppColors.textTertiary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .background(AppColors.cardBackground)
        .cornerRadius(AppCornerRadius.large)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
}
