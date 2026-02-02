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
    
    // MARK: - 背景
    private var backgroundView: some View {
        Group {
            if isDarkMode {
                Color(red: 0.07, green: 0.07, blue: 0.10)
                    .ignoresSafeArea()
            } else {
                RadialGradient(
                    colors: [Color(white: 0.98), Color.white],
                    center: .center,
                    startRadius: 50,
                    endRadius: 400
                )
                .ignoresSafeArea()
            }
        }
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
    
    // MARK: - Slogan
    private var sloganView: some View {
        HStack(spacing: 4) {
            Text("Link to your ")
                .font(.system(size: 26, weight: .medium, design: .serif))
                .foregroundColor(isDarkMode ? Color.white.opacity(0.8) : Color(white: 0.35))
                .tracking(0.4)
            
            Text("World")
                .font(.system(size: 26, weight: .bold, design: .serif))
                .foregroundColor(isDarkMode ? Color(red: 0.45, green: 0.65, blue: 1.0) : AppColors.primary)
                .tracking(0.3)
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
