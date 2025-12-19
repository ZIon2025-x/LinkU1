import SwiftUI

/// 视图检查器 - 企业级视图调试工具
#if DEBUG
public struct ViewInspector: ViewModifier {
    let name: String
    let color: Color
    
    public init(name: String, color: Color = .red) {
        self.name = name
        self.color = color
    }
    
    public func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geometry in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(name)
                            .font(.caption2)
                            .foregroundColor(.white)
                            .padding(4)
                            .background(color.opacity(0.7))
                            .cornerRadius(4)
                        
                        Text("\(Int(geometry.size.width))×\(Int(geometry.size.height))")
                            .font(.caption2)
                            .foregroundColor(.white)
                            .padding(4)
                            .background(color.opacity(0.5))
                            .cornerRadius(4)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
            )
    }
}

extension View {
    /// 添加视图检查器（仅 DEBUG 模式）
    public func inspect(name: String, color: Color = .red) -> some View {
        #if DEBUG
        return self.modifier(ViewInspector(name: name, color: color))
        #else
        return self
        #endif
    }
}
#endif

