import SwiftUI

// MARK: - 骨架屏动画效果
/// 丝滑的骨架屏加载动画，提供更优雅的加载体验

/// 骨架屏shimmer效果修饰符
struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0
    let duration: Double
    let delay: Double
    
    init(duration: Double = 1.5, delay: Double = 0) {
        self.duration = duration
        self.delay = delay
    }
    
    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geometry in
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.clear,
                            Color.white.opacity(0.4),
                            Color.clear
                        ]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geometry.size.width * 2)
                    .offset(x: -geometry.size.width + (geometry.size.width * 2 * phase))
                }
            )
            .mask(content)
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    withAnimation(
                        Animation
                            .linear(duration: duration)
                            .repeatForever(autoreverses: false)
                    ) {
                        phase = 1
                    }
                }
            }
    }
}

extension View {
    /// 添加shimmer闪烁效果
    func shimmer(duration: Double = 1.5, delay: Double = 0) -> some View {
        modifier(ShimmerModifier(duration: duration, delay: delay))
    }
}

// MARK: - 基础骨架元素

/// 骨架占位形状
struct SkeletonShape: View {
    let width: CGFloat?
    let height: CGFloat
    let cornerRadius: CGFloat
    
    init(
        width: CGFloat? = nil,
        height: CGFloat = 16,
        cornerRadius: CGFloat = AppCornerRadius.small
    ) {
        self.width = width
        self.height = height
        self.cornerRadius = cornerRadius
    }
    
    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(AppColors.fill)
            .frame(width: width, height: height)
            .shimmer()
    }
}

/// 骨架圆形
struct SkeletonCircle: View {
    let size: CGFloat
    
    init(size: CGFloat = 48) {
        self.size = size
    }
    
    var body: some View {
        Circle()
            .fill(AppColors.fill)
            .frame(width: size, height: size)
            .shimmer()
    }
}

/// 骨架图片
struct SkeletonImage: View {
    let width: CGFloat?
    let height: CGFloat
    let cornerRadius: CGFloat
    
    init(
        width: CGFloat? = nil,
        height: CGFloat = 120,
        cornerRadius: CGFloat = AppCornerRadius.medium
    ) {
        self.width = width
        self.height = height
        self.cornerRadius = cornerRadius
    }
    
    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(AppColors.fill)
            .frame(width: width, height: height)
            .shimmer()
    }
}

// MARK: - 任务卡片骨架屏

struct TaskCardSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            // 图片区域
            SkeletonImage(height: 100, cornerRadius: AppCornerRadius.medium)
            
            // 标题
            SkeletonShape(width: nil, height: 18, cornerRadius: AppCornerRadius.tiny)
            
            // 描述
            SkeletonShape(width: 120, height: 14, cornerRadius: AppCornerRadius.tiny)
            
            // 底部信息
            HStack {
                SkeletonShape(width: 60, height: 12, cornerRadius: AppCornerRadius.tiny)
                Spacer()
                SkeletonShape(width: 50, height: 20, cornerRadius: AppCornerRadius.small)
            }
        }
        .padding(AppSpacing.md)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppCornerRadius.large, style: .continuous))
    }
}

// MARK: - 活动卡片骨架屏

struct ActivityCardSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            // 头部
            HStack(spacing: AppSpacing.md) {
                SkeletonCircle(size: 56)
                
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    SkeletonShape(width: 150, height: 18, cornerRadius: AppCornerRadius.tiny)
                    SkeletonShape(width: 100, height: 14, cornerRadius: AppCornerRadius.tiny)
                }
                
                Spacer()
            }
            
            // 分隔线
            SkeletonShape(height: 1, cornerRadius: 0)
            
            // 信息行
            HStack(spacing: AppSpacing.lg) {
                SkeletonShape(width: 80, height: 14, cornerRadius: AppCornerRadius.tiny)
                Spacer()
                SkeletonShape(width: 60, height: 14, cornerRadius: AppCornerRadius.tiny)
            }
        }
        .padding(AppSpacing.md)
        .frame(width: 280)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppCornerRadius.large, style: .continuous))
    }
}

