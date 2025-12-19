import SwiftUI
import Combine

/// 应用主题管理 - 企业级主题系统
public class AppTheme: ObservableObject {
    public static let shared = AppTheme()
    
    @Published public var colorScheme: ColorScheme = .light
    @Published public var isDarkMode: Bool = false
    
    private let themeKey = "app_theme"
    
    private init() {
        loadTheme()
    }
    
    /// 加载主题
    private func loadTheme() {
        if let themeString = UserDefaults.standard.string(forKey: themeKey) {
            switch themeString {
            case "dark":
                colorScheme = .dark
                isDarkMode = true
            case "light":
                colorScheme = .light
                isDarkMode = false
            default:
                colorScheme = .light
                isDarkMode = false
            }
        } else {
            // 默认跟随系统
            colorScheme = .light
            isDarkMode = false
        }
    }
    
    /// 设置主题
    public func setTheme(_ scheme: ColorScheme) {
        colorScheme = scheme
        isDarkMode = scheme == .dark
        UserDefaults.standard.set(
            scheme == .dark ? "dark" : "light",
            forKey: themeKey
        )
    }
    
    /// 切换主题
    public func toggleTheme() {
        setTheme(isDarkMode ? .light : .dark)
    }
}

/// 主题颜色
public struct ThemeColors {
    public static let primary = Color.blue
    public static let secondary = Color.gray
    public static let success = Color.green
    public static let warning = Color.orange
    public static let error = Color.red
    public static let background = Color(UIColor.systemBackground)
    public static let foreground = Color(UIColor.label)
}

