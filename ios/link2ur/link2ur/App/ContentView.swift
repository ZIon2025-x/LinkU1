import SwiftUI

public struct ContentView: View {
    @EnvironmentObject public var appState: AppState
    @State private var remainingTime: Double = 3.0 // 剩余时间（秒）
    @State private var progress: Double = 1.0 // 进度值（1.0 到 0.0）
    @State private var timer: Timer?
    @State private var hasStartedAnimation: Bool = false // 标记是否已启动动画
    
    public var body: some View {
        Group {
            if appState.isCheckingLoginStatus {
                // 正在检查登录状态，显示加载界面
                ZStack {
                    // 现代渐变背景（与登录页面一致）
                    ZStack {
                        // 主渐变背景
                        LinearGradient(
                            gradient: Gradient(colors: [
                                AppColors.primary.opacity(0.12),
                                AppColors.primary.opacity(0.06),
                                AppColors.primary.opacity(0.02),
                                AppColors.background
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .ignoresSafeArea()
                        
                        // 动态装饰性圆形背景
                        Circle()
                            .fill(
                                RadialGradient(
                                    gradient: Gradient(colors: [
                                        AppColors.primary.opacity(0.08),
                                        AppColors.primary.opacity(0.02),
                                        Color.clear
                                    ]),
                                    center: .center,
                                    startRadius: 50,
                                    endRadius: 200
                                )
                            )
                            .frame(width: 400, height: 400)
                            .offset(x: -180, y: -350)
                            .blur(radius: 20)
                        
                        Circle()
                            .fill(
                                RadialGradient(
                                    gradient: Gradient(colors: [
                                        AppColors.primary.opacity(0.06),
                                        AppColors.primary.opacity(0.01),
                                        Color.clear
                                    ]),
                                    center: .center,
                                    startRadius: 40,
                                    endRadius: 150
                                )
                            )
                            .frame(width: 300, height: 300)
                            .offset(x: 220, y: 450)
                            .blur(radius: 15)
                    }
                    
                    // 右上角倒计时圆圈
                    VStack {
                        HStack {
                            Spacer()
                            ZStack {
                                // 背景圆圈
                                Circle()
                                    .stroke(AppColors.separator.opacity(0.3), lineWidth: 3)
                                    .frame(width: 40, height: 40)
                                
                                // 进度圆圈（带动画）
                                Circle()
                                    .trim(from: 0, to: CGFloat(progress))
                                    .stroke(
                                        LinearGradient(
                                            gradient: Gradient(colors: AppColors.gradientPrimary),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                                    )
                                    .frame(width: 40, height: 40)
                                    .rotationEffect(.degrees(-90))
                                
                                // 时间文字
                                Text("\(max(0, Int(ceil(remainingTime))))")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(AppColors.textPrimary)
                            }
                            .padding(.top, 8)
                            .padding(.trailing, 16)
                            .onAppear {
                                // 当加载界面出现时，立即启动动画
                                if appState.isCheckingLoginStatus && !hasStartedAnimation {
                                    remainingTime = 3.0
                                    progress = 0.0  // 从空开始
                                    hasStartedAnimation = true
                                    
                                    // 立即启动动画，从空到满
                                    withAnimation(.linear(duration: 3.0)) {
                                        progress = 1.0
                                    }
                                    
                                    // 使用定时器更新显示的数字
                                    timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                                        if remainingTime > 0 {
                                            remainingTime = max(0, remainingTime - 0.1)
                                        } else {
                                            timer?.invalidate()
                                            timer = nil
                                        }
                                    }
                                }
                            }
                        }
                        Spacer()
                    }
                    
                    // Logo 和加载指示器
                    VStack(spacing: AppSpacing.lg) {
                        ZStack {
                            // 外圈光晕效果
                            Circle()
                                .fill(
                                    RadialGradient(
                                        gradient: Gradient(colors: [
                                            AppColors.primary.opacity(0.15),
                                            AppColors.primary.opacity(0.05),
                                            Color.clear
                                        ]),
                                        center: .center,
                                        startRadius: 40,
                                        endRadius: 70
                                    )
                                )
                                .frame(width: 140, height: 140)
                                .blur(radius: 8)
                            
                            // 渐变背景圆圈
                            Circle()
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: AppColors.gradientPrimary),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 110, height: 110)
                                .shadow(color: AppColors.primary.opacity(0.3), radius: 20, x: 0, y: 10)
                                .overlay(
                                    Circle()
                                        .stroke(
                                            LinearGradient(
                                                gradient: Gradient(colors: [
                                                    Color.white.opacity(0.3),
                                                    Color.clear
                                                ]),
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ),
                                            lineWidth: 2
                                        )
                                )
                            
                            Image("Logo")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 75, height: 75)
                                .clipShape(Circle())
                                .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                        }
                        
                        VStack(spacing: AppSpacing.xs) {
                            Text(LocalizationKey.appName.localized)
                                .font(AppTypography.largeTitle)
                                .fontWeight(.bold)
                                .foregroundColor(AppColors.textPrimary)
                            
                            Text(LocalizationKey.appTagline.localized)
                                .font(AppTypography.subheadline)
                                .foregroundColor(AppColors.textSecondary)
                        }
                        
                        // 加载指示器
                        ProgressView()
                            .scaleEffect(1.2)
                            .progressViewStyle(CircularProgressViewStyle(tint: AppColors.primary))
                            .padding(.top, AppSpacing.md)
                    }
                }
            } else if appState.isAuthenticated || appState.userSkippedLogin {
                // 已登录或用户选择跳过登录，都显示主界面
                MainTabView()
            } else {
                LoginView()
            }
        }
        .onAppear {
            // 静默检查登录状态，但不强制登录
            appState.checkLoginStatus()
        }
        .onChange(of: appState.isCheckingLoginStatus) { isChecking in
            if !isChecking {
                // 停止倒计时
                timer?.invalidate()
                timer = nil
                remainingTime = 3.0 // 重置
                progress = 0.0 // 重置为空
                hasStartedAnimation = false // 重置标记
            }
        }
        .onDisappear {
            // 清理定时器
            timer?.invalidate()
            timer = nil
        }
    }
    
    public init() {}
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(AppState())
    }
}

