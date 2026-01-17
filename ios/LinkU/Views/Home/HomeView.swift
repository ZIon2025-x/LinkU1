import SwiftUI

struct HomeView: View {
    @EnvironmentObject var appState: AppState
    @State private var searchText = ""
    
    var body: some View {
        NavigationView {
            ZStack(alignment: .top) {
                // 背景渐变：升级为多层弥散光晕
                AppColors.background.ignoresSafeArea()
                
                ZStack {
                    Circle()
                        .fill(AppColors.primary.opacity(0.15))
                        .frame(width: 300, height: 300)
                        .blur(radius: 60)
                        .offset(x: 180, y: -100)
                    
                    Circle()
                        .fill(AppColors.accentPink.opacity(0.1))
                        .frame(width: 250, height: 250)
                        .blur(radius: 50)
                        .offset(x: -150, y: 100)
                }
                .ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: AppSpacing.lg) {
                        // 1. 顶部 Header (个性化欢迎)
                        headerSection
                        
                        // 2. 搜索框 (现代感设计)
                        searchSection
                        
                        // 3. 核心功能金刚区 (快捷操作)
                        quickActionsSection
                        
                        // 4. 推荐任务 (横向滑动)
                        recommendedSection
                        
                        // 5. 最新动态 (垂直列表)
                        recentActivitySection
                    }
                    .padding(.bottom, 100)
                }
            }
            .navigationBarHidden(true)
        }
    }
    
    // MARK: - Subviews
    
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("下午好,")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(AppColors.textSecondary)
                
                Text("\(appState.currentUser?.username ?? "Link²Urer") 👋")
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundColor(AppColors.textPrimary)
            }
            
            Spacer()
            
            NavigationLink(destination: MessageView()) {
                Image(systemName: "bell.badge.fill")
                    .symbolRenderingMode(.hierarchical)
                    .font(.system(size: 22))
                    .foregroundColor(AppColors.primary)
                    .padding(12)
                    .glassStyle(cornerRadius: AppCornerRadius.round)
            }
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.top, AppSpacing.sm)
    }
    
    private var searchSection: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(AppColors.textSecondary)
            TextField("搜索任务、达人或动态...", text: $searchText)
                .font(.system(size: 15))
        }
        .padding()
        .background(AppColors.cardBackground)
        .cornerRadius(AppCornerRadius.medium)
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)
        .padding(.horizontal, AppSpacing.md)
    }
    
    private var quickActionsSection: some View {
        VStack(spacing: AppSpacing.md) {
            HStack(spacing: AppSpacing.md) {
                quickActionButton(title: "发布任务", icon: "plus.circle.fill", color: AppColors.primary, dest: AnyView(CreateTaskView()))
                quickActionButton(title: "发布商品", icon: "tag.fill", color: AppColors.accentOrange, dest: AnyView(CreateFleaMarketItemView()))
            }
            
            HStack(spacing: AppSpacing.md) {
                quickActionButton(title: "热门论坛", icon: "bubble.left.and.bubble.right.fill", color: AppColors.success, dest: AnyView(ForumView()))
                quickActionButton(title: "排行榜", icon: "trophy.fill", color: AppColors.accentPurple, dest: AnyView(LeaderboardView()))
            }
        }
        .padding(.horizontal, AppSpacing.md)
    }
    
    private func quickActionButton(title: String, icon: String, color: Color, dest: AnyView) -> some View {
        NavigationLink(destination: dest) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 44, height: 44)
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(color)
                }
                
                Text(title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(AppColors.textPrimary)
                
                Spacer()
            }
            .padding(12)
            .background(AppColors.cardBackground)
            .cornerRadius(AppCornerRadius.medium)
            .shadow(color: Color.black.opacity(0.03), radius: 10, x: 0, y: 5)
        }
        .buttonStyle(PlainButtonStyle())
        .bouncyButton()
    }
    
    private var recommendedSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack {
                Text("为你推荐")
                    .font(.system(size: 22, weight: .black, design: .rounded))
                Spacer()
                NavigationLink(destination: TasksView()) {
                    Text("更多")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(AppColors.primary)
                }
            }
            .padding(.horizontal, AppSpacing.md)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppSpacing.md) {
                    ForEach(0..<5) { _ in
                        ModernTaskCard()
                    }
                }
                .padding(.horizontal, AppSpacing.md)
                .padding(.bottom, 8)
            }
        }
    }
    
    private var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("最新动态")
                .font(.system(size: 22, weight: .black, design: .rounded))
                .padding(.horizontal, AppSpacing.md)
            
            ForEach(0..<3) { _ in
                ActivityRow()
            }
        }
    }
}

// MARK: - Modern Task Card
struct ModernTaskCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundColor(AppColors.accentOrange)
                    .font(.system(size: 12, weight: .bold))
                Text("急需")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(AppColors.accentOrange)
                Spacer()
                PriceTag(price: 150, fontSize: 16)
            }
            
            Text("英语文档翻译")
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(AppColors.textPrimary)
            
            Text("需要明天下午前完成一份关于金融科技的文档翻译...")
                .font(.system(size: 13))
                .foregroundColor(AppColors.textSecondary)
                .lineLimit(2)
            
            Spacer(minLength: 8)
            
            HStack {
                Label("上海", systemImage: "mappin.and.ellipse")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(AppColors.textTertiary)
                Spacer()
                Text("2小时前")
                    .font(.system(size: 10))
                    .foregroundColor(AppColors.textTertiary)
            }
        }
        .padding(16)
        .frame(width: 200, height: 180)
        .cardStyle(radius: AppCornerRadius.large)
    }
}

// MARK: - Modern Activity Row
struct ActivityRow: View {
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(AppColors.primaryGradient)
                    .frame(width: 52, height: 52)
                Image(systemName: "person.fill")
                    .foregroundColor(.white)
                    .font(.system(size: 24))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("用户 User123")
                    .font(.system(size: 15, weight: .bold))
                Text("发布了新商品：iPhone 15 Pro Max")
                    .font(.system(size: 13))
                    .foregroundColor(AppColors.textSecondary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(AppColors.textTertiary)
        }
        .padding(16)
        .background(AppColors.cardBackground)
        .cornerRadius(AppCornerRadius.medium)
        .padding(.horizontal, AppSpacing.md)
        .shadow(color: Color.black.opacity(0.02), radius: 8, x: 0, y: 4)
    }
}