// MARK: - 论坛板块骨架屏

struct ForumCategorySkeleton: View {
    var body: some View {
        HStack(spacing: AppSpacing.md) {
            // 图标容器
            SkeletonCircle(size: 64)
                .background(
                    RoundedRectangle(cornerRadius: AppCornerRadius.large, style: .continuous)
                        .fill(AppColors.primary.opacity(0.1))
                )
            
            // 信息区域
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                SkeletonShape(width: 150, height: 18, cornerRadius: AppCornerRadius.tiny)
                SkeletonShape(width: 200, height: 14, cornerRadius: AppCornerRadius.tiny)
                
                // 底部信息
                HStack(spacing: AppSpacing.sm) {
                    SkeletonShape(width: 60, height: 12, cornerRadius: AppCornerRadius.tiny)
                    SkeletonShape(width: 50, height: 12, cornerRadius: AppCornerRadius.tiny)
                }
            }
            
            Spacer()
            
            // 箭头
            SkeletonShape(width: 14, height: 14, cornerRadius: AppCornerRadius.tiny)
        }
        .padding(AppSpacing.md)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppCornerRadius.large, style: .continuous))
    }
}

// MARK: - 论坛帖子骨架屏

struct ForumPostSkeleton: View {
    var body: some View {
        HStack(spacing: AppSpacing.md) {
            // 头像
            SkeletonCircle(size: 44)
            
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                // 用户名和时间
                HStack {
                    SkeletonShape(width: 80, height: 14, cornerRadius: AppCornerRadius.tiny)
                    Spacer()
                    SkeletonShape(width: 50, height: 12, cornerRadius: AppCornerRadius.tiny)
                }
                
                // 标题
                SkeletonShape(height: 16, cornerRadius: AppCornerRadius.tiny)
                
                // 内容预览
                SkeletonShape(width: 200, height: 14, cornerRadius: AppCornerRadius.tiny)
            }
        }
        .padding(AppSpacing.md)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppCornerRadius.medium, style: .continuous))
    }
}

// MARK: - 列表骨架屏

struct ListSkeleton: View {
    let itemCount: Int
    let itemHeight: CGFloat
    let spacing: CGFloat
    
    init(itemCount: Int = 5, itemHeight: CGFloat = 80, spacing: CGFloat = AppSpacing.md) {
        self.itemCount = itemCount
        self.itemHeight = itemHeight
        self.spacing = spacing
    }
    
    var body: some View {
        VStack(spacing: spacing) {
            ForEach(0..<itemCount, id: \.self) { index in
                HStack(spacing: AppSpacing.md) {
                    SkeletonCircle(size: 48)
                    
                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        SkeletonShape(height: 16, cornerRadius: AppCornerRadius.tiny)
                        SkeletonShape(width: 150, height: 14, cornerRadius: AppCornerRadius.tiny)
                    }
                    
                    Spacer()
                }
                .padding(AppSpacing.md)
                .background(AppColors.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: AppCornerRadius.medium, style: .continuous))
                .opacity(1.0 - Double(index) * 0.1) // 渐变透明度
            }
        }
    }
}

// MARK: - 网格骨架屏

struct GridSkeleton: View {
    let columns: Int
    let rows: Int
    let spacing: CGFloat
    
    init(columns: Int = 2, rows: Int = 3, spacing: CGFloat = AppSpacing.md) {
        self.columns = columns
        self.rows = rows
        self.spacing = spacing
    }
    
    var body: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: spacing), count: columns),
            spacing: spacing
        ) {
            ForEach(0..<(columns * rows), id: \.self) { index in
                TaskCardSkeleton()
                    .opacity(1.0 - Double(index) * 0.05)
            }
        }
    }
}

