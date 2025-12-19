import SwiftUI

// 统一的加载状态视图组件
struct LoadingView: View {
    var message: String? = nil
    @State private var opacity = 0.0
    
    var body: some View {
        VStack(spacing: AppSpacing.md) {
            ProgressView()
                .scaleEffect(1.2)
                .tint(AppColors.primary)
            
            if let message = message {
                Text(message)
                    .font(AppTypography.subheadline)
                    .foregroundColor(AppColors.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(AppSpacing.xl)
        .opacity(opacity)
        .onAppear {
            withAnimation(.easeIn(duration: 0.3)) {
                opacity = 1.0
            }
        }
    }
}

// 简洁的加载指示器（用于内联加载）
struct CompactLoadingView: View {
    var body: some View {
        ProgressView()
            .tint(AppColors.primary)
            .scaleEffect(0.9)
    }
}

// 全屏加载视图（用于页面首次加载）
struct FullScreenLoadingView: View {
    var body: some View {
        ZStack {
            AppColors.background
                .ignoresSafeArea()
            
            LoadingView()
        }
    }
}

