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
    
    /// 添加删除线
    public func strikethrough(_ active: Bool = true) -> Text {
        if active {
            return self.strikethrough()
        }
        return self
    }
}