// MARK: - 轮播骨架屏

struct BannerSkeleton: View {
    var body: some View {
        SkeletonImage(height: 180, cornerRadius: AppCornerRadius.large)
            .padding(.horizontal, AppSpacing.md)
    }
}

// MARK: - 详情页骨架屏

struct DetailSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            // 图片
            SkeletonImage(height: 250, cornerRadius: 0)
            
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                // 标题
                SkeletonShape(height: 24, cornerRadius: AppCornerRadius.small)
                
                // 副标题
                SkeletonShape(width: 200, height: 16, cornerRadius: AppCornerRadius.tiny)
                
                // 分隔
                SkeletonShape(height: 1, cornerRadius: 0)
                    .padding(.vertical, AppSpacing.sm)
                
                // 内容行
                ForEach(0..<4, id: \.self) { index in
                    HStack(spacing: AppSpacing.md) {
                        SkeletonCircle(size: 24)
                        SkeletonShape(height: 16, cornerRadius: AppCornerRadius.tiny)
                    }
                    .opacity(1.0 - Double(index) * 0.1)
                }
            }
            .padding(.horizontal, AppSpacing.md)
            
            Spacer()
        }
    }
}

// MARK: - 个人资料骨架屏

struct ProfileSkeleton: View {
    var body: some View {
        VStack(spacing: AppSpacing.lg) {
            // 头像
            SkeletonCircle(size: 100)
            
            // 用户名
            SkeletonShape(width: 120, height: 24, cornerRadius: AppCornerRadius.small)
            
            // 简介
            SkeletonShape(width: 200, height: 16, cornerRadius: AppCornerRadius.tiny)
            
            // 统计信息
            HStack(spacing: AppSpacing.xl) {
                ForEach(0..<3, id: \.self) { _ in
                    VStack(spacing: AppSpacing.xs) {
                        SkeletonShape(width: 40, height: 20, cornerRadius: AppCornerRadius.small)
                        SkeletonShape(width: 50, height: 14, cornerRadius: AppCornerRadius.tiny)
                    }
                }
            }
            .padding(.top, AppSpacing.md)
        }
    }
}

// MARK: - 骨架屏容器

/// 骨架屏容器 - 自动根据加载状态切换
struct SkeletonContainer<Content: View, Skeleton: View>: View {
    let isLoading: Bool
    let content: () -> Content
    let skeleton: () -> Skeleton
    
    init(
        isLoading: Bool,
        @ViewBuilder content: @escaping () -> Content,
        @ViewBuilder skeleton: @escaping () -> Skeleton
    ) {
        self.isLoading = isLoading
        self.content = content
        self.skeleton = skeleton
    }
    
    var body: some View {
        ZStack {
            if isLoading {
                skeleton()
                    .transition(.opacity)
            } else {
                content()
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            }
        }
        .animation(AnimationHelper.silkySpring, value: isLoading)
    }
}

// MARK: - 预览

#Preview("Skeleton Components") {
    ScrollView {
        VStack(spacing: AppSpacing.xl) {
            Group {
                Text("任务卡片骨架屏")
                    .font(AppTypography.bodyBold)
                TaskCardSkeleton()
                    .frame(width: 200)
            }
            
            Divider()
            
            Group {
                Text("活动卡片骨架屏")
                    .font(AppTypography.bodyBold)
                ActivityCardSkeleton()
            }
            
            Divider()
            
            Group {
                Text("论坛帖子骨架屏")
                    .font(AppTypography.bodyBold)
                ForumPostSkeleton()
            }
            
            Divider()
            
            Group {
                Text("Banner骨架屏")
                    .font(AppTypography.bodyBold)
                BannerSkeleton()
            }
            
            Divider()
            
            Group {
                Text("列表骨架屏")
                    .font(AppTypography.bodyBold)
                ListSkeleton(itemCount: 3)
            }
        }
        .padding()
    }
    .background(AppColors.background)
}
