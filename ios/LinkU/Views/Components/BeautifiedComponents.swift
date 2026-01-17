import SwiftUI

// MARK: - 骨架屏组件 (Skeleton Screen)
struct SkeletonView: View {
    @State private var isAnimating = false
    
    var body: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(
                LinearGradient(
                    colors: [
                        Color(UIColor.systemGray5),
                        Color(UIColor.systemGray6),
                        Color(UIColor.systemGray5)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .mask(
                Rectangle()
                    .offset(x: isAnimating ? 400 : -400)
            )
            .background(Color(UIColor.systemGray6))
            .cornerRadius(8)
            .onAppear {
                withAnimation(Animation.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    isAnimating = true
                }
            }
    }
}

// MARK: - 高级徽章 (Status Badge)
struct StatusBadge: View {
    let status: String
    
    var color: Color {
        switch status.lowercased() {
        case "open", "active": return AppColors.success
        case "closed", "completed": return AppColors.secondary
        case "pending": return AppColors.warning
        case "error", "cancelled": return AppColors.error
        default: return AppColors.primary
        }
    }
    
    var body: some View {
        Text(status.uppercased())
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .foregroundColor(color)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
    }
}

// MARK: - 价格标签 (Price Tag)
struct PriceTag: View {
    let price: Double
    var fontSize: CGFloat = 18
    
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 2) {
            Text("¥")
                .font(.system(size: fontSize * 0.7, weight: .bold))
            Text(String(format: "%.0f", price))
                .font(.system(size: fontSize, weight: .black, design: .rounded))
            if price.truncatingRemainder(dividingBy: 1) != 0 {
                Text(String(format: ".%02d", Int((price * 100).truncatingRemainder(dividingBy: 100))))
                    .font(.system(size: fontSize * 0.6, weight: .bold))
            }
        }
        .foregroundColor(AppColors.error)
    }
}

// MARK: - 渐变主按钮 (Primary Gradient Button)
struct PrimaryButton: View {
    let title: String
    let icon: String?
    let action: () -> Void
    
    init(_ title: String, icon: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon = icon {
                    Image(systemName: icon)
                }
                Text(title)
                    .fontWeight(.bold)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .foregroundColor(.white)
            .background(AppColors.primaryGradient)
            .cornerRadius(AppCornerRadius.medium)
            .shadow(color: AppColors.primary.opacity(0.3), radius: 12, x: 0, y: 6)
        }
        .bouncyButton()
    }
}

// MARK: - 加载视图 (Modern Loading View)
struct LoadingView: View {
    @State private var isAnimating = false
    
    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .stroke(AppColors.primary.opacity(0.1), lineWidth: 4)
                    .frame(width: 50, height: 50)
                
                Circle()
                    .trim(from: 0, to: 0.7)
                    .stroke(AppColors.primaryGradient, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 50, height: 50)
                    .rotationEffect(Angle(degrees: isAnimating ? 360 : 0))
                    .onAppear {
                        withAnimation(Animation.linear(duration: 1).repeatForever(autoreverses: false)) {
                            isAnimating = true
                        }
                    }
            }
            
            Text("正在为你加载...")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - 空状态视图 (Empty State View)
struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    
    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(AppColors.primary.opacity(0.05))
                    .frame(width: 100, height: 100)
                
                Image(systemName: icon)
                    .font(.system(size: 40))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(AppColors.primary)
            }
            
            Text(title)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(AppColors.textPrimary)
            
            Text(message)
                .font(.system(size: 15))
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
