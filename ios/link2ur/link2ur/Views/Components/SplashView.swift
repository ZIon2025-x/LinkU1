import SwiftUI

/// 启动屏：专业简洁，Logo + Slogan + 呼吸动效，支持暗黑模式
struct SplashView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var logoOpacity: Double = 0.85
    @State private var textOpacity: Double = 0.0
    
    private var isDarkMode: Bool { colorScheme == .dark }
    
    var body: some View {
        ZStack {
            // 背景：浅色 / 暗黑模式
            backgroundView
            
            VStack(spacing: 0) {
                Spacer()
                
                // Logo 容器
                logoContainer
                
                // Slogan
                sloganView
                    .opacity(textOpacity)
                    .padding(.top, 20)
                
                Spacer()
                
                // 底部压舱石：品牌签名，极克制
                Text("POWERED BY Link²Ur")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(isDarkMode ? Color.white.opacity(0.2) : Color(white: 0.65))
                    .tracking(0.5)
                    .padding(.bottom, 36)
            }
        }
        .onAppear {
            startAnimations()
        }
    }
    
    // MARK: - 背景（微渐变 + 弥散光，空气感与现代科技感）
    private var backgroundView: some View {
        Group {
            if isDarkMode {
                // 暗色：深底 + 极浅蓝绿弥散光
                ZStack {
                    Color(red: 0.07, green: 0.07, blue: 0.10)
                        .ignoresSafeArea()
                    // 非对称微渐变：左上略偏蓝
                    LinearGradient(
                        colors: [
                            Color(red: 0.12, green: 0.14, blue: 0.22),
                            Color(red: 0.07, green: 0.07, blue: 0.10)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .opacity(0.6)
                    .ignoresSafeArea()
                    meshOrbsDark
                }
            } else {
                // 浅色：微渐变基底 + 角落弥散光（蓝绿色）
                ZStack {
                    // 1. 微渐变基底：极浅品牌色非对称渐变，避免纯白单调
                    LinearGradient(
                        colors: [
                            Color(red: 0.97, green: 0.98, blue: 1.0),   // 极浅蓝
                            Color(red: 0.99, green: 0.99, blue: 1.0),   // 近乎白
                            Color(red: 0.98, green: 0.99, blue: 0.98)   // 极浅青
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .ignoresSafeArea()
                    // 2. 弥散光：角落模糊蓝绿色块，增加深邃感与空气感
                    meshOrbsLight
                }
            }
        }
    }
    
    /// 浅色模式：角落弥散光（蓝、青绿，大范围模糊）
    private var meshOrbsLight: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                // 左上：极浅蓝
                Ellipse()
                    .fill(
                        RadialGradient(
                            colors: [AppColors.primary.opacity(0.12), AppColors.primary.opacity(0.02), Color.clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: w * 0.5
                        )
                    )
                    .frame(width: w * 0.85, height: w * 0.85)
                    .blur(radius: 60)
                    .offset(x: -w * 0.2, y: -h * 0.15)
                // 右下：极浅青绿
                Ellipse()
                    .fill(
                        RadialGradient(
                            colors: [Color(red: 0.4, green: 0.75, blue: 0.85).opacity(0.1), Color(red: 0.5, green: 0.8, blue: 0.85).opacity(0.02), Color.clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: w * 0.45
                        )
                    )
                    .frame(width: w * 0.8, height: w * 0.8)
                    .blur(radius: 70)
                    .offset(x: w * 0.25, y: h * 0.2)
                // 右上：极淡青，补充光感
                Ellipse()
                    .fill(
                        RadialGradient(
                            colors: [Color(red: 0.45, green: 0.7, blue: 0.9).opacity(0.06), Color.clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: w * 0.4
                        )
                    )
                    .frame(width: w * 0.7, height: w * 0.7)
                    .blur(radius: 55)
                    .offset(x: w * 0.3, y: -h * 0.1)
            }
        }
        .ignoresSafeArea()
    }
    
    /// 暗色模式：角落弥散光（低饱和度蓝绿）
    private var meshOrbsDark: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                Ellipse()
                    .fill(
                        RadialGradient(
                            colors: [Color(red: 0.2, green: 0.4, blue: 0.6).opacity(0.15), Color.clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: w * 0.5
                        )
                    )
                    .frame(width: w * 0.9, height: w * 0.9)
                    .blur(radius: 80)
                    .offset(x: -w * 0.15, y: -h * 0.2)
                Ellipse()
                    .fill(
                        RadialGradient(
                            colors: [Color(red: 0.2, green: 0.5, blue: 0.55).opacity(0.12), Color.clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: w * 0.45
                        )
                    )
                    .frame(width: w * 0.85, height: w * 0.85)
                    .blur(radius: 90)
                    .offset(x: w * 0.3, y: h * 0.25)
            }
        }
        .ignoresSafeArea()
    }
    
    // MARK: - Logo 容器
    private var logoContainer: some View {
        ZStack {
            Circle()
                .fill(isDarkMode ? Color.white.opacity(0.1) : Color.white)
                .overlay(
                    Circle()
                        .stroke(
                            isDarkMode ? Color.white.opacity(0.08) : Color.black.opacity(0.04),
                            lineWidth: 1
                        )
                )
                .shadow(color: Color.black.opacity(isDarkMode ? 0.2 : 0.06), radius: 20, x: 0, y: 8)
                .shadow(color: AppColors.primary.opacity(isDarkMode ? 0.15 : 0.08), radius: 16, x: 0, y: 6)
                .frame(width: 150, height: 150)
            
            Image("Logo")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 108, height: 108)
                .saturation(1.3)
                .brightness(isDarkMode ? 0.12 : 0.08)
                .opacity(logoOpacity)
        }
    }
    
    // MARK: - Slogan（系统无衬线 + 略增字间距）
    private var sloganView: some View {
        HStack(spacing: 4) {
            Text("Link to your ")
                .font(.system(size: 26, weight: .medium))
                .foregroundColor(isDarkMode ? Color.white.opacity(0.8) : Color(white: 0.35))
                .tracking(0.9)
            
            Text("World")
                .font(.system(size: 26, weight: .bold))
                .foregroundColor(isDarkMode ? Color(red: 0.45, green: 0.65, blue: 1.0) : AppColors.primary)
                .tracking(0.7)
        }
    }
    
    private func startAnimations() {
        // Logo 微呼吸效果
        withAnimation(
            .easeInOut(duration: 2.0)
            .repeatForever(autoreverses: true)
        ) {
            logoOpacity = 1.0
        }
        
        // 文字从下往上淡入
        withAnimation(
            .easeOut(duration: 0.8)
            .delay(0.3)
        ) {
            textOpacity = 1.0
        }
    }
}

#Preview("Light") {
    SplashView()
        .preferredColorScheme(.light)
}

#Preview("Dark") {
    SplashView()
        .preferredColorScheme(.dark)
}
