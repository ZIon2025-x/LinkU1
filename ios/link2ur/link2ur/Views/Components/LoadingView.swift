import SwiftUI

// MARK: - 统一的加载状态视图组件 - 丝滑流畅的加载体验

/// 标准加载视图 - 系统蓝风格
struct LoadingView: View {
    var message: String? = nil
    @State private var isAnimating = false
    @State private var pulseScale: CGFloat = 1.0
    
    var body: some View {
        VStack(spacing: 24) {
            ZStack {
                // 脉冲背景
                Circle()
                    .fill(AppColors.primary.opacity(0.05))
                    .frame(width: 60, height: 60)
                    .scaleEffect(pulseScale)
                
                // 背景环
                Circle()
                    .stroke(AppColors.primary.opacity(0.08), lineWidth: 2.5)
                    .frame(width: 40, height: 40)
                
                // 动画环 - 使用系统蓝主色
                Circle()
                    .trim(from: 0, to: 0.7)
                    .stroke(
                        LinearGradient(
                            colors: [AppColors.primary, AppColors.primary.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                    )
                    .frame(width: 40, height: 40)
                    .rotationEffect(Angle(degrees: isAnimating ? 360 : 0))
            }
            
            if let message = message {
                Text(message)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(AppColors.textSecondary)
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            withAnimation(Animation.linear(duration: 0.8).repeatForever(autoreverses: false)) {
                isAnimating = true
            }
            withAnimation(Animation.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                pulseScale = 1.15
            }
        }
    }
}

/// 简洁的加载指示器（用于内联加载）
struct CompactLoadingView: View {
    @State private var isAnimating = false
    
    var body: some View {
        Circle()
            .trim(from: 0, to: 0.7)
            .stroke(AppColors.primary, style: StrokeStyle(lineWidth: 2, lineCap: .round))
            .frame(width: 20, height: 20)
            .rotationEffect(Angle(degrees: isAnimating ? 360 : 0))
            .onAppear {
                withAnimation(Animation.linear(duration: 0.7).repeatForever(autoreverses: false)) {
                    isAnimating = true
                }
            }
    }
}

/// 全屏加载视图（用于页面首次加载）
struct FullScreenLoadingView: View {
    var body: some View {
        ZStack {
            AppColors.background.ignoresSafeArea()
            LoadingView()
        }
    }
}

/// 点状加载动画（用于聊天等场景）
struct DotsLoadingView: View {
    @State private var animatingDots: [Bool] = [false, false, false]
    
    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(AppColors.primary)
                    .frame(width: 8, height: 8)
                    .scaleEffect(animatingDots[index] ? 1.0 : 0.5)
                    .opacity(animatingDots[index] ? 1.0 : 0.5)
            }
        }
        .onAppear {
            for index in 0..<3 {
                withAnimation(Animation.easeInOut(duration: 0.5).repeatForever(autoreverses: true).delay(Double(index) * 0.15)) {
                    animatingDots[index] = true
                }
            }
        }
    }
}

/// 成功动画视图
struct SuccessAnimationView: View {
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            Circle().stroke(AppColors.success.opacity(0.2), lineWidth: 3).frame(width: 60, height: 60)
            Circle().trim(from: 0, to: isAnimating ? 1 : 0)
                .stroke(AppColors.success, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .frame(width: 60, height: 60).rotationEffect(.degrees(-90))
            Image(systemName: "checkmark").font(.system(size: 28, weight: .bold))
                .foregroundColor(AppColors.success).scaleEffect(isAnimating ? 1 : 0).opacity(isAnimating ? 1 : 0)
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6, blendDuration: 0)) { isAnimating = true }
            HapticFeedback.success()
        }
    }
}

/// 错误动画视图
struct ErrorAnimationView: View {
    @State private var isAnimating = false
    @State private var shake: CGFloat = 0
    
    var body: some View {
        ZStack {
            Circle().fill(AppColors.error.opacity(0.1)).frame(width: 60, height: 60)
            Circle().stroke(AppColors.error, lineWidth: 3).frame(width: 60, height: 60)
            Image(systemName: "xmark").font(.system(size: 28, weight: .bold))
                .foregroundColor(AppColors.error).scaleEffect(isAnimating ? 1 : 0)
        }
        .offset(x: shake)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.5, blendDuration: 0)) { isAnimating = true }
            withAnimation(.spring(response: 0.1, dampingFraction: 0.3, blendDuration: 0).repeatCount(3, autoreverses: true)) { shake = 10 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.spring(response: 0.2, dampingFraction: 0.5, blendDuration: 0)) { shake = 0 }
            }
            HapticFeedback.error()
        }
    }
}
