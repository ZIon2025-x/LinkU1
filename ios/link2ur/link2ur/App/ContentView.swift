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
                // 正在检查登录状态，显示视频加载界面
                ZStack {
                    // 视频背景（全屏循环播放，从多个视频中随机选择）
                    VideoLoadingView(
                        videoName: "linker",  // 默认视频名（如果 videoNames 为空时使用）
                        videoExtension: "mp4",
                        videoNames: ["linker1", "linker2", "linker3", "linker4"],  // 4个视频文件名（不含扩展名）
                        showOverlay: false
                    )
                    
                    // 可选的半透明遮罩（如果需要降低视频亮度）
                    Color.black.opacity(0.05)
                        .ignoresSafeArea()
                    
                    // 右上角倒计时圆圈（可选，如果需要显示加载进度）
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
                    
                    // 中间文本：Link to your world（蓝色字体，world 是蓝底白字）
                    VStack {
                        Spacer()
                        HStack(spacing: 4) {
                            Text("Link to your ")
                                .font(AppTypography.largeTitle)
                                .fontWeight(.bold)
                                .foregroundColor(AppColors.primary)
                            
                            Text("world")
                                .font(AppTypography.largeTitle)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 4)
                                .background(AppColors.primary)
                                .cornerRadius(8)
                        }
                        .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
                        .padding(.top, 100)  // 往下移动（增加顶部间距）
                        Spacer()
                    }
                    
                    // 左下角 Logo
                    VStack {
                        Spacer()
                        HStack {
                            Image("Logo")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 80, height: 80)
                                .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
                            Spacer()
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)  // 确保左对齐
                        .padding(.leading, AppSpacing.lg)
                        .padding(.bottom, AppSpacing.lg)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)  // 确保在左下角
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

