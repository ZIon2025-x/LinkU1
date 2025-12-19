import SwiftUI

/// 视图修饰符扩展 - 企业级视图工具

// MARK: - 阴影修饰符

extension View {
    /// 应用自定义阴影
    public func customShadow(
        color: Color = .black,
        radius: CGFloat = 5,
        x: CGFloat = 0,
        y: CGFloat = 2,
        opacity: Double = 0.1
    ) -> some View {
        self.shadow(
            color: color.opacity(opacity),
            radius: radius,
            x: x,
            y: y
        )
    }
}

// MARK: - 边框修饰符

extension View {
    /// 应用自定义边框
    public func customBorder(
        _ content: some ShapeStyle,
        width: CGFloat = 1,
        cornerRadius: CGFloat = 0
    ) -> some View {
        self.overlay(
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(content, lineWidth: width)
        )
    }
}

// MARK: - 渐变背景修饰符

extension View {
    /// 应用渐变背景
    public func gradientBackground(
        colors: [Color],
        startPoint: UnitPoint = .topLeading,
        endPoint: UnitPoint = .bottomTrailing
    ) -> some View {
        self.background(
            LinearGradient(
                colors: colors,
                startPoint: startPoint,
                endPoint: endPoint
            )
        )
    }
}

// MARK: - 卡片样式修饰符

extension View {
    /// 应用卡片样式
    public func cardStyle(
        backgroundColor: Color = .white,
        cornerRadius: CGFloat = 12,
        shadowRadius: CGFloat = 5,
        shadowOpacity: Double = 0.1
    ) -> some View {
        self
            .background(backgroundColor)
            .cornerRadius(cornerRadius)
            .customShadow(radius: shadowRadius, opacity: shadowOpacity)
    }
}

// MARK: - 隐藏修饰符

extension View {
    /// 条件隐藏
    @ViewBuilder
    public func hidden(_ condition: Bool) -> some View {
        if condition {
            self.hidden()
        } else {
            self
        }
    }
}

// MARK: - 动画修饰符

extension View {
    /// 应用默认动画
    public func defaultAnimation() -> some View {
        self.animation(.default, value: UUID())
    }
    
    /// 应用弹性动画
    public func springAnimation() -> some View {
        self.animation(.spring(), value: UUID())
    }
}

// MARK: - 尺寸修饰符

extension View {
    /// 应用固定尺寸
    public func fixedSize(_ size: CGSize) -> some View {
        self.frame(width: size.width, height: size.height)
    }
    
    /// 应用最小尺寸
    public func minSize(_ size: CGSize) -> some View {
        self.frame(minWidth: size.width, minHeight: size.height)
    }
    
    /// 应用最大尺寸
    public func maxSize(_ size: CGSize) -> some View {
        self.frame(maxWidth: size.width, maxHeight: size.height)
    }
}

