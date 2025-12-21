import SwiftUI

/// Text 扩展 - 企业级文本工具
extension Text {
    
    /// 创建带样式的文本
    public static func styled(
        _ content: String,
        font: Font = .body,
        color: Color = .primary,
        weight: Font.Weight = .regular
    ) -> Text {
        return Text(content)
            .font(font)
            .foregroundColor(color)
            .fontWeight(weight)
    }
    
    /// 创建强调文本
    public static func emphasized(_ content: String) -> Text {
        return Text(content)
            .fontWeight(.bold)
            .foregroundColor(.primary)
    }
    
    /// 创建次要文本
    public static func secondary(_ content: String) -> Text {
        return Text(content)
            .foregroundColor(.secondary)
            .font(.caption)
    }
    
    /// 创建错误文本
    public static func error(_ content: String) -> Text {
        return Text(content)
            .foregroundColor(.red)
            .font(.caption)
    }
    
    /// 创建成功文本
    public static func success(_ content: String) -> Text {
        return Text(content)
            .foregroundColor(.green)
            .font(.caption)
    }
}

/// 文本格式化扩展
extension Text {
    /// 添加链接样式
    public func linkStyle() -> some View {
        self
            .foregroundColor(.blue)
            .underline()
    }
    
    // 注意: strikethrough 方法已移除，因为 SwiftUI 的 Text 已有原生的 strikethrough() 方法
    // 自定义版本会导致无限递归
}

