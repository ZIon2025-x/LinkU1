import SwiftUI

// 统一的加载状态视图组件 - 系统蓝风格
struct LoadingView: View {
    var message: String? = nil
    @State private var isAnimating = false
    
    var body: some View {
        VStack(spacing: 24) {
            ZStack {
                // 背景环
                Circle()
                    .stroke(AppColors.primary.opacity(0.08), lineWidth: 2.5)
                    .frame(width: 40, height: 40)
                
                // 动画环 - 使用系统蓝主色
                Circle()
                    .trim(from: 0, to: 0.7)
                    .stroke(
                        LinearGradient(colors: [AppColors.primary, AppColors.primary.opacity(0.2)], startPoint: .topLeading, endPoint: .bottomTrailing),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                    )
                    .frame(width: 40, height: 40)
                    .rotationEffect(Angle(degrees: isAnimating ? 360 : 0))
                    .onAppear {
                        withAnimation(Animation.linear(duration: 1.0).repeatForever(autoreverses: false)) {
                            isAnimating = true
                        }
                    }
            }
            
            if let message = message {
                Text(message)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(AppColors.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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

