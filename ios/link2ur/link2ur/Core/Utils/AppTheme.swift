import SwiftUI
import Combine

/// 主题模式枚举
public enum ThemeMode: String, CaseIterable {
    case system = "system"
    case light = "light"
    case dark = "dark"
    
    var displayName: String {
        switch self {
        case .system:
            return LocalizationKey.themeSystem.localized
        case .light:
            return LocalizationKey.themeLight.localized
        case .dark:
            return LocalizationKey.themeDark.localized
        }
    }
}

/// 应用主题管理 - 企业级主题系统
public class AppTheme: ObservableObject {
    public static let shared = AppTheme()
    
    @Published public var themeMode: ThemeMode = .system
    @Published public var colorScheme: ColorScheme? = nil // nil 表示跟随系统
    
    private let themeKey = "app_theme_mode"
    private var systemColorSchemeObserver: NSObjectProtocol?
    
    private init() {
        loadTheme()
        observeSystemColorScheme()
    }
    
    deinit {
        if let observer = systemColorSchemeObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    /// 加载主题设置
    private func loadTheme() {
        if let themeString = UserDefaults.standard.string(forKey: themeKey),
           let mode = ThemeMode(rawValue: themeString) {
            themeMode = mode
        } else {
            // 默认跟随系统
            themeMode = .system
        }
        updateColorScheme()
    }
    
    /// 更新 colorScheme 基于当前 themeMode
    private func updateColorScheme() {
        switch themeMode {
        case .system:
            // 跟随系统，使用 nil 让 SwiftUI 自动处理
            colorScheme = nil
        case .light:
            colorScheme = .light
        case .dark:
            colorScheme = .dark
        }
    }
    
    /// 观察系统颜色方案变化
    private func observeSystemColorScheme() {
        systemColorSchemeObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            // 当应用变为活跃时，如果模式是跟随系统，更新颜色方案
            if self?.themeMode == .system {
                self?.updateColorScheme()
            }
        }
    }
    
    /// 设置主题模式
    public func setThemeMode(_ mode: ThemeMode) {
        themeMode = mode
        updateColorScheme()
        UserDefaults.standard.set(mode.rawValue, forKey: themeKey)
    }
    
    /// 获取当前实际的颜色方案（如果跟随系统，返回系统当前的颜色方案）
    public func getCurrentColorScheme() -> ColorScheme {
        if themeMode == .system {
            // 获取系统当前的颜色方案
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                return windowScene.traitCollection.userInterfaceStyle == .dark ? .dark : .light
            }
            return .light
        }
        return colorScheme ?? .light
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

