import SwiftUI

/// Color 扩展 - 企业级颜色工具
extension Color {
    
    // MARK: - 初始化
    
    /// 从十六进制字符串创建颜色
    public init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
    
    /// 从 RGB 值创建颜色
    public init(r: Double, g: Double, b: Double, opacity: Double = 1.0) {
        self.init(.sRGB, red: r / 255, green: g / 255, blue: b / 255, opacity: opacity)
    }
    
    // MARK: - 转换
    
    /// 转换为十六进制字符串
    public var hexString: String {
        let uiColor = UIColor(self)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        let rgb: Int = (Int)(red * 255) << 16 | (Int)(green * 255) << 8 | (Int)(blue * 255) << 0
        
        return String(format: "#%06x", rgb)
    }
    
    // MARK: - 调整
    
    /// 调整亮度
    public func brightness(_ amount: Double) -> Color {
        return Color(UIColor(self).withBrightness(amount))
    }
    
    /// 调整透明度
    public func opacity(_ amount: Double) -> Color {
        let uiColor = UIColor(self)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        return Color(.sRGB, red: Double(red), green: Double(green), blue: Double(blue), opacity: amount)
    }
    
    /// 混合颜色
    public func blend(with color: Color, intensity: Double = 0.5) -> Color {
        let uiColor1 = UIColor(self)
        let uiColor2 = UIColor(color)
        
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        
        uiColor1.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        uiColor2.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        
        let r = r1 * (1 - intensity) + r2 * intensity
        let g = g1 * (1 - intensity) + g2 * intensity
        let b = b1 * (1 - intensity) + b2 * intensity
        let a = a1 * (1 - intensity) + a2 * intensity
        
        return Color(.sRGB, red: Double(r), green: Double(g), blue: Double(b), opacity: Double(a))
    }
}

// MARK: - UIColor 扩展

extension UIColor {
    func withBrightness(_ amount: CGFloat) -> UIColor {
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        
        if getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha) {
            return UIColor(hue: hue, saturation: saturation, brightness: brightness * amount, alpha: alpha)
        }
        return self
    }
}

