import SwiftUI

struct HomeView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        NavigationView {
            ZStack {
                AppColors.background
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: AppSpacing.lg) {
                        // 顶部欢迎区域
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("你好，\(appState.currentUser?.username ?? "Link²Urer") 👋")
                                    .font(.title)
                                    .fontWeight(.bold)
                                    .foregroundColor(AppColors.textPrimary)
                                
                                Text("今天想做点什么？")
                                    .font(.subheadline)
                                    .foregroundColor(AppColors.textSecondary)
                            }
                            
                            Spacer()
                            
                            NavigationLink(destination: MessageView()) {
                                ZStack(alignment: .topTrailing) {
                                    Image(systemName: "bell.fill")
                                        .font(.title3)
                                        .foregroundColor(AppColors.textPrimary)
                                    
                                    Circle()
                                        .fill(AppColors.error)
                                        .frame(width: 8, height: 8)
                                        .offset(x: 2, y: -2)
                                }
                            }
                        }
                        .padding(.horizontal, AppSpacing.md)
                        .padding(.top, AppSpacing.sm)
                        
                        // 快捷操作
                        VStack(spacing: AppSpacing.sm) {
                            HStack(spacing: AppSpacing.md) {
                                NavigationLink(destination: CreateTaskView()) {
                                    ShortcutButtonContent(
                                        title: "发布任务",
                                        icon: "plus.circle.fill",
                                        gradient: [AppColors.primary, AppColors.primary.opacity(0.8)]
                                    )
                                }
                                .buttonStyle(PlainButtonStyle())
                                
                                NavigationLink(destination: CreateFleaMarketItemView()) {
                                    ShortcutButtonContent(
                                        title: "发布商品",
                                        icon: "tag.fill",
                                        gradient: [AppColors.warning, AppColors.warning.opacity(0.8)]
                                    )
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                            
                            HStack(spacing: AppSpacing.md) {
                                NavigationLink(destination: ForumView()) {
                                    ShortcutButtonContent(
                                        title: "论坛",
                                        icon: "bubble.left.and.bubble.right.fill",
                                        gradient: [AppColors.success, AppColors.success.opacity(0.8)]
                                    )
                                }
                                .buttonStyle(PlainButtonStyle())
                                
                                NavigationLink(destination: LeaderboardView()) {
                                    ShortcutButtonContent(
                                        title: "排行榜",
                                        icon: "trophy.fill",
                                        gradient: [Color(red: 0.9, green: 0.7, blue: 0.2), Color(red: 0.9, green: 0.7, blue: 0.2).opacity(0.8)]
                                    )
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(.horizontal, AppSpacing.md)
                        
                        // 推荐任务
                        VStack(alignment: .leading, spacing: AppSpacing.md) {
                            HStack {
                                Text("推荐任务")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(AppColors.textPrimary)
                                
                                Spacer()
                                
                                NavigationLink(destination: TasksView()) {
                                    Text("查看全部")
                                }
                                .buttonStyle(PlainButtonStyle())
                                .font(.subheadline)
                                .foregroundColor(AppColors.primary)
                            }
                            .padding(.horizontal, AppSpacing.md)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: AppSpacing.md) {
                                    ForEach(0..<5) { _ in
                                        RecommendedTaskCard()
                                    }
                                }
                                .padding(.horizontal, AppSpacing.md)
                            }
                        }
                        
                        // 最新动态
                        VStack(alignment: .leading, spacing: AppSpacing.md) {
                            Text("最新动态")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(AppColors.textPrimary)
                                .padding(.horizontal, AppSpacing.md)
                            
                            ForEach(0..<3) { _ in
                                ActivityRow()
                            }
                        }
                        .padding(.bottom, AppSpacing.xl)
                    }
                }
            }
            .navigationBarHidden(true)
        }
    }
}

// 快捷按钮内容组件
struct ShortcutButtonContent: View {
    let title: String
    let icon: String
    let gradient: [Color]
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 32))
                .foregroundColor(.white)
            
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 100)
        .background(
            LinearGradient(
                gradient: Gradient(colors: gradient),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(AppCornerRadius.large)
        .shadow(color: gradient[0].opacity(0.3), radius: 8, x: 0, y: 4)
    }
}

// 快捷按钮组件（用于需要action的情况）
struct ShortcutButton: View {
    let title: String
    let icon: String
    let gradient: [Color]
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ShortcutButtonContent(title: title, icon: icon, gradient: gradient)
        }
    }
}

// 推荐任务卡片组件
struct RecommendedTaskCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                ZStack {
                    Circle()
                        .fill(AppColors.primaryLight)
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: "doc.text.fill")
                        .foregroundColor(AppColors.primary)
                }
                
                Spacer()
                
                Text("¥ 150")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(AppColors.error)
            }
            
            Text("急需一名翻译人员")
                .font(.headline)
                .foregroundColor(AppColors.textPrimary)
                .lineLimit(1)
            
            Text("需要在明天下午前完成一份英语文档翻译...")
                .font(.caption)
                .foregroundColor(AppColors.textSecondary)
                .lineLimit(2)
            
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.caption2)
                    Text("上海")
                        .font(.caption)
                }
                .foregroundColor(AppColors.textSecondary)
                
                Spacer()
                
                Text("2小时前")
                    .font(.caption2)
                    .foregroundColor(AppColors.textSecondary)
            }
        }
        .padding(AppSpacing.md)
        .frame(width: 200)
        .background(AppColors.cardBackground)
        .cornerRadius(AppCornerRadius.medium)
        .shadow(color: AppShadow.small.color, radius: AppShadow.small.radius, x: AppShadow.small.x, y: AppShadow.small.y)
    }
}

// 动态行组件
struct ActivityRow: View {
    var body: some View {
        HStack(spacing: AppSpacing.md) {
            ZStack {
                Circle()
                    .fill(AppColors.primaryLight)
                    .frame(width: 48, height: 48)
                
                Image(systemName: "person.circle.fill")
                    .foregroundColor(AppColors.primary)
                    .font(.title3)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("用户 User123 发布了新商品")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(AppColors.textPrimary)
                
                Text("全新的 iPhone 15 Pro Max，未拆封...")
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(AppColors.textSecondary)
        }
        .padding(AppSpacing.md)
        .background(AppColors.cardBackground)
        .cornerRadius(AppCornerRadius.medium)
        .padding(.horizontal, AppSpacing.md)
        .shadow(color: AppShadow.small.color, radius: AppShadow.small.radius, x: AppShadow.small.x, y: AppShadow.small.y)
    }
}
