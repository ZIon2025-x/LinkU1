import SwiftUI

/// 环境值扩展 - 企业级环境值管理

private struct IsPreviewKey: EnvironmentKey {
    static let defaultValue = false
}

private struct ScreenSizeKey: EnvironmentKey {
    static let defaultValue = UIScreen.main.bounds.size
}

extension EnvironmentValues {
    /// 是否是预览模式
    public var isPreview: Bool {
        get { self[IsPreviewKey.self] }
        set { self[IsPreviewKey.self] = newValue }
    }
    
    /// 屏幕尺寸
    public var screenSize: CGSize {
        get { self[ScreenSizeKey.self] }
        set { self[ScreenSizeKey.self] = newValue }
    }
}

extension View {
    /// 设置预览模式
    public func isPreview(_ value: Bool) -> some View {
        environment(\.isPreview, value)
    }
    
    /// 设置屏幕尺寸
    public func screenSize(_ size: CGSize) -> some View {
        environment(\.screenSize, size)
    }
}

